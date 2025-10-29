# Google Gemini Provider Guide

The Google provider gives you access to Gemini models with built-in web search grounding and thinking capabilities.

## Configuration

Set your Google API key:

```bash
# Add to .env file (automatically loaded)
GOOGLE_API_KEY=AIza...
```

Or use in-memory storage:

```elixir
ReqLLM.put_key(:google_api_key, "AIza...")
```

## Supported Models

Popular Gemini models include:

- `gemini-2.5-flash` - Fast, cost-effective with thinking support
- `gemini-2.5-pro` - Most capable with extended thinking
- `gemini-1.5-pro` - Balanced performance
- `gemini-1.5-flash` - Fast and efficient

See the full list with `mix req_llm.model_sync google`.

## Basic Usage

```elixir
# Simple text generation
{:ok, response} = ReqLLM.generate_text(
  "google:gemini-2.5-flash",
  "Explain async programming"
)

# Streaming
{:ok, stream_response} = ReqLLM.stream_text(
  "google:gemini-2.5-flash",
  "Write a poem"
)

ReqLLM.StreamResponse.tokens(stream_response)
|> Stream.each(&IO.write/1)
|> Stream.run()
```

## Provider-Specific Options

### API Version

Select between stable v1 and beta v1beta APIs:

```elixir
# Stable v1 (default)
{:ok, response} = ReqLLM.generate_text(
  "google:gemini-2.5-flash",
  "Hello",
  provider_options: [google_api_version: "v1"]
)

# Beta v1beta (required for grounding)
{:ok, response} = ReqLLM.generate_text(
  "google:gemini-2.5-flash",
  "What are today's headlines?",
  provider_options: [google_api_version: "v1beta"]
)
```

### Google Search Grounding

Enable built-in web search for real-time information (requires `google_api_version: "v1beta"`):

```elixir
{:ok, response} = ReqLLM.generate_text(
  "google:gemini-2.5-flash",
  "What are today's tech headlines?",
  provider_options: [
    google_api_version: "v1beta",
    google_grounding: %{enable: true}
  ]
)
```

Legacy Gemini 1.5 models use different grounding format:

```elixir
{:ok, response} = ReqLLM.generate_text(
  "google:gemini-1.5-pro",
  "Latest news",
  provider_options: [
    google_api_version: "v1beta",
    google_grounding: %{
      dynamic_retrieval: %{
        mode: "MODE_DYNAMIC",
        dynamic_threshold: 0.7
      }
    }
  ]
)
```

**Note**: When `google_grounding` is used without specifying `google_api_version`, v1beta is automatically selected with a warning.

### Thinking Budget

Control thinking tokens for Gemini 2.5 models:

```elixir
{:ok, response} = ReqLLM.generate_text(
  "google:gemini-2.5-pro",
  "Solve this complex problem",
  provider_options: [google_thinking_budget: 4096]
)

# Set to 0 to disable thinking
{:ok, response} = ReqLLM.generate_text(
  "google:gemini-2.5-flash",
  "Quick answer",
  provider_options: [google_thinking_budget: 0]
)

# Omit for dynamic allocation (default)
{:ok, response} = ReqLLM.generate_text(
  "google:gemini-2.5-pro",
  "Problem to solve"
)
```

### Safety Settings

Configure content safety filters:

```elixir
{:ok, response} = ReqLLM.generate_text(
  "google:gemini-2.5-flash",
  "Tell me a story",
  provider_options: [
    google_safety_settings: [
      %{
        category: "HARM_CATEGORY_HATE_SPEECH",
        threshold: "BLOCK_MEDIUM_AND_ABOVE"
      },
      %{
        category: "HARM_CATEGORY_DANGEROUS_CONTENT",
        threshold: "BLOCK_ONLY_HIGH"
      }
    ]
  ]
)
```

Safety categories:
- `HARM_CATEGORY_HATE_SPEECH`
- `HARM_CATEGORY_DANGEROUS_CONTENT`
- `HARM_CATEGORY_HARASSMENT`
- `HARM_CATEGORY_SEXUALLY_EXPLICIT`

Thresholds:
- `BLOCK_NONE`
- `BLOCK_ONLY_HIGH`
- `BLOCK_MEDIUM_AND_ABOVE`
- `BLOCK_LOW_AND_ABOVE`

### Candidate Count

Generate multiple response candidates:

