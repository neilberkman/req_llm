defmodule ReqLLM.Generation do
  @moduledoc """
  Text generation functionality for ReqLLM.

  This module provides the core text generation capabilities including:
  - Text generation with full response metadata
  - Text streaming with metadata
  - Usage and cost extraction utilities

  All functions follow Vercel AI SDK patterns and return structured responses
  with proper error handling.
  """

  alias ReqLLM.{Model, Response}

  require Logger

  @doc """
  Returns the base generation options schema.

  This schema delegates to ReqLLM.Provider.Options.generation_schema/0 which is
  the canonical runtime options schema. Provider-specific options should be
  validated separately by each provider via Provider.Options.process/4.

  For the complete schema including provider extensions, use:
      Provider.Options.compose_schema(Provider.Options.generation_schema(), provider_mod)
  """
  @spec schema :: NimbleOptions.t()
  def schema do
    ReqLLM.Provider.Options.generation_schema()
  end

  @doc """
  Generates text using an AI model with full response metadata.

  Returns a canonical ReqLLM.Response which includes usage data, context, and metadata.
  For simple text-only results, use `generate_text!/3`.

  ## Parameters

    * `model_spec` - Model specification in various formats
    * `messages` - Text prompt or list of messages
    * `opts` - Additional options (keyword list)

  ## Options

    * `:temperature` - Control randomness in responses (0.0 to 2.0)
    * `:max_tokens` - Limit the length of the response
    * `:top_p` - Nucleus sampling parameter
    * `:presence_penalty` - Penalize new tokens based on presence
    * `:frequency_penalty` - Penalize new tokens based on frequency
    * `:tools` - List of tool definitions
    * `:tool_choice` - Tool choice strategy
    * `:system_prompt` - System prompt to prepend
    * `:provider_options` - Provider-specific options

  ## Examples

      {:ok, response} = ReqLLM.Generation.generate_text("anthropic:claude-3-sonnet", "Hello world")
      ReqLLM.Response.text(response)
      #=> "Hello! How can I assist you today?"

      # Access usage metadata
      ReqLLM.Response.usage(response)
      #=> %{input_tokens: 10, output_tokens: 8}

  """

  @spec generate_text(
          String.t() | {atom(), keyword()} | struct(),
          String.t() | list(),
          keyword()
        ) :: {:ok, Response.t()} | {:error, term()}
  def generate_text(model_spec, messages, opts \\ []) do
    with {:ok, model} <- Model.from(model_spec),
         {:ok, provider_module} <- ReqLLM.provider(model.provider),
         {:ok, request} <- provider_module.prepare_request(:chat, model, messages, opts),
         {:ok, %Req.Response{status: status, body: decoded_response}} when status in 200..299 <-
           Req.request(request) do
      {:ok, decoded_response}
    else
      {:ok, %Req.Response{status: status, body: body}} ->
        {:error,
         ReqLLM.Error.API.Request.exception(
           reason: "HTTP #{status}: Request failed",
           status: status,
           response_body: body
         )}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Generates text using an AI model, returning only the text content.

  This is a convenience function that extracts just the text from the response.
  For access to usage metadata and other response data, use `generate_text/3`.
  Raises on error.

  ## Parameters

  Same as `generate_text/3`.

  ## Examples

      ReqLLM.Generation.generate_text!("anthropic:claude-3-sonnet", "Hello world")
      #=> "Hello! How can I assist you today?"

  """
  @spec generate_text!(
          String.t() | {atom(), keyword()} | struct(),
          String.t() | list(),
          keyword()
        ) :: String.t() | no_return()
  def generate_text!(model_spec, messages, opts \\ []) do
    case generate_text(model_spec, messages, opts) do
      {:ok, response} -> Response.text(response)
      {:error, error} -> raise error
    end
  end

  @doc """
  Streams text generation using an AI model with full response metadata.

  Returns a canonical ReqLLM.Response containing usage data and stream.
  For simple streaming without metadata, use `stream_text!/3`.

  ## Parameters

  Same as `generate_text/3`.

  ## Examples

      {:ok, response} = ReqLLM.Generation.stream_text("anthropic:claude-3-sonnet", "Tell me a story")
      ReqLLM.Response.text_stream(response) |> Enum.each(&IO.write/1)

      # Access usage metadata after streaming
      ReqLLM.Response.usage(response)
      #=> %{input_tokens: 15, output_tokens: 42}

  """
  @spec stream_text(
          String.t() | {atom(), keyword()} | struct(),
          String.t() | list(),
          keyword()
        ) :: {:ok, ReqLLM.StreamResponse.t()} | {:error, term()}
  def stream_text(model_spec, messages, opts \\ []) do
    with {:ok, model} <- Model.from(model_spec),
         {:ok, provider_module} <- ReqLLM.provider(model.provider),
         {:ok, context} <- ReqLLM.Context.normalize(messages, opts) do
      ReqLLM.Streaming.start_stream(provider_module, model, context, opts)
    end
  end

  @doc """
  **DEPRECATED**: This function will be removed in a future version.

  The streaming API has been redesigned to return a composite `StreamResponse` struct
  that provides both the stream and metadata. Use `stream_text/3` instead:

      {:ok, response} = ReqLLM.Generation.stream_text(model, messages)
      response.stream |> Enum.each(&IO.write/1)

  For simple text extraction, use:

      text = ReqLLM.StreamResponse.text(response)
  """
  @deprecated "Use stream_text/3 with StreamResponse instead"
  @spec stream_text!(
          String.t() | {atom(), keyword()} | struct(),
          String.t() | list(),
          keyword()
        ) :: Enumerable.t() | no_return()
  def stream_text!(_model_spec, _messages, _opts \\ []) do
    IO.warn("""
    ReqLLM.Generation.stream_text!/3 is deprecated and will be removed in a future version.

    Please migrate to the new streaming API:

    Old code:
        ReqLLM.Generation.stream_text!(model, messages) |> Enum.each(&IO.write/1)

    New code:
        {:ok, response} = ReqLLM.Generation.stream_text(model, messages)
        response.stream |> Enum.each(&IO.write/1)

    Or for simple text extraction:
        text = ReqLLM.StreamResponse.text(response)
    """)

    :ok
  end

  @doc """
  Generates structured data using an AI model with schema validation.

  Returns a canonical ReqLLM.Response which includes the generated object, usage data,
  context, and metadata. For simple object-only results, use `generate_object!/4`.

  ## Parameters

    * `model_spec` - Model specification in various formats
    * `messages` - Text prompt or list of messages
    * `schema` - Schema definition for structured output (keyword list)
    * `opts` - Additional options (keyword list)

  ## Options

    * `:temperature` - Control randomness in responses (0.0 to 2.0)
    * `:max_tokens` - Limit the length of the response
    * `:top_p` - Nucleus sampling parameter
    * `:presence_penalty` - Penalize new tokens based on presence
    * `:frequency_penalty` - Penalize new tokens based on frequency
    * `:system_prompt` - System prompt to prepend
    * `:provider_options` - Provider-specific options

  ## Examples

      {:ok, response} = ReqLLM.Generation.generate_object("anthropic:claude-3-sonnet", "Generate a person", person_schema)
      ReqLLM.Response.object(response)
      #=> %{name: "Alice Smith", age: 30, occupation: "Engineer"}

      # Access usage metadata
      ReqLLM.Response.usage(response)
      #=> %{input_tokens: 25, output_tokens: 15}

  """
  @spec generate_object(
          String.t() | {atom(), keyword()} | struct(),
          String.t() | list(),
          keyword(),
          keyword()
        ) :: {:ok, Response.t()} | {:error, term()}
  def generate_object(model_spec, messages, object_schema, opts \\ []) do
    with {:ok, model} <- Model.from(model_spec),
         {:ok, provider_module} <- ReqLLM.provider(model.provider),
         {:ok, compiled_schema} <- ReqLLM.Schema.compile(object_schema),
         opts_with_schema = Keyword.put(opts, :compiled_schema, compiled_schema),
         {:ok, request} <-
           provider_module.prepare_request(:object, model, messages, opts_with_schema),
         {:ok, %Req.Response{status: status, body: decoded_response}} when status in 200..299 <-
           Req.request(request) do
      {:ok, decoded_response}
    else
      {:ok, %Req.Response{status: status, body: body}} ->
        {:error,
         ReqLLM.Error.API.Request.exception(
           reason: "HTTP #{status}: Request failed",
           status: status,
           response_body: body
         )}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Generates structured data using an AI model, returning only the object content.

  This is a convenience function that extracts just the object from the response.
  For access to usage metadata and other response data, use `generate_object/4`.
  Raises on error.

  ## Parameters

  Same as `generate_object/4`.

  ## Examples

      ReqLLM.Generation.generate_object!("anthropic:claude-3-sonnet", "Generate a person", person_schema)
      #=> %{name: "Alice Smith", age: 30, occupation: "Engineer"}

  """
  @spec generate_object!(
          String.t() | {atom(), keyword()} | struct(),
          String.t() | list(),
          keyword(),
          keyword()
        ) :: map() | no_return()
  def generate_object!(model_spec, messages, object_schema, opts \\ []) do
    case generate_object(model_spec, messages, object_schema, opts) do
      {:ok, response} -> Response.object(response)
      {:error, error} -> raise error
    end
  end

  @doc """
  Streams structured data generation using an AI model with schema validation.

  Returns a `ReqLLM.StreamResponse` that provides both real-time structured data streaming
  and concurrent metadata collection. Uses the same Finch-based streaming infrastructure
  as `stream_text/3` with HTTP/2 multiplexing and connection pooling.

  ## Parameters

    * `model_spec` - Model specification in various formats
    * `messages` - Text prompt or list of messages
    * `schema` - Schema definition for structured output (keyword list)
    * `opts` - Additional options (keyword list)

  ## Options

  Same as `generate_object/4`.

  ## Returns

    * `{:ok, stream_response}` - StreamResponse with object stream and metadata task
    * `{:error, reason}` - Request failed or invalid parameters

  ## Examples

      # Stream structured data generation
      {:ok, response} = ReqLLM.Generation.stream_object("anthropic:claude-3-sonnet", "Generate a person", person_schema)

      # Process structured chunks as they arrive
      response.stream
      |> Stream.filter(&(&1.type in [:content, :tool_call]))
      |> Stream.each(&IO.inspect/1)
      |> Stream.run()

      # Concurrent metadata collection
      usage = ReqLLM.StreamResponse.usage(response)
      #=> %{input_tokens: 25, output_tokens: 15, total_cost: 0.045}

  ## Structure Notes

  Object streaming may include both content chunks (partial JSON) and tool_call chunks
  depending on the provider's structured output implementation. Use appropriate filtering
  based on your needs.

  """
  @spec stream_object(
          String.t() | {atom(), keyword()} | struct(),
          String.t() | list(),
          keyword(),
          keyword()
        ) :: {:ok, ReqLLM.StreamResponse.t()} | {:error, term()}
  def stream_object(model_spec, messages, object_schema, opts \\ []) do
    with {:ok, model} <- Model.from(model_spec),
         {:ok, provider_module} <- ReqLLM.provider(model.provider),
         {:ok, compiled_schema} <- ReqLLM.Schema.compile(object_schema),
         {:ok, prepared_req} <-
           provider_module.prepare_request(
             :object,
             model,
             messages,
             Keyword.put(opts, :compiled_schema, compiled_schema)
           ) do
      prepared_context = prepared_req.options[:context] || %ReqLLM.Context{messages: []}

      stream_opts =
        opts
        |> Keyword.merge(Map.to_list(prepared_req.options))
        |> Keyword.put(:stream, true)
        |> Keyword.put_new(:operation, :object)
        |> Keyword.put(:compiled_schema, compiled_schema)

      ReqLLM.Streaming.start_stream(provider_module, model, prepared_context, stream_opts)
    end
  end

  @doc """
  **DEPRECATED**: This function will be removed in a future version.

  The streaming API has been redesigned to return a composite `StreamResponse` struct
  that provides both the stream and metadata. Use `stream_object/4` instead:

      {:ok, response} = ReqLLM.Generation.stream_object(model, messages, schema)
      response.stream |> Enum.each(&IO.inspect/1)

  For simple object extraction, use:

      object = ReqLLM.StreamResponse.object(response)

  ## Legacy Parameters

  Same as `stream_object/4`.

  ## Legacy Examples

      ReqLLM.Generation.stream_object!("anthropic:claude-3-sonnet", "Generate a person", person_schema)
      |> Enum.each(&IO.inspect/1)

  """
  @deprecated "Use stream_object/4 with StreamResponse instead"
  @spec stream_object!(
          String.t() | {atom(), keyword()} | struct(),
          String.t() | list(),
          keyword(),
          keyword()
        ) :: Enumerable.t() | no_return()
  def stream_object!(_model_spec, _messages, _object_schema, _opts \\ []) do
    IO.warn("""
    ReqLLM.Generation.stream_object!/4 is deprecated and will be removed in a future version.

    Please migrate to the new streaming API:

    Old code:
        ReqLLM.Generation.stream_object!(model, messages, schema) |> Enum.each(&IO.inspect/1)

    New code:
        {:ok, response} = ReqLLM.Generation.stream_object(model, messages, schema)
        response.stream |> Enum.each(&IO.inspect/1)

    Or for simple object extraction:
        object = ReqLLM.StreamResponse.object(response)
    """)

    :ok
  end
end
