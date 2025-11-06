defmodule ReqLLM.Providers.Google.Context do
  @moduledoc """
  Google Gemini-specific context encoding for the Gemini API format.

  Handles encoding ReqLLM contexts to Google's Gemini API format, shared between
  Google AI Studio and Vertex AI Gemini providers.

  ## Key Differences from OpenAI

  - System messages are extracted to top-level `systemInstruction` parameter
  - Uses `contents` instead of `messages`
  - Tool calls use `functionCall` content blocks
  - Tool results use `functionResponse` content blocks
  - Parameters use camelCase (maxOutputTokens, topP, topK, etc.)

  ## Message Format

      %{
        systemInstruction: %{parts: [%{text: "You are a helpful assistant"}]},
        contents: [
          %{role: "user", parts: [%{text: "What's the weather?"}]},
          %{role: "model", parts: [
            %{text: "I'll check that for you."},
            %{functionCall: %{name: "get_weather", args: %{location: "SF"}}}
          ]},
          %{role: "user", parts: [
            %{functionResponse: %{name: "get_weather", response: %{result: "72°F and sunny"}}}
          ]}
        ],
        generationConfig: %{
          maxOutputTokens: 1000,
          temperature: 0.7
        }
      }
  """

  alias ReqLLM.Providers.Google

  @doc """
  Encode context to Gemini API format.

  Returns a map with the Gemini request body structure.
  """
  @spec encode_request(ReqLLM.Context.t(), String.t(), keyword()) :: map()
  def encode_request(context, model_id, opts) do
    # Convert OpenAI-style context to Gemini format
    encoded = ReqLLM.Provider.Defaults.encode_context_to_openai_format(context, model_id)
    messages = encoded[:messages] || encoded["messages"] || []
    {system_instruction, contents} = Google.split_messages_for_gemini(messages)

    # Build tool configuration
    tool_config = Google.build_google_tool_config(opts[:tool_choice])

    tools_data =
      case opts[:tools] do
        tools when is_list(tools) and tools != [] ->
          grounding_tools = Google.build_grounding_tools(opts[:google_grounding])

          user_tools = [
            %{functionDeclarations: Enum.map(tools, &ReqLLM.Tool.to_schema(&1, :google))}
          ]

          all_tools = grounding_tools ++ user_tools

          %{tools: all_tools}
          |> maybe_put(:toolConfig, tool_config)

        _ ->
          case Google.build_grounding_tools(opts[:google_grounding]) do
            [] ->
              %{}
              |> maybe_put(:toolConfig, tool_config)

            grounding_tools ->
              %{tools: grounding_tools}
              |> maybe_put(:toolConfig, tool_config)
          end
      end

    # Build generationConfig with Gemini-specific parameter names
    generation_config =
      %{}
      |> maybe_put(:temperature, opts[:temperature])
      |> maybe_put(:maxOutputTokens, opts[:max_tokens])
      |> maybe_put(:topP, opts[:top_p])
      |> maybe_put(:topK, opts[:top_k])
      |> maybe_put(:candidateCount, opts[:google_candidate_count] || 1)
      |> Google.maybe_add_thinking_config(opts[:google_thinking_budget])

    %{}
    |> maybe_put(:cachedContent, opts[:cached_content])
    |> maybe_put(:systemInstruction, system_instruction)
    |> Map.put(:contents, contents)
    |> Map.merge(tools_data)
    |> maybe_put(:generationConfig, generation_config)
    |> maybe_put(:safetySettings, opts[:google_safety_settings])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
