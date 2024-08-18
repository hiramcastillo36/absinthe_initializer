defmodule AbsintheInitializer.Auth.Plug.SetCurrentUser do
  def plug_current_user(project_name) do
    plug_current_user_content = """
    defmodule #{project_name}Web.Plugs.SetCurrentUser do
      @behaviour Plug

      import Plug.Conn

      def init(opts), do: opts

      def call(conn, _) do
        context = build_context(conn)
        Absinthe.Plug.put_options(conn, context: context)
      end

      defp build_context(conn) do
        with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
            {:ok, decoded_token} <- Base.url_decode64(token, padding: false),
            {:ok, _verify_session} <- #{project_name}.Accounts.UserToken.verify_session_token_query(decoded_token) do
          %{token: token}
        else
          _ -> %{}
        end
      end
    end
    """
    plug_current_user_content
  end
end
