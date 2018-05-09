defmodule Battleship.Game.Supervisor do
  @moduledoc false
  use DynamicSupervisor
  # Create a new game with:
  #     iex> Battleship.Game.Supervisor.start_child()

  def start_link do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_child do
    child = %{
      id: Battleship.Game,
      start: { Battleship.Game, :start_link, []}
    }
    DynamicSupervisor.start_child(__MODULE__, child)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
