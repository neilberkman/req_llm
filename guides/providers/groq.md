# Groq Provider Guide

Groq provides ultra-fast LLM inference with their custom hardware, delivering exceptional performance for real-time applications.

## Configuration

Set your Groq API key:

```bash
# Add to .env file (automatically loaded)
GROQ_API_KEY=gsk_...
```

Or use in-memory storage:

```elixir
ReqLLM.put_key(:groq_api_key, "gsk_...")
```

## Supported Models

Popular Groq models include:

- `llama-3.3-70b-versatile` - Latest Llama 3.3
- `llama-3.1-8b-instant` - Fast, efficient
- `mixtral-8x7b-32768` - Large context window
- `gemma2-9b-it` - Google's Gemma 2

See the full list with `mix req_llm.model_sync groq`.

## Basic Usage

```elixir
# Simple text generation
{:ok, response} = ReqLLM.generate_text(
  "groq:llama-3.3-70b-versatile",
  "Explain async programming"
)

# Streaming (ultra-fast with Groq hardware)
{:ok, stream_response} = ReqLLM.stream_text(
  "groq:llama-3.1-8b-instant",
  "Write a story"
)

ReqLLM.StreamResponse.tokens(stream_response)
|> Stream.each(&IO.write/1)
|> Stream.run()
```

## Provider-Specific Options

### Service Tier

Control performance tier for requests:

```elixir
{:ok, response} = ReqLLM.generate_text(
  "groq:llama-3.3-70b-versatile",
  "Hello",
  provider_options: [service_tier: "performance"]
)
```

Tiers:
- `"auto"` - Automatic selection (default)
- `"on_demand"` - Standard on-demand
- `"flex"` - Flexible pricing
- `"performance"` - Highest performance

### Reasoning Effort

Control reasoning level for compatible models:

```elixir
{:ok, response} = ReqLLM.generate_text(
  "groq:deepseek-r1-distill-llama-70b",
  "Complex problem",
  provider_options: [reasoning_effort: "high"]
)
```

Levels: `"none"`, `"default"`, `"low"`, `"medium"`, `"high"`

### Reasoning Format

Specify format for reasoning output:

```elixir
{:ok, response} = ReqLLM.generate_text(
  "groq:deepseek-r1-distill-llama-70b",
  "Problem to solve",
  provider_options: [reasoning_format: "detailed"]
)
```

### Web Search

Enable web search capabilities:

```elixir
{:ok, response} = ReqLLM.generate_text(
  "groq:llama-3.3-70b-versatile",
  "Latest tech news",
  provider_options: [
    search_settings: %{
      include_domains: ["techcrunch.com", "arstechnica.com"],
      exclude_domains: ["spam.com"]
    }
  ]
)
```

### Compound Custom

Custom configuration for Compound systems:

```elixir
{:ok, response} = ReqLLM.generate_text(
  "groq:model",
  "Text",
  provider_options: [
    compound_custom: %{
      # Compound-specific settings
    }
  ]
)
```

## Complete Example

```elixir
import ReqLLM.Context

context = Context.new([
  system("You are a fast, helpful coding assistant"),
  user("Explain tail call optimization")
])

{:ok, response} = ReqLLM.generate_text(
  "groq:llama-3.3-70b-versatile",
  context,
  temperature: 0.7,
  max_tokens: 1000,
  provider_options: [
    service_tier: "performance",
    search_settings: %{
      include_domains: ["developer.mozilla.org", "stackoverflow.com"]
    }
  ]
)

text = ReqLLM.Response.text(response)
usage = response.usage

IO.puts(text)
IO.puts("Tokens: #{usage.total_tokens}, Cost: $#{usage.total_cost}")
```

## Tool Calling

Groq supports function calling on compatible models:

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
  "groq:llama-3.3-70b-versatile",
  "What's the weather in Berlin?",
  tools: [weather_tool]
)
```

## Structured Output

Groq supports structured output generation:

```elixir
schema = [
  name: [type: :string, required: true],
  age: [type: :integer, required: true],
  skills: [type: {:list, :string}]
]

{:ok, response} = ReqLLM.generate_object(
  "groq:llama-3.3-70b-versatile",
  "Generate a software engineer profile",
  schema
)

person = ReqLLM.Response.object(response)
```

## Performance Tips

1. **Use Streaming**: Groq's hardware excels at streaming - you'll see tokens instantly
2. **Choose Right Model**: Use `8b-instant` for speed, `70b` for quality
3. **Service Tier**: Use `"performance"` tier for lowest latency
4. **Batch Requests**: Groq handles concurrent requests efficiently

## Streaming Performance

Groq's custom hardware provides exceptional streaming performance:

```elixir
{:ok, stream_response} = ReqLLM.stream_text(
  "groq:llama-3.1-8b-instant",
  "Count from 1 to 100"
)

# You'll see tokens appearing almost instantly
stream_response
|> ReqLLM.StreamResponse.tokens()
|> Stream.each(&IO.write/1)
|> Stream.run()
```

## Error Handling

```elixir
case ReqLLM.generate_text("groq:llama-3.3-70b-versatile", "Hello") do
  {:ok, response} -> 
    handle_success(response)
    
  {:error, error} -> 
    IO.puts("Error: #{error.message}")
end
```

## Key Advantages

1. **Speed**: Custom LPU hardware for ultra-fast inference
2. **Cost**: Competitive pricing for high performance
3. **Reliability**: Enterprise-grade infrastructure
4. **Compatibility**: OpenAI-compatible API

## Resources

- [Groq Documentation](https://console.groq.com/docs)
- [Model Playground](https://console.groq.com/playground)
- [Pricing](https://wow.groq.com/pricing/)
