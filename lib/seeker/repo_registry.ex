defmodule Seeker.RepoRegistry do
  @registry %{
    just_travel: %{
      display: "Just Travel",
      environments: %{
        prod: %{
          display: "Production",
          repo: Seeker.JustTravel.ProdRepo,
          queries_module: Seeker.JustTravel.Queries
        },
        homo: %{
          display: "Homologation",
          repo: Seeker.JustTravel.HomoRepo,
          queries_module: Seeker.JustTravel.Queries
        }
      }
    }
    # Add new organizations here:
    # acme: %{
    #   display: "Acme Corp",
    #   environments: %{
    #     prod: %{display: "Production", repo: Seeker.Acme.ProdRepo, queries_module: Seeker.Acme.Queries},
    #     homo: %{display: "Staging",    repo: Seeker.Acme.HomoRepo, queries_module: Seeker.Acme.Queries}
    #   }
    # }
  }

  def all, do: @registry

  def get(org, env) when is_atom(org) and is_atom(env) do
    get_in(@registry, [org, :environments, env])
  end

  def get_org(org) when is_atom(org), do: Map.get(@registry, org)

  def all_repos do
    for {_org, %{environments: envs}} <- @registry,
        {_env, %{repo: repo}} <- envs,
        do: repo
  end
end
