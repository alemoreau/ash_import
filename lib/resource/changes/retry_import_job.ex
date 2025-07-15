defmodule AshImport.Resource.Changes.RetryImportJob do
  @moduledoc """
  Retries a failed import job by resetting failed records
  and scheduling a new background job.
  """
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    import_job = changeset.data

    schedule_processing_job(changeset, import_job)
  end

  defp schedule_processing_job(changeset, import_job) do
    # Schedule new Oban job for processing
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
          "Failed to schedule retry job: #{inspect(reason)}"
        )
    end
  end
end
