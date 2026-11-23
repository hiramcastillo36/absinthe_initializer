defmodule AbsintheInitializer do
  @moduledoc """
  Automates the setup of an Absinthe GraphQL API in a Phoenix project,
  with configurable authentication (HttpOnly cookies, Bearer tokens, session caching,
  hashed session tokens, and ETS rate limiting).
  """

  alias AbsintheInitializer.Template

  @valid_transports [:bearer, :cookie, :both]
  @valid_caches [:ets, :cachex, :none]

  @doc """
  Converts a `snake_case` string to `CamelCase`.

  ## Examples

      iex> AbsintheInitializer.to_camel_case("my_app")
      "MyApp"
  """
  def to_camel_case(string) do
    string
    |> String.split("_")
    |> Enum.map_join("", &String.capitalize/1)
  end

  @doc """
  Runs the Absinthe initializer in the current working directory.

  ## Options

    * `:app` - Overrides the project app name (defaults to `Mix.Project.config()[:app]`).
    * `:auth_transport` - `:bearer`, `:cookie`, or `:both` (default: `:both`).
    * `:cache` - `:ets`, `:cachex`, or `:none` (default: `:ets`).
    * `:rate_limit` - Boolean enabling ETS rate limiting on auth mutations (default: `true`).
  """
  def setup(with_auth \\ false, opts \\ []) do
    project_name =
      opts
      |> Keyword.get_lazy(:app, fn -> Mix.Project.config()[:app] end)
      |> to_string()

    project_module = to_camel_case(project_name)
    auth_transport = validate_opt!(opts, :auth_transport, :both, @valid_transports)
    cache = validate_opt!(opts, :cache, :ets, @valid_caches)
    rate_limit = Keyword.get(opts, :rate_limit, true)
    cookies_enabled = with_auth and auth_transport in [:cookie, :both]

    assigns = [
      app_name: project_name,
      app_module: project_module,
      auth_transport: auth_transport,
      cache: cache,
      rate_limit: rate_limit,
      cookies_enabled: cookies_enabled
    ]

    update_mix_exs(with_auth, cache)
    update_router(project_name, project_module, with_auth, cookies_enabled)
    setup_base_files(project_name, with_auth, assigns)

    if with_auth do
      setup_auth_files(project_name, assigns)
      maybe_update_config_exs(project_name, project_module, auth_transport, cache, rate_limit)
      maybe_update_application_ex(project_name, project_module, cache, rate_limit)
    end
  end

  defp validate_opt!(opts, key, default, valid_values) do
    value = Keyword.get(opts, key, default)

    if value in valid_values do
      value
    else
      message =
        "Invalid #{inspect(key)}: #{inspect(value)}. Expected one of: #{inspect(valid_values)}"

      raise ArgumentError, message
    end
  end

  defp setup_base_files(project_name, with_auth, assigns) do
    schema_template = if with_auth, do: "auth/schema.ex.eex", else: "schema.ex.eex"

    Template.render_to_file(
      schema_template,
      Path.join(["lib", "#{project_name}_web", "schema", "schema.ex"]),
      assigns
    )

    Template.render_to_file(
      "changeset_errors.ex.eex",
      Path.join(["lib", "#{project_name}_web", "schema", "changeset_errors.ex"]),
      assigns
    )
  end

  defp setup_auth_files(project_name, assigns) do
    web_root = Path.join(["lib", "#{project_name}_web"])
    app_root = Path.join(["lib", project_name])
    cache = Keyword.fetch!(assigns, :cache)
    rate_limit = Keyword.fetch!(assigns, :rate_limit)
    cookies_enabled = Keyword.fetch!(assigns, :cookies_enabled)

    # Core auth config & session cache
    Template.render_to_file(
      "auth/config.ex.eex",
      Path.join([app_root, "auth", "config.ex"]),
      assigns
    )

    Template.render_to_file(
      "auth/session_cache.ex.eex",
      Path.join([app_root, "auth", "session_cache.ex"]),
      assigns
    )

    case cache do
      :ets ->
        Template.render_to_file(
          "auth/session_cache_ets.ex.eex",
          Path.join([app_root, "auth", "session_cache", "ets.ex"]),
          assigns
        )

      :cachex ->
        Template.render_to_file(
          "auth/session_cache_cachex.ex.eex",
          Path.join([app_root, "auth", "session_cache", "cachex.ex"]),
          assigns
        )

      :none ->
        :ok
    end

    if rate_limit do
      Template.render_to_file(
        "auth/rate_limiter.ex.eex",
        Path.join([app_root, "auth", "rate_limiter.ex"]),
        assigns
      )

      Template.render_to_file(
        "auth/middlewares/rate_limit.ex.eex",
        Path.join([web_root, "schema", "middleware", "rate_limit.ex"]),
        assigns
      )
    end

    # Plugs & middleware
    Template.render_to_file(
      "auth/plugs/set_current_user.ex.eex",
      Path.join([web_root, "plugs", "set_current_user.ex"]),
      assigns
    )

    if cookies_enabled do
      Template.render_to_file(
        "auth/plugs/auth_cookie.ex.eex",
        Path.join([web_root, "plugs", "auth_cookie.ex"]),
        assigns
      )

      Template.render_to_file(
        "auth/middlewares/auth_cookie.ex.eex",
        Path.join([web_root, "schema", "middleware", "auth_cookie.ex"]),
        assigns
      )
    end

    Template.render_to_file(
      "auth/middlewares/authenticate.ex.eex",
      Path.join([web_root, "schema", "middleware", "authenticate.ex"]),
      assigns
    )

    Template.render_to_file(
      "auth/middlewares/admin_authentication.ex.eex",
      Path.join([web_root, "schema", "middleware", "admin_authentication.ex"]),
      assigns
    )

    # GraphQL types, queries, mutations, and resolver
    accounts_gql = Path.join([web_root, "schema", "context", "accounts"])

    Template.render_to_file(
      "auth/graphql/types.ex.eex",
      Path.join(accounts_gql, "types.ex"),
      assigns
    )

    Template.render_to_file(
      "auth/graphql/queries.ex.eex",
      Path.join(accounts_gql, "queries.ex"),
      assigns
    )

    Template.render_to_file(
      "auth/graphql/mutations.ex.eex",
      Path.join(accounts_gql, "mutations.ex"),
      assigns
    )

    Template.render_to_file(
      "auth/resolvers/accounts.ex.eex",
      Path.join([web_root, "resolvers", "accounts.ex"]),
      assigns
    )

    # Accounts context, schemas, notifier, and migration
    Template.render_to_file(
      "auth/accounts/accounts.ex.eex",
      Path.join([app_root, "accounts.ex"]),
      assigns
    )

    Template.render_to_file(
      "auth/accounts/user.ex.eex",
      Path.join([app_root, "accounts", "user.ex"]),
      assigns
    )

    Template.render_to_file(
      "auth/accounts/user_token.ex.eex",
      Path.join([app_root, "accounts", "user_token.ex"]),
      assigns
    )

    Template.render_to_file(
      "auth/accounts/user_notifier.ex.eex",
      Path.join([app_root, "accounts", "user_notifier.ex"]),
      assigns
    )

    timestamp =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.to_string()
      |> String.slice(0..18)
      |> String.replace(["-", ":", ".", " "], "")

    Template.render_to_file(
      "auth/migrations/create_users.exs.eex",
      Path.join(["priv", "repo", "migrations", "#{timestamp}_create_users.exs"]),
      assigns
    )
  end

  defp update_mix_exs(with_auth, cache) do
    mix_path = Path.join(File.cwd!(), "mix.exs")
    mix_content = File.read!(mix_path)

    base_deps = [
      ~s(      {:absinthe, "~> 1.7.0"},),
      ~s(      {:absinthe_plug, "~> 1.5"},),
      ~s(      {:absinthe_phoenix, "~> 2.0.1"},)
    ]

    auth_deps = if with_auth, do: [~s(      {:bcrypt_elixir, "~> 3.0"},)], else: []
    cachex? = with_auth and cache == :cachex
    cache_deps = if cachex?, do: [~s(      {:cachex, "~> 4.0"},)], else: []

    absinthe_deps = Enum.join(base_deps ++ auth_deps ++ cache_deps, "\n") <> "\n"
    updated_content = insert_absinthe_deps(mix_content, absinthe_deps)
    File.write!(mix_path, updated_content)
  end

  defp insert_absinthe_deps(content, absinthe_deps) do
    deps_marker = "defp deps do\n    ["

    case String.split(content, deps_marker) do
      [before, after_scope] ->
        before <> deps_marker <> "\n" <> absinthe_deps <> after_scope

      _ ->
        raise "Could not find dependencies section in mix.exs"
    end
  end

  defp update_router(project_name, project_module, with_auth, cookies_enabled) do
    router_path = Path.join(["lib", "#{project_name}_web", "router.ex"])
    router_content = File.read!(router_path)

    route_marker = """
        plug :accepts, ["json"]
      end
    """

    updated_content =
      insert_absinthe_routes(router_content, project_module, route_marker, cookies_enabled)

    File.write!(router_path, updated_content)

    if with_auth do
      updated_plug_content = update_plug(File.read!(router_path), project_module)
      File.write!(router_path, updated_plug_content)
    end
  end

  defp update_plug(content, project_module) do
    add_plug_current_user = "   plug #{project_module}Web.Plugs.SetCurrentUser\n "
    route_plug_marker = " plug :accepts, [\"json\"]\n "

    case String.split(content, route_plug_marker) do
      [before, after_plug] ->
        before <> route_plug_marker <> add_plug_current_user <> after_plug

      _ ->
        raise "Could not find plug section in router.ex"
    end
  end

  defp insert_absinthe_routes(content, project_module, route_marker, cookies_enabled) do
    before_send_opt =
      if cookies_enabled do
        ",\n        before_send: {#{project_module}Web.Plugs.AuthCookie, :before_send}"
      else
        ""
      end

    absinthe_routes = """
      scope "/" do
        pipe_through :api

        forward "/api",
          Absinthe.Plug,
          schema: #{project_module}Web.Schema#{before_send_opt}

        forward "/graphiql",
          Absinthe.Plug.GraphiQL,
          schema: #{project_module}Web.Schema#{before_send_opt}
      end
    """

    case String.split(content, route_marker) do
      [before, after_scope] ->
        before <> route_marker <> "\n" <> absinthe_routes <> after_scope

      _ ->
        raise "Could not find route section in router.ex"
    end
  end

  defp maybe_update_config_exs(project_name, project_module, auth_transport, cache, rate_limit) do
    config_path = Path.join(["config", "config.exs"])

    if File.exists?(config_path) do
      content = File.read!(config_path)
      config_header = "config :#{project_name}, #{project_module}.Auth,"

      unless String.contains?(content, config_header) do
        auth_config = """
        config :#{project_name}, #{project_module}.Auth,
          transport: #{inspect(auth_transport)},
          cookie_name: "_#{project_name}_session",
          cookie_opts: [http_only: true, secure: false, same_site: "Lax", max_age: 604_800],
          session_ttl_days: 7,
          cache: #{inspect(cache)},
          cache_ttl_seconds: 300,
          rate_limit: [enabled: #{rate_limit}, max_requests: 10, window_seconds: 60]
        """

        updated =
          case String.split(content, ~s(import_config "\#{config_env()}.exs"), parts: 2) do
            [before, after_import] ->
              before <>
                auth_config <>
                "\n" <> ~s(import_config "\#{config_env()}.exs") <> after_import

            _ ->
              String.trim_trailing(content) <> "\n\n" <> auth_config
          end

        File.write!(config_path, updated)
      end
    end
  end

  defp maybe_update_application_ex(project_name, project_module, cache, rate_limit) do
    app_path = Path.join(["lib", project_name, "application.ex"])

    cache_entries =
      case cache do
        :ets -> ["      #{project_module}.Auth.SessionCache.ETS,"]
        :cachex -> ["      {Cachex, name: :#{project_name}_session_cache},"]
        :none -> []
      end

    rate_limit_entries =
      if rate_limit, do: ["      #{project_module}.Auth.RateLimiter,"], else: []

    children_entries = cache_entries ++ rate_limit_entries

    if File.exists?(app_path) and children_entries != [] do
      content = File.read!(app_path)
      marker = "children = ["

      with [before, after_marker] <- String.split(content, marker, parts: 2) do
        missing_entries =
          Enum.reject(children_entries, fn entry ->
            String.contains?(content, String.trim(entry))
          end)

        if missing_entries != [] do
          insertion = "\n" <> Enum.join(missing_entries, "\n")
          File.write!(app_path, before <> marker <> insertion <> after_marker)
        end
      end
    end
  end
end
