# Adding a New Organization

This guide walks through adding a second organization — say, "Acme Corp" — with production and homologation environments.

The change touches six files. None of the existing LiveView, router, or template code needs to change.

---

## Step 1 — Add credentials to `.env`

```dotenv
# Acme Corp — Production
ACME_PROD_DB_HOST=db.acme.com
ACME_PROD_DB_PORT=5432
ACME_PROD_DB_USER=your_user
ACME_PROD_DB_PASS=your_password
ACME_PROD_DB_NAME=acme_production

# Acme Corp — Homologation
ACME_HOMO_DB_HOST=db-staging.acme.com
ACME_HOMO_DB_PORT=5432
ACME_HOMO_DB_USER=your_user
ACME_HOMO_DB_PASS=your_password
ACME_HOMO_DB_NAME=acme_staging

ACME_DB_SSL_MODE=verify_none
```

Also add the same variables (with empty values) to `.env.example` so the template stays up to date.

---

## Step 2 — Create the Repo modules

```elixir
# lib/seeker/organizations/acme/prod_repo.ex
defmodule Seeker.Acme.ProdRepo do
  use Ecto.Repo,
    otp_app: :seeker,
    adapter: Ecto.Adapters.Postgres
end
```

```elixir
# lib/seeker/organizations/acme/homo_repo.ex
defmodule Seeker.Acme.HomoRepo do
  use Ecto.Repo,
    otp_app: :seeker,
    adapter: Ecto.Adapters.Postgres
end
```

---

## Step 3 — Create the Queries module

```elixir
# lib/seeker/organizations/acme/queries.ex
defmodule Seeker.Acme.Queries do
  alias Seeker.QueryResult
  # alias Seeker.Acme.Contexts.SomeContext

  @general_queries [
    %{
      context: "General",
      key: :acme_table_list,
      name: "List All Tables",
      sql: """
      SELECT table_schema, table_name
      FROM information_schema.tables
      WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
      ORDER BY table_schema, table_name
      """
    }
  ]

  def list_queries do
    @general_queries
    |> Enum.map(&Map.update!(&1, :sql, fn s -> String.trim(s) end))
  end

  def get_sql(key) when is_atom(key) do
    case Enum.find(list_queries(), fn q -> q.key == key end) do
      %{sql: sql} -> {:ok, sql}
      nil -> {:error, "Unknown query: #{key}"}
    end
  end

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
```

---

## Step 4 — Add runtime config

In `config/runtime.exs`, add a block below the Just Travel section:

```elixir
# ── Acme Corp ────────────────────────────────────────────────────────────────

acme_ssl_opts =
  case env!("ACME_DB_SSL_MODE", :string, "verify_none") do
    "verify_peer" ->
      cacert = env!("ACME_DB_SSL_CACERT", :string, "/etc/ssl/certs/ca-certificates.crt")
      [verify: :verify_peer, cacertfile: cacert]
    _ ->
      [verify: :verify_none]
  end

config :seeker, Seeker.Acme.ProdRepo,
  hostname: env!("ACME_PROD_DB_HOST", :string, nil),
  port:     env!("ACME_PROD_DB_PORT", :integer, 5432),
  username: env!("ACME_PROD_DB_USER", :string, nil),
  password: env!("ACME_PROD_DB_PASS", :string, nil),
  database: env!("ACME_PROD_DB_NAME", :string, nil),
  ssl:      acme_ssl_opts,
  pool_size: 2,
  connect_timeout: 10_000,
  log: false

config :seeker, Seeker.Acme.HomoRepo,
  hostname: env!("ACME_HOMO_DB_HOST", :string, nil),
  port:     env!("ACME_HOMO_DB_PORT", :integer, 5432),
  username: env!("ACME_HOMO_DB_USER", :string, nil),
  password: env!("ACME_HOMO_DB_PASS", :string, nil),
  database: env!("ACME_HOMO_DB_NAME", :string, nil),
  ssl:      acme_ssl_opts,
  pool_size: 2,
  connect_timeout: 10_000,
  log: false
```

---

## Step 5 — Register in `RepoRegistry`

In `lib/seeker/repo_registry.ex`, add an entry to `@registry`:

```elixir
@registry %{
  just_travel: %{ ... },   # existing

  acme: %{
    display: "Acme Corp",
    environments: %{
      prod: %{display: "Production",    repo: Seeker.Acme.ProdRepo, queries_module: Seeker.Acme.Queries},
      homo: %{display: "Homologation",  repo: Seeker.Acme.HomoRepo, queries_module: Seeker.Acme.Queries}
    }
  }
}
```

---

## Step 6 — Add repos to the supervision tree

In `lib/seeker/application.ex`:

```elixir
children = [
  SeekerWeb.Telemetry,
  Seeker.JustTravel.ProdRepo,
  Seeker.JustTravel.HomoRepo,
  Seeker.Acme.ProdRepo,      # ← add
  Seeker.Acme.HomoRepo,      # ← add
  ...
]
```

And in `lib/seeker/connection_monitor.ex`, the monitor reads repos dynamically from `RepoRegistry.all_repos/0`, so **no change is needed there**.

---

## Step 7 — Restart

```bash
mix phx.server
```

Navigate to [http://localhost:4000/orgs/acme/prod](http://localhost:4000/orgs/acme/prod). The new organization appears with its own connection badges and query sidebar.

---

## Adding query contexts for the new org

Follow the same pattern as Just Travel:

```
lib/seeker/organizations/acme/contexts/billing.ex
```

Register it in `lib/seeker/organizations/acme/queries.ex`. See [queries.md](queries.md) for the full pattern.
