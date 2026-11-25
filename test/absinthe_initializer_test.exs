defmodule AbsintheInitializerTest do
  use ExUnit.Case, async: false
  doctest AbsintheInitializer

  @sample_mix_exs """
  defmodule MyApp.MixProject do
    use Mix.Project

    def project do
      [
        app: :my_app,
        version: "0.1.0",
        deps: deps()
      ]
    end

    defp deps do
      [
        {:phoenix, "~> 1.7.0"}
      ]
    end
  end
  """

  @sample_router_ex """
  defmodule MyAppWeb.Router do
    use MyAppWeb, :router

    pipeline :api do
      plug :accepts, ["json"]
    end

    scope "/api", MyAppWeb do
      pipe_through :api
    end
  end
  """

  @sample_config_exs """
  import Config

  config :my_app,
    ecto_repos: [MyApp.Repo]

  import_config "\#{config_env()}.exs"
  """

  @sample_application_ex """
  defmodule MyApp.Application do
    use Application

    @impl true
    def start(_type, _args) do
      children = [
        MyApp.Repo,
        MyAppWeb.Endpoint
      ]

      opts = [strategy: :one_for_one, name: MyApp.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end
  """

  defp scaffold_phoenix_project(tmp_dir, app_name \\ "my_app") do
    File.write!(Path.join(tmp_dir, "mix.exs"), @sample_mix_exs)

    router_dir = Path.join([tmp_dir, "lib", "#{app_name}_web"])
    File.mkdir_p!(router_dir)
    File.write!(Path.join(router_dir, "router.ex"), @sample_router_ex)

    app_dir = Path.join([tmp_dir, "lib", app_name])
    File.mkdir_p!(app_dir)
    File.write!(Path.join(app_dir, "application.ex"), @sample_application_ex)

    config_dir = Path.join(tmp_dir, "config")
    File.mkdir_p!(config_dir)
    File.write!(Path.join(config_dir, "config.exs"), @sample_config_exs)
  end

  defp assert_valid_elixir!(path) do
    assert File.exists?(path), "Expected generated file to exist: #{path}"
    content = File.read!(path)
    assert {:ok, _ast} = Code.string_to_quoted(content), "Invalid Elixir syntax in #{path}"
    content
  end

  describe "setup/2 without auth" do
    @tag :tmp_dir
    test "adds Absinthe deps, routes, schema, and changeset errors for snake_case app", %{
      tmp_dir: tmp_dir
    } do
      scaffold_phoenix_project(tmp_dir)

      File.cd!(tmp_dir, fn ->
        AbsintheInitializer.setup(false, app: :my_app)
      end)

      mix_content = assert_valid_elixir!(Path.join(tmp_dir, "mix.exs"))
      assert mix_content =~ ~s({:absinthe, "~> 1.7"})
      assert mix_content =~ ~s({:absinthe_plug, "~> 1.5"})
      assert mix_content =~ ~s({:absinthe_phoenix, "~> 2.0"})
      refute mix_content =~ "bcrypt_elixir"

      router_content =
        assert_valid_elixir!(Path.join([tmp_dir, "lib", "my_app_web", "router.ex"]))

      assert router_content =~ ~s(forward "/api")
      assert router_content =~ "analyze_complexity: true"
      assert router_content =~ "max_complexity: 200"
      assert router_content =~ "if Application.compile_env(:my_app, :dev_routes) do"
      assert router_content =~ ~s(forward "/graphiql")
      assert router_content =~ "schema: MyAppWeb.Schema"
      refute router_content =~ "SetCurrentUser"
      refute router_content =~ "before_send:"

      schema_content =
        assert_valid_elixir!(Path.join([tmp_dir, "lib", "my_app_web", "schema", "schema.ex"]))

      assert schema_content =~ "defmodule MyAppWeb.Schema do"
      assert schema_content =~ "field :hello, :string"

      changeset_errors =
        assert_valid_elixir!(
          Path.join([tmp_dir, "lib", "my_app_web", "schema", "changeset_errors.ex"])
        )

      assert changeset_errors =~ "defmodule MyAppWeb.Schema.ChangesetErrors do"

      plug_path = Path.join([tmp_dir, "lib", "my_app_web", "plugs", "set_current_user.ex"])
      refute File.exists?(Path.join([tmp_dir, "lib", "my_app", "accounts.ex"]))
      refute File.exists?(plug_path)
    end
  end

  describe "setup/2 with default auth (both transport, ETS cache, rate limit)" do
    @tag :tmp_dir
    test "generates hardened auth scaffold, config, and supervision children", %{
      tmp_dir: tmp_dir
    } do
      scaffold_phoenix_project(tmp_dir)

      File.cd!(tmp_dir, fn ->
        AbsintheInitializer.setup(true, app: :my_app)
      end)

      mix_content = assert_valid_elixir!(Path.join(tmp_dir, "mix.exs"))
      assert mix_content =~ ~s({:bcrypt_elixir, "~> 3.0"})
      refute mix_content =~ "cachex"

      router_content =
        assert_valid_elixir!(Path.join([tmp_dir, "lib", "my_app_web", "router.ex"]))

      assert router_content =~ "plug MyAppWeb.Plugs.SetCurrentUser"
      assert router_content =~ "before_send: {MyAppWeb.Plugs.AuthCookie, :before_send}"

      config_content = assert_valid_elixir!(Path.join([tmp_dir, "config", "config.exs"]))
      assert config_content =~ "config :my_app, MyApp.Auth,"
      assert config_content =~ "transport: :both"
      assert config_content =~ "secure: config_env() == :prod"
      assert config_content =~ "csrf_protection: true"
      assert config_content =~ "trust_proxy: false"
      assert config_content =~ "cache: :ets"
      assert config_content =~ "enabled: true"

      app_content = assert_valid_elixir!(Path.join([tmp_dir, "lib", "my_app", "application.ex"]))
      assert app_content =~ "MyApp.Auth.SessionCache.ETS"
      assert app_content =~ "MyApp.Auth.RateLimiter"

      expected_files = [
        ["lib", "my_app_web", "schema", "schema.ex"],
        ["lib", "my_app_web", "schema", "changeset_errors.ex"],
        ["lib", "my_app_web", "schema", "middleware", "authenticate.ex"],
        ["lib", "my_app_web", "schema", "middleware", "admin_authentication.ex"],
        ["lib", "my_app_web", "schema", "middleware", "auth_cookie.ex"],
        ["lib", "my_app_web", "schema", "middleware", "rate_limit.ex"],
        ["lib", "my_app_web", "schema", "context", "accounts", "types.ex"],
        ["lib", "my_app_web", "schema", "context", "accounts", "queries.ex"],
        ["lib", "my_app_web", "schema", "context", "accounts", "mutations.ex"],
        ["lib", "my_app_web", "resolvers", "accounts.ex"],
        ["lib", "my_app_web", "plugs", "set_current_user.ex"],
        ["lib", "my_app_web", "plugs", "auth_cookie.ex"],
        ["lib", "my_app", "auth", "config.ex"],
        ["lib", "my_app", "auth", "session_cache.ex"],
        ["lib", "my_app", "auth", "session_cache", "ets.ex"],
        ["lib", "my_app", "auth", "rate_limiter.ex"],
        ["lib", "my_app", "accounts.ex"],
        ["lib", "my_app", "accounts", "user.ex"],
        ["lib", "my_app", "accounts", "user_token.ex"],
        ["lib", "my_app", "accounts", "user_notifier.ex"]
      ]

      for segments <- expected_files do
        assert_valid_elixir!(Path.join([tmp_dir | segments]))
      end

      user_content = File.read!(Path.join([tmp_dir, "lib", "my_app", "accounts", "user.ex"]))
      assert user_content =~ "cast(attrs, [:email, :password])"
      assert user_content =~ "def role_changeset(user, attrs)"

      token_content =
        File.read!(Path.join([tmp_dir, "lib", "my_app", "accounts", "user_token.ex"]))

      assert token_content =~ ":crypto.hash(@hash_algorithm, raw_token)"
      assert token_content =~ "byte_size(raw_token) == @rand_size"

      plug_content = File.read!(Path.join(tmp_dir, "lib/my_app_web/plugs/set_current_user.ex"))
      assert plug_content =~ "invalid_token_blocked?"
      assert plug_content =~ ":auth_error"
      assert plug_content =~ "maybe_clear_cookie"

      auth_mw_path = Path.join(tmp_dir, "lib/my_app_web/schema/middleware/authenticate.ex")
      auth_mw = File.read!(auth_mw_path)

      assert auth_mw =~ "The session is invalid or expired."
      assert auth_mw =~ "Too many invalid token attempts."

      mutations_path = Path.join(tmp_dir, "lib/my_app_web/schema/context/accounts/mutations.ex")
      mutations_content = File.read!(mutations_path)

      assert mutations_content =~ "field :sign_out_all, :sign_out_result"

      assert mutations_content =~
               "middleware Middleware.RateLimit, action: :sign_in, by_arg: :email"

      assert mutations_content =~ "middleware Middleware.AuthCookie, :put"

      migrations =
        Path.wildcard(Path.join([tmp_dir, "priv", "repo", "migrations", "*_create_users.exs"]))

      assert [migration_path] = migrations
      migration_content = assert_valid_elixir!(migration_path)
      assert migration_content =~ "defmodule MyApp.Repo.Migrations.CreateUsers do"
    end
  end

  describe "setup/2 with configurable auth options" do
    @tag :tmp_dir
    test "supports cookie transport with Cachex and no rate limit", %{tmp_dir: tmp_dir} do
      scaffold_phoenix_project(tmp_dir)

      File.cd!(tmp_dir, fn ->
        AbsintheInitializer.setup(true,
          app: :my_app,
          auth_transport: :cookie,
          cache: :cachex,
          rate_limit: false
        )
      end)

      mix_content = assert_valid_elixir!(Path.join(tmp_dir, "mix.exs"))
      assert mix_content =~ ~s({:cachex, "~> 4.0"})

      app_content = assert_valid_elixir!(Path.join([tmp_dir, "lib", "my_app", "application.ex"]))
      assert app_content =~ "{Cachex, name: :my_app_session_cache}"
      refute app_content =~ "RateLimiter"

      cachex_path = Path.join([tmp_dir, "lib", "my_app", "auth", "session_cache", "cachex.ex"])
      assert_valid_elixir!(cachex_path)
      refute File.exists?(Path.join(tmp_dir, "lib/my_app/auth/session_cache/ets.ex"))
      refute File.exists?(Path.join([tmp_dir, "lib", "my_app", "auth", "rate_limiter.ex"]))

      config_content = assert_valid_elixir!(Path.join([tmp_dir, "config", "config.exs"]))
      assert config_content =~ "transport: :cookie"
      assert config_content =~ "cache: :cachex"
      assert config_content =~ "enabled: false"
    end

    @tag :tmp_dir
    test "supports bearer-only transport without cache or rate limit", %{tmp_dir: tmp_dir} do
      scaffold_phoenix_project(tmp_dir)

      File.cd!(tmp_dir, fn ->
        AbsintheInitializer.setup(true,
          app: :my_app,
          auth_transport: :bearer,
          cache: :none,
          rate_limit: false
        )
      end)

      router_content =
        assert_valid_elixir!(Path.join([tmp_dir, "lib", "my_app_web", "router.ex"]))

      assert router_content =~ "plug MyAppWeb.Plugs.SetCurrentUser"
      refute router_content =~ "before_send:"
      refute File.exists?(Path.join([tmp_dir, "lib", "my_app_web", "plugs", "auth_cookie.ex"]))

      auth_cookie_mw =
        Path.join([tmp_dir, "lib", "my_app_web", "schema", "middleware", "auth_cookie.ex"])

      refute File.exists?(auth_cookie_mw)
      refute File.exists?(Path.join(tmp_dir, "lib/my_app/auth/session_cache/ets.ex"))

      mutations_path = Path.join(tmp_dir, "lib/my_app_web/schema/context/accounts/mutations.ex")
      mutations_content = assert_valid_elixir!(mutations_path)

      refute mutations_content =~ "Middleware.AuthCookie"
      refute mutations_content =~ "Middleware.RateLimit"
    end
  end

  describe "setup/2 error handling" do
    @tag :tmp_dir
    test "raises when mix.exs is missing the deps section", %{tmp_dir: tmp_dir} do
      scaffold_phoenix_project(tmp_dir)
      File.write!(Path.join(tmp_dir, "mix.exs"), "defmodule Empty do\nend\n")

      File.cd!(tmp_dir, fn ->
        assert_raise RuntimeError, ~r/Could not find dependencies section in mix.exs/, fn ->
          AbsintheInitializer.setup(false, app: :my_app)
        end
      end)
    end

    @tag :tmp_dir
    test "raises when router.ex is missing the api pipeline marker", %{tmp_dir: tmp_dir} do
      scaffold_phoenix_project(tmp_dir)

      File.write!(
        Path.join([tmp_dir, "lib", "my_app_web", "router.ex"]),
        "defmodule MyAppWeb.Router do\nend\n"
      )

      File.cd!(tmp_dir, fn ->
        assert_raise RuntimeError, ~r/Could not find route section in router.ex/, fn ->
          AbsintheInitializer.setup(false, app: :my_app)
        end
      end)
    end

    test "raises ArgumentError on invalid transport or cache options" do
      assert_raise ArgumentError, ~r/Invalid :auth_transport/, fn ->
        AbsintheInitializer.setup(true, app: :my_app, auth_transport: :jwt)
      end

      assert_raise ArgumentError, ~r/Invalid :cache/, fn ->
        AbsintheInitializer.setup(true, app: :my_app, cache: :redis)
      end
    end
  end

  describe "Mix.Tasks.AbsintheInitializer" do
    setup do
      previous_shell = Mix.shell()
      Mix.shell(Mix.Shell.Process)
      on_exit(fn -> Mix.shell(previous_shell) end)
      :ok
    end

    test "raises on unsupported CLI flags or invalid option values" do
      assert_raise Mix.Error, ~r/Invalid option\(s\): --unknown/, fn ->
        Mix.Tasks.AbsintheInitializer.run(["--unknown"])
      end

      assert_raise Mix.Error, ~r/Invalid value for --auth-transport/, fn ->
        Mix.Tasks.AbsintheInitializer.run(["--auth", "--auth-transport", "jwt"])
      end

      assert_raise Mix.Error, ~r/Invalid value for --cache/, fn ->
        Mix.Tasks.AbsintheInitializer.run(["--auth", "--cache", "redis"])
      end
    end

    @tag :tmp_dir
    test "runs basic setup via Mix task", %{tmp_dir: tmp_dir} do
      scaffold_phoenix_project(tmp_dir, "absinthe_initializer")

      File.cd!(tmp_dir, fn ->
        Mix.Tasks.AbsintheInitializer.run([])
      end)

      assert_received {:mix_shell, :info, ["Starting Absinthe setup..."]}
      assert_received {:mix_shell, :info, ["Absinthe setup complete."]}

      path = Path.join([tmp_dir, "lib", "absinthe_initializer_web", "schema", "schema.ex"])
      assert_valid_elixir!(path)
    end

    @tag :tmp_dir
    test "runs configurable auth setup via Mix task flags", %{tmp_dir: tmp_dir} do
      scaffold_phoenix_project(tmp_dir, "absinthe_initializer")

      File.cd!(tmp_dir, fn ->
        Mix.Tasks.AbsintheInitializer.run([
          "--auth",
          "--auth-transport",
          "cookie",
          "--cache",
          "ets",
          "--no-rate-limit"
        ])
      end)

      assert_received {:mix_shell, :info, ["Starting Absinthe setup..."]}
      assert_received {:mix_shell, :info, ["Absinthe setup complete."]}

      accounts_path = Path.join([tmp_dir, "lib", "absinthe_initializer", "accounts.ex"])
      assert_valid_elixir!(accounts_path)

      config_content = assert_valid_elixir!(Path.join([tmp_dir, "config", "config.exs"]))
      assert config_content =~ "transport: :cookie"
      assert config_content =~ "enabled: false"
    end
  end
end
