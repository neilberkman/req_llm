defmodule ReqLLM.Providers.AmazonBedrock.Mistral do
  @moduledoc """
  Mistral model family support for AWS Bedrock via Converse API.

  Handles Mistral-specific limitations:
  - Some Mistral models (7B, 8x7B) don't support system messages in Converse API
  - This module prepends system messages to the first user message as a workaround
  """

  alias ReqLLM.Message
  alias ReqLLM.Providers.AmazonBedrock.Converse

  @doc """
  Mistral formatter requires Converse API endpoint.
  """
  def requires_converse_api?, do: true

  @doc """
  Mistral models don't support toolChoice in Bedrock Converse API.
  """
  def supports_converse_tool_choice?, do: false

  @doc """
  Check if a specific Mistral model ID should preserve its inference profile prefix.

  Pixtral models REQUIRE inference profiles and cannot be invoked with base model ID.
  """
  def preserve_inference_profile?(model_id) do
    # Pixtral models must be invoked via inference profile (us./eu./ap.)
    String.contains?(model_id, "pixtral")
  end

  @doc """
  Format request for Mistral models.

  Wraps Converse formatter but handles system message incompatibility
  by prepending system messages to the first user message.
  """
  def format_request(model_id, context, opts) do
    # Convert system messages to user message prefix for compatibility
    context = convert_system_messages_for_mistral(context)

    # Delegate to Converse formatter
    Converse.format_request(model_id, context, opts)
  end

  @doc """
  Parse response - delegates to Converse formatter.
  """
  def parse_response(body, opts) do
    Converse.parse_response(body, opts)
  end

  @doc """
  Parse stream chunk - delegates to Converse formatter.
  """
  def parse_stream_chunk(chunk, model_id) do
    Converse.parse_stream_chunk(chunk, model_id)
  end

  # Convert system messages to user message prefix
  # This allows Mistral models to work with system messages even though
  # Bedrock Converse API doesn't support them for these models
  defp convert_system_messages_for_mistral(context) do
    {system_msgs, other_msgs} =
      context.messages
      |> Enum.split_with(fn %Message{role: role} -> role == :system end)

    case {system_msgs, other_msgs} do
      {[], _} ->
        # No system messages, return as-is
        context

      {sys_msgs, [first_user_msg | rest_msgs]} when first_user_msg.role == :user ->
        # Prepend system content to first user message
        system_text =
          sys_msgs
          |> Enum.map_join("\n\n", &extract_text_content/1)

        # Prepend system text to user message content
        updated_first_msg = prepend_system_to_user(first_user_msg, system_text)

        %{context | messages: [updated_first_msg | rest_msgs]}

      {sys_msgs, other_msgs} ->
        # No user message to prepend to - create one with system content
        system_text =
          sys_msgs
          |> Enum.map_join("\n\n", &extract_text_content/1)

        system_as_user = %Message{
          role: :user,
          content: system_text
        }

        %{context | messages: [system_as_user | other_msgs]}
    end
  end

  defp extract_text_content(%Message{content: content}) when is_binary(content) do
    content
  end

  defp extract_text_content(%Message{content: parts}) when is_list(parts) do
    parts
    |> Enum.filter(fn %{type: type} -> type == :text end)
    |> Enum.map_join("\n", fn %{text: text} -> text end)
  end

  defp prepend_system_to_user(%Message{content: content} = msg, system_text)
       when is_binary(content) do
    %{msg | content: system_text <> "\n\n" <> content}
  end

  defp prepend_system_to_user(%Message{content: parts} = msg, system_text) when is_list(parts) do
    system_part = %ReqLLM.Message.ContentPart{type: :text, text: system_text <> "\n\n"}
    %{msg | content: [system_part | parts]}
  end
end
