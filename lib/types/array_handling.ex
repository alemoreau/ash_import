defmodule AshImport.Types.ArrayHandling do
  @moduledoc """
  Enum type for handling array values in JSON.
  """
  use Ash.Type.Enum,
    values: [:stringify, :join_comma, :first_element, :length]
end
