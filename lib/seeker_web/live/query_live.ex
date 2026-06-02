defmodule SeekerWeb.QueryLive do
  use SeekerWeb, :live_view

  alias Seeker.{ConnectionMonitor, QueryResult, RepoRegistry}

  @impl true
  def mount(%{"org" => org_str, "env" => env_str}, _session, socket) do
    org = String.to_existing_atom(org_str)
    env = String.to_existing_atom(env_str)

    org_info = RepoRegistry.get_org(org)
    entry = RepoRegistry.get(org, env)

    if is_nil(entry) do
      {:ok, push_navigate(socket, to: ~p"/orgs/just_travel/prod")}
    else
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Seeker.PubSub, "conn_status")
      end

      conn_statuses = build_conn_statuses(org)

      socket =
        socket
        |> assign(:org, org)
        |> assign(:env, env)
        |> assign(:org_info, org_info)
        |> assign(:entry, entry)
        |> assign(:grouped_queries, group_queries(entry.queries_module.list_queries()))
        |> assign(:sql, "")
        |> assign(:active_query_key, nil)
        |> assign(:result, nil)
        |> assign(:running, false)
        |> assign(:conn_statuses, conn_statuses)
        |> assign(:page_title, "#{org_info.display} · Seeker")

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(%{"org" => org_str, "env" => env_str}, _uri, socket) do
    org = String.to_existing_atom(org_str)
    env = String.to_existing_atom(env_str)
    entry = RepoRegistry.get(org, env)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:env, env)
      |> assign(:entry, entry)
      |> assign(:grouped_queries, group_queries(entry.queries_module.list_queries()))
      |> assign(:result, nil)
      |> assign(:running, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("load_query", %{"key" => key_str}, socket) do
    key = String.to_existing_atom(key_str)

    case socket.assigns.entry.queries_module.get_sql(key) do
      {:ok, sql} ->
        {:noreply, assign(socket, sql: sql, active_query_key: key, result: nil)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("run_query", %{"sql" => sql}, socket) do
    sql = String.trim(sql)

    if sql == "" do
      {:noreply, socket}
    else
      socket = assign(socket, :running, true)
      %{queries_module: qmod, repo: repo} = socket.assigns.entry

      {:noreply,
       start_async(socket, :run_query, fn ->
         qmod.run_sql(repo, sql)
       end)}
    end
  end

  def handle_event("clear", _params, socket) do
    {:noreply, assign(socket, sql: "", result: nil, active_query_key: nil)}
  end

  @impl true
  def handle_async(:run_query, {:ok, result}, socket) do
    {:noreply, assign(socket, running: false, result: result)}
  end

  def handle_async(:run_query, {:exit, reason}, socket) do
    {:noreply,
     assign(socket,
       running: false,
       result: {:error, {:unknown, "Query process crashed: #{inspect(reason)}"}}
     )}
  end

  @impl true
  def handle_info({:conn_status, repo, status}, socket) do
    org_envs = socket.assigns.org_info.environments

    updated =
      Enum.reduce(org_envs, socket.assigns.conn_statuses, fn {env_key, env_data}, acc ->
        if env_data.repo == repo, do: Map.put(acc, env_key, status), else: acc
      end)

    {:noreply, assign(socket, :conn_statuses, updated)}
  end

  # ── Private helpers ────────────────────────────────────────────────────────

  defp group_queries(queries) do
    queries
    |> Enum.group_by(& &1.context)
    |> Enum.sort_by(fn {context, _} -> context end)
  end

  defp build_conn_statuses(org) do
    org_info = RepoRegistry.get_org(org)

    Map.new(org_info.environments, fn {env_key, env_data} ->
      {env_key, ConnectionMonitor.status(env_data.repo)}
    end)
  end

  # ── Component helpers (used in template) ──────────────────────────────────

  def conn_badge_class(:connected), do: "badge-success"
  def conn_badge_class({:error, :vpn_down}), do: "badge-error"
  def conn_badge_class({:error, :bad_credentials}), do: "badge-warning"
  def conn_badge_class(_), do: "badge-ghost"

  def conn_badge_text(:connected), do: "Connected"
  def conn_badge_text({:error, :vpn_down}), do: "VPN down"
  def conn_badge_text({:error, :bad_credentials}), do: "Auth error"
  def conn_badge_text(:unknown), do: "Checking..."
  def conn_badge_text(_), do: "Unknown"

  def result_meta({:ok, %QueryResult{num_rows: n, duration_ms: ms}}) do
    "#{n} #{if n == 1, do: "row", else: "rows"} · #{ms}ms"
  end

  def result_meta(_), do: ""

  def error_kind_label(:connection), do: "Connection error"
  def error_kind_label(:db_error), do: "Database error"
  def error_kind_label(_), do: "Error"

  def format_cell(nil), do: "NULL"
  def format_cell([]), do: ""
  def format_cell(%DateTime{} = dt), do: DateTime.to_string(dt)
  def format_cell(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_string(ndt)
  def format_cell(%Date{} = d), do: Date.to_string(d)
  def format_cell(val) when is_list(val), do: Jason.encode!(val)
  def format_cell(val) when is_map(val), do: Jason.encode!(val)
  def format_cell(val), do: to_string(val)
end
