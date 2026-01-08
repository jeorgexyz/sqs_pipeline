defmodule SqsPipeline.Producer do
  @moduledoc """
  GenStage producer that polls SQS for new messages.
  When demand is received, it fetches messages from SQS and emits them downstream.
  """
  use GenStage
  require Logger

  @poll_interval 5_000
  @max_messages 10

  # Client API

  def start_link(_opts) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  # Server Callbacks

  @impl true
  def init(:ok) do
    Logger.info("SqsPipeline.Producer started")
    {:producer, %{queue: :queue.new(), demand: 0, timer: nil}}
  end

  @impl true
  def handle_demand(incoming_demand, state) do
    Logger.debug("Producer received demand: #{incoming_demand}")
    new_state = %{state | demand: state.demand + incoming_demand}
    
    # If we have pending demand and no timer, schedule a poll
    new_state = maybe_schedule_poll(new_state)
    
    # Try to dispatch any queued events
    dispatch_events(new_state, [])
  end

  @impl true
  def handle_info(:poll_sqs, state) do
    new_state = %{state | timer: nil}
    
    case fetch_messages() do
      {:ok, messages} when length(messages) > 0 ->
        Logger.info("Fetched #{length(messages)} messages from SQS")
        
        # Queue the messages
        new_queue = Enum.reduce(messages, state.queue, fn msg, queue ->
          :queue.in(msg, queue)
        end)
        
        new_state = %{new_state | queue: new_queue}
        dispatch_events(new_state, [])
        
      {:ok, []} ->
        Logger.debug("No messages in SQS")
        new_state = maybe_schedule_poll(new_state)
        {:noreply, [], new_state}
        
      {:error, reason} ->
        Logger.error("Error fetching from SQS: #{inspect(reason)}")
        new_state = maybe_schedule_poll(new_state)
        {:noreply, [], new_state}
    end
  end

  # Private Functions

  defp dispatch_events(%{demand: 0} = state, events) do
    {:noreply, Enum.reverse(events), state}
  end

  defp dispatch_events(%{queue: queue, demand: demand} = state, events) do
    case :queue.out(queue) do
      {{:value, message}, new_queue} ->
        new_state = %{state | queue: new_queue, demand: demand - 1}
        dispatch_events(new_state, [message | events])
        
      {:empty, _queue} ->
        new_state = maybe_schedule_poll(state)
        {:noreply, Enum.reverse(events), new_state}
    end
  end

  defp maybe_schedule_poll(%{demand: demand, timer: nil} = state) when demand > 0 do
    timer = Process.send_after(self(), :poll_sqs, @poll_interval)
    %{state | timer: timer}
  end

  defp maybe_schedule_poll(state), do: state

  defp fetch_messages do
    queue_url = get_queue_url()
    
    queue_url
    |> ExAws.SQS.receive_message(
      max_number_of_messages: @max_messages,
      wait_time_seconds: 10
    )
    |> ExAws.request()
    |> case do
      {:ok, %{body: %{messages: messages}}} ->
        parsed_messages = Enum.map(messages, &parse_message/1)
        {:ok, parsed_messages}
        
      {:ok, %{body: %{messages: nil}}} ->
        {:ok, []}
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_message(sqs_message) do
    # Parse S3 event notification from SQS message body
    case Jason.decode(sqs_message.body) do
      {:ok, %{"Records" => records}} ->
        # Extract S3 event details
        s3_event = List.first(records)
        
        %{
          receipt_handle: sqs_message.receipt_handle,
          bucket: get_in(s3_event, ["s3", "bucket", "name"]),
          key: get_in(s3_event, ["s3", "object", "key"]),
          size: get_in(s3_event, ["s3", "object", "size"]),
          event_time: get_in(s3_event, ["eventTime"])
        }
        
      _ ->
        # Fallback for non-S3 events
        %{
          receipt_handle: sqs_message.receipt_handle,
          body: sqs_message.body
        }
    end
  end

  defp get_queue_url do
    Application.get_env(:sqs_pipeline, :queue_url) ||
      System.get_env("SQS_QUEUE_URL") ||
      "https://sqs.us-east-1.amazonaws.com/123456789012/my-queue"
  end
end
