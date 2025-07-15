defmodule AshImport.Resource.Changes.SetupInitialArgumentMappings do
  @moduledoc """
  Sets up initial argument mappings for all required arguments of the selected create action.

  This change automatically creates a basic column mapping for each required argument,
  making it easier for users to get started with import configuration.

  The initial mappings use:
  - Column derivation type for each required argument
  - Column name matching the argument name
  - No transformations by default
  """
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    # Only set up initial mappings if none are provided
    current_mappings = Ash.Changeset.get_attribute(changeset, :argument_mappings) || []

    if Enum.empty?(current_mappings) do
      create_initial_mappings(changeset)
    else
      changeset
    end
  end

  defp create_initial_mappings(changeset) do
    original_resource = changeset.resource.original_resource()

    # Get the create action to use - either from import_config or default
    create_action_name = get_create_action_name(changeset, original_resource)

    case get_action_info(original_resource, create_action_name) do
      {:ok, action_info} ->
        initial_mappings = build_initial_mappings(action_info, original_resource)
        Ash.Changeset.change_attribute(changeset, :argument_mappings, initial_mappings)

      {:error, reason} ->
        Ash.Changeset.add_error(changeset, reason)
    end
  end

  defp get_create_action_name(changeset, original_resource) do
    # Check if create_action is specified in import_config
    import_config = Ash.Changeset.get_attribute(changeset, :import_config) || %{}

    case Map.get(import_config, :create_action) do
      nil ->
        # Use the default create action from the resource
        AshImport.Resource.Info.create_actions(original_resource) |> List.first()

      action_name when is_atom(action_name) ->
        action_name

      action_name when is_binary(action_name) ->
        String.to_atom(action_name)
    end
  end

  defp get_action_info(resource, action_name) do
    case Ash.Resource.Info.action(resource, action_name) do
      nil ->
        {:error, "Action #{action_name} not found on resource #{inspect(resource)}"}

      action ->
        {:ok, action}
    end
  end

  defp build_initial_mappings(action, _resource) do
    # Create mappings for all accepted arguments/attributes
    accepted_args = action.accept || []

    Enum.map(accepted_args, fn arg_name ->
      %{
        argument_name: to_string(arg_name),
        derivation: :unset
      }
    end)
  end
end
