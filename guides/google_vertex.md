# Google Vertex AI

Access both Claude and Gemini models through Google Cloud's Vertex AI platform. Supports all Claude 4.x models (Opus, Sonnet, Haiku) and Gemini 2.5 models (Pro, Flash) with full tool calling, reasoning support, and context caching.

## Configuration

Vertex AI uses Google Cloud OAuth2 authentication with service accounts.

### Service Account (Recommended)

**Environment Variables:**

```bash
GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
GOOGLE_CLOUD_PROJECT="your-project-id"
GOOGLE_CLOUD_REGION="global"
```

**Provider Options:**

```elixir
ReqLLM.generate_text(
  "google_vertex_anthropic:claude-sonnet-4-5@20250929",
  "Hello",
  provider_options: [
    service_account_json: "/path/to/service-account.json",
    project_id: "your-project-id",
    region: "global"
  ]
)
```

## Provider Options

Passed via `:provider_options` keyword:

### Common Options

#### `service_account_json`

- **Type**: String (file path)
- **Purpose**: Path to Google Cloud service account JSON file
- **Fallback**: `GOOGLE_APPLICATION_CREDENTIALS` env var
- **Example**: `provider_options: [service_account_json: "/path/to/credentials.json"]`

#### `project_id`

- **Type**: String
- **Purpose**: Google Cloud project ID
- **Fallback**: `GOOGLE_CLOUD_PROJECT` env var
- **Example**: `provider_options: [project_id: "my-project-123"]`
- **Required**: Yes

#### `region`

- **Type**: String
- **Default**: `"global"`
- **Purpose**: GCP region for Vertex AI endpoint
- **Example**: `provider_options: [region: "us-central1"]`
- **Note**: Use `"global"` for newest models, specific regions for regional deployment

#### `additional_model_request_fields`

- **Type**: Map
- **Purpose**: Model-specific request fields (e.g., thinking configuration)
- **Example**:
  ```elixir
  provider_options: [
    additional_model_request_fields: %{
      thinking: %{type: "enabled", budget_tokens: 4096}
    }
  ]
  ```

### Claude-Specific Options

Vertex AI supports the same Claude options as native Anthropic:

#### `anthropic_top_k`

- **Type**: `1..40`
- **Purpose**: Sample from top K options per token
- **Example**: `provider_options: [anthropic_top_k: 20]`

#### `stop_sequences`

- **Type**: List of strings
- **Purpose**: Custom stop sequences
- **Example**: `provider_options: [stop_sequences: ["END", "STOP"]]`

#### `anthropic_metadata`

- **Type**: Map
- **Purpose**: Request metadata for tracking
- **Example**: `provider_options: [anthropic_metadata: %{user_id: "123"}]`

#### `thinking`

- **Type**: Map
- **Purpose**: Enable extended thinking/reasoning
- **Example**: `provider_options: [thinking: %{type: "enabled", budget_tokens: 4096}]`
- **Access**: `ReqLLM.Response.thinking(response)`

#### `anthropic_prompt_cache`

- **Type**: Boolean
- **Purpose**: Enable prompt caching
- **Example**: `provider_options: [anthropic_prompt_cache: true]`

#### `anthropic_prompt_cache_ttl`

- **Type**: String (e.g., `"1h"`)
- **Purpose**: Cache TTL (default ~5min if omitted)
- **Example**: `provider_options: [anthropic_prompt_cache_ttl: "1h"]`

### Gemini-Specific Options

#### `google_thinking_budget`

- **Type**: Integer
- **Purpose**: Thinking token budget for Gemini 2.5 reasoning models
- **Example**: `provider_options: [google_thinking_budget: 4096]`
- **Access**: `ReqLLM.Response.thinking(response)`

#### `google_safety_settings`

- **Type**: List of maps
- **Purpose**: Configure safety filters
- **Example**:
  ```elixir
  provider_options: [
    google_safety_settings: [
      %{category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE"}
    ]
  ]
  ```

#### `google_grounding`

- **Type**: Map
- **Purpose**: Enable Google Search grounding
- **Example**: `provider_options: [google_grounding: %{google_search: %{}}]`

#### `cached_content`

- **Type**: String
- **Purpose**: Reference to cached content for 90% cost savings
- **Example**: `provider_options: [cached_content: cache.name]`
- **See**: Context Caching section below

## Supported Models

### Claude 4.5 Family

- **Haiku 4.5**: `google_vertex_anthropic:claude-haiku-4-5@20251001`
  - Fast, cost-effective
  - Full tool calling and reasoning support

- **Sonnet 4.5**: `google_vertex_anthropic:claude-sonnet-4-5@20250929`
  - Balanced performance and capability
  - Extended thinking support

