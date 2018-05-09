defmodule Battleship.Game do
  @moduledoc false
  use GenServer
  alias Battleship.Board
  alias __MODULE__

  @typedoc """
  Stores a gameplay and links to both player's boards. The current player turn
  is indicated pointing to its player id.

  #### Example:

      %Game{
        players: [
          player1: %{player_pid: pid<0.1>, board_pid: PID<0.10>},
          player2: %{player_pid: pid<0.2>, board_pid: PID<0.20>}
        ],
        turn: :player1}
  """
  @type game_struct_t :: %Game{
    players: [{any, %{player_pid: pid, board_pid: pid}}],
    turn: any}
  defstruct players: [], turn: nil

  @doc """
  Start a game PID which will manage the gameplay of battleship with two
  players.

  #### Example:

      iex> start_link()
      {:ok, #PID<0.1.2>}
  """
  def start_link do
    GenServer.start_link(__MODULE__, :ok)
  end

  @doc """
  To begin a game the gameplay must have two players. This function adds one
  player.

  Can pass board requirements as the size of the board in width and height
  (`{width, height}`), and the required number of ships incl their sizes.

      iex> add_player(game_pid, [{1,2},{3,4}],
                      board_size: {5,5},
                      required_ship_sizes: [2])
      :ok

  Returns:

    - If needs one more player `:ok`
    - If game has two players `:game_started`
  """
  @default_options [
    player_id: self(), player_pid: self(),
    board_size: {10,10}, required_ship_sizes: [2,3,3,4,5] ]
  def add_player(game_pid, ship_def, options \\ []) do
    options = Keyword.merge(@default_options, options)
    _add_player(game_pid, ship_def,
      options[:player_id], options[:player_pid],
      options[:board_size], options[:required_ship_sizes])
  end
  defp _add_player(game_pid, [[_|_]|_] = ship_def, player_id, player_pid,
          {_x,_y} = board_size, [ship_size|_] = required_ship_sizes) when
          is_pid(game_pid) and is_pid(player_pid) and is_integer(ship_size)
  do
    GenServer.call(game_pid, {:add_player, ship_def,
      player_id, player_pid, board_size, required_ship_sizes})
  end
  defp _add_player(_game_pid, _ship_def, _player_id, _player_pid, _board_size,
                   _required_ship_sizes) do
    raise ArgumentError, message: "Invalid argument adding a player in your function call"
  end

  #@doc """
  #If game has only one player just remove it from the context. If game has
  #two players the game was already started, so just send a :game_terminated
  #event
  #"""
  #def drop_player(game_pid, player_id) do
  #  GenServer.cast(game_pid, {:drop_player, player_id})
  #end

  @doc """
  Asyncronous (will receive) call to fire into the opponent board.
  """
  def fire(game_pid, {_x,_y} = position, player_id \\ self()) when is_pid(game_pid) do
    GenServer.cast(game_pid, {:fire, position, player_id})
  end

  #CALLBACKS
  # A game hasn't started as long as there is no player turn defined, which is
  # the fisrt thing done after start a game with two players.
  defguard game_started(turn) when not is_nil(turn)
  defguard is_player_turn(player_id, turn) when player_id === turn

  def init(:ok) do
    # When a linked user drops, manage wheter to drop the gameplay or not
    #Process.flag(:trap_exit, true)
    {:ok, %Game{}}
  end

  def handle_call({:add_player,
    ship_def, player_id, player_pid,
    board_size, required_ships_sizes},
    _from, game_ctx) do
    with \
      :ok <- check_player_id_not_taken(game_ctx, player_id),
      {:ok, board_pid} <- Board.start_link(ship_def, board_size, required_ships_sizes),
      player_def <- %{player_pid: player_pid, board_pid: board_pid},
      game_ctx <- Map.update!(game_ctx, :players, &([{player_id, player_def}| &1])),
      num_players <- length(game_ctx.players)
      # Link to player_pid so if player PID drops we can manage what to do with
      # the current gameplay
      #true <- Process.link(player_pid)
    do
      case num_players do
        1 ->
          # Still need one more player
          player_pid
          |>send({:wait_other_player, %{id_receiver: player_id, pid_receiver: player_pid}})
          {:reply, :ok, game_ctx}
        2 ->
          # Start the game
          [{p2_id, %{player_pid: p2_pid}}, {p1_id, %{player_pid: p1_pid}}] = game_ctx.players
          send(p1_pid, {:joined_game, %{game_pid: self(), player_id: p1_id}})
          send(p1_pid, {:your_turn, %{id_receiver: p1_id, pid_receiver: p1_pid}})
          send(p2_pid, {:joined_game, %{game_pid: self(), player_id: p2_id}})
          send(p2_pid, {:wait_other_player, %{id_receiver: p2_id, pid_receiver: p2_pid}})
          {:reply, :game_started, Map.put(game_ctx, :turn, p1_id)}
      end
    else
      other -> {:reply, other, game_ctx}
    end
  end

  # Ensures that in the current game, the other player doens't have the same ID
  defp check_player_id_not_taken(game_ctx, player_id) do
    game_ctx
    |>player_info(player_id)
    |>case do
        nil -> :ok
        %{player_pid: player_pid} ->
          {:error, :player_id_already_taken,
            "The player_id #{player_id} was already taken"<>
            " by the player with PID #{inspect(player_pid)}"}
      end
  end
  defp player_info(game_ctx, player_id) do
    game_ctx.players
    |>List.keyfind(player_id, 0)
    |>case do
        {_player_id, player_info} -> player_info
        nil -> nil
      end
  end

  #def handle_info({:EXIT, player_pid, :normal}, %{turn: nil} = game_ctx) do
  #  # Game hasn't started yet, so it's safe to remove this user.
  #  IO.puts "Manage user drops before game started #{inspect player_pid}"
  #  {:noreply, game_ctx}
  #end
  #def handle_info({:EXIT, _from, :normal}, %{turn: player_id} = game_ctx) when not is_nil(player_id) do
  #  # Game has started, drop the game and the other players
  #  Process.exit(self(), :normal)
  #  {:noreply, game_ctx}
  #end
  #def handle_cast({:drop_player, player_id}, %{turn: turn} = game_ctx)
  #  when game_started(turn) do
  #  {:noreply, Keyword.delete(game_ctx, player_id)}
  #end
  ## The game has alredy started. It doesn't make sense to keep this game on.
  ## This will finish this process, the boards, and all their related process.
  #def handle_cast({:drop_player, _player_id}, %{turn: turn} = game_ctx)
  #  when not game_started(turn) do
  #  {:stop, :normal, game_ctx}
  #end

  def handle_cast({:fire, _position, player_id}, %{turn: turn} = game_ctx)
    when not is_player_turn(player_id, turn) do
    player_pid(game_ctx, player_id)
    |>send({:error, :not_your_turn})
    {:noreply, game_ctx}
  end
  def handle_cast({:fire, position, player_id}, %{turn: turn} = game_ctx)
    when is_player_turn(player_id, turn) do
    player_pid = player_pid(game_ctx, player_id)
    opponent_id = opponent_id(game_ctx, player_id)
    opponent_pid = opponent_pid(game_ctx, player_id)
    game_ctx.players[opponent_id]
    |>Map.get(:board_pid)
    |>Board.fire(position)
    |>case do
        {:ok, :lose } ->
          # Send attacker the result of his fire
          send(player_pid, {:fire_result, :ship_down, position})
          send(player_pid, {:game_terminated, :win})
          # Send opponent the damage
          send(opponent_pid, {:received_fire, :ship_down, position})
          send(opponent_pid, {:game_terminated, :lose})
          {:noreply, game_ctx}
        {:ok, status} ->
          # Send attacker the result of his fire
          send(player_pid, {:fire_result, status, position})
          send(player_pid, {:wait_other_player, %{id_receiver: player_id, pid_receiver: player_pid}})
          # Send opponent the damage
          send(opponent_pid, {:received_fire, status, position})
          send(opponent_pid, {:your_turn, %{id_receiver: opponent_id, pid_receiver: opponent_pid}})
          {:noreply, Map.put(game_ctx, :turn, opponent_id(game_ctx, player_id))}
        {:error, reason} ->
          # Example: {:error, :already_fired}
          send(player_pid, {:error, reason, position})
          {:noreply, game_ctx}
      end
  end
  defp player_pid(game_ctx, player_id) do
    game_ctx.players[player_id][:player_pid]
  end
  # Returns the id of the opponent of `player_id`
  defp opponent_id(game_ctx, player_id) do
    game_ctx.players
    |>Keyword.keys()
    |>List.delete(player_id)
    |>List.first()
  end
  # Returns the PID of the opponent of `player_id`
  defp opponent_pid(game_ctx, player_id) do
    game_ctx.players[opponent_id(game_ctx, player_id)][:player_pid]
  end

end
