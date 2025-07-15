# DSL: AshImport.Resource

The `AshImport.Resource` extension adds import capabilities to your Ash resources. When used, it automatically generates ImportJob and ImportRecord resources to handle file imports with flexible data transformation.

## import_config

Configuration for import behavior on this resource.

### Options

| Name | Type | Default | Docs |
|------|------|---------|------|
| `supported_formats` | `list(atom)` | `[:csv, :json]` | Supported file formats for import |
| `max_file_size_mb` | `integer` | `100` | Maximum file size in megabytes |
| `create_action` | `atom` | `:create` | The action to use when creating records from imports (deprecated: use `create_actions` instead) |
| `batch_size` | `integer` | `100` | Number of records to process in each batch |
| `max_concurrent_jobs` | `integer` | `5` | Maximum number of concurrent import jobs per resource |
| `track_progress?` | `boolean` | `true` | Whether to track import progress |
| `store_errors?` | `boolean` | `true` | Whether to store detailed error information for failed records |
| `relationship_opts` | `keyword_list` |  | Options to pass to the has_many :import_jobs relationship |
| `mixin` | `atom \| mfa` |  | A module or MFA tuple to mix into the generated import resources |
| `import_extensions` | `keyword_list` | `[]` | Extensions for the generated import resources |
| `table_name_suffix` | `string` | `"_import_jobs"` | Suffix for the import job table name in SQL data layers |
| `job_resource_name` | `atom` |  | Override the name of the generated ImportJob resource |
| `record_resource_name` | `atom` |  | Override the name of the generated ImportRecord resource |

### Introspection

The following functions can be used to retrieve configuration:

- `AshImport.Resource.Info.supported_formats/1`
- `AshImport.Resource.Info.max_file_size_mb/1`
- `AshImport.Resource.Info.create_action/1` (deprecated)
- `AshImport.Resource.Info.create_actions/1` (use this instead)
- `AshImport.Resource.Info.batch_size/1`
- `AshImport.Resource.Info.max_concurrent_jobs/1`
- `AshImport.Resource.Info.track_progress?/1`
- `AshImport.Resource.Info.store_errors?/1`

## import_config.belongs_to_actor

Creates a belongs_to relationship for the actor resource on the ImportJob. When creating a new import job, if the actor on the action is set and matches the resource type, the import job will be related to the actor.

### Arguments

| Name | Type | Docs |
|------|------|------|
| `name` | `atom` | The name of the relationship (e.g., :user) |
| `destination` | `atom` | The resource of the actor (e.g., MyApp.Users.User) |

### Options

| Name | Type | Default | Docs |
|------|------|---------|------|
| `domain` | `atom` |  | The domain that the destination resource belongs to |
| `define_attribute?` | `boolean` | `true` | Whether to define the foreign key attribute |
| `allow_nil?` | `boolean` | `true` | Whether this relationship must always be present |
| `attribute_type` | `atom` |  | The type of the foreign key attribute |
| `public?` | `boolean` | `false` | Whether the relationship should be public |

### Examples

```elixir
belongs_to_actor :user, MyApp.Users.User, domain: MyApp.Users
```

## import_config.transformations

Define custom transformations available for column value processing.

### transformations.add

Add a custom transformation function.

#### Arguments

| Name | Type | Docs |
|------|------|------|
| `name` | `atom` | The name of the transformation |
| `module` | `atom` | The module containing the transformation logic |

#### Examples

```elixir
add :parse_phone, MyApp.Transformations.PhoneParser
```

## Generated Resources

When you add `AshImport.Resource` to a resource, it automatically generates two new resources:

### ImportJob Resource

- **Name**: `{YourResource}.ImportJob`
- **Purpose**: Tracks import jobs with configuration, status, and progress
- **Key Attributes**:
  - `file_path`, `file_type`, `file_size`, `file_hash`
  - `status` - `:pending`, `:processing`, `:completed`, `:failed`, `:cancelled`
  - `import_config` - Overall import configuration
  - `argument_mappings` - Array of value derivation configurations
  - Progress tracking fields (if enabled)
  - Error tracking fields (if enabled)

- **Key Actions**:
  - `create` - Create a new import job
  - `configure_mappings` - Set up argument mappings
  - `start` - Begin background processing
  - `cancel` - Cancel a running import
  - `retry` - Retry a failed import

### ImportRecord Resource

- **Name**: `{YourResource}.ImportRecord`
- **Purpose**: Tracks individual record import attempts
- **Key Attributes**:
  - `row_number`, `raw_data`, `transformed_data`
  - `status` - `:pending`, `:processing`, `:success`, `:failed`, `:skipped`
  - `created_record_id` - ID of successfully created record
  - Error and retry tracking fields

