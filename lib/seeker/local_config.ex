defmodule Seeker.LocalConfig do
  @moduledoc """
  Reads organization and query definitions from `priv/local/`.

  Organization files: `priv/local/organizations/<slug>.json`
  Query files:        `priv/local/queries/<slug>.json`

  Values in organization files can be literal strings/integers or
  `"$ENV_VAR_NAME"` references, which are resolved via System.get_env/1.
  """

  require Logger

  @local_dir "priv/local"

  def orgs_path, do: Path.join(@local_dir, "organizations")
  def queries_path(org_slug), do: Path.join([@local_dir, "queries", "#{org_slug}.json"])

  @doc "Loads all organizations from `priv/local/organizations/`. Returns a map keyed by slug string."
  def load_orgs do
    path = orgs_path()

    unless File.dir?(path) do
      Logger.warning(
        "Seeker: no organizations directory at #{path}. Create #{path}/<slug>.json to add organizations."
      )

      %{}
    else
      path
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Map.new(fn filename ->
        slug = Path.rootname(filename)
        org_path = Path.join(path, filename)

        case Jason.decode(File.read!(org_path)) do
          {:ok, raw} ->
            {slug, parse_org(slug, raw)}

          {:error, reason} ->
            Logger.error("Seeker: failed to parse #{org_path}: #{inspect(reason)}")
            {slug, nil}
        end
      end)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()
    end
  end

  @doc "Loads queries for an org from `priv/local/queries/<slug>.json`. Returns a list of query maps."
  def load_queries(org_slug) do
    path = queries_path(org_slug)

    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, list} when is_list(list) ->
            Enum.map(list, fn q ->
              %{
                context: q["context"] || "General",
                key: q["key"],
                name: q["name"],
                sql: String.trim(q["sql"] || "")
              }
            end)

          {:error, reason} ->
            Logger.error("Seeker: failed to parse queries at #{path}: #{inspect(reason)}")
            []
        end

      {:error, :enoent} ->
        []

      {:error, reason} ->
        Logger.error("Seeker: failed to read #{path}: #{inspect(reason)}")
        []
    end
  end

  @doc "Persists queries for an org to `priv/local/queries/<slug>.json`."
  def save_queries(org_slug, queries) do
    path = queries_path(org_slug)
    File.mkdir_p!(Path.dirname(path))

    json =
      queries
      |> Enum.map(fn q ->
        %{"context" => q.context, "key" => q.key, "name" => q.name, "sql" => q.sql}
      end)
      |> Jason.encode!(pretty: true)

    File.write!(path, json)
  end

  # ── Private ──────────────────────────────────────────────────────────────────

  defp parse_org(slug, raw) do
    environments =
      (raw["environments"] || %{})
      |> Map.new(fn {env_key, env_raw} ->
        repo_name = :"seeker_repo_#{slug}_#{env_key}"

        db_opts = [
          name: repo_name,
          hostname: resolve(env_raw["hostname"]),
          port: resolve_int(env_raw["port"], 5432),
          username: resolve(env_raw["username"]),
          password: resolve(env_raw["password"]),
          database: resolve(env_raw["database"]),
          ssl: build_ssl(env_raw),
          pool_size: 2,
          connect_timeout: 10_000,
          log: false
        ]

        {env_key, %{display: env_raw["display"] || env_key, repo: repo_name, db_opts: db_opts}}
      end)

    %{display: raw["display"] || slug, environments: environments}
  end

  defp resolve(nil), do: nil
  defp resolve("$" <> var_name), do: System.get_env(var_name)
  defp resolve(value), do: value

  defp resolve_int(nil, default), do: default

  defp resolve_int("$" <> var_name, default) do
    case System.get_env(var_name) do
      nil -> default
      val -> String.to_integer(val)
    end
  end

  defp resolve_int(value, _default) when is_integer(value), do: value
  defp resolve_int(value, _default) when is_binary(value), do: String.to_integer(value)

  defp build_ssl(env_raw) do
    mode = resolve(env_raw["ssl_mode"]) || "verify_none"

    if mode == "verify_peer" do
      cacert =
        resolve(env_raw["ssl_cacert"]) ||
          "/etc/ssl/certs/ca-certificates.crt"

      [verify: :verify_peer, cacertfile: cacert]
    else
      [verify: :verify_none]
    end
  end
end
