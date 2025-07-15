defmodule AshImport.TransformationExecutor do
  @moduledoc """
  Executes transformation pipelines defined by the embedded resources.
  """

  alias AshImport.Resource.Transformation

  @doc """
  Execute a transformation with the given context.
  """
  def execute(%Transformation{module: module} = transformation, raw_data, context)
      when not is_nil(module) do
    # First, resolve all inputs
    with {:ok, input_values} <- resolve_inputs(transformation.inputs, raw_data, context) do
      # Then apply the transformation module
      apply_transformation(module, input_values, transformation.options, context)
    end
  end

  @doc """
  Execute an argument mapping to get the value for an argument.
  """
  def execute_mapping(argument_mapping, raw_data, context) do
    execute(argument_mapping.transformation, raw_data, context)
  end

  # Resolve inputs to their values
  defp resolve_inputs(inputs, raw_data, context) do
    inputs
    |> Enum.reduce_while({:ok, []}, fn input, {:ok, acc} ->
      case resolve_input(input, raw_data, context) do
        {:ok, value} -> {:cont, {:ok, acc ++ [value]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  # Handle Ash.Union inputs from the new Transformation structure
  defp resolve_input(%Ash.Union{type: :column, value: column_input}, raw_data, _context) do
    value = Map.get(raw_data, column_input.name)
    {:ok, value}
  end

  defp resolve_input(%Ash.Union{type: :static, value: static_input}, _raw_data, _context) do
    {:ok, static_input.value}
  end

  defp resolve_input(%Ash.Union{type: :transformation, value: transformation}, raw_data, context) do
    # For nested transformations, execute the nested transformation
    execute(transformation, raw_data, context)
  end

  # Handle direct Transformation structs (when passed directly as inputs)
  defp resolve_input(%Transformation{} = transformation, raw_data, context) do
    execute(transformation, raw_data, context)
  end

  # Apply transformation using the module-based approach
  defp apply_transformation(module, input_values, options, context) do
    case AshImport.Transformation.init_transformation({module, options}) do
      {:ok, {module, runtime_opts}} ->
        # Handle single vs multiple inputs
        input = if length(input_values) == 1, do: hd(input_values), else: input_values
        module.transform(input, runtime_opts, context)

      {:error, _} = error ->
        error
    end
  end
end
