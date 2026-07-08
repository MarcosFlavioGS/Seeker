defmodule Mix.Tasks.Seeker.Query do
  @shortdoc "Runs a SQL query against an org/environment and prints the result as JSON"
  @moduledoc """
  Runs a SQL query (raw or saved) against a configured organization/environment
  and prints the result on stdout.

      mix seeker.query --org just_travel --env prod --sql "SELECT id FROM orders LIMIT 1"
      mix seeker.query --org just_travel --env prod --key find_order_by_email --param email=a@b.com

  Options:

    * `--org`         organization slug (required, see `mix seeker.orgs`)
    * `--env`         environment key, e.g. `prod`/`homo` (required)
    * `--sql`         raw SQL to run
    * `--key`         key of a saved query (see `mix seeker.queries --org ...`)
    * `--param`       `name=value`, substitutes `:name` placeholders in the SQL. Repeatable.
    * `--allow-write` required to run anything other than SELECT/WITH/EXPLAIN/SHOW
    * `--format`      `json` (default) or `table`

  Exactly one of `--sql` or `--key` must be given.

  On success, prints `{"columns": [...], "rows": [...], "num_rows": N, "duration_ms": N}`
  to stdout. On failure, prints `{"error": "..."}` to stderr and exits with status 1.
  """

  use Mix.Task

  alias Seeker.{AgentCLI, QueryStore}

  @requirements ["app.start"]

  @switches [
    org: :string,
    env: :string,
    sql: :string,
    key: :string,
    param: :keep,
    allow_write: :boolean,
    format: :string
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches)

    with {:ok, org} <- require_opt(opts, :org),
         {:ok, env} <- require_opt(opts, :env),
         {:ok, repo} <- AgentCLI.fetch_repo(org, env),
         {:ok, sql} <- fetch_sql(org, opts) do
      sql = AgentCLI.substitute_params(sql, params(opts))

      case AgentCLI.check_writable(sql, opts[:allow_write] || false) do
        :ok ->
          case Seeker.SQLRunner.run_sql(repo, sql) do
            {:ok, result} -> AgentCLI.print_result(result, opts[:format] || "json")
            {:error, {_kind, message}} -> AgentCLI.fail(message)
          end

        {:error, message} ->
          AgentCLI.fail(message)
      end
    else
      {:error, message} -> AgentCLI.fail(message)
    end
  end

  defp require_opt(opts, key) do
    case Keyword.get(opts, key) do
      nil -> {:error, "Missing required --#{key}"}
      value -> {:ok, value}
    end
  end

  defp fetch_sql(_org, opts) do
    case {opts[:sql], opts[:key]} do
      {sql, nil} when is_binary(sql) and sql != "" -> {:ok, sql}
      {nil, key} when is_binary(key) and key != "" -> fetch_saved_sql(opts[:org], key)
      {nil, nil} -> {:error, "Provide either --sql or --key"}
      {_sql, _key} -> {:error, "Provide only one of --sql or --key"}
    end
  end

  defp fetch_saved_sql(org, key), do: QueryStore.get_sql(org, key)

  defp params(opts) do
    opts
    |> Keyword.get_values(:param)
    |> Enum.map(fn kv ->
      case String.split(kv, "=", parts: 2) do
        [name, value] -> {name, value}
        _ -> Mix.raise("Invalid --param #{inspect(kv)}, expected name=value")
      end
    end)
  end
end
