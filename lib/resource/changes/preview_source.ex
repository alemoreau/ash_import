defmodule AshImport.Resource.Changes.PreviewSource do
  @moduledoc """
  Previews and validates the import file using the appropriate Source implementation.

  This change:
  - Determines the appropriate source module based on file_type
  - Uses the source_config attribute directly for source configuration
  - Delegates preview to the source module
  - Updates the changeset with preview results
  """
  use Ash.Resource.Change
  require Logger

  def change(changeset, opts, _context) do
    supported_source_types = Keyword.get(opts, :supported_source_types, [])
    source_type = Ash.Changeset.get_attribute(changeset, :source_type)
    source_config = Ash.Changeset.get_attribute(changeset, :source_config) || %{}

    file_path = Map.get(source_config, :file_path) || Map.get(source_config, "file_path")
    Logger.info("PreviewSource: previewing #{file_path} (#{source_type})")

    # Get the appropriate source module
    source_module = Keyword.get(supported_source_types, source_type)

    # Preview using the source
    case source_module.preview(source_config) do
      {:ok, preview_result} ->
        Logger.info("PreviewSource: preview complete - #{inspect(preview_result)}")

        changeset
        |> apply_preview_result(preview_result)
        |> maybe_update_source_config(preview_result.source_config_overrides, source_config)

      {:error, reason} ->
        Logger.error("PreviewSource: failed to preview file: #{reason}")

        changeset
        |> Ash.Changeset.add_error("Failed to preview file: #{reason}")
    end
  end

  defp apply_preview_result(changeset, preview_result) do
    changeset
    |> Ash.Changeset.change_attribute(:total_records, preview_result.total_records)
    |> Ash.Changeset.change_attribute(:estimated_records, preview_result.estimated_records)
    |> Ash.Changeset.change_attribute(:sample, preview_result.sample)
    |> Ash.Changeset.change_attribute(:column_names, preview_result.column_names)
  end

  defp maybe_update_source_config(changeset, source_config_overrides, current_source_config)
       when map_size(source_config_overrides) > 0 do
    # Merge the overrides into the current source config
    updated_source_config = Map.merge(current_source_config, source_config_overrides)

    Ash.Changeset.change_attribute(changeset, :source_config, updated_source_config)
  end

  defp maybe_update_source_config(changeset, _, _), do: changeset
end
