import Config

# Configure AWS
config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role],
  region: {:system, "AWS_REGION"}

# Configure the SQS queue URL
config :sqs_pipeline,
  queue_url: System.get_env("SQS_QUEUE_URL")

# Import environment specific config
import_config "#{config_env()}.exs"
