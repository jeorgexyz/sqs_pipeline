# Migration Guide: v0.1 → v0.2

This guide helps you migrate from the original incomplete implementation to the modernized v0.2.

## Major Changes

### Module Names
| Old | New |
|-----|-----|
| `GTube` / `Gtube` / `GTUBE` | `SqsPipeline` |
| `SQS.Server` | Removed (functionality in Producer) |
| `SQS.Producer` | `SqsPipeline.Producer` |
| `SQS.ProducerConsumer` | `SqsPipeline.ProducerConsumer` |
| `SQS.Consumer` | `SqsPipeline.Consumer` |
| `SQS.ConsumerSupervisor` | `SqsPipeline.ConsumerSupervisor` |

### Dependencies
```elixir
# Old (incomplete)
{:gen_stage, "~> 1.0.0"}

# New (complete)
{:gen_stage, "~> 1.2"},
{:ex_aws, "~> 2.5"},
{:ex_aws_s3, "~> 2.4"},
{:ex_aws_sqs, "~> 3.4"},
{:hackney, "~> 1.18"},
{:sweet_xml, "~> 0.7"},
{:jason, "~> 1.4"}
```

### Configuration

#### Old
No configuration files existed.

#### New
```elixir
# config/config.exs
config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role],
  region: {:system, "AWS_REGION"}

config :sqs_pipeline,
  queue_url: System.get_env("SQS_QUEUE_URL")
```

### Application Startup

#### Old
```elixir
defmodule GTube do
  use Application

  def start (_Type, _args) do
    import Supervisor.Spec  # Deprecated

    children = [
      worker(SQS.Server, []),  # Deprecated, missing module
      worker(SQS.Producer, []),
      # ...
    ]

    opts = [strategy: one_for_one, name: ApplicationSupervisor]  # Wrong format
    Supervisor.start_link(children, opts)
  end
end
```

#### New
```elixir
defmodule SqsPipeline.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {SqsPipeline.Producer, []},
      {SqsPipeline.ConsumerSupervisor, name: :pipeline_1, pipeline_id: 1},
      {SqsPipeline.ConsumerSupervisor, name: :pipeline_2, pipeline_id: 2},
      {SqsPipeline.ConsumerSupervisor, name: :pipeline_3, pipeline_id: 3}
    ]

    opts = [strategy: :one_for_one, name: SqsPipeline.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Producer Changes

#### Old Issues
- Used `//` instead of `\\` for default arguments
- Called non-existent `SQS.Server.pull/1`
- Incorrect GenServer.cast to wrong module name
- No actual SQS integration

#### New Implementation
- Properly polls SQS using ExAws
- Implements internal queue for demand buffering
- Parses S3 event notifications
- Uses `@` module attributes for constants
- Proper error handling

### ProducerConsumer Changes

#### Old Issues
- Typo: `ProducerConsumber` instead of `ProducerConsumer`
- Incomplete variable binding (`[events] = events`)
- Incorrect ExAws usage
- No error handling

#### New Implementation
- Fixed naming
- Proper event handling with `Enum.map`
- Error handling for S3 downloads
- Automatic gzip decompression
- Registry-based naming

### Consumer Changes

#### Old Issues
- Syntax errors in `use GenStage.start_link`
- Undefined `file` variable
- Incorrect string joining for module names
- Missing private functions

#### New Implementation
- Proper GenStage callbacks
- Complete processing pipeline
- JSON output format
- SQS message deletion after success
- Error handling and logging

## Step-by-Step Migration

### 1. Update Dependencies

```bash
# Remove old mix.lock
rm mix.lock

# Update mix.exs with new dependencies
cp mix.exs.new mix.exs

# Get dependencies
mix deps.get
```

### 2. Update Module References

