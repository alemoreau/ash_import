defmodule AshImport.Sources.CsvFileSourceTest do
  @moduledoc """
  Tests for the CsvFileSource implementation.
  """
  use ExUnit.Case, async: false

  alias AshImport.Sources.CsvFileSource

  setup_all do
    %{
      products_csv_path: "test/support/products.csv",
      products_without_header_csv_path: "test/support/products_without_header.csv",
      headers_only_csv_path: "test/support/headers_only.csv",
      large_products_csv_path: "test/support/large_products.csv",
      empty_csv_path: "test/support/empty.csv"
    }
  end

  describe "preview/1" do
    test "previews CSV file with headers correctly", %{products_csv_path: filepath} do
      source_config = %{
        file_path: filepath,
        has_headers?: true
      }

      {:ok, result} = CsvFileSource.preview(source_config)

      assert result.total_records == 3
      assert result.estimated_records == 3
      assert result.column_names == ["name", "description", "price"]
      assert length(result.sample) == 3
      assert Map.has_key?(result.source_config_overrides, :delimiter)
      assert result.source_config_overrides.delimiter == ","
    end

    test "previews CSV file without headers correctly", %{
      products_without_header_csv_path: filepath
    } do
      source_config = %{
        file_path: filepath,
        has_headers?: false
      }

      {:ok, result} = CsvFileSource.preview(source_config)

      assert result.total_records == 3
      assert result.estimated_records == 3
      assert result.column_names == ["column_0", "column_1", "column_2"]
      assert length(result.sample) == 3

      # Check sample structure
      first_sample = List.first(result.sample)
      assert first_sample["column_0"] == "1"
      assert first_sample["column_1"] == "Product 1"
      assert first_sample["column_2"] == "19.99"
    end

    test "previews CSV with only headers", %{headers_only_csv_path: filepath} do
      source_config = %{
        file_path: filepath,
        has_headers?: true
      }

      {:ok, result} = CsvFileSource.preview(source_config)

      assert result.total_records == 0
      assert result.estimated_records == 0
      assert result.column_names == ["name", "price", "category"]
      assert result.sample == []
    end

    test "limits sample size for large files", %{large_products_csv_path: filepath} do
      source_config = %{
        file_path: filepath,
        has_headers?: true
      }

      {:ok, result} = CsvFileSource.preview(source_config)

      assert result.total_records == 7
      assert result.estimated_records == 7
      # Limited to 5 samples
      assert length(result.sample) == 5

      # Verify first few samples
      sample_names = Enum.map(result.sample, & &1["name"])
      assert sample_names == ["Product 1", "Product 2", "Product 3", "Product 4", "Product 5"]
    end

    test "detects delimiter when not specified", %{products_csv_path: filepath} do
      source_config = %{
        file_path: filepath,
        has_headers?: true
      }

      {:ok, result} = CsvFileSource.preview(source_config)

      assert result.source_config_overrides.delimiter == ","
    end

    test "uses specified delimiter when provided", %{products_csv_path: filepath} do
      source_config = %{
        file_path: filepath,
        has_headers?: true,
        delimiter: ";"
      }

      {:ok, result} = CsvFileSource.preview(source_config)
    end

    test "handles skip_rows configuration", %{products_csv_path: filepath} do
      source_config = %{
        file_path: filepath,
        has_headers?: true,
        skip_rows: 1
      }

      {:ok, result} = CsvFileSource.preview(source_config)

      # Should skip 1 row, then treat next row as header, leaving 2 data rows
      assert result.total_records == 2
      assert result.estimated_records == 2
    end

    test "returns error for non-existent file" do
      source_config = %{
        file_path: "/nonexistent/file.csv",
        has_headers?: true
      }

      {:error, message} = CsvFileSource.preview(source_config)

      assert message =~ "File not found"
    end

    test "returns error for empty file", %{empty_csv_path: filepath} do
      source_config = %{
        file_path: filepath,
        has_headers?: true
      }

      {:error, message} = CsvFileSource.preview(source_config)

      assert message == "File is empty"
    end
  end

  describe "stream/1" do
    test "streams CSV file with headers", %{products_csv_path: filepath} do
      source_config = %{
        file_path: filepath,
        has_headers?: true,
        delimiter: ","
      }

      {:ok, stream} = CsvFileSource.stream(source_config)

      records = Enum.to_list(stream)

      assert length(records) == 3

      # Check first record
      {row_num, data} = List.first(records)
      assert row_num == 1
      assert data["name"] == "1"
      assert data["description"] == "Product 1"
      assert data["price"] == "19.99"

      # Check last record
      {row_num, data} = List.last(records)
      assert row_num == 3
      assert data["name"] == "3"
      assert data["description"] == "Product 3"
      assert data["price"] == "39.99"
    end

    test "streams CSV file without headers", %{products_without_header_csv_path: filepath} do
      source_config = %{
        file_path: filepath,
        has_headers?: false,
        delimiter: ","
      }

      {:ok, stream} = CsvFileSource.stream(source_config)

      records = Enum.to_list(stream)

      assert length(records) == 3

      # Check first record
      {row_num, data} = List.first(records)
      assert row_num == 1
      assert data["column_0"] == "1"
      assert data["column_1"] == "Product 1"
      assert data["column_2"] == "19.99"
    end

    test "handles skip_rows in streaming", %{products_csv_path: filepath} do
      source_config = %{
        file_path: filepath,
        has_headers?: true,
        delimiter: ",",
        skip_rows: 1
      }

      {:ok, stream} = CsvFileSource.stream(source_config)

      records = Enum.to_list(stream)

      # Should skip 1 row, then use next as header, leaving 2 data records
      assert length(records) == 2
    end

    test "returns error for non-existent file" do
      source_config = %{
        file_path: "/nonexistent/file.csv",
        has_headers?: true,
        delimiter: ","
      }

      {:error, message} = CsvFileSource.stream(source_config)

      assert message =~ "Failed to create CSV stream"
    end
  end
end
