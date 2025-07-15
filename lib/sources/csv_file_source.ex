defmodule AshImport.Sources.CsvFileSource do
  @moduledoc """
  CSV file source implementation.

  Supports configuration options:
  - file_path: Path to the CSV file (required)
  - delimiter: CSV delimiter character (auto-detected if not provided)
  - has_headers?: Whether the CSV has a header row (default: true)
  - skip_rows: Number of rows to skip at the beginning (default: 0)
  - encoding: File encoding (default: "utf-8")
  """

  @behaviour AshImport.Sources.Source

  require Logger

  @impl AshImport.Sources.Source
  def preview(source_config) do
    file_path = Map.fetch!(source_config, :file_path)

    case validate_file(file_path) do
      :ok ->
        do_preview(file_path, source_config)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl AshImport.Sources.Source
  def stream(source_config) do
    file_path = Map.fetch!(source_config, :file_path)
    delimiter = get_delimiter(source_config)
    has_headers? = Map.get(source_config, :has_headers?, true)
    skip_rows = Map.get(source_config, :skip_rows, 0)

    try do
      stream = build_record_stream(file_path, delimiter, has_headers?, skip_rows)
      {:ok, stream}
    rescue
      error ->
        {:error, "Failed to create CSV stream: #{inspect(error)}"}
    end
  end

  defp validate_file(file_path) do
    case File.stat(file_path) do
      {:ok, %{size: 0}} ->
        {:error, "File is empty"}

      {:ok, %{size: _}} ->
        :ok

      {:error, :enoent} ->
        {:error, "File not found: #{file_path}"}

      {:error, reason} ->
        {:error, "File access error: #{inspect(reason)}"}
    end
  end

  defp do_preview(file_path, source_config) do
    has_headers? = Map.get(source_config, :has_headers?, true)
    skip_rows = Map.get(source_config, :skip_rows, 0)
    configured_delimiter = Map.get(source_config, :delimiter)

    # Read first line to detect delimiter if needed
    first_line =
      file_path
      |> File.stream!()
      |> Stream.drop(skip_rows)
      |> Enum.take(1)
      |> List.first()

    case first_line do
      nil ->
        {:ok,
         %{
           total_records: 0,
           estimated_records: 0,
           sample: [],
           column_names: [],
           source_config_overrides: %{}
         }}

      line ->
        # Always detect the actual delimiter from the file
        detected_delimiter = detect_delimiter(String.trim(line))

        # Use configured delimiter if provided, otherwise use detected delimiter
        delimiter = configured_delimiter || detected_delimiter
        delimiter_codepoint = string_to_codepoint(delimiter)

        # Scan through the full file
        {total_records, estimated_records, sample_records, column_names} =
          preview_csv(file_path, delimiter_codepoint, has_headers?, skip_rows)

        source_config_overrides =
          if configured_delimiter do
            %{detected_delimiter: detected_delimiter}
          else
            %{delimiter: delimiter, detected_delimiter: detected_delimiter}
          end

        {:ok,
         %{
           total_records: total_records,
           estimated_records: estimated_records,
           sample: sample_records,
           column_names: column_names,
           source_config_overrides: source_config_overrides
         }}
    end
  end

  defp preview_csv(file_path, delimiter, has_headers?, skip_rows) do
    sample_size = 5

    stream =
      file_path
      |> File.stream!()
      |> Stream.drop(skip_rows)
      |> CSV.decode(separator: delimiter)

    # Get headers and column names
    {header_fields, data_stream, column_names} =
      if has_headers? do
        case Enum.take(stream, 1) do
          [{:ok, fields}] ->
            {fields, Stream.drop(stream, 1), fields}

          _ ->
            {[], stream, []}
        end
      else
        # For CSV without headers, peek at first row to determine column count
        case Enum.take(stream, 1) do
          [{:ok, fields}] ->
            cols = Enum.with_index(fields) |> Enum.map(fn {_, idx} -> "column_#{idx}" end)
            {[], stream, cols}

          _ ->
            {[], stream, []}
        end
      end

    # Process records and collect sample
    {total_count, success_count, _failed_count, sample_records} =
      data_stream
      |> Stream.with_index()
      |> Enum.reduce({0, 0, 0, []}, fn
        {{:ok, fields}, _index}, {total, success, failed, samples} ->
          # Create record map
          record =
            if has_headers? and not Enum.empty?(header_fields) do
              Enum.zip(header_fields, fields) |> Enum.into(%{})
            else
              Enum.zip(column_names, fields) |> Enum.into(%{})
            end

          new_samples =
            if length(samples) < sample_size do
              [record | samples]
            else
              samples
            end

          {total + 1, success + 1, failed, new_samples}

        {{:error, _reason}, _index}, {total, success, failed, samples} ->
          {total + 1, success, failed + 1, samples}
      end)

    {total_count, success_count, Enum.reverse(sample_records), column_names}
  end

  defp build_record_stream(file_path, delimiter, has_headers?, skip_rows) do
    delimiter_codepoint = string_to_codepoint(delimiter)

    base_stream =
      file_path
      |> File.stream!()
      |> Stream.drop(skip_rows)
      |> CSV.decode(separator: delimiter_codepoint)

    if has_headers? do
      # Extract headers and build records with header keys
      [{:ok, headers} | data_stream] = Enum.to_list(base_stream)

      data_stream
      |> Stream.with_index(1)
      |> Stream.map(fn
        {{:ok, values}, row_num} ->
          data = Enum.zip(headers, values) |> Enum.into(%{})
          {row_num, data}

        {{:error, reason}, row_num} ->
          Logger.warning("Failed to parse CSV row #{row_num}: #{inspect(reason)}")
          {row_num, %{}}
      end)
    else
      # No headers - use column indices
      base_stream
      |> Stream.with_index(1)
      |> Stream.map(fn
        {{:ok, values}, row_num} ->
          data =
            values
            |> Enum.with_index()
            |> Enum.into(%{}, fn {value, idx} -> {"column_#{idx}", value} end)

          {row_num, data}

        {{:error, reason}, row_num} ->
          Logger.warning("Failed to parse CSV row #{row_num}: #{inspect(reason)}")
          {row_num, %{}}
      end)
    end
  end

  defp detect_delimiter(line) do
    delimiters = [",", ";", "\t", "|"]

    counts =
      Enum.map(delimiters, fn delimiter ->
        {delimiter, String.graphemes(line) |> Enum.count(&(&1 == delimiter))}
      end)

    {delimiter, _count} = Enum.max_by(counts, fn {_delim, count} -> count end)

    if String.contains?(line, delimiter) do
      delimiter
    else
      ","
    end
  end

  defp get_delimiter(source_config) do
    Map.get(source_config, :delimiter, ",")
  end

  defp string_to_codepoint(delimiter) do
    case delimiter do
      "," -> ?,
      ";" -> ?;
      "\t" -> ?\t
      "|" -> ?|
      <<codepoint::utf8>> -> codepoint
      _ -> ?,
    end
  end
end
