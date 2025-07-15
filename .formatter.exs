spark_locals_without_parens = [
  # Domain-level DSL
  include_import_resources?: 1,

  # Resource-level DSL
  import_config: 0,
  import_config: 1,
  belongs_to_actor: 2,
  belongs_to_actor: 3,
  supported_formats: 1,
  create_action: 1,
  batch_size: 1,
  track_progress?: 1,
  store_errors?: 1,
  relationship_opts: 1,
  mixin: 1,
  import_extensions: 1,
  table_name_suffix: 1,
  job_resource_name: 1,
  record_resource_name: 1,

  # Transformations and reducers
  transformations: 0,
  transformations: 1,
  add: 2,

  # Shared options
  allow_nil?: 1,
  attribute_type: 1,
  define_attribute?: 1,
  domain: 1,
  public?: 1
]

[
  import_deps: [:ash],
  locals_without_parens: spark_locals_without_parens,
  export: [
    locals_without_parens: spark_locals_without_parens
  ],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
