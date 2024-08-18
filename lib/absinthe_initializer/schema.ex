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

  def generate_schema_with_auth(project_capitalized) do
    schema_content = """
    defmodule #{project_capitalized}Web.Schema do
      use Absinthe.Schema

      #Types
      import_types #{project_capitalized}Web.Schema.Context.Accounts.Types

      #Queries
      import_types #{project_capitalized}Web.Schema.Context.Accounts.Queries

      #Mutations
      import_types #{project_capitalized}Web.Schema.Context.Accounts.Mutations

      query do
        import_fields :account_queries
      end

      mutation do
        import_fields :account_mutations
      end
    end
    """
  schema_content
  end
end
