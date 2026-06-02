# Architecture

## Overview

Seeker is a Phoenix 1.8 LiveView application. It has no local database of its own — every connection it manages points to a remote organization database. The app runs exclusively on `localhost` and is never deployed.

```
Browser ──LiveView WebSocket──▶ Phoenix App ──Ecto/Postgrex──▶ Remote PostgreSQL
                                     │
                                 .env file
                              (credentials)
```

## Layers

### 1. Configuration (`config/runtime.exs`)

All database credentials are loaded at startup from `.env` using [Dotenvy](https://hexdocs.pm/dotenvy). `runtime.exs` is evaluated after compilation and before the application starts, making it the correct place for secrets. Environment variables in the shell always override values in `.env`.

### 2. Organization repos (`lib/seeker/organizations/`)

Each organization (e.g. Just Travel) has its own subdirectory containing:

```
just_travel/
  prod_repo.ex    ← Ecto.Repo pointing to the production DB
  homo_repo.ex    ← Ecto.Repo pointing to the homologation DB
  queries.ex      ← aggregates all context modules; exposes run_sql/2
  contexts/
    mobility.ex   ← predefined queries for the Mobility team
    insurances.ex ← predefined queries for the Insurances team
```

Each `*_repo.ex` is a standard `Ecto.Repo` backed by `Ecto.Adapters.Postgres`. Queries are executed as raw SQL via `Ecto.Adapters.SQL.query/4` — no schemas, no changesets, no migrations.

Pool size is intentionally small (2 connections per repo) because Seeker is a single-user tool.

### 3. `RepoRegistry` (`lib/seeker/repo_registry.ex`)

A compile-time map that links URL-friendly names to the actual Elixir modules:

```elixir
%{
  just_travel: %{
    display: "Just Travel",
    environments: %{
      prod: %{repo: Seeker.JustTravel.ProdRepo, queries_module: Seeker.JustTravel.Queries},
      homo: %{repo: Seeker.JustTravel.HomoRepo, queries_module: Seeker.JustTravel.Queries}
    }
  }
}
```

The LiveView uses `RepoRegistry.get(org, env)` to resolve the correct repo and queries module from URL parameters without dynamic atom creation beyond `String.to_existing_atom/1`.

### 4. `ConnectionMonitor` (`lib/seeker/connection_monitor.ex`)

A `GenServer` that pings all registered repos with `SELECT 1` every 30 seconds. On each check it:

1. Runs the ping with a 5-second timeout
2. Classifies the result: `:connected`, `{:error, :vpn_down}`, `{:error, :bad_credentials}`, `{:error, :unknown}`
3. Broadcasts the new status via `Phoenix.PubSub` on the `"conn_status"` topic

This means the LiveView never polls — it just subscribes on mount and receives push updates.

### 5. `QueryLive` (`lib/seeker_web/live/query_live.ex`)

The single LiveView that powers the entire UI. Route: `/orgs/:org/:env`.

**Mount flow:**
1. Resolve `org` and `env` atoms from URL params using `String.to_existing_atom/1`
2. Look up the registry entry
3. Subscribe to `"conn_status"` PubSub topic
4. Build `grouped_queries` by grouping the query list by `:context`
5. Query the ConnectionMonitor for each env's current status

**Query execution:**
SQL runs inside `start_async/3` so a slow or hanging query does not block the LiveView process. Results arrive as `handle_async/3` callbacks.

**Error classification** (in `queries.ex`):

| Postgrex error | User-facing label |
|---|---|
| `DBConnection.ConnectionError` | Connection error — VPN likely down |
| `Postgrex.Error` | Database error — SQL problem |
| Other | Unknown error |

### 6. Supervision tree

```
Seeker.Supervisor (one_for_one)
  ├── SeekerWeb.Telemetry
  ├── Seeker.JustTravel.ProdRepo     ← DBConnection pool, auto-reconnects
  ├── Seeker.JustTravel.HomoRepo
  ├── DNSCluster
  ├── Phoenix.PubSub
  ├── Seeker.ConnectionMonitor       ← must start after PubSub and repos
  └── SeekerWeb.Endpoint
```

`DBConnection` (used internally by Postgrex) retries failed connections with exponential backoff. If the VPN is down at startup, the repos start but have no live connections — they reconnect automatically when the VPN comes up. The `ConnectionMonitor` reflects this in the UI.

## Data flow: running a query

```
User clicks "Run Query"
        │
        ▼
handle_event("run_query", %{"sql" => sql}, socket)
        │  assigns running: true
        │
        ▼
start_async(socket, :run_query, fn -> queries_module.run_sql(repo, sql) end)
        │  spawns a linked task
        │
        ▼
Ecto.Adapters.SQL.query(repo, sql, [], timeout: 30_000)
        │  runs in the async task
        │
        ▼
handle_async(:run_query, {:ok, result}, socket)
        │  assigns result: {:ok, %QueryResult{...}}
        │
        ▼
Template re-renders the results table
```

## Key design decisions

**Why Phoenix LiveView instead of plain Mix/IEx?**
Query results are tabular data. LiveView renders them as HTML tables, shows live connection badges, and lets you click predefined queries — none of which are possible in IEx.

**Why Ecto.Repo instead of raw Postgrex?**
`Ecto.Repo` wraps DBConnection, which handles connection pooling, retry/reconnect, and checkout timeouts. Raw `Postgrex.start_link` would require manual process management.

**Why `String.to_existing_atom/1` for URL params?**
`:org` and `:env` come from the URL. Using `String.to_atom/1` on untrusted input can exhaust the atom table. `to_existing_atom` only succeeds for atoms already defined in the registry, acting as implicit validation.

**Why no local database?**
Seeker queries remote databases; it has no data of its own to persist. Removing the local DB removes the need to run `mix ecto.create`, avoids accidental `mix ecto.migrate` runs, and simplifies setup.
