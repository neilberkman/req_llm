# Amazon Bedrock

Access AWS Bedrock's unified API for multiple AI model families including Anthropic Claude, Cohere Command R, OpenAI OSS, and Meta Llama.

## Configuration

AWS Bedrock uses AWS Signature V4 authentication. Configure credentials via:

### Option 1: Environment Variables (Recommended)

```bash
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1
```

### Option 2: ReqLLM Keys (Composite Key)

```elixir
ReqLLM.put_key(:aws_bedrock, %{
  access_key_id: "AKIA...",
  secret_access_key: "...",
  region: "us-east-1"
})
```

### Option 3: Provider Options

```elixir
ReqLLM.generate_text(
  "bedrock:anthropic.claude-3-sonnet-20240229-v1:0",
  "Hello",
  provider_options: [
    region: "us-east-1",
    access_key_id: "AKIA...",
    secret_access_key: "..."
  ]
)
```

### Authentication Types

#### Long-term Credentials (IAM User)

Standard AWS access key and secret key from an IAM user.

#### Temporary Credentials (STS AssumeRole)

Session tokens from AWS Security Token Service (STS) for temporary access:

```elixir
provider_options: [
  access_key_id: "ASIA...",
  secret_access_key: "...",
  session_token: "FwoGZXIv...",  # From STS AssumeRole
  region: "us-east-1"
]
```

## Provider Options

Passed via `:provider_options` keyword:

### `region`

- **Type**: String
- **Default**: `"us-east-1"`
- **Purpose**: AWS region where Bedrock is available
- **Example**: `provider_options: [region: "us-west-2"]`

### `access_key_id`

- **Type**: String
- **Purpose**: AWS Access Key ID
- **Fallback**: `AWS_ACCESS_KEY_ID` env var
- **Example**: `provider_options: [access_key_id: "AKIA..."]`

### `secret_access_key`

- **Type**: String
- **Purpose**: AWS Secret Access Key
- **Fallback**: `AWS_SECRET_ACCESS_KEY` env var
- **Example**: `provider_options: [secret_access_key: "..."]`

### `session_token`

- **Type**: String
- **Purpose**: AWS Session Token for temporary credentials
- **Example**: `provider_options: [session_token: "..."]`

### `use_converse`

- **Type**: Boolean
- **Purpose**: Force use of Bedrock Converse API
- **Default**: Auto-detect based on tools presence
- **Example**: `provider_options: [use_converse: true]`

### `additional_model_request_fields`

- **Type**: Map
- **Purpose**: Additional model-specific request fields
- **Example**: `provider_options: [additional_model_request_fields: %{reasoning_config: %{...}}]`
- **Use Case**: Claude extended thinking configuration

### Claude-Specific Options

#### `anthropic_prompt_cache`

- **Type**: Boolean
- **Purpose**: Enable Anthropic prompt caching for Claude models
- **Example**: `provider_options: [anthropic_prompt_cache: true]`

#### `anthropic_prompt_cache_ttl`

- **Type**: String (e.g., `"1h"`)
- **Purpose**: Cache TTL (default ~5min if omitted)
- **Example**: `provider_options: [anthropic_prompt_cache_ttl: "1h"]`

## Supported Model Families

### Anthropic Claude

- **All capabilities**: Tool calling, streaming with tools, attachments, reasoning, prompt caching
- **Inference profiles**: Supports region-specific routing (`global.`, `us.`, `eu.`)
- **Models**: Claude 3.x, 4.x (Sonnet, Opus, Haiku)
- **Example**: `bedrock:global.anthropic.claude-sonnet-4-5-20250929-v1:0`

### Cohere Command R/R+

- **Tool calling**: Full support including streaming with tools
- **RAG-optimized**: Excellent for production RAG workloads with citations
- **Works with Converse API** directly without custom formatter
- **Example**: `bedrock:cohere.command-r-plus-v1:0`

### OpenAI OSS

- **Smart routing**: Native `/invoke` for simple requests, `/converse` when tools present
- **Tool calling**: Full support in non-streaming mode
- **Models**: gpt-oss-20b, gpt-oss-120b
- **Example**: `bedrock:openai.gpt-oss-120b-1:0`

### Meta Llama

- **Inference profiles only**: us.meta.llama3-2-3b-instruct-v1:0
- **No tool calling**: Basic text generation only
- **Example**: `bedrock:us.meta.llama3-2-3b-instruct-v1:0`

## Wire Format Notes

- **Streaming**: AWS Event Stream format (binary framed, not SSE)
- **Auth**: AWS Signature V4 with **5-minute signature expiry**
- **Endpoints**: Model-specific paths (`/model/{model_id}/invoke` or `/converse`)
- **API Routing**: Auto-detects between native and Converse API based on tools

All differences handled automatically by ReqLLM.

### AWS Signature V4 Limitations

AWS Signature V4 has a **hardcoded 5-minute expiry** that cannot be extended:

- AWS validates signatures when **responding**, not when receiving requests
- Requests taking >5 minutes fail with **HTTP 403 "Signature expired"**
- **Real-world impact**: Slow models with large outputs can timeout
  - Example: Claude Opus 4.1 with extended thinking + high token limits
  - Recording `token_limit.json` fixture took >6 minutes → 403 error

**Workaround**: Use faster model variants or lower token limits for time-critical applications.

## Unsupported Model Families

Several Bedrock model families have tool calling support only in non-streaming mode. Because ReqLLM requires streaming+tools for complete fixture coverage (including `object_streaming.json`), these families are not currently supported:

- **Amazon Nova** (Micro, Lite, Pro, Premier)
- **Mistral** (7B, Large, Mixtral, Small, Pixtral)
- **Meta Llama 3.3 70B**

All return HTTP 400 "model doesn't support tool use in streaming mode" when attempting streaming with tools enabled.

If there's demand for these model families, workarounds (skip streaming tests, provide partial coverage) may be added. See [issue #163](https://github.com/agentjido/req_llm/issues/163) for details.

## Resources

- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Bedrock Runtime API](https://docs.aws.amazon.com/bedrock/latest/APIReference/API_runtime_Welcome.html)
- [AWS Signature V4 Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_aws-signing.html)
