# Battleship

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

#### Supervisor structure

Battleship and Game.Supervisor are supervisors. GameDispatcher pairs players
together. GameSupervisor is a DynamicSupervisor. Game and Board are simple
GenServers.

                      Battleship
                    /          \
        GameDispatcher      Game.Supervisor
                              /   |   \
                          Game   Game   ...
                        /   /   |   \
                    Board Board Board Board

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `battleship` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:battleship, "~> 0.1"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/battleship](https://hexdocs.pm/battleship).

