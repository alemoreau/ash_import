defmodule AshImport.Resource.TransformationTest do
  @moduledoc """
  Tests for AshImport.Resource.Transformation embedded resource.
  """
  use ExUnit.Case, async: true

  alias AshImport.Resource.Transformation

  describe "AshImport.Resource.Transformation" do
    test "can create transformation with module only" do
      changeset =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :get_value,
          module: AshImport.Transformation.GetValue
        })

      assert changeset.valid?
      assert Ash.Changeset.get_attribute(changeset, :module) == AshImport.Transformation.GetValue
      assert Ash.Changeset.get_attribute(changeset, :inputs) == []
      assert Ash.Changeset.get_attribute(changeset, :options) == %{}
    end

    test "can create transformation with column input" do
      # Create transformation with the column input
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :trim,
          module: AshImport.Transformation.Trim,
          inputs: [%{type: "column", name: "test_column"}]
        })
        |> Ash.create()

      assert transformation.name == :trim
      assert length(transformation.inputs) == 1

      input = List.first(transformation.inputs)
      assert input.type == :column
      assert input.value.name == "test_column"
    end

    test "can create nested transformation structure" do
      {:ok, inner_transformation} =
        Transformation
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: :concat,
            module: AshImport.Transformation.Concat,
            inputs: [
              %{type: "column", name: "first_name"},
              %{type: "column", name: "last_name"}
            ]
          }
        )
        |> Ash.create()

      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :join,
          module: AshImport.Transformation.Join,
          inputs: [
            %{type: "static", value: "Hello"},
            inner_transformation
          ],
          options: %{"separator" => " "}
        })
        |> Ash.create()

      assert transformation.name == :join
      assert length(transformation.inputs) == 2
      assert transformation.options["separator"] == " "

      # Verify the nested structure
      transformation_input =
        Enum.find(transformation.inputs, &(&1.type == :transformation)).value

      assert transformation_input.name == :concat
      assert length(transformation_input.inputs) == 2
    end

    test "supports custom transformation with options" do
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :custom,
          module: AshImport.Transformation.Custom,
          inputs: [%{type: "column", name: "product_code"}],
          options: %{
            "module" => "MyModule",
            "function" => "add_prefix",
            "args" => ["PROD-"]
          }
        })
        |> Ash.create()

      assert transformation.name == :custom
      assert transformation.options["module"] == "MyModule"
      assert transformation.options["function"] == "add_prefix"
      assert transformation.options["args"] == ["PROD-"]
    end

    test "multiple column inputs for join transformations" do
      # Create multiple column inputs
      inputs =
        for name <- ["city", "state", "country"] do
          %{type: "column", name: name}
        end

      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :join,
          module: AshImport.Transformation.Join,
          inputs: inputs,
          options: %{"separator" => ", "}
        })
        |> Ash.create()

      assert transformation.name == :join
      assert length(transformation.inputs) == 3
      assert transformation.options["separator"] == ", "

      # Verify all inputs are column types
      assert Enum.all?(transformation.inputs, &(&1.type == :column))

      # Verify input names
      input_names = Enum.map(transformation.inputs, & &1.value.name)
      assert "city" in input_names
      assert "state" in input_names
      assert "country" in input_names
    end

    test "handles complex nested transformation chains" do
      # Create parse transformations
      {:ok, parse_price} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :parse_float,
          module: AshImport.Transformation.ParseFloat,
          inputs: [%{type: "column", name: "price"}]
        })
        |> Ash.create()

      {:ok, parse_tax} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :parse_float,
          module: AshImport.Transformation.ParseFloat,
          inputs: [%{type: "column", name: "tax"}]
        })
        |> Ash.create()

      {:ok, parse_shipping} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :parse_float,
          module: AshImport.Transformation.ParseFloat,
          inputs: [%{type: "column", name: "shipping"}]
        })
        |> Ash.create()

      # Create sum transformation that uses all parsed values
      {:ok, total_transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :sum,
          module: AshImport.Transformation.Sum,
          inputs: [
            parse_price,
            parse_tax,
            parse_shipping
          ]
        })
        |> Ash.create()

      assert total_transformation.name == :sum
      assert length(total_transformation.inputs) == 3

      # Verify all inputs are transformation types
      assert Enum.all?(total_transformation.inputs, &(&1.type == :transformation))

      # Verify the nested transformations
      names = Enum.map(total_transformation.inputs, & &1.value.name)
      assert :parse_float in names
      assert Enum.count(names, &(&1 == :parse_float)) == 3
    end

    test "can create and persist complex transformation structure" do
      # Test that the full structure can be created and retrieved
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :trim,
          module: AshImport.Transformation.Trim,
          inputs: [%{type: "column", name: "full_name"}],
          options: %{"description" => "Clean up name field"}
        })
        |> Ash.create()

      # Verify structure is maintained
      assert transformation.name == :trim
      assert length(transformation.inputs) == 1
      assert transformation.options["description"] == "Clean up name field"

      input = List.first(transformation.inputs)
      assert input.type == :column
      assert input.value.name == "full_name"
    end
  end

  describe "TransformationInput union type behavior" do
    test "handles column input type correctly" do
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :get_value,
          module: AshImport.Transformation.GetValue,
          inputs: [%{type: "column", name: "test_field"}]
        })
        |> Ash.create()

      input = List.first(transformation.inputs)
      assert input.type == :column
      assert input.value.name == "test_field"
    end

    test "handles transformation input type correctly" do
      # Create a nested transformation
      {:ok, inner_transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :trim,
          module: AshImport.Transformation.Trim,
          inputs: [%{type: "column", name: "inner_field"}]
        })
        |> Ash.create()

      # Use the inner transformation as an input
      {:ok, outer_transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :upcase,
          module: AshImport.Transformation.Upcase,
          inputs: [inner_transformation]
        })
        |> Ash.create()

      input = List.first(outer_transformation.inputs)
      assert input.type == :transformation
      assert is_struct(input.value, Transformation)
      assert input.value.name == :trim
    end

    test "validates union type constraints" do
      # Test that invalid union types are rejected
      changeset =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :get_value,
          module: AshImport.Transformation.GetValue,
          inputs: [%{type: "invalid_type", value: "some_value"}]
        })

      # This should fail validation due to invalid union type
      assert {:error, _} = Ash.create(changeset)
    end
  end

  describe "integration with ArgumentMapping" do
    test "can be used in argument mapping structure" do
      # This tests that the Transformation can be properly integrated
      # with ArgumentMapping once that's updated to use it

      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :downcase,
          module: AshImport.Transformation.Downcase,
          inputs: [%{type: "column", name: "email_address"}]
        })
        |> Ash.create()

      # Verify the transformation is properly structured for use in ArgumentMapping
      assert transformation.name == :downcase
      assert length(transformation.inputs) == 1

      input = List.first(transformation.inputs)
      assert input.type == :column
      assert input.value.name == "email_address"
    end
  end
end
