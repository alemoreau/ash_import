defmodule AshImport.Transformation.Join do
  @moduledoc """
  Joins multiple values with a configurable separator.
  """
  use AshImport.Transformation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def transform(values, opts, _context) when is_list(values) do
    separator = Keyword.get(opts, :separator, ", ")

    result =
      values
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&to_string/1)
      |> Enum.join(separator)

    {:ok, result}
  end

  @impl true
  def transform(_values, _opts, _context) do
    {:error, "Join transformation expects a list of values"}
  end

  @impl true
  def describe(opts) do
    separator = Keyword.get(opts, :separator, ", ")
    "Joins multiple values with '#{separator}' separator"
  end
end
