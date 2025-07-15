defmodule AshImport.Domain.Transformers.AllowImportResources do
  @moduledoc """
  Configures the domain to allow import resources based on configuration.

  If include_import_resources? is true, sets up the domain to allow all
  ImportJob and ImportRecord resources from resources using AshImport.
  """
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  def transform(dsl_state) do
    if AshImport.Domain.Info.include_import_resources?(dsl_state) do
      resources = Ash.Domain.Info.resources(dsl_state)

      Enum.reduce(resources, {:ok, dsl_state}, fn resource, {:ok, dsl_state} ->
        if AshImport.Resource in Spark.extensions(resource) do
          import_job_resource = AshImport.Resource.Info.import_job_resource(resource)
          import_record_resource = AshImport.Resource.Info.import_record_resource(resource)

          {:ok,
           [import_job_resource, import_record_resource]
           |> Enum.reduce(dsl_state, fn resource, acc ->
             if resource in resources do
               acc
             else
               entity =
                 Transformer.build_entity!(Ash.Domain.Dsl, [:resources], :resource,
                   resource: resource
                 )

               Transformer.add_entity(acc, [:resources], entity)
             end
           end)}
        else
          {:ok, dsl_state}
        end
      end)
    else
      existing_allow_mfa = Ash.Domain.Info.allow(dsl_state)

      {:ok,
       Transformer.set_option(
         dsl_state,
         [:resources],
         :allow,
         {AshImport, :allow_import_resources, [existing_allow_mfa]}
       )}
    end
  end
end
