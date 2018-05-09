defmodule BattleshipTest do
  use ExUnit.Case

  @board_size {5,5}
  @required_ship_sizes [1,2]
  @p1_ship_def [ [{4,5},{5,5}], [{2,2}] ]
  @p2_ship_def [ [{1,1},{1,2}], [{3,3}] ]

  test "Ensure that a complete game can be played" do
    current_pid = self()
    {:ok, game_pid} = Battleship.add_player(@p1_ship_def,
            player_id: :p1,
            player_pid: current_pid,
            board_size: @board_size,
            required_ship_sizes: @required_ship_sizes)
    assert_receive({:wait_other_player, %{pid_receiver: ^current_pid, id_receiver: :p1}})
    {:ok, ^game_pid} = Battleship.add_player(@p2_ship_def,
            player_id: :p2,
            player_pid: current_pid,
            board_size: @board_size,
            required_ship_sizes: @required_ship_sizes)
    assert_receive({:joined_game, %{game_pid: ^game_pid, player_id: :p1}})
    assert_receive({:joined_game, %{game_pid: ^game_pid, player_id: :p2}})
    assert_receive({:your_turn, %{id_receiver: :p1, pid_receiver: ^current_pid}})
    assert_receive({:wait_other_player, %{id_receiver: :p2, pid_receiver: ^current_pid}})
    # If player 2 attack when is not his turn
    Battleship.fire(game_pid, {4,5}, :p2)
    assert_receive({:error, :not_your_turn})
    # Player 1 attack on his turn
    Battleship.fire(game_pid, {4,4}, :p1)
    assert_receive({:fire_result, :water, {4,4}})
    assert_receive({:wait_other_player, %{id_receiver: :p1, pid_receiver: ^current_pid}})
    assert_receive({:your_turn, %{id_receiver: :p2, pid_receiver: ^current_pid}})
    # Player 2 turn
    Battleship.fire(game_pid, {4,5}, :p2)
    assert_receive({:fire_result, :hit, {4,5}})
    assert_receive({:wait_other_player, %{id_receiver: :p2, pid_receiver: ^current_pid}})
    assert_receive({:your_turn, %{id_receiver: :p1, pid_receiver: ^current_pid}})
    # Player 2 turn
    Battleship.fire(game_pid, {4,4}, :p1)
    assert_receive({:error, :already_fired, {4,4}})
    Battleship.fire(game_pid, {1,1}, :p1)
    Battleship.fire(game_pid, {5,5}, :p2)
    assert_receive({:fire_result, :ship_down, {5,5}})
    Battleship.fire(game_pid, {3,3}, :p1)
    # Player 2 wins
    Battleship.fire(game_pid, {2,2}, :p2)
    assert_receive({:fire_result, :ship_down, {2,2}})
    assert_receive({:received_fire, :ship_down, {2,2}})
    assert_receive({:game_terminated, :win})
    assert_receive({:game_terminated, :lose})
  end

end
