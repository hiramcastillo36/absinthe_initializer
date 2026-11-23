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

  defp scaffold_phoenix_project(tmp_dir, app_name \\ "my_app") do
    File.write!(Path.join(tmp_dir, "mix.exs"), @sample_mix_exs)

    router_dir = Path.join([tmp_dir, "lib", "#{app_name}_web"])
    File.mkdir_p!(router_dir)
    File.write!(Path.join(router_dir, "router.ex"), @sample_router_ex)
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
      assert mix_content =~ ~s({:absinthe, "~> 1.7.0"})
      assert mix_content =~ ~s({:absinthe_plug, "~> 1.5"})
      assert mix_content =~ ~s({:absinthe_phoenix, "~> 2.0.1"})
      refute mix_content =~ "bcrypt_elixir"

      router_content =
        assert_valid_elixir!(Path.join([tmp_dir, "lib", "my_app_web", "router.ex"]))

      assert router_content =~ ~s(forward "/api")
      assert router_content =~ ~s(forward "/graphiql")
      assert router_content =~ "schema: MyAppWeb.Schema"
      refute router_content =~ "SetCurrentUser"

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

  describe "setup/2 with auth" do
    @tag :tmp_dir
    test "generates full auth scaffold with valid Elixir syntax", %{tmp_dir: tmp_dir} do
      scaffold_phoenix_project(tmp_dir)

      File.cd!(tmp_dir, fn ->
        AbsintheInitializer.setup(true, app: :my_app)
      end)

      mix_content = assert_valid_elixir!(Path.join(tmp_dir, "mix.exs"))
      assert mix_content =~ ~s({:bcrypt_elixir, "~> 3.0"})

      router_content =
        assert_valid_elixir!(Path.join([tmp_dir, "lib", "my_app_web", "router.ex"]))

      assert router_content =~ "plug MyAppWeb.Plugs.SetCurrentUser"

      expected_files = [
        ["lib", "my_app_web", "schema", "schema.ex"],
        ["lib", "my_app_web", "schema", "changeset_errors.ex"],
        ["lib", "my_app_web", "schema", "middleware", "authenticate.ex"],
        ["lib", "my_app_web", "schema", "middleware", "admin_authentication.ex"],
        ["lib", "my_app_web", "schema", "context", "accounts", "types.ex"],
        ["lib", "my_app_web", "schema", "context", "accounts", "queries.ex"],
        ["lib", "my_app_web", "schema", "context", "accounts", "mutations.ex"],
        ["lib", "my_app_web", "resolvers", "accounts.ex"],
        ["lib", "my_app_web", "plugs", "set_current_user.ex"],
        ["lib", "my_app", "accounts.ex"],
        ["lib", "my_app", "accounts", "user.ex"],
        ["lib", "my_app", "accounts", "user_token.ex"],
        ["lib", "my_app", "accounts", "user_notifier.ex"]
      ]

      for segments <- expected_files do
        assert_valid_elixir!(Path.join([tmp_dir | segments]))
      end

      migrations =
        Path.wildcard(Path.join([tmp_dir, "priv", "repo", "migrations", "*_create_users.exs"]))

      assert [migration_path] = migrations
      migration_content = assert_valid_elixir!(migration_path)
      assert migration_content =~ "defmodule MyAppWeb.Migrations.CreateUsers do"
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
  end

  describe "Mix.Tasks.AbsintheInitializer" do
    setup do
      previous_shell = Mix.shell()
      Mix.shell(Mix.Shell.Process)
      on_exit(fn -> Mix.shell(previous_shell) end)
      :ok
    end

    test "raises on unsupported CLI flags" do
      assert_raise Mix.Error, ~r/Invalid option\(s\): --unknown/, fn ->
        Mix.Tasks.AbsintheInitializer.run(["--unknown"])
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
    test "runs auth setup via Mix task with --auth", %{tmp_dir: tmp_dir} do
      scaffold_phoenix_project(tmp_dir, "absinthe_initializer")

      File.cd!(tmp_dir, fn ->
        Mix.Tasks.AbsintheInitializer.run(["--auth"])
      end)

      assert_received {:mix_shell, :info, ["Starting Absinthe setup..."]}
      assert_received {:mix_shell, :info, ["Absinthe setup complete."]}

      accounts_path = Path.join([tmp_dir, "lib", "absinthe_initializer", "accounts.ex"])
      assert_valid_elixir!(accounts_path)
    end
  end
end
