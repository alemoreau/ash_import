defmodule AshImport.Transformation.Unset do
  @moduledoc """
  A special transformation that indicates an argument mapping has not been configured yet.

  This transformation is used as a placeholder when automatically generating initial
  argument mappings. It always returns an error to force users to configure
  proper transformations before attempting to import data.

  ## Usage

  This transformation is typically used internally and not configured directly by users.
  When users see `:unset` transformations in their import job, they should replace them
  with appropriate transformations like `:static`, `:column`, etc.

  ## Examples

      # This would be automatically generated
      %{
        argument_name: "name",
        transformation: :unset
      }

      # User should change it to something like:
      %{
        argument_name: "name", 
        transformation: {:column, [column_name: "product_name"]}
      }

  """
  use AshImport.Transformation

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def transform(_input, _opts, context) do
    argument_name = Map.get(context, :current_argument, "unknown")

    {:error,
     "Argument '#{argument_name}' has an unset transformation. Please configure a proper transformation (e.g., :static, :column, :computed) before importing data."}
  end

  @impl true
  def describe(_opts) do
    "Unset (requires configuration)"
  end
end
