# OpenRouter Provider Guide

OpenRouter provides a unified API to access hundreds of AI models from multiple providers with intelligent routing and fallback capabilities.

## Configuration

Set your OpenRouter API key:

```bash
# Add to .env file (automatically loaded)
OPENROUTER_API_KEY=sk-or-...
```

Or use in-memory storage:

```elixir
ReqLLM.put_key(:openrouter_api_key, "sk-or-...")
```

## Basic Usage

```elixir
# Access any model through OpenRouter
{:ok, response} = ReqLLM.generate_text(
  "openrouter:anthropic/claude-3.5-sonnet",
  "Explain quantum computing"
)

# Different provider models
{:ok, response} = ReqLLM.generate_text(
  "openrouter:google/gemini-pro",
  "Write a poem"
)
```

## Provider-Specific Options

### Model Routing

Specify fallback models for automatic routing:

```elixir
{:ok, response} = ReqLLM.generate_text(
  "openrouter:anthropic/claude-3.5-sonnet",
  "Hello",
  provider_options: [
    openrouter_models: [
      "anthropic/claude-3.5-sonnet",
      "anthropic/claude-3-haiku",
      "openai/gpt-4o"
    ],
    openrouter_route: "fallback"
  ]
)
```

### Provider Preferences

Control which providers are used for routing:

```elixir
{:ok, response} = ReqLLM.generate_text(
  "openrouter:meta-llama/llama-3-70b",
  "Question",
  provider_options: [
    openrouter_provider: %{
      order: ["Together", "Fireworks"],
      require_parameters: true
    }
  ]
)
```

### Prompt Transforms

Apply transforms to prompts:

```elixir
{:ok, response} = ReqLLM.generate_text(
  "openrouter:model",
  "Text",
  provider_options: [
    openrouter_transforms: ["middle-out"]
  ]
)
```

### Sampling Parameters

OpenRouter supports additional sampling controls:

```elixir
{:ok, response} = ReqLLM.generate_text(
  "openrouter:model",
  "Creative task",
  provider_options: [
    openrouter_top_k: 40,
    openrouter_repetition_penalty: 1.1,
    openrouter_min_p: 0.05,
    openrouter_top_a: 0.1
  ]
)
```

**Note**: Some parameters like `top_k` may not be available for all underlying models (e.g., OpenAI models).

### App Attribution

Set headers for app discoverability in OpenRouter rankings:

```elixir
{:ok, response} = ReqLLM.generate_text(
  "openrouter:model",
  "Hello",
  provider_options: [
    app_referer: "https://myapp.com",
    app_title: "My Awesome App"
  ]
)
```

These set:
- `HTTP-Referer` header for app identification
- `X-Title` header for app title in rankings

## Complete Example

```elixir
import ReqLLM.Context

context = Context.new([
  system("You are a helpful assistant"),
  user("Explain machine learning")
])

{:ok, response} = ReqLLM.generate_text(
  "openrouter:anthropic/claude-3.5-sonnet",
  context,
  temperature: 0.7,
  max_tokens: 1000,
  provider_options: [
    # Fallback routing
    openrouter_models: [
      "anthropic/claude-3.5-sonnet",
      "anthropic/claude-3-haiku"
    ],
    openrouter_route: "fallback",
    
    # Sampling controls
    openrouter_top_k: 40,
    openrouter_repetition_penalty: 1.05,
    
    # App attribution
    app_referer: "https://myapp.com",
    app_title: "ML Learning App"
  ]
)

text = ReqLLM.Response.text(response)
usage = response.usage

IO.puts(text)
IO.puts("Cost: $#{usage.total_cost}")
```

## Tool Calling

OpenRouter supports tool calling for compatible models:

```elixir
weather_tool = ReqLLM.tool(
  name: "get_weather",
  description: "Get weather for a location",
  parameter_schema: [
    location: [type: :string, required: true]
  ],
  callback: {WeatherAPI, :fetch}
)

{:ok, response} = ReqLLM.generate_text(
  "openrouter:anthropic/claude-3.5-sonnet",
  "What's the weather in Tokyo?",
  tools: [weather_tool]
)
```

## Streaming

```elixir
{:ok, stream_response} = ReqLLM.stream_text(
  "openrouter:anthropic/claude-3-haiku",
  "Write a story"
)

ReqLLM.StreamResponse.tokens(stream_response)
|> Stream.each(&IO.write/1)
|> Stream.run()
```

## Model Discovery

OpenRouter provides access to hundreds of models. Browse available models:

- Visit [OpenRouter Models](https://openrouter.ai/models)
- Use the registry: `mix req_llm.model_sync openrouter`

Popular models:
- `anthropic/claude-3.5-sonnet`
- `openai/gpt-4o`
- `google/gemini-pro`
- `meta-llama/llama-3-70b`
- `mistralai/mixtral-8x7b`

## Pricing

OpenRouter uses dynamic pricing based on the underlying provider. Check response usage for actual costs:

```elixir
{:ok, response} = ReqLLM.generate_text("openrouter:model", "Hello")
IO.puts("Cost: $#{response.usage.total_cost}")
```

## Error Handling

```elixir
case ReqLLM.generate_text("openrouter:model", "Hello") do
  {:ok, response} -> 
    handle_success(response)
    
  {:error, error} -> 
    IO.puts("Error: #{error.message}")
end
```

## Key Benefits

1. **Unified Access**: Single API for multiple providers
2. **Automatic Fallback**: Routing to alternative models on failure
3. **Cost Optimization**: Choose models by price/performance
4. **No Vendor Lock-in**: Easy switching between providers

## Resources

- [OpenRouter Documentation](https://openrouter.ai/docs)
- [Model List](https://openrouter.ai/models)
- [Pricing](https://openrouter.ai/docs#models)
