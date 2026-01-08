# SQS Pipeline

A production-ready GenStage-based data processing pipeline for AWS S3/SQS events.

## Architecture

```
S3/SQS → [Producer] → [ProducerConsumer] → [Consumer] → Output
                ↓              ↓                ↓
            Polls SQS    Downloads S3      Processes & 
                         Files             Deletes from SQS
```

### Components

1. **Producer** - Polls SQS for new messages (S3 event notifications)
2. **ProducerConsumer** - Downloads S3 objects and decompresses if needed
3. **Consumer** - Processes files and writes results to disk

### Features

- **Backpressure handling** - GenStage demand-driven architecture prevents overwhelming
- **Parallel processing** - Multiple consumer pipelines (configurable)
- **Automatic decompression** - Handles gzipped files automatically
- **Resilient** - Supervisor trees ensure fault tolerance
- **Production-ready** - Proper error handling, logging, and AWS integration

## Prerequisites

- Elixir 1.14+
- AWS Account with:
  - S3 bucket configured to send notifications to SQS
  - SQS queue receiving S3 event notifications
  - IAM credentials with permissions for S3 and SQS

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd sqs_pipeline
```

2. Install dependencies:
```bash
mix deps.get
```

3. Configure AWS credentials (choose one):

**Option A: Environment variables**
```bash
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_REGION=us-east-1
export SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/123456789012/your-queue
```

**Option B: IAM Role (recommended for EC2/ECS)**
- Attach an IAM role with S3 and SQS permissions to your instance
- The application will automatically use instance credentials

## AWS Setup

### 1. Create S3 Bucket and Enable Notifications

```bash
# Create bucket
aws s3 mb s3://your-data-bucket

# Create SQS queue
aws sqs create-queue --queue-name data-processing-queue

# Get queue ARN
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/data-processing-queue \
  --attribute-names QueueArn
```

### 2. Configure S3 to send notifications to SQS

Create a file `notification.json`:
```json
{
  "QueueConfigurations": [
    {
      "QueueArn": "arn:aws:sqs:us-east-1:123456789012:data-processing-queue",
      "Events": ["s3:ObjectCreated:*"]
    }
  ]
}
```

Apply the configuration:
```bash
aws s3api put-bucket-notification-configuration \
  --bucket your-data-bucket \
  --notification-configuration file://notification.json
```

### 3. Set SQS Queue Policy

The SQS queue needs permission to receive messages from S3. Create `queue-policy.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Action": "SQS:SendMessage",
      "Resource": "arn:aws:sqs:us-east-1:123456789012:data-processing-queue",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "arn:aws:s3:::your-data-bucket"
        }
      }
    }
  ]
}
```

Apply the policy:
```bash
aws sqs set-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/123456789012/data-processing-queue \
  --attributes file://queue-policy.json
```

## Configuration

Edit `config/dev.exs` or set environment variables:

```elixir
config :sqs_pipeline,
  queue_url: "https://sqs.us-east-1.amazonaws.com/123456789012/your-queue"

config :ex_aws,
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_access_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
  region: System.get_env("AWS_REGION") || "us-east-1"
```

## Running

### Development
```bash
mix run --no-halt
```

### Production
```bash
# Build release
MIX_ENV=prod mix release

# Run
_build/prod/rel/sqs_pipeline/bin/sqs_pipeline start
```

### Docker
```dockerfile
FROM elixir:1.14-alpine

WORKDIR /app
COPY . .

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    MIX_ENV=prod mix release

CMD ["_build/prod/rel/sqs_pipeline/bin/sqs_pipeline", "start"]
```

Build and run:
```bash
docker build -t sqs-pipeline .
docker run -e SQS_QUEUE_URL=$SQS_QUEUE_URL \
           -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
           -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
           sqs-pipeline
```

## Testing

### Local Testing with LocalStack

1. Start LocalStack:
```bash
docker run -d -p 4566:4566 localstack/localstack
```

2. Create test resources:
```bash
# Create bucket
aws --endpoint-url=http://localhost:4566 s3 mb s3://test-bucket

# Create queue
aws --endpoint-url=http://localhost:4566 sqs create-queue \
  --queue-name test-queue
```

3. Run tests:
```bash
mix test
```

## Customization

### Processing Logic

Edit `lib/sqs_pipeline/consumer.ex` to customize processing:

```elixir
defp process_file(content) do
  # Your custom processing logic here
  # Examples:
  # - Parse CSV/JSON
  # - Run analytics
  # - Transform data
  # - Send to database
  
  %{
    result: "your_result",
    processed_at: DateTime.utc_now()
  }
end
```

### Number of Pipelines

Edit `lib/sqs_pipeline/application.ex` to add more parallel pipelines:

```elixir
children = [
  {SqsPipeline.Producer, []},
  {SqsPipeline.ConsumerSupervisor, name: :pipeline_1, pipeline_id: 1},
  {SqsPipeline.ConsumerSupervisor, name: :pipeline_2, pipeline_id: 2},
  {SqsPipeline.ConsumerSupervisor, name: :pipeline_3, pipeline_id: 3},
  {SqsPipeline.ConsumerSupervisor, name: :pipeline_4, pipeline_id: 4},  # Add more
]
```

### Demand Settings

Adjust `min_demand` and `max_demand` in each stage to control backpressure:

```elixir
# In producer_consumer.ex
subscribe_to: [
  {SqsPipeline.Producer, min_demand: 0, max_demand: 5}  # Process 5 at a time
]

# In consumer.ex
subscribe_to: [
  {via_tuple_pc(pipeline_id), min_demand: 0, max_demand: 20}  # Process 20 at a time
]
```

## Monitoring

The application logs key events:

- Message polling from SQS
- S3 downloads
- Processing results
- Errors and failures

Example log output:
```
[info] SqsPipeline.Producer started
[info] Fetched 5 messages from SQS
[info] Downloading s3://bucket/data/file.txt.gz
[info] Pipeline 1 successfully processed data/file.txt.gz
```

## Output

Processed results are written to `output/` directory:

```json
{
  "line_count": 1523,
  "byte_size": 45230,
  "processed_at": "2026-01-07T12:34:56.789Z"
}
```

## Performance Tuning

1. **Increase pipelines** for more parallelism
2. **Adjust demand** to control batch sizes
3. **Poll interval** - Modify `@poll_interval` in Producer
4. **SQS long polling** - Already set to 10 seconds for efficiency

## Error Handling

- Failed S3 downloads are logged and skipped
- Failed processing is logged but won't crash pipelines
- Messages are only deleted after successful processing
- Supervisor trees restart failed processes

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

