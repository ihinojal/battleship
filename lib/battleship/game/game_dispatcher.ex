defmodule Battleship.GameDispatcher do
  @moduledoc false
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Add a player to the next game. As soon as there is two player to play a game
  the game will be started.

  To know more about how this should be called read `Battleship.add_player/2`
  """
  def add_player([[_|_]|_] = ship_def, options \\ []) do
    GenServer.call(__MODULE__, {:add_player, ship_def, options})
  end

  @doc """
  Drop all users waiting for an opponent.
  """
  def drop_waiting_users do
    GenServer.call(__MODULE__, :drop_waiting_users)
  end

  # Callbacks
  @impl true
  def init(:ok) do
    {:ok, nil}
  end

  @impl true
  def handle_call(:drop_waiting_users, _from, nil) do
    {:reply, :ok, nil}
  end
  def handle_call(:drop_waiting_users, _from, game_pid) when is_pid(game_pid) do
    # kill the game and their boards
    Process.exit(game_pid, :kill)
    {:reply, :ok, nil}
  end

  @impl true
  def handle_call({:add_player, ship_def, options}, from, nil) do
    # Create a new game
    {:ok, game_pid} = Battleship.Game.Supervisor.start_child()
    # Try to add the player with the game_pid just created
    handle_call({:add_player, ship_def, options}, from, game_pid)
  end
  @impl true
  def handle_call({:add_player, ship_def, options}, _from, game_pid) when is_pid(game_pid) do
    Battleship.Game.add_player(game_pid, ship_def, options)
    |>case do
        :ok -> {:reply, {:ok, game_pid}, game_pid}
        :game_started -> {:reply, {:ok, game_pid}, nil}
        error -> {:reply, error, game_pid}
      end
  end


end