```elixir
{:ok, response} = ReqLLM.generate_text(
  "google:gemini-2.5-flash",
  "Creative story idea",
  provider_options: [google_candidate_count: 3]
)
```

**Note**: Only the first candidate is returned in the response. This option is useful for internal ranking/selection.

### Embedding Dimensions

Control dimensions for embedding models:

```elixir
{:ok, embedding} = ReqLLM.embed(
  "google:text-embedding-004",
  "Hello world",
  provider_options: [dimensions: 256]
)
```

### Embedding Task Type

Specify the task type for embeddings:

```elixir
{:ok, embedding} = ReqLLM.embed(
  "google:text-embedding-004",
  "search query",
  provider_options: [task_type: "RETRIEVAL_QUERY"]
)
```

Task types:
- `RETRIEVAL_QUERY` - For search queries
- `RETRIEVAL_DOCUMENT` - For documents to be searched
- `SEMANTIC_SIMILARITY` - For similarity comparison
- `CLASSIFICATION` - For classification tasks

### Title for Embeddings

Provide document titles for better embedding quality:

```elixir
{:ok, embedding} = ReqLLM.embed(
  "google:text-embedding-004",
  "Document content...",
  provider_options: [
    task_type: "RETRIEVAL_DOCUMENT",
    title: "Product Documentation"
  ]
)
```

## Complete Example with Grounding

```elixir
import ReqLLM.Context

context = Context.new([
  system("You are a helpful assistant with access to web search"),
  user("What are the latest developments in quantum computing this month?")
])

{:ok, response} = ReqLLM.generate_text(
  "google:gemini-2.5-pro",
  context,
  temperature: 0.7,
  max_tokens: 1000,
  provider_options: [
    google_api_version: "v1beta",
    google_grounding: %{enable: true},
    google_thinking_budget: 2048,
    google_safety_settings: [
      %{category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE"}
    ]
  ]
)

text = ReqLLM.Response.text(response)
usage = response.usage

IO.puts(text)
IO.puts("Tokens: #{usage.total_tokens}, Cost: $#{usage.total_cost}")
```

## Tool Calling

Gemini supports function calling through ReqLLM's unified tool interface:

```elixir
weather_tool = ReqLLM.tool(
  name: "get_weather",
  description: "Get current weather",
  parameter_schema: [
    location: [type: :string, required: true]
  ],
  callback: {WeatherAPI, :fetch}
)

{:ok, response} = ReqLLM.generate_text(
  "google:gemini-2.5-flash",
  "What's the weather in Tokyo?",
  tools: [weather_tool]
)
```

## Multimodal Support

Gemini models support vision capabilities:

```elixir
import ReqLLM.Context
alias ReqLLM.Message.ContentPart

context = Context.new([
  user([
    ContentPart.text("Describe this image"),
    ContentPart.image_url("https://example.com/photo.jpg")
  ])
])

{:ok, response} = ReqLLM.generate_text("google:gemini-2.5-flash", context)
```

## Embeddings

```elixir
# Single embedding with task type
{:ok, embedding} = ReqLLM.embed(
  "google:text-embedding-004",
  "What is machine learning?",
  provider_options: [
    task_type: "RETRIEVAL_QUERY",
    dimensions: 768
  ]
)

# Multiple embeddings for document indexing
documents = ["Doc 1 content", "Doc 2 content", "Doc 3 content"]

{:ok, embeddings} = ReqLLM.embed(
  "google:text-embedding-004",
  documents,
  provider_options: [
    task_type: "RETRIEVAL_DOCUMENT"
  ]
)
```

## Error Handling

```elixir
case ReqLLM.generate_text("google:gemini-2.5-flash", "Hello") do
  {:ok, response} -> 
    handle_success(response)
    
  {:error, error} -> 
    IO.puts("Error: #{error.message}")
end
```

## Key Differences from OpenAI

Google's Gemini API differs from OpenAI (handled automatically by ReqLLM):

1. **Endpoint Structure**: Uses `/models/{model}:generateContent`
2. **Authentication**: API key in query parameter or header
3. **Message Format**: Different content/parts structure
4. **System Instructions**: Separate `systemInstruction` field
5. **Safety Settings**: Gemini-specific safety configuration

## Resources

- [Google AI Documentation](https://ai.google.dev/docs)
- [Gemini API Reference](https://ai.google.dev/api/rest)
- [Pricing](https://ai.google.dev/pricing)
