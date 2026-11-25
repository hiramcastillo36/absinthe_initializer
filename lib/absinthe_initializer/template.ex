defmodule AbsintheInitializer.Template do
  @moduledoc """
  Renders EEx templates bundled under `priv/templates/` and writes generated files.
  """

  @doc """
  Renders a template relative to `priv/templates/` with the given `assigns`.
  """
  def render(relative_path, assigns \\ []) do
    template_path = Path.join(templates_dir(), relative_path)
    EEx.eval_file(template_path, assigns: assigns)
  end

  @doc """
  Renders a template and writes the result to `target_path`, creating parent directories as needed.
  """
  def render_to_file(relative_path, target_path, assigns \\ []) do
    target_path |> Path.dirname() |> File.mkdir_p!()
    content = render(relative_path, assigns)
    File.write!(target_path, content)
  end

  defp templates_dir do
    Application.app_dir(:absinthe_initializer, "priv/templates")
  end
end
