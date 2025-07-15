defmodule AshImport.Types.FileEncoding do
  @moduledoc """
  Enum type for file encodings.
  """
  use Ash.Type.Enum,
    values: [
      utf8: "utf-8",
      latin1: "latin1",
      cp1252: "cp1252",
      iso8859_1: "iso-8859-1"
    ]
end
