defmodule AshImport.Transformation.FirstNonEmpty do
  @moduledoc """
  Returns the first non-empty value from a list.
  """
  use AshImport.Transformation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def transform(values, _opts, _context) when is_list(values) do
    result =
      Enum.find(values, fn
        nil -> false
        "" -> false
        _ -> true
      end)

    {:ok, result}
  end

  @impl true
  def transform(_values, _opts, _context) do
    {:error, "FirstNonEmpty transformation expects a list of values"}
  end

  @impl true
  def describe(_opts), do: "Returns the first non-empty value from a list"
end
