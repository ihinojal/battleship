defmodule Battleship.BoardTest do
  use ExUnit.Case
  alias Battleship.Board
  #doctest Battleship, import: true

  @required_ships_sizes [2,3,3,4,5]
  @board_size {10,10}
  @incomplete_board [
    [{3,6},{3,7},{3,8}],
    [{6,10},{7,10},{8,10}],
    [{1,7},{1,8},{1,9},{1,10}],
    [{10,6},{10,7},{10,8},{10,9},{10,10}]
  ]
  @valid_board [ [{1,1},{1,2}] | @incomplete_board ]

  describe "creating a board" do
    test "is succesful on a valid board" do
      assert {:ok, _pid} = Board.start_link(@valid_board,
                            @board_size, @required_ships_sizes)
    end

    test "fails if not 5 ships are present" do
      assert {:error, :incorrect_ship_sizes, _msg} =
        Board.start_link(@incomplete_board,
                         @board_size, @required_ships_sizes)
    end

    @out_of_board [[{-1,3},{0,3}] | @incomplete_board]
    test "fails if ship out of board" do
      assert {:error, :out_of_board, _msg} =
        Board.start_link(@out_of_board, @board_size, @required_ships_sizes)
    end

    @crossing_ships [[{9,10},{10,10}] | @incomplete_board]
    test "fails if board with crossing ships" do
      assert {:error, :crossing_ship, _msg} =
        Board.start_link(@crossing_ships, @board_size, @required_ships_sizes)
    end

    @non_linear_ship [[{1,1},{2,2}] | @incomplete_board]
    test "fails if non linear ship" do
      assert {:error, :non_contiguos_ship, _msg} =
        Board.start_link(@non_linear_ship, @board_size, @required_ships_sizes)
    end
    @downward_ship [[{1,2},{1,1}] | @incomplete_board]
    test "its fine if ship is downward" do
      assert {:ok, _pid} =
        Board.start_link(@downward_ship, @board_size, @required_ships_sizes)
    end
    test "one unit cell is fine" do
      assert {:ok, _pid} =
        Board.start_link([[{1,1}]], @board_size, [1])
    end
  end

  describe "playing a game" do
    @cell_with_ships Enum.flat_map(@valid_board, &(&1))
    #@all_cells (for x <- 1..10, y <- 1..10, do: {x,y})
    #@cell_with_water @all_cells -- @cell_with_ships
    test "works" do
      {:ok, board} = Board.start_link(@valid_board,
                                      @board_size, @required_ships_sizes)
      {:ok, :water} = Board.fire(board, {3,9})
      {:error, :invalid_coordinate} = Board.fire(board, {0,0})
      {:error, :invalid_coordinate} = Board.fire(board, {1,0})
      {:error, :already_fired} = Board.fire(board, {3,9})
      {:ok, :hit} = Board.fire(board, {3,8})
      {:ok, :hit} = Board.fire(board, {3,7})
      {:ok, :ship_down} = Board.fire(board, {3,6})
      @cell_with_ships -- [{3,8},{3,7},{3,6},{10,10}]
      |> Enum.each(fn(ship_cell)->
        {:ok, result} = Board.fire(board, ship_cell)
        assert result in [:ship_down, :hit]
      end)
      # Last ship cell will return `:lose`
      assert {:ok, :lose} == Board.fire(board, {10,10})
    end
  end


end
