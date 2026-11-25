# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Configurable authentication transport via `--auth-transport bearer|cookie|both` (default: `both`), including HttpOnly/SameSite cookie support via Absinthe `before_send` and `Middleware.AuthCookie`.
- Configurable session caching via `--cache ets|cachex|none` (default: `ets`) with `@behaviour SessionCache`, zero-dependency ETS adapter with TTL cleanup, Cachex adapter, and automatic invalidation on `sign_out`, `sign_out_all`, role updates, user deletion, and password/email changes.
- Built-in ETS rate limiting (`--rate-limit` / `--no-rate-limit`) for `sign_in` (dual IP + normalized email buckets), `sign_up`, and invalid session token spraying protection (`RateLimiter.blocked?/3`), ignoring spoofable `X-Forwarded-For` headers unless `trust_proxy: true`.
- Cookie CSRF protection (`csrf_protection: true`, halting cross-site and non-JSON POST requests with `403` to prevent Login CSRF and authenticated CSRF), GraphQL JSON batching protection (`max_batch_size: 1`), SHA-256 hashed rate-limit argument keys, `secure: config_env() == :prod` cookie default, GraphQL query complexity limit (`max_complexity: 200`), and `/graphiql` gated behind `:dev_routes`.
- Offensive security audit suite (`e2e/security_audit_test.exs`, `SEC-01`–`SEC-12`) executed on every CI run.
- In-memory token length validation (`byte_size == 32`) before hitting cache or database, distinct `:invalid_token` / `:rate_limited` errors in auth middleware, and automatic cleanup of invalid/expired session cookies.
- Centralized runtime auth configuration (`MyApp.Auth.Config`) injected into `config/config.exs` and supervision tree children injected into `application.ex`.
- `sign_out_all` GraphQL mutation to revoke all active sessions across devices.
- Live runtime unit tests for generated `Auth.Config`, `SessionCache.ETS`, and `RateLimiter` modules.
- End-to-end regression suite (`scripts/e2e_regression.sh` + `e2e/auth_e2e_test.exs`) and CI `e2e` job generating a real Phoenix + PostgreSQL app to verify the full GraphQL auth lifecycle.

### Changed
- Migrated all code generators to EEx templates under `priv/templates/` (bundled in Hex package).
- Resolved `current_user` once in `SetCurrentUser` plug (cache → DB) instead of re-querying in every middleware and resolver.
- Hashed session tokens with SHA-256 before storing them in `users_tokens`.

### Fixed
- Removed `:is_admin` from `User.registration_changeset/3` to prevent mass assignment, and added explicit `User.role_changeset/2`.
- Protected `me`, `sign_out`, and `sign_out_all` with `Middleware.Authenticate`.
- Added missing mailer functions to `UserNotifier`.

## [0.1.4] - 2026-11-23

### Added
- GitHub Actions CI workflow (formatting, strict compilation, tests, docs, Hex audit).
- Automated Hex.pm + HexDocs + GitHub Releases workflow triggered on `v*` tags.
- Dependabot configuration for Mix dependencies and GitHub Actions.
- ExUnit integration test suite covering default and `--auth` setups.
- MIT `LICENSE` file and `CHANGELOG.md`.

### Changed
- Scoped `ex_doc` dependency to `only: :dev, runtime: false`.
- Improved `mix absinthe_initializer` CLI flag parsing with `OptionParser`.
- Configured ExDoc metadata (`source_ref`, `extras`, `files` in Hex package).

### Fixed
- Fixed generated file paths for `snake_case` Phoenix project names (e.g. `my_app`).
- Resolved project name via `Mix.Project.config()[:app]` instead of relying on `AbsintheInitializer.MixProject`.
- Replaced `File.mkdir!/1` with `File.mkdir_p!/1` when creating plugs and migration directories.
- Removed compiler warnings (duplicate/unused aliases and duplicated `start_permanent`).

## [0.1.3] - 2024-09-05

### Added
- `--auth` flag to generate user authentication context, migrations, plugs, middleware, resolvers, and GraphQL types/queries/mutations.

### Fixed
- Project name detection when running the Mix task.

### Documentation
- Updated `README.md` with installation, usage, and generated structure details.

[Unreleased]: https://github.com/hiramcastillo36/absinthe_initializer/compare/v0.1.4...HEAD
[0.1.4]: https://github.com/hiramcastillo36/absinthe_initializer/releases/tag/v0.1.4
