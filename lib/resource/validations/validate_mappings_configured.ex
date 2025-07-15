defmodule AshImport.Resource.Validations.ValidateMappingsConfigured do
  @moduledoc """
  Validates that all argument mappings are fully configured (no unset transformations)
  before starting an import job.
  """
  use Ash.Resource.Validation
  require Logger

  alias AshImport.Resource.ArgumentMapping

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    argument_mappings = Ash.Changeset.get_attribute(changeset, :argument_mappings) || []

    Logger.info("ValidateMappingsConfigured: checking #{length(argument_mappings)} mappings")

    # Get the target resource and action to validate required arguments
    original_resource = changeset.resource.original_resource()
    create_actions = AshImport.Resource.Info.create_actions(original_resource)
    create_action_name = List.first(create_actions)

    # Check required arguments for the action
    required_args_result =
      check_required_arguments(argument_mappings, original_resource, create_action_name)

    # Check for empty transformations or unset operations
    mapping_result = check_mappings(argument_mappings)

    # Combine results
    errors = []

    # Add required arguments errors
    errors =
      case required_args_result do
        :ok -> errors
        error_msg -> [error_msg | errors]
      end

    # Add mapping errors
    errors =
      case mapping_result do
        :ok -> errors
        {:error, reasons} -> reasons ++ errors
      end

    if Enum.empty?(errors) do
      Logger.info("ValidateMappingsConfigured: All mappings are properly configured")
      :ok
    else
      Logger.warning("ValidateMappingsConfigured: Found issues: #{inspect(errors)}")

      {:error,
       message:
         "Some argument mappings are not properly configured: #{Enum.join(Enum.reverse(errors), ", ")}",
       field: :argument_mappings}
    end
  end

  defp check_mappings([]), do: {:error, ["No argument mappings configured"]}

  defp check_mappings(mappings) do
    errors =
      mappings
      |> Enum.with_index()
      |> Enum.flat_map(fn {mapping, index} ->
        check_mapping(mapping, index)
      end)

    if Enum.empty?(errors) do
      :ok
    else
      {:error, errors}
    end
  end

  defp check_mapping(%ArgumentMapping{} = mapping, index) do
    errors = []

    # Check if transformation is present
    if is_nil(mapping.transformation) do
      ["Mapping #{index} (#{mapping.argument}): no transformation configured" | errors]
    else
      # Check the transformation recursively
      case check_transformation(mapping.transformation, "#{mapping.argument}") do
        :ok -> errors
        {:error, reasons} -> reasons ++ errors
      end
    end
  end

  # Handle non-struct mappings (backward compatibility)
  defp check_mapping(mapping, index) when is_map(mapping) do
    argument =
      Map.get(mapping, :argument) || Map.get(mapping, :argument_name) ||
        Map.get(mapping, "argument") || Map.get(mapping, "argument_name")

    # Check for old-style unset derivations
    case mapping do
      %{derivation: :unset} ->
        ["Mapping #{index} (#{argument}): has unset derivation"]

      %{"derivation" => :unset} ->
        ["Mapping #{index} (#{argument}): has unset derivation"]

      _ ->
        []
    end
  end

  defp check_transformation(nil, path), do: {:error, ["#{path}: transformation is nil"]}

  defp check_transformation(%{operation: operation} = _transformation, _path)
       when not is_nil(operation) do
    # Basic check - transformation has operation and inputs (if any)
    :ok
  end

  defp check_transformation(_, _path), do: :ok

  defp check_required_arguments(argument_mappings, original_resource, create_action_name) do
    case Ash.Resource.Info.action(original_resource, create_action_name) do
      nil ->
        "Create action '#{create_action_name}' not found in resource #{inspect(original_resource)}"

      action ->
        # Get required arguments from the action
        required_args =
          action.arguments
          |> Enum.filter(& &1.required)
          |> Enum.map(& &1.name)

        # Get mapped arguments from argument mappings
        mapped_args =
          argument_mappings
          |> Enum.map(fn %ArgumentMapping{argument: arg} -> arg end)

        # Find missing required arguments
        missing_required = required_args -- mapped_args

        if Enum.empty?(missing_required) do
          :ok
        else
          "Missing required argument mappings: #{Enum.join(missing_required, ", ")}"
        end
    end
  end
end
