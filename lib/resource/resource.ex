defmodule AshImport.Resource do
  @moduledoc """
  Extension for configuring file imports on an Ash resource.

  This extension automatically generates ImportJob and ImportRecord resources
  to handle CSV and JSON file imports with configurable mappings and transformations.
  """

  @belongs_to_actor %Spark.Dsl.Entity{
    name: :belongs_to_actor,
    describe: """
    Creates a belongs_to relationship for the actor resource on the ImportJob.
    When creating a new import job, if the actor on the action is set and
    matches the resource type, the import job will be related to the actor.
    If your actors are polymorphic or varying types, declare a belongs_to_actor for each type.

    A reference is also created with `on_delete: :nilify` and `on_update: :update`
    """,
    examples: [
      "belongs_to_actor :user, MyApp.Users.User, domain: MyApp.Users"
    ],
    no_depend_modules: [:destination, :domain],
    target: AshImport.Resource.BelongsToActor,
    args: [:name, :destination],
    schema: AshImport.Resource.BelongsToActor.schema()
  }

  @transformations %Spark.Dsl.Section{
    name: :transformations,
    describe: """
    Define custom transformations available for column value processing.
    """,
    entities: [
      %Spark.Dsl.Entity{
        name: :add,
        describe: "Add a custom transformation function",
        examples: [
          "add :parse_phone, MyApp.Transformations.PhoneParser"
        ],
        target: AshImport.Resource.Transformation,
        args: [:name, :module],
        schema: [
          name: [
            type: :atom,
            required: true,
            doc: "The name of the transformation"
          ],
          module: [
            type: :atom,
            required: true,
            doc: "The module containing the transformation logic"
          ]
        ]
      }
    ]
  }

  @import_config %Spark.Dsl.Section{
    name: :import_config,
    describe: """
    A section for configuring how imports work for this resource.
    """,
    entities: [@belongs_to_actor],
    sections: [@transformations],
    schema: [
      supported_sources: [
        type: :keyword_list,
        default: [csv: AshImport.Sources.CsvFileSource, json: AshImport.Sources.JsonFileSource],
        doc: """
        Supported data sources for import as a keyword list of {source_type, source_module} pairs.
        Users can implement custom sources by providing their own modules that implement the source behavior.

        Example:
            supported_sources [
              csv: AshImport.Sources.CsvFileSource,
              json: AshImport.Sources.JsonFileSource,
              api: MyApp.Sources.ApiSource,
              xml: MyApp.Sources.XmlFileSource
            ]
        """
      ],
      create_actions: [
        type: {:list, :atom},
        default: [:create],
        doc:
          "List of actions available for creating records from imports. Users can choose which one to use based on their data."
      ],
      batch_size: [
        type: :integer,
        default: 100,
        doc: "Number of records to process in each batch"
      ],
      track_progress?: [
        type: :boolean,
        default: true,
        doc: "Whether to track import progress"
      ],
      store_errors?: [
        type: :boolean,
        default: true,
        doc: "Whether to store detailed error information for failed records"
      ],
      relationship_opts: [
        type: :keyword_list,
        doc: """
        Options to pass to the has_many :import_jobs relationship that is created on this resource.
        For example, `public?: true` to expose the relationship over graphql.
        See `d:Ash.Resource.Dsl.relationships.has_many`.
        """
      ],
      mixin: [
        type: {:or, [:atom, :mfa]},
        default: nil,
        doc: """
        A module that defines a `using` macro or {module, function, arguments} tuple
        that will be mixed into the generated import resources.
        """
      ],
      import_extensions: [
        type: :keyword_list,
        default: [],
        doc: """
        Extensions that should be used by the generated import resources.
        For example: `extensions: [AshGraphql.Resource], notifier: [Ash.Notifiers.PubSub]`
        """
      ],
      table_name_suffix: [
        type: :string,
        default: "_import_jobs",
        doc: """
        The suffix to use for the import job table name if using a SQL-based data layer
        """
      ],
      job_resource_name: [
        type: :atom,
        doc: """
        Override the name of the generated ImportJob resource. Defaults to {Resource}.ImportJob
        """
      ],
      record_resource_name: [
        type: :atom,
        doc: """
        Override the name of the generated ImportRecord resource. Defaults to {Resource}.ImportRecord
        """
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@import_config],
    transformers: [
      AshImport.Resource.Transformers.ValidateBelongsToActor,
      AshImport.Resource.Transformers.CreateImportJobResource,
      AshImport.Resource.Transformers.CreateImportRecordResource,
      AshImport.Resource.Transformers.RelateImportResources
    ]
end
