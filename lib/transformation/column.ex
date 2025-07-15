defmodule AshImport.Transformation.Column do
  @moduledoc """
  A transformation that extracts a value from a single column in the import data.

  ## Options

  - `:column_name` (required) - The name of the column to extract from
  - `:transformations` (optional) - List of transformations to apply (default: [])
  - `:default` (optional) - Default value if column is missing or nil

  ## Examples

      # Extract the "name" column as-is
      {AshImport.Transformation.Column, [column_name: "name"]}

      # Extract "email" column with transformations
      {AshImport.Transformation.Column, [
        column_name: "email",
        transformations: [:downcase, :trim],
        default: nil
      ]}

  """
  use AshImport.Transformation

  @impl true
  def init(opts) do
    column_name = Keyword.get(opts, :column_name)
    transformations = Keyword.get(opts, :transformations, [])
    default = Keyword.get(opts, :default)

    cond do
      is_nil(column_name) ->
        {:error, "Column transformation requires a :column_name option"}

      not is_binary(column_name) ->
        {:error, "Column name must be a string, got: #{inspect(column_name)}"}

      not is_list(transformations) ->
        {:error, "Transformations must be a list, got: #{inspect(transformations)}"}

      true ->
        {:ok,
         %{
           column_name: column_name,
           transformations: transformations,
           default: default
         }}
    end
  end

  @impl true
  def transform(raw_data, %{column_name: column_name} = opts, context) do
    value = Map.get(raw_data, column_name, opts[:default])

    case apply_transformations(value, opts.transformations, context) do
      {:ok, transformed_value} -> {:ok, transformed_value}
      {:error, _} = error -> error
    end
  end

  @impl true
  def describe(%{column_name: column_name, transformations: transformations}) do
    base = "Column '#{column_name}'"

    if Enum.empty?(transformations) do
      base
    else
      "#{base} with transformations: #{inspect(transformations)}"
    end
  end

  defp apply_transformations(value, [], _context), do: {:ok, value}

  defp apply_transformations(value, transformations, context) do
    # For now, implement basic transformations
    # In a full implementation, this would use the transformation modules
    Enum.reduce_while(transformations, {:ok, value}, fn transformation, {:ok, current_value} ->
      case apply_single_transformation(current_value, transformation, context) do
        {:ok, new_value} -> {:cont, {:ok, new_value}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp apply_single_transformation(value, transformation, _context) do
    case transformation do
      :trim when is_binary(value) ->
        {:ok, String.trim(value)}

      :downcase when is_binary(value) ->
        {:ok, String.downcase(value)}

      :upcase when is_binary(value) ->
        {:ok, String.upcase(value)}

      :trim when is_nil(value) ->
        {:ok, nil}

      :downcase when is_nil(value) ->
        {:ok, nil}

      :upcase when is_nil(value) ->
        {:ok, nil}

      unknown ->
        {:error, "Unknown transformation: #{inspect(unknown)}"}
    end
  end
end
