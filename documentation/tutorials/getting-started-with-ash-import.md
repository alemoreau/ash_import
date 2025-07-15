# Getting Started with AshImport

AshImport provides powerful, flexible file import capabilities for Ash resources. This tutorial will walk you through setting up and using AshImport to import CSV and JSON files with configurable data transformations.

## Installation

First, add `ash_import` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:ash_import, "~> 0.1.0"},
    {:ash_oban, "~> 0.2"},
    {:oban, "~> 2.15"},
    {:nimble_csv, "~> 1.2"},
    {:jason, "~> 1.4"}
  ]
end
```

Add `:ash_import` to your `.formatter.exs`:

```elixir
[
  import_deps: [:ash, :ash_import],
  # ... other config
]
```

## Basic Setup

### 1. Configure Your Resource

Add the `AshImport.Resource` extension to any resource you want to enable imports for:

```elixir
defmodule MyApp.User do
  use Ash.Resource,
    domain: MyApp.Users,
    extensions: [AshImport.Resource]

  import_config do
    supported_formats [:csv, :json]
    create_action :create
    batch_size 100
    track_progress? true
    store_errors? true
  end

  attributes do
    uuid_primary_key :id
    attribute :email, :string, allow_nil?: false, public?: true
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :phone, :string, public?: true
    attribute :age, :integer, public?: true
    attribute :active, :boolean, default: true, public?: true
  end

  actions do
    defaults [:read, :update, :destroy]
    
    create :create do
      accept [:email, :name, :phone, :age, :active]
      
      validate present(:email)
      validate present(:name)
    end
  end
end
```

### 2. Configure Your Domain

Add the `AshImport.Domain` extension to automatically include import resources:

```elixir
defmodule MyApp.Users do
  use Ash.Domain,
    extensions: [AshImport.Domain]

  import_config do
    include_import_resources? true
  end

  resources do
    resource MyApp.User
  end
end
```

This automatically adds `MyApp.User.ImportJob` and `MyApp.User.ImportRecord` resources to your domain.

### 3. Configure Oban

AshImport uses Oban for background processing. Add Oban to your supervision tree:

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyApp.Repo,
      {Oban, Application.fetch_env!(:my_app, Oban)},
      # ... other children
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

Configure Oban in your config files:

```elixir
# config/config.exs
config :my_app, Oban,
  repo: MyApp.Repo,
  queues: [
    import_jobs: 5,
    import_records: 10
  ]
```

## Creating Your First Import

### Step 1: Create an Import Job

```elixir
# Create a CSV file (users.csv)
csv_content = """
email,first_name,last_name,phone,age
john@example.com,John,Doe,555-1234,30
jane@example.com,Jane,Smith,555-5678,25
bob@example.com,Bob,Johnson,555-9012,35
"""

# Create the import job
{:ok, job} = MyApp.User.ImportJob.create(%{
  file_type: :csv,
  file_content: csv_content  # or file_path: "/path/to/users.csv"
}, domain: MyApp.Users)

IO.inspect(job.status)  # :pending
```

### Step 2: Configure Argument Mappings

AshImport validates that all **required arguments** for the selected create action are properly mapped before starting an import. This ensures data integrity and prevents runtime errors.

```elixir
# Configure how to map CSV columns to resource attributes
{:ok, job} = Ash.update(job, :configure_mappings, %{
  argument_mappings: [
    %AshImport.Resource.ArgumentMapping{
      argument: :email,
      transformation: %AshImport.Resource.Transformation{
        name: :get_value,
        module: AshImport.Transformation.GetValue,
        inputs: [%{type: "column", name: "email"}],
        options: %{}
      }
    },
    
    %AshImport.Resource.ArgumentMapping{
      argument: :name,
      transformation: %AshImport.Resource.Transformation{
        name: :join,
        module: AshImport.Transformation.Join,
        inputs: [
          %{type: "column", name: "first_name"},
          %{type: "column", name: "last_name"}
        ],
        options: %{"separator" => " "}
      }
    },
    
    %AshImport.Resource.ArgumentMapping{
      argument: :phone,
      transformation: %AshImport.Resource.Transformation{
        name: :trim,
        module: AshImport.Transformation.Trim,
        inputs: [%{type: "column", name: "phone"}],
        options: %{}
      }
    },
    
    %AshImport.Resource.ArgumentMapping{
      argument: :age,
      transformation: %AshImport.Resource.Transformation{
        name: :parse_integer,
        module: AshImport.Transformation.ParseInteger,
        inputs: [%{type: "column", name: "age"}],
        options: %{}
      }
    },
    
    %AshImport.Resource.ArgumentMapping{
      argument: :active,
      transformation: %AshImport.Resource.Transformation{
        name: :static_value,
        module: AshImport.Transformation.Static,
        inputs: [%{type: "static", value: true}],
        options: %{}
      }
    }
  ]
}, domain: MyApp.Users)
```

### Step 3: Start the Import

```elixir
# Start the background import process
{:ok, job} = Ash.update(job, :start, %{}, domain: MyApp.Users)

IO.inspect(job.status)  # :processing
```

### Step 4: Monitor Progress

```elixir
# Refresh the job to see updated progress
{:ok, updated_job} = Ash.reload(job, domain: MyApp.Users)

