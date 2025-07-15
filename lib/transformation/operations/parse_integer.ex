defmodule AshImport.Transformation.ParseInteger do
  @moduledoc """
  Parses strings as integers.
  """
  use AshImport.Transformation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def transform(value, _opts, _context) do
    cond do
      is_binary(value) ->
        case Integer.parse(value) do
          {int, _} -> {:ok, int}
          :error -> {:error, "Could not parse '#{value}' as integer"}
        end

      is_integer(value) ->
        {:ok, value}

      is_nil(value) ->
        {:ok, nil}

      true ->
        {:error, "Could not parse '#{inspect(value)}' as integer"}
    end
  end

  @impl true
  def describe(_opts), do: "Parses strings as integers"
end
