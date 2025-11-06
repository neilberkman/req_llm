defmodule ReqLLM.Providers.GoogleVertex.Gemini do
  @moduledoc """
  Gemini model family support for Google Vertex AI.

  Handles Gemini models (Gemini 2.5 Flash, Gemini 2.5 Pro, etc.)
  on Google Vertex AI.

  This module acts as a thin adapter between Vertex AI's GCP infrastructure
  and Google's native Gemini format. It delegates to the native Google
  provider for all format conversion.

  ## Reasoning Support

  Extended thinking (reasoning) is supported for Gemini 2.5 models.
  Enable with `google_thinking_budget` option.
  """

  alias ReqLLM.Providers.Google

  @doc """
  Formats a ReqLLM context into Gemini request format for Vertex AI.

  Delegates to the shared Google.Context module. Vertex AI uses the
  same Gemini API format as the direct Google provider.
  """
  def format_request(model_id, context, opts) do
    # Delegate to shared Google.Context encoding
    Google.Context.encode_request(context, model_id, opts)
  end

  @doc """
  Parses a Gemini response from Vertex AI into ReqLLM format.

  Delegates to the native Google provider's response parsing logic.
  """
  def parse_response(body, model, opts) do
    operation = opts[:operation]
    context = opts[:context] || %ReqLLM.Context{messages: []}

    # Create temporary request/response pair that mimics what Google.decode_response expects
    temp_req = %Req.Request{
      options: %{
        context: context,
        model: model.model,
        operation: operation,
        stream: false
      }
    }

    temp_resp = %Req.Response{
      status: 200,
      body: body
    }

    # Let Google provider decode the response
    {_req, decoded_resp} = Google.decode_response({temp_req, temp_resp})

    case decoded_resp do
      %Req.Response{body: parsed_body} -> {:ok, parsed_body}
      error -> {:error, error}
    end
  end

  @doc """
  Extracts usage information from Gemini response.

  Delegates to the native Google provider's usage extraction.
  """
  def extract_usage(body, _model) do
    # Gemini responses include usageMetadata field
    case body do
      %{"usageMetadata" => usage} ->
        {:ok,
         %{
           input_tokens: Map.get(usage, "promptTokenCount", 0),
           output_tokens: Map.get(usage, "candidatesTokenCount", 0),
           reasoning_tokens: Map.get(usage, "thinkingTokenCount"),
           cached_tokens: Map.get(usage, "cachedContentTokenCount")
         }}

      _ ->
        {:error, :no_usage_data}
    end
  end

  @doc """
  Decodes Server-Sent Events for streaming responses.

  Gemini uses the same SSE format as the native Google provider.
  """
  def decode_stream_event(event, model) do
    # Delegate directly to Google provider's decode_stream_event
    Google.decode_stream_event(event, model)
  end
end
