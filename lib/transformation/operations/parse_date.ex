defmodule AshImport.Transformation.ParseDate do
  @moduledoc """
  Parses strings as dates.
  """
  use AshImport.Transformation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def transform(value, _opts, _context) do
    cond do
      is_binary(value) ->
        case Date.from_iso8601(value) do
          {:ok, date} -> {:ok, date}
          {:error, _} -> {:error, "Could not parse '#{value}' as date"}
        end

      match?(%Date{}, value) ->
        {:ok, value}

      is_nil(value) ->
        {:ok, nil}

      true ->
        {:error, "Could not parse '#{inspect(value)}' as date"}
    end
  end

  @impl true
  def describe(_opts), do: "Parses strings as dates"
end
