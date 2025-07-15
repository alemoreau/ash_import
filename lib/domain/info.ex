defmodule AshImport.Domain.Info do
  @moduledoc "Introspection helpers for `AshImport.Domain`"

  @spec include_import_resources?(Spark.Dsl.t() | Ash.Domain.t()) :: boolean
  def include_import_resources?(domain) do
    Spark.Dsl.Extension.get_opt(domain, [:import_config], :include_import_resources?, false)
  end
end
