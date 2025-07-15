defmodule AshImport.Transformation.Upcase do
  @moduledoc """
  Converts strings to uppercase.
  """
  use AshImport.Transformation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def transform(value, _opts, _context) do
    cond do
      is_binary(value) -> {:ok, String.upcase(value)}
      is_nil(value) -> {:ok, nil}
      true -> {:ok, value}
    end
  end

  @impl true
  def describe(_opts), do: "Converts strings to uppercase"
end
