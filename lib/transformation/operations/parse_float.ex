defmodule AshImport.Transformation.ParseFloat do
  @moduledoc """
  Parses strings as floats.
  """
  use AshImport.Transformation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def transform(value, _opts, _context) do
    cond do
      is_binary(value) ->
        case Float.parse(value) do
          {float, _} -> {:ok, float}
          :error -> {:error, "Could not parse '#{value}' as float"}
        end

      is_float(value) ->
        {:ok, value}

      is_integer(value) ->
        {:ok, value * 1.0}

      is_nil(value) ->
        {:ok, nil}

      true ->
        {:error, "Could not parse '#{inspect(value)}' as float"}
    end
  end

  @impl true
  def describe(_opts), do: "Parses strings as floats"
end
