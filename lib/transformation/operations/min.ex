defmodule AshImport.Transformation.Min do
  @moduledoc """
  Finds the minimum value.
  """
  use AshImport.Transformation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def transform(values, _opts, _context) when is_list(values) do
    if Enum.empty?(values) do
      {:ok, nil}
    else
      {:ok, Enum.min(values)}
    end
  end

  @impl true
  def transform(_values, _opts, _context) do
    {:error, "Min transformation expects a list of values"}
  end

  @impl true
  def describe(_opts), do: "Finds the minimum value"
end
