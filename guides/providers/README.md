# Provider Guides

Provider-specific documentation for ReqLLM's supported providers. Each guide covers provider-specific options, features, and best practices.

## Available Providers

### [Anthropic](anthropic.md) 🎯
Claude models with extended thinking and prompt caching.

**Key Features:**
- Claude 3.5 Sonnet, Haiku, Opus models
- Extended thinking/reasoning capabilities
- Prompt caching for cost optimization
- Vision support

**Popular Options:**
- `anthropic_top_k` - Sampling control
- `thinking` - Enable reasoning
- `anthropic_prompt_cache` - Prompt caching
- `stop_sequences` - Custom stop sequences

---

### [OpenAI](openai.md) 🤖
GPT models and reasoning models (o1, o3, GPT-5) with dual API architecture.

**Key Features:**
- Chat Completions API (GPT-4, GPT-3.5)
- Responses API (o1, o3, o4, GPT-4.1, GPT-5)
- Automatic routing based on model
- Native structured outputs
- Embeddings support

**Popular Options:**
- `openai_structured_output_mode` - Control structured output strategy
- `reasoning_effort` - Reasoning level for o1/o3/GPT-5
- `max_completion_tokens` - Token limit for reasoning models
- `dimensions` - Embedding dimensions

---

### [Google Gemini](google.md) 🔍
Gemini models with built-in web search grounding and thinking capabilities.

**Key Features:**
- Gemini 2.5 Pro and Flash with thinking support
- Google Search grounding for real-time info
- API version selection (v1 stable, v1beta)
- Safety settings configuration
- Embeddings with task types

**Popular Options:**
- `google_grounding` - Enable web search
- `google_thinking_budget` - Control thinking tokens
- `google_api_version` - Select API version
- `google_safety_settings` - Content safety filters

---

### [OpenRouter](openrouter.md) 🔀
Unified access to 200+ models from multiple providers with intelligent routing.

**Key Features:**
- Access to models from multiple providers
- Automatic fallback routing
- Provider preferences
- App attribution for rankings

**Popular Options:**
- `openrouter_models` - Fallback model list
- `openrouter_route` - Routing strategy
- `openrouter_provider` - Provider preferences
- `app_referer`, `app_title` - App attribution

---

### [Groq](groq.md) ⚡
Ultra-fast inference with custom LPU hardware.

**Key Features:**
- Llama 3.3, Mixtral, Gemma models
- Exceptional streaming performance
- Web search integration
- Service tier selection for performance control

**Popular Options:**
- `service_tier` - Performance tier selection
- `reasoning_effort` - Reasoning level
- `search_settings` - Web search configuration
- `reasoning_format` - Reasoning output format

---

### [xAI (Grok)](xai.md) 🌐
Grok models with Live Search for real-time web access.

**Key Features:**
- Grok-4, Grok-3-mini models
- Live Search with citations
- Native structured outputs (grok-2-1212+)
- Vision support (grok-2-vision)
- Reasoning capabilities

**Popular Options:**
- `search_parameters` - Live Search configuration
- `reasoning_effort` - Reasoning level (grok-3-mini)
- `xai_structured_output_mode` - Structured output strategy
- `max_completion_tokens` - Token limits

---

## Common Patterns

### Selecting a Provider

```elixir
# Direct provider selection
{:ok, response} = ReqLLM.generate_text("anthropic:claude-3-5-sonnet", "Hello")

# With provider options
{:ok, response} = ReqLLM.generate_text(
  "google:gemini-2.5-flash",
  "Hello",
  provider_options: [
    google_grounding: %{enable: true}
  ]
)
```

### Provider-Agnostic Code

```elixir
# Same code works across providers
providers = ["anthropic:claude-3-5-sonnet", "openai:gpt-4o", "google:gemini-2.5-flash"]

for model_spec <- providers do
  {:ok, response} = ReqLLM.generate_text(model_spec, "Hello")
  IO.puts("#{model_spec}: #{ReqLLM.Response.text(response)}")
end
```

### Using Provider-Specific Features

```elixir
# Anthropic: Extended thinking
ReqLLM.generate_text(
  "anthropic:claude-3-5-sonnet",
  "Complex problem",
  provider_options: [thinking: %{type: "enabled", budget_tokens: 4096}]
)

# Google: Web grounding
ReqLLM.generate_text(
  "google:gemini-2.5-flash",
  "Latest news",
  provider_options: [
    google_api_version: "v1beta",
    google_grounding: %{enable: true}
  ]
)

# xAI: Live Search
ReqLLM.generate_text(
  "xai:grok-4",
  "Current events",
  provider_options: [
    search_parameters: %{mode: "always", max_sources: 5}
  ]
)
```

## Provider Options

All provider-specific options are passed via the `:provider_options` keyword:

```elixir
ReqLLM.generate_text(
  model_spec,
  messages,
  temperature: 0.7,              # Standard option
  max_tokens: 1000,              # Standard option
  provider_options: [            # Provider-specific options
    anthropic_top_k: 20,         # Anthropic-specific
    google_grounding: %{...},    # Google-specific
    search_parameters: %{...}    # xAI-specific
  ]
)
```

## Choosing a Provider

Consider these factors when selecting a provider:

### By Use Case

- **General Purpose**: Anthropic Claude, OpenAI GPT-4
- **Speed**: Groq, Google Gemini Flash
- **Real-time Info**: Google Gemini (grounding), xAI Grok (Live Search)
- **Reasoning**: OpenAI o1/o3, Anthropic Claude (thinking)
- **Cost-Effective**: OpenRouter, Groq
- **Embeddings**: OpenAI, Google

### By Feature

- **Vision**: Anthropic Claude, OpenAI GPT-4, Google Gemini, xAI Grok-2-vision
- **Tool Calling**: All providers
- **Streaming**: All providers
- **Structured Output**: OpenAI, xAI (native), others (via tools)
- **Web Search**: Google (grounding), xAI (Live Search), Groq

### By Performance

- **Lowest Latency**: Groq
- **Highest Quality**: OpenAI GPT-4, Anthropic Claude 3.5 Sonnet
- **Best Value**: Check current pricing, OpenRouter for comparison

## Configuration

All providers support multiple key management approaches:

```bash
# .env file (recommended)
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GOOGLE_API_KEY=AIza...
GROQ_API_KEY=gsk_...
XAI_API_KEY=xai-...
OPENROUTER_API_KEY=sk-or-...
```

```elixir
# In-memory storage
ReqLLM.put_key(:anthropic_api_key, "sk-ant-...")
ReqLLM.put_key(:openai_api_key, "sk-...")

# Per-request override
ReqLLM.generate_text(model, messages, api_key: "sk-...")
```

## Additional Providers

ReqLLM also supports:

- **Cerebras** - Ultra-fast open-source model inference
- **Amazon Bedrock** - AWS-hosted models
- **Meta** - Llama models
- **Zai/ZaiCoder** - Specialized coding models

See provider modules in `lib/req_llm/providers/` for full list.

## Next Steps

1. Choose a provider from the list above
2. Read the provider-specific guide
3. Configure your API key
4. Start building with ReqLLM's unified API

## Contributing

To add a new provider guide:

1. Create `guides/providers/provider_name.md`
2. Follow the template from existing guides
3. Document all provider-specific options from `provider_schema`
4. Include examples and best practices
5. Update this README

See [Adding a Provider](../adding_a_provider.md) for implementation details.
