defmodule AshImport.Sources.Source do
  @moduledoc """
  Behaviour for implementing data sources for import jobs.

  A source is responsible for:
  - Previewing a file to extract metadata (total records, sample data, column names)
  - Streaming records from the file for processing
  """

  @type source_config :: map()

  @type preview_result :: %{
          total_records: non_neg_integer(),
          estimated_records: non_neg_integer(),
          sample: list(map()),
          column_names: list(String.t()),
          source_config_overrides: map()
        }

  @type record :: {row_number :: non_neg_integer(), data :: map()}

  @doc """
  Preview the source to extract metadata.

  Returns:
  - total_records: The total number of records in the source
  - estimated_records: The number of records that can be successfully parsed
  - sample: A sample of records (typically first 5) for preview
  - column_names: List of column names detected or generated
  - source_config_overrides: Any configuration overrides suggested during preview
  """
  @callback preview(source_config()) :: {:ok, preview_result()} | {:error, String.t()}

  @doc """
  Streams records from the source.

  Returns a stream of {row_number, data} tuples where:
  - row_number: The record's position in the source (1-indexed)
  - data: A map of column_name => value
  """
  @callback stream(source_config()) :: {:ok, Enumerable.t()} | {:error, String.t()}
end
