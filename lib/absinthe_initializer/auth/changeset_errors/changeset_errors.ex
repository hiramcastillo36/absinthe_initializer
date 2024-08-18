defmodule AbsintheInitializer.Auth.ChangesetErrors do
  def generate_file(project_capitalized) do
    changeset_errors_content = """
      defmodule #{project_capitalized}Web.Schema.ChangesetErrors do
        @doc \"\"\"
        Traverses the changeset errors and returns a map of
        error messages. For example:
        %{start_date: ["can't be blank"], end_date: ["can't be blank"]}
        \"\"\"

        def error_details(changeset) do
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
              String.replace(acc, "%{\#{key}}", _to_string(value))
            end)
          end)
        end

        defp _to_string(val) when is_list(val) do
          [ last | base_list ]  = Enum.reverse(val)

          base_str  = base_list
          |> Enum.reverse()
          |> Enum.join(", ")

          "\#{ base_str }, and \#{ last }"
        end

        defp _to_string(val), do: to_string(val)
      end
    """
    project_name = String.downcase(project_capitalized)
    File.write("lib/#{project_name}_web/schema/changeset_errors.ex", changeset_errors_content)
  end
end
