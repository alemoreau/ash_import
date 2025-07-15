defmodule AshImport.TransformationExecutorTest do
  @moduledoc """
  Tests for the TransformationExecutor module.
  """
  use ExUnit.Case, async: true

  alias AshImport.TransformationExecutor
  alias AshImport.Resource.Transformation

  describe "single input operations" do
    test "get_value returns the input value" do
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :get_value,
          module: AshImport.Transformation.GetValue,
          inputs: [%{type: "column", name: "test_column"}]
        })
        |> Ash.create()

      raw_data = %{"test_column" => "test_value"}
      assert {:ok, "test_value"} = TransformationExecutor.execute(transformation, raw_data, %{})
    end

    test "trim removes whitespace" do
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :trim,
          module: AshImport.Transformation.Trim,
          inputs: [%{type: "column", name: "name"}]
        })
        |> Ash.create()

      raw_data = %{"name" => "  John Doe  "}
      assert {:ok, "John Doe"} = TransformationExecutor.execute(transformation, raw_data, %{})
    end

    test "downcase converts to lowercase" do
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :downcase,
          module: AshImport.Transformation.Downcase,
          inputs: [%{type: "column", name: "email"}]
        })
        |> Ash.create()

      raw_data = %{"email" => "JOHN@EXAMPLE.COM"}

      assert {:ok, "john@example.com"} =
               TransformationExecutor.execute(transformation, raw_data, %{})
    end

    test "upcase converts to uppercase" do
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :upcase,
          module: AshImport.Transformation.Upcase,
          inputs: [%{type: "column", name: "code"}]
        })
        |> Ash.create()

      raw_data = %{"code" => "abc123"}
      assert {:ok, "ABC123"} = TransformationExecutor.execute(transformation, raw_data, %{})
    end

    test "parse_integer converts string to integer" do
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :parse_integer,
          module: AshImport.Transformation.ParseInteger,
          inputs: [%{type: "column", name: "quantity"}]
        })
        |> Ash.create()

      raw_data = %{"quantity" => "42"}
      assert {:ok, 42} = TransformationExecutor.execute(transformation, raw_data, %{})
    end

    test "parse_float converts string to float" do
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :parse_float,
          module: AshImport.Transformation.ParseFloat,
          inputs: [%{type: "column", name: "price"}]
        })
        |> Ash.create()

      raw_data = %{"price" => "19.99"}
      assert {:ok, 19.99} = TransformationExecutor.execute(transformation, raw_data, %{})
    end
  end

  describe "multiple input operations" do
    test "concat joins values with space" do
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :concat,
          module: AshImport.Transformation.Concat,
          inputs: [
            %{type: "column", name: "first_name"},
            %{type: "column", name: "last_name"}
          ]
        })
        |> Ash.create()

      raw_data = %{"first_name" => "John", "last_name" => "Doe"}
      assert {:ok, "John Doe"} = TransformationExecutor.execute(transformation, raw_data, %{})
    end

    test "join uses custom separator" do
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :join,
          module: AshImport.Transformation.Join,
          inputs: [
            %{type: "column", name: "city"},
            %{type: "column", name: "state"},
            %{type: "column", name: "country"}
          ],
          options: %{"separator" => ", "}
        })
        |> Ash.create()

      raw_data = %{"city" => "New York", "state" => "NY", "country" => "USA"}

      assert {:ok, "New York, NY, USA"} =
               TransformationExecutor.execute(transformation, raw_data, %{})
    end

    test "first_non_empty finds first valid value" do
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :first_non_empty,
          module: AshImport.Transformation.FirstNonEmpty,
          inputs: [
            %{type: "column", name: "primary_email"},
            %{type: "column", name: "secondary_email"},
            %{type: "static", value: "no-email@example.com"}
          ]
        })
        |> Ash.create()

      raw_data = %{"primary_email" => "", "secondary_email" => "john@example.com"}

      assert {:ok, "john@example.com"} =
               TransformationExecutor.execute(transformation, raw_data, %{})
    end

    test "sum adds numeric values" do
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :sum,
          module: AshImport.Transformation.Sum,
          inputs: [
            %{type: "column", name: "price"},
            %{type: "column", name: "tax"},
            %{type: "column", name: "shipping"}
          ]
        })
        |> Ash.create()

      raw_data = %{"price" => "100.00", "tax" => "8.50", "shipping" => "5.00"}
      assert {:ok, 113.50} = TransformationExecutor.execute(transformation, raw_data, %{})
    end
  end

  describe "input types" do
    test "static input returns configured value" do
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :static_test,
          module: AshImport.Transformation.GetValue,
          inputs: [%{type: "static", value: "imported"}]
        })
        |> Ash.create()

      assert {:ok, "imported"} = TransformationExecutor.execute(transformation, %{}, %{})
    end
  end

  describe "nested transformations" do
    test "transformation input executes nested transformation" do
      # Create nested transformation that concatenates first and last name
      {:ok, nested_transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :concat_name,
          module: AshImport.Transformation.Concat,
          inputs: [
            %{type: "column", name: "first_name"},
            %{type: "column", name: "last_name"}
          ]
        })
        |> Ash.create()

      # Create main transformation that joins the full name with a title
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :join_with_title,
          module: AshImport.Transformation.Join,
          inputs: [
            %{type: "static", value: "Mr."},
            nested_transformation
          ],
          options: %{"separator" => " "}
        })
        |> Ash.create()

      raw_data = %{"first_name" => "John", "last_name" => "Doe"}
      assert {:ok, "Mr. John Doe"} = TransformationExecutor.execute(transformation, raw_data, %{})
    end

    test "complex nested transformation pipeline" do
      # Create price parsing transformation
      {:ok, price_transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :parse_price,
          module: AshImport.Transformation.ParseFloat,
          inputs: [%{type: "column", name: "price"}]
        })
        |> Ash.create()

      # Create tax parsing transformation
      {:ok, tax_transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :parse_tax,
          module: AshImport.Transformation.ParseFloat,
          inputs: [%{type: "column", name: "tax"}]
        })
        |> Ash.create()

      # Create sum transformation that uses the parsed values
      {:ok, total_transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :sum_total,
          module: AshImport.Transformation.Sum,
          inputs: [
            price_transformation,
            tax_transformation
          ]
        })
        |> Ash.create()

      raw_data = %{"price" => "100.00", "tax" => "8.50"}
      assert {:ok, 108.50} = TransformationExecutor.execute(total_transformation, raw_data, %{})
    end
  end

  describe "error handling" do
    test "returns error for invalid integer parse" do
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :parse_integer,
          module: AshImport.Transformation.ParseInteger,
          inputs: [%{type: "column", name: "quantity"}]
        })
        |> Ash.create()

      raw_data = %{"quantity" => "not_a_number"}
      assert {:error, _} = TransformationExecutor.execute(transformation, raw_data, %{})
    end
  end

  describe "custom operations" do
    defmodule TestCustomOperations do
      def add_prefix(value, prefix) do
        "#{prefix}#{value}"
      end

      def multiply_by([value], factor) do
        value * factor
      end
    end

    test "custom operation calls module function" do
      {:ok, transformation} =
        Transformation
        |> Ash.Changeset.for_create(:create, %{
          name: :custom_prefix,
          module: AshImport.Transformation.Custom,
          inputs: [%{type: "column", name: "code"}],
          options: %{
            module: TestCustomOperations,
            function: :add_prefix,
            args: ["PROD-"]
          }
        })
        |> Ash.create()

      raw_data = %{"code" => "123"}
      assert {:ok, "PROD-123"} = TransformationExecutor.execute(transformation, raw_data, %{})
    end
  end
end
