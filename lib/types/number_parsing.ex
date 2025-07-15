defmodule AshImport.Types.NumberParsing do
  @moduledoc """
  Enum type for number parsing strategies.
  """
  use Ash.Type.Enum,
    values: [:strict, :lenient, :string_fallback]
end
