defmodule AshImport.Transformation.Computed do
  @moduledoc """
  A transformation that calls a custom function to compute a value.

  This allows for complex custom logic that goes beyond simple column
  extraction and transformation.

  ## Options

  - `:module` (required) - The module containing the computation function
  - `:function` (required) - The function name to call
  - `:args` (optional) - Additional arguments to pass to the function (default: [])

  The function will be called as: `module.function(raw_data, context, ...args)`

  ## Examples

      # Call a custom pricing function
      {AshImport.Transformation.Computed, [
        module: MyApp.Pricing,
        function: :calculate_price,
        args: [:with_tax]
      ]}

      # Generate a slug from multiple fields
      {AshImport.Transformation.Computed, [
        module: MyApp.Utils,
        function: :generate_slug
      ]}

  ## Custom Function Contract

  Your function should have this signature:

      def your_function(raw_data, context, ...additional_args) do
        # raw_data is a map of column_name => value
        # context contains import_job, row_number, user_inputs, etc.
        # Return {:ok, value} or {:error, reason}
      end

  """
  use AshImport.Transformation

  @impl true
  def init(opts) do
    module = Keyword.get(opts, :module)
    function = Keyword.get(opts, :function)
    args = Keyword.get(opts, :args, [])

    cond do
      is_nil(module) ->
        {:error, "Computed transformation requires a :module option"}

      is_nil(function) ->
        {:error, "Computed transformation requires a :function option"}

      not is_atom(module) ->
        {:error, "Module must be an atom, got: #{inspect(module)}"}

      not is_atom(function) ->
        {:error, "Function must be an atom, got: #{inspect(function)}"}

      not is_list(args) ->
        {:error, "Args must be a list, got: #{inspect(args)}"}

      not Code.ensure_loaded?(module) ->
        {:error, "Module #{inspect(module)} could not be loaded"}

      not function_exported?(module, function, length(args) + 2) ->
        {:error, "Function #{module}.#{function}/#{length(args) + 2} does not exist"}

      true ->
        {:ok,
         %{
           module: module,
           function: function,
           args: args
         }}
    end
  end

  @impl true
  def transform(raw_data, %{module: module, function: function, args: args}, context) do
    try do
      apply(module, function, [raw_data, context | args])
    rescue
      error ->
        {:error, "Error in computed transformation: #{Exception.message(error)}"}
    end
  end

  @impl true
  def describe(%{module: module, function: function, args: args}) do
    arg_count = length(args) + 2
    "Computed: #{module}.#{function}/#{arg_count}"
  end
end
