defmodule AshImport.ImportRecordTest do
  @moduledoc """
  Tests for ImportRecord creation and bulk operations.

  This test suite validates that ImportRecord resources can be created
  individually and in bulk, which is essential for the import worker
  functionality.
  """
  use ExUnit.Case, async: true

  alias AshImport.Test.Product.ImportJob
  alias AshImport.Test.Product.ImportRecord

  setup do
    # Create a test import job first
    filepath = Path.join([__DIR__, "support", "products.csv"])

    {:ok, job} =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: filepath
        }
      })
      |> Ash.create(domain: AshImport.Test)

    %{import_job: job}
  end

  test "can create a single ImportRecord", %{import_job: job} do
    # Test data representing a parsed CSV row
    raw_data = %{
      "name" => "Test Product",
      "description" => "A test product",
      "price" => "19.99",
      "category" => "test"
    }

    # Create a single import record
    {:ok, record} =
      Ash.create(
        ImportRecord,
        %{
          import_job_id: job.id,
          row_number: 1,
          raw_data: raw_data
        },
        domain: AshImport.Test
      )

    # Verify the record was created correctly
    assert record.import_job_id == job.id
    assert record.row_number == 1
    assert record.raw_data == raw_data
    # Default status after creation
    assert record.status == :success
    assert record.id != nil
    assert record.inserted_at != nil
  end

  test "can create multiple ImportRecords with bulk_create", %{import_job: job} do
    # Test data representing multiple parsed CSV rows
    import_record_inputs = [
      %{
        import_job_id: job.id,
        row_number: 1,
        raw_data: %{"name" => "Product 1", "price" => "10.00"}
      },
      %{
        import_job_id: job.id,
        row_number: 2,
        raw_data: %{"name" => "Product 2", "price" => "20.00"}
      },
      %{
        import_job_id: job.id,
        row_number: 3,
        raw_data: %{"name" => "Product 3", "price" => "30.00"}
      }
    ]

    # Bulk create import records
    result =
      Ash.bulk_create(import_record_inputs, ImportRecord, :create,
        domain: AshImport.Test,
        return_records?: true,
        return_errors?: true
      )

    # Verify bulk creation was successful
    assert %{errors: []} = result
    assert length(result.records) == 3

    # Verify each record was created correctly
    created_records = result.records |> Enum.sort_by(& &1.row_number)

    Enum.zip(created_records, import_record_inputs)
    |> Enum.each(fn {record, input} ->
      assert record.import_job_id == input.import_job_id
      assert record.row_number == input.row_number
      assert record.raw_data == input.raw_data
      # Default status after creation
      assert record.status == :success
      assert record.id != nil
    end)
  end

  test "can query ImportRecords by import_job_id", %{import_job: job} do
    # Create some test records
    import_record_inputs = [
      %{
        import_job_id: job.id,
        row_number: 1,
        raw_data: %{"name" => "Product A"}
      },
      %{
        import_job_id: job.id,
        row_number: 2,
        raw_data: %{"name" => "Product B"}
      }
    ]

    # Bulk create the records
    Ash.bulk_create(import_record_inputs, ImportRecord, :create,
      domain: AshImport.Test,
      return_records?: false,
      return_errors?: true
    )

    # Query records for this import job
    {:ok, records} = Ash.read(ImportRecord, domain: AshImport.Test)
    job_records = Enum.filter(records, &(&1.import_job_id == job.id))

    # Verify we can find the records
    assert length(job_records) == 2

    # Verify they have the correct data
    sorted_records = Enum.sort_by(job_records, & &1.row_number)
    assert Enum.at(sorted_records, 0).raw_data["name"] == "Product A"
    assert Enum.at(sorted_records, 1).raw_data["name"] == "Product B"
    assert Enum.at(sorted_records, 0).status == :success
    # Both should have default status
    assert Enum.at(sorted_records, 1).status == :success
  end

  test "bulk_create handles errors gracefully" do
    # Try to create records with invalid data (missing required import_job_id)
    invalid_inputs = [
      %{
        row_number: 1,
        raw_data: %{"name" => "Product 1"}
        # Missing import_job_id
      },
      %{
        # Invalid ID format
        import_job_id: "invalid-id",
        row_number: 2,
        raw_data: %{"name" => "Product 2"}
      }
    ]

    # Bulk create with invalid data
    result =
      Ash.bulk_create(invalid_inputs, ImportRecord, :create,
        domain: AshImport.Test,
        return_records?: true,
        return_errors?: true
      )

    # Verify errors were returned
    assert length(result.errors) > 0
    # Should have no successful records due to validation failures
    assert result.records == []
  end

  test "can set ImportRecord error", %{import_job: job} do
    # Create a test record
    {:ok, record} =
      Ash.create(
        ImportRecord,
        %{
          import_job_id: job.id,
          row_number: 1,
          raw_data: %{"name" => "Test Product"}
        },
        domain: AshImport.Test
      )

    assert record.status == :success

    # Set an error on the record
    {:ok, updated_record} =
      record
      |> Ash.Changeset.for_update(:set_error, %{
        error_message: "Validation failed",
        validation_errors: ["Price is required", "Category is invalid"]
      })
      |> Ash.update(domain: AshImport.Test)

    assert updated_record.status == :failed
    assert updated_record.error_message == "Validation failed"
    assert updated_record.validation_errors == ["Price is required", "Category is invalid"]
    # Same record
    assert updated_record.id == record.id
  end

  test "can create skipped ImportRecord", %{import_job: job} do
    # Create a skipped record using the skip action
    {:ok, record} =
      Ash.create(
        ImportRecord,
        %{
          import_job_id: job.id,
          row_number: 1,
          raw_data: %{"name" => "Test Product"},
          skip_message: "Duplicate product name"
        },
        action: :skip,
        domain: AshImport.Test
      )

    assert record.status == :skipped
    assert record.skip_message == "Duplicate product name"
    assert record.import_job_id == job.id
  end

  test "ImportRecord has relationship to ImportJob", %{import_job: job} do
    # Create a test record
    {:ok, record} =
      Ash.create(
        ImportRecord,
        %{
          import_job_id: job.id,
          row_number: 1,
          raw_data: %{"name" => "Test Product"}
        },
        domain: AshImport.Test
      )

    # Load the relationship
    {:ok, record_with_job} = Ash.load(record, :import_job, domain: AshImport.Test)

    # Verify the relationship works
    assert record_with_job.import_job.id == job.id
    assert record_with_job.import_job.source_config[:file_path] =~ "products.csv"
  end
end
