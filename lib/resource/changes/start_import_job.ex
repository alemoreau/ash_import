defmodule AshImport.Resource.Changes.StartImportJob do
  @moduledoc """
  Starts an import job by scheduling the background processing job.

  This change only handles Oban job scheduling. File analysis and 
  mappings validation are handled by separate changes/validations.
  """
  use Ash.Resource.Change
  require Logger

  def change(changeset, _opts, _context) do
    import_job = changeset.data

    Logger.info("StartImportJob: Scheduling background job for import job #{import_job.id}")

    # Schedule background job
    schedule_processing_job(changeset, import_job)
  end

  defp schedule_processing_job(changeset, import_job) do
    # Schedule Oban job for processing
    job_args = %{
      "import_job_id" => import_job.id,
      "import_job_resource" => import_job.__struct__ |> Atom.to_string()
    }

    case AshImport.Workers.ImportJobWorker.new(job_args) |> Oban.insert() do
      {:ok, oban_job} ->
        Ash.Changeset.change_attribute(changeset, :oban_job_id, oban_job.id)

      {:error, reason} ->
        changeset
        |> Ash.Changeset.change_attribute(:status, :failed)
        |> Ash.Changeset.change_attribute(
          :error_message,
          "Failed to schedule job: #{inspect(reason)}"
        )
    end
  end
end
