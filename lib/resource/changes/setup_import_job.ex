defmodule AshImport.Resource.Changes.SetupImportJob do
  @moduledoc """
  Sets up the initial import job configuration and analyzes the file
  to suggest initial mappings.
  """
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    initial_mappings = Ash.Changeset.get_argument(changeset, :initial_mappings) || []
    file_path = Ash.Changeset.get_attribute(changeset, :file_path)
    # file_type = Ash.Changeset.get_attribute(changeset, :file_type)
    file_type = detect_file_type(file_path)

    # Set up default import config if not provided
    changeset = ensure_import_config(changeset)

    # If initial mappings provided, convert and set them
    if initial_mappings != [] do
      case convert_initial_mappings(changeset, initial_mappings) do
        {:ok, argument_mappings} ->
          Ash.Changeset.change_attribute(changeset, :argument_mappings, argument_mappings)

        {:error, message} ->
          Ash.Changeset.add_error(changeset, message)
      end
    else
      # Analyze file and suggest mappings
      suggest_mappings(changeset, file_path, file_type)
    end
  end

  defp ensure_import_config(changeset) do
    case Ash.Changeset.get_attribute(changeset, :import_config) do
      nil ->
        # Create default import config
        resource = changeset.resource.original_resource()
        import_config_module = Module.concat([resource, ImportConfig])

        default_config = struct(import_config_module, %{})
        Ash.Changeset.change_attribute(changeset, :import_config, default_config)

      _config ->
        changeset
    end
  end

  defp convert_initial_mappings(changeset, initial_mappings) do
    resource = changeset.resource.original_resource()
    argument_mapping_module = Module.concat([resource, ImportConfig, ArgumentMapping])

    # Get the action we'll be using for imports
    create_action = AshImport.Resource.Info.create_action(resource)
    action = Ash.Resource.Info.action(resource, create_action)

    if !action do
      {:error, "Create action #{create_action} not found on resource #{inspect(resource)}"}
    else
      available_args = get_available_arguments(action)

      converted_mappings =
        Enum.map(initial_mappings, fn mapping ->
          convert_mapping(argument_mapping_module, mapping, available_args, resource)
        end)

      case Enum.find(converted_mappings, &match?({:error, _}, &1)) do
        {:error, reason} -> {:error, reason}
        nil -> {:ok, Enum.map(converted_mappings, fn {:ok, mapping} -> mapping end)}
      end
    end
  end

  defp get_available_arguments(action) do
    attributes = action.accept |> MapSet.new()
    arguments = action.arguments |> Enum.map(& &1.name) |> MapSet.new()
    MapSet.union(attributes, arguments) |> MapSet.to_list()
  end

  defp convert_mapping(mapping_module, mapping, available_args, resource) do
    target_arg = mapping["target_argument"] || mapping[:target_argument]

    cond do
      !target_arg ->
        {:error, "Missing target_argument in mapping: #{inspect(mapping)}"}

      target_arg not in available_args ->
        {:error, "Invalid target_argument #{target_arg}. Available: #{inspect(available_args)}"}

      true ->
        case build_mapping_config(mapping, resource) do
          {:ok, config} ->
            {:ok,
             struct(mapping_module, %{
               target_argument: target_arg,
               derivation_type: config.type,
               config: config.value
             })}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp build_mapping_config(mapping, resource) do
    type = mapping["type"] || mapping[:type] || "column"

    case type do
      "static" ->
        build_static_config(mapping, resource)

      "column" ->
        build_column_config(mapping, resource)

      "columns" ->
        build_multi_column_config(mapping, resource)

      _ ->
        {:error, "Unsupported mapping type: #{type}"}
    end
  end

  defp build_static_config(mapping, resource) do
    config_module = Module.concat([resource, ImportConfig, StaticValueConfig])
    value = mapping["value"] || mapping[:value]

    {:ok,
     %{
       type: :static,
       value: struct(config_module, %{value: value})
     }}
  end

  defp build_column_config(mapping, resource) do
    config_module = Module.concat([resource, ImportConfig, ColumnValueConfig])
    column_name = mapping["column_name"] || mapping[:column_name]

    if !column_name do
      {:error, "Missing column_name for column mapping"}
    else
      {:ok,
       %{
         type: :column,
         value:
           struct(config_module, %{
             column_name: column_name,
             transformations: [],
             default_value: mapping["default_value"] || mapping[:default_value],
             required?: mapping["required?"] || mapping[:required?] || false
           })
       }}
    end
  end

  defp build_multi_column_config(mapping, resource) do
    config_module = Module.concat([resource, ImportConfig, MultiColumnConfig])
    column_names = mapping["column_names"] || mapping[:column_names]
    reducer = mapping["reducer"] || mapping[:reducer] || "concat"

    if !column_names || !is_list(column_names) do
      {:error, "Missing or invalid column_names for columns mapping"}
    else
      reducer_atom =
        case reducer do
          atom when is_atom(atom) -> atom
          string when is_binary(string) -> String.to_atom(string)
          _ -> :concat
        end

      {:ok,
       %{
         type: :columns,
         value:
           struct(config_module, %{
             column_names: column_names,
             reducer: reducer_atom,
             reducer_config: mapping["reducer_config"] || mapping[:reducer_config] || %{},
             transformations: []
           })
       }}
    end
  end

  defp suggest_mappings(changeset, file_path, file_type) do
    # For now, just return the changeset without suggestions
    # In a full implementation, this would analyze the file and suggest mappings
    IO.inspect(changeset, label: "Changeset before suggestions")
    IO.inspect(file_path, label: "File Path")
    IO.inspect(file_type, label: "File Type")

    case analyze_file_structure(file_path, file_type) do
      {:ok, suggestions} ->
        # Store suggestions in changeset context for later use
        Ash.Changeset.set_context(changeset, %{suggested_mappings: suggestions})

      {:error, _reason} ->
        # Continue without suggestions
        changeset
    end
  end

  defp detect_file_type(file_path) do
    case Path.extname(file_path) do
      ".csv" -> :csv
      ".json" -> :json
      _ -> :unknown
    end
  end

  defp analyze_file_structure(file_path, :csv) do
    try do
      # Read first few lines to get headers and sample data
      lines = File.stream!(file_path, []) |> Enum.take(3)

      case lines do
        [header_line | data_lines] ->
          headers = parse_csv_line(header_line)

          suggestions = %{
            file_type: :csv,
            headers: headers,
            sample_data: Enum.map(data_lines, &parse_csv_line/1)
          }

          {:ok, suggestions}

        [] ->
          {:error, "Empty file"}
      end
    rescue
      error ->
        {:error, "Failed to analyze CSV: #{inspect(error)}"}
    end
  end

  defp analyze_file_structure(file_path, :json) do
    try do
      case File.read(file_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, data} when is_list(data) ->
              sample = Enum.take(data, 3)
              keys = extract_json_keys(sample)

              suggestions = %{
                file_type: :json,
                keys: keys,
                sample_data: sample
              }

              {:ok, suggestions}

            {:ok, data} when is_map(data) ->
              suggestions = %{
                file_type: :json,
                keys: Map.keys(data),
                sample_data: [data]
              }

              {:ok, suggestions}

            {:error, error} ->
              {:error, "Invalid JSON: #{inspect(error)}"}
          end

        {:error, reason} ->
          {:error, "Failed to read file: #{inspect(reason)}"}
      end
    rescue
      error ->
        {:error, "Failed to analyze JSON: #{inspect(error)}"}
    end
  end

  defp parse_csv_line(line) do
    # Simple CSV parsing - for production use a proper CSV library
    line
    |> String.trim()
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.trim(&1, "\""))
  end

  defp extract_json_keys(sample_data) do
    sample_data
    |> Enum.filter(&is_map/1)
    |> Enum.flat_map(&Map.keys/1)
    |> Enum.uniq()
  end
end
