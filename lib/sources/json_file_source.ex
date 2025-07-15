defmodule AshImport.Sources.JsonFileSource do
  @moduledoc """
  JSON file source implementation.

  Supports configuration options:
  - file_path: Path to the JSON file (required)
  - root_path: JSONPath to the array of records (e.g., "data.items")
  - encoding: File encoding (default: "utf-8")
  """

  @behaviour AshImport.Sources.Source

  require Logger

  @impl AshImport.Sources.Source
  def preview(source_config) do
    file_path = Map.fetch!(source_config, :file_path)

    case validate_and_read_file(file_path) do
      {:ok, content} ->
        do_preview(content, source_config)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl AshImport.Sources.Source
  def stream(source_config) do
    file_path = Map.fetch!(source_config, :file_path)
    root_path = Map.get(source_config, :root_path)

    case validate_and_read_file(file_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} ->
            build_record_stream(data, root_path)

          {:error, reason} ->
            {:error, "JSON decode error: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_and_read_file(file_path) do
    case File.stat(file_path) do
      {:ok, %{size: 0}} ->
        {:error, "File is empty"}

      {:ok, %{size: _}} ->
        File.read(file_path)

      {:error, :enoent} ->
        {:error, "File not found: #{file_path}"}

      {:error, reason} ->
        {:error, "File access error: #{inspect(reason)}"}
    end
  end

  defp do_preview(content, source_config) do
    root_path = Map.get(source_config, :root_path)

    case Jason.decode(content) do
      {:ok, data} ->
        preview_json_data(data, root_path)

      {:error, reason} ->
        {:error, "JSON decode error: #{inspect(reason)}"}
    end
  end

  defp preview_json_data(data, root_path) do
    case extract_array(data, root_path) do
      {:ok, array} when is_list(array) ->
        total_records = length(array)
        sample_records = Enum.take(array, 5)

        # Extract column names from first record
        column_names =
          case List.first(array) do
            nil -> []
            first when is_map(first) -> Map.keys(first) |> Enum.sort()
            _ -> []
          end

        {:ok,
         %{
           total_records: total_records,
           estimated_records: total_records,
           sample: sample_records,
           column_names: column_names,
           source_config_overrides: %{}
         }}

      {:ok, single_item} when is_map(single_item) ->
        # Handle single object
        column_names = Map.keys(single_item) |> Enum.sort()

        {:ok,
         %{
           total_records: 1,
           estimated_records: 1,
           sample: [single_item],
           column_names: column_names,
           source_config_overrides: %{}
         }}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "Invalid JSON structure: expected array or object"}
    end
  end

  defp build_record_stream(data, root_path) do
    case extract_array(data, root_path) do
      {:ok, array} when is_list(array) ->
        stream =
          array
          |> Stream.with_index(1)
          |> Stream.map(fn {item, row_num} -> {row_num, item} end)

        {:ok, stream}

      {:ok, single_item} when is_map(single_item) ->
        # Single object becomes a stream of one item
        {:ok, Stream.map([{1, single_item}], & &1)}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, "Invalid JSON structure for streaming"}
    end
  end

  defp extract_array(data, nil), do: {:ok, data}

  defp extract_array(data, root_path) when is_binary(root_path) do
    path_parts = String.split(root_path, ".")

    result =
      Enum.reduce_while(path_parts, data, fn key, acc ->
        case acc do
          map when is_map(map) ->
            case Map.get(map, key) do
              nil -> {:halt, {:error, "Key '#{key}' not found in JSON path: #{root_path}"}}
              value -> {:cont, value}
            end

          _ ->
            {:halt, {:error, "Invalid JSON path: #{root_path}"}}
        end
      end)

    case result do
      {:error, _} = error -> error
      value -> {:ok, value}
    end
  end
end
