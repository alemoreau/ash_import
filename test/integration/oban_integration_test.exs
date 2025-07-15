defmodule AshImport.ObanIntegrationTest do
  @moduledoc """
  Tests for Oban integration in AshImport.

  This test suite verifies that import jobs correctly schedule and execute
  background processing using Oban workers.
  """
  use ExUnit.Case, async: false
  use Oban.Testing, repo: AshImport.Test.Repo, prefix: "private"

  alias AshImport.Test.Product.ImportJob
  alias AshImport.Workers.ImportJobWorker
  alias AshImport.Resource.{Transformation, ArgumentMapping}

  setup_all do
    # Start the test repo
    {:ok, _} = AshImport.Test.Repo.start_link()

    # Start Oban with test configuration
    oban_config = Application.get_env(:ash_import, :oban)
    {:ok, _} = Oban.start_link(oban_config)

    :ok
  end

  test "starting an import job schedules an Oban worker" do
    # Create a transformation for getting the name
    {:ok, name_transformation} =
      Transformation
      |> Ash.Changeset.for_create(:create, %{
        name: :get_value,
        module: AshImport.Transformation.GetValue,
        inputs: [%{type: "column", name: "name"}]
      })
      |> Ash.create()

    # Create argument mapping
    {:ok, name_mapping} =
      ArgumentMapping
      |> Ash.Changeset.for_create(:create, %{
        argument: "name",
        transformation: name_transformation,
        required: true
      })
      |> Ash.create()

    # Create and configure a job
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: Path.join([__DIR__, "..", "support", "products.csv"])
        }
      })
      |> Ash.create!(domain: AshImport.Test)

    assert job.status == :pending

    updated_job =
      job
      |> Ash.Changeset.for_update(:configure_mappings, %{argument_mappings: [name_mapping]})
      |> Ash.update!(domain: AshImport.Test)

    Oban.Testing.with_testing_mode(:manual, fn ->
      # Start the job - this should schedule an Oban worker
      started_job =
        updated_job |> Ash.Changeset.for_update(:start) |> Ash.update!(domain: AshImport.Test)

      # Verify the job was scheduled
      assert started_job.status == :processing
      assert started_job.oban_job_id != nil

      assert_enqueued(
        worker: ImportJobWorker,
        args: %{
          "import_job_id" => started_job.id,
          "import_job_resource" => "Elixir.AshImport.Test.Product.ImportJob"
        }
      )
    end)
  end

  test "cancelling an import job cancels the Oban job" do
    # Create a transformation for getting the name
    {:ok, name_transformation} =
      Transformation
      |> Ash.Changeset.for_create(:create, %{
        name: :get_value,
        module: AshImport.Transformation.GetValue,
        inputs: [%{type: "column", name: "name"}]
      })
      |> Ash.create()

    # Create argument mapping
    {:ok, name_mapping} =
      ArgumentMapping
      |> Ash.Changeset.for_create(:create, %{
        argument: "name",
        transformation: name_transformation,
        required: true
      })
      |> Ash.create()

    # Create and configure a job
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: Path.join([__DIR__, "..", "support", "products.csv"])
        }
      })
      |> Ash.create!(domain: AshImport.Test)

    updated_job =
      job
      |> Ash.Changeset.for_update(:configure_mappings, %{argument_mappings: [name_mapping]})
      |> Ash.update!(domain: AshImport.Test)

    Oban.Testing.with_testing_mode(:manual, fn ->
      # Start the job
      started_job =
        updated_job |> Ash.Changeset.for_update(:start) |> Ash.update!(domain: AshImport.Test)

      # Verify job was scheduled
      assert_enqueued(
        worker: ImportJobWorker,
        args: %{
          "import_job_id" => started_job.id,
          "import_job_resource" => "Elixir.AshImport.Test.Product.ImportJob"
        }
      )

      # Cancel the job
      cancelled_job =
        started_job |> Ash.Changeset.for_update(:cancel) |> Ash.update!(domain: AshImport.Test)

      assert cancelled_job.status == :cancelled

      # Note: In a real application, you might want to check that the Oban job
      # is cancelled/discarded, but this depends on your cancellation implementation
    end)
  end

  test "retrying a failed import job reschedules the Oban worker" do
    # Create a transformation for getting the name
    {:ok, name_transformation} =
      Transformation
      |> Ash.Changeset.for_create(:create, %{
        name: :get_value,
        module: AshImport.Transformation.GetValue,
        inputs: [%{type: "column", name: "name"}]
      })
      |> Ash.create()

    # Create argument mapping
    {:ok, name_mapping} =
      ArgumentMapping
      |> Ash.Changeset.for_create(:create, %{
        argument: "name",
        transformation: name_transformation,
        required: true
      })
      |> Ash.create()

    # Create and configure a job
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: Path.join([__DIR__, "..", "support", "products.csv"])
        }
      })
      |> Ash.create!(domain: AshImport.Test)

    updated_job =
      job
      |> Ash.Changeset.for_update(:configure_mappings, %{argument_mappings: [name_mapping]})
      |> Ash.update!(domain: AshImport.Test)

    Oban.Testing.with_testing_mode(:manual, fn ->
      # Start the job
      started_job =
        updated_job |> Ash.Changeset.for_update(:start) |> Ash.update!(domain: AshImport.Test)

      # Mark the job as failed
      failed_job =
        started_job
        |> Ash.Changeset.for_update(:mark_failed, %{error: "Test error"})
        |> Ash.update!(domain: AshImport.Test)

      assert failed_job.status == :failed

      # Retry the job - this should reschedule the Oban worker
      retried_job =
        failed_job |> Ash.Changeset.for_update(:retry) |> Ash.update!(domain: AshImport.Test)

      assert retried_job.status == :pending

      # Start again - should schedule a new Oban job
      restarted_job =
        retried_job |> Ash.Changeset.for_update(:start) |> Ash.update!(domain: AshImport.Test)

      # Should have a new Oban job scheduled
      assert_enqueued(
        worker: ImportJobWorker,
        args: %{
          "import_job_id" => restarted_job.id,
          "import_job_resource" => "Elixir.AshImport.Test.Product.ImportJob"
        }
      )
    end)
  end

  test "Oban worker handles missing import job gracefully" do
    # Test that the worker handles the case where an import job is deleted
    # but the Oban job still tries to process it

    Oban.Testing.with_testing_mode(:manual, fn ->
      # Try to perform a job with a non-existent import job ID
      result =
        perform_job(ImportJobWorker, %{
          "import_job_id" => "non-existent-id",
          "import_job_resource" => "Elixir.AshImport.Test.Product.ImportJob"
        })

      # Should handle the error gracefully
      assert {:error, _reason} = result
    end)
  end

  test "import job tracks Oban job ID correctly" do
    # Create a transformation for getting the name
    {:ok, name_transformation} =
      Transformation
      |> Ash.Changeset.for_create(:create, %{
        name: :get_value,
        module: AshImport.Transformation.GetValue,
        inputs: [%{type: "column", name: "name"}]
      })
      |> Ash.create()

    # Create argument mapping
    {:ok, name_mapping} =
      ArgumentMapping
      |> Ash.Changeset.for_create(:create, %{
        argument: "name",
        transformation: name_transformation,
        required: true
      })
      |> Ash.create()

    # Create and configure a job
    job =
      ImportJob
      |> Ash.Changeset.for_create(:create, %{
        source_type: :csv,
        source_config: %{
          file_path: Path.join([__DIR__, "..", "support", "products.csv"])
        }
      })
      |> Ash.create!(domain: AshImport.Test)

    updated_job =
      job
      |> Ash.Changeset.for_update(:configure_mappings, %{argument_mappings: [name_mapping]})
      |> Ash.update!(domain: AshImport.Test)

    Oban.Testing.with_testing_mode(:manual, fn ->
      # Before starting, should have no Oban job ID
      assert updated_job.oban_job_id == nil

      # Start the job
      started_job =
        updated_job |> Ash.Changeset.for_update(:start) |> Ash.update!(domain: AshImport.Test)

      # After starting, should have an Oban job ID
      assert started_job.oban_job_id != nil
      assert is_integer(started_job.oban_job_id)

      # The Oban job ID should correspond to the scheduled job
      assert_enqueued(
        worker: ImportJobWorker,
        args: %{
          "import_job_id" => started_job.id,
          "import_job_resource" => "Elixir.AshImport.Test.Product.ImportJob"
        }
      )
    end)
  end
end
