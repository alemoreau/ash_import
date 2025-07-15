defmodule AshImport.Resource.ArgumentMapping do
  @moduledoc """
  Embedded resource representing the mapping between an argument and its transformation.

  This defines how a specific argument of the target resource action will be populated
  from the import data using a transformation pipeline.
  """
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    # The argument name in the target action
    attribute :argument, :string do
      allow_nil? false
      public? true
    end

    # The transformation to apply
    attribute :transformation, AshImport.Resource.Transformation do
      allow_nil? false
      public? true
    end

    # Whether this mapping is required
    attribute :required, :boolean do
      allow_nil? false
      default true
      public? true
    end

    # Description of what this mapping does
    attribute :description, :string do
      allow_nil? true
      public? true
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end
end
