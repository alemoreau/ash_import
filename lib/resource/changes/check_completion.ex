defmodule AshImport.Resource.Changes.CheckCompletion do
  @moduledoc """
  Checks if an import job is completed based on processed records
  and updates the status accordingly.
  """
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    # Calculate if import is complete
    total = Ash.Changeset.get_attribute(changeset, :total_records)
    processed = Ash.Changeset.get_attribute(changeset, :processed_records)

    if total && processed && processed >= total do
      changeset
      |> Ash.Changeset.change_attribute(:status, :completed)
      |> Ash.Changeset.change_attribute(:completed_at, DateTime.utc_now())
    else
      changeset
    end
  end
end
