defmodule AshImport.Transformation.Concat do
  @moduledoc """
  Concatenates multiple values with space separator.
  """
  use AshImport.Transformation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def transform(values, _opts, _context) when is_list(values) do
    result =
      values
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&to_string/1)
      |> Enum.join(" ")

    {:ok, result}
  end

  @impl true
  def transform(_values, _opts, _context) do
    {:error, "Concat transformation expects a list of values"}
  end

  @impl true
  def describe(_opts), do: "Concatenates multiple values with space separator"
end
