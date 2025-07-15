defmodule AshImport.Resource.InfoTest do
  @moduledoc """
  Tests for AshImport.Resource.Info module to ensure all DSL configuration options
  are properly read and returned with correct defaults.
  """
  use ExUnit.Case, async: true

  # Test modules with different configurations
  defmodule MinimalResource do
    @moduledoc false
    use Ash.Resource,
      domain: AshImport.Test.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshImport.Resource]

    import_config do
      # Using all defaults
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read, :create]
    end
  end

  defmodule CustomConfigResource do
    @moduledoc false
    use Ash.Resource,
      domain: AshImport.Test.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshImport.Resource]

    import_config do
      supported_sources(
        csv: AshImport.Sources.CsvFileSource,
        json: AshImport.Sources.JsonFileSource,
        xml: Custom.XmlSource,
        api: Custom.ApiSource
      )

      create_actions([:create, :create_with_validation, :bulk_create])
      batch_size 250
      track_progress? false
      store_errors? false
      table_name_suffix "_custom_imports"
      relationship_opts public?: true, description: "Import jobs for this resource"
      import_extensions data_layer: Ash.DataLayer.Ets, extensions: [Custom.Extension]
      job_resource_name CustomImportJob
      record_resource_name CustomImportRecord

      belongs_to_actor :user, MyApp.User, domain: MyApp.Users
      belongs_to_actor :admin, MyApp.Admin, domain: MyApp.Admins

      transformations do
        add :parse_phone, MyApp.Transformations.PhoneParser
        add :format_currency, MyApp.Transformations.CurrencyFormatter
        add :slugify, MyApp.Transformations.Slugify
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read]

      create :create do
        accept [:name]
      end

      create :create_with_validation do
        accept [:name]
      end

      create :bulk_create do
        accept [:name]
      end
    end
  end

  defmodule PartialConfigResource do
    @moduledoc false
    use Ash.Resource,
      domain: AshImport.Test.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshImport.Resource]

    import_config do
      supported_sources(csv: AshImport.Sources.CsvFileSource)
      batch_size 75
      track_progress? true
      store_errors? false

      transformations do
        add :upcase, String
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :title, :string, public?: true
    end

    actions do
      defaults [:read, :create]
    end
  end

  describe "supported_sources/1" do
    test "returns default sources when not configured" do
      sources = AshImport.Resource.Info.supported_sources(MinimalResource)

      assert sources == [
               csv: AshImport.Sources.CsvFileSource,
               json: AshImport.Sources.JsonFileSource
             ]
    end

    test "returns custom sources when configured" do
      sources = AshImport.Resource.Info.supported_sources(CustomConfigResource)

      expected = [
        csv: AshImport.Sources.CsvFileSource,
        json: AshImport.Sources.JsonFileSource,
        xml: Custom.XmlSource,
        api: Custom.ApiSource
      ]

      assert sources == expected
    end

    test "returns partial custom sources" do
      sources = AshImport.Resource.Info.supported_sources(PartialConfigResource)

      assert sources == [csv: AshImport.Sources.CsvFileSource]
    end
  end

  describe "supported_source_types/1" do
    test "returns default source types when not configured" do
      types = AshImport.Resource.Info.supported_source_types(MinimalResource)

      assert types == [:csv, :json]
    end

    test "returns custom source types when configured" do
      types = AshImport.Resource.Info.supported_source_types(CustomConfigResource)

      assert types == [:csv, :json, :xml, :api]
    end

    test "returns partial custom source types" do
      types = AshImport.Resource.Info.supported_source_types(PartialConfigResource)

      assert types == [:csv]
    end
  end

  describe "create_actions/1" do
    test "returns default create action when not configured" do
      actions = AshImport.Resource.Info.create_actions(MinimalResource)

      assert actions == [:create]
    end

    test "returns custom create actions when configured" do
      actions = AshImport.Resource.Info.create_actions(CustomConfigResource)

      assert actions == [:create, :create_with_validation, :bulk_create]
    end

    test "returns default when partially configured" do
      actions = AshImport.Resource.Info.create_actions(PartialConfigResource)

      assert actions == [:create]
    end
  end

  describe "create_action/1 (deprecated)" do
    test "returns first create action for backwards compatibility" do
      action = AshImport.Resource.Info.create_action(MinimalResource)
      assert action == :create

      action = AshImport.Resource.Info.create_action(CustomConfigResource)
      assert action == :create
    end
  end

  describe "numeric configuration options" do
    test "batch_size/1 returns correct values" do
      # default
      assert AshImport.Resource.Info.batch_size(MinimalResource) == 100
      assert AshImport.Resource.Info.batch_size(CustomConfigResource) == 250
      assert AshImport.Resource.Info.batch_size(PartialConfigResource) == 75
    end
  end

  describe "boolean configuration options" do
    test "track_progress?/1 returns correct values" do
      # default
      assert AshImport.Resource.Info.track_progress?(MinimalResource) == true
      assert AshImport.Resource.Info.track_progress?(CustomConfigResource) == false
      assert AshImport.Resource.Info.track_progress?(PartialConfigResource) == true
    end

    test "store_errors?/1 returns correct values" do
      # default
      assert AshImport.Resource.Info.store_errors?(MinimalResource) == true
      assert AshImport.Resource.Info.store_errors?(CustomConfigResource) == false
      assert AshImport.Resource.Info.store_errors?(PartialConfigResource) == false
    end
  end

  describe "string configuration options" do
    test "table_name_suffix/1 returns correct values" do
      # default
      assert AshImport.Resource.Info.table_name_suffix(MinimalResource) == "_import_jobs"
      assert AshImport.Resource.Info.table_name_suffix(CustomConfigResource) == "_custom_imports"
      # default
      assert AshImport.Resource.Info.table_name_suffix(PartialConfigResource) == "_import_jobs"
    end
  end

  describe "keyword list configuration options" do
    test "relationship_opts/1 returns correct values" do
      # default
      assert AshImport.Resource.Info.relationship_opts(MinimalResource) == []

      assert AshImport.Resource.Info.relationship_opts(CustomConfigResource) == [
               public?: true,
               description: "Import jobs for this resource"
             ]

      # default
      assert AshImport.Resource.Info.relationship_opts(PartialConfigResource) == []
    end

    test "import_extensions/1 returns correct values" do
      # default
      assert AshImport.Resource.Info.import_extensions(MinimalResource) == []

      assert AshImport.Resource.Info.import_extensions(CustomConfigResource) == [
               data_layer: Ash.DataLayer.Ets,
               extensions: [Custom.Extension]
             ]

      # default
      assert AshImport.Resource.Info.import_extensions(PartialConfigResource) == []
    end
  end

  describe "optional atom configuration options" do
    test "job_resource_name/1 returns correct values" do
      # default
      assert AshImport.Resource.Info.job_resource_name(MinimalResource) == nil
      assert AshImport.Resource.Info.job_resource_name(CustomConfigResource) == CustomImportJob
      # default
      assert AshImport.Resource.Info.job_resource_name(PartialConfigResource) == nil
    end

    test "record_resource_name/1 returns correct values" do
      # default
      assert AshImport.Resource.Info.record_resource_name(MinimalResource) == nil

      assert AshImport.Resource.Info.record_resource_name(CustomConfigResource) ==
               CustomImportRecord

      # default
      assert AshImport.Resource.Info.record_resource_name(PartialConfigResource) == nil
    end
  end

  describe "mixin/1" do
    test "returns nil when not configured" do
      assert AshImport.Resource.Info.mixin(MinimalResource) == nil
      assert AshImport.Resource.Info.mixin(PartialConfigResource) == nil
    end

    # Note: Testing mixin would require defining actual mixin modules,
    # which is complex for this test. The CustomConfigResource doesn't include it.
  end

  describe "generated resource names" do
    test "import_job_resource/1 generates correct module names" do
      assert AshImport.Resource.Info.import_job_resource(MinimalResource) ==
               AshImport.Resource.InfoTest.MinimalResource.ImportJob

      # custom name
      assert AshImport.Resource.Info.import_job_resource(CustomConfigResource) == CustomImportJob

      assert AshImport.Resource.Info.import_job_resource(PartialConfigResource) ==
               AshImport.Resource.InfoTest.PartialConfigResource.ImportJob
    end

    test "import_record_resource/1 generates correct module names" do
      assert AshImport.Resource.Info.import_record_resource(MinimalResource) ==
               AshImport.Resource.InfoTest.MinimalResource.ImportRecord

      # custom name
      assert AshImport.Resource.Info.import_record_resource(CustomConfigResource) ==
               CustomImportRecord

      assert AshImport.Resource.Info.import_record_resource(PartialConfigResource) ==
               AshImport.Resource.InfoTest.PartialConfigResource.ImportRecord
    end
  end

  describe "belongs_to_actor/1" do
    test "returns empty list when not configured" do
      assert AshImport.Resource.Info.belongs_to_actor(MinimalResource) == []
      assert AshImport.Resource.Info.belongs_to_actor(PartialConfigResource) == []
    end

    test "returns configured actors" do
      actors = AshImport.Resource.Info.belongs_to_actor(CustomConfigResource)

      assert length(actors) == 2

      # Check that we have the expected actor configurations
      actor_names = Enum.map(actors, & &1.name)
      assert :user in actor_names
      assert :admin in actor_names

      # Check one of the actor configurations in detail
      user_actor = Enum.find(actors, &(&1.name == :user))
      assert user_actor.destination == MyApp.User
      assert user_actor.domain == MyApp.Users
    end
  end

  describe "transformations/1" do
    test "returns empty map when not configured" do
      assert AshImport.Resource.Info.transformations(MinimalResource) == %{}
    end

    test "returns configured transformations as map" do
      transformations = AshImport.Resource.Info.transformations(CustomConfigResource)

      expected = %{
        parse_phone: MyApp.Transformations.PhoneParser,
        format_currency: MyApp.Transformations.CurrencyFormatter,
        slugify: MyApp.Transformations.Slugify
      }

      assert transformations == expected
    end

    test "returns partial transformations" do
      transformations = AshImport.Resource.Info.transformations(PartialConfigResource)

      assert transformations == %{upcase: String}
    end
  end

  describe "edge cases and error handling" do
    test "all functions work with atom resource parameter" do
      # Test that functions work when passed an atom (compiled resource) vs dsl_state
      # This tests the is_atom(resource) branches in the Info module

      # These should not raise errors
      assert is_list(AshImport.Resource.Info.supported_source_types(MinimalResource))
      assert is_integer(AshImport.Resource.Info.batch_size(MinimalResource))
      assert is_boolean(AshImport.Resource.Info.track_progress?(MinimalResource))
      assert is_list(AshImport.Resource.Info.belongs_to_actor(MinimalResource))
      assert is_map(AshImport.Resource.Info.transformations(MinimalResource))
    end

    test "functions return consistent types" do
      # Ensure all functions return the expected types for type safety

      assert is_list(AshImport.Resource.Info.supported_sources(CustomConfigResource))
      assert is_list(AshImport.Resource.Info.supported_source_types(CustomConfigResource))
      assert is_list(AshImport.Resource.Info.create_actions(CustomConfigResource))
      assert is_atom(AshImport.Resource.Info.create_action(CustomConfigResource))
      assert is_integer(AshImport.Resource.Info.batch_size(CustomConfigResource))
      assert is_boolean(AshImport.Resource.Info.track_progress?(CustomConfigResource))
      assert is_boolean(AshImport.Resource.Info.store_errors?(CustomConfigResource))
      assert is_binary(AshImport.Resource.Info.table_name_suffix(CustomConfigResource))
      assert is_list(AshImport.Resource.Info.relationship_opts(CustomConfigResource))
      assert is_list(AshImport.Resource.Info.import_extensions(CustomConfigResource))
      assert is_atom(AshImport.Resource.Info.job_resource_name(CustomConfigResource))
      assert is_atom(AshImport.Resource.Info.record_resource_name(CustomConfigResource))
      assert is_list(AshImport.Resource.Info.belongs_to_actor(CustomConfigResource))
      assert is_map(AshImport.Resource.Info.transformations(CustomConfigResource))
    end
  end
end
