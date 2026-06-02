defmodule SeekerWeb.HomeLive do
  use SeekerWeb, :live_view

  alias Seeker.{ConnectionMonitor, RepoRegistry}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Seeker.PubSub, "conn_status")
    end

    {:ok,
     socket
     |> assign(:orgs, RepoRegistry.all())
     |> assign(:conn_statuses, build_all_statuses())
     |> assign(:page_title, "Seeker")}
  end

  @impl true
  def handle_info({:conn_status, repo, status}, socket) do
    {:noreply,
     assign(socket, :conn_statuses, Map.put(socket.assigns.conn_statuses, repo, status))}
  end

  defp build_all_statuses do
    Map.new(RepoRegistry.all_repos(), fn repo -> {repo, ConnectionMonitor.status(repo)} end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-[70vh] flex flex-col items-center justify-center p-8">
      <div class="mb-10 text-center">
        <h2 class="text-2xl font-bold mb-1">Organizations</h2>
        <p class="text-base-content/50 text-sm">Select a database to query</p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 w-full max-w-3xl">
        <div
          :for={{org_key, org_info} <- @orgs}
          class="card bg-base-200 shadow hover:shadow-md transition-shadow"
        >
          <div class="card-body p-6">
            <h2 class="card-title text-lg mb-4">{org_info.display}</h2>
            <div class="flex flex-col gap-2">
              <.link
                :for={{env_key, env_data} <- org_info.environments}
                navigate={~p"/orgs/#{org_key}/#{env_key}"}
                class="flex items-center justify-between btn btn-ghost btn-sm w-full normal-case"
              >
                <span>{env_data.display}</span>
                <span class={[
                  "badge badge-sm",
                  badge_class(Map.get(@conn_statuses, env_data.repo, :unknown))
                ]}>
                  {badge_text(Map.get(@conn_statuses, env_data.repo, :unknown))}
                </span>
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
