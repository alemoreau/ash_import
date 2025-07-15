defmodule AshImport.Workers.ImportJobWorker do
  @moduledoc """
  Simplified Oban worker that processes import jobs by streaming the input file
  and creating ImportRecords in batches.

  This worker:
  1. Loads the ImportJob
  2. Streams the input file
  3. Maps rows to ImportRecord inputs using derivations
  4. Creates ImportRecords using bulk_create in batches
  5. Updates import job progress between batches
  6. Marks job as completed or failed
  """
  use Oban.Worker,
    queue: :import_jobs,
    max_attempts: 3

  require Logger

  alias AshImport.TransformationExecutor

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"import_job_id" => job_id, "import_job_resource" => resource_name}
      }) do
    import_job_resource = String.to_atom(resource_name)

    case load_import_job(import_job_resource, job_id) do
      {:ok, import_job} ->
        process_import_job(import_job)

      {:error, reason} ->
        Logger.error("Failed to load import job #{job_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp load_import_job(import_job_resource, job_id) do
    # Get domain from the resource's configured domain
    domain = Ash.Resource.Info.domain(import_job_resource)

    case Ash.get(import_job_resource, job_id, domain: domain) do
      {:ok, import_job} -> {:ok, import_job}
      {:error, reason} -> {:error, reason}
      nil -> {:error, "Import job not found"}
    end
  end

  defp process_import_job(import_job) do
    Logger.info("Starting import job #{import_job.id}")

    try do
      original_resource = import_job.__struct__.original_resource()
      batch_size = AshImport.Resource.Info.batch_size(original_resource)

      # Stream the file and process in batches
      case stream_file_and_process(import_job, batch_size) do
        {:ok, total_processed} ->
          complete_import_job(import_job, total_processed)

        {:error, reason} ->
          fail_import_job(import_job, reason)
      end
    rescue
      error ->
        Logger.error("Import job #{import_job.id} failed with error: #{inspect(error)}")
        fail_import_job(import_job, "Unexpected error: #{inspect(error)}")
    end
  end

  defp stream_file_and_process(import_job, batch_size) do
    source_type = import_job.source_type
    source_config = import_job.source_config || %{}

    # Get the appropriate source module
    source_module = get_source_module(source_type)

    # Stream using the source
    case source_module.stream(source_config) do
      {:ok, row_stream} ->
        process_file_stream(import_job, row_stream, batch_size)

      {:error, reason} ->
        {:error, "Failed to stream file: #{reason}"}
    end
  end

  defp get_source_module(:csv), do: AshImport.Sources.CsvFileSource
  defp get_source_module(:json), do: AshImport.Sources.JsonFileSource

  defp process_file_stream(import_job, row_stream, batch_size) do
    original_resource = import_job.__struct__.original_resource()
    import_record_resource = AshImport.Resource.Info.import_record_resource(original_resource)
    domain = Ash.Resource.Info.domain(import_job.__struct__)

    # Process rows in batches
    row_stream
    |> Stream.chunk_every(batch_size)
    |> Stream.with_index()
    |> Enum.reduce_while({:ok, 0}, fn {batch_rows, batch_index}, {:ok, total_processed} ->
      Logger.info("Processing batch #{batch_index + 1} for import job #{import_job.id}")

      # Convert rows to ImportRecord inputs with transformed data
      {valid_import_record_inputs, _invalid_import_record_inputs} =
        Enum.map(batch_rows, fn {row_num, raw_data} ->
          # Apply transformations to get the final data for the target resource
          case apply_transformations(import_job, raw_data) do
            {:ok, transformed_data} ->
              {:ok,
               %{
                 import_job_id: import_job.id,
                 row_number: row_num,
                 raw_data: raw_data,
                 transformed_data: transformed_data
               }}

            {:error, error} ->
              Logger.warning("Transformation failed for row #{row_num}: #{inspect(error)}")

              {:error,
               %{
                 import_job_id: import_job.id,
                 row_number: row_num,
                 raw_data: raw_data,
                 error_message: "Transformation failed: #{inspect(error)}"
               }}
          end
        end)
        |> Enum.split_with(fn
          {:ok, _} -> true
          {:error, _} -> false
        end)

      # TODO: do something with invalid records
      # Bulk create ImportRecords
      case Ash.bulk_create(
             valid_import_record_inputs |> Enum.map(fn {:ok, input} -> input end),
             import_record_resource,
             :create,
             domain: domain,
             return_records?: false,
             return_errors?: true
           ) do
        %{errors: []} ->
          batch_count = length(batch_rows)
          new_total = total_processed + batch_count

          # Update progress
          case update_progress(import_job, new_total) do
            :ok ->
              {:cont, {:ok, new_total}}

            {:error, reason} ->
              Logger.warning("Failed to update progress: #{reason}")
              # Continue despite progress update failure
              {:cont, {:ok, new_total}}
          end

        %{errors: errors} ->
          Logger.error("Failed to create import records: #{inspect(errors)}")
          {:halt, {:error, "Failed to create import records: #{inspect(errors)}"}}
      end
    end)
  end

  defp update_progress(import_job, processed_count) do
    domain = Ash.Resource.Info.domain(import_job.__struct__)

    case import_job
         |> Ash.Changeset.for_update(:update_progress, %{processed_records: processed_count})
         |> Ash.update(domain: domain) do
      {:ok, _updated_job} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp complete_import_job(import_job, total_processed) do
    domain = Ash.Resource.Info.domain(import_job.__struct__)

    Logger.info(
      "Import job #{import_job.id} completed successfully. Processed #{total_processed} records."
    )

    case import_job
         |> Ash.Changeset.for_update(:mark_completed)
         |> Ash.update(domain: domain) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to mark job #{import_job.id} as completed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fail_import_job(import_job, error_message) do
    domain = Ash.Resource.Info.domain(import_job.__struct__)

    Logger.error("Import job #{import_job.id} failed: #{error_message}")

    case import_job
         |> Ash.Changeset.for_update(:mark_failed, %{error: error_message})
         |> Ash.update(domain: domain) do
      {:ok, _} ->
        {:error, error_message}

      {:error, reason} ->
        Logger.error("Failed to mark job #{import_job.id} as failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp apply_transformations(import_job, raw_data) do
    # Build context for transformations
    context = %{
      user_inputs: import_job.user_inputs || %{}
    }

    # Apply each argument mapping transformation
    import_job.argument_mappings
    |> Enum.reduce_while({:ok, %{}}, fn mapping, {:ok, acc} ->
      case TransformationExecutor.execute(mapping.transformation, raw_data, context) do
        {:ok, value} ->
          {:cont, {:ok, Map.put(acc, mapping.argument, value)}}

        {:error, error} ->
          {:halt, {:error, "Failed to transform argument '#{mapping.argument}': #{error}"}}
      end
    end)
  end
end
