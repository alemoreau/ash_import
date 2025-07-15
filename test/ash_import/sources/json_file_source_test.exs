defmodule AshImport.Sources.JsonFileSourceTest do
  @moduledoc """
  Tests for the JsonFileSource implementation.
  """
  use ExUnit.Case, async: false

  alias AshImport.Sources.JsonFileSource

  setup_all do
    %{
      products_json_path: "test/support/products.json",
      products_nested_json_path: "test/support/products_nested.json",
      empty_json_path: "test/support/empty.json"
    }
  end

  describe "preview/1" do
    test "previews JSON array correctly", %{products_json_path: filepath} do
      source_config = %{
        file_path: filepath
      }

      {:ok, result} = JsonFileSource.preview(source_config)

      assert result.total_records == 2
      assert result.estimated_records == 2
      # Sorted alphabetically
      assert result.column_names == ["name", "price"]
      assert length(result.sample) == 2
      assert result.source_config_overrides == %{}
    end

    test "previews nested JSON with root path", %{products_nested_json_path: filepath} do
      source_config = %{
        file_path: filepath,
        root_path: "data"
      }

      {:ok, result} = JsonFileSource.preview(source_config)

      assert result.total_records == 2
      assert result.estimated_records == 2
      assert result.column_names == ["name", "price"]
      assert length(result.sample) == 2

      # Check sample content
      first_sample = List.first(result.sample)
      assert first_sample["name"] == "Product 1"
      assert first_sample["price"] == 19.99
    end

    test "handles single JSON object as array of one", %{products_json_path: filepath} do
      # Create a temporary single object JSON for testing
      single_object = %{"name" => "Single Product", "price" => 99.99}
      temp_file = "/tmp/single_product.json"
      File.write!(temp_file, Jason.encode!(single_object))

      source_config = %{
        file_path: temp_file
      }

      {:ok, result} = JsonFileSource.preview(source_config)

      assert result.total_records == 1
      assert result.estimated_records == 1
      assert result.column_names == ["name", "price"]
      assert length(result.sample) == 1

      # Check sample content
      first_sample = List.first(result.sample)
      assert first_sample["name"] == "Single Product"
      assert first_sample["price"] == 99.99

      # Cleanup
      File.rm!(temp_file)
    end

    test "returns error for non-existent file" do
      source_config = %{
        file_path: "/nonexistent/file.json"
      }

      {:error, message} = JsonFileSource.preview(source_config)

      assert message =~ "File not found"
    end

    test "returns error for empty file", %{empty_json_path: filepath} do
      source_config = %{
        file_path: filepath
      }

      {:error, message} = JsonFileSource.preview(source_config)

      assert message == "File is empty"
    end

    test "returns error for invalid JSON" do
      # Create a temporary invalid JSON file
      temp_file = "/tmp/invalid.json"
      File.write!(temp_file, "{invalid json")

      source_config = %{
        file_path: temp_file
      }

      {:error, message} = JsonFileSource.preview(source_config)

      assert message =~ "JSON decode error"

      # Cleanup
      File.rm!(temp_file)
    end

    test "returns error for invalid root path", %{products_nested_json_path: filepath} do
      source_config = %{
        file_path: filepath,
        root_path: "nonexistent.path"
      }

      {:error, message} = JsonFileSource.preview(source_config)

      assert message =~ "Key 'nonexistent' not found in JSON path"
    end

    test "limits sample size to 5 records" do
      # Create a large JSON array for testing
      large_data =
        Enum.map(1..10, fn i ->
          %{"id" => i, "name" => "Product #{i}", "price" => i * 10.0}
        end)

      temp_file = "/tmp/large_products.json"
      File.write!(temp_file, Jason.encode!(large_data))

      source_config = %{
        file_path: temp_file
      }

      {:ok, result} = JsonFileSource.preview(source_config)

      assert result.total_records == 10
      assert result.estimated_records == 10
      # Limited to 5
      assert length(result.sample) == 5

      # Check that we get the first 5 records
      sample_ids = Enum.map(result.sample, & &1["id"])
      assert sample_ids == [1, 2, 3, 4, 5]

      # Cleanup
      File.rm!(temp_file)
    end
  end

  describe "stream/1" do
    test "streams JSON array", %{products_json_path: filepath} do
      source_config = %{
        file_path: filepath
      }

      {:ok, stream} = JsonFileSource.stream(source_config)

      records = Enum.to_list(stream)

      assert length(records) == 2

      # Check first record
      {row_num, data} = List.first(records)
      assert row_num == 1
      assert data["name"] == "Product 1"
      assert data["price"] == 19.99

      # Check second record
      {row_num, data} = List.last(records)
      assert row_num == 2
      assert data["name"] == "Product 2"
      assert data["price"] == 29.99
    end

    test "streams nested JSON with root path", %{products_nested_json_path: filepath} do
      source_config = %{
        file_path: filepath,
        root_path: "data"
      }

      {:ok, stream} = JsonFileSource.stream(source_config)

      records = Enum.to_list(stream)

      assert length(records) == 2

      # Check first record
      {row_num, data} = List.first(records)
      assert row_num == 1
      assert data["name"] == "Product 1"
      assert data["price"] == 19.99
    end

    test "streams single JSON object", %{} do
      # Create a temporary single object JSON for testing
      single_object = %{"name" => "Single Product", "price" => 99.99}
      temp_file = "/tmp/single_product.json"
      File.write!(temp_file, Jason.encode!(single_object))

      source_config = %{
        file_path: temp_file
      }

      {:ok, stream} = JsonFileSource.stream(source_config)

      records = Enum.to_list(stream)

      assert length(records) == 1

      # Check the single record
      {row_num, data} = List.first(records)
      assert row_num == 1
      assert data["name"] == "Single Product"
      assert data["price"] == 99.99

      # Cleanup
      File.rm!(temp_file)
    end

    test "returns error for non-existent file" do
      source_config = %{
        file_path: "/nonexistent/file.json"
      }

      {:error, message} = JsonFileSource.stream(source_config)

      assert message =~ "File not found"
    end

    test "returns error for invalid JSON" do
      # Create a temporary invalid JSON file
      temp_file = "/tmp/invalid.json"
      File.write!(temp_file, "{invalid json")

      source_config = %{
        file_path: temp_file
      }

      {:error, message} = JsonFileSource.stream(source_config)

      assert message =~ "JSON decode error"

      # Cleanup
      File.rm!(temp_file)
    end

    test "returns error for invalid root path", %{products_nested_json_path: filepath} do
      source_config = %{
        file_path: filepath,
        root_path: "nonexistent.path"
      }

      {:error, message} = JsonFileSource.stream(source_config)

      assert message =~ "Key 'nonexistent' not found in JSON path"
    end

    test "handles empty arrays" do
      # Create an empty array JSON file
      temp_file = "/tmp/empty_array.json"
      File.write!(temp_file, "[]")

      source_config = %{
        file_path: temp_file
      }

      {:ok, stream} = JsonFileSource.stream(source_config)

      records = Enum.to_list(stream)

      assert length(records) == 0

      # Cleanup
      File.rm!(temp_file)
    end
  end
end
