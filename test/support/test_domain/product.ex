defmodule AshImport.Test.Product do
  @moduledoc """
  Test resource for testing AshImport functionality.

  This resource is used in test suites to validate import functionality
  without affecting production resources.
  """
  use Ash.Resource,
    domain: AshImport.Test,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshImport.Resource]

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :description, :string do
      public? true
      allow_nil? true
    end

    attribute :price, :decimal do
      public? true
      allow_nil? false
    end

    attribute :category, :string do
      public? true
      allow_nil? false
    end

    attribute :active, :boolean do
      public? true
      allow_nil? false
      default true
    end
  end

  import_config do
    supported_sources(
      csv: AshImport.Sources.CsvFileSource,
      json: AshImport.Sources.JsonFileSource
    )

    create_actions([:create])
    batch_size 100
    track_progress? true
    store_errors? true
  end

  actions do
    defaults [:read, :update, :destroy, create: :*]
  end
end
