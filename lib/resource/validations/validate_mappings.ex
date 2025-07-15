defmodule AshImport.Resource.Validations.ValidateMappings do
  @moduledoc """
  Validates that argument mappings are correctly configured and compatible
  with the target resource's action.
  """
  use Ash.Resource.Validation

  alias AshImport.Resource.ArgumentMapping

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    argument_mappings = Ash.Changeset.get_attribute(changeset, :argument_mappings) || []

    if Enum.empty?(argument_mappings) do
      # Allow empty mappings - they can be configured later
      :ok
    else
      case validate_all_mappings(changeset, argument_mappings) do
        :ok -> :ok
        {:error, errors} -> {:error, errors}
      end
    end
  end

  defp validate_all_mappings(changeset, argument_mappings) do
    # Get the original resource and its create action
    original_resource = changeset.resource.original_resource()

    # Get the create action to use - default for now
    create_action_name = AshImport.Resource.Info.create_actions(original_resource) |> List.first()

    case get_action_info(original_resource, create_action_name) do
      {:ok, action_info} ->
        validate_mappings_against_action(argument_mappings, action_info, original_resource)

      {:error, reason} ->
        {:error, [reason]}
    end
  end

  defp get_action_info(resource, action_name) do
    case Ash.Resource.Info.action(resource, action_name) do
      nil ->
        {:error, "Action #{action_name} not found on resource #{inspect(resource)}"}

      action ->
        # Get available arguments and attributes
        available_args = get_available_arguments(action)

        {:ok,
         %{
           action: action,
           available_arguments: available_args,
           required_arguments: get_required_arguments(action)
         }}
    end
  end

  defp get_available_arguments(action) do
    # Combine accepted attributes and action arguments
    attributes = action.accept |> MapSet.new()
    arguments = action.arguments |> Enum.map(& &1.name) |> MapSet.new()

    MapSet.union(attributes, arguments) |> MapSet.to_list()
  end

  defp get_required_arguments(action) do
    # Get required arguments (those without defaults and allow_nil? false)
    required_args =
      action.arguments
      |> Enum.filter(fn arg ->
        !arg.allow_nil? && is_nil(arg.default)
      end)
      |> Enum.map(& &1.name)

    # Note: We can't easily determine required attributes here without more context
    required_args
  end

  defp validate_mappings_against_action(argument_mappings, action_info, _original_resource) do
    errors =
      argument_mappings
      |> Enum.with_index()
      |> Enum.flat_map(fn {mapping, index} ->
        validate_single_mapping(mapping, index, action_info)
      end)

    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp validate_single_mapping(%ArgumentMapping{} = mapping, index, action_info) do
    errors = []

    # Convert argument name to atom for comparison
    argument_atom =
      if is_binary(mapping.argument), do: String.to_atom(mapping.argument), else: mapping.argument

    # Validate target argument exists
    errors =
      if argument_atom not in action_info.available_arguments do
        [
          "Mapping #{index}: argument '#{mapping.argument}' not available in action #{action_info.action.name}"
          | errors
        ]
      else
        errors
      end

    # The transformation structure is already validated by the embedded resource
    errors
  end
end
