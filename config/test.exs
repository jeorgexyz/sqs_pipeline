import Config

# Test configuration
config :logger, level: :warn

# Use LocalStack or mock for testing
config :ex_aws,
  access_key_id: "test",
  secret_access_key: "test",
  region: "us-east-1"

config :sqs_pipeline,
  queue_url: "http://localhost:4566/000000000000/test-queue"
