defmodule Seeker.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    orgs = Seeker.LocalConfig.load_orgs()
    Seeker.OrgRegistry.setup(orgs)

    repo_children =
      for {slug, org} <- orgs,
          {env_key, env_config} <- org.environments do
        Supervisor.child_spec(
          {Seeker.DynamicRepo, env_config.db_opts},
          id: :"seeker_repo_#{slug}_#{env_key}"
        )
      end

    children =
      [SeekerWeb.Telemetry] ++
        repo_children ++
        [
          {DNSCluster, query: Application.get_env(:seeker, :dns_cluster_query) || :ignore},
          {Phoenix.PubSub, name: Seeker.PubSub},
          # Must start after PubSub and all repos
          Seeker.QueryStore,
          Seeker.ConnectionMonitor,
          SeekerWeb.Endpoint
        ]

    opts = [strategy: :one_for_one, name: Seeker.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    SeekerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
