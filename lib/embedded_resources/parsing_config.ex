defmodule AshImport.EmbeddedResources.ParsingConfig do
  @moduledoc """
  Union type for parsing configuration that can be either CSV or JSON parsing config.
  """
  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        csv: [
          type: AshImport.EmbeddedResources.CsvParsingConfig,
          tag: :type,
          tag_value: :csv
        ],
        json: [
          type: AshImport.EmbeddedResources.JsonParsingConfig,
          tag: :type,
          tag_value: :json
        ]
      ]
    ]

  def cast_input(value, constraints) do
    case value do
      %{type: :csv} ->
        {:ok, value}

      %{type: :json} ->
        {:ok, value}

      # Auto-detect based on content structure
      %{detected_delimiter: _} = csv_config ->
        {:ok, Map.put(csv_config, :type, :csv)}

      %{json_root_path: _} = json_config ->
        {:ok, Map.put(json_config, :type, :json)}

      # Default to CSV if ambiguous
      config when is_map(config) ->
        {:ok, Map.put(config, :type, :csv)}

      _ ->
        super(value, constraints)
    end
  end

  def cast_stored(value, constraints) do
    case value do
      %{"type" => "csv"} = stored_value ->
        csv_config = Map.drop(stored_value, ["type"])
        {:ok, %{type: :csv, config: csv_config}}

      %{"type" => "json"} = stored_value ->
        json_config = Map.drop(stored_value, ["type"])
        {:ok, %{type: :json, config: json_config}}

      _ ->
        super(value, constraints)
    end
  end

  def dump_to_native(value, constraints) do
    case value do
      %{type: type, config: config} ->
        {:ok, Map.put(config, "type", to_string(type))}

      %{type: type} = full_config ->
        config_without_type = Map.drop(full_config, [:type])
        {:ok, Map.put(config_without_type, "type", to_string(type))}

      _ ->
        super(value, constraints)
    end
  end
end
