defmodule Battleship.GameTest do
  use ExUnit.Case
  alias Battleship.Game

  @board_size {5,5}
  @required_ship_sizes [1,2]
  @p1_ship_def [ [{4,5},{5,5}], [{2,2}] ]
  @p2_ship_def [ [{1,1},{1,2}], [{3,3}] ]
  @incomplete_ship_def [[{1,1}]] # I need to ships!


  setup do
    {:ok, game_pid} = Game.start_link()
    %{game_pid: game_pid}
  end

  describe "Adding a player with a invalid call fails directly" do
    test "with a game_pid which is not a pid" do
      assert_raise ArgumentError, fn ->
        Game.add_player(nil, @p1_ship_def, required_ship_sizes: @required_ship_sizes)
      end
    end
    test "with a ship_definition which is not a ship_definition", %{game_pid: game_pid} do
      assert_raise ArgumentError, fn ->
        Game.add_player(game_pid, nil, required_ship_sizes: @required_ship_sizes)
      end
      assert_raise ArgumentError, fn ->
        Game.add_player(game_pid, @p1_ship_def,
                        required_ship_sizes: "not ship sizes like [3,3,4,5]")
      end
      assert_raise ArgumentError, fn ->
        Game.add_player(game_pid, @p1_ship_def,
                        required_ship_sizes: @required_ship_sizes,
                        player_pid: "Not a PID")
      end
      assert_raise ArgumentError, fn ->
        Game.add_player(game_pid, @p1_ship_def,
                        required_ship_sizes: @required_ship_sizes,
                        board_size: "Not a size like {5,5}")
      end
    end
  end

  test "Adding a player with different ships from the required fails", %{game_pid: game_pid} do
    assert {:error, :incorrect_ship_sizes, _msg} =
      Game.add_player(game_pid, @incomplete_ship_def,
                      required_ship_sizes: @required_ship_sizes)
  end

  describe "Manage when a user drops during the game" do
    @tag :skip
    test "If game wasn't started, and any player process is dead, that player is drpped", %{game_pid: game_pid} do
      player_pid = spawn(fn-> receive do :nop -> :nop end end)
      :ok = Game.add_player(game_pid, @p1_ship_def,
              player_pid: player_pid,
              board_size: @board_size,
              required_ship_sizes: @required_ship_sizes)
      # When a player is added, its PID is liked to game
      assert player_pid in elem(Process.info(game_pid, :links),1)
      # Unlink from main process to avoid crashing this test
      Process.unlink(game_pid)
      # End player PID
      #Process.exit(player_pid, :drop)
      refute Process.alive?(player_pid)
      assert Process.alive?(game_pid)
    end

    @tag :skip
    test "If game was started, and any player process is dead, also game is killed", %{game_pid: game_pid} do
      player1_pid = spawn(fn-> receive do :nop -> :nop end end)
      player2_pid = spawn(fn-> receive do :nop -> :nop end end)
      :ok = Game.add_player(game_pid, @p1_ship_def,
              player_pid: player1_pid,
              board_size: @board_size,
              required_ship_sizes: @required_ship_sizes)
      :game_started = Game.add_player(game_pid, @p2_ship_def,
              player_pid: player2_pid,
              board_size: @board_size,
              required_ship_sizes: @required_ship_sizes)
      Process.unlink(game_pid) #Unlink from main process to avoid crashing
      # When a player drops and the game is started, drop the whole gameplay
      #Process.exit(player1_pid, :drop)
      refute Process.alive?(player1_pid)
      #refute Process.alive?(player2_pid)
      refute Process.alive?(game_pid)
    end
  end

  test "I can create a custom board", %{game_pid: game_pid} do
    assert :ok == Game.add_player(game_pid, [[{1,2},{1,3}]],
                              player_id: :player1,
                              player_pid: self(),
                              board_size: {5,5},
                              required_ship_sizes: [2])
  end

  describe "Integration test" do
    test "playing a game", %{game_pid: game_pid} do
      current_pid = self()
      assert Game.add_player(game_pid, @p1_ship_def,
              player_id: :p1,
              player_pid: current_pid,
              board_size: @board_size,
              required_ship_sizes: @required_ship_sizes) == :ok
      assert_receive({:wait_other_player, %{pid_receiver: ^current_pid, id_receiver: :p1}})
      assert Game.add_player(game_pid, @p2_ship_def,
              player_id: :p2,
              player_pid: current_pid,
              board_size: @board_size,
              required_ship_sizes: @required_ship_sizes) == :game_started
      assert_receive({:joined_game, %{game_pid: ^game_pid, player_id: :p1}})
      assert_receive({:joined_game, %{game_pid: ^game_pid, player_id: :p2}})
      assert_receive({:your_turn, %{id_receiver: :p1, pid_receiver: ^current_pid}})
      assert_receive({:wait_other_player, %{id_receiver: :p2, pid_receiver: ^current_pid}})
      # If player 2 attack when is not his turn
      Game.fire(game_pid, {4,5}, :p2)
      assert_receive({:error, :not_your_turn})
      # Player 1 attack on his turn
      Game.fire(game_pid, {4,4}, :p1)
      assert_receive({:fire_result, :water, {4,4}})
      assert_receive({:wait_other_player, %{id_receiver: :p1, pid_receiver: ^current_pid}})
      assert_receive({:your_turn, %{id_receiver: :p2, pid_receiver: ^current_pid}})
      # Player 2 turn
      Game.fire(game_pid, {4,5}, :p2)
      assert_receive({:fire_result, :hit, {4,5}})
      assert_receive({:wait_other_player, %{id_receiver: :p2, pid_receiver: ^current_pid}})
      assert_receive({:your_turn, %{id_receiver: :p1, pid_receiver: ^current_pid}})
      # Player 2 turn
      Game.fire(game_pid, {4,4}, :p1)
      assert_receive({:error, :already_fired, {4,4}})
      Game.fire(game_pid, {1,1}, :p1)
      Game.fire(game_pid, {5,5}, :p2)
      assert_receive({:fire_result, :ship_down, {5,5}})
      Game.fire(game_pid, {3,3}, :p1)
      # Player 2 wins
      Game.fire(game_pid, {2,2}, :p2)
      assert_receive({:fire_result, :ship_down, {2,2}})
      assert_receive({:received_fire, :ship_down, {2,2}})
      assert_receive({:game_terminated, :win})
      assert_receive({:game_terminated, :lose})
    end
  end


end
