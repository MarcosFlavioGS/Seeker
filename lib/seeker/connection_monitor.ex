defmodule Seeker.ConnectionMonitor do
  @moduledoc """
  Periodically pings all registered repos and broadcasts their
  connection status via PubSub so LiveViews can show live badges.
  """

  use GenServer

  alias Seeker.RepoRegistry

  @check_interval 30_000
  @ping_timeout 5_000

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @doc "Returns the current connection status for a repo: :connected | {:error, atom}"
  def status(repo), do: GenServer.call(__MODULE__, {:status, repo})

  @doc "Forces an immediate re-check of all repos."
  def check_now, do: send(__MODULE__, :check)

  # ── GenServer callbacks ────────────────────────────────────────────────────

  @impl true
  def init(_) do
    state = Map.new(RepoRegistry.all_repos(), fn repo -> {repo, :unknown} end)
    send(self(), :check)
    {:ok, state}
  end

  @impl true
  def handle_info(:check, state) do
    new_state =
      Map.new(state, fn {repo, _prev} ->
        status = ping(repo)
        Phoenix.PubSub.broadcast(Seeker.PubSub, "conn_status", {:conn_status, repo, status})
        {repo, status}
      end)

    Process.send_after(self(), :check, @check_interval)
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:status, repo}, _from, state) do
    {:reply, Map.get(state, repo, :unknown), state}
  end

  # ── Private ────────────────────────────────────────────────────────────────

  defp ping(repo) do
    case Ecto.Adapters.SQL.query(repo, "SELECT 1", [], timeout: @ping_timeout) do
      {:ok, _} -> :connected
      {:error, reason} -> {:error, classify(reason)}
    end
  rescue
    _ -> {:error, :unknown}
  end

  defp classify(%DBConnection.ConnectionError{}), do: :vpn_down
  defp classify(%Postgrex.Error{postgres: %{code: :invalid_authorization_specification}}), do: :bad_credentials
  defp classify(_), do: :unknown
end
