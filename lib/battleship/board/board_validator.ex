defmodule Battleship.Board.BoardValidator do
  @moduledoc false

  @doc """
  Validate one ship in the current board. It checks:
    - The length of the ship is correct
    - The ship is placed inside the board
    - Is not crossing other ships
    - The cells of this ships are placed in a straight line 

  If the ship looks right, then return :ok. Otherwise return the error:

      iex> validate_ship(%Battleship.Board{}, [{1,1}, {1,2}])
      :ok

      iex> validate_ship(%Battleship.Board{}, [{1,1}, {1,2}])
      {:error, :incorrect_size, "The ship should be at least 2 units"}

  Available errors are:

    - `{:error, :incorrect_ship_sizes, "Expected to have the following ship
        lengths [2,3,3,4,5] but there were [2,3] instead"}
    - `{:error, :incorrect_size, "The ship should be at least 2 units"}`
    - `{:error, :out_of_board, "cell {11,2} is out of the board"}`
    - `{:error, :crossing_ship, "cell {1,1} has two ships crossing"}`
    - `{:error, :non_contiguos_ship, "Ship defined as [{1,1},{2,2}] is not
        contiguos"}`
  """
  def validate_ship(%{board_size: board_size, required_ship_sizes: required_ship_sizes} = board, ship_def) do
    with \
      :ok <- check_ship_length(ship_def, Enum.min_max(required_ship_sizes)),
      # Checks if any ship cells are placed out of the board
      :ok <- check_ship_out_of_board(ship_def, board_size),
      # Check no ships is crossing one to another
      :ok <- check_crossing(board, ship_def),
      # The cell of this ship are in a line
      :ok <- contiguos_ship(ship_def) do
      # If no errors, add this ship to the board and keep processing other
      # ships until all are done or an error is found
      {:ok, {board, ship_def}}
    else
      other -> other
    end
  end

  @doc """
  Validate the board once all ships are placed.

  Returns :ok or {:error, reason, "msg" }
  """
  def validate_board(%{required_ship_sizes: required_ship_sizes}=board) do
    if board_ships_sizes(board) == required_ship_sizes do
      :ok
    else
      {:error, :incorrect_ship_sizes,
        "Expected to have the following ship lengths"<>
        "#{inspect(required_ship_sizes)} but there were"<>
        "#{inspect(board_ships_sizes(board)) } instead"}
    end
  end

  defp check_ship_length(ship, {min_ship_size,_max_ship_size}) when length(ship) < min_ship_size do
    {:error, :incorrect_size, "The ship should be at least #{min_ship_size} units"}
  end
  defp check_ship_length(ship, {_min_ship_size,max_ship_size}) when length(ship) > max_ship_size do
    {:error, :incorrect_size, "The ship should be at most #{max_ship_size} units"}
  end
  defp check_ship_length(_ship, _size_range), do: :ok

  # Check if the ship is placed out of the board
  defp check_ship_out_of_board(ship_def, {board_cols, board_rows}) do
    # Traverse all coordinates of this ship in the board, if coordinates
    # exists in the board they must be a pid
    ship_def
    |>Enum.find(fn({x,y})-> not(x in 0..board_cols and y in 0..board_rows) end)
    |>case do
      nil -> :ok
      coord -> {:error, :out_of_board, "cell #{inspect(coord)} is out of the board"}
    end
  end

  # Check if ship have a common cell where it is crossing another
  # previous ship.
  defp check_crossing(%{coordinates: coordinates}, ship_def) do
    # Find if a cell already has a defined ship inside
    ship_def
    |>Enum.find(fn(coord)-> coordinates[coord] end)
    |>case do
      nil -> :ok
      coord -> {:error, :crossing_ship, "cell #{inspect(coord)} has two ships crossing"}
    end
  end

  # Check if the cells of a ship are contiguos one to another in a line.
  # That is that cells are not scattered across the board.
  defp contiguos_ship(ship) do
    if contiguos_cells?(ship) do
      :ok
    else
      {:error, :non_contiguos_ship, "Ship defined as #{inspect(ship)} is not contiguos"}
    end
  end

  # Check if a list of cells are contiguos cells in the board
  # iex> contiguos_cells?([{0,1},{0,2},{0,3}]) #=> true
  # # The ship has a blank cell
  # iex> contiguos_cells?([{1,1},{1,2},{1,4}]) #=> false
  # # The cell are the same
  # iex> contiguos_cells?([{1,2},{1,2}]) #=> false
  defp contiguos_cells?([{_x,_y}|[]]), do: true
  defp contiguos_cells?([{x,y1},{x,y2}|rest]) do
    contiguos_cells?([{x,y1},{x,y2}|rest], :horizontal)
  end
  defp contiguos_cells?([{x1,y},{x2,y}|rest]) do
    contiguos_cells?([{x1,y},{x2,y}|rest], :vertical)
  end
  defp contiguos_cells?(_ship_cells), do: false
  defp contiguos_cells?([_|[]],_orientation), do: true
  defp contiguos_cells?([{x,y1},{x,y2}|rest], :horizontal) when y2-y1 in [-1,1] do
    contiguos_cells?([{x,y2}|rest], :horizontal)
  end
  defp contiguos_cells?([{x1,y},{x2,y}|rest], :vertical) when x2-x1 in [-1,1] do
    contiguos_cells?([{x2,y}|rest], :vertical)
  end
  defp contiguos_cells?(_ship_cells, _orientation), do: false

  # What are the sizes of each ship of the board
  # iex> board_ships_sizes(board_struct) #=> [2,3,3,4,5]
  defp board_ships_sizes(board_struct) do
    board_struct.ships
    |>Map.values()
    |>Enum.sort()
  end

end
