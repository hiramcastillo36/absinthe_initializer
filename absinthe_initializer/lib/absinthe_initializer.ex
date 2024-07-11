defmodule AbsintheInitializer do
  @moduledoc """
  Documentation for `AbsintheInitializer`.
  """

  def to_camel_case(string) do
    string
    |> String.split("_")
    |> Enum.map(&capitalize_first_letter/1)
    |> Enum.join("")
  end

  defp capitalize_first_letter(word) do
    word
    |> String.downcase()
    |> String.capitalize()
  end

  def setup do

    path = File.cwd!()

    mix_path = Path.join([path, "mix.exs"])
    # Añadir dependencias de Absinthe
    mix_exs_content = File.read!(mix_path)

    string_to_split_on = """
      defp deps do
        [
    """

    project_name = AbsintheInitializer.MixProject.get_project_name() |> Atom.to_string()

    project_capitalized = to_camel_case(project_name)

    case String.split(mix_exs_content, string_to_split_on) do
      [before, after_dp] ->
        deps_content =
          """
                {:absinthe, "~> 1.7.0"},
                {:absinthe_plug, "~> 1.5"},
                {:absinthe_phoenix, "~> 2.0.1"},
          """
        updated_mix_exs_content = "#{before}#{string_to_split_on}\n#{deps_content}\n#{after_dp}"
        File.write!("mix.exs", updated_mix_exs_content)
      _ ->
        IO.puts("No se pudo encontrar la sección de dependencias en mix.exs")
        System.halt(1)
    end

    # Añadir el router de Absinthe

    router_content = """
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


    router_path = Path.join(["lib", "#{project_name}_web", "router.ex"])

    File.cd!(Path.join(["lib", "#{project_name}_web"]))

    File.dir?("schema") || File.mkdir!("schema")

    File.write!(Path.join(["schema", "schema.ex"]), AbsintheInitializer.Schema.generate_schema(project_capitalized))

    router_ex_content = File.read!("router.ex")

    string_to_split_on = """
        plug :accepts, ["json"]
      end
    """

    case String.split(router_ex_content, string_to_split_on) do
      [before, after_scope] ->
        updated_router_ex_content = "#{before}#{string_to_split_on}\n#{router_content}\n#{after_scope}"
        File.write!("router.ex", updated_router_ex_content)
      _ ->
        IO.puts("No se pudo encontrar la sección de rutas en router.ex")
        System.halt(1)
    end
  end

end
