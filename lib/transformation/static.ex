defmodule AshImport.Transformation.Static do
  @moduledoc """
  A transformation that returns a static value regardless of input data.

  ## Options

  - `:value` (required) - The static value to return

  ## Examples

      # Always return "imported"
      {AshImport.Transformation.Static, [value: "imported"]}

      # Always return the current timestamp
      {AshImport.Transformation.Static, [value: DateTime.utc_now()]}

  """
  use AshImport.Transformation

  @impl true
  def init(opts) do
    case Keyword.fetch(opts, :value) do
      {:ok, value} ->
        {:ok, %{value: value}}

      :error ->
        {:error, "Static transformation requires a :value option"}
    end
  end

  @impl true
  def transform(_input, %{value: value}, _context) do
    {:ok, value}
  end

  @impl true
  def describe(%{value: value}) do
    "Static value: #{inspect(value)}"
  end
end
