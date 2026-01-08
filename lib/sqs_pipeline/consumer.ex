defmodule SqsPipeline.Consumer do
  @moduledoc """
  GenStage consumer that:
  1. Receives file content from the producer_consumer
  2. Processes the file (counts lines in this example)
  3. Writes output to disk
  4. Deletes the message from SQS
  """
  use GenStage
  require Logger

  # Client API

  def start_link(opts) do
    pipeline_id = Keyword.fetch!(opts, :pipeline_id)
    GenStage.start_link(__MODULE__, pipeline_id, name: via_tuple(pipeline_id))
  end

  defp via_tuple(pipeline_id) do
    {:via, Registry, {SqsPipeline.Registry, {:consumer, pipeline_id}}}
  end

  # Server Callbacks

  @impl true
  def init(pipeline_id) do
    Logger.info("Consumer started for pipeline #{pipeline_id}")
    
    # Ensure output directory exists
    File.mkdir_p!("output")

    {:consumer, pipeline_id,
     subscribe_to: [
       {via_tuple_pc(pipeline_id), min_demand: 0, max_demand: 10}
     ]}
  end

  defp via_tuple_pc(pipeline_id) do
    {:via, Registry, {SqsPipeline.Registry, {:producer_consumer, pipeline_id}}}
  end

  @impl true
  def handle_events(events, _from, pipeline_id) do
    Logger.debug("Pipeline #{pipeline_id} Consumer processing #{length(events)} events")

    for event <- events do
      process_event(event, pipeline_id)
    end

    {:noreply, [], pipeline_id}
  end

  # Private Functions

  defp process_event(%{content: content, key: key} = event, pipeline_id) do
    try do
      # Process the file content
      result = process_file(content)
      
      # Write output
      write_output(result, key, pipeline_id)
      
      # Delete message from SQS
      delete_message(event.receipt_handle)
      
      Logger.info("Pipeline #{pipeline_id} successfully processed #{key}")
    rescue
      e ->
        Logger.error("Pipeline #{pipeline_id} failed to process #{key}: #{Exception.format(:error, e, __STACKTRACE__)}")
    end
  end

  defp process_event(%{body: body} = event, pipeline_id) do
    # Non-S3 event
    Logger.info("Pipeline #{pipeline_id} processing raw message")
    
    try do
      # Simple processing
      Logger.debug("Message body: #{body}")
      
      # Delete message from SQS
      delete_message(event.receipt_handle)
    rescue
      e ->
        Logger.error("Pipeline #{pipeline_id} failed to process message: #{Exception.format(:error, e, __STACKTRACE__)}")
    end
  end

  defp process_file(content) when is_binary(content) do
    # Count non-empty lines
    line_count =
      content
      |> String.split("\n")
      |> Enum.filter(&(&1 != ""))
      |> length()

    %{
      line_count: line_count,
      byte_size: byte_size(content),
      processed_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp write_output(result, key, pipeline_id) do
    # Extract filename from key
    filename =
      key
      |> String.split("/")
      |> List.last()
      |> String.replace(~r/\.(gz|txt|log)$/, "")

    output_file = "output/#{filename}_pipeline_#{pipeline_id}.json"

    # Write result as JSON
    json_output = Jason.encode!(result, pretty: true)
    
    File.write!(output_file, json_output <> "\n", [:append])
    
    Logger.debug("Wrote output to #{output_file}")
  end

  defp delete_message(receipt_handle) do
    queue_url = get_queue_url()

    case ExAws.SQS.delete_message(queue_url, receipt_handle) |> ExAws.request() do
      {:ok, _} ->
        Logger.debug("Deleted message from SQS")
        :ok

      {:error, reason} ->
        Logger.error("Failed to delete message from SQS: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_queue_url do
    Application.get_env(:sqs_pipeline, :queue_url) ||
      System.get_env("SQS_QUEUE_URL") ||
      "https://sqs.us-east-1.amazonaws.com/123456789012/my-queue"
  end
end
