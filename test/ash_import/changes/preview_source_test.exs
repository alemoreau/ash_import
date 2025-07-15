defmodule AshImport.PreviewSourceTest do
  @moduledoc """
  Tests for the PreviewSource change that previews files during job creation.
  """
  use ExUnit.Case, async: false

  alias AshImport.Test.Product.ImportJob

  setup_all do
    # Start the test repo
    {:ok, _} = AshImport.Test.Repo.start_link()

    %{
      empty_csv_path: "test/support/empty.csv",
      products_csv_path: "test/support/products.csv",
      products_without_header_csv_path: "test/support/products_without_header.csv",
      headers_only_csv_path: "test/support/headers_only.csv",
      large_products_csv_path: "test/support/large_products.csv",
      products_json_path: "test/support/products.json",
      products_nested_json_path: "test/support/products_nested.json"
    }
  end

  test "PreviewSource correctly counts CSV records during job creation", %{
    products_csv_path: filepath
  } do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: filepath,
          has_headers?: true
        }
      })
      |> Ash.create!()

    assert job.total_records == 3
  end

  test "PreviewSource handles CSV without headers", %{
    products_without_header_csv_path: filepath
  } do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: filepath,
          has_headers?: false
        }
      })
      |> Ash.create!()

    assert job.total_records == 3
  end

  test "PreviewSource handles empty CSV file", %{empty_csv_path: filepath} do
    # Empty files are now handled by PreviewSource change
    assert_raise Ash.Error.Invalid, ~r/File is empty/, fn ->
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: filepath,
          has_headers?: true
        }
      })
      |> Ash.create!()
    end
  end

  test "PreviewSource handles CSV with only headers", %{headers_only_csv_path: filepath} do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: filepath,
          has_headers?: true
        }
      })
      |> Ash.create!()

    # Should count 0 data records (1 line - 1 header = 0)
    assert job.total_records == 0
  end

  test "PreviewSource handles JSON array", %{products_json_path: filepath} do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :json,
        source_config: %{
          file_path: filepath
        }
      })
      |> Ash.create!()

    # Should count 2 JSON objects
    assert job.total_records == 2
  end

  test "PreviewSource handles JSON with nested array", %{products_nested_json_path: filepath} do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :json,
        source_config: %{
          file_path: filepath,
          root_path: "data"
        }
      })
      |> Ash.create!()

    # Should count 2 JSON objects in the nested array
    assert job.total_records == 2
  end

  test "PreviewSource handles file read errors gracefully" do
    filepath = "/nonexistent/path/file.csv"

    # This should fail during creation due to file preview error
    assert_raise Ash.Error.Invalid, fn ->
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: filepath,
          has_headers?: true
        }
      })
      |> Ash.create!()
    end
  end

  test "ImportJob accepts source_config with CSV configuration", %{
    products_csv_path: filepath
  } do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: filepath,
          delimiter: ",",
          has_headers?: true,
          skip_rows: 0
        }
      })
      |> Ash.create!()

    assert job.source_type == :csv
    assert job.total_records == 3
  end

  test "ImportJob accepts source_config with JSON configuration", %{products_json_path: filepath} do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :json,
        source_config: %{
          file_path: filepath,
          encoding: "utf-8"
        }
      })
      |> Ash.create!()

    assert job.source_type == :json
    assert job.total_records == 2
  end

  test "PreviewSource populates sample records for CSV with headers", %{
    products_csv_path: filepath
  } do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: filepath,
          has_headers?: true
        }
      })
      |> Ash.create!()

    assert job.total_records == 3
    # Should have all 3 records as sample (less than 5)
    assert length(job.sample) == 3

    # Check that sample records have proper header-based keys
    first_sample = List.first(job.sample)
    assert Map.has_key?(first_sample, "name")
    assert Map.has_key?(first_sample, "description")
    assert Map.has_key?(first_sample, "price")

    # Verify sample data content
    assert first_sample["name"] == "1"
    assert first_sample["description"] == "Product 1"
    assert first_sample["price"] == "19.99"
  end

  test "PreviewSource populates sample records for CSV without headers", %{
    products_without_header_csv_path: filepath
  } do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: filepath,
          has_headers?: false
        }
      })
      |> Ash.create!()

    assert job.total_records == 3
    assert length(job.sample) == 3

    # Check that sample records have numeric column keys
    first_sample = List.first(job.sample)
    assert Map.has_key?(first_sample, "column_0")
    assert Map.has_key?(first_sample, "column_1")
    assert Map.has_key?(first_sample, "column_2")

    # Verify sample data content
    assert first_sample["column_0"] == "1"
    assert first_sample["column_1"] == "Product 1"
    assert first_sample["column_2"] == "19.99"
  end

  test "PreviewSource populates sample records for JSON array", %{products_json_path: filepath} do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :json,
        source_config: %{
          file_path: filepath
        }
      })
      |> Ash.create!()

    assert job.total_records == 2
    assert length(job.sample) == 2

    # Check that sample records have JSON structure
    first_sample = List.first(job.sample)
    assert first_sample["name"] == "Product 1"
    assert first_sample["price"] == 19.99

    second_sample = List.last(job.sample)
    assert second_sample["name"] == "Product 2"
    assert second_sample["price"] == 29.99
  end

  test "PreviewSource populates sample records for nested JSON", %{
    products_nested_json_path: filepath
  } do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :json,
        source_config: %{
          file_path: filepath,
          root_path: "data"
        }
      })
      |> Ash.create!()

    assert job.total_records == 2
    assert length(job.sample) == 2

    # Check that sample records have proper JSON structure from nested path
    first_sample = List.first(job.sample)
    assert first_sample["name"] == "Product 1"
    assert first_sample["price"] == 19.99
  end

  test "PreviewSource limits sample size for large files", %{large_products_csv_path: filepath} do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: filepath,
          has_headers?: true
        }
      })
      |> Ash.create!()

    assert job.total_records == 7
    # Should be limited to 5 sample records
    assert length(job.sample) == 5

    # Verify it contains the first 5 records
    sample_names = Enum.map(job.sample, & &1["name"])
    assert sample_names == ["Product 1", "Product 2", "Product 3", "Product 4", "Product 5"]
  end

  test "PreviewSource extracts column names for CSV with headers", %{
    products_csv_path: filepath
  } do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: filepath,
          has_headers?: true
        }
      })
      |> Ash.create!()

    assert job.column_names == ["name", "description", "price"]
  end

  test "PreviewSource generates column names for CSV without headers", %{
    products_without_header_csv_path: filepath
  } do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: filepath,
          has_headers?: false
        }
      })
      |> Ash.create!()

    assert job.column_names == ["column_0", "column_1", "column_2"]
  end

  test "PreviewSource extracts column names for JSON array", %{products_json_path: filepath} do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :json,
        source_config: %{
          file_path: filepath
        }
      })
      |> Ash.create!()

    # Column names should be sorted alphabetically from JSON keys
    assert job.column_names == ["name", "price"]
  end

  test "PreviewSource extracts column names for nested JSON", %{
    products_nested_json_path: filepath
  } do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :json,
        source_config: %{
          file_path: filepath,
          root_path: "data"
        }
      })
      |> Ash.create!()

    # Column names should be sorted alphabetically from JSON keys
    assert job.column_names == ["name", "price"]
  end

  test "PreviewSource handles empty files gracefully with column names", %{
    empty_csv_path: filepath
  } do
    assert_raise Ash.Error.Invalid, ~r/File is empty/, fn ->
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: filepath,
          has_headers?: true
        }
      })
      |> Ash.create!()
    end
  end

  test "update_source_config retriggers preview with new settings", %{
    products_csv_path: filepath
  } do
    # Create job with default settings
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: filepath,
          has_headers?: true
        }
      })
      |> Ash.create!()

    # Verify initial preview results
    assert job.column_names == ["name", "description", "price"]
    assert job.total_records == 3

    # Update source config to change settings
    new_source_config = %{
      file_path: filepath,
      # Change to no headers
      has_headers?: false,
      delimiter: ","
    }

    updated_job =
      job
      |> Ash.Changeset.for_update(:update_source_config, %{
        source_type: :csv,
        source_config: new_source_config
      })
      |> Ash.update!()

    # Verify preview was retriggered with new settings
    # Generated column names
    assert updated_job.column_names == ["column_0", "column_1", "column_2"]
    assert updated_job.source_type == :csv
    # Total records should be different since no header row is skipped
    # Header + 3 data rows = 4 rows
    assert updated_job.total_records == 4
  end

  test "update_source_config works with JSON files", %{products_json_path: filepath} do
    # Create job with JSON file
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :json,
        source_config: %{
          file_path: filepath
        }
      })
      |> Ash.create!()

    # Verify initial preview
    assert job.column_names == ["name", "price"]
    assert job.total_records == 2

    # Update source config for JSON
    new_source_config = %{
      file_path: filepath,
      encoding: "utf-8"
    }

    updated_job =
      job
      |> Ash.Changeset.for_update(:update_source_config, %{
        source_type: :json,
        source_config: new_source_config
      })
      |> Ash.update!()

    # Verify source config was updated and preview retriggered
    assert updated_job.source_type == :json
    # Should remain the same for this simple case
    assert updated_job.column_names == ["name", "price"]
    assert updated_job.total_records == 2
  end

  test "PreviewSource handles custom delimiter detection", %{products_csv_path: filepath} do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: filepath,
          has_headers?: true
          # No delimiter specified - should auto-detect
        }
      })
      |> Ash.create!()

    # Should detect comma delimiter and update source_config
    assert Map.get(job.source_config, :delimiter) == ","
  end

  test "PreviewSource respects explicitly set delimiter", %{products_csv_path: filepath} do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: filepath,
          has_headers?: true,
          # Explicitly set (even though file uses comma)
          delimiter: ";"
        }
      })
      |> Ash.create!()

    assert Map.get(job.source_config, :delimiter) == ";"
  end

  test "PreviewSource handles skip_rows configuration", %{products_csv_path: filepath} do
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: filepath,
          has_headers?: true,
          skip_rows: 1
        }
      })
      |> Ash.create!()

    # Should skip 1 row, then treat next row as header, leaving 2 data rows
    assert job.total_records == 2
    assert job.estimated_records == 2
  end
end