Search and replace in your codebase:
```bash
# Find all references to old modules
grep -r "GTube\|Gtube\|GTUBE\|SQS\." lib/

# Update to new module names
sed -i 's/GTube/SqsPipeline/g' lib/**/*.ex
sed -i 's/SQS\./SqsPipeline./g' lib/**/*.ex
```

### 3. Add Configuration

```bash
# Create config directory
mkdir -p config

# Copy new configuration files
cp config/config.exs.new config/config.exs
cp config/dev.exs.new config/dev.exs
cp config/prod.exs.new config/prod.exs
cp config/runtime.exs.new config/runtime.exs
```

### 4. Update Application Module

Replace your main application module with the new structure.

### 5. Set Environment Variables

```bash
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
export SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/123456789012/your-queue
```

### 6. Test

```bash
# Compile
mix compile

# Run tests
mix test

# Run application
mix run --no-halt
```

## Breaking Changes

1. **Module Names**: All module names changed from `GTube`/`SQS` to `SqsPipeline`
2. **Configuration**: Now uses config files instead of hardcoded values
3. **Dependencies**: Added ExAws dependencies
4. **Output Format**: Changed from plain text to JSON
5. **File Structure**: Reorganized into proper lib/ structure

## New Features Available

1. **Docker Support**: Build and run in containers
2. **LocalStack Testing**: Test locally without AWS costs
3. **Automated Setup**: Use `scripts/setup_aws.sh`
4. **Better Logging**: Structured log messages
5. **Error Recovery**: Proper supervision and error handling
6. **Parallel Processing**: Multiple pipelines out of the box

## Customization Guide

### Change Processing Logic

Edit `lib/sqs_pipeline/consumer.ex`:

```elixir
defp process_file(content) do
  # Old: Count lines
  line_count = content |> String.split("\n") |> length()

  # New: Your custom logic
  result = YourModule.process(content)
  
  %{
    result: result,
    processed_at: DateTime.utc_now()
  }
end
```

### Add More Pipelines

Edit `lib/sqs_pipeline/application.ex`:

```elixir
children = [
  {SqsPipeline.Producer, []},
  {SqsPipeline.ConsumerSupervisor, name: :pipeline_1, pipeline_id: 1},
  {SqsPipeline.ConsumerSupervisor, name: :pipeline_2, pipeline_id: 2},
  {SqsPipeline.ConsumerSupervisor, name: :pipeline_3, pipeline_id: 3},
  # Add more pipelines
  {SqsPipeline.ConsumerSupervisor, name: :pipeline_4, pipeline_id: 4},
  {SqsPipeline.ConsumerSupervisor, name: :pipeline_5, pipeline_id: 5}
]
```

### Adjust Demand Levels

Higher demand = more parallelism per pipeline, but higher memory usage.

```elixir
# In producer_consumer.ex
subscribe_to: [{SqsPipeline.Producer, min_demand: 0, max_demand: 10}]

# In consumer.ex  
subscribe_to: [{pc, min_demand: 5, max_demand: 50}]
```

## Getting Help

- Check `ARCHITECTURE.md` for system design
- Review `README.md` for setup instructions
- Read inline code documentation
- Run `mix docs` to generate documentation

## Rollback Plan

If you need to rollback:

1. Keep the old codebase in a separate branch
2. The new version is completely separate - no shared state
3. Can run both versions side-by-side with different queue names

## Testing Your Migration

1. **Test with LocalStack first**:
   ```bash
   docker-compose up -d localstack
   ./scripts/test_local.sh
   ```

2. **Test with real AWS (dev environment)**:
   ```bash
   MIX_ENV=dev mix run --no-halt
   aws s3 cp test.txt s3://your-bucket/
   ```

3. **Monitor logs**:
   ```bash
   tail -f output/*.json
   ```

4. **Verify SQS messages are being deleted**:
   ```bash
   aws sqs get-queue-attributes \
     --queue-url $SQS_QUEUE_URL \
     --attribute-names ApproximateNumberOfMessages
   ```
