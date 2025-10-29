# xAI (Grok) Provider Guide

xAI's Grok models provide powerful reasoning capabilities with real-time web search through Live Search integration.

## Configuration

Set your xAI API key:

```bash
# Add to .env file (automatically loaded)
XAI_API_KEY=xai-...
```

Or use in-memory storage:

```elixir
ReqLLM.put_key(:xai_api_key, "xai-...")
```

## Supported Models

xAI Grok models:

- `grok-4` - Latest and most capable
- `grok-3-mini`, `grok-3-mini-fast` - Efficient with reasoning support
- `grok-2-1212`, `grok-2-vision-1212` - Previous generation with vision
- `grok-beta` - Beta features

See the full list with `mix req_llm.model_sync xai`.

## Basic Usage

```elixir
# Simple text generation
{:ok, response} = ReqLLM.generate_text(
  "xai:grok-4",
  "Explain quantum computing"
)

# Streaming
{:ok, stream_response} = ReqLLM.stream_text(
  "xai:grok-4",
  "Write a story"
)

ReqLLM.StreamResponse.tokens(stream_response)
|> Stream.each(&IO.write/1)
|> Stream.run()
```

## Provider-Specific Options

### Max Completion Tokens

Preferred over `max_tokens` for Grok-4 models:

```elixir
{:ok, response} = ReqLLM.generate_text(
  "xai:grok-4",
  "Long explanation",
  provider_options: [max_completion_tokens: 2000]
)
```

**Note**: ReqLLM automatically translates `max_tokens` to `max_completion_tokens` for models that require it.

### Live Search

Enable real-time web search capabilities:

```elixir
{:ok, response} = ReqLLM.generate_text(
  "xai:grok-4",
  "What are today's top tech headlines?",
  provider_options: [
    search_parameters: %{
      mode: "auto",              # auto, always, or never
      max_sources: 5,            # Maximum sources to cite
      date_range: "recent",      # recent, week, month, year
      citations: true            # Include citations in response
    }
  ]
)
```

Search modes:
- `"auto"` - Search when beneficial (default)
- `"always"` - Always search
- `"never"` - Disable search

**Note**: Live Search incurs additional costs per source retrieved.

### Reasoning Effort

Control reasoning level (grok-3-mini models only):

```elixir
{:ok, response} = ReqLLM.generate_text(
  "xai:grok-3-mini",
  "Complex problem",
  provider_options: [reasoning_effort: "high"]
)
```

Levels: `"low"`, `"medium"`, `"high"`

**Note**: Only supported for grok-3-mini and grok-3-mini-fast models.

### Parallel Tool Calls

Control whether multiple tools can be called simultaneously:

```elixir
{:ok, response} = ReqLLM.generate_text(
  "xai:grok-4",
  "Check weather in multiple cities",
  tools: [weather_tool],
  provider_options: [parallel_tool_calls: true]  # Default
)
```

### Structured Output Mode

xAI supports two modes for structured outputs:

```elixir
schema = [
  name: [type: :string, required: true],
  age: [type: :integer, required: true]
]

# Auto mode (recommended) - automatic selection
{:ok, response} = ReqLLM.generate_object(
  "xai:grok-4",
  "Generate a person",
  schema,
  provider_options: [xai_structured_output_mode: :auto]
)

# JSON schema mode - uses native response_format (models >= grok-2-1212)
{:ok, response} = ReqLLM.generate_object(
  "xai:grok-4",
  "Generate a person",
  schema,
  provider_options: [xai_structured_output_mode: :json_schema]
)

# Tool strict mode - uses strict tool calling (fallback for older models)
{:ok, response} = ReqLLM.generate_object(
  "xai:grok-2",
  "Generate a person",
  schema,
  provider_options: [xai_structured_output_mode: :tool_strict]
)
```

Modes:
- `:auto` - Automatic selection based on model (default)
- `:json_schema` - Native structured outputs (requires grok-2-1212+)
- `:tool_strict` - Strict tool calling fallback

### Stream Options

Configure streaming behavior:

