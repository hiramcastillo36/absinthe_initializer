defmodule AbsintheInitializer.Middlewares.Authenticate do
  def authenticate(project_capitalized) do
    authenticate_content = """
    defmodule #{project_capitalized}Web.Schema.Middleware.Authenticate do
       @behaviour Absinthe.Middleware

      def call(resolution, _) do
        case resolution.context do
          %{token: token} ->
            with {:ok, decoded_token} <- Base.url_decode64(token, padding: false) do
                  case #{project_capitalized}.Accounts.get_user_by_session_token(decoded_token) do
                    %#{project_capitalized}.Accounts.User{} = _ ->
                      resolution
                    nil ->
                      resolution
                      |> Absinthe.Resolution.put_result({:error, "The session is invalid!"})
                  end
            end
          _ ->
            resolution
            |> Absinthe.Resolution.put_result({:error, "Please sign in first!"})
        end
      end
    end
    """
    authenticate_content
  end
end
