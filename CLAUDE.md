# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AshImport is a comprehensive Elixir library that provides powerful CSV and JSON file import capabilities for Ash resources. It features a flexible value derivation system, background processing via AshOban, and automatically generates ImportJob and ImportRecord resources to handle complex data transformations.

## Development Commands

### Testing
- `mix test` - Run all tests
- `mix test test/path/to/specific_test.exs` - Run a specific test file

### Code Quality
- `mix credo --strict` - Run static code analysis with strict mode
- `mix dialyxir` - Run type checking
- `mix sobelow --skip` - Run security analysis (with skipped checks)
- `mix format` - Format code according to project standards
- `mix spark.formatter` - Format Spark DSL extensions

### Documentation
- `mix docs` - Generate documentation (includes Spark cheat sheets and doc link replacement)
- `mix spark.cheat_sheets` - Generate DSL cheat sheets

### Dependencies
- `mix deps.get` - Install dependencies
- `mix deps.update` - Update dependencies

## Architecture

### Core Components

1. **AshImport.Resource** - Main extension that adds import capabilities to Ash resources
   - Automatically creates ImportJob and ImportRecord resources
   - Configurable via the `import_config` DSL block
   - Supports flexible value derivation from multiple sources

2. **AshImport.Domain** - Domain-level extension for including import resources
   - Can automatically include all import resources with `include_import_resources? true`

3. **Value Derivation System** - Flexible mapping configuration
   - `ArgumentMapping` - Maps action arguments to values from various sources
   - Multiple derivation types: static, column, columns, expression, user_input, computed
   - Embedded resources for configuration: StaticValueConfig, ColumnValueConfig, etc.

4. **Transformers** - Located in `lib/resource/transformers/` and `lib/domain/transformers/`
   - `CreateEmbeddedResources` - Creates embedded configuration resources
   - `CreateImportJobResource` - Generates ImportJob resource
   - `CreateImportRecordResource` - Generates ImportRecord resource
   - `RelateImportResources` - Adds relationships to original resource
   - `ValidateBelongsToActor` - Validates actor relationships

### Key Configuration Options

The `import_config` DSL supports:
- `supported_formats` - File formats to support (CSV, JSON)
- `create_action` - Which action to use for creating records
- `batch_size` - Number of records per batch
- `track_progress?` - Enable progress tracking
- `store_errors?` - Store detailed error information
- `belongs_to_actor` - Track which user initiated the import
- `transformations` - Custom value transformations

### Generated Resources

For each resource with `AshImport.Resource`:
- `{Resource}.ImportJob` - Tracks import jobs with status, progress, and configuration
- `{Resource}.ImportRecord` - Individual record import attempts
- `{Resource}.ImportConfig.*` - Embedded resources for configuration including:
  - `ArgumentMapping` - Main configuration for mapping arguments to values
  - `StaticValueConfig`, `ColumnValueConfig`, `MultiColumnConfig`, etc. - Different derivation strategies
  - `Transformation` - For value transformations (trim, downcase, parse_date, etc.)

### Background Processing

Uses Oban workers for scalable processing:
- `AshImport.Workers.ImportJobWorker` - Orchestrates overall import process
- `AshImport.Workers.ImportRecordWorker` - Processes individual records
- Supports cancellation, retry logic, and progress tracking

### File Processing

Comprehensive file handling with:
- `AshImport.Processors.CsvProcessor` - Advanced CSV parsing with delimiter detection
- `AshImport.Processors.JsonProcessor` - JSON parsing with JSONPath extraction and flattening
- File validation, structure analysis, and parsing option suggestions

### Test Structure

Tests will be organized under `test/support/` with example resources demonstrating different import configurations.

## Formatter Configuration

The project uses custom Spark DSL formatting defined in `.formatter.exs` with specific `locals_without_parens` for import DSL functions.

## Dependencies

Key dependencies include:
- `ash` ~> 3.5 - Core Ash framework
- `ash_oban` ~> 0.2 - Background job processing
- `nimble_csv` ~> 1.2 - CSV parsing
- `jason` ~> 1.4 - JSON parsing
- `igniter` - Code generation and modification
- `spark` - DSL framework for Elixir
- Development tools: `credo`, `dialyxir`, `sobelow`, `ex_doc`