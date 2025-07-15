# defmodule AshImport.Transformation.Input do
#   use Ash.Type.NewType,
#     subtype_of: :union,
#     lazy_init?: true,
#     constraints: [
#       types: [
#         column: [
#           tag: :type,
#           tag_value: "column",
#           cast_tag?: false,
#           type: AshImport.Transformation.Input.Column
#         ],
#         static: [
#           tag: :type,
#           tag_value: "static",
#           cast_tag?: false,
#           type: AshImport.Transformation.Inputs.Static
#         ]
#         # transformation: [
#         #   type: AshImport.Resource.Transformation,
#         #   tag: :type,
#         #   tag_value: "transformation"
#         # ]
#       ]
#     ]
# end
defmodule AshImport.Transformation.Input do
  use Ash.Type.NewType,
    subtype_of: :struct,
    constraints: [
      instance_of: AshImport.Resource.Transformation
    ]
end
