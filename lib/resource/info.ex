defmodule AshImport.Resource.Info do
  @moduledoc "Introspection helpers for `AshImport.Resource`"

  @spec supported_sources(Spark.Dsl.t() | Ash.Resource.t()) :: Keyword.t()
  def supported_sources(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:import_config], :supported_sources,
      csv: AshImport.Sources.CsvFileSource,
      json: AshImport.Sources.JsonFileSource
    )
  end

  @spec supported_source_types(Spark.Dsl.t() | Ash.Resource.t()) :: list(atom)
  def supported_source_types(resource) do
    resource
    |> supported_sources()
    |> Keyword.keys()
  end

  @spec create_actions(Spark.Dsl.t() | Ash.Resource.t()) :: list(atom)
  def create_actions(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:import_config], :create_actions, [:create])
  end

  @spec create_action(Spark.Dsl.t() | Ash.Resource.t()) :: atom
  @deprecated "Use create_actions/1 instead. This function returns the first action from the list for backwards compatibility."
  def create_action(resource) do
    resource
    |> create_actions()
    |> List.first(:create)
  end

  @spec batch_size(Spark.Dsl.t() | Ash.Resource.t()) :: integer
  def batch_size(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:import_config], :batch_size, 100)
  end

  @spec track_progress?(Spark.Dsl.t() | Ash.Resource.t()) :: boolean
  def track_progress?(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:import_config], :track_progress?, true)
  end

  @spec store_errors?(Spark.Dsl.t() | Ash.Resource.t()) :: boolean
  def store_errors?(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:import_config], :store_errors?, true)
  end

  @spec relationship_opts(Spark.Dsl.t() | Ash.Resource.t()) :: Keyword.t()
  def relationship_opts(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:import_config], :relationship_opts, [])
  end

  @spec mixin(Spark.Dsl.t() | Ash.Resource.t()) :: {module, atom, list} | module | nil
  def mixin(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:import_config], :mixin, nil)
  end

  @spec import_extensions(Spark.Dsl.t() | Ash.Resource.t()) :: Keyword.t()
  def import_extensions(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:import_config], :import_extensions, [])
  end

  @spec table_name_suffix(Spark.Dsl.t() | Ash.Resource.t()) :: String.t()
  def table_name_suffix(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:import_config], :table_name_suffix, "_import_jobs")
  end

  @spec job_resource_name(Spark.Dsl.t() | Ash.Resource.t()) :: atom | nil
  def job_resource_name(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:import_config], :job_resource_name, nil)
  end

  @spec record_resource_name(Spark.Dsl.t() | Ash.Resource.t()) :: atom | nil
  def record_resource_name(resource) do
    Spark.Dsl.Extension.get_opt(resource, [:import_config], :record_resource_name, nil)
  end

  @spec belongs_to_actor(Spark.Dsl.t() | Ash.Resource.t()) :: [
          AshImport.Resource.BelongsToActor.t()
        ]
  def belongs_to_actor(resource) do
    Spark.Dsl.Extension.get_entities(resource, [:import_config])
    |> Enum.filter(fn
      %AshImport.Resource.BelongsToActor{} -> true
      _ -> false
    end)
  end

  @spec transformations(Spark.Dsl.t() | Ash.Resource.t()) :: map
  def transformations(resource) do
    resource
    |> Spark.Dsl.Extension.get_entities([:import_config, :transformations])
    |> Map.new(&{&1.name, &1.module})
  end

  @spec import_job_resource(Spark.Dsl.t() | Ash.Resource.t()) :: Ash.Resource.t()
  def import_job_resource(resource) do
    case job_resource_name(resource) do
      nil ->
        if is_atom(resource) do
          Module.concat([resource, ImportJob])
        else
          Module.concat([Spark.Dsl.Extension.get_persisted(resource, :module), ImportJob])
        end

      name ->
        name
    end
  end

  @spec import_record_resource(Spark.Dsl.t() | Ash.Resource.t()) :: Ash.Resource.t()
  def import_record_resource(resource) do
    case record_resource_name(resource) do
      nil ->
        if is_atom(resource) do
          Module.concat([resource, ImportRecord])
        else
          Module.concat([Spark.Dsl.Extension.get_persisted(resource, :module), ImportRecord])
        end

      name ->
        name
    end
  end
end
