defmodule AbsintheInitializer do
  @moduledoc """
  Documentation for `AbsintheInitializer`.
  """

  alias AbsintheInitializer.{MixProject, Schema, Middlewares}
  alias AbsintheInitializer.Auth.{Graphql, Resolver, Schema, Migrations, ChangesetErrors}
  alias AbsintheInitializer.Auth.Plug.SetCurrentUser

  def to_camel_case(string) do
    string
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join("")
  end

  def setup(with_auth \\ false) do
    project_name = AbsintheInitializer.MixProject.get_project_name() |> Atom.to_string()
    project_capitalized = to_camel_case(project_name)

    update_mix_exs(with_auth)
    update_router(project_capitalized, with_auth)
    setup_schema(project_name, project_capitalized, with_auth)
    create_changeset_errors(project_capitalized)

    if with_auth do
      setup_middleware(project_capitalized)
      setup_graphql_mutations(project_capitalized)
      setup_graphql_queries(project_capitalized)
      setup_graphql_types(project_capitalized)
      setup_resolver(project_capitalized)
      create_user_table_and_context(project_capitalized)
      create_plug_file(project_capitalized)
    end
  end

  defp create_changeset_errors(project_capitalized) do
    ChangesetErrors.generate_file(project_capitalized)
  end

  defp update_mix_exs(with_auth) do
    mix_path = Path.join(File.cwd!(), "mix.exs")
    mix_content = File.read!(mix_path)

    if with_auth do
      absinthe_deps = """
        {:absinthe, "~> 1.7.0"},
        {:absinthe_plug, "~> 1.5"},
        {:absinthe_phoenix, "~> 2.0.1"},
        {:bcrypt_elixir, "~> 3.0"},
      """
      updated_content = insert_absinthe_deps(mix_content, absinthe_deps)
      File.write!(mix_path, updated_content)
    else
      absinthe_deps = """
        {:absinthe, "~> 1.7.0"},
        {:absinthe_plug, "~> 1.5"},
        {:absinthe_phoenix, "~> 2.0.1"},
      """
      updated_content = insert_absinthe_deps(mix_content, absinthe_deps)
      File.write!(mix_path, updated_content)
    end
  end

  defp create_plug_file(project_capitalized) do
    plug_path = Path.join(["lib", "#{String.downcase(project_capitalized)}_web", "plugs"])
    File.mkdir!(plug_path)

    plug_content = SetCurrentUser.plug_current_user(project_capitalized)
    File.write!(Path.join(plug_path, "set_current_user.ex"), plug_content)
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

  defp update_router(project_capitalized, with_auth) do
    router_path = Path.join(["lib", "#{String.downcase(project_capitalized)}_web", "router.ex"])
    router_content = File.read!(router_path)

    if with_auth do
      route_marker = """
        plug :accepts, ["json"]
      end
    """
      updated_content = insert_absinthe_routes(router_content, project_capitalized, route_marker)
      File.write!(router_path, updated_content)

      updated_plug_content = update_plug(File.read!(router_path), project_capitalized)
      File.write!(router_path, updated_plug_content)

    else
      route_marker = """
        plug :accepts, ["json"]
      end
    """
      updated_content = insert_absinthe_routes(router_content, project_capitalized, route_marker)
      File.write!(router_path, updated_content)
    end
  end


  defp create_user_table_and_context(project_capitalized) do
    project_name = String.downcase(project_capitalized)
    schema_dir = Path.join(["lib", "#{project_name}", "accounts"])
    File.mkdir_p!(schema_dir)

    Migrations.UsersMigration.generate_migration(project_capitalized)
    Schema.UserNotifier.generate_user_notifier(project_capitalized)
    Schema.UserToken.generate_user_token(project_capitalized)
    Schema.User.generate_user_schema(project_capitalized)
    Schema.Accounts.generate_accounts_file(project_capitalized)
  end

  defp update_plug(content, project_capitalized) do
    add_plug_current_user = "\t\tplug #{project_capitalized}Web.Plugs.SetCurrentUser\n "

      route_plug_marker = " plug :accepts, [\"json\"]\n "

      case String.split(content, route_plug_marker) do
        [before, after_plug] ->
          before <> route_plug_marker <> add_plug_current_user <> after_plug
        _ ->
          raise "Could not find plug section in router.ex"
      end
  end

  defp insert_absinthe_routes(content, project_capitalized, route_marker) do
    absinthe_routes = """
      scope "/" do
        pipe_through :api

        forward "/api",
         Absinthe.Plug,
         schema: #{project_capitalized}Web.Schema

        forward "/graphiql",
          Absinthe.Plug.GraphiQL,
          schema: #{project_capitalized}Web.Schema
      end
    """

    case String.split(content, route_marker) do
      [before, after_scope] ->
        before <> route_marker <> "\n\n" <> absinthe_routes <> after_scope
      _ ->
        raise "Could not find route section in router.ex"
    end
  end

  defp setup_schema(project_name, project_capitalized, with_auth) do
    schema_dir = Path.join(["lib", "#{project_name}_web", "schema"])
    File.mkdir_p!(schema_dir)

    schema_content = if with_auth do
      AbsintheInitializer.Schema.generate_schema_with_auth(project_capitalized)
    else
      AbsintheInitializer.Schema.generate_schema(project_capitalized)
    end

    File.write!(Path.join(schema_dir, "schema.ex"), schema_content)
  end

  defp setup_middleware(project_capitalized) do
    middleware_dir = Path.join(["lib", String.downcase(project_capitalized) <> "_web", "schema", "middleware"])
    File.mkdir_p!(middleware_dir)

    File.write!(Path.join(middleware_dir, "admin_authentication.ex"),
      Middlewares.AdminAuthentication.admin_authentication(project_capitalized))

    File.write!(Path.join(middleware_dir, "authenticate.ex"),
      Middlewares.Authenticate.authenticate(project_capitalized))
  end

  defp setup_graphql_mutations(project_capitalized) do
    mutations_dir = Path.join(["lib", String.downcase(project_capitalized) <> "_web", "schema", "context", "accounts"])
    File.mkdir_p!(mutations_dir)

    File.write!(Path.join(mutations_dir, "mutations.ex"),
    Graphql.AccountsMutations.account_mutations(project_capitalized))
  end

  defp setup_graphql_queries(project_capitalized) do
    queries_dir = Path.join(["lib", String.downcase(project_capitalized) <> "_web", "schema", "context", "accounts"])
    File.mkdir_p!(queries_dir)

    File.write!(Path.join(queries_dir, "queries.ex"),
      Graphql.AccountsQueries.account_queries(project_capitalized))
  end

  defp setup_graphql_types(project_capitalized) do
    types_dir = Path.join(["lib", String.downcase(project_capitalized) <> "_web", "schema", "context", "accounts"])
    File.mkdir_p!(types_dir)

    File.write!(Path.join(types_dir, "types.ex"),
      Graphql.AccountsTypes.account_types(project_capitalized))
  end

  defp setup_resolver(project_capitalized) do
    resolver_dir = Path.join(["lib", String.downcase(project_capitalized) <> "_web", "resolvers"])
    File.mkdir_p!(resolver_dir)

    File.write!(Path.join(resolver_dir, "accounts.ex"),
      Resolver.AccountsResolver.accounts_resolver(project_capitalized))
  end
end
