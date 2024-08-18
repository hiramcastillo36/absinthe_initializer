defmodule Mix.Tasks.AbsintheInitializer do
  use Mix.Task

  alias AbsintheInitializer

  @shortdoc "Initializes Absinthe in a Phoenix project"
  @moduledoc """
  This task initializes Absinthe in a Phoenix project.
  """

  @impl Mix.Task
  def run(args) do
    Mix.shell().info("Starting Absinthe setup...")

    if(args == ["--auth"]) do
      AbsintheInitializer.setup(true)
    else
      AbsintheInitializer.setup()
    end

    Mix.shell().info("Absinthe setup complete.")
  end
end