IO.inspect(updated_job.status)           # :completed
IO.inspect(updated_job.total_records)    # 3
IO.inspect(updated_job.successful_records) # 3
IO.inspect(updated_job.failed_records)   # 0
```

## Advanced Value Derivation

### Mathematical Expressions

```elixir
# Calculate total price from price and tax
%AshImport.Resource.ArgumentMapping{
  argument: :total_price,
  transformation: %AshImport.Resource.Transformation{
    name: :expression,
    module: AshImport.Transformation.Expression,
    inputs: [
      %{type: "column", name: "price"},
      %{type: "column", name: "tax_rate"}
    ],
    options: %{
      "expression" => "price * (1 + tax_rate / 100)",
      "variables" => ["price", "tax_rate"]
    }
  }
}
```

### User Input

```elixir
# Prompt user for category selection
%AshImport.Resource.ArgumentMapping{
  argument: :category,
  transformation: %AshImport.Resource.Transformation{
    name: :user_input,
    module: AshImport.Transformation.UserInput,
    inputs: [],
    options: %{
      "prompt" => "Select category for this import",
      "input_type" => "select",
      "options" => ["electronics", "clothing", "food"]
    }
  }
}

# Provide user inputs when starting
{:ok, job} = Ash.update(job, :provide_user_inputs, %{
  user_inputs: %{
    "select_category_for_this_import" => "electronics"
  }
}, domain: MyApp.Users)
```

### Custom Computed Values

```elixir
# Define a custom computation module
defmodule MyApp.Computations.RiskCalculator do
  use AshImport.Transformation.Computed

  @impl true
  def transform([amount, history], _context) do
    # Your custom logic here
    risk_score = String.to_integer(amount) * length(String.split(history, ","))
    {:ok, risk_score}
  end
end

# Use in mapping
%AshImport.Resource.ArgumentMapping{
  argument: :risk_score,
  transformation: %AshImport.Resource.Transformation{
    name: :computed,
    module: MyApp.Computations.RiskCalculator,
    inputs: [
      %{type: "column", name: "transaction_amount"},
      %{type: "column", name: "purchase_history"}
    ],
    options: %{}
  }
}
```

## Custom Transformations

### Custom Transformation

```elixir
defmodule MyApp.Transformations.PhoneNormalizer do
  def transform(phone) when is_binary(phone) do
    normalized = phone
    |> String.replace(~r/[^\d+]/, "")
    |> String.trim_leading("+")
    
    {:ok, "+1#{normalized}"}
  end
  
  def transform(_), do: {:error, "Invalid phone number"}
end

# Register in your resource
import_config do
  transformations do
    add :normalize_phone, MyApp.Transformations.PhoneNormalizer
  end
end

# Use in mapping
%AshImport.Resource.ArgumentMapping{
  argument: :phone,
  transformation: %AshImport.Resource.Transformation{
    name: :normalize_phone,
    module: MyApp.Transformations.PhoneNormalizer,
    inputs: [%{type: "column", name: "phone"}],
    options: %{}
  }
}
```

## JSON File Imports

### Basic JSON Import

```elixir
json_content = """
{
  "users": [
    {"email": "john@example.com", "full_name": "John Doe", "age": 30},
    {"email": "jane@example.com", "full_name": "Jane Smith", "age": 25}
  ]
}
"""

{:ok, job} = MyApp.User.ImportJob.create(%{
  file_type: :json,
  file_content: json_content,
  import_config: %{
    json_root_path: "users"  # Extract the users array
  }
}, domain: MyApp.Users)
```

### Flattened JSON

For nested JSON objects, you can enable flattening:

```elixir
{:ok, job} = MyApp.User.ImportJob.create(%{
  file_type: :json,
  file_content: nested_json_content,
  import_config: %{
    flatten?: true  # Converts user.profile.email to user_profile_email
  }
}, domain: MyApp.Users)
```

## Error Handling and Monitoring

### Checking Import Errors

```elixir
# Get failed import records
{:ok, failed_records} = Ash.read(MyApp.User.ImportRecord,
  domain: MyApp.Users,
  filter: [import_job_id: job.id, status: :failed]
)

Enum.each(failed_records, fn record ->
  IO.puts("Row #{record.row_number}: #{record.error_message}")
  IO.inspect(record.raw_data)
end)
```

### Retrying Failed Imports

```elixir
# Retry a failed import job
{:ok, retried_job} = Ash.update(job, :retry, %{}, domain: MyApp.Users)
```

### Cancelling Running Imports

```elixir
# Cancel a running import
{:ok, cancelled_job} = Ash.update(job, :cancel, %{}, domain: MyApp.Users)
```

## Actor Tracking

Track which user initiated imports:

```elixir
# Configure actor in your resource
import_config do
  belongs_to_actor :user, MyApp.User, domain: MyApp.Users
end

# Create import with actor
{:ok, job} = MyApp.User.ImportJob.create(%{
  file_type: :csv,
  file_path: "/path/to/file.csv"
}, domain: MyApp.Users, actor: current_user)
```

## Best Practices

1. **Start Small**: Test your mappings with a small sample file first
2. **Use Validations**: Add validations to your create action to catch data issues early
3. **Monitor Progress**: Set up monitoring for long-running imports
4. **Handle Errors Gracefully**: Always check for failed records and provide user feedback
5. **Use Transformations**: Normalize data during import rather than after
6. **Batch Size**: Adjust batch_size based on your data complexity and server capacity
7. **File Validation**: Validate file structure before starting large imports

## Next Steps

- Explore the [AshImport.Resource DSL Reference](../dsls/DSL-AshImport.Resource.md)
- Learn about [Advanced Value Derivation Patterns](advanced-patterns.md)
- Set up [Import Monitoring and Alerting](monitoring.md)