defmodule AbsintheInitializer.Schema do
  def generate_schema(project_capitalized) do
    schema_content = """
      defmodule #{project_capitalized}Web.Schema do
        use Absinthe.Schema
        import_types Absinthe.Type.Custom

        query do
          field :hello, :string do
            resolve fn _, _, _ ->
              {:ok, "world"}
            end
          end
        end
      end
      """
    schema_content
  end
end
