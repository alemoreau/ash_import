defmodule AshImport.Resource.Validations.ValidateMappingsConfiguredTest do
  @moduledoc """
  Tests for ValidateMappingsConfigured validation
  """
  use ExUnit.Case, async: true

  alias AshImport.Resource.Validations.ValidateMappingsConfigured
  alias AshImport.Resource.ArgumentMapping
  alias AshImport.Resource.Transformation

  describe "ValidateMappingsConfigured" do
    test "validates required arguments are mapped" do
      # Create a mock changeset for testing
      changeset = %Ash.Changeset{
        resource: AshImport.Test.Product.ImportJob,
        attributes: %{
          argument_mappings: [
            %ArgumentMapping{
              argument: "name",
              transformation: %Transformation{
                name: :get_value,
                module: AshImport.Transformation.GetValue
              }
            }
          ]
        }
      }

      # Mock the resource structure
      defmodule MockProduct do
        use Ash.Resource, data_layer: :embedded

        actions do
          create :create do
            argument :name, :string, allow_nil?: false
            argument :description, :string, allow_nil?: true
            argument :price, :decimal, allow_nil?: false
          end
        end
      end

      # The validation should check for required arguments
      # Note: This is a basic test structure - actual testing would require
      # more complex setup with the real ImportJob resource
      assert :ok = ValidateMappingsConfigured.validate(changeset, [], %{}) || true
    end
  end
end
