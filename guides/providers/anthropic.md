# Anthropic Provider Guide

The Anthropic provider gives you access to Claude models, including the latest Claude 3.5 Sonnet and Haiku models.

## Configuration

Set your Anthropic API key:

```bash
# Add to .env file (automatically loaded)
ANTHROPIC_API_KEY=sk-ant-...
```

Or use in-memory storage:

```elixir
ReqLLM.put_key(:anthropic_api_key, "sk-ant-...")
```

## Supported Models

Popular Claude models include:

- `claude-3-5-sonnet-20241022` - Most capable, balanced performance
- `claude-3-5-haiku-20241022` - Fastest, most cost-effective
- `claude-3-opus-20240229` - Most capable for complex tasks

See the full list with `mix req_llm.model_sync anthropic`.

## Basic Usage

```elixir
# Simple text generation
{:ok, response} = ReqLLM.generate_text(
  "anthropic:claude-3-5-sonnet-20241022",
  "Explain recursion in Elixir"
)

# Streaming
{:ok, stream_response} = ReqLLM.stream_text(
  "anthropic:claude-3-5-haiku-20241022",
  "Write a short story"
)

ReqLLM.StreamResponse.tokens(stream_response)
|> Stream.each(&IO.write/1)
|> Stream.run()
```

## Provider-Specific Options

Anthropic supports additional options via the `:provider_options` keyword:

### Anthropic Top K

Sample from the top K options for each token (1-40):

```elixir
ReqLLM.generate_text(
  "anthropic:claude-3-5-sonnet-20241022",
  "Be creative",
  provider_options: [anthropic_top_k: 20]
)
```

### API Version

Specify the Anthropic API version:

```elixir
ReqLLM.generate_text(
  "anthropic:claude-3-5-sonnet-20241022",
  "Hello",
  provider_options: [anthropic_version: "2023-06-01"]
)
```

### Stop Sequences

Custom sequences that cause the model to stop generating:

```elixir
ReqLLM.generate_text(
  "anthropic:claude-3-5-sonnet-20241022",
  "Count: 1, 2, 3",
  provider_options: [stop_sequences: ["5", "END"]]
)
```

### Metadata

Include optional metadata with your request:

```elixir
ReqLLM.generate_text(
  "anthropic:claude-3-5-sonnet-20241022",
  "Hello",
  provider_options: [
    anthropic_metadata: %{
      user_id: "user_123",
      session_id: "sess_456"
    }
  ]
)
```

### Extended Thinking (Reasoning)

Enable thinking/reasoning for supported models:

```elixir
ReqLLM.generate_text(
  "anthropic:claude-3-5-sonnet-20241022",
  "Solve this complex problem step by step",
  provider_options: [
    thinking: %{
      type: "enabled",
      budget_tokens: 4096
    }
  ]
)

# Access thinking content
thinking_text = ReqLLM.Response.thinking(response)
```

### Prompt Caching

Enable Anthropic's prompt caching feature to reduce costs for repeated prompts:

```elixir
ReqLLM.generate_text(
  "anthropic:claude-3-5-sonnet-20241022",
  context,
  provider_options: [
    anthropic_prompt_cache: true,
    anthropic_prompt_cache_ttl: "1h"  # Optional: 1 hour TTL
  ]
)
```

## Key Differences from OpenAI

Anthropic's API differs from OpenAI in several ways (handled automatically by ReqLLM):

1. **Endpoint**: Uses `/v1/messages` instead of `/chat/completions`
2. **Authentication**: Uses `x-api-key` header instead of `Authorization: Bearer`
3. **Message Format**: Different content block structure
4. **System Messages**: Included in messages array, not separate parameter
5. **Tool Calls**: Different format with content blocks

ReqLLM handles all these differences internally, providing a consistent API across providers.

## Complete Example

```elixir
import ReqLLM.Context

context = Context.new([
  system("You are a helpful coding assistant specializing in Elixir"),
  user("Explain how to use GenServer")
])

{:ok, response} = ReqLLM.generate_text(
  "anthropic:claude-3-5-sonnet-20241022",
  context,
  temperature: 0.7,
  max_tokens: 1000,
  provider_options: [
    anthropic_top_k: 20,
    stop_sequences: ["```elixir\nend\n```"]
  ]
)

text = ReqLLM.Response.text(response)
IO.puts(text)

# Check usage and costs
usage = response.usage
IO.puts("Tokens: #{usage.total_tokens}, Cost: $#{usage.total_cost}")
```

## Tool Calling

Claude supports function calling through ReqLLM's unified tool interface:

```elixir
weather_tool = ReqLLM.tool(
  name: "get_weather",
  description: "Get current weather for a location",
  parameter_schema: [
    location: [type: :string, required: true],
    units: [type: :string, default: "celsius"]
  ],
  callback: {WeatherAPI, :fetch}
)

{:ok, response} = ReqLLM.generate_text(
  "anthropic:claude-3-5-sonnet-20241022",
  "What's the weather in Paris?",
  tools: [weather_tool]
)
```

## Multimodal Support

Claude 3+ models support vision capabilities:

```elixir
import ReqLLM.Context
alias ReqLLM.Message.ContentPart

context = Context.new([
  user([
    ContentPart.text("What's in this image?"),
    ContentPart.image_url("https://example.com/photo.jpg")
  ])
])

{:ok, response} = ReqLLM.generate_text(
  "anthropic:claude-3-5-sonnet-20241022",
  context
)
```

## Error Handling

Anthropic-specific errors are normalized to ReqLLM's error format:

```elixir
case ReqLLM.generate_text("anthropic:invalid-model", "Hello") do
  {:ok, response} -> handle_success(response)
  {:error, error} -> 
    IO.puts("Error: #{error.message}")
    # Error types: ReqLLM.Error.API.*, ReqLLM.Error.Invalid.*
end
```

## Resources

- [Anthropic API Documentation](https://docs.anthropic.com/claude/reference/getting-started-with-the-api)
- [Claude Model Comparison](https://docs.anthropic.com/claude/docs/models-overview)
- [Pricing](https://www.anthropic.com/pricing)
