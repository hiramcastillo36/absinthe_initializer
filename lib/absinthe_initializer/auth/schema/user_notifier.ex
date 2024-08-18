defmodule AbsintheInitializer.Auth.Schema.UserNotifier do
  def generate_user_notifier(project_capitalized) do
    user_notifier_content = """
      defmodule #{project_capitalized}.Accounts.UserNotifier do
        import Swoosh.Email

        alias #{project_capitalized}.Mailer

        # Delivers the email using the application mailer.
        defp deliver(recipient, subject, body) do
          email =
            new()
            |> to(recipient)
            |> from({"#{project_capitalized}", "contact@example.com"})
            |> subject(subject)
            |> text_body(body)

          with {:ok, _metadata} <- Mailer.deliver(email) do
            {:ok, email}
          end
        end
      end
    """

    project_name = String.downcase(project_capitalized)
    File.write("lib/#{project_name}/accounts/user_notifier.ex", user_notifier_content)
  end
end