- **Key Actions**:
  - `create` - Create import record entries
  - `process` - Process individual record
  - `mark_success`/`mark_failed`/`mark_skipped` - Update status
  - `retry` - Retry failed record

## Value Derivation System

The heart of AshImport is its flexible value derivation system. Each action argument can be mapped using `ArgumentMapping` configurations that define how to transform raw import data into resource attributes.

### Argument Mapping Structure

Argument mappings use the `AshImport.Resource.ArgumentMapping` embedded resource:

```elixir
%AshImport.Resource.ArgumentMapping{
  argument: :email,
  transformation: %AshImport.Resource.Transformation{
    name: :get_value,
    module: AshImport.Transformation.GetValue,
    inputs: [%{type: "column", name: "email_address"}],
    options: %{}
  }
}
```

### Required Arguments Validation

AshImport validates that all **required arguments** for the selected create action are properly mapped before starting an import. This ensures data integrity and prevents runtime errors.

### Transformation Types

#### Static Values
Provide a hardcoded value for all records.

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

#### Column Mapping
Maps a single column with optional transformations.

```elixir
%AshImport.Resource.ArgumentMapping{
  argument: :email,
  transformation: %AshImport.Resource.Transformation{
    name: :get_value,
    module: AshImport.Transformation.GetValue,
    inputs: [%{type: "column", name: "email_address"}],
    options: %{}
  }
}
```

#### Multi-column Mapping
Combine multiple columns using transformations.

```elixir
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
}
```

#### Expression Evaluation
Evaluate simple mathematical expressions.

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

#### User Input
Prompt user for values during configuration.

```elixir
%AshImport.Resource.ArgumentMapping{
  argument: :category,
  transformation: %AshImport.Resource.Transformation{
    name: :user_input,
    module: AshImport.Transformation.UserInput,
    inputs: [%{type: "user_input", name: "category"}],
    options: %{
      "prompt" => "Select category",
      "input_type" => "select",
      "options" => ["electronics", "clothing", "food"]
    }
  }
}
```

### Built-in Transformation Modules

- `AshImport.Transformation.Trim` - Remove whitespace
- `AshImport.Transformation.Downcase` - Convert to lowercase
- `AshImport.Transformation.Upcase` - Convert to uppercase
- `AshImport.Transformation.ParseInteger` - Parse integers
- `AshImport.Transformation.ParseFloat` - Parse floating-point numbers
- `AshImport.Transformation.ParseDate` - Parse date strings
- `AshImport.Transformation.ParseDatetime` - Parse datetime strings
- `AshImport.Transformation.Concat` - Concatenate values
- `AshImport.Transformation.Join` - Join values with separator
- `AshImport.Transformation.Sum` - Sum numeric values
- `AshImport.Transformation.Average` - Calculate average
- `AshImport.Transformation.Min` - Find minimum value
- `AshImport.Transformation.Max` - Find maximum value
- `AshImport.Transformation.FirstNonEmpty` - Return first non-empty value

## Examples

### Basic Resource Configuration

```elixir
defmodule MyApp.User do
  use Ash.Resource,
    domain: MyApp.Users,
    extensions: [AshImport.Resource]

  import_config do
    supported_formats [:csv, :json]
    create_action :create
    batch_size 50
    track_progress? true
    store_errors? true
    
    belongs_to_actor :admin, MyApp.Admin, domain: MyApp.Accounts
    
    transformations do
      add :normalize_phone, MyApp.Transformations.PhoneNormalizer
    end
  end

  # ... rest of resource definition
end
```

### Complex Argument Mapping

```elixir
# During import job configuration
argument_mappings = [
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
        %{type: "column", name: "first"},
        %{type: "column", name: "last"}
      ],
      options: %{"separator" => " "}
    }
  },
  
  %AshImport.Resource.ArgumentMapping{
    argument: :total,
    transformation: %AshImport.Resource.Transformation{
      name: :expression,
      module: AshImport.Transformation.Expression,
      inputs: [
        %{type: "column", name: "quantity"},
        %{type: "column", name: "price"}
      ],
      options: %{"expression" => "quantity * price"}
    }
  },
  
  %AshImport.Resource.ArgumentMapping{
    argument: :category,
    transformation: %AshImport.Resource.Transformation{
      name: :computed,
      module: AshImport.Transformation.Computed,
      inputs: [
        %{type: "column", name: "description"},
        %{type: "column", name: "tags"}
      ],
      options: %{
        "module" => "MyApp.CategoryClassifier",
        "function" => "classify"
      }
    }
  }
]
```