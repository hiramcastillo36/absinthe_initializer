defmodule AbsintheInitializer.Auth.Graphql.AccountsMutations do
  def account_mutations(project_capitalized) do
    account_mutations_content = """
    defmodule #{project_capitalized}Web.Schema.Context.Accounts.Mutations do
      @moduledoc \"\"\"
      This module contains mutations related to user accounts, including sign up, sign in, sign out, and role updates.
      \"\"\"

      use Absinthe.Schema.Notation
      alias #{project_capitalized}Web.Resolvers
      alias #{project_capitalized}Web.Schema.Middleware

      object :account_mutations do
        @desc \"\"\"
        Create a user account.
        This mutation allows the creation of a new user account and returns a session.

        ## Mutation
        ```graphql
        mutation SignUp($email: String!, $password: String!) {
          signUp(email: $email, password: $password) {
            token
            user {
              id
              email
            }
          }
        }
        ```
        ## Variables
        ```json
        {
          "email": "user@example.com",
          "password": "securepassword"
        }
        ```
        \"\"\"
        field :sign_up, :session do
          arg :email, :string
          arg :password, :string
          resolve &Resolvers.Accounts.sign_up/3
        end

        @desc \"\"\"
        Sign in a user.
        This mutation authenticates a user and returns a session.

        ## Mutation
        ```graphql
        mutation SignIn($email: String!, $password: String!) {
          signIn(email: $email, password: $password) {
            token
            user {
              id
              email
            }
          }
        }
        ```
        ## Variables
        ```json
        {
          "email": "user@example.com",
          "password": "securepassword"
        }
        ```
        \"\"\"
        field :sign_in, :session do
          arg :email, :string
          arg :password, :string
          resolve &Resolvers.Accounts.sign_in/3
        end

        @desc \"\"\"
        Sign out a user.
        This mutation ends the current user session.

        ## Mutation
        ```graphql
        mutation SignOut {
          signOut {
            message
          }
        }
        ```
        \"\"\"
        field :sign_out, :session do
          resolve &Resolvers.Accounts.sign_out/3
        end
      end
    end

    """
    account_mutations_content
  end
end
