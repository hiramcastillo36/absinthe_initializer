defmodule AbsintheInitializer.GeneratedRuntimeTest do
  use ExUnit.Case, async: false

  @compile {:no_warn_undefined,
            [
              RuntimeTestApp.Auth.Config,
              RuntimeTestApp.Auth.SessionCache,
              RuntimeTestApp.Auth.SessionCache.ETS,
              RuntimeTestApp.Auth.RateLimiter
            ]}

  alias AbsintheInitializer.Template

  @assigns [
    app_name: "runtime_test_app",
    app_module: "RuntimeTestApp",
    auth_transport: :both,
    cache: :ets,
    rate_limit: true,
    cookies_enabled: true
  ]

  setup_all do
    templates = [
      "auth/config.ex.eex",
      "auth/session_cache.ex.eex",
      "auth/session_cache_ets.ex.eex",
      "auth/rate_limiter.ex.eex"
    ]

    for template <- templates do
      template
      |> Template.render(@assigns)
      |> Code.compile_string(template)
    end

    :ok
  end

  setup do
    on_exit(fn ->
      Application.delete_env(:runtime_test_app, RuntimeTestApp.Auth)
    end)

    :ok
  end

  describe "generated Auth.Config" do
    test "returns defaults and respects runtime Application env overrides" do
      config = RuntimeTestApp.Auth.Config

      assert config.transport() == :both
      assert config.cookies_enabled?()
      assert config.bearer_enabled?()
      assert config.cookie_name() == "_runtime_test_app_session"
      assert Keyword.get(config.cookie_opts(), :path) == "/"
      assert config.csrf_protection?()
      refute config.trust_proxy?()
      assert config.max_batch_size() == 1
      assert config.session_ttl_days() == 7
      assert config.cache() == :ets
      assert config.cache_ttl_seconds() == 300
      assert config.rate_limit_enabled?()
      assert config.rate_limit_max_requests() == 10
      assert config.rate_limit_window_seconds() == 60
      assert config.rate_limit_invalid_token_max_requests() == 20

      Application.put_env(:runtime_test_app, RuntimeTestApp.Auth,
        transport: :cookie,
        cache: :none,
        session_ttl_days: 14,
        cookie_opts: [secure: true, same_site: "Strict"],
        rate_limit: [enabled: false, max_requests: 5, invalid_token_max_requests: 3]
      )

      assert config.transport() == :cookie
      assert config.cookies_enabled?()
      refute config.bearer_enabled?()
      assert config.cache() == :none
      assert config.session_ttl_days() == 14
      assert Keyword.get(config.cookie_opts(), :secure) == true
      assert Keyword.get(config.cookie_opts(), :same_site) == "Strict"
      assert Keyword.get(config.cookie_opts(), :http_only) == true
      refute config.rate_limit_enabled?()
      assert config.rate_limit_max_requests() == 5
      assert config.rate_limit_invalid_token_max_requests() == 3
    end
  end

  describe "generated SessionCache + ETS adapter" do
    test "caches, expires, deletes single token, and revokes all user sessions" do
      cache = RuntimeTestApp.Auth.SessionCache
      ets_cache = RuntimeTestApp.Auth.SessionCache.ETS

      start_supervised!(ets_cache)

      user_1 = %{id: 1, email: "alice@example.com"}
      user_2 = %{id: 2, email: "bob@example.com"}

      assert cache.get("missing_token") == :miss

      assert :ok = cache.put("token_1a", user_1, 60)
      assert :ok = cache.put("token_1b", user_1, 60)
      assert :ok = cache.put("token_2a", user_2, 60)

      assert {:ok, ^user_1} = cache.get("token_1a")
      assert {:ok, ^user_1} = cache.get("token_1b")
      assert {:ok, ^user_2} = cache.get("token_2a")

      # Single token invalidation
      assert :ok = cache.delete("token_1a")
      assert cache.get("token_1a") == :miss
      assert {:ok, ^user_1} = cache.get("token_1b")

      # Revoke all sessions for user_1 without touching user_2
      assert :ok = cache.put("token_1c", user_1, 60)
      assert :ok = cache.delete_user_sessions(1)
      assert cache.get("token_1b") == :miss
      assert cache.get("token_1c") == :miss
      assert {:ok, ^user_2} = cache.get("token_2a")

      # Expired TTL returns :miss immediately
      assert :ok = cache.put("expired_token", user_2, 0)
      assert cache.get("expired_token") == :miss

      # :none cache mode bypasses ETS cleanly
      Application.put_env(:runtime_test_app, RuntimeTestApp.Auth, cache: :none)
      assert cache.get("token_2a") == :miss
      assert :ok = cache.put("token_none", user_2, 60)
      assert :ok = cache.delete("token_none")
      assert :ok = cache.delete_user_sessions(2)
    end
  end

  describe "generated RateLimiter" do
    test "enforces max_requests per bucket and exposes non-mutating blocked?/3" do
      limiter = RuntimeTestApp.Auth.RateLimiter
      start_supervised!(limiter)

      bucket = {:sign_in, "127.0.0.1"}
      other_bucket = {:sign_in, "10.0.0.2"}

      refute limiter.blocked?(bucket, 2, 60)
      assert :ok = limiter.check_rate(bucket, 2, 60)
      refute limiter.blocked?(bucket, 2, 60)
      assert :ok = limiter.check_rate(bucket, 2, 60)

      # At limit: blocked?/3 reports true without changing other buckets
      assert limiter.blocked?(bucket, 2, 60)
      assert {:error, :rate_limited} = limiter.check_rate(bucket, 2, 60)
      assert limiter.blocked?(bucket, 2, 60)

      # Separate IP bucket is unaffected
      refute limiter.blocked?(other_bucket, 2, 60)
      assert :ok = limiter.check_rate(other_bucket, 2, 60)
    end
  end
end
