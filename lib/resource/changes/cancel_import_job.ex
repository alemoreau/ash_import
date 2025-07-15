defmodule AshImport.Resource.Changes.CancelImportJob do
  @moduledoc """
  Cancels an import job by stopping the background processing
  and updating the status.
  """
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    import_job = changeset.data

    # Cancel the Oban job if it exists
    if import_job.oban_job_id do
      case Oban.cancel_job(import_job.oban_job_id) do
        :ok ->
          changeset

        {:ok, _job} ->
          changeset

        {:error, :not_found} ->
          # Job already completed or doesn't exist
          changeset

        {:error, reason} ->
          Ash.Changeset.add_error(
            changeset,
            "Failed to cancel background job: #{inspect(reason)}"
          )
      end
    else
      changeset
    end
  end
end
