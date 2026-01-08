# Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                            │
│                                                              │
│  ┌──────────┐           ┌──────────┐                        │
│  │ S3       │           │ SQS      │                        │
│  │ Bucket   │──────────▶│ Queue    │                        │
│  └──────────┘  Events   └──────────┘                        │
│                              │                               │
└──────────────────────────────┼───────────────────────────────┘
                               │
                               │ Poll Messages
                               │
┌──────────────────────────────┼───────────────────────────────┐
│                    SQS Pipeline Application                  │
│                               │                               │
│                               ▼                               │
│                        ┌──────────────┐                       │
│                        │  Producer    │                       │
│                        │  (GenStage)  │                       │
│                        └──────┬───────┘                       │
│                               │                               │
│                    Distribute Events                          │
│              ┌────────────────┼────────────────┐             │
│              │                │                 │             │
│              ▼                ▼                 ▼             │
│     ┌────────────────┐ ┌────────────────┐ ┌────────────────┐│
│     │  Pipeline 1    │ │  Pipeline 2    │ │  Pipeline 3    ││
│     ├────────────────┤ ├────────────────┤ ├────────────────┤│
│     │ProducerConsumer│ │ProducerConsumer│ │ProducerConsumer││
│     │ Download S3    │ │ Download S3    │ │ Download S3    ││
│     │ Decompress     │ │ Decompress     │ │ Decompress     ││
│     └───────┬────────┘ └───────┬────────┘ └───────┬────────┘│
│             │                  │                   │          │
│             ▼                  ▼                   ▼          │
│     ┌────────────────┐ ┌────────────────┐ ┌────────────────┐│
│     │   Consumer 1   │ │   Consumer 2   │ │   Consumer 3   ││
│     │ Process File   │ │ Process File   │ │ Process File   ││
│     │ Write Output   │ │ Write Output   │ │ Write Output   ││
│     │ Delete from SQS│ │ Delete from SQS│ │ Delete from SQS││
│     └───────┬────────┘ └───────┬────────┘ └───────┬────────┘│
│             │                  │                   │          │
└─────────────┼──────────────────┼───────────────────┼──────────┘
              │                  │                   │
              ▼                  ▼                   ▼
         ┌─────────────────────────────────────────────┐
         │            output/ directory                 │
         │          (JSON result files)                 │
         └─────────────────────────────────────────────┘
```

## Component Details

### Producer (SqsPipeline.Producer)
- **Type**: GenStage Producer
- **Responsibility**: Poll SQS for messages
- **Features**:
  - Long polling (10 seconds) for efficiency
  - Demand-driven polling (only polls when downstream needs data)
  - Queues messages internally
  - Parses S3 event notifications
- **Configurable**: Poll interval, max messages per request

### ProducerConsumer (SqsPipeline.ProducerConsumer)
- **Type**: GenStage ProducerConsumer
- **Responsibility**: Download and prepare file content
- **Features**:
  - Downloads objects from S3
  - Automatic gzip decompression
  - Error handling for failed downloads
  - Passes file content downstream
- **Multiple Instances**: One per pipeline for parallelism

### Consumer (SqsPipeline.Consumer)
- **Type**: GenStage Consumer
- **Responsibility**: Process files and manage SQS lifecycle
- **Features**:
  - Processes file content (line counting example)
  - Writes results to output directory
  - Deletes messages from SQS after success
  - Error handling prevents message deletion on failure
- **Multiple Instances**: One per pipeline for parallelism

## Data Flow

1. **File Upload**: User uploads file to S3 bucket
2. **S3 Event**: S3 sends notification to SQS queue
3. **Poll**: Producer polls SQS when downstream demands data
4. **Parse**: Producer parses S3 event notification
5. **Distribute**: Producer distributes events to available pipelines
6. **Download**: ProducerConsumer downloads file from S3
7. **Decompress**: ProducerConsumer decompresses if needed
8. **Process**: Consumer processes file content
9. **Output**: Consumer writes results to disk
10. **Cleanup**: Consumer deletes message from SQS

## Backpressure

GenStage provides automatic backpressure:

```
Consumer (demand: 10)
    ↓ "I need 10 events"
ProducerConsumer (demand: 1)
    ↓ "I need 1 event to fulfill demand"
Producer
    ↓ Polls SQS for 1 message
```

If consumers are slow, producer automatically stops polling until demand increases.

## Supervision Tree

```
Application.Supervisor (one_for_one)
├── Producer
├── ConsumerSupervisor (Pipeline 1) (one_for_one)
│   ├── Registry
│   ├── ProducerConsumer 1
│   └── Consumer 1
├── ConsumerSupervisor (Pipeline 2) (one_for_one)
│   ├── Registry
│   ├── ProducerConsumer 2
│   └── Consumer 2
└── ConsumerSupervisor (Pipeline 3) (one_for_one)
    ├── Registry
    ├── ProducerConsumer 3
    └── Consumer 3
```

If any component crashes, its supervisor restarts it independently.

## Configuration Points

### Number of Pipelines
Change in `application.ex`:
```elixir
# Add more for higher parallelism
{SqsPipeline.ConsumerSupervisor, name: :pipeline_4, pipeline_id: 4}
```

### Demand Levels
Adjust in each stage:
```elixir
# ProducerConsumer: How many events to request from Producer
subscribe_to: [{SqsPipeline.Producer, min_demand: 0, max_demand: 5}]

# Consumer: How many events to request from ProducerConsumer
subscribe_to: [{pc, min_demand: 0, max_demand: 20}]
```

### Poll Interval
Adjust in `producer.ex`:
```elixir
@poll_interval 5_000  # milliseconds
```

### Processing Logic
Customize in `consumer.ex`:
```elixir
defp process_file(content) do
  # Your custom logic here
end
```

## Performance Characteristics

- **Throughput**: Scales with number of pipelines
- **Latency**: Depends on S3 download time + processing time
- **Resource Usage**: Each pipeline uses minimal memory
- **Failure Recovery**: Automatic via supervision trees
- **Cost Efficiency**: Long polling reduces SQS requests

## Deployment Patterns

### Single Instance
```
[Producer] → [3 Pipelines]
```
Good for: Small to medium workloads

### Multiple Instances (Same Queue)
```
Instance 1: [Producer] → [3 Pipelines]
Instance 2: [Producer] → [3 Pipelines]
Instance 3: [Producer] → [3 Pipelines]
```
Good for: High throughput, automatic load distribution

### Fan-out (Multiple Queues)
```
S3 → SNS → [Queue 1] → Instance 1
         → [Queue 2] → Instance 2
         → [Queue 3] → Instance 3
```
Good for: Different processing per file type
