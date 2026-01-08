defmodule SqsPipeline.ProducerConsumer do
  @moduledoc """
  GenStage producer_consumer that:
  1. Receives S3 object metadata from the producer
  2. Downloads the file content from S3
  3. Decompresses if needed
  4. Passes the file content to consumers
  """
  use GenStage
  require Logger

  # Client API

  def start_link(opts) do
    pipeline_id = Keyword.fetch!(opts, :pipeline_id)
    GenStage.start_link(__MODULE__, pipeline_id, name: via_tuple(pipeline_id))
  end

  defp via_tuple(pipeline_id) do
    {:via, Registry, {SqsPipeline.Registry, {:producer_consumer, pipeline_id}}}
  end

  # Server Callbacks

  @impl true
  def init(pipeline_id) do
    Logger.info("ProducerConsumer started for pipeline #{pipeline_id}")
    
    {:producer_consumer, pipeline_id,
     subscribe_to: [
       {SqsPipeline.Producer, min_demand: 0, max_demand: 1}
     ]}
  end

  @impl true
  def handle_events(events, _from, pipeline_id) do
    Logger.debug("Pipeline #{pipeline_id} ProducerConsumer received #{length(events)} events")

    processed_events =
      events
      |> Enum.map(&download_and_process/1)
      |> Enum.filter(fn
        {:ok, _} -> true
        {:error, _} -> false
      end)
      |> Enum.map(fn {:ok, event} -> event end)

    {:noreply, processed_events, pipeline_id}
  end

  # Private Functions

  defp download_and_process(%{bucket: bucket, key: key} = event) when not is_nil(bucket) do
    Logger.info("Downloading s3://#{bucket}/#{key}")

    case ExAws.S3.get_object(bucket, key) |> ExAws.request() do
      {:ok, %{body: file_content}} ->
        # Decompress if gzipped
        file_content = maybe_decompress(file_content, key)
        
        Logger.debug("Downloaded #{byte_size(file_content)} bytes from #{key}")
        {:ok, Map.put(event, :content, file_content)}

      {:error, reason} ->
        Logger.error("Failed to download s3://#{bucket}/#{key}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp download_and_process(event) do
    # Non-S3 event, pass through
    {:ok, event}
  end

  defp maybe_decompress(content, key) do
    if String.ends_with?(key, ".gz") do
      try do
        :zlib.gunzip(content)
      rescue
        e ->
          Logger.warn("Failed to decompress #{key}: #{inspect(e)}, using raw content")
          content
      end
    else
      content
    end
  end
end
