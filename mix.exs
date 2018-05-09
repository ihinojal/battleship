defmodule Battleship.MixProject do
  use Mix.Project

  @github_url "https://github.com/ihinojal/btctool"

  def project do
    [
      app: :battleship,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      # Docs
      source_url: @github_url,
      #homepage_url: "https://battleship.pw??",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Battleship, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end

  defp description do
    "This library is a multiplayer game of the classic battleship board or"<>
    " paper game."
  end

  defp package do
    [
      maintainers: ["Ivan H."],
      licenses: ["MIT"],
      links: %{"Github" => @github_url}
    ]
  end

  defp docs do
    [
      main: "Battleship", # The main page in the docs
      # source_ref: "v#{@version}",
      # logo: "path/to/logo.png",
      extras: ["README.md"]
    ]
  end
end
