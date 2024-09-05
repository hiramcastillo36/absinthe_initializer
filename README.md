# AbsintheInitializer

`AbsintheInitializer` is a Mix task that automates the setup of a GraphQL API using Absinthe in your Phoenix project. This tool simplifies the process of configuring Absinthe, routing, and optionally setting up authentication, allowing you to focus on developing your GraphQL API quickly.

## Features

- Automatically sets up Absinthe and adds the necessary dependencies to your `mix.exs` file.
- Configures routing for the GraphQL API and the GraphiQL interface.
- Optionally adds user authentication, including middleware, resolvers, and migrations.
- Generates a schema, mutations, queries, and types for your GraphQL API.

## Installation

To install `AbsintheInitializer`, add the following dependency to your Phoenix project's `mix.exs`:

```elixir
defp deps do
  [
    {:absinthe_initializer, "~> 0.1.0"}
  ]
end
```

Fetch the dependencies with:

```bash
mix deps.get
```

## Usage

`AbsintheInitializer` can be used through a Mix task that configures Absinthe in your Phoenix project. The task also provides an option to enable user authentication.

### Basic Setup

To initialize Absinthe without authentication, simply run:

```bash
mix absinthe_initializer
```

This command will:
- Add the required Absinthe dependencies to your `mix.exs`.
- Set up GraphQL routes in your Phoenix router.
- Generate a basic GraphQL schema.

### Setup with Authentication

To initialize Absinthe with user authentication, run the task with the `--auth` flag:

```bash
mix absinthe_initializer --auth
```

This command will:
- Add Absinthe and authentication-related dependencies (e.g., `bcrypt_elixir`).
- Generate user context, schema, and migrations.
- Set up GraphQL mutations, queries, and types for user accounts.
- Configure middleware for authentication.

### Example

```bash
# Basic setup without authentication
mix absinthe_initializer

# Setup with authentication
mix absinthe_initializer --auth
```

## Project Structure

After running the `mix absinthe_initializer` task, your project will have the following additions:

```
lib/
  my_project_web/
    schema/
      schema.ex        # GraphQL schema
      context/
        accounts/
          queries.ex   # GraphQL queries for user accounts
          mutations.ex # GraphQL mutations for user accounts
          types.ex     # GraphQL types for user accounts
    resolvers/
      accounts.ex      # Resolver for account queries and mutations
    plugs/
      set_current_user.ex  # Plug for setting the current user in the session
```

## Generated Files and Modules

### Authentication Setup (optional)

If you run the task with the `--auth` flag, the following modules and files are generated:

- **User context**: Manages user accounts.
- **GraphQL types, queries, and mutations**: Used for authentication-related operations.
- **Authentication middleware**: Handles authentication checks in the GraphQL API.

## Development

If you want to extend or customize the functionality of `AbsintheInitializer`, you can modify the generated schema, mutations, queries, or add additional middleware and resolvers to suit your project needs.

## Contributing

Contributions are welcome! Feel free to submit issues or pull requests to improve this project.

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/absinthe_initializer>.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

