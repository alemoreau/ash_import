defmodule AshImport.EmbeddedResources.CsvParsingConfig do
  @moduledoc """
  Configuration for CSV parsing options.
  """
  use Ash.Resource, data_layer: :embedded

  attributes do
    # Delimiter configuration
    attribute :detected_delimiter, :string do
      allow_nil? true
      public? true
      description "The delimiter detected or configured for the CSV file"
    end

    attribute :default_delimiter, AshImport.Types.CsvDelimiter do
      allow_nil? false
      public? true
      default :comma
      description "Default delimiter to use if detection fails"
    end

    attribute :detect_delimiter?, :boolean do
      allow_nil? false
      public? true
      default true
      description "Whether to auto-detect the delimiter from the file content"
    end

    # Header configuration
    attribute :has_headers?, :boolean do
      allow_nil? false
      public? true
      default true
      description "Whether the CSV file has a header row"
    end

    attribute :skip_rows, :integer do
      allow_nil? false
      public? true
      default 0
      description "Number of rows to skip at the beginning of the file"
      constraints min: 0
    end

    # Encoding configuration
    attribute :file_encoding, AshImport.Types.FileEncoding do
      allow_nil? false
      public? true
      default :utf8
      description "File encoding (e.g., utf-8, latin1, cp1252)"
    end

    # Quote configuration
    attribute :quote_char, :string do
      allow_nil? false
      public? true
      default "\""
      description "Character used for quoting fields"
      constraints max_length: 1
    end

    attribute :escape_char, :string do
      allow_nil? true
      public? true
      description "Character used for escaping quotes (defaults to quote_char)"
      constraints max_length: 1
    end

    # Line ending configuration
    attribute :line_ending, AshImport.Types.LineEnding do
      allow_nil? true
      public? true
      description "Line ending style (auto-detected if nil)"
    end

    # Parsing configuration
    attribute :trim_fields?, :boolean do
      allow_nil? false
      public? true
      default false
      description "Whether to trim whitespace from field values"
    end

    attribute :empty_value_handling, AshImport.Types.EmptyValueHandling do
      allow_nil? false
      public? true
      default :as_nil
      description "How to handle empty field values"
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :detected_delimiter,
        :default_delimiter,
        :detect_delimiter?,
        :has_headers?,
        :skip_rows,
        :file_encoding,
        :quote_char,
        :escape_char,
        :line_ending,
        :trim_fields?,
        :empty_value_handling
      ]
    end

    update :update do
      primary? true

      accept [
        :detected_delimiter,
        :default_delimiter,
        :detect_delimiter?,
        :has_headers?,
        :skip_rows,
        :file_encoding,
        :quote_char,
        :escape_char,
        :line_ending,
        :trim_fields?,
        :empty_value_handling
      ]
    end
  end
end
