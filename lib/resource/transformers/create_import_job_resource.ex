defmodule AshImport.Resource.Transformers.CreateImportJobResource do
  @moduledoc "Creates an ImportJob resource for a given resource"
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  # sobelow_skip ["DOS.StringToAtom", "RCE.CodeModule"]
  def transform(dsl_state) do
    import_job_module = AshImport.Resource.Info.import_job_resource(dsl_state)
    module = Transformer.get_persisted(dsl_state, :module)

    # Get configuration
    belongs_to_actors = AshImport.Resource.Info.belongs_to_actor(dsl_state)
    import_extensions = AshImport.Resource.Info.import_extensions(dsl_state)
    track_progress? = AshImport.Resource.Info.track_progress?(dsl_state)
    store_errors? = AshImport.Resource.Info.store_errors?(dsl_state)

    # Get embedded resource modules (unused in current implementation)
    _import_config_module = Module.concat([module, ImportConfig])
    _argument_mapping_module = Module.concat([module, ImportConfig, ArgumentMapping])

    # Check for data layer
    data_layer = import_extensions[:data_layer] || Ash.DataLayer.data_layer(dsl_state)

    {postgres?, sqlite?, parent_table, repo} = get_data_layer_info(dsl_state, data_layer)

    table = get_table_name(dsl_state, parent_table)

    {ets?, private?} = get_ets_info(dsl_state, data_layer)

    # Check for multitenancy
    multitenant? = not is_nil(Ash.Resource.Info.multitenancy_strategy(dsl_state))

    # Get mixin if configured
    mixin = get_mixin(dsl_state)

    # Get primary key info from original resource (unused in current implementation)
    _destination_attribute = get_primary_key_attribute(dsl_state, module)

    Module.create(
      import_job_module,
      quote do
        use Ash.Resource,
            unquote(
              import_extensions
              |> Keyword.put(:data_layer, data_layer)
              |> Keyword.put(:domain, Ash.Resource.Info.domain(dsl_state))
              |> Keyword.put(:validate_domain_inclusion?, false)
            )

        def import_job?, do: true
        def original_resource, do: unquote(module)

        if unquote(multitenant?) do
          multitenancy do
            strategy(unquote(Ash.Resource.Info.multitenancy_strategy(dsl_state)))
            attribute(unquote(Ash.Resource.Info.multitenancy_attribute(dsl_state)))
            global?(unquote(Ash.Resource.Info.multitenancy_global?(dsl_state)))

            parse_attribute(
              unquote(Macro.escape(Ash.Resource.Info.multitenancy_parse_attribute(dsl_state)))
            )
          end
        end

        if unquote(postgres?) do
          table = unquote(table)
          repo = unquote(repo)
          belongs_to_actors = unquote(Macro.escape(belongs_to_actors))

          Code.eval_quoted(
            quote do
              postgres do
                table(unquote(table))
                repo(unquote(repo))

                references do
                  for actor_relationship <- unquote(Macro.escape(belongs_to_actors)) do
                    if actor_relationship.define_attribute? do
                      reference(actor_relationship.name, on_delete: :nilify, on_update: :update)
                    end
                  end
                end
              end
            end,
            [],
            __ENV__
          )
        end

        if unquote(sqlite?) do
          table = unquote(table)
          repo = unquote(repo)
          belongs_to_actors = unquote(Macro.escape(belongs_to_actors))

          Code.eval_quoted(
            quote do
              sqlite do
                table(unquote(table))
                repo(unquote(repo))

                references do
                  for actor_relationship <- unquote(Macro.escape(belongs_to_actors)) do
                    if actor_relationship.define_attribute? do
                      reference(actor_relationship.name, on_delete: :nilify, on_update: :update)
                    end
                  end
                end
              end
            end,
            [],
            __ENV__
          )
        end

        if unquote(ets?) do
          private? = unquote(private?)

          Code.eval_quoted(
            quote do
              ets do
                private?(unquote(private?))
              end
            end,
            [],
            __ENV__
          )
        end

        attributes do
          uuid_primary_key :id

          # Source information
          attribute :source_type, :atom do
            allow_nil? false
            public? true
            constraints one_of: unquote(AshImport.Resource.Info.supported_source_types(dsl_state))
            description "Type of data source (csv, json, etc.)"
          end

          # Source configuration for file processing
          attribute :source_config, :map do
            allow_nil? false
            public? true
            default %{}

            description "Configuration for the source file processing including delimiters, headers, paths, etc."
          end

          attribute :argument_mappings, {:array, AshImport.Resource.ArgumentMapping} do
            allow_nil? false
            public? true
            default []
          end

          # Configuration for transformation processing
          attribute :transformation_config, :map do
            allow_nil? false
            public? true
            default %{}

            description "Configuration for transformation processing including batch settings, error handling, etc."
          end

          # Status and progress - managed by state machine
          attribute :status, :atom do
            allow_nil? false
            public? true
            default :pending
          end

          if unquote(track_progress?) do
            attribute :total_records, :integer do
              allow_nil? true
              public? true
            end

            attribute :estimated_records, :integer do
              allow_nil? true
              public? true
            end

            attribute :processed_records, :integer do
              allow_nil? false
              public? true
              default 0
            end

            attribute :successful_records, :integer do
              allow_nil? false
              public? true
              default 0
            end

            attribute :failed_records, :integer do
              allow_nil? false
              public? true
              default 0
            end

            attribute :skipped_records, :integer do
              allow_nil? false
              public? true
              default 0
            end
          end

          attribute :parsing_failed_records, :integer do
            allow_nil? true
            public? true
          end

          # Preview data - sample records from the file
          attribute :sample, {:array, :map} do
            allow_nil? false
            public? true
            default []
            description "Sample records from the file for preview before import"
          end

          # Column information extracted during analysis
          attribute :column_names, {:array, :string} do
            allow_nil? false
            public? true
            default []
            description "Column names detected from the file (CSV headers or JSON keys)"
          end

          # Timing
          attribute :started_at, :utc_datetime_usec do
            allow_nil? true
            public? true
          end

          attribute :completed_at, :utc_datetime_usec do
            allow_nil? true
            public? true
          end

          # Error tracking
          if unquote(store_errors?) do
            attribute :error_message, :string do
              allow_nil? true
              public? true
            end

            attribute :processing_errors, {:array, :string} do
              allow_nil? false
              public? true
              default []
            end
          end

          # User inputs for mappings
          attribute :user_inputs, :map do
            allow_nil? false
            public? true
            default %{}
          end

          # Oban job tracking
          attribute :oban_job_id, :integer do
            allow_nil? true
            public? false
          end

          create_timestamp :inserted_at, public?: true
          update_timestamp :updated_at, public?: true
        end

        actions do
          defaults [:read]

          create :create do
            primary? true

            accept [
              :source_type,
              :source_config,
              :transformation_config
            ]

            change {AshImport.Resource.Changes.PreviewSource,
                    [
                      supported_source_types:
                        unquote(AshImport.Resource.Info.supported_sources(dsl_state))
                    ]}
          end

          update :configure_mappings do
            primary? true
            # TODO
            require_atomic? false
            accept [:argument_mappings]

            validate {AshImport.Resource.Validations.ValidateMappings, []}
          end

          update :provide_user_inputs do
            accept [:user_inputs]
          end

          update :update_source_config do
            require_atomic? false
            accept [:source_type, :source_config]

            change {AshImport.Resource.Changes.PreviewSource,
                    [
                      supported_source_types:
                        unquote(AshImport.Resource.Info.supported_sources(dsl_state))
                    ]}
          end

          update :start do
            # TODO
            require_atomic? false

            accept []

            validate {AshImport.Resource.Validations.ValidateMappingsConfigured, []}

            change set_attribute(:status, :processing)
            change set_attribute(:started_at, &DateTime.utc_now/0)
            change {AshImport.Resource.Changes.StartImportJob, []}
          end

          update :cancel do
            # TODO
            require_atomic? false

            accept []

            validate one_of(:status, [:pending, :processing])

            change set_attribute(:status, :cancelled)
            change {AshImport.Resource.Changes.CancelImportJob, []}
          end

          update :retry do
            # TODO
            require_atomic? false
            accept []

            validate one_of(:status, [:failed, :cancelled])

            change set_attribute(:status, :pending)
            change set_attribute(:started_at, nil)
            change set_attribute(:completed_at, nil)

            if unquote(track_progress?) do
              change set_attribute(:processed_records, 0)
              change set_attribute(:successful_records, 0)
              change set_attribute(:failed_records, 0)
              change set_attribute(:skipped_records, 0)
            end

            if unquote(store_errors?) do
              change set_attribute(:error_message, nil)
              change set_attribute(:processing_errors, [])
            end

            change {AshImport.Resource.Changes.RetryImportJob, []}
          end

          # Internal actions for progress tracking
          if unquote(track_progress?) do
            update :update_progress do
              # TODO: use expr
              require_atomic? false

              accept [
                :processed_records,
                :successful_records,
                :failed_records,
                :skipped_records
              ]

              change {AshImport.Resource.Changes.CheckCompletion, []}
            end
          end

          update :mark_completed do
            # TODO
            require_atomic? false

            accept []

            validate one_of(:status, [:processing])

            change set_attribute(:status, :completed)
            change set_attribute(:completed_at, &DateTime.utc_now/0)
          end

          update :mark_failed do
            # TODO
            require_atomic? false

            accept []

            argument :error, :string do
              allow_nil? false
            end

            validate one_of(:status, [:pending, :processing])

            change set_attribute(:status, :failed)
            change set_attribute(:completed_at, &DateTime.utc_now/0)

            if unquote(store_errors?) do
              change set_attribute(:error_message, arg(:error))
            end
          end
        end

        relationships do
          has_many :import_records,
                   unquote(AshImport.Resource.Info.import_record_resource(dsl_state)) do
            public? true
            destination_attribute :import_job_id
          end

          # has_many :failed_import_records, unquote(AshImport.Resource.Info.import_record_resource(dsl_state)) do
          #   public? true
          #   destination_attribute :import_job_id
          #   filter expr(status == :failed)
          # end

          for actor_relationship <- unquote(Macro.escape(belongs_to_actors)) do
            belongs_to actor_relationship.name, actor_relationship.destination do
              domain(actor_relationship.domain)
              define_attribute?(actor_relationship.define_attribute?)
              allow_nil?(actor_relationship.allow_nil?)
              attribute_type(actor_relationship.attribute_type)
              public?(actor_relationship.public?)
              attribute_writable?(true)
            end
          end
        end

        calculations do
          calculate :progress_percentage, :float do
            calculation fn records, _ ->
              records
              |> Enum.map(fn record ->
                if record.total_records && record.total_records > 0 do
                  record.processed_records / record.total_records * 100
                else
                  0.0
                end
              end)
            end
          end
        end

        unquote(mixin)
      end,
      Macro.Env.location(__ENV__)
    )

    {:ok, dsl_state}
  end

  defp get_data_layer_info(dsl_state, data_layer) do
    cond do
      data_layer == AshPostgres.DataLayer ->
        {true, false, apply(AshPostgres, :table, [dsl_state]),
         apply(AshPostgres, :repo, [dsl_state])}

      data_layer == AshSqlite.DataLayer ->
        {false, true, apply(AshSqlite.DataLayer.Info, :table, [dsl_state]),
         apply(AshSqlite.DataLayer.Info, :repo, [dsl_state])}

      true ->
        {false, false, nil, nil}
    end
  end

  defp get_table_name(dsl_state, parent_table) do
    suffix = AshImport.Resource.Info.table_name_suffix(dsl_state)

    case parent_table do
      table when is_binary(table) -> table <> suffix
      _ -> nil
    end
  end

  defp get_ets_info(dsl_state, data_layer) do
    if data_layer == Ash.DataLayer.Ets do
      {true, Ash.DataLayer.Ets.Info.private?(dsl_state)}
    else
      {false, nil}
    end
  end

  defp get_mixin(dsl_state) do
    case AshImport.Resource.Info.mixin(dsl_state) do
      {m, f, a} ->
        apply(m, f, a)

      nil ->
        quote do
        end

      module when is_atom(module) ->
        quote do
          use unquote(module)
        end
    end
  end

  defp get_primary_key_attribute(dsl_state, _module) do
    case Ash.Resource.Info.primary_key(dsl_state) do
      [key] ->
        Ash.Resource.Info.attribute(dsl_state, key)

      keys ->
        raise Spark.Error.DslError,
          module: Transformer.get_persisted(dsl_state, :module),
          path: [:extensions, AshImport.Resource],
          message: """
          Resources with composite primary keys are not currently supported. Got keys #{inspect(keys)}
          """
    end
  end

  def after?(AshImport.Resource.Transformers.CreateEmbeddedResources), do: true
  def after?(_), do: false
end
