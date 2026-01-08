import Config

# Runtime configuration (runs when application starts)
if config_env() == :prod do
  config :sqs_pipeline,
    queue_url: System.get_env("SQS_QUEUE_URL") || 
      raise """
      environment variable SQS_QUEUE_URL is missing.
      For example: https://sqs.us-east-1.amazonaws.com/123456789012/my-queue
      """
end
