defmodule Seeker.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SeekerWeb.Telemetry,
      # Just Travel repos — DBConnection retries in the background if VPN is down at startup
      Seeker.JustTravel.ProdRepo,
      Seeker.JustTravel.HomoRepo,
      # Add new org repos here:
      # Seeker.Acme.ProdRepo,
      # Seeker.Acme.HomoRepo,
      {DNSCluster, query: Application.get_env(:seeker, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Seeker.PubSub},
      # Must start after PubSub and all repos
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
