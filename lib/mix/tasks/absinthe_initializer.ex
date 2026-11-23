defmodule Mix.Tasks.AbsintheInitializer do
  @shortdoc "Initializes Absinthe in a Phoenix project"
  @moduledoc """
  Initializes Absinthe GraphQL in a Phoenix project.

  ## Usage

      mix absinthe_initializer
      mix absinthe_initializer --auth

  ## Options

    * `--auth` - Generates user authentication context, schema, migrations,
      middleware, plugs, resolvers, and GraphQL account types, queries, and mutations.
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _remaining, invalid} = OptionParser.parse(args, strict: [auth: :boolean])

    if invalid != [] do
      invalid_flags = Enum.map_join(invalid, ", ", fn {flag, _} -> flag end)
      Mix.raise("Invalid option(s): #{invalid_flags}. Supported options: --auth")
    end

    with_auth = Keyword.get(opts, :auth, false)

    Mix.shell().info("Starting Absinthe setup...")
    AbsintheInitializer.setup(with_auth)
    Mix.shell().info("Absinthe setup complete.")
  end
end
