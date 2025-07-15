defmodule AshImport.Resource.Transformation do
  @moduledoc """
  """
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :name, :atom do
      allow_nil? false
      public? true
    end

    attribute :module, :atom do
      allow_nil? false
      public? true
    end

    # Configuration options for operations
    attribute :options, :map do
      allow_nil? false
      default %{}
      public? true
    end

    # Array of nested transformation configs (for inputs or nested transformations)
    # attribute :inputs, {:array, AshImport.Transformation.Input} do
    #   allow_nil? false
    #   default []
    #   public? true
    # end
    attribute :inputs, {:array, :union} do
      allow_nil? false
      default []
      public? true

      constraints items: [
                    types: [
                      column: [
                        tag: :type,
                        tag_value: "column",
                        cast_tag?: false,
                        type: AshImport.Transformation.Input.Column
                      ],
                      static: [
                        tag: :type,
                        tag_value: "static",
                        cast_tag?: false,
                        type: AshImport.Transformation.Inputs.Static
                      ],
                      transformation: [
                        type: :struct,
                        constraints: [
                          instance_of: AshImport.Resource.Transformation
                        ]
                      ]
                    ]
                  ]
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end
end
