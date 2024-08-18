defmodule AbsintheInitializer.Middlewares.AdminAuthentication do
  def admin_authentication(project_capitalized) do
    authenticate_content = """
    defmodule #{project_capitalized}Web.Schema.Middleware.AdminAuthentication do
    @behaviour Absinthe.Middleware

      alias #{project_capitalized}.Accounts
      alias #{project_capitalized}.Accounts.User

      def call(%{context: %{token: token}} = resolution, _) do
        with {:ok, decoded_token} <- Base.url_decode64(token, padding: false),
            %User{is_admin: true} <- Accounts.get_user_by_session_token(decoded_token) do
          resolution
        else
          %User{} ->
            add_error(resolution, "Not authorized!")
          _ ->
            add_error(resolution, "The session is invalid!")
        end
      end

      def call(resolution, _) do
        add_error(resolution, "Please sign in first!")
      end

      defp add_error(resolution, message) do
        Absinthe.Resolution.put_result(resolution, {:error, message})
      end
    end
    """
    authenticate_content
  end
end
