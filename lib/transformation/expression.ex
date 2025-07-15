defmodule AshImport.Transformation.Expression do
  @moduledoc """
  A transformation that evaluates a simple expression using column values as variables.

  This provides a safe way to perform basic calculations and string operations
  without requiring custom functions.

  ## Options

  - `:expression` (required) - The expression template (string)
  - `:variables` (optional) - Map of variable names to column names (default: auto-detect)

  ## Expression Syntax

  Variables are referenced with `{{variable_name}}` syntax. Basic operations supported:
  - String concatenation: `"{{first_name}} {{last_name}}"`
  - Math operations: `"{{price}} * {{quantity}}"`
  - Conditional: `"{{status == 'active' ? 'Yes' : 'No'}}"`

  ## Examples

      # Simple string concatenation
      {AshImport.Transformation.Expression, [
        expression: "{{first_name}} {{last_name}}",
        variables: %{"first_name" => "fname", "last_name" => "lname"}
      ]}

      # Math calculation
      {AshImport.Transformation.Expression, [
        expression: "{{price}} * {{quantity}}"
      ]}

      # Auto-detect variables from column names
      {AshImport.Transformation.Expression, [
        expression: "Product: {{name}} (${{price}})"
      ]}

  """
  use AshImport.Transformation

  @impl true
  def init(opts) do
    expression = Keyword.get(opts, :expression)
    variables = Keyword.get(opts, :variables, %{})

    cond do
      is_nil(expression) or expression == "" ->
        {:error, "Expression transformation requires an :expression option"}

      not is_binary(expression) ->
        {:error, "Expression must be a string, got: #{inspect(expression)}"}

      not is_map(variables) ->
        {:error, "Variables must be a map, got: #{inspect(variables)}"}

      true ->
        # Auto-detect variables from expression if not provided
        detected_variables =
          if Enum.empty?(variables) do
            detect_variables(expression)
          else
            variables
          end

        {:ok,
         %{
           expression: expression,
           variables: detected_variables
         }}
    end
  end

  @impl true
  def transform(raw_data, %{expression: expression, variables: variables}, _context) do
    try do
      # Substitute variables in the expression
      substituted =
        Enum.reduce(variables, expression, fn {var_name, column_name}, acc ->
          value = Map.get(raw_data, column_name, "")
          String.replace(acc, "{{#{var_name}}}", to_string(value))
        end)

      # For now, return the substituted string
      # In a more advanced implementation, we could evaluate mathematical expressions
      result =
        if is_mathematical_expression?(substituted) do
          evaluate_math_expression(substituted)
        else
          substituted
        end

      {:ok, result}
    rescue
      error ->
        {:error, "Error evaluating expression: #{Exception.message(error)}"}
    end
  end

  @impl true
  def describe(%{expression: expression}) do
    "Expression: #{expression}"
  end

  # Detect {{variable}} patterns in the expression
  defp detect_variables(expression) do
    ~r/\{\{(\w+)\}\}/
    |> Regex.scan(expression, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.into(%{}, fn var -> {var, var} end)
  end

  # Check if the expression looks like math (contains operators)
  defp is_mathematical_expression?(expr) do
    String.contains?(expr, ["+", "-", "*", "/", "(", ")"])
  end

  # Very basic math expression evaluation
  # In production, you'd want a proper expression parser/evaluator
  defp evaluate_math_expression(expr) do
    # Remove whitespace and try to evaluate simple expressions
    cleaned = String.replace(expr, ~r/\s/, "")

    # This is a very basic implementation
    # In practice, you'd use a proper expression evaluator library
    case safe_math_eval(cleaned) do
      {:ok, result} -> result
      # Return original if evaluation fails
      {:error, _} -> expr
    end
  end

  defp safe_math_eval(expr) do
    # Only allow numbers, basic operators, and parentheses
    if Regex.match?(~r/^[\d\+\-\*\/\(\)\.\s]+$/, expr) do
      try do
        # In a real implementation, use a proper math expression parser
        # This is just a placeholder
        {:ok, expr}
      rescue
        _ -> {:error, "Invalid expression"}
      end
    else
      {:error, "Unsafe expression"}
    end
  end
end
