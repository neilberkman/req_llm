import Config

config :logger, :console,
  level: :warning,
  format: "$time $metadata[$level] $message\n",
  metadata: [:req_llm, :component]

config :req_llm, :catalog_enabled?, true

config :req_llm, :catalog,
  allow: %{
    anthropic: :all,
    openai: :all,
    google: :all,
    google_vertex: :all,
    groq: :all,
    xai: :all,
    openrouter: :all,
    amazon_bedrock: :all,
    google_vertex_anthropic: :all,
    zai: :all,
    zai_coder: :all,
    cerebras: :all
  },
  overrides: [],
  custom: []

config :req_llm, :sample_embedding_models, ~w(
    openai:text-embedding-3-small
    google:text-embedding-004
  )
config :req_llm, :sample_text_models, ~w(
    anthropic:claude-3-5-haiku-20241022
    openai:gpt-4o-mini
    google:gemini-2.0-flash
    google_vertex:gemini-2.5-flash
    google_vertex:gemini-2.5-flash-lite
    google_vertex:gemini-2.5-pro
  )
config :req_llm, :test_sample_per_provider, 1