```elixir
{:ok, stream_response} = ReqLLM.stream_text(
  "xai:grok-4",
  "Story",
  provider_options: [
    stream_options: %{include_usage: true}
  ]
)
```

## Complete Example with Live Search

```elixir
import ReqLLM.Context

context = Context.new([
  system("You are a helpful assistant with access to real-time web search"),
  user("Summarize today's news about AI developments")
])

{:ok, response} = ReqLLM.generate_text(
  "xai:grok-4",
  context,
  temperature: 0.7,
  max_tokens: 1500,
  provider_options: [
    search_parameters: %{
      mode: "always",
      max_sources: 10,
      date_range: "recent",
      citations: true
    },
    parallel_tool_calls: true
  ]
)

text = ReqLLM.Response.text(response)
usage = response.usage

IO.puts(text)
IO.puts("Cost: $#{usage.total_cost}")
```

## Tool Calling

Grok supports function calling:

```elixir
tools = [
  ReqLLM.tool(
    name: "get_weather",
    description: "Get weather for a location",
    parameter_schema: [
      location: [type: :string, required: true]
    ],
    callback: {WeatherAPI, :fetch}
  ),
  ReqLLM.tool(
    name: "get_stock_price",
    description: "Get stock price",
    parameter_schema: [
      symbol: [type: :string, required: true]
    ],
    callback: {StockAPI, :fetch}
  )
]

{:ok, response} = ReqLLM.generate_text(
  "xai:grok-4",
  "What's the weather in NYC and the price of AAPL?",
  tools: tools,
  provider_options: [parallel_tool_calls: true]  # Can call both tools at once
)
```

## Structured Output

Grok models support native structured outputs (grok-2-1212 and newer):

```elixir
schema = [
  title: [type: :string, required: true],
  summary: [type: :string, required: true],
  tags: [type: {:list, :string}],
  confidence: [type: :float]
]

{:ok, response} = ReqLLM.generate_object(
  "xai:grok-4",
  "Analyze this article and extract structured data",
  schema
)

data = ReqLLM.Response.object(response)
```

### Schema Constraints

xAI's native structured outputs have limitations:

**Not Supported:**
- `minLength`/`maxLength` for strings
- `minItems`/`maxItems`/`minContains`/`maxContains` for arrays
- `pattern` constraints
- `allOf` (must be expanded/flattened)

**Supported:**
- `anyOf`
- `additionalProperties: false` (enforced on root)

ReqLLM automatically sanitizes schemas to comply with these constraints.

## Model-Specific Notes

### Grok-4 Models

- Do NOT support `stop`, `presence_penalty`, or `frequency_penalty`
- Use `max_completion_tokens` instead of `max_tokens`
- Support native structured outputs

### Grok-3-mini Models

- Support `reasoning_effort` parameter
- Efficient for cost-sensitive applications
- Good balance of speed and quality

### Grok-2 Models (1212+)

- Support native structured outputs
- Support vision (grok-2-vision-1212)
- Previous generation capabilities

## Vision Support

Grok vision models support image analysis:

```elixir
import ReqLLM.Context
alias ReqLLM.Message.ContentPart

context = Context.new([
  user([
    ContentPart.text("Describe this image"),
    ContentPart.image_url("https://example.com/photo.jpg")
  ])
])

{:ok, response} = ReqLLM.generate_text(
  "xai:grok-2-vision-1212",
  context
)
```

## Error Handling

```elixir
case ReqLLM.generate_text("xai:grok-4", "Hello") do
  {:ok, response} -> 
    handle_success(response)
    
  {:error, error} -> 
    IO.puts("Error: #{error.message}")
end
```

## Cost Considerations

1. **Live Search**: Each source retrieved adds cost
2. **Model Selection**: grok-3-mini more cost-effective than grok-4
3. **Token Limits**: Set appropriate `max_completion_tokens` to control costs

## Resources

- [xAI API Documentation](https://docs.x.ai/)
- [Grok Models](https://x.ai/grok)
- [Pricing](https://x.ai/api)
