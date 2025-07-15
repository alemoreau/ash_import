defmodule AshImport.EmbeddedResources.JsonParsingConfig do
  @moduledoc """
  Configuration for JSON parsing options.
  """
  use Ash.Resource, data_layer: :embedded

  attributes do
    # Root path configuration
    attribute :json_root_path, :string do
      allow_nil? true
      public? true
      description "JSONPath to the array of records (e.g., 'data.items')"
    end

    # Encoding configuration
    attribute :file_encoding, AshImport.Types.FileEncoding do
      allow_nil? false
      public? true
      default :utf8
      description "File encoding (e.g., utf-8, latin1, cp1252)"
    end

    # Parsing configuration
    attribute :flatten_nested?, :boolean do
      allow_nil? false
      public? true
      default false
      description "Whether to flatten nested objects into dot-notation keys"
    end

    attribute :array_handling, AshImport.Types.ArrayHandling do
      allow_nil? false
      public? true
      default :stringify
      description "How to handle array values in JSON"
    end

    attribute :null_value_handling, AshImport.Types.EmptyValueHandling do
      allow_nil? false
      public? true
      default :as_nil
      description "How to handle null values in JSON"
    end

    # Schema validation
    attribute :validate_schema?, :boolean do
      allow_nil? false
      public? true
      default false
      description "Whether to validate JSON against expected schema"
    end

    attribute :required_fields, {:array, :string} do
      allow_nil? false
      public? true
      default []
      description "List of required fields that must be present in each record"
    end

    # Date parsing configuration
    attribute :date_formats, {:array, :string} do
      allow_nil? false
      public? true
      default ["{ISO:Extended}", "{RFC3339}", "{YYYY}-{0M}-{0D}"]
      description "List of date formats to try when parsing date strings"
    end

    # Number parsing configuration
    attribute :number_parsing, AshImport.Types.NumberParsing do
      allow_nil? false
      public? true
      default :strict
      description "How to parse numbers from strings"
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :json_root_path,
        :file_encoding,
        :flatten_nested?,
        :array_handling,
        :null_value_handling,
        :validate_schema?,
        :required_fields,
        :date_formats,
        :number_parsing
      ]
    end

    update :update do
      primary? true

      accept [
        :json_root_path,
        :file_encoding,
        :flatten_nested?,
        :array_handling,
        :null_value_handling,
        :validate_schema?,
        :required_fields,
        :date_formats,
        :number_parsing
      ]
    end
  end
end
