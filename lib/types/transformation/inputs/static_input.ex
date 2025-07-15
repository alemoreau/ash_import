defmodule AshImport.Transformation.Inputs.Static do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :value, :term do
      public? true
      allow_nil? true
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end
end
