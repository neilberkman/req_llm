# Google Vertex AI

Access Claude and Gemini models through Google Cloud's Vertex AI platform. Supports Claude 4.x (Opus, Sonnet, Haiku) and Gemini 2.5 (Flash, Flash Lite, Pro) with full tool calling and reasoning support.

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

### `service_account_json`

- **Type**: String (file path)
- **Purpose**: Path to Google Cloud service account JSON file
- **Fallback**: `GOOGLE_APPLICATION_CREDENTIALS` env var
- **Example**: `provider_options: [service_account_json: "/path/to/credentials.json"]`

### `project_id`

- **Type**: String
- **Purpose**: Google Cloud project ID
- **Fallback**: `GOOGLE_CLOUD_PROJECT` env var
- **Example**: `provider_options: [project_id: "my-project-123"]`
- **Required**: Yes

### `region`

- **Type**: String
- **Default**: `"global"`
- **Purpose**: GCP region for Vertex AI endpoint
- **Example**: `provider_options: [region: "us-central1"]`
- **Note**: Use `"global"` for newest models, specific regions for regional deployment

### `additional_model_request_fields`

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

Vertex AI supports Google Gemini options for Gemini models:

#### `google_thinking_budget`

- **Type**: Integer
- **Purpose**: Thinking token budget for Gemini 2.5 models
- **Example**: `provider_options: [google_thinking_budget: 4096]`

#### `google_safety_settings`

- **Type**: List of maps
- **Purpose**: Safety filter configurations
- **Example**: `provider_options: [google_safety_settings: [%{category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE"}]]`

#### `google_candidate_count`

- **Type**: Integer
- **Purpose**: Number of response candidates (default: 1)
- **Example**: `provider_options: [google_candidate_count: 1]`

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

- **Gemini 2.5 Flash**: `google_vertex_anthropic:gemini-2.5-flash`
  - Fast multimodal model
  - Full tool calling and reasoning support
  - 1M context, 65K output

- **Gemini 2.5 Flash Lite**: `google_vertex_anthropic:gemini-2.5-flash-lite`
  - Lightweight fast model
  - Full tool calling and reasoning support
  - 1M context, 65K output
  - Most cost-effective

- **Gemini 2.5 Pro**: `google_vertex_anthropic:gemini-2.5-pro`
  - Highest capability Gemini model
  - Advanced reasoning and complex tasks
  - 1M context, 65K output

### Model ID Format

Vertex uses the `@` symbol for versioning:

- Format: `claude-{tier}-{version}@{date}`
- Example: `claude-sonnet-4-5@20250929`

## Wire Format Notes

- **Authentication**: OAuth2 with service account tokens (auto-refreshed)
- **Endpoint**: Model-specific paths under `aiplatform.googleapis.com`
- **Claude API**: Uses Anthropic's raw message format (compatible with native API)
- **Gemini API**: Uses Google's native Gemini format (same as direct Google provider)
- **Streaming**: Standard Server-Sent Events (SSE)
- **Region routing**: Global endpoint for newest models, regional for specific deployments

All differences handled automatically by ReqLLM.

## Resources

- [Vertex AI Documentation](https://cloud.google.com/vertex-ai/docs)
- [Claude on Vertex AI](https://cloud.google.com/vertex-ai/generative-ai/docs/partner-models/use-claude)
- [Gemini on Vertex AI](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/overview)
- [Service Account Setup](https://cloud.google.com/iam/docs/service-accounts-create)
