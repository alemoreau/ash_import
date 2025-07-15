defmodule AshImport.Resource.Transformers.CreateImportRecordResource do
  @moduledoc "Creates an ImportRecord resource for a given resource"
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  # sobelow_skip ["DOS.StringToAtom", "RCE.CodeModule"]
  def transform(dsl_state) do
    import_record_module = AshImport.Resource.Info.import_record_resource(dsl_state)
    import_job_module = AshImport.Resource.Info.import_job_resource(dsl_state)
    module = Transformer.get_persisted(dsl_state, :module)

    # Get configuration
    import_extensions = AshImport.Resource.Info.import_extensions(dsl_state)
    store_errors? = AshImport.Resource.Info.store_errors?(dsl_state)

    # Check for data layer
    data_layer = import_extensions[:data_layer] || Ash.DataLayer.data_layer(dsl_state)

    {postgres?, sqlite?, parent_table, repo} = get_data_layer_info(dsl_state, data_layer)

    table = get_table_name(dsl_state, parent_table)

    {ets?, private?} = get_ets_info(dsl_state, data_layer)

    # Check for multitenancy
    multitenant? = not is_nil(Ash.Resource.Info.multitenancy_strategy(dsl_state))

    # Get mixin if configured
    mixin = get_mixin(dsl_state)

    # Get primary key attribute from original resource
    destination_attribute = get_primary_key_attribute(dsl_state, module)

    Module.create(
      import_record_module,
      quote do
        use Ash.Resource,
            unquote(
              import_extensions
              |> Keyword.put(:data_layer, data_layer)
              |> Keyword.put(:domain, Ash.Resource.Info.domain(dsl_state))
              |> Keyword.put(:validate_domain_inclusion?, false)
            )

        def import_record?, do: true
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

          Code.eval_quoted(
            quote do
              postgres do
                table(unquote(table))
                repo(unquote(repo))

                references do
                  reference(:import_job, on_delete: :delete)
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

          Code.eval_quoted(
            quote do
              sqlite do
                table(unquote(table))
                repo(unquote(repo))

                references do
                  reference(:import_job, on_delete: :delete)
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

          # Record information
          attribute :row_number, :integer do
            allow_nil? false
            public? true
          end

          attribute :raw_data, :map do
            allow_nil? false
            public? true
          end

          attribute :transformed_data, :map do
            allow_nil? true
            public? true
          end

          # Processing status
          attribute :status, :atom do
            allow_nil? false
            public? true
            default :success
            constraints one_of: [:success, :failed, :skipped]
          end

          # Error tracking
          if unquote(store_errors?) do
            attribute :error_message, :string do
              allow_nil? true
              public? true
            end

            attribute :validation_errors, {:array, :string} do
              allow_nil? false
              public? true
              default []
            end
          end

          # Skip information
          attribute :skip_message, :string do
            allow_nil? true
            public? true
          end

          create_timestamp :inserted_at, public?: true
          update_timestamp :updated_at, public?: true
        end

        actions do
          defaults [:read]

          create :create do
            primary? true

            accept [
              :import_job_id,
              :row_number,
              :raw_data
            ]

            argument :create_action, :atom, default: :create
            argument :transformed_data, :map

            change set_attribute(:status, :success)
            change set_attribute(:transformed_data, arg(:transformed_data))

            change manage_relationship(:transformed_data, :created_record,
                     type: :create,
                     on_no_match: {:create, arg(:create_action)}
                   )
          end

          create :create_failed do
            accept [
              :import_job_id,
              :row_number,
              :raw_data,
              :transformed_data
              | if unquote(store_errors?) do
                  [:error_message, :validation_errors]
                else
                  []
                end
            ]

            change set_attribute(:status, :failed)
          end

          create :skip do
            accept [
              :import_job_id,
              :row_number,
              :raw_data,
              :transformed_data,
              :skip_message
            ]

            change set_attribute(:status, :skipped)
          end

          if unquote(store_errors?) do
            update :set_error do
              accept [:error_message, :validation_errors]

              change set_attribute(:status, :failed)
            end
          end
        end

        relationships do
          belongs_to :import_job, unquote(import_job_module) do
            public? true
            allow_nil? false
            attribute_writable? true
          end

          if unquote(destination_attribute.name) != :id do
            belongs_to :created_record, unquote(module) do
              public? true
              allow_nil? true
              source_attribute :created_record_id
              destination_attribute unquote(destination_attribute.name)
            end
          else
            belongs_to :created_record, unquote(module) do
              public? true
              allow_nil? true
              source_attribute :created_record_id
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

  defp get_table_name(_dsl_state, parent_table) do
    suffix = "_import_records"

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

  def after?(AshImport.Resource.Transformers.CreateImportJobResource), do: true
  def after?(_), do: false
end
