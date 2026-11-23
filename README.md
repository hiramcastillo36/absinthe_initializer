# AbsintheInitializer

[![CI](https://github.com/hiramcastillo36/absinthe_initializer/actions/workflows/ci.yml/badge.svg)](https://github.com/hiramcastillo36/absinthe_initializer/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/absinthe_initializer.svg)](https://hex.pm/packages/absinthe_initializer)
[![HexDocs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/absinthe_initializer)
[![License: MIT](https://img.shields.io/hexpm/l/absinthe_initializer.svg)](LICENSE)

`AbsintheInitializer` is a Mix task that automates the setup of a GraphQL API using Absinthe in your Phoenix project, with optional production-ready, configurable authentication.

## Features

- Automatically adds Absinthe dependencies to `mix.exs` and configures `/api` and `/graphiql` routes in your Phoenix router.
- Generates a GraphQL schema and Ecto `ChangesetErrors` helper.
- Optional hardened authentication (`--auth`) with:
  - **Configurable transport (`--auth-transport bearer|cookie|both`):** HttpOnly / SameSite cookies via Absinthe `before_send`, Bearer headers, or hybrid mode (default: `both`).
  - **Configurable session cache (`--cache ets|cachex|none`):** `@behaviour SessionCache` with a zero-dependency ETS adapter (with TTL & cleanup) or Cachex, plus instant cache invalidation on `sign_out`, `sign_out_all`, and password changes.
  - **SHA-256 hashed session tokens in DB:** raw tokens are never stored in PostgreSQL.
  - **Single user lookup per request:** `SetCurrentUser` resolves `current_user` once (cache → DB) into the Absinthe context.
  - **Built-in ETS rate limiting (`--rate-limit` / `--no-rate-limit`):** protects `sign_in`, `sign_up`, and invalid session token spraying against brute-force attacks with zero extra dependencies.
  - **Invalid token hardening:** rejects malformed tokens in memory before touching cache/DB, returns distinct errors for missing vs invalid/expired vs rate-limited tokens, and automatically clears invalid/expired cookies.
  - **Centralized runtime configuration** in `config/config.exs` + automatic supervision tree wiring in `application.ex`.

## Installation

Add `absinthe_initializer` to your Phoenix project's `mix.exs`:

```elixir
defp deps do
  [
    {:absinthe_initializer, "~> 0.1.4", only: :dev, runtime: false}
  ]
end
```

Fetch dependencies:

```bash
mix deps.get
```

## Usage

### Basic Setup (without authentication)

```bash
mix absinthe_initializer
```

### Hardened Authentication Setup

```bash
# Default auth: both HttpOnly cookies & Bearer tokens, ETS cache, ETS rate limiting
mix absinthe_initializer --auth

# Cookie-only SPA setup with ETS cache
mix absinthe_initializer --auth --auth-transport cookie --cache ets

# API/mobile Bearer-only setup with Cachex and no rate limiting
mix absinthe_initializer --auth --auth-transport bearer --cache cachex --no-rate-limit
```

### CLI Options

| Flag | Values | Default | Description |
| --- | --- | --- | --- |
| `--auth` | boolean | `false` | Enables full authentication scaffolding |
| `--auth-transport` | `bearer`, `cookie`, `both` | `both` | Token delivery & extraction mode |
| `--cache` | `ets`, `cachex`, `none` | `ets` | Session cache adapter |
| `--rate-limit` / `--no-rate-limit` | boolean | `true` | ETS rate limiting on `sign_in` / `sign_up` |

## Runtime Configuration (`config/config.exs`)

When `--auth` is enabled, `AbsintheInitializer` injects a configuration block into `config/config.exs` that you can override per environment (for example setting `secure: true` in `config/runtime.exs` for production HTTPS):

```elixir
config :my_app, MyApp.Auth,
  transport: :both,
  cookie_name: "_my_app_session",
  cookie_opts: [http_only: true, secure: false, same_site: "Lax", max_age: 604_800],
  session_ttl_days: 7,
  cache: :ets,
  cache_ttl_seconds: 300,
  rate_limit: [enabled: true, max_requests: 10, window_seconds: 60]
```

## Generated Project Structure (with `--auth`)

```text
lib/
  my_app/
    accounts.ex
    accounts/
      user.ex
      user_token.ex
      user_notifier.ex
    auth/
      config.ex
      session_cache.ex
      session_cache/
        ets.ex               # or cachex.ex when --cache cachex
      rate_limiter.ex        # when --rate-limit (default)
  my_app_web/
    plugs/
      set_current_user.ex
      auth_cookie.ex         # when --auth-transport cookie|both
    resolvers/
      accounts.ex
    schema/
      schema.ex
      changeset_errors.ex
      middleware/
        authenticate.ex
        admin_authentication.ex
        auth_cookie.ex       # when --auth-transport cookie|both
        rate_limit.ex        # when --rate-limit (default)
      context/
        accounts/
          types.ex
          queries.ex
          mutations.ex
priv/
  repo/
    migrations/
      <timestamp>_create_users.exs
```

## Contributing

Contributions are welcome! Feel free to submit issues or pull requests against the `dev` branch.

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and is published on [HexDocs](https://hexdocs.pm/absinthe_initializer).

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
