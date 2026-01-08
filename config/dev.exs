import Config

# Development configuration
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# You can override the queue URL here for local testing
# config :sqs_pipeline,
#   queue_url: "http://localhost:4566/000000000000/test-queue"  # For LocalStack
