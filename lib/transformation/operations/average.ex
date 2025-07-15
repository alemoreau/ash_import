defmodule AshImport.Transformation.Average do
  @moduledoc """
  Calculates the average of numeric values.
  """
  use AshImport.Transformation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def transform(values, _opts, _context) when is_list(values) do
    case convert_to_numbers(values) do
      {:ok, numbers} ->
        if Enum.empty?(numbers) do
          {:ok, nil}
        else
          {:ok, Enum.sum(numbers) / length(numbers)}
        end

      {:error, _} = error ->
        error
    end
  end

  @impl true
  def transform(_values, _opts, _context) do
    {:error, "Average transformation expects a list of values"}
  end

  @impl true
  def describe(_opts), do: "Calculates the average of numeric values"

  defp convert_to_numbers(values) do
    values
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, acc} ->
      case convert_to_number(value) do
        {:ok, number} -> {:cont, {:ok, acc ++ [number]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp convert_to_number(value) when is_number(value), do: {:ok, value}

  defp convert_to_number(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> {:ok, float}
      :error -> {:error, "Could not convert '#{value}' to number"}
    end
  end

  defp convert_to_number(value), do: {:error, "Could not convert '#{inspect(value)}' to number"}
end
