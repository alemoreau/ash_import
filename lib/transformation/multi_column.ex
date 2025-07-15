defmodule AshImport.Transformation.MultiColumn do
  @moduledoc """
  A transformation that combines values from multiple columns using a reducer function.

  ## Options

  - `:column_names` (required) - List of column names to combine
  - `:reducer` (required) - How to combine the values (:concat, :first_non_empty, :join, :sum, etc.)
  - `:separator` (optional) - Separator for :join and :concat reducers (default: " ")
  - `:transformations` (optional) - List of transformations to apply after reduction (default: [])
  - `:default` (optional) - Default value if all columns are missing/nil

  ## Examples

      # Concatenate first and last name
      {AshImport.Transformation.MultiColumn, [
        column_names: ["first_name", "last_name"],
        reducer: :concat,
        separator: " "
      ]}

      # Sum numeric columns
      {AshImport.Transformation.MultiColumn, [
        column_names: ["price", "tax", "shipping"],
        reducer: :sum
      ]}

      # Take first non-empty value
      {AshImport.Transformation.MultiColumn, [
        column_names: ["email", "backup_email", "contact_email"],
        reducer: :first_non_empty
      ]}

  """
  use AshImport.Transformation

  @impl true
  def init(opts) do
    column_names = Keyword.get(opts, :column_names)
    reducer = Keyword.get(opts, :reducer)
    separator = Keyword.get(opts, :separator, " ")
    transformations = Keyword.get(opts, :transformations, [])
    default = Keyword.get(opts, :default)

    cond do
      not is_list(column_names) or Enum.empty?(column_names) ->
        {:error, "MultiColumn transformation requires a non-empty list of :column_names"}

      is_nil(reducer) ->
        {:error, "MultiColumn transformation requires a :reducer option"}

      reducer not in [:concat, :join, :first_non_empty, :sum, :average, :min, :max] ->
        {:error,
         "Unknown reducer: #{reducer}. Supported: [:concat, :join, :first_non_empty, :sum, :average, :min, :max]"}

      not is_list(transformations) ->
        {:error, "Transformations must be a list, got: #{inspect(transformations)}"}

      true ->
        {:ok,
         %{
           column_names: column_names,
           reducer: reducer,
           separator: separator,
           transformations: transformations,
           default: default
         }}
    end
  end

  @impl true
  def transform(raw_data, opts, context) do
    values =
      Enum.map(opts.column_names, fn column_name ->
        Map.get(raw_data, column_name)
      end)

    case apply_reducer(values, opts.reducer, opts) do
      {:ok, reduced_value} ->
        apply_transformations(reduced_value, opts.transformations, context)

      {:error, _} = error ->
        error
    end
  end

  @impl true
  def describe(%{column_names: column_names, reducer: reducer}) do
    "Combine columns [#{Enum.join(column_names, ", ")}] using #{reducer}"
  end

  defp apply_reducer(values, reducer, opts) do
    case reducer do
      :concat ->
        non_nil_values = Enum.reject(values, &is_nil/1)
        result = Enum.join(non_nil_values, opts.separator)
        {:ok, if(result == "", do: opts[:default], else: result)}

      :join ->
        non_nil_values = Enum.reject(values, &is_nil/1)
        result = Enum.join(non_nil_values, opts.separator)
        {:ok, if(result == "", do: opts[:default], else: result)}

      :first_non_empty ->
        result =
          Enum.find(values, fn value ->
            not is_nil(value) and value != ""
          end)

        {:ok, result || opts[:default]}

      :sum ->
        numeric_values =
          values
          |> Enum.reject(&is_nil/1)
          |> Enum.map(&parse_number/1)

        if Enum.any?(numeric_values, &is_nil/1) do
          {:error, "Cannot sum non-numeric values"}
        else
          {:ok, Enum.sum(numeric_values)}
        end

      :average ->
        numeric_values =
          values
          |> Enum.reject(&is_nil/1)
          |> Enum.map(&parse_number/1)

        if Enum.any?(numeric_values, &is_nil/1) do
          {:error, "Cannot average non-numeric values"}
        else
          count = length(numeric_values)

          if count == 0 do
            {:ok, opts[:default]}
          else
            {:ok, Enum.sum(numeric_values) / count}
          end
        end

      :min ->
        non_nil_values = Enum.reject(values, &is_nil/1)
        {:ok, if(Enum.empty?(non_nil_values), do: opts[:default], else: Enum.min(non_nil_values))}

      :max ->
        non_nil_values = Enum.reject(values, &is_nil/1)
        {:ok, if(Enum.empty?(non_nil_values), do: opts[:default], else: Enum.max(non_nil_values))}
    end
  end

  defp parse_number(value) when is_number(value), do: value

  defp parse_number(value) when is_binary(value) do
    case Float.parse(value) do
      {number, ""} ->
        number

      _ ->
        case Integer.parse(value) do
          {number, ""} -> number
          _ -> nil
        end
    end
  end

  defp parse_number(_), do: nil

  defp apply_transformations(value, [], _context), do: {:ok, value}

  defp apply_transformations(value, transformations, _context) do
    # Basic transformation support - same as Column transformation
    Enum.reduce_while(transformations, {:ok, value}, fn transformation, {:ok, current_value} ->
      case apply_single_transformation(current_value, transformation) do
        {:ok, new_value} -> {:cont, {:ok, new_value}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp apply_single_transformation(value, transformation) do
    case transformation do
      :trim when is_binary(value) -> {:ok, String.trim(value)}
      :downcase when is_binary(value) -> {:ok, String.downcase(value)}
      :upcase when is_binary(value) -> {:ok, String.upcase(value)}
      :trim when is_nil(value) -> {:ok, nil}
      :downcase when is_nil(value) -> {:ok, nil}
      :upcase when is_nil(value) -> {:ok, nil}
      unknown -> {:error, "Unknown transformation: #{inspect(unknown)}"}
    end
  end
end
