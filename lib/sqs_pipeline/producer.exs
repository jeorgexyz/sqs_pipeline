defmodule Gtube.Producer do
  use GenStage

  def start_link(initial \\ 0) do
    GenStage.start_link(__MODULE__, initial, name: __MODULE__)
  end

  def init(0), do: {:producer, 0}

  def handle_demand(demand, state) when demand > 0 do
    events = Enum.to_list(state..(state + demand - 1))
    {:noreply, events, state + demand}
  end

  defp take(demand) do

    {count, events} = SQL.Server.pull(demand)
  end

end
