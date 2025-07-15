defmodule AshImport do
  @moduledoc """
  AshImport provides CSV and JSON file import capabilities for Ash resources.

  It automatically generates ImportJob and ImportRecord resources to track
  import progress and handle data transformation with configurable mappings.
  """

  def allow_import_resources({m, f, a}, resource) do
    apply(m, f, a) || allow_import_resources(nil, resource)
  end

  @import_job_regex ~r/\.ImportJob$/
  @import_record_regex ~r/\.ImportRecord$/

  def allow_import_resources(nil, resource) do
    resource_name = to_string(resource)

    cond do
      String.match?(resource_name, @import_job_regex) ->
        check_original_resource(resource_name, @import_job_regex)

      String.match?(resource_name, @import_record_regex) ->
        check_original_resource(resource_name, @import_record_regex)

      true ->
        false
    end
  end

  defp check_original_resource(resource_name, regex) do
    original_resource =
      try do
        resource_name
        |> String.replace(regex, "")
        |> String.to_existing_atom()
      rescue
        ArgumentError -> false
      end

    original_resource && AshImport.Resource in Spark.extensions(original_resource)
  end
end
