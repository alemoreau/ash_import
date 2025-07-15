defmodule AshImport.Resource.ColumnInput do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :name, :string do
      public? true
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end
end
