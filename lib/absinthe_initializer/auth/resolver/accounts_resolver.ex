defmodule AbsintheInitializer.Auth.Resolver.AccountsResolver do
  def accounts_resolver(project_capitalized) do
    accounts_resolver_content = """
    defmodule #{project_capitalized}Web.Resolvers.Accounts do
        alias #{project_capitalized}.Accounts
        alias #{project_capitalized}.Accounts.User

        alias #{project_capitalized}Web.Schema.ChangesetErrors

        def me(_, _, %{context: %{token: token}}) do
          with {:ok, decoded_token} <- Base.url_decode64(token, padding: false) do
            case Accounts.get_user_by_session_token(decoded_token) do
              %User{} = user ->
                {:ok, user}
              nil ->
                {:ok, nil}
            end
          else
            _ ->
              {:ok, nil}
          end
        end

        def me(_, _, _)do
          {:ok, nil}
        end

        def sign_up(_, %{email: email, password: password}, _)do
          case Accounts.register_user(%{email: email, password: password}) do
            {:ok, user} ->
              token = #{project_capitalized}.Accounts.generate_user_session_token(user)

              {:ok, %{user: user, token: Base.url_encode64(token, padding: false)}}
            {:error, %Ecto.Changeset{} = changeset} ->
              {
                :error,
                message: "Could not create account.",
                details: ChangesetErrors.error_details(changeset)
              }
          end
        end

        def sign_in(_, %{email: email, password: password}, _)do
          case Accounts.get_user_by_email_and_password(email, password) do
            %User{} = user ->
              token = #{project_capitalized}.Accounts.generate_user_session_token(user)

              {:ok, %{user: user, token: Base.url_encode64(token, padding: false)}}
            nil ->
              {
                :error,
                message: "Credentials are invalid."
              }
          end
        end

        def sign_out(_, _, %{context: %{token: token}}) do
          with {:ok, decoded_token} <- Base.url_decode64(token, padding: false) do
            #{project_capitalized}.Accounts.delete_user_session_token(decoded_token)
          end
          {:ok, nil}
        end
      end
    """
    accounts_resolver_content
  end
end
