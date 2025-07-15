defmodule AshImport.Resource.ArgumentMappingTest do
  @moduledoc """
  Tests for ArgumentMapping embedded resource used in transformation pipelines.
  """
  use ExUnit.Case, async: true

  alias AshImport.Resource.{ArgumentMapping, Transformation}

  describe "ArgumentMapping" do
    test "validates argument name is required" do
      # Create a valid Transformation first
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :get_value,
          module: AshImport.Transformation.GetValue,
          inputs: [%{type: "column", name: "test_column"}]
        })
        |> Ash.create()

      # Valid
      changeset =
        ArgumentMapping
        |> Ash.Changeset.for_create(:create, %{
          argument: "name",
          transformation: transformation
        })

      assert changeset.valid?
      assert Ash.Changeset.get_attribute(changeset, :argument) == "name"
      # default
      assert Ash.Changeset.get_attribute(changeset, :required) == true

      # Invalid - empty argument
      invalid_changeset =
        ArgumentMapping
        |> Ash.Changeset.for_create(:create, %{
          argument: "",
          transformation: transformation
        })

      refute invalid_changeset.valid?
    end

    test "allows optional mappings" do
      # Create a valid Transformation first
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :get_value,
          module: AshImport.Transformation.GetValue,
          inputs: [%{type: "column", name: "test_column"}]
        })
        |> Ash.create()

      changeset =
        ArgumentMapping
        |> Ash.Changeset.for_create(:create, %{
          argument: "optional_field",
          transformation: transformation,
          required: false,
          description: "Optional field mapping"
        })

      assert changeset.valid?
      assert Ash.Changeset.get_attribute(changeset, :required) == false
      assert Ash.Changeset.get_attribute(changeset, :description) == "Optional field mapping"
    end
  end

  describe "complex transformation structures" do
    test "can build transformation with multiple inputs" do
      # Create a join transformation with column and static inputs
      {:ok, join_transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :join,
          module: AshImport.Transformation.Join,
          inputs: [
            %{type: "column", name: "first_name"},
            %{type: "column", name: "last_name"},
            %{type: "static", value: "imported"}
          ],
          options: %{"separator" => " - "}
        })
        |> Ash.create()

      # Create the argument mapping
      {:ok, mapping} =
        ArgumentMapping
        |> Ash.Changeset.for_create(:create, %{
          argument: "full_name_with_tag",
          transformation: join_transformation,
          required: true,
          description: "Combines first name, last name, and adds 'imported' tag"
        })
        |> Ash.create()

      # Verify the structure
      assert mapping.argument == "full_name_with_tag"
      assert mapping.transformation.module == AshImport.Transformation.Join
      assert length(mapping.transformation.inputs) == 3
      assert mapping.required == true
      assert mapping.description == "Combines first name, last name, and adds 'imported' tag"

      # Verify inputs
      inputs = mapping.transformation.inputs
      column_inputs = Enum.filter(inputs, &(&1.type == :column))
      static_inputs = Enum.filter(inputs, &(&1.type == :static))

      assert length(column_inputs) == 2
      assert length(static_inputs) == 1

      # Check specific inputs
      assert Enum.any?(column_inputs, &(&1.value.name == "first_name"))
      assert Enum.any?(column_inputs, &(&1.value.name == "last_name"))
      assert Enum.any?(static_inputs, &(&1.value.value == "imported"))
    end

    test "can create transformation with parse operations" do
      # Create a transformation that parses a price column as float
      {:ok, parse_transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :parse_float,
          module: AshImport.Transformation.ParseFloat,
          inputs: [%{type: "column", name: "price_string"}]
        })
        |> Ash.create()

      # Create the argument mapping
      {:ok, mapping} =
        ArgumentMapping
        |> Ash.Changeset.for_create(:create, %{
          argument: "price",
          transformation: parse_transformation,
          required: true
        })
        |> Ash.create()

      # Verify the structure
      assert mapping.argument == "price"
      assert mapping.transformation.module == AshImport.Transformation.ParseFloat
      assert length(mapping.transformation.inputs) == 1

      # Verify the input
      input = List.first(mapping.transformation.inputs)
      assert input.type == :column
      assert input.value.name == "price_string"
    end
  end
end
