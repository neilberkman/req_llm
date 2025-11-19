defmodule ReqLLM.ModelTest do
  use ExUnit.Case, async: true

  alias ReqLLM.Model

  # Helper to create test model with capabilities
  defp test_model(capabilities) do
    %LLMDB.Model{
      id: "test-model",
      provider: :test,
      capabilities: capabilities
    }
  end

  describe "reasoning_enabled?/1" do
    test "returns true when model has reasoning.enabled = true" do
      model = test_model(%{reasoning: %{enabled: true}})
      assert Model.reasoning_enabled?(model)
    end

    test "returns false when reasoning.enabled is false" do
      model = test_model(%{reasoning: %{enabled: false}})
      refute Model.reasoning_enabled?(model)
    end

    test "returns false when reasoning.enabled is nil" do
      model = test_model(%{reasoning: %{enabled: nil}})
      refute Model.reasoning_enabled?(model)
    end

    test "returns false when reasoning is missing" do
      model = test_model(%{})
      refute Model.reasoning_enabled?(model)
    end

    test "returns false for non-Model structs" do
      refute Model.reasoning_enabled?(%{})
      refute Model.reasoning_enabled?(nil)
    end
  end

  describe "json_native?/1" do
    test "returns true when model has json.native = true" do
      model = test_model(%{json: %{native: true}})
      assert Model.json_native?(model)
    end

    test "returns false when json.native is false" do
      model = test_model(%{json: %{native: false}})
      refute Model.json_native?(model)
    end

    test "returns false when json is missing" do
      model = test_model(%{})
      refute Model.json_native?(model)
    end

    test "returns false for non-Model structs" do
      refute Model.json_native?(%{})
    end
  end

  describe "json_schema?/1" do
    test "returns true when model has json.schema = true" do
      model = test_model(%{json: %{schema: true}})
      assert Model.json_schema?(model)
    end

    test "returns false when json.schema is false" do
      model = test_model(%{json: %{schema: false}})
      refute Model.json_schema?(model)
    end

    test "returns false when json is missing" do
      model = test_model(%{})
      refute Model.json_schema?(model)
    end

    test "returns false for non-Model structs" do
      refute Model.json_schema?(%{})
    end
  end

  describe "json_strict?/1" do
    test "returns true when model has json.strict = true" do
      model = test_model(%{json: %{strict: true}})
      assert Model.json_strict?(model)
    end

    test "returns false when json.strict is false" do
      model = test_model(%{json: %{strict: false}})
      refute Model.json_strict?(model)
    end

    test "returns false when json is missing" do
      model = test_model(%{})
      refute Model.json_strict?(model)
    end

    test "returns false for non-Model structs" do
      refute Model.json_strict?(%{})
    end
  end

  describe "tools_enabled?/1" do
    test "returns true when model has tools.enabled = true" do
      model = test_model(%{tools: %{enabled: true}})
      assert Model.tools_enabled?(model)
    end

    test "returns false when tools.enabled is false" do
      model = test_model(%{tools: %{enabled: false}})
      refute Model.tools_enabled?(model)
    end

    test "returns false when tools is missing" do
      model = test_model(%{})
      refute Model.tools_enabled?(model)
    end

    test "returns false for non-Model structs" do
      refute Model.tools_enabled?(%{})
    end
  end

  describe "tools_strict?/1" do
    test "returns true when model has tools.strict = true" do
      model = test_model(%{tools: %{strict: true}})
      assert Model.tools_strict?(model)
    end

    test "returns false when tools.strict is false" do
      model = test_model(%{tools: %{strict: false}})
      refute Model.tools_strict?(model)
    end

    test "returns false when tools is missing" do
      model = test_model(%{})
      refute Model.tools_strict?(model)
    end

    test "returns false for non-Model structs" do
      refute Model.tools_strict?(%{})
    end
  end

  describe "tools_parallel?/1" do
    test "returns true when model has tools.parallel = true" do
      model = test_model(%{tools: %{parallel: true}})
      assert Model.tools_parallel?(model)
    end

    test "returns false when tools.parallel is false" do
      model = test_model(%{tools: %{parallel: false}})
      refute Model.tools_parallel?(model)
    end

    test "returns false when tools is missing" do
      model = test_model(%{})
      refute Model.tools_parallel?(model)
    end

    test "returns false for non-Model structs" do
      refute Model.tools_parallel?(%{})
    end
  end

  describe "tools_streaming?/1" do
    test "returns true when model has tools.streaming = true" do
      model = test_model(%{tools: %{streaming: true}})
      assert Model.tools_streaming?(model)
    end

    test "returns false when tools.streaming is false" do
      model = test_model(%{tools: %{streaming: false}})
      refute Model.tools_streaming?(model)
    end

    test "returns false when tools is missing" do
      model = test_model(%{})
      refute Model.tools_streaming?(model)
    end

    test "returns false for non-Model structs" do
      refute Model.tools_streaming?(%{})
    end
  end

  describe "streaming_text?/1" do
    test "returns true when model has streaming.text = true" do
      model = test_model(%{streaming: %{text: true}})
      assert Model.streaming_text?(model)
    end

    test "returns false when streaming.text is false" do
      model = test_model(%{streaming: %{text: false}})
      refute Model.streaming_text?(model)
    end

    test "returns false when streaming is missing" do
      model = test_model(%{})
      refute Model.streaming_text?(model)
    end

    test "returns false for non-Model structs" do
      refute Model.streaming_text?(%{})
    end
  end

  describe "streaming_tool_calls?/1" do
    test "returns true when model has streaming.tool_calls = true" do
      model = test_model(%{streaming: %{tool_calls: true}})
      assert Model.streaming_tool_calls?(model)
    end

    test "returns false when streaming.tool_calls is false" do
      model = test_model(%{streaming: %{tool_calls: false}})
      refute Model.streaming_tool_calls?(model)
    end

    test "returns false when streaming is missing" do
      model = test_model(%{})
      refute Model.streaming_tool_calls?(model)
    end

    test "returns false for non-Model structs" do
      refute Model.streaming_tool_calls?(%{})
    end
  end

  describe "chat?/1" do
    test "returns true when model has chat = true" do
      model = test_model(%{chat: true})
      assert Model.chat?(model)
    end

    test "returns false when chat is false" do
      model = test_model(%{chat: false})
      refute Model.chat?(model)
    end

    test "returns false when chat is nil" do
      model = test_model(%{chat: nil})
      refute Model.chat?(model)
    end

    test "returns false when chat is missing" do
      model = test_model(%{})
      refute Model.chat?(model)
    end

    test "returns false for non-Model structs" do
      refute Model.chat?(%{})
    end
  end

  describe "list_helpers/0" do
    test "returns sorted list of all helper function names" do
      helpers = Model.list_helpers()

      assert is_list(helpers)
      assert length(helpers) == 11

      assert :reasoning_enabled? in helpers
      assert :json_native? in helpers
      assert :json_schema? in helpers
      assert :json_strict? in helpers
      assert :tools_enabled? in helpers
      assert :tools_strict? in helpers
      assert :tools_parallel? in helpers
      assert :tools_streaming? in helpers
      assert :streaming_text? in helpers
      assert :streaming_tool_calls? in helpers
      assert :chat? in helpers

      # Verify it's sorted
      assert helpers == Enum.sort(helpers)
    end
  end
end
