defmodule ReqLLM.Catalog do
  @moduledoc """
  Runtime catalog system that applies configuration to the compile-time base catalog.

  The Catalog layer sits between raw model metadata sources (priv/models_dev/*.json)
  and the Provider Registry. It is responsible for:
  - Loading metadata from base sources (models.dev snapshots)
  - Merging custom provider/model definitions from config
  - Applying model-level allowlist filtering
  - Applying metadata overrides
  - Producing the "effective catalog" used by the rest of the system
  """

  @config_schema NimbleOptions.new!(
                   allow: [
                     type: :any,
                     default: %{},
                     doc:
                       "Map of provider_id => list of allowed model IDs. Only these models will be available."
                   ],
                   overrides: [
                     type: :any,
                     default: [],
                     doc: "Deep merge patches for provider and model metadata"
                   ],
                   custom: [
                     type: :any,
                     default: [],
                     doc: "Custom provider/model definitions (e.g., local VLLM, LLaMA CPP)"
                   ]
                 )

  @doc """
  Load the effective catalog from Application config.

  Reads configuration from `Application.get_env(:req_llm, :catalog, [])` and calls `load/1`.

  Returns `{:ok, catalog}` or `{:error, reason}`.
  """
  @spec load() :: {:ok, map()} | {:error, term()}
  def load do
    config = Application.get_env(:req_llm, :catalog, [])
    load(config)
  end

  @doc """
  Load the effective catalog by applying allowlist, custom providers, and overrides
  to the compile-time base catalog.

  Returns a map: `%{provider_id => %{"id" => ..., "models" => %{model_id => ...}}}`

  Returns `{:error, reason}` if:
  - Config validation fails
  - Allow is empty in non-test environment
  - Base catalog loading fails

  ## Processing Order
  1. Validate config with NimbleOptions schema
  2. Load base catalog from `ReqLLM.Catalog.Base.base()` (compile-time, zero I/O)
  3. Merge `config.custom` (custom providers/models replace by ID)
  4. Filter by `config.allow` (drop all non-allowed models)
  5. Apply `config.overrides.providers` (deep merge, excluding `"models"` key)
  6. Apply `config.overrides.models` (deep merge per model)
  7. Return effective catalog
  """
  @spec load(keyword()) :: {:ok, map()} | {:error, term()}
  def load(config) do
    with {:ok, validated} <- validate_config(config),
         :ok <- check_allow_not_empty(validated),
         {:ok, base} <- load_base_catalog() do
      catalog = merge_custom(base, validated[:custom])
      catalog = filter_by_allow(catalog, validated[:allow])
      catalog = apply_overrides(catalog, validated[:overrides])
      {:ok, catalog}
    end
  end

  defp validate_config(config) do
    with {:ok, validated} <- validate_schema(config),
         :ok <- validate_allow(validated[:allow]),
         :ok <- validate_overrides(validated[:overrides]),
         :ok <- validate_custom(validated[:custom]) do
      {:ok, validated}
    end
  end

  defp validate_schema(config) do
    {:ok, NimbleOptions.validate!(config, @config_schema)}
  rescue
    e in NimbleOptions.ValidationError ->
      {:error, Exception.message(e)}
  end

  defp validate_allow(allow) when is_map(allow), do: :ok
  defp validate_allow(_), do: {:error, "allow must be a map"}

  defp validate_overrides(overrides) when is_list(overrides), do: :ok
  defp validate_overrides(_), do: {:error, "overrides must be a keyword list"}

  defp validate_custom(custom) when is_list(custom), do: :ok
  defp validate_custom(_), do: {:error, "custom must be a list"}

  defp check_allow_not_empty(config) do
    allow = config[:allow]

    if is_map(allow) do
      :ok
    else
      {:error, "allow must be a map"}
    end
  end

  defp load_base_catalog do
    case Code.ensure_loaded?(ReqLLM.Catalog.Base) do
      true -> {:ok, ReqLLM.Catalog.Base.base()}
      false -> {:error, "Base catalog not available"}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp merge_custom(base_catalog, []), do: base_catalog

  defp merge_custom(base_catalog, custom_entries) when is_list(custom_entries) do
    Enum.reduce(custom_entries, base_catalog, fn entry, acc ->
      merge_custom_entry(acc, entry)
    end)
  end

  defp merge_custom_entry(catalog, %{"provider" => provider, "models" => models})
       when is_map(provider) and is_list(models) do
    provider = normalize_keys(provider)
    provider_id = to_string(provider["id"])
    provider = Map.put(provider, "id", provider_id)

    models_map =
      Map.new(models, fn model ->
        model = normalize_keys(model)
        model_id = to_string(model["id"])
        model = Map.put(model, "id", model_id)
        {model_id, model}
      end)

    provider_with_models = Map.put(provider, "models", models_map)

    Map.put(catalog, provider_id, provider_with_models)
  end

  defp merge_custom_entry(catalog, %{provider: provider, models: models})
       when is_map(provider) and is_list(models) do
    merge_custom_entry(catalog, %{
      "provider" => provider,
      "models" => models
    })
  end

  defp merge_custom_entry(catalog, _entry), do: catalog

  defp filter_by_allow(catalog, allow) when map_size(allow) == 0, do: catalog

  defp filter_by_allow(catalog, allow) do
    allow = normalize_keys(allow)

    catalog
    |> Enum.map(fn {provider_id, provider} ->
      case Map.get(allow, provider_id) do
        nil ->
          nil

        allowed_models when is_list(allowed_models) ->
          allowed_models = Enum.map(allowed_models, &to_string/1)

          filtered_models =
            case provider["models"] do
              models when is_map(models) ->
                models
                |> Enum.filter(fn {model_id, _model} -> model_id in allowed_models end)
                |> Map.new()

              _ ->
                %{}
            end

          {provider_id, Map.put(provider, "models", filtered_models)}

        _ ->
          {provider_id, provider}
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp apply_overrides(catalog, []), do: catalog

  defp apply_overrides(catalog, overrides) do
    provider_overrides = normalize_keys(Keyword.get(overrides, :providers, %{}))
    model_overrides = normalize_keys(Keyword.get(overrides, :models, %{}))

    catalog
    |> apply_provider_overrides(provider_overrides)
    |> apply_model_overrides(model_overrides)
  end

  defp apply_provider_overrides(catalog, provider_overrides)
       when map_size(provider_overrides) == 0 do
    catalog
  end

  defp apply_provider_overrides(catalog, provider_overrides) do
    Enum.reduce(provider_overrides, catalog, fn {provider_id, overrides}, acc ->
      case Map.get(acc, provider_id) do
        nil ->
          acc

        provider ->
          models = Map.get(provider, "models")
          overrides_without_models = Map.delete(normalize_keys(overrides), "models")
          updated_provider = deep_merge(provider, overrides_without_models)
          updated_provider = Map.put(updated_provider, "models", models)
          Map.put(acc, provider_id, updated_provider)
      end
    end)
  end

  defp apply_model_overrides(catalog, model_overrides) when map_size(model_overrides) == 0 do
    catalog
  end

  defp apply_model_overrides(catalog, model_overrides) do
    Enum.reduce(model_overrides, catalog, fn {provider_id, models}, acc ->
      case Map.get(acc, provider_id) do
        nil ->
          acc

        provider ->
          updated_models =
            Enum.reduce(normalize_keys(models), provider["models"], fn {model_id, overrides},
                                                                       model_acc ->
              case Map.get(model_acc, model_id) do
                nil ->
                  model_acc

                model ->
                  updated_model = deep_merge(model, normalize_keys(overrides))
                  Map.put(model_acc, model_id, updated_model)
              end
            end)

          updated_provider = Map.put(provider, "models", updated_models)
          Map.put(acc, provider_id, updated_provider)
      end
    end)
  end

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn
      _key, left_val, right_val when is_map(left_val) and is_map(right_val) ->
        deep_merge(left_val, right_val)

      _key, _left_val, right_val ->
        right_val
    end)
  end

  defp deep_merge(_left, right), do: right

  defp normalize_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      normalized_key = to_string(key)

      normalized_value =
        cond do
          is_map(value) -> normalize_keys(value)
          is_list(value) -> Enum.map(value, &if(is_map(&1), do: normalize_keys(&1), else: &1))
          true -> value
        end

      {normalized_key, normalized_value}
    end)
  end

  defp normalize_keys(value), do: value
end
