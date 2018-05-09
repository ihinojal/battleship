defmodule Battleship.Board do
  @moduledoc false

  use GenServer
  alias __MODULE__
  alias Battleship.Board.BoardValidator

  @typedoc """
  A struct which stores the coordinates of the board (as pids) in a grid, and a
  list of all the ships.

  #### Example:

      %Board{
        coordinates: %{{0,1} => PID#coord<0.1>, {0,2} => PID#coord<0.2> },
        ships: [PID#ship<1.1>],
        board_size: {10,10},
        required_ship_sizes: [2,3,3,4,5]
      }
  """
  @type board_struct_t ::
    %Board{coordinates: %{coordinate_t => reference | :fired},
      ships: %{ reference => integer},
      board_size: coordinate_t,
      required_ship_sizes: [integer]
    }
  defstruct \
    coordinates: %{},
    ships: %{},
    board_size: {10,10},
    required_ship_sizes: []

  @typedoc """
  A coordinate of a board
  """
  @type coordinate_t :: {integer, integer}

  @typedoc """
  Defines a ship with a list of coordinates where this ship is located.
  """
  @type ship_def_t :: [coordinate_t]

  @doc """
  Start a pid which tracks the boards, the ships, and their cells.

  Argument `ship_defs` is a list of ships
      iex> {:ok, _board_pid} = start_link([
          [{0,1},{0,2}], # First ship length 2
          [{3,6},{3,7},{3,8}], # Second ship length 3
          [{6,9},{7,9},{8,9}],
          [{1,6},{1,7},{1,8},{1,9}],
          [{9,6},{9,7},{9,8},{9,9},{9,9}]
        ]
  """
  @spec start_link([ship_def_t], {integer, integer}, [integer]) ::
    {:ok, pid} | {:error, atom, binary}
  # Base call where a blanket board is created spawning a bunch of
  # Coordinates
  def start_link(ship_defs, board_size, required_ship_sizes ) do
    _start_link(ship_defs,
      %Board{board_size: board_size, required_ship_sizes: required_ship_sizes})
  end
  # Process a ship
  @spec _start_link([ship_def_t], board_struct_t ) ::
    {:ok, pid} | {:error, atom, binary}
  defp _start_link([ship_def|others], board_struct) do
    # Spawn a ship proccess, update coordinate_pid with it, and add it
    # to the board
    with \
      {:ok, {board_struct, ship_def}} <-
        BoardValidator.validate_ship(board_struct, ship_def),
      {:ok, board_struct} <- add_to_board(board_struct, ship_def)
    do
      _start_link(others, board_struct)
    else
      other -> other
    end
  end
  # No more ships to proccess. Just store the current board using an
  # Agent.
  defp _start_link([], board_struct = %Board{}) do
    # Checks if there are present all required ship with its length
    BoardValidator.validate_board(board_struct)
    |>case do
      :ok -> GenServer.start_link(__MODULE__, board_struct)
      error -> error
    end
  end

  @doc """
  Fire in a cell. Depending if there is a part of a ship on that cell
  the result varies:
   - `hit` if there is a ship
   - `ship_down` if there is a ship and it was taken down in this fire
   - `all_ships_down` if ALL the ships were taken down. The last ship
      was taken down in this fire.

      iex> fire(board_pid, {1,2})
      {:ok, :hit}

  Can return:
  - {:ok, :hit}
  - {:ok, :ship_down}
  - {:ok, :lose}
  - {:ok, :water}
  - {:error, :already_fired}
  - {:error, :invalid_coordinate}
  """
  @spec fire(pid, coordinate_t) ::
    {:ok, :hit} | {:ok, :ship_down} | {:ok, :lose} | {:ok, :water} |
    {:error, :already_fired} | {:error, :invalid_coordinate}
  def fire(board_pid, {_x,_y}=cell) do
    GenServer.call(board_pid, {:fire, cell})
  end

  defp add_to_board(board, ship_struct) do
    ship_ref = make_ref()
    # Store the num of cells of this ship. E.g.: %Board{ships: %{#Ref.0123 => 3}}
    board = put_in(board, [Access.key(:ships), ship_ref], length(ship_struct))
    # Set each cell of the board to know there is part of a ship there
    # E.g.: %Board{coordinates: %{{0,0} => #Ref.0123, {0,1} => #Ref.0123}}
    board = ship_struct
            |>Enum.reduce(board, fn({x,y}, board)->
                put_in(board, [Access.key(:coordinates), {x,y}], ship_ref)
              end)
    {:ok, board}
  end

  #CALLBACKS
  def init(board) do
    {:ok, board}
  end

  def handle_call({:fire, {x,y}}, _from, %Board{
    coordinates: coordinates, ships: ships, board_size: {max_x, max_y}} = board) do
    # Find if there is a ship in that coordinate
    ship_id = coordinates[{x,y}] # 
    cond do
      # Check if fired coordinate is not out of board
      not(x in 1..max_x and y in 1..max_y) ->
        {:reply, {:error, :invalid_coordinate}, board}
      # Check coordinate wasn't fired before
      coordinates[{x,y}] == :fired ->
        {:reply, {:error, :already_fired}, board}
      # If there is only a ship left alive of length 1 and its just hit
      map_size(ships) == 1 and ships[ship_id] == 1 ->
        board = %Board{ board |
          coordinates: Map.put(coordinates, {x,y}, :fired), ships: %{}}
        {:reply, {:ok, :lose}, board}
      # There are more ships, but this one has just sinked
      ships[ship_id] == 1 ->
        #Assign this coordinate to :fired and remove this ship from ships
        board = %Board{ board |
          coordinates: Map.put(coordinates, {x,y}, :fired),
          ships: Map.delete(ships, ship_id)
        }
        {:reply, {:ok, :ship_down}, board}
      # This ship have more than one coords still up
      is_reference(ship_id) ->
        # Assign this coordinate to :fired and reduce length of this ship
        board = %Board{ board |
          coordinates: Map.put(coordinates, {x,y}, :fired),
          ships: Map.update(ships, ship_id, 0,&(&1-1))
        }
        {:reply, {:ok, :hit}, board}
      # There is no ship in this coordinate, count as fired
      (nil == coordinates[{x,y}]) ->
        # Assign this coordinate to :fired
        board = %Board{board|coordinates: Map.put(coordinates, {x,y}, :fired)}
        {:reply, {:ok, :water}, board}
    end
  end

end
