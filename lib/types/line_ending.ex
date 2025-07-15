defmodule AshImport.Types.LineEnding do
  @moduledoc """
  Enum type for line ending styles.
  """
  use Ash.Type.Enum,
    values: [
      lf: "\n",
      crlf: "\r\n",
      cr: "\r"
    ]
end
