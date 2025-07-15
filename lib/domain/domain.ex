defmodule AshImport.Domain do
  @moduledoc """
  Extension for automatically including import resources in a domain.

  When `include_import_resources?` is set to true, this extension will
  automatically include all ImportJob and ImportRecord resources from
  resources that use the AshImport.Resource extension.
  """

  @import_config %Spark.Dsl.Section{
    name: :import_config,
    describe: """
    A section for configuring import behavior at the domain level.
    """,
    schema: [
      include_import_resources?: [
        type: :boolean,
        default: false,
        doc: "Automatically include all import job and record resources in the domain."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    transformers: [
      AshImport.Domain.Transformers.AllowImportResources
    ],
    sections: [@import_config]
end
