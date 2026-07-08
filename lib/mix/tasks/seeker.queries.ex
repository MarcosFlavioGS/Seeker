defmodule Mix.Tasks.Seeker.Queries do
  @shortdoc "Lists saved queries for an organization as JSON"
  @moduledoc """
  Prints the saved queries for an organization as JSON.

      mix seeker.queries --org just_travel

  Each entry has `context`, `key`, `name`, and `sql`. Use `key` with
  `mix seeker.query --key ...` to run one.
  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: [org: :string])

    case opts[:org] do
      nil ->
        Seeker.AgentCLI.fail("Missing required --org")

      org ->
        org
        |> Seeker.QueryStore.list_queries()
        |> Jason.encode!()
        |> Mix.shell().info()
    end
  end
end
