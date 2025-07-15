defmodule AshImport.Types.CsvDelimiter do
  @moduledoc """
  Enum type for CSV delimiters.
  """
  use Ash.Type.Enum,
    values: [
      comma: ",",
      semicolon: ";",
      tab: "\t",
      pipe: "|"
    ]
end
