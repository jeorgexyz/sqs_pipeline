defmodule SqsPipeline.Application do
  @moduledoc """
  Main application supervisor for the SQS/S3 processing pipeline.
  Starts the producer and multiple consumer pipelines for parallel processing.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Single producer that polls SQS
      {SqsPipeline.Producer, []},
      
      # Multiple consumer pipelines for parallel processing
      {SqsPipeline.ConsumerSupervisor, name: :pipeline_1, pipeline_id: 1},
      {SqsPipeline.ConsumerSupervisor, name: :pipeline_2, pipeline_id: 2},
      {SqsPipeline.ConsumerSupervisor, name: :pipeline_3, pipeline_id: 3}
    ]

    opts = [strategy: :one_for_one, name: SqsPipeline.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
