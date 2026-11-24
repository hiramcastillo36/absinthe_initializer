defmodule E2eAppWeb.AuthE2eTest do
  use E2eAppWeb.ConnCase, async: false

  alias E2eApp.Accounts
  alias E2eApp.Accounts.{User, UserToken}
  alias E2eApp.Auth.SessionCache
  alias E2eApp.Repo
  alias E2eAppWeb.Schema.Middleware.AdminAuthentication

  @sign_up_mutation """
  mutation SignUp($email: String!, $password: String!) {
    signUp(email: $email, password: $password) {
      token
      user {
        id
        email
        isAdmin
      }
    }
  }
  """

  @sign_in_mutation """
  mutation SignIn($email: String!, $password: String!) {
    signIn(email: $email, password: $password) {
      token
      user {
        id
        email
        isAdmin
      }
    }
  }
  """

  @me_query """
  query Me {
    me {
      id
      email
      isAdmin
    }
  }
  """

  @sign_out_mutation """
  mutation SignOut {
    signOut {
      message
    }
  }
  """

  @sign_out_all_mutation """
  mutation SignOutAll {
    signOutAll {
      message
    }
  }
  """

  setup do
    original_config = Application.get_env(:e2e_app, E2eApp.Auth)

    on_exit(fn ->
      if original_config do
        Application.put_env(:e2e_app, E2eApp.Auth, original_config)
      else
        Application.delete_env(:e2e_app, E2eApp.Auth)
      end
    end)

    :ok
  end

  defp graphql(conn, query, variables \\ %{}) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post("/api", Jason.encode!(%{query: query, variables: variables}))
  end

  defp unique_ip do
    "10.0.#{:rand.uniform(250)}.#{:rand.uniform(250)}"
  end

  describe "end-to-end GraphQL authentication" do
    test "signUp creates user, hashes token in DB, sets HttpOnly cookie, and populates cache" do
      conn =
        build_conn()
        |> put_req_header("x-forwarded-for", unique_ip())
        |> graphql(@sign_up_mutation, %{
          email: "alice@example.com",
          password: "super_secure_password_123"
        })

      body = json_response(conn, 200)
      assert %{"data" => %{"signUp" => %{"token" => token, "user" => user}}} = body
      assert is_binary(token) and byte_size(token) > 20
      assert user["email"] == "alice@example.com"
      assert user["isAdmin"] == false

      # Cookie is set as HttpOnly
      assert %{value: ^token, http_only: true} = conn.resp_cookies["_e2e_app_session"]

      # Stored token in PostgreSQL is SHA-256 hashed, never plaintext
      [db_token] = Repo.all(UserToken)
      {:ok, raw_token} = Base.url_decode64(token, padding: false)
      assert db_token.token != raw_token
      assert db_token.token == :crypto.hash(:sha256, raw_token)

      # Session cache was populated
      assert {:ok, %User{email: "alice@example.com"}} = SessionCache.get(token)

      # `me` works via Authorization: Bearer header
      bearer_conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> graphql(@me_query)

      assert %{"data" => %{"me" => %{"email" => "alice@example.com"}}} =
               json_response(bearer_conn, 200)

      # `me` also works via HttpOnly cookie without Bearer header
      cookie_conn =
        build_conn()
        |> put_req_cookie("_e2e_app_session", token)
        |> graphql(@me_query)

      assert %{"data" => %{"me" => %{"email" => "alice@example.com"}}} =
               json_response(cookie_conn, 200)
    end

    test "blocks mass assignment of is_admin and rejects weak passwords" do
      cs =
        User.registration_changeset(%User{}, %{
          email: "hacker@example.com",
          password: "super_secure_password_123",
          is_admin: true
        })

      assert Ecto.Changeset.get_change(cs, :is_admin) == nil

      conn =
        build_conn()
        |> put_req_header("x-forwarded-for", unique_ip())
        |> graphql(@sign_up_mutation, %{email: "bad@example.com", password: "short"})

      body = json_response(conn, 200)
      assert %{"errors" => [%{"message" => "Could not create account.", "details" => details}]} = body
      assert is_list(details["password"])
    end

    test "blocks missing, malformed, and invalid tokens and clears invalid cookies" do
      # Missing token
      no_token_conn = build_conn() |> graphql(@me_query)

      assert %{"errors" => [%{"message" => "Please sign in first!"}]} =
               json_response(no_token_conn, 200)

      # Malformed token (rejected in memory before cache/DB)
      malformed_conn =
        build_conn()
        |> put_req_header("x-forwarded-for", unique_ip())
        |> put_req_header("authorization", "Bearer not_valid_base64!!!")
        |> graphql(@me_query)

      assert %{"errors" => [%{"message" => "The session is invalid or expired."}]} =
               json_response(malformed_conn, 200)

      # Valid-length random token that does not exist in DB (via cookie -> clears cookie)
      fake_token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

      invalid_cookie_conn =
        build_conn()
        |> put_req_header("x-forwarded-for", unique_ip())
        |> put_req_cookie("_e2e_app_session", fake_token)
        |> graphql(@me_query)

      assert %{"errors" => [%{"message" => "The session is invalid or expired."}]} =
               json_response(invalid_cookie_conn, 200)

      assert %{max_age: 0} = invalid_cookie_conn.resp_cookies["_e2e_app_session"]
    end

    test "rate limits invalid token spraying per IP" do
      Application.put_env(:e2e_app, E2eApp.Auth,
        transport: :both,
        cache: :ets,
        rate_limit: [enabled: true, max_requests: 10, invalid_token_max_requests: 2, window_seconds: 60]
      )

      attacker_ip = unique_ip()
      fake_token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

      for _ <- 1..2 do
        conn =
          build_conn()
          |> put_req_header("x-forwarded-for", attacker_ip)
          |> put_req_header("authorization", "Bearer #{fake_token}")
          |> graphql(@me_query)

        assert %{"errors" => [%{"message" => "The session is invalid or expired."}]} =
                 json_response(conn, 200)
      end

      blocked_conn =
        build_conn()
        |> put_req_header("x-forwarded-for", attacker_ip)
        |> put_req_header("authorization", "Bearer #{fake_token}")
        |> graphql(@me_query)

      assert %{
               "errors" => [
                 %{"message" => "Too many invalid token attempts. Please try again later."}
               ]
             } = json_response(blocked_conn, 200)
    end

    test "rate limits signIn brute-force attempts per IP" do
      Application.put_env(:e2e_app, E2eApp.Auth,
        transport: :both,
        cache: :ets,
        rate_limit: [enabled: true, max_requests: 2, invalid_token_max_requests: 20, window_seconds: 60]
      )

      ip = unique_ip()

      for _ <- 1..2 do
        conn =
          build_conn()
          |> put_req_header("x-forwarded-for", ip)
          |> graphql(@sign_in_mutation, %{email: "nobody@example.com", password: "wrong_password_123"})

        assert %{"errors" => [%{"message" => "Invalid email or password."}]} =
                 json_response(conn, 200)
      end

      limited_conn =
        build_conn()
        |> put_req_header("x-forwarded-for", ip)
        |> graphql(@sign_in_mutation, %{email: "nobody@example.com", password: "wrong_password_123"})

      assert %{"errors" => [%{"message" => "Too many requests. Please try again later."}]} =
               json_response(limited_conn, 200)
    end

    test "signOut revokes token immediately in DB, cache, and clears cookie" do
      {:ok, user} =
        Accounts.register_user(%{
          email: "bob@example.com",
          password: "super_secure_password_123"
        })

      token = Accounts.generate_user_session_token(user)

      sign_out_conn =
        build_conn()
        |> put_req_cookie("_e2e_app_session", token)
        |> graphql(@sign_out_mutation)

      assert %{"data" => %{"signOut" => %{"message" => "Signed out successfully."}}} =
               json_response(sign_out_conn, 200)

      assert %{max_age: 0} = sign_out_conn.resp_cookies["_e2e_app_session"]
      assert SessionCache.get(token) == :miss

      # Reusing revoked token is immediately blocked
      reused_conn =
        build_conn()
        |> put_req_header("x-forwarded-for", unique_ip())
        |> put_req_header("authorization", "Bearer #{token}")
        |> graphql(@me_query)

      assert %{"errors" => [%{"message" => "The session is invalid or expired."}]} =
               json_response(reused_conn, 200)
    end

    test "signOutAll revokes all sessions across multiple devices" do
      {:ok, user} =
        Accounts.register_user(%{
          email: "carol@example.com",
          password: "super_secure_password_123"
        })

      token_1 = Accounts.generate_user_session_token(user)
      token_2 = Accounts.generate_user_session_token(user)

      sign_out_all_conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token_1}")
        |> graphql(@sign_out_all_mutation)

      assert %{"data" => %{"signOutAll" => %{"message" => "All sessions revoked."}}} =
               json_response(sign_out_all_conn, 200)

      for token <- [token_1, token_2] do
        assert SessionCache.get(token) == :miss

        conn =
          build_conn()
          |> put_req_header("x-forwarded-for", unique_ip())
          |> put_req_header("authorization", "Bearer #{token}")
          |> graphql(@me_query)

        assert %{"errors" => [%{"message" => "The session is invalid or expired."}]} =
                 json_response(conn, 200)
      end
    end

    test "cookie-only mode hides token from JSON body and rejects Bearer header" do
      {:ok, _user} =
        Accounts.register_user(%{
          email: "dave@example.com",
          password: "super_secure_password_123"
        })

      Application.put_env(:e2e_app, E2eApp.Auth,
        transport: :cookie,
        cache: :ets,
        rate_limit: [enabled: true, max_requests: 10, window_seconds: 60]
      )

      sign_in_conn =
        build_conn()
        |> put_req_header("x-forwarded-for", unique_ip())
        |> graphql(@sign_in_mutation, %{
          email: "dave@example.com",
          password: "super_secure_password_123"
        })

      assert %{"data" => %{"signIn" => %{"token" => nil, "user" => %{"email" => "dave@example.com"}}}} =
               json_response(sign_in_conn, 200)

      assert %{value: cookie_token, http_only: true} = sign_in_conn.resp_cookies["_e2e_app_session"]

      # Cookie works
      ok_conn =
        build_conn()
        |> put_req_cookie("_e2e_app_session", cookie_token)
        |> graphql(@me_query)

      assert %{"data" => %{"me" => %{"email" => "dave@example.com"}}} = json_response(ok_conn, 200)

      # Bearer is ignored in cookie-only mode
      rejected_conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{cookie_token}")
        |> graphql(@me_query)

      assert %{"errors" => [%{"message" => "Please sign in first!"}]} =
               json_response(rejected_conn, 200)
    end

    test "AdminAuthentication blocks non-admin and allows admin after role update" do
      {:ok, user} =
        Accounts.register_user(%{
          email: "admin@example.com",
          password: "super_secure_password_123"
        })

      token = Accounts.generate_user_session_token(user)
      assert {:ok, _} = SessionCache.get(token)

      non_admin_res =
        AdminAuthentication.call(%Absinthe.Resolution{context: %{current_user: user}}, [])

      assert non_admin_res.errors == ["Not authorized!"]

      {:ok, admin_user} = Accounts.update_user_role(user, %{is_admin: true})
      assert admin_user.is_admin == true
      assert SessionCache.get(token) == :miss

      admin_res =
        AdminAuthentication.call(%Absinthe.Resolution{context: %{current_user: admin_user}}, [])

      assert admin_res.errors == []
    end
  end
end
