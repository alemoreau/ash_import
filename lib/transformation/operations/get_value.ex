defmodule AshImport.Transformation.GetValue do
  @moduledoc """
  Returns the input value unchanged.
  """
  use AshImport.Transformation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def transform(value, _opts, _context) do
    {:ok, value}
  end

  @impl true
  def describe(_opts), do: "Returns the input value unchanged"
end
