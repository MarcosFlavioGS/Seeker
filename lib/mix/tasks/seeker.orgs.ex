defmodule Mix.Tasks.Seeker.Orgs do
  @shortdoc "Lists configured organizations and environments as JSON"
  @moduledoc """
  Prints all configured organizations and their environments as JSON.

      mix seeker.orgs

  Output shape:

      [{"slug": "just_travel", "display": "Just Travel",
        "environments": [{"key": "prod", "display": "Production"}, ...]}]
  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(_args) do
    payload =
      Seeker.OrgRegistry.all()
      |> Enum.map(fn {slug, org} ->
        %{
          slug: slug,
          display: org.display,
          environments:
            Enum.map(org.environments, fn {env_key, env} ->
              %{key: env_key, display: env.display}
            end)
        }
      end)

    Mix.shell().info(Jason.encode!(payload))
  end
end
