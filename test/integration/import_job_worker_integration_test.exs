defmodule AshImport.ImportJobWorkerIntegrationTest do
  @moduledoc """
  Integration test for ImportJobWorker with TransformationExecutor using Oban.Testing.
  """
  use ExUnit.Case, async: false
  use Oban.Testing, repo: AshImport.Test.Repo, prefix: "private"

  alias AshImport.Workers.ImportJobWorker
  alias AshImport.Test.Product

  setup_all do
    # Start the test repo
    {:ok, _} = AshImport.Test.Repo.start_link()

    # Start Oban with test configuration
    oban_config = Application.get_env(:ash_import, :oban)
    {:ok, _} = Oban.start_link(oban_config)

    :ok
  end

  describe "ImportJobWorker with real ImportJob and TransformationExecutor" do
    test "processes import job with transformation successfully" do
      # Create an import job using the test CSV file
      {:ok, import_job} =
        Product.ImportJob
        |> Ash.Changeset.for_create(:create, %{
          source_type: :csv,
          source_config: %{
            file_path: Path.join([__DIR__, "..", "support", "products.csv"])
          }
        })
        |> Ash.create(domain: AshImport.Test)

      # Create argument mappings with embedded transformations
      argument_mappings = [
        %{
          argument: "name",
          transformation: %{
            name: :get_value,
            module: AshImport.Transformation.GetValue,
            inputs: [%{type: "column", name: "name"}]
          },
          required: true
        },
        %{
          argument: "category",
          transformation: %{
            name: :get_value,
            module: AshImport.Transformation.GetValue,
            inputs: [%{type: "static", value: "electronics"}]
          },
          required: false
        },
        %{
          argument: "price",
          transformation: %{
            name: :parse_float,
            module: AshImport.Transformation.ParseFloat,
            inputs: [%{type: "column", name: "price"}]
          },
          required: true
        }
      ]

      # Update the import job with argument mappings
      {:ok, import_job} =
        import_job
        |> Ash.Changeset.for_update(:configure_mappings, %{
          argument_mappings: argument_mappings
        })
        |> Ash.update(domain: AshImport.Test)

      # Verify the import job was created correctly
      assert import_job.source_type == :csv
      assert length(import_job.argument_mappings) == 3

      # Find the name mapping
      name_arg_mapping = Enum.find(import_job.argument_mappings, &(&1.argument == "name"))
      assert name_arg_mapping.transformation.name == :get_value
      assert length(name_arg_mapping.transformation.inputs) == 1

      # Find the price mapping
      price_arg_mapping = Enum.find(import_job.argument_mappings, &(&1.argument == "price"))
      assert price_arg_mapping.transformation.name == :parse_float
      assert length(price_arg_mapping.transformation.inputs) == 1

      Oban.Testing.with_testing_mode(:manual, fn ->
        # Start the import job - this should schedule an Oban worker
        started_job =
          import_job |> Ash.Changeset.for_update(:start) |> Ash.update!(domain: AshImport.Test)

        # Verify the job was scheduled
        assert started_job.status == :processing
        assert started_job.oban_job_id != nil

        assert_enqueued(
          worker: ImportJobWorker,
          args: %{
            "import_job_id" => started_job.id,
            "import_job_resource" => "Elixir.AshImport.Test.Product.ImportJob"
          }
        )

        # Execute the job using Oban.Testing
        :ok =
          perform_job(ImportJobWorker, %{
            "import_job_id" => started_job.id,
            "import_job_resource" => "Elixir.AshImport.Test.Product.ImportJob"
          })

        # Verify that import records were created
        updated_job = Ash.reload!(started_job, domain: AshImport.Test)

        import_records =
          updated_job
          |> Ash.load!(:import_records, domain: AshImport.Test)
          |> Map.get(:import_records)

        # We should have 3 import records (one for each row in products.csv)
        assert length(import_records) == 3
      end)
    end

    test "handles transformation errors in import job processing" do
      # Create an import job using the test CSV file
      {:ok, import_job} =
        Product.ImportJob
        |> Ash.Changeset.for_create(:create, %{
          source_type: :csv,
          source_config: %{
            file_path: Path.join([__DIR__, "..", "support", "products.csv"])
          }
        })
        |> Ash.create(domain: AshImport.Test)

      # Create argument mapping that tries to parse name as integer (will fail)
      argument_mappings = [
        %{
          argument: "price",
          transformation: %{
            name: :parse_integer,
            module: AshImport.Transformation.ParseInteger,
            inputs: [%{type: "column", name: "name"}]
          },
          required: true
        }
      ]

      # Update with argument mappings
      {:ok, import_job} =
        import_job
        |> Ash.Changeset.for_update(:configure_mappings, %{
          argument_mappings: argument_mappings
        })
        |> Ash.update(domain: AshImport.Test)

      # Verify the configuration is correct
      assert length(import_job.argument_mappings) == 1
      mapping = List.first(import_job.argument_mappings)
      assert mapping.argument == "price"
      assert mapping.transformation.name == :parse_integer

      Oban.Testing.with_testing_mode(:manual, fn ->
        # Start the import job - this should schedule an Oban worker
        started_job =
          import_job |> Ash.Changeset.for_update(:start) |> Ash.update!(domain: AshImport.Test)

        # Verify the job was scheduled
        assert started_job.status == :processing
        assert started_job.oban_job_id != nil

        assert_enqueued(
          worker: ImportJobWorker,
          args: %{
            "import_job_id" => started_job.id,
            "import_job_resource" => "Elixir.AshImport.Test.Product.ImportJob"
          }
        )

        # Execute the job using Oban.Testing - this should fail due to transformation error
        result =
          perform_job(ImportJobWorker, %{
            "import_job_id" => started_job.id,
            "import_job_resource" => "Elixir.AshImport.Test.Product.ImportJob"
          })

        # Should fail because missing "name" column
        assert {:error, _reason} = result
      end)
    end

    test "creates transformation with static value in import job" do
      # Create an import job using the test CSV file
      {:ok, import_job} =
        Product.ImportJob
        |> Ash.Changeset.for_create(:create, %{
          source_type: :csv,
          source_config: %{
            file_path: Path.join([__DIR__, "..", "support", "products.csv"])
          }
        })
        |> Ash.create(domain: AshImport.Test)

      # Create simple transformations with column and static inputs
      argument_mappings = [
        %{
          argument: "name",
          transformation: %{
            name: :get_value,
            module: AshImport.Transformation.GetValue,
            inputs: [%{type: "column", name: "name"}]
          },
          required: true
        },
        %{
          argument: "category",
          transformation: %{
            name: :get_value,
            module: AshImport.Transformation.GetValue,
            inputs: [%{type: "static", value: "electronics"}]
          },
          required: false
        }
      ]

      # Update with argument mappings
      {:ok, import_job} =
        import_job
        |> Ash.Changeset.for_update(:configure_mappings, %{
          argument_mappings: argument_mappings
        })
        |> Ash.update(domain: AshImport.Test)

      # Verify the transformation structure
      assert length(import_job.argument_mappings) == 2

      # Check name mapping (column input)
      name_mapping = Enum.find(import_job.argument_mappings, &(&1.argument == "name"))
      assert name_mapping.transformation.name == :get_value
      column_input = List.first(name_mapping.transformation.inputs)
      assert column_input.type == :column
      assert column_input.value.name == "name"

      # Check category mapping (static input)
      category_mapping = Enum.find(import_job.argument_mappings, &(&1.argument == "category"))
      assert category_mapping.transformation.name == :get_value
      static_input = List.first(category_mapping.transformation.inputs)
      assert static_input.type == :static
      assert static_input.value.value == "electronics"
    end

    test "import job with user inputs and static values" do
      # Create an import job using the test JSON file
      {:ok, import_job} =
        Product.ImportJob
        |> Ash.Changeset.for_create(:create, %{
          source_type: :json,
          source_config: %{
            file_path: Path.join([__DIR__, "..", "support", "products.json"])
          }
        })
        |> Ash.create(domain: AshImport.Test)

      # Create argument mapping with join transformation
      argument_mappings = [
        %{
          argument: "description",
          transformation: %{
            name: :join,
            module: AshImport.Transformation.Join,
            inputs: [
              %{type: "column", name: "name"},
              %{type: "static", value: "imported"}
            ],
            options: %{"separator" => " - "}
          },
          required: false
        }
      ]

      # Update with argument mappings
      {:ok, import_job} =
        import_job
        |> Ash.Changeset.for_update(:configure_mappings, %{
          argument_mappings: argument_mappings
        })
        |> Ash.update(domain: AshImport.Test)

      {:ok, import_job} =
        import_job
        |> Ash.Changeset.for_update(:provide_user_inputs, %{
          user_inputs: %{"category" => "Electronics"}
        })
        |> Ash.update(domain: AshImport.Test)

      # Verify the configuration
      assert import_job.user_inputs["category"] == "Electronics"
      assert length(import_job.argument_mappings) == 1

      mapping = List.first(import_job.argument_mappings)
      assert mapping.argument == "description"
      assert mapping.transformation.name == :join
      # Options might be stored with atom keys or string keys
      separator =
        mapping.transformation.options[:separator] || mapping.transformation.options["separator"]

      assert separator == " - "

      # Verify inputs include static value
      static_input = Enum.find(mapping.transformation.inputs, &(&1.type == :static))
      assert static_input.value.value == "imported"
    end
  end
end
