defmodule ReqLLM.Step.RetryProviderIntegrationTest do
  use ExUnit.Case, async: true

  alias ReqLLM.Model
  alias ReqLLM.Providers.{Anthropic, Google, AmazonBedrock}

  setup do
    System.put_env("ANTHROPIC_API_KEY", "test-anthropic-key")
    System.put_env("GOOGLE_API_KEY", "test-google-key")
    System.put_env("AWS_ACCESS_KEY_ID", "AKIATEST")
    System.put_env("AWS_SECRET_ACCESS_KEY", "test-secret-key")
    System.put_env("AWS_REGION", "us-east-1")

    context = %ReqLLM.Context{
      messages: [
        %ReqLLM.Message{
          role: :user,
          content: [%ReqLLM.Message.ContentPart{type: :text, text: "Hello"}]
        }
      ]
    }

    {:ok, context: context}
  end

  describe "Anthropic provider retry configuration" do
    test "attach/3 configures retry options on request" do
      model = %Model{provider: :anthropic, model: "claude-3-5-haiku-20241022"}

      request =
        Anthropic.attach(
          Req.new(),
          model,
          []
        )

      assert is_function(request.options[:retry], 2)
      assert request.options[:max_retries] == 3
      assert is_function(request.options[:retry_delay], 1)
      assert request.options[:retry_delay].(1) == 0
      assert request.options[:retry_log_level] == false
    end

    test "retry function correctly identifies retryable errors" do
      model = %Model{provider: :anthropic, model: "claude-3-5-haiku-20241022"}

      request =
        Anthropic.attach(
          Req.new(),
          model,
          []
        )

      retry_fn = request.options[:retry]

      assert retry_fn.(request, %Req.TransportError{reason: :closed}) == {:delay, 0}
      assert retry_fn.(request, %Req.TransportError{reason: :timeout}) == {:delay, 0}
      assert retry_fn.(request, %Req.TransportError{reason: :econnrefused}) == {:delay, 0}

      assert retry_fn.(request, %RuntimeError{message: "error"}) == false
      assert retry_fn.(request, %Req.Response{status: 500}) == false
      assert retry_fn.(request, %Req.Response{status: 200}) == false
    end
  end

  describe "Google provider retry configuration" do
    test "attach/3 configures retry options on request" do
      model = %Model{provider: :google, model: "gemini-2.0-flash-exp"}

      request =
        Google.attach(
          Req.new(),
          model,
          []
        )

      assert is_function(request.options[:retry], 2)
      assert request.options[:max_retries] == 3
      assert is_function(request.options[:retry_delay], 1)
      assert request.options[:retry_delay].(1) == 0
      assert request.options[:retry_log_level] == false
    end

    test "retry function correctly identifies retryable errors" do
      model = %Model{provider: :google, model: "gemini-2.0-flash-exp"}

      request =
        Google.attach(
          Req.new(),
          model,
          []
        )

      retry_fn = request.options[:retry]

      assert retry_fn.(request, %Req.TransportError{reason: :closed}) == {:delay, 0}
      assert retry_fn.(request, %Req.TransportError{reason: :timeout}) == {:delay, 0}
      assert retry_fn.(request, %Req.TransportError{reason: :econnrefused}) == {:delay, 0}

      assert retry_fn.(request, %RuntimeError{message: "error"}) == false
      assert retry_fn.(request, %Req.Response{status: 500}) == false
      assert retry_fn.(request, %Req.Response{status: 200}) == false
    end
  end

  describe "Amazon Bedrock provider retry configuration" do
    test "attach/3 configures retry options on request", %{context: context} do
      model = %Model{provider: :amazon_bedrock, model: "anthropic.claude-3-5-haiku-20241022-v1:0"}

      request =
        AmazonBedrock.attach(
          Req.new(),
          model,
          context: context
        )

      assert is_function(request.options[:retry], 2)
      assert request.options[:max_retries] == 3
      assert is_function(request.options[:retry_delay], 1)
      assert request.options[:retry_delay].(1) == 0
      assert request.options[:retry_log_level] == false
    end

    test "retry function correctly identifies retryable errors", %{context: context} do
      model = %Model{provider: :amazon_bedrock, model: "anthropic.claude-3-5-haiku-20241022-v1:0"}

      request =
        AmazonBedrock.attach(
          Req.new(),
          model,
          context: context
        )

      retry_fn = request.options[:retry]

      assert retry_fn.(request, %Req.TransportError{reason: :closed}) == {:delay, 0}
      assert retry_fn.(request, %Req.TransportError{reason: :timeout}) == {:delay, 0}
      assert retry_fn.(request, %Req.TransportError{reason: :econnrefused}) == {:delay, 0}

      assert retry_fn.(request, %RuntimeError{message: "error"}) == false
      assert retry_fn.(request, %Req.Response{status: 500}) == false
      assert retry_fn.(request, %Req.Response{status: 200}) == false
    end
  end

  describe "all three providers have consistent retry behavior" do
    test "all providers use the same retry configuration", %{context: context} do
      anthropic_model = %Model{provider: :anthropic, model: "claude-3-5-haiku-20241022"}
      google_model = %Model{provider: :google, model: "gemini-2.0-flash-exp"}

      bedrock_model = %Model{
        provider: :amazon_bedrock,
        model: "anthropic.claude-3-5-haiku-20241022-v1:0"
      }

      anthropic_request =
        Anthropic.attach(
          Req.new(),
          anthropic_model,
          []
        )

      google_request =
        Google.attach(
          Req.new(),
          google_model,
          []
        )

      bedrock_request =
        AmazonBedrock.attach(
          Req.new(),
          bedrock_model,
          context: context
        )

      assert anthropic_request.options[:max_retries] == 3
      assert google_request.options[:max_retries] == 3
      assert bedrock_request.options[:max_retries] == 3

      assert is_function(anthropic_request.options[:retry], 2)
      assert is_function(google_request.options[:retry], 2)
      assert is_function(bedrock_request.options[:retry], 2)

      assert is_function(anthropic_request.options[:retry_delay], 1)
      assert is_function(google_request.options[:retry_delay], 1)
      assert is_function(bedrock_request.options[:retry_delay], 1)

      assert anthropic_request.options[:retry_delay].(1) == 0
      assert google_request.options[:retry_delay].(1) == 0
      assert bedrock_request.options[:retry_delay].(1) == 0

      assert anthropic_request.options[:retry_log_level] == false
      assert google_request.options[:retry_log_level] == false
      assert bedrock_request.options[:retry_log_level] == false
    end

    test "all providers handle the same set of retryable errors", %{context: context} do
      anthropic_model = %Model{provider: :anthropic, model: "claude-3-5-haiku-20241022"}
      google_model = %Model{provider: :google, model: "gemini-2.0-flash-exp"}

      bedrock_model = %Model{
        provider: :amazon_bedrock,
        model: "anthropic.claude-3-5-haiku-20241022-v1:0"
      }

      anthropic_request =
        Anthropic.attach(Req.new(), anthropic_model, [])

      google_request =
        Google.attach(Req.new(), google_model, [])

      bedrock_request =
        AmazonBedrock.attach(
          Req.new(),
          bedrock_model,
          context: context
        )

      retryable_errors = [
        %Req.TransportError{reason: :closed},
        %Req.TransportError{reason: :timeout},
        %Req.TransportError{reason: :econnrefused}
      ]

      non_retryable_cases = [
        %Req.TransportError{reason: :nxdomain},
        %RuntimeError{message: "error"},
        %Req.Response{status: 200},
        %Req.Response{status: 500}
      ]

      for error <- retryable_errors do
        assert anthropic_request.options[:retry].(anthropic_request, error) == {:delay, 0},
               "Anthropic should retry #{inspect(error)}"

        assert google_request.options[:retry].(google_request, error) == {:delay, 0},
               "Google should retry #{inspect(error)}"

        assert bedrock_request.options[:retry].(bedrock_request, error) == {:delay, 0},
               "Bedrock should retry #{inspect(error)}"
      end

      for case <- non_retryable_cases do
        assert anthropic_request.options[:retry].(anthropic_request, case) == false,
               "Anthropic should not retry #{inspect(case)}"

        assert google_request.options[:retry].(google_request, case) == false,
               "Google should not retry #{inspect(case)}"

        assert bedrock_request.options[:retry].(bedrock_request, case) == false,
               "Bedrock should not retry #{inspect(case)}"
      end
    end
  end
end
