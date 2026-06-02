defmodule Seeker.JustTravel.Queries do
  @moduledoc """
  Aggregates all Just Travel query contexts.

  To add a new context (e.g. "Hotels"), create:
    lib/seeker/organizations/just_travel/contexts/hotels.ex

  Then add it to the list in list_queries/0 below.
  """

  alias Seeker.QueryResult
  alias Seeker.JustTravel.Contexts.{Insurances, Mobility}

  @general_queries [
    %{
      context: "General",
      key: :table_list,
      name: "List All Tables",
      sql: """
      SELECT table_schema, table_name
      FROM information_schema.tables
      WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
      ORDER BY table_schema, table_name
      """
    },
    %{
      context: "General",
      key: :db_size,
      name: "Database Size",
      sql: """
      SELECT
        pg_database.datname AS database,
        pg_size_pretty(pg_database_size(pg_database.datname)) AS size
      FROM pg_database
      WHERE datname = current_database()
      """
    }
  ]

  @doc "Returns all queries from all contexts, in order."
  def list_queries do
    (@general_queries ++ Mobility.list_queries() ++ Insurances.list_queries())
    |> Enum.map(&Map.update!(&1, :sql, fn s -> String.trim(s) end))
  end

  @doc "Returns the SQL string for a named query key."
  def get_sql(key) when is_atom(key) do
    case Enum.find(list_queries(), fn q -> q.key == key end) do
      %{sql: sql} -> {:ok, sql}
      nil -> {:error, "Unknown query: #{key}"}
    end
  end

  @doc "Runs ad-hoc SQL against the given Ecto.Repo module."
  def run_sql(repo, sql) when is_binary(sql) do
    start = System.monotonic_time(:millisecond)

    case Ecto.Adapters.SQL.query(repo, sql, [], timeout: 30_000) do
      {:ok, result} ->
        {:ok,
         %QueryResult{
           columns: result.columns,
           rows: result.rows,
           num_rows: result.num_rows,
           duration_ms: System.monotonic_time(:millisecond) - start
         }}

      {:error, %DBConnection.ConnectionError{} = e} ->
        {:error, {:connection, "Cannot reach database — is the VPN connected? (#{e.message})"}}

      {:error, %Postgrex.Error{} = e} ->
        {:error, {:db_error, Exception.message(e)}}

      {:error, reason} ->
        {:error, {:unknown, inspect(reason)}}
    end
  end
end
