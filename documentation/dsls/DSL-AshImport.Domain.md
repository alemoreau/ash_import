# DSL: AshImport.Domain

The `AshImport.Domain` extension automatically includes import resources (ImportJob and ImportRecord) from resources that use the `AshImport.Resource` extension.

## import_config

Configuration for import behavior at the domain level.

### Options

| Name | Type | Default | Docs |
|------|------|---------|------|
| `include_import_resources?` | `boolean` | `false` | Automatically include all import job and record resources in the domain |

### Introspection

The following function can be used to retrieve configuration:

- `AshImport.Domain.Info.include_import_resources?/1`

## Behavior

When `include_import_resources?` is set to `true`, the domain will automatically include:

1. All `ImportJob` resources from resources using `AshImport.Resource`
2. All `ImportRecord` resources from resources using `AshImport.Resource`

This means you don't need to manually add these generated resources to your domain's `resources` block.

## Examples

### Auto-include All Import Resources

```elixir
defmodule MyApp.Users do
  use Ash.Domain,
    extensions: [AshImport.Domain]

  import_config do
    include_import_resources? true
  end

  resources do
    resource MyApp.User
    resource MyApp.Admin
    # MyApp.User.ImportJob and MyApp.User.ImportRecord
    # are automatically included due to include_import_resources? true
  end
end
```

### Manual Resource Inclusion

```elixir
defmodule MyApp.Users do
  use Ash.Domain,
    extensions: [AshImport.Domain]

  import_config do
    include_import_resources? false
  end

  resources do
    resource MyApp.User
    resource MyApp.Admin
    
    # Manually include specific import resources
    resource MyApp.User.ImportJob
    resource MyApp.User.ImportRecord
  end
end
```

### Mixed Approach

```elixir
defmodule MyApp.Mixed do
  use Ash.Domain,
    extensions: [AshImport.Domain]

  import_config do
    include_import_resources? true
  end

  resources do
    # Resources with AshImport.Resource extension
    resource MyApp.User     # Auto-includes User.ImportJob and User.ImportRecord
    resource MyApp.Product  # Auto-includes Product.ImportJob and Product.ImportRecord
    
    # Regular resources
    resource MyApp.Category
    resource MyApp.Tag
    
    # All import resources are automatically available
  end
end
```

## Generated Resource Access

When using `include_import_resources? true`, you can access the generated resources directly:

```elixir
# These resources are automatically available in your domain
MyApp.User.ImportJob
MyApp.User.ImportRecord
MyApp.Product.ImportJob  
MyApp.Product.ImportRecord

# You can use them with Ash functions
{:ok, job} = Ash.create(MyApp.User.ImportJob, %{
  file_type: :csv,
  file_path: "/path/to/file.csv"
}, domain: MyApp.Users)

{:ok, jobs} = Ash.read(MyApp.User.ImportJob, domain: MyApp.Users)
```

## Benefits

### Auto-inclusion (`include_import_resources? true`)

**Pros:**
- Less boilerplate - no need to manually list import resources
- Automatically stays in sync as you add/remove `AshImport.Resource` extensions
- Cleaner domain definition

**Cons:**
- Less explicit about which resources are included
- All import resources are included (no selective inclusion)

### Manual inclusion (`include_import_resources? false`)

**Pros:**
- Explicit control over which import resources are included
- Clear visibility of all domain resources
- Can selectively include only certain import resources

**Cons:**
- More boilerplate code
- Need to remember to add import resources when adding `AshImport.Resource` extension
- Can get out of sync if you forget to update the domain

## Recommendation

Use `include_import_resources? true` in most cases for convenience, especially during development. Consider manual inclusion if you need fine-grained control over resource exposure or in complex domains with many resources.