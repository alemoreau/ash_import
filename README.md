![Logo](https://github.com/ash-project/ash/blob/main/logos/cropped-for-header-black-text.png?raw=true#gh-light-mode-only)
![Logo](https://github.com/ash-project/ash/blob/main/logos/cropped-for-header-white-text.png?raw=true#gh-dark-mode-only)

![Elixir CI](https://github.com/ash-project/ash_import/workflows/CI/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hex version badge](https://img.shields.io/hexpm/v/ash_import.svg)](https://hex.pm/packages/ash_import)
[![Hexdocs badge](https://img.shields.io/badge/docs-hexdocs-purple)](https://hexdocs.pm/ash_import)

# AshImport

Welcome! This is the extension for importing CSV and JSON files into your [Ash](https://hexdocs.pm/ash) resources with powerful, flexible data transformation capabilities.

## ✨ Features

- 📁 **Multiple File Formats**: Support for CSV and JSON files with configurable parsing options
- 🎯 **Flexible Value Derivation**: Map file data to resource attributes using multiple strategies:
  - Static values
  - Single column mapping with transformations
  - Multi-column combination with transformations
  - Mathematical expressions
  - User input prompts
  - Custom computed functions
- ⚡ **Background Processing**: Powered by Oban for scalable, reliable import processing
- 📊 **Progress Tracking**: Real-time progress updates with detailed error reporting
- 🔄 **Retry Logic**: Automatic retry capabilities for failed imports
- 👥 **Actor Tracking**: Track which users initiated imports
- 🏗️ **Auto-Generated Resources**: Automatically creates ImportJob and ImportRecord resources
- 🔧 **Extensible**: Easy to add custom transformations and reducers

## Quick Start

### 1. Add to your dependencies

```elixir
def deps do
  [
    {:ash_import, "~> 0.1.0"},
    {:ash_oban, "~> 0.2"}, # Required for background processing
    {:oban, "~> 2.15"} # Required for background processing
  ]
end
```

### 2. Add to your formatter

```elixir
# .formatter.exs
[
  import_deps: [:ash, :ash_import],
  # ... other config
]
```

### 3. Configure your resource

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
    
    # Track who initiated the import
    belongs_to_actor :admin, MyApp.Admin, domain: MyApp.Accounts
    
    # Custom transformations
    transformations do
      add :normalize_phone, MyApp.Transformations.PhoneNormalizer
      add :validate_email, MyApp.Transformations.EmailValidator
    end
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
    end
  end
end
```

### 4. Configure your domain

```elixir
defmodule MyApp.Users do
  use Ash.Domain,
    extensions: [AshImport.Domain]

  import_config do
    include_import_resources? true  # Auto-include ImportJob and ImportRecord
  end

  resources do
    resource MyApp.User
    resource MyApp.Admin
  end
end
```

### 5. Use the import functionality

```elixir
# Create an import job
{:ok, job} = MyApp.User.ImportJob.create(%{
  file_path: "/path/to/users.csv",
  file_type: :csv
}, domain: MyApp.Users)

# Configure flexible argument mappings
{:ok, job} = Ash.update(job, :configure_mappings, %{
  argument_mappings: [
    %AshImport.Resource.ArgumentMapping{
      argument: :email,
      transformation: %AshImport.Resource.Transformation{
        name: :get_value,
        module: AshImport.Transformation.GetValue,
        inputs: [%{type: "column", name: "email_address"}]
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
      argument: :active,
      transformation: %AshImport.Resource.Transformation{
        name: :static_value,
        module: AshImport.Transformation.Static,
        inputs: [%{type: "static", value: true}]
      }
    },
    
    %AshImport.Resource.ArgumentMapping{
      argument: :phone,
      transformation: %AshImport.Resource.Transformation{
        name: :normalize_phone,
        module: MyApp.Transformations.PhoneNormalizer,
        inputs: [%{type: "column", name: "phone"}]
      }
    }
  ]
}, domain: MyApp.Users)

# Start the import (processes in background)
{:ok, job} = Ash.update(job, :start, %{}, domain: MyApp.Users)

# Check progress
IO.inspect(job.status)           # :processing
IO.inspect(job.processed_records) # 150
IO.inspect(job.total_records)     # 1000
```

## Value Derivation Types

AshImport supports multiple ways to derive values for your resource attributes using the `ArgumentMapping` system:

### Static Values
```elixir
%AshImport.Resource.ArgumentMapping{
  argument: :active,
  transformation: %AshImport.Resource.Transformation{
    name: :static_value,
    module: AshImport.Transformation.Static,
    inputs: [%{type: "static", value: true}]
  }
}
```

### Column Mapping
```elixir
%AshImport.Resource.ArgumentMapping{
  argument: :email,
  transformation: %AshImport.Resource.Transformation{
    name: :get_value,
    module: AshImport.Transformation.GetValue,
    inputs: [%{type: "column", name: "email_address"}],
    options: %{"transformations" => ["downcase", "trim"]}
  }
}
```

### Multi-Column Combination
```elixir
%AshImport.Resource.ArgumentMapping{
  argument: :full_name,
  transformation: %AshImport.Resource.Transformation{
    name: :join,
    module: AshImport.Transformation.Join,
    inputs: [
      %{type: "column", name: "first_name"},
      %{type: "column", name: "last_name"}
    ],
    options: %{"separator" => " "}
  }
}
```

### Mathematical Expressions
```elixir
%AshImport.Resource.ArgumentMapping{
  argument: :total_price,
  transformation: %AshImport.Resource.Transformation{
    name: :expression,
    module: AshImport.Transformation.Expression,
    inputs: [
      %{type: "column", name: "price"},
      %{type: "column", name: "tax_rate"}
    ],
    options: %{"expression" => "price * (1 + tax_rate / 100)"}
  }
}
```

### User Input
```elixir
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
```

### Custom Computed Values
```elixir
%AshImport.Resource.ArgumentMapping{
  argument: :risk_score,
  transformation: %AshImport.Resource.Transformation{
    name: :computed,
    module: MyApp.RiskCalculator,
    inputs: [
      %{type: "column", name: "transaction_amount"},
      %{type: "column", name: "user_history"}
    ],
    options: %{"function" => "calculate"}
  }
}
```

## Built-in Transformation Modules

AshImport provides comprehensive transformation modules for common operations:

### String Transformations
- `AshImport.Transformation.Trim` - Remove leading/trailing whitespace
- `AshImport.Transformation.Downcase` - Convert to lowercase
- `AshImport.Transformation.Upcase` - Convert to uppercase
- `AshImport.Transformation.Replace` - String replacement

### Parsing Transformations
- `AshImport.Transformation.ParseInteger` - Parse integers from strings
- `AshImport.Transformation.ParseFloat` - Parse floating-point numbers
- `AshImport.Transformation.ParseDate` - Parse date strings
- `AshImport.Transformation.ParseDatetime` - Parse datetime strings
- `AshImport.Transformation.ParseBoolean` - Parse boolean values

### Collection Transformations
- `AshImport.Transformation.Join` - Join multiple values with separator
- `AshImport.Transformation.Concat` - Concatenate values
- `AshImport.Transformation.FirstNonEmpty` - Return first non-empty value
- `AshImport.Transformation.Sum` - Sum numeric values
- `AshImport.Transformation.Average` - Calculate average
- `AshImport.Transformation.Min` / `AshImport.Transformation.Max` - Find min/max values

### Input Sources
- `AshImport.Transformation.GetValue` - Extract value from single column
- `AshImport.Transformation.Static` - Provide static values
- `AshImport.Transformation.UserInput` - Get values from user input
- `AshImport.Transformation.Expression` - Evaluate mathematical expressions
- `AshImport.Transformation.Computed` - Use custom computed functions

## Tutorials

- [Getting Started with AshImport](documentation/tutorials/getting-started-with-ash-import.md)

## Reference

- [AshImport.Resource DSL](documentation/dsls/DSL-AshImport.Resource.md)
- [AshImport.Domain DSL](documentation/dsls/DSL-AshImport.Domain.md)
