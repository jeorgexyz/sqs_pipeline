defmodule SqsPipeline.ConsumerSupervisor do
  @moduledoc """
  Supervisor that manages a ProducerConsumer and Consumer pair for each pipeline.
  This allows multiple parallel processing pipelines.
  """
  use Supervisor

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    pipeline_id = Keyword.fetch!(opts, :pipeline_id)

    children = [
      # Registry for this pipeline's stages
      {Registry, keys: :unique, name: SqsPipeline.Registry},
      
      # ProducerConsumer downloads S3 files
      {SqsPipeline.ProducerConsumer, pipeline_id: pipeline_id},
      
      # Consumer processes files
      {SqsPipeline.Consumer, pipeline_id: pipeline_id}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
