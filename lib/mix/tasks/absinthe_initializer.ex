defmodule Mix.Tasks.AbsintheInitializer do
  @shortdoc "Initializes Absinthe in a Phoenix project"
  @moduledoc """
  Initializes Absinthe GraphQL in a Phoenix project with optional hardened authentication.

  ## Usage

      mix absinthe_initializer
      mix absinthe_initializer --auth
      mix absinthe_initializer --auth --auth-transport cookie --cache ets
      mix absinthe_initializer --auth --auth-transport bearer --cache cachex --no-rate-limit

  ## Options

    * `--auth` - Generates user authentication context, hashed session tokens, migrations,
      middleware, plugs, resolvers, GraphQL account types/queries/mutations, and config.
    * `--auth-transport` - Session transport strategy: `bearer`, `cookie`, or `both`
      (default: `both`). Only used with `--auth`.
    * `--cache` - Session cache adapter: `ets` (zero dependencies), `cachex`, or `none`
      (default: `ets`). Only used with `--auth`.
    * `--rate-limit` / `--no-rate-limit` - Enables or disables ETS rate limiting on
      `sign_in` and `sign_up` mutations (default: enabled with `--auth`).
  """

  use Mix.Task

  @valid_transports ~w(bearer cookie both)
  @valid_caches ~w(ets cachex none)

  @impl Mix.Task
  def run(args) do
    {opts, _remaining, invalid} =
      OptionParser.parse(args,
        strict: [
          auth: :boolean,
          auth_transport: :string,
          cache: :string,
          rate_limit: :boolean
        ]
      )

    if invalid != [] do
      invalid_flags = Enum.map_join(invalid, ", ", fn {flag, _} -> flag end)

      Mix.raise(
        "Invalid option(s): #{invalid_flags}. " <>
          "Supported options: --auth, --auth-transport, --cache, --rate-limit, --no-rate-limit"
      )
    end

    with_auth = Keyword.get(opts, :auth, false)
    auth_transport = parse_enum!(opts, :auth_transport, "both", @valid_transports)
    cache = parse_enum!(opts, :cache, "ets", @valid_caches)
    rate_limit = Keyword.get(opts, :rate_limit, true)

    Mix.shell().info("Starting Absinthe setup...")

    AbsintheInitializer.setup(with_auth,
      auth_transport: auth_transport,
      cache: cache,
      rate_limit: rate_limit
    )

    Mix.shell().info("Absinthe setup complete.")
  end

  defp parse_enum!(opts, key, default, valid_values) do
    value = Keyword.get(opts, key, default)

    if value in valid_values do
      String.to_atom(value)
    else
      flag = "--#{key |> Atom.to_string() |> String.replace("_", "-")}"
      allowed = Enum.join(valid_values, ", ")
      Mix.raise("Invalid value for #{flag}: #{inspect(value)}. Allowed values: #{allowed}")
    end
  end
end
