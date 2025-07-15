defmodule AshImport.TransformationTest do
  @moduledoc """
  Tests for the main Transformation module.
  """
  use ExUnit.Case, async: true

  alias AshImport.Transformation
  alias AshImport.Transformation.Static

  describe "AshImport.Transformation" do
    test "normalize_transformation_spec/1 handles {module, opts} tuples" do
      assert Transformation.normalize_transformation_spec({Static, [value: "test"]}) ==
               {Static, [value: "test"]}
    end

    test "normalize_transformation_spec/1 handles module atoms" do
      assert Transformation.normalize_transformation_spec(Static) == {Static, []}
    end

    test "normalize_transformation_spec/1 maps built-in transformation atoms" do
      assert Transformation.normalize_transformation_spec(:static) == {:static, []}
      assert Transformation.normalize_transformation_spec(:column) == {:column, []}
      assert Transformation.normalize_transformation_spec(:multi_column) == {:multi_column, []}
      assert Transformation.normalize_transformation_spec(:user_input) == {:user_input, []}
      assert Transformation.normalize_transformation_spec(:computed) == {:computed, []}
      assert Transformation.normalize_transformation_spec(:expression) == {:expression, []}
    end

    test "normalize_transformation_spec/1 treats unknown atoms as modules" do
      # Unknown atoms are treated as module names (not built-ins)
      assert Transformation.normalize_transformation_spec(:unknown) == {:unknown, []}
    end

    test "normalize_transformation_spec/1 returns error for invalid specs" do
      assert {:error, _} = Transformation.normalize_transformation_spec("invalid")
    end

    test "init_transformation/1 initializes valid transformations" do
      assert {:ok, {Static, %{value: "test"}}} =
               Transformation.init_transformation({Static, [value: "test"]})
    end

    test "init_transformation/1 returns error for invalid options" do
      assert {:error, _} = Transformation.init_transformation({Static, []})
    end
  end

  describe "backward compatibility" do
    test "normalize_transformation_spec/1 still works" do
      assert Transformation.normalize_transformation_spec({Static, [value: "test"]}) ==
               {Static, [value: "test"]}
    end

    test "init_transformation/1 still works" do
      assert {:ok, {Static, %{value: "test"}}} =
               Transformation.init_transformation({Static, [value: "test"]})
    end

    test "execute_transformation/3 still works" do
      {:ok, transformation} = Transformation.init_transformation({Static, [value: "test"]})
      context = %{user_inputs: %{}, import_job: nil, row_number: 1}
      assert {:ok, "test"} = Transformation.execute_transformation(transformation, %{}, context)
    end

    test "describe_transformation/1 still works" do
      {:ok, transformation} = Transformation.init_transformation({Static, [value: "test"]})
      description = Transformation.describe_transformation(transformation)
      assert String.contains?(description, "Static value")
    end
  end
end
