defmodule AshImport.Transformation.Custom do
  @moduledoc """
  Custom transformation operation.
  Calls the function inside the provided module with the value.
  """
  use AshImport.Transformation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def transform(value, opts, _context) do
    module = Keyword.get(opts, :module)
    function = Keyword.get(opts, :function, :transform)
    args = Keyword.get(opts, :args, [])

    if is_nil(module) or not is_atom(module) do
      {:error, "Custom transformation requires a valid module"}
    else
      case apply(module, function, [value | args]) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> {:error, reason}
        result -> {:ok, result}
      end
    end
  end

  @impl true
  def describe(_opts), do: "Custom transformation operation"
end
