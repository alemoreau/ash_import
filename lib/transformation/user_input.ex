defmodule AshImport.Transformation.UserInput do
  @moduledoc """
  A transformation that prompts the user for input during import configuration.

  This transformation looks up a user-provided value from the import job's
  user_inputs map based on a key.

  ## Options

  - `:key` (required) - The key to look up in user_inputs
  - `:prompt` (optional) - Human-readable prompt for this input
  - `:input_type` (optional) - Type hint for UI (:text, :number, :select, etc.)
  - `:options` (optional) - Available options for select inputs
  - `:default` (optional) - Default value if not provided by user

  ## Examples

      # Prompt user for a category
      {AshImport.Transformation.UserInput, [
        key: "default_category",
        prompt: "What category should be used for products without one?",
        input_type: :select,
        options: ["Electronics", "Books", "Clothing"],
        default: "Other"
      ]}

      # Prompt for a simple text value
      {AshImport.Transformation.UserInput, [
        key: "import_source",
        prompt: "What is the source of this import?",
        input_type: :text,
        default: "manual_import"
      ]}

  """
  use AshImport.Transformation

  @impl true
  def init(opts) do
    key = Keyword.get(opts, :key)
    prompt = Keyword.get(opts, :prompt, "User input for #{key}")
    input_type = Keyword.get(opts, :input_type, :text)
    options = Keyword.get(opts, :options, [])
    default = Keyword.get(opts, :default)

    cond do
      is_nil(key) ->
        {:error, "UserInput transformation requires a :key option"}

      not is_binary(key) ->
        {:error, "UserInput key must be a string, got: #{inspect(key)}"}

      input_type not in [:text, :number, :select, :multiselect, :boolean, :date, :datetime] ->
        {:error, "Invalid input_type: #{input_type}"}

      input_type in [:select, :multiselect] and Enum.empty?(options) ->
        {:error, "Select and multiselect inputs require options"}

      true ->
        {:ok,
         %{
           key: key,
           prompt: prompt,
           input_type: input_type,
           options: options,
           default: default
         }}
    end
  end

  @impl true
  def transform(_raw_data, opts, context) do
    case Map.get(context.user_inputs, opts.key, opts[:default]) do
      nil ->
        {:error, "Missing user input for key '#{opts.key}'. Prompt: #{opts.prompt}"}

      value ->
        {:ok, value}
    end
  end

  @impl true
  def describe(%{key: key, prompt: prompt}) do
    "User input '#{key}': #{prompt}"
  end
end
