defmodule Battleship.GameDispatcherTest do
  use ExUnit.Case
  alias Battleship.GameDispatcher

  setup do
    # Before each group of testing ensure the GameDispatcher has no users
    # waiting for an opponent
    GameDispatcher.drop_waiting_users()
  end

  test "game dispatcher is always up" do
    assert is_pid(Process.whereis(GameDispatcher))
  end

  test "When adding two players they are joined together in a game" do
    # Add player1 and then player2
    {:ok, gameA_p1_pid} = GameDispatcher.add_player([[{1,1}]],
      board_size: {5,5}, required_ship_sizes: [1], player_id: :p1)
    {:ok, gameA_p2_pid} = GameDispatcher.add_player([[{5,5}]],
      board_size: {5,5}, required_ship_sizes: [1], player_id: :p2)
    # The game_pid of both players are the same
    assert gameA_p1_pid == gameA_p2_pid
    {:ok, gameB_p1_pid} = GameDispatcher.add_player([[{1,1}]],
      board_size: {5,5}, required_ship_sizes: [1], player_id: :p1)
    {:ok, gameB_p2_pid} = GameDispatcher.add_player([[{5,5}]],
      board_size: {5,5}, required_ship_sizes: [1], player_id: :p2)
    # The game_pid of both players are the same
    assert gameB_p1_pid == gameB_p2_pid
    assert gameA_p1_pid != gameB_p2_pid
  end

  test "If I add two players with the same ID to the same game it fails" do
    # Add player1 and then player2 with the same ID
    GameDispatcher.add_player([[{1,1}]],
      board_size: {5,5}, required_ship_sizes: [1], player_id: :player)
    assert {:error, :player_id_already_taken, _msg} =
      GameDispatcher.add_player([[{5,5}]],
        board_size: {5,5}, required_ship_sizes: [1], player_id: :player)
  end

end
