defmodule AshImport.Transformation.Trim do
  @moduledoc """
  Trims whitespace from string values.
  """
  use AshImport.Transformation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def transform(value, _opts, _context) do
    cond do
      is_binary(value) -> {:ok, String.trim(value)}
      is_nil(value) -> {:ok, nil}
      true -> {:ok, value}
    end
  end

  @impl true
  def describe(_opts), do: "Trims whitespace from string values"
end
