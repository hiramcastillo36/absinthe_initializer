defmodule Mix.Tasks.AbsintheInitializer do
  use Mix.Task

  alias AbsintheInitializer

  @shortdoc "Initializes Absinthe in a Phoenix project"
  @moduledoc """
  This task initializes Absinthe in a Phoenix project.
  """

  @impl Mix.Task
  def run(_) do
    Mix.shell().info("Starting Absinthe setup...")

    AbsintheInitializer.setup()

    Mix.shell().info("Absinthe setup complete.")
  end
end
