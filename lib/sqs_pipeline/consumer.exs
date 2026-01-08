defmodule Gtube.Consumer do
  use GenStage

  #### Client API
  def start_link(_initial) do
    use GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  #### Server Callbacks
  def init(:ok) do
    upstream = Enum.join([name: __MODULE__, "ProducerConsumer"], "")
    {:consumer, :ok, subscribe_to: [GTUBE.ProducerConsumer, min_demand: 0, max_demand: 10]}
  end


  def handle_events(events, _from, state) do
    :timer.sleep(1000)

    for event <- events do
      IO.puts ({self(), event, state})

      SQS.Server.release(events)

    end

    # As a consumer we never emit events
    {:noreply, [], state}
  end
end
