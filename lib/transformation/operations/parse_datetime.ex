defmodule AshImport.Transformation.ParseDatetime do
  @moduledoc """
  Parses strings as datetimes.
  """
  use AshImport.Transformation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def transform(value, _opts, _context) do
    cond do
      is_binary(value) ->
        case DateTime.from_iso8601(value) do
          {:ok, datetime, _} -> {:ok, datetime}
          {:error, _} -> {:error, "Could not parse '#{value}' as datetime"}
        end

      match?(%DateTime{}, value) ->
        {:ok, value}

      is_nil(value) ->
        {:ok, nil}

      true ->
        {:error, "Could not parse '#{inspect(value)}' as datetime"}
    end
  end

  @impl true
  def describe(_opts), do: "Parses strings as datetimes"
end
