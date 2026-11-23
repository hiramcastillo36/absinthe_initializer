# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
