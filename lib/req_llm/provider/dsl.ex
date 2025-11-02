defmodule ReqLLM.Provider.DSL do
  @moduledoc """
  Domain-Specific Language for defining ReqLLM providers.

  This macro simplifies provider creation by automatically handling:
  - Plugin behaviour implementation
  - Metadata loading from JSON files
  - Provider registry registration
  - Default configuration setup

  ## Usage

      defmodule MyProvider do
      use ReqLLM.Provider.DSL,
      id: :my_provider,
      base_url: "https://api.example.com/v1",
      metadata: "priv/models_dev/my_provider.json"

        def attach(request, model) do
          # Provider-specific request configuration
        end

        def parse(response, model) do
          # Provider-specific response parsing
        end
      end

  ## Options

    * `:id` - Unique provider identifier (required atom)
    * `:base_url` - Default API base URL (required string)
    * `:metadata` - Path to JSON metadata file (optional string)
    * `:context_wrapper` - Module name for context wrapper struct (optional atom)
    * `:response_wrapper` - Module name for response wrapper struct (optional atom)
    * `:provider_schema` - NimbleOptions schema defining supported options and defaults (optional keyword list)

  ## Generated Code

  The DSL automatically generates:

  1. **Plugin Behaviour**: `use Req.Plugin`
  2. **Default Base URL**: `def default_base_url(), do: "https://api.example.com/v1"`
  3. **Registry Registration**: Calls `ReqLLM.Provider.Registry.register/3`
  4. **Metadata Loading**: Loads and parses JSON metadata at compile time

  ## Metadata Files

  Metadata files should contain JSON with model information:

      {
        "models": [
          {
            "id": "my-model-1",
            "context_length": 8192,
            "capabilities": ["text_generation"],
            "pricing": {
              "input": 0.001,
              "output": 0.002
            }
          }
        ],
        "capabilities": ["text_generation", "embeddings"],
        "documentation": "https://api.example.com/docs"
      }

  ## Example Implementation

      defmodule ReqLLM.Providers.Example do
      use ReqLLM.Provider.DSL,
      id: :example,
      base_url: "https://api.example.com/v1",
      metadata: "priv/models_dev/example.json",
      context_wrapper: ReqLLM.Providers.Example.Context,
      response_wrapper: ReqLLM.Providers.Example.Response,
      provider_schema: [
        temperature: [type: :float, default: 0.7],
        max_tokens: [type: :pos_integer, default: 1024],
        stream: [type: :boolean, default: false],
        api_version: [type: :string, default: "2023-06-01"]
      ]

        def attach(request, %ReqLLM.Model{} = model) do
          api_key = ReqLLM.get_key(:example_api_key)

          request
          |> Req.Request.put_header("authorization", "Bearer \#{api_key}")
          |> Req.Request.put_header("content-type", "application/json")
          |> Req.Request.put_base_url(default_base_url())
          |> Req.Request.put_body(%{
            model: model.model,
            messages: format_messages(model.context),
            temperature: model.temperature
          })
        end

        def parse(response, %ReqLLM.Model{} = model) do
          case response.body do
            %{"content" => content} ->
              {:ok, content}
            %{"error" => error} ->
              {:error, ReqLLM.Error.api_error(error)}
            _ ->
              {:error, ReqLLM.Error.parse_error("Invalid response format")}
          end
        end

        # Private helper functions...
      end

  """

  require Logger

  @doc """
  Sigil for defining lists of atoms from space-separated words.

  ## Examples

      ~a[temperature max_tokens top_p]  # => [:temperature, :max_tokens, :top_p]
  """
  defmacro __using__(opts) do
    # Support both old format (id: + metadata:) and new format (ids: [...])
    provider_ids =
      case {Keyword.get(opts, :ids), Keyword.get(opts, :id), Keyword.get(opts, :metadata)} do
        {ids, nil, nil} when is_list(ids) ->
          # New format: ids: [{:provider_id1, "path1.json"}, {:provider_id2, "path2.json"}]
          Enum.map(ids, fn
            {id, metadata_path} when is_atom(id) and is_binary(metadata_path) ->
              {id, metadata_path}

            other ->
              raise ArgumentError,
                    "Provider :ids must be a list of {id, metadata_path} tuples, got: #{inspect(other)}"
          end)

        {nil, id, metadata_path} when is_atom(id) ->
          # Old format (backwards compat): id: :provider_id, metadata: "path.json"
          [{id, metadata_path}]

        {nil, nil, _} ->
          raise ArgumentError, "Provider must specify either :id or :ids"

        _ ->
          raise ArgumentError,
                "Provider cannot specify both :id and :ids - use one or the other"
      end

    base_url = Keyword.fetch!(opts, :base_url)
    provider_schema = Keyword.get(opts, :provider_schema, [])
    default_env_key = Keyword.get(opts, :default_env_key)
    context_wrapper = Keyword.get(opts, :context_wrapper)
    response_wrapper = Keyword.get(opts, :response_wrapper)

    # Validate base_url
    if !is_binary(base_url) do
      raise ArgumentError, "Provider :base_url must be a string, got: #{inspect(base_url)}"
    end

    if default_env_key && !is_binary(default_env_key) do
      raise ArgumentError,
            "Provider :default_env_key must be a string, got: #{inspect(default_env_key)}"
    end

    # Store first provider ID for backwards compat (provider_id/0 function)
    [{primary_id, primary_metadata_path} | _] = provider_ids

    quote do
      use ReqLLM.Provider.Defaults

      @provider_ids unquote(provider_ids)
      @provider_id unquote(primary_id)
      @base_url unquote(base_url)
      @metadata_path unquote(primary_metadata_path)
      @provider_schema_opts unquote(provider_schema)
      @default_env_key unquote(default_env_key)
      @context_wrapper unquote(context_wrapper)
      @response_wrapper unquote(response_wrapper)

      # Mark all metadata files as external resources
      for {_id, metadata_path} <- @provider_ids, metadata_path do
        @external_resource metadata_path
      end

      @before_compile ReqLLM.Provider.DSL

      def default_base_url do
        @base_url
      end

      defoverridable default_base_url: 0
    end
  end

  defmacro __before_compile__(env) do
    # Get the compiled module's attributes
    provider_ids = Module.get_attribute(env.module, :provider_ids)
    provider_id = Module.get_attribute(env.module, :provider_id)
    metadata_path = Module.get_attribute(env.module, :metadata_path)
    provider_schema_opts = Module.get_attribute(env.module, :provider_schema_opts)
    default_env_key = Module.get_attribute(env.module, :default_env_key)
    context_wrapper = Module.get_attribute(env.module, :context_wrapper)
    response_wrapper = Module.get_attribute(env.module, :response_wrapper)

    # Load metadata for ALL provider IDs
    all_provider_metadata =
      Enum.map(provider_ids, fn {id, path} ->
        {id, load_metadata(path)}
      end)

    # Primary metadata (backwards compat)
    metadata = load_metadata(metadata_path)

    # Build provider schema and extended generation schema
    provider_schema_definition = build_provider_schema(provider_schema_opts)
    extended_schema_definition = build_extended_generation_schema(provider_schema_opts)

    quote do
      # Store metadata as module attribute
      @req_llm_metadata unquote(Macro.escape(metadata))
      @req_llm_all_provider_metadata unquote(Macro.escape(all_provider_metadata))

      # Build the provider schema at compile time
      @provider_schema unquote(provider_schema_definition)

      # Build the extended generation schema (base + provider options)
      @extended_generation_schema unquote(extended_schema_definition)

      # Optional helpers for accessing provider info
      def metadata, do: @req_llm_metadata
      def provider_id, do: unquote(provider_id)

      # New function for multi-provider support
      def provider_ids, do: @req_llm_all_provider_metadata

      # Provider option helpers
      def supported_provider_options do
        # Return keys from the merged schema
        @extended_generation_schema.schema |> Keyword.keys()
      end

      def default_provider_opts do
        @provider_schema.schema
        |> Enum.filter(fn {_key, opts} -> Keyword.has_key?(opts, :default) end)
        |> Enum.map(fn {key, opts} -> {key, opts[:default]} end)
      end

      def provider_schema, do: @provider_schema

      def provider_extended_generation_schema, do: @extended_generation_schema

      # Translation helper functions available to all providers
      @doc false
      def validate_mutex!(opts, keys, msg) when is_list(keys) do
        present = Enum.filter(keys, &Keyword.has_key?(opts, &1))

        if length(present) > 1 do
          raise ReqLLM.Error.Invalid.Parameter.exception(parameter: msg)
        end

        :ok
      end

      @doc false
      def translate_rename(opts, from, to) when is_atom(from) and is_atom(to) do
        validate_mutex!(opts, [from, to], "#{from} and #{to} cannot be used together")

        case Keyword.pop(opts, from) do
          {nil, opts} -> {opts, []}
          {value, opts} -> {Keyword.put(opts, to, value), []}
        end
      end

      @doc false
      def translate_drop(opts, key, msg \\ nil) do
        {value, opts} = Keyword.pop(opts, key)
        warnings = if value != nil && msg, do: [msg], else: []
        {opts, warnings}
      end

      @doc false
      def translate_combine_warnings(results) do
        {final_opts, all_warnings} =
          Enum.reduce(results, {[], []}, fn {opts, warnings}, {acc_opts, acc_warns} ->
            {Keyword.merge(acc_opts, opts), acc_warns ++ warnings}
          end)

        {final_opts, all_warnings}
      end

      # Generate default_env_key callback if provided
      unquote(
        if default_env_key do
          quote do
            def default_env_key, do: unquote(default_env_key)
          end
        end
      )

      # Generate wrap_context callback if wrapper is provided
      unquote(
        if context_wrapper do
          quote do
            @doc false
            def wrap_context(%ReqLLM.Context{} = ctx) do
              struct!(unquote(context_wrapper), context: ctx)
            end
          end
        end
      )

      # Generate wrap_response callback if wrapper is provided
      unquote(
        if response_wrapper do
          quote do
            # 1. Avoid double wrapping (can happen in tests)
            @doc false
            def wrap_response(%unquote(response_wrapper){} = already_wrapped), do: already_wrapped

            # 2. Wrap everything (including streams) in provider-specific struct
            @doc false
            def wrap_response(data), do: struct!(unquote(response_wrapper), payload: data)
          end
        end
      )
    end
  end

  # Private helper to build provider schema from options
  defp build_provider_schema([]) do
    # Return empty schema - providers must explicitly declare what they support
    quote do
      NimbleOptions.new!([])
    end
  end

  defp build_provider_schema(schema_opts) when is_list(schema_opts) do
    # Validate that provider schema keys don't overlap with core generation schema
    validate_schema_keys(schema_opts)

    # Build schema directly from provider-specific options
    quote do
      NimbleOptions.new!(unquote(schema_opts))
    end
  end

  # Private helper to build extended generation schema (base + provider options)
  defp build_extended_generation_schema(provider_schema_opts) do
    quote do
      # Get the base generation schema and merge with provider-specific options
      base_schema = ReqLLM.Provider.Options.generation_schema().schema
      provider_options = unquote(provider_schema_opts)

      # Merge the schemas - provider options extend base options
      merged_schema = Keyword.merge(base_schema, provider_options)
      NimbleOptions.new!(merged_schema)
    end
  end

  # Compile-time validation that provider schema keys don't overlap with core options
  defp validate_schema_keys(schema_opts) do
    core_keys = ReqLLM.Provider.Options.generation_schema().schema |> Keyword.keys()

    Enum.each(schema_opts, fn {key, _opts} ->
      if key in core_keys do
        IO.warn(
          "Provider schema key #{inspect(key)} conflicts with core generation option. " <>
            "This will be an error in a future version. " <>
            "Consider using a provider-specific name to avoid conflicts."
        )
      end
    end)
  end

  # Private helper to load metadata at compile time
  defp load_metadata(nil), do: %{}

  defp load_metadata(path) when is_binary(path) do
    full_path = Path.expand(path)

    if File.exists?(full_path) do
      case File.read(full_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, data} ->
              # Convert string keys to atom keys for easier access
              atomize_keys(data)

            {:error, error} ->
              Logger.warning("Failed to parse JSON metadata from #{path}: #{inspect(error)}")
              %{}
          end

        {:error, error} ->
          Logger.warning("Failed to read metadata file #{path}: #{inspect(error)}")
          %{}
      end
    else
      Logger.warning("Metadata file not found: #{path}")
      %{}
    end
  end

  # Helper to recursively convert string keys to atoms (for known keys only)
  defp atomize_keys(data) when is_map(data) do
    data
    |> Map.new(fn
      {"models", value} -> {:models, atomize_keys(value)}
      {"capabilities", value} -> {:capabilities, value}
      {"pricing", value} -> {:pricing, atomize_keys(value)}
      {"context_length", value} -> {:context_length, value}
      {"id", value} -> {:id, value}
      {"input", value} -> {:input, value}
      {"output", value} -> {:output, value}
      {key, value} -> {key, atomize_keys(value)}
    end)
  end

  defp atomize_keys(data) when is_list(data) do
    Enum.map(data, &atomize_keys/1)
  end

  defp atomize_keys(data), do: data
end
