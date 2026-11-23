defmodule AbsintheInitializer.MixProject do
  use Mix.Project

  @version "0.1.4"
  @source_url "https://github.com/hiramcastillo36/absinthe_initializer"

  def project do
    [
      app: :absinthe_initializer,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      description:
        "A Mix task that automates setting up Absinthe GraphQL (with optional authentication) in Phoenix projects.",
      package: package(),
      deps: deps(),
      name: "AbsintheInitializer",
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :eex]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Hiram Castillo"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/master/CHANGELOG.md"
      },
      files: ~w(lib priv .formatter.exs mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end
end
