defmodule Seeker.SQLRunner do
  @moduledoc """
  Executes raw SQL against a named DynamicRepo instance.

  The `repo` argument is an atom process name (e.g. `:"seeker_repo_just_travel_prod"`).
  `put_dynamic_repo/1` is safe here because each call runs in its own process
  (via `start_async/3` in the LiveView).
  """

  alias Seeker.{DynamicRepo, QueryResult}

  def run_sql(repo, sql) when is_atom(repo) and is_binary(sql) do
    DynamicRepo.put_dynamic_repo(repo)
    start = System.monotonic_time(:millisecond)

    try do
      case DynamicRepo.query(sql, [], timeout: 30_000) do
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
    rescue
      _ ->
        {:error, {:unknown, "Unexpected error during query execution"}}
    catch
      :exit, _ ->
        {:error, {:connection, "Cannot reach database — is the VPN connected?"}}
    end
  end
end
