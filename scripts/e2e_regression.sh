#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/absinthe_e2e.XXXXXX")"
PHX_NEW_VERSION="${PHX_NEW_VERSION:-1.7.21}"

cleanup() {
  if [ "${KEEP_E2E_DIR:-0}" != "1" ]; then
    rm -rf "$WORK_DIR"
  else
    echo "Keeping E2E workspace at: $WORK_DIR"
  fi
}
trap cleanup EXIT

echo "==> Installing phx_new archive ($PHX_NEW_VERSION)..."
mix archive.install hex phx_new "$PHX_NEW_VERSION" --force

echo "==> Generating fresh Phoenix API project in $WORK_DIR/e2e_app..."
cd "$WORK_DIR"
mix phx.new e2e_app \
  --no-html \
  --no-assets \
  --no-dashboard \
  --no-live \
  --no-gettext \
  --no-install

cd "$WORK_DIR/e2e_app"

echo "==> Adding absinthe_initializer local path dependency..."
REPO_DIR="$REPO_DIR" elixir -e '
  repo_dir = System.fetch_env!("REPO_DIR")
  path = "mix.exs"
  content = File.read!(path)
  marker = "defp deps do\n    ["
  dep = "\n      {:absinthe_initializer, path: #{inspect(repo_dir)}, only: :dev, runtime: false},"
  [before, after_marker] = String.split(content, marker, parts: 2)
  File.write!(path, before <> marker <> dep <> after_marker)
'

echo "==> Fetching absinthe_initializer and running mix absinthe_initializer --auth..."
mix deps.get
mix absinthe_initializer --auth

echo "==> Fetching generated Absinthe & Bcrypt dependencies..."
mix deps.get

echo "==> Preparing PostgreSQL test database and running migrations..."
MIX_ENV=test mix ecto.drop --quiet || true
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate

echo "==> Compiling generated Phoenix app with --warnings-as-errors..."
MIX_ENV=test mix compile --warnings-as-errors

echo "==> Running end-to-end GraphQL authentication regression tests..."
cp "$REPO_DIR/e2e/auth_e2e_test.exs" "$WORK_DIR/e2e_app/test/e2e_app_web/auth_e2e_test.exs"
MIX_ENV=test mix test test/e2e_app_web/auth_e2e_test.exs

echo "==> E2E regression suite passed!"
