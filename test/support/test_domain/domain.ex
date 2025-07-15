defmodule AshImport.Test do
  @moduledoc """
  Debug/test domain for testing AshImport functionality.

  This domain provides a sandbox for testing import functionality
  without affecting production domains.
  """
  use Ash.Domain,
    extensions: [AshImport.Domain]

  resources do
    resource AshImport.Test.Product
  end

  import_config do
    include_import_resources? true
  end
end
