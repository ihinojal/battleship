defmodule Battleship do
  @moduledoc """
  This library is a multiplayer game of the classic
  [battleship](https://en.wikipedia.org/wiki/Battleship_(game)) board or paper
  game.

  It's meant to be used within a website or similar because is mostly
  asyncronous, passing messages between the players processes.

  To be played you need to add two players together in the same game, and then
  each one fire the opponent. To manage the turns users will have to wait to
  receive a message with a notification that is their turn.

  To get a sample of how it works take a look a sample game in file
  `test/battleship_test.exs`.


  """
  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Returns a game_pid that can be new (the new player is the first one) or an
  previoulsy created game pid (a user was there waiting for a opponent).

  #### Call response
  If the call was succesful will return `{:ok, game_pid}`.

  If there was an error, return value can be:

    - `{:error, :player_id_already_taken, "The player_id (...) was already taken by the player with PID (...)"}`
    - `{:error, :incorrect_ship_sizes, "Expected to have the following ship lengths (...) but there were (...) instead"}`
    - Any other about each of the passed ship configuration. Described in
      `Battleship.Board.BoardValidator.validate_ship/2`

  #### Asyncronous messages

  This function can generate the following messages that will be passed to the
  player processes:

    - `{:wait_other_player, %{id_receiver: player_id, pid_receiver: player_pid}})` -
      Sent when the user have to wait for an opponent. Also is generated after
      a succesful fire to the opponent.
    - `{:joined_game, %{game_pid: self(), player_id: p2_id}})` -
      Both users are ready to begin the game. One will receive a `:your_turn`
      message and the other a `:wait_other_player`
    - `{:your_turn, %{id_receiver: p1_id, pid_receiver: p1_pid}})` -
      The user can fire to the opponent.

  #### Options

    - `player_pid` - Is a PID where all the messages are returned when a fire
        is made by an user in the opponent board. By default is the calling
        process PID (`self()`).
    - `player_id` - When after a player was added, you'll want to fire in the
        opponent board with something like `Battleship.fire(game_pid, {1,2},
        :player_1)`. The third parameter `:player_1` is any data so the game know if
        the player which is firind is player_1 or player 2. By default the player_id
        will be the current process pid of the caller (self()), asuming the function
        `Battleship.fire/2` is made inside the player process which is different from
        the opponent player.
    - `board_size` - A tuple with the number of cells of the board. By default
        will be `{10,10}`. So there will be a grid from `1` to `10`
    - `required_ship_sizes` - When adding ships, the required number of ships
        and their lenghts can be stated. E.g.: [1,2,3] means three ships are required

  #### Examples
      iex> Battleship.add_player([[{1,1}]], board_size: {5,5}, required_ship_sizes: [1], player_id: :p1)
      {:ok, #PID<1.2.3>}
      iex> Battleship.add_player([[{5,5}]], board_size: {5,5}, required_ship_sizes: [1], player_id: :p2)
      {:ok, #PID<1.2.3>}
      iex> # Now we have a paired game. If we add another player we will have
      iex> # an unpaired game, as the user has to wait to a opponent.
      iex> Battleship.add_player([[{5,5}]], board_size: {5,5}, required_ship_sizes: [1], player_id: :p2)
      {:ok, #PID<4.5.6>}

  """
  defdelegate add_player(ship_def, options \\ []),
    to: Battleship.GameDispatcher

  @doc """
  Fire in opponent board.

  #### Asyncronous messages
  The function call is asyncronous, so a message with the result will be send
  to the process pid indicated in the options `player_pid` when the player was
  added with `add_player/2`, which by default is the calling process `self()`.

  The messages that can be received are many depending of the situation of the
  gameplay:

    - `{:fire_result, :ship_down, position})`
    - `{:fire_result, :hit, position})`
    - `{:fire_result, :water, position})`
    - `{:received_fire, :ship_down, position})`
    - `{:received_fire, :hit, position})`
    - `{:received_fire, :water, position})`
    - `{:game_terminated, :win})`
    - `{:game_terminated, :lose})`
    - `{:wait_other_player, %{id_receiver: player_id, pid_receiver: player_pid}})`
    - `{:your_turn, %{id_receiver: opponent_id, pid_receiver: opponent_pid}})`
    - `{:error, :already_fired}`

  Where:

    - `position`. Is a `{x,y}` coordinate.
    - `player_id`. Is usually the PID of the player, but can by an atom or any
      object.
  """
  defdelegate fire(game_pid, position, player_id),
    to: Battleship.Game

  # Callbacks
  @doc false
  def init(:ok) do
    # Start one process called `GameDispatcher` which will pair players in a
    # game, and a `Game.Supervisor` that will be a factory of new games.
    children = [
      %{
        id: Battleship.Game.Supervisor,
        start: { Battleship.Game.Supervisor, :start_link, []}
      },
      %{
        id: Battleship.GameDispatcher,
        start: { Battleship.GameDispatcher, :start_link, []}
      }
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end

end
