defmodule AbsintheInitializer.MixProject do
  use Mix.Project

  def project do
    [
      app: :absinthe_initializer,
      version: "0.1.1",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: "An Absinthe initializer",
      package: [
        licenses: ["MIT"],
        maintainers: ["Hiram Castillo"],
        links: %{"GitHub" => "https://github.com/hiramcastillo36/absinthe_initializer"}
      ],
      deps: deps(),
      name: "AbsintheInitializer",
      source_url: "https://github.com/hiramcastillo36/absinthe_initializer",
      docs: [
        main: "AbsintheInitializer",
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:ex_doc, "~> 0.24"}
    ]
  end

  def get_project_name do
    config = Mix.Project.config()
    config[:app]
  end
end
