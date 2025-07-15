defmodule AshImport.Resource.Transformers.RelateImportResources do
  @moduledoc "Relates the resource to its created import resources"
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  def transform(dsl_state) do
    with {:ok, source_attribute} <- validate_source_attribute(dsl_state),
         {:ok, relationship} <- build_has_many(dsl_state, source_attribute) do
      {:ok,
       Transformer.add_entity(dsl_state, [:relationships], %{
         relationship
         | source: Transformer.get_persisted(dsl_state, :module)
       })}
    else
      {:error, message} ->
        {:error,
         Spark.Error.DslError.exception(
           module: Transformer.get_persisted(dsl_state, :module),
           path: [:extensions, AshImport.Resource],
           message: message
         )}
    end
  end

  def before?(Ash.Resource.Transformers.SetRelationshipSource), do: true
  def before?(_), do: false

  def after?(AshImport.Resource.Transformers.CreateImportRecordResource), do: true
  def after?(_), do: false

  defp validate_source_attribute(dsl_state) do
    case Ash.Resource.Info.primary_key(dsl_state) do
      [key] ->
        {:ok, key}

      keys ->
        {:error,
         "Only resources with a single primary key are currently supported. Got keys #{inspect(keys)}"}
    end
  end

  defp build_has_many(dsl_state, _source_attribute) do
    default_opts = [
      name: :import_jobs,
      destination: AshImport.Resource.Info.import_job_resource(dsl_state),
      # Import jobs don't directly belong to the source resource
      # They are independent entities that reference the resource type
      destination_attribute: nil,
      source_attribute: nil,
      read_action: :read,
      no_attributes?: true
    ]

    opts =
      default_opts
      |> Keyword.merge(AshImport.Resource.Info.relationship_opts(dsl_state))

    # For now, we'll create a simpler relationship without direct foreign key
    # Import jobs are discovered by querying with resource type filters
    Transformer.build_entity(
      Ash.Resource.Dsl,
      [:relationships],
      :has_many,
      opts
    )
  end
end
