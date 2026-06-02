defmodule SeekerWeb.QueryLive do
  use SeekerWeb, :live_view

  alias Seeker.{ConnectionMonitor, OrgRegistry, QueryResult, QueryStore, SQLRunner}

  @impl true
  def mount(%{"org" => org, "env" => env}, _session, socket) do
    org_info = OrgRegistry.get_org(org)
    entry = OrgRegistry.get(org, env)

    if is_nil(entry) do
      {:ok, push_navigate(socket, to: ~p"/")}
    else
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Seeker.PubSub, "conn_status")
        QueryStore.subscribe(org)
      end

      socket =
        socket
        |> assign(:org, org)
        |> assign(:env, env)
        |> assign(:org_info, org_info)
        |> assign(:entry, entry)
        |> assign(:grouped_queries, group_queries(QueryStore.list_queries(org)))
        |> assign(:sql, "")
        |> assign(:active_query_key, nil)
        |> assign(:result, nil)
        |> assign(:running, false)
        |> assign(:copied, false)
        |> assign(:conn_statuses, build_conn_statuses(org))
        |> assign(:page_title, "#{org_info.display} · Seeker")
        |> assign(:show_form, false)
        |> assign(:form_query, %{})
        |> assign(:editing_key, nil)

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(%{"org" => org, "env" => env}, _uri, socket) do
    entry = OrgRegistry.get(org, env)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:env, env)
      |> assign(:entry, entry)
      |> assign(:grouped_queries, group_queries(QueryStore.list_queries(org)))
      |> assign(:result, nil)
      |> assign(:running, false)
      |> assign(:copied, false)

    {:noreply, socket}
  end

  # ── Query sidebar events ───────────────────────────────────────────────────

  @impl true
  def handle_event("load_query", %{"key" => key}, socket) do
    case QueryStore.get_sql(socket.assigns.org, key) do
      {:ok, sql} -> {:noreply, assign(socket, sql: sql, active_query_key: key, result: nil)}
      {:error, _} -> {:noreply, socket}
    end
  end

  def handle_event("run_query", %{"sql" => sql}, socket) do
    sql = String.trim(sql)

    if sql == "" do
      {:noreply, socket}
    else
      socket = assign(socket, running: true, copied: false)
      repo = socket.assigns.entry.repo

      {:noreply,
       start_async(socket, :run_query, fn ->
         SQLRunner.run_sql(repo, sql)
       end)}
    end
  end

  def handle_event("clear", _params, socket) do
    {:noreply, assign(socket, sql: "", result: nil, active_query_key: nil, copied: false)}
  end

  def handle_event("copy_json", _params, socket) do
    json = encode_result_as_json(socket.assigns.result)
    Process.send_after(self(), :clear_copied, 2000)

    {:noreply,
     socket
     |> assign(:copied, true)
     |> push_event("copy-to-clipboard", %{text: json})}
  end

  # ── Query form events ──────────────────────────────────────────────────────

  def handle_event("open_new_query", _params, socket) do
    {:noreply, assign(socket, show_form: true, form_query: %{}, editing_key: nil)}
  end

  def handle_event("edit_query", %{"key" => key}, socket) do
    queries = QueryStore.list_queries(socket.assigns.org)

    case Enum.find(queries, fn q -> q.key == key end) do
      nil ->
        {:noreply, socket}

      query ->
        form_query = %{
          "context" => query.context,
          "name" => query.name,
          "sql" => query.sql
        }

        {:noreply, assign(socket, show_form: true, form_query: form_query, editing_key: key)}
    end
  end

  def handle_event("close_query_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, form_query: %{}, editing_key: nil)}
  end

  def handle_event("save_query", params, socket) do
    org = socket.assigns.org

    result =
      case socket.assigns.editing_key do
        nil -> QueryStore.create(org, params)
        key -> QueryStore.update(org, key, params)
      end

    case result do
      {:ok, _} ->
        {:noreply, assign(socket, show_form: false, form_query: %{}, editing_key: nil)}

      :ok ->
        {:noreply, assign(socket, show_form: false, form_query: %{}, editing_key: nil)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  def handle_event("delete_query", %{"key" => key}, socket) do
    QueryStore.delete(socket.assigns.org, key)

    socket =
      if socket.assigns.active_query_key == key do
        assign(socket, sql: "", active_query_key: nil, result: nil)
      else
        socket
      end

    {:noreply, socket}
  end

  # ── Async & PubSub ─────────────────────────────────────────────────────────

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
  def handle_info({:queries_updated, org_slug}, socket) do
    queries = QueryStore.list_queries(org_slug)
    {:noreply, assign(socket, grouped_queries: group_queries(queries))}
  end

  def handle_info({:conn_status, repo, status}, socket) do
    updated =
      Enum.reduce(
        socket.assigns.org_info.environments,
        socket.assigns.conn_statuses,
        fn {env_key, env_data}, acc ->
          if env_data.repo == repo, do: Map.put(acc, env_key, status), else: acc
        end
      )

    {:noreply, assign(socket, :conn_statuses, updated)}
  end

  def handle_info(:clear_copied, socket) do
    {:noreply, assign(socket, :copied, false)}
  end

  # ── Private ────────────────────────────────────────────────────────────────

  defp group_queries(queries) do
    queries
    |> Enum.group_by(& &1.context)
    |> Enum.sort_by(fn {context, _} -> context end)
  end

  defp build_conn_statuses(org) do
    org_info = OrgRegistry.get_org(org)

    Map.new(org_info.environments, fn {env_key, env_data} ->
      {env_key, ConnectionMonitor.status(env_data.repo)}
    end)
  end

  defp encode_result_as_json({:ok, %QueryResult{columns: cols, rows: rows}}) do
    rows
    |> Enum.map(fn row ->
      cols
      |> Enum.zip(row)
      |> Map.new(fn {col, val} -> {col, prepare_for_json(val)} end)
    end)
    |> Jason.encode!(pretty: true)
  end

  defp encode_result_as_json(_), do: "[]"

  defp prepare_for_json(nil), do: nil
  defp prepare_for_json(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp prepare_for_json(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)
  defp prepare_for_json(%Date{} = d), do: Date.to_iso8601(d)
  defp prepare_for_json(%Decimal{} = d), do: Decimal.to_string(d)
  defp prepare_for_json(val), do: val

  # ── Template helpers ───────────────────────────────────────────────────────

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
