defmodule AshImport.Types.EmptyValueHandling do
  @moduledoc """
  Enum type for handling empty field values.
  """
  use Ash.Type.Enum,
    values: [:as_nil, :as_empty_string, :skip_field]
end
