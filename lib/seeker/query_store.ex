defmodule Seeker.QueryStore do
  @moduledoc """
  GenServer that owns all query definitions for every organization.

  Queries are loaded from `priv/local/queries/<slug>.json` at startup and held
  in memory. Mutations (create/update/delete) persist to disk immediately and
  broadcast a `:queries_updated` message over PubSub so LiveViews refresh.

  Query keys are plain strings (e.g. `"find_order_by_email"`).
  """

  use GenServer

  alias Seeker.{LocalConfig, OrgRegistry}

  @pubsub Seeker.PubSub
  @topic_prefix "queries:"

  # ── Public API ───────────────────────────────────────────────────────────────

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def subscribe(org_slug),
    do: Phoenix.PubSub.subscribe(@pubsub, @topic_prefix <> org_slug)

  def list_queries(org_slug),
    do: GenServer.call(__MODULE__, {:list, org_slug})

  def get_sql(org_slug, key),
    do: GenServer.call(__MODULE__, {:get_sql, org_slug, key})

  def create(org_slug, attrs),
    do: GenServer.call(__MODULE__, {:create, org_slug, attrs})

  def update(org_slug, key, attrs),
    do: GenServer.call(__MODULE__, {:update, org_slug, key, attrs})

  def delete(org_slug, key),
    do: GenServer.call(__MODULE__, {:delete, org_slug, key})

  # ── GenServer callbacks ───────────────────────────────────────────────────────

  @impl true
  def init(_) do
    state =
      Map.new(OrgRegistry.all(), fn {slug, _} ->
        {slug, LocalConfig.load_queries(slug)}
      end)

    {:ok, state}
  end

  @impl true
  def handle_call({:list, org_slug}, _from, state) do
    {:reply, Map.get(state, org_slug, []), state}
  end

  def handle_call({:get_sql, org_slug, key}, _from, state) do
    result =
      state
      |> Map.get(org_slug, [])
      |> Enum.find(fn q -> q.key == key end)
      |> case do
        %{sql: sql} -> {:ok, sql}
        nil -> {:error, "Unknown query: #{key}"}
      end

    {:reply, result, state}
  end

  def handle_call({:create, org_slug, attrs}, _from, state) do
    queries = Map.get(state, org_slug, [])
    key = derive_key(attrs["key"], attrs["name"])

    if Enum.any?(queries, fn q -> q.key == key end) do
      {:reply, {:error, "A query with key \"#{key}\" already exists"}, state}
    else
      new_query = %{
        context: String.trim(attrs["context"] || "General"),
        key: key,
        name: String.trim(attrs["name"] || ""),
        sql: String.trim(attrs["sql"] || "")
      }

      new_queries = queries ++ [new_query]
      new_state = Map.put(state, org_slug, new_queries)
      persist_and_broadcast(org_slug, new_queries)
      {:reply, {:ok, new_query}, new_state}
    end
  end

  def handle_call({:update, org_slug, key, attrs}, _from, state) do
    queries = Map.get(state, org_slug, [])

    new_queries =
      Enum.map(queries, fn q ->
        if q.key == key do
          %{
            context: String.trim(attrs["context"] || q.context),
            key: q.key,
            name: String.trim(attrs["name"] || q.name),
            sql: String.trim(attrs["sql"] || q.sql)
          }
        else
          q
        end
      end)

    new_state = Map.put(state, org_slug, new_queries)
    persist_and_broadcast(org_slug, new_queries)
    {:reply, :ok, new_state}
  end

  def handle_call({:delete, org_slug, key}, _from, state) do
    queries = Map.get(state, org_slug, [])
    new_queries = Enum.reject(queries, fn q -> q.key == key end)
    new_state = Map.put(state, org_slug, new_queries)
    persist_and_broadcast(org_slug, new_queries)
    {:reply, :ok, new_state}
  end

  # ── Private ──────────────────────────────────────────────────────────────────

  defp persist_and_broadcast(org_slug, queries) do
    LocalConfig.save_queries(org_slug, queries)
    Phoenix.PubSub.broadcast(@pubsub, @topic_prefix <> org_slug, {:queries_updated, org_slug})
  end

  defp derive_key(key, _name) when is_binary(key) and key != "", do: slugify(key)
  defp derive_key(_key, name) when is_binary(name), do: slugify(name)
  defp derive_key(_key, _name), do: "query_#{System.unique_integer([:positive])}"

  defp slugify(str) do
    str
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end
end