- **Opus 4.1**: `google_vertex_anthropic:claude-opus-4-1@20250805`
  - Highest capability
  - Advanced reasoning

### Claude 4.0 & Earlier

- **Sonnet 4.0**: `google_vertex_anthropic:claude-sonnet-4@20250514`
- **Opus 4.0**: `google_vertex_anthropic:claude-opus-4@20250514`
- **Sonnet 3.7**: `google_vertex_anthropic:claude-3-7-sonnet@20250219`
- **Sonnet 3.5 v2**: `google_vertex_anthropic:claude-3-5-sonnet@20241022`
- **Haiku 3.5**: `google_vertex_anthropic:claude-3-5-haiku@20241022`

### Gemini 2.5 Family

- **Gemini 2.5 Pro**: `google_vertex_anthropic:gemini-2.5-pro`
  - Highest capability Gemini model
  - Extended thinking support
  - Context caching support

- **Gemini 2.5 Flash**: `google_vertex_anthropic:gemini-2.5-flash`
  - Fast, cost-effective
  - Extended thinking support
  - Context caching support

- **Gemini 2.5 Flash Lite**: `google_vertex_anthropic:gemini-2.5-flash-lite`
  - Fastest, most cost-effective
  - Lightweight workloads

### Model ID Format

Vertex uses different formats for Claude vs Gemini:

- **Claude**: `claude-{tier}-{version}@{date}` (e.g., `claude-sonnet-4-5@20250929`)
- **Gemini**: `gemini-{version}-{tier}` (e.g., `gemini-2.5-flash`)

## Context Caching

Both Claude and Gemini models on Vertex AI support context caching for up to 90% cost savings on repeated prompts.

### Creating a Cache

```elixir
alias ReqLLM.Providers.Google.CachedContent

{:ok, cache} = CachedContent.create(
  provider: :google_vertex,
  model: "gemini-2.5-flash",
  service_account_json: "/path/to/credentials.json",
  project_id: "your-project-id",
  region: "us-central1",
  contents: [
    %{
      role: "user",
      parts: [%{text: "Large document content..."}]
    }
  ],
  ttl: "3600s"
)
```

### Using a Cache

```elixir
{:ok, response} = ReqLLM.generate_text(
  "google_vertex_anthropic:gemini-2.5-flash",
  "Question about the document?",
  provider_options: [
    cached_content: cache.name,
    service_account_json: "/path/to/credentials.json",
    project_id: "your-project-id",
    region: "us-central1"
  ]
)

# Check cache usage
response.usage.cached_tokens  # Number of tokens served from cache
```

### Managing Caches

```elixir
# List all caches
{:ok, caches} = CachedContent.list(
  provider: :google_vertex,
  service_account_json: "/path/to/credentials.json",
  project_id: "your-project-id",
  region: "us-central1"
)

# Get cache details
{:ok, cache} = CachedContent.get(
  provider: :google_vertex,
  name: cache.name,
  service_account_json: "/path/to/credentials.json",
  project_id: "your-project-id",
  region: "us-central1"
)

# Update TTL
{:ok, updated} = CachedContent.update(
  provider: :google_vertex,
  name: cache.name,
  ttl: "7200s",
  service_account_json: "/path/to/credentials.json",
  project_id: "your-project-id",
  region: "us-central1"
)

# Delete cache
:ok = CachedContent.delete(
  provider: :google_vertex,
  name: cache.name,
  service_account_json: "/path/to/credentials.json",
  project_id: "your-project-id",
  region: "us-central1"
)
```

### Cache Requirements

- **Minimum tokens**: 1,024 for Flash models, 4,096 for Pro models
- **TTL format**: String with 's' suffix (e.g., "600s", "3600s")
- **Region**: Must match region used for inference
- **Gemini only**: Context caching is only supported for Gemini models on Vertex (not Claude)

## Wire Format Notes

- **Authentication**: OAuth2 with service account tokens (auto-refreshed)
- **Endpoint**: Model-specific paths under `aiplatform.googleapis.com`
- **API**: Uses Anthropic's raw message format (compatible with native API)
- **Streaming**: Standard Server-Sent Events (SSE)
- **Region routing**: Global endpoint for newest models, regional for specific deployments

All differences handled automatically by ReqLLM.

## Resources

- [Vertex AI Documentation](https://cloud.google.com/vertex-ai/docs)
- [Claude on Vertex AI](https://cloud.google.com/vertex-ai/generative-ai/docs/partner-models/use-claude)
- [Service Account Setup](https://cloud.google.com/iam/docs/service-accounts-create)
