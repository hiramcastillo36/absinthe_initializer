defmodule AbsintheInitializer.Auth.Graphql.AccountsQueries do
  def account_queries(project_capitalized) do
    account_queries_content = """
    defmodule #{project_capitalized}Web.Schema.Context.Accounts.Queries do
      @moduledoc \"\"\"
      This module contains queries related to user accounts.
      \"\"\"

      use Absinthe.Schema.Notation
      alias #{project_capitalized}Web.Resolvers

      object :account_queries do
        @desc \"\"\"
        Get the current user.
        This query returns information about the currently authenticated user.

        ## Query
        ```graphql
        query Me {
          me {
            id
            username
            email
            # Add other user fields as needed
          }
        }
        ```
        \"\"\"
        field :me, :user do
          resolve &Resolvers.Accounts.me/3
        end
      end
    end

    """
    account_queries_content
  end
end
