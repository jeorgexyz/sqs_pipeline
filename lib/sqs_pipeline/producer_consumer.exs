defmodule Gtube.ProducerConsumber do
  use GenStage

  require Integer

  def start_link(__initial) do
    GenStage.start_link(__MODULE__, : state_doesnt_matter, name: __MODULE__)

  end

  def handle_events(events, _from, state) do
    numbers =
    events
    |>Enum.filter(&Integer.is_even/1)

    {:noreply, numbers, state}
  end
end
