defmodule AshImport.Transformation do
  @moduledoc """
  A behaviour for defining custom transformations that transform raw import data
  into values for resource attributes/arguments.

  Transformations are now implemented as modules that implement this behaviour,
  replacing the old :operation-based system with a more flexible module-based approach.

  ## Creating Custom Transformations

  To create a custom transformation, implement this behaviour:

      defmodule MyApp.Transformations.Trim do
        use AshImport.Transformation

        @impl true
        def init(opts), do: {:ok, opts}

  I        @impl true
        def transform(input, opts, _context) do
          {:ok, String.trim(input)}
        end

        @impl true
        def describe(_opts) do
          "Trims whitespace from string values"
        end
      end

  ## Usage

  Transformations are configured using the :module attribute in transformation configs:

      transformations: [
        %{
          name: :trim_name,
          module: MyApp.Transformations.Trim
        }
      ]

  ## Built-in Transformations

  AshImport provides several built-in transformations:

  - `AshImport.Transformation.Trim` - Trims whitespace from strings
  - `AshImport.Transformation.Downcase` - Converts strings to lowercase
  - `AshImport.Transformation.Upcase` - Converts strings to uppercase
  - `AshImport.Transformation.ParseInteger` - Parses strings as integers
  - `AshImport.Transformation.ParseFloat` - Parses strings as floats
  - `AshImport.Transformation.ParseDate` - Parses strings as dates
  - `AshImport.Transformation.ParseDatetime` - Parses strings as datetimes
  - `AshImport.Transformation.Concat` - Concatenates multiple values
  - `AshImport.Transformation.Join` - Joins values with separator
  - `AshImport.Transformation.Sum` - Sums numeric values
  - `AshImport.Transformation.Average` - Calculates average of numeric values
  - `AshImport.Transformation.Min` - Finds minimum value
  - `AshImport.Transformation.Max` - Finds maximum value
  - `AshImport.Transformation.FirstNonEmpty` - Returns first non-empty value
  """

  @type raw_data :: map()
  @type context :: %{
          import_job: Ash.Resource.record(),
          row_number: non_neg_integer(),
          user_inputs: map()
        }
  @type init_opts :: Keyword.t()
  @type runtime_opts :: any()

  @doc """
  Initialize the transformation with compile-time options.

  This is called once when the transformation is configured and should
  validate the options and prepare any compile-time optimizations.
  """
  @callback init(init_opts) :: {:ok, runtime_opts} | {:error, String.t()}

  @doc """
  Transform input value(s) into the desired output.

  Takes the input value(s), runtime options from init/1, and a context map.

  Should return the transformed value or an error.
  """
  @callback transform(any(), runtime_opts, context) ::
              {:ok, any()} | {:error, String.t()}

  @doc """
  Provide a human-readable description of what this transformation does.

  Used for debugging and user interfaces.
  """
  @callback describe(runtime_opts) :: String.t()

  @doc """
  Optional callback to validate that this transformation can work with
  the given argument type and constraints.

  Defaults to always returning :ok.
  """
  @callback validate_for_argument(runtime_opts, Ash.Resource.Actions.Argument.t()) ::
              :ok | {:error, String.t()}

  @optional_callbacks [validate_for_argument: 2]

  @doc """
  Transforms a transformation specification into a normalized {module, opts} tuple.

  Handles various input formats:
  - `{module, opts}` - already normalized
  - `module` - module with empty opts
  """
  def normalize_transformation_spec(transformation_spec) do
    case transformation_spec do
      {module, opts} when is_atom(module) and is_list(opts) ->
        {module, opts}

      {module, opts} when is_atom(module) and is_map(opts) ->
        {module,
         Enum.map(opts, fn
           {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
           {key, value} -> {key, value}
         end)}

      module when is_atom(module) ->
        {module, []}

      _ ->
        {:error, "Invalid transformation specification: #{inspect(transformation_spec)}"}
    end
  end

  @doc """
  Initialize a transformation from its specification.
  """
  def init_transformation(transformation_spec) do
    case normalize_transformation_spec(transformation_spec) do
      {:error, _} = error ->
        error

      {module, opts} ->
        case module.init(opts) do
          {:ok, runtime_opts} -> {:ok, {module, runtime_opts}}
          {:error, _} = error -> error
        end
    end
  end

  @doc """
  Execute a transformation with the given raw data and context.
  """
  def execute_transformation({module, runtime_opts}, input, context) do
    module.transform(input, runtime_opts, context)
  end

  @doc """
  Get a description of a transformation.
  """
  def describe_transformation({module, runtime_opts}) do
    module.describe(runtime_opts)
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour AshImport.Transformation

      @impl true
      def validate_for_argument(_runtime_opts, _argument), do: :ok

      defoverridable validate_for_argument: 2
    end
  end
end
