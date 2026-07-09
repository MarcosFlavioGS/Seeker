# Architecture

## Overview

Seeker is a Phoenix 1.8 LiveView application. It has no local database of its own — every connection it manages points to a remote organization database. The app runs exclusively on `localhost` and is never deployed.

```
Browser ──LiveView WebSocket──▶ Phoenix App ──Ecto/Postgrex──▶ Remote PostgreSQL
                                     │
                              priv/local/            .env
                           (org + query JSON)    (credentials)
```

## Layers

### 1. Local configuration (`priv/local/`)

All user-specific data lives in `priv/local/`, which is gitignored. There are two subdirectories:

- **`organizations/<slug>.json`** — defines an organization: display name, environment names, and database connection parameters. Values can be literal strings/integers or `"$ENV_VAR_NAME"` references that are resolved at startup.
- **`queries/<slug>.json`** — all queries for that organization, as a JSON array. This file is read at startup and written back whenever a query is created, edited, or deleted via the UI.

`priv/local.example/` (committed) contains reference files showing the expected format.

### 2. `LocalConfig` (`lib/seeker/local_config.ex`)

Pure functions that read and write `priv/local/`. Called once at application start to load organizations, and on every query mutation to persist changes.

- `load_orgs/0` — scans `organizations/*.json`, resolves `$VAR` references via `System.get_env/1`, returns a map keyed by slug string.
- `load_queries/1` — reads `queries/<slug>.json`, returns a list of query maps with atom keys.
- `save_queries/2` — serializes and writes the query list back to disk.

### 3. `OrgRegistry` (`lib/seeker/org_registry.ex`)

A thin wrapper around `:persistent_term`. Called once during `Application.start/2` with the map from `LocalConfig.load_orgs/0`, then read-only for the rest of the app's life. Keys are slug strings (e.g. `"acme"`); repo names are atoms (e.g. `:"seeker_repo_acme_prod"`).

### 4. `DynamicRepo` (`lib/seeker/dynamic_repo.ex`)

A single `Ecto.Repo` module started once per org/env combination with a unique process name:

```
Seeker.DynamicRepo (name: :"seeker_repo_acme_prod", hostname: "...", ...)
Seeker.DynamicRepo (name: :"seeker_repo_acme_staging", hostname: "...", ...)
```

All repo instances share one module (for adapter metadata) but run as separate processes with separate DBConnection pools. To target a specific instance, call `DynamicRepo.put_dynamic_repo(repo_name)` before querying — this sets process-local state that Ecto reads for the next call. Each query runs in its own process (via `start_async/3` or `spawn_monitor`), so concurrent queries never interfere.

### 5. `QueryStore` (`lib/seeker/query_store.ex`)

A `GenServer` that owns all query definitions in memory. It loads queries from disk on startup and updates the JSON file on every mutation. After any change it broadcasts `{:queries_updated, org_slug}` via PubSub so all connected LiveViews refresh their sidebars immediately without a page reload.

### 6. `SQLRunner` (`lib/seeker/sql_runner.ex`)

A single function `run_sql(repo_name, sql)` that sets the dynamic repo, executes the SQL, and normalizes the result into a `%QueryResult{}`. Errors are classified into `:connection`, `:db_error`, or `:unknown`.

### 7. `ConnectionMonitor` (`lib/seeker/connection_monitor.ex`)

A `GenServer` that pings all registered repos with `SELECT 1` every 30 seconds. On each check it:

1. Runs the ping in isolation (using `put_dynamic_repo` + a `try/rescue/catch` block to handle pool unavailability)
2. Classifies the result: `:connected`, `{:error, :vpn_down}`, `{:error, :bad_credentials}`, `{:error, :unknown}`
3. Broadcasts the new status via `Phoenix.PubSub` on the `"conn_status"` topic

This means the LiveView never polls — it subscribes on mount and receives push updates.

### 7b. `AgentCLI` and the `mix seeker.*` tasks (`lib/seeker/agent_cli.ex`, `lib/mix/tasks/seeker.*.ex`)

A non-LiveView entry point into the same `OrgRegistry` / `QueryStore` / `SQLRunner` layers, for agents (and humans) that want to run queries from a shell instead of the UI. `mix seeker.orgs` and `mix seeker.queries` expose discovery data as JSON; `mix seeker.query` runs a query and prints a JSON `%QueryResult{}` (or a JSON error on stderr with exit code 1). `AgentCLI` also enforces a `--allow-write` guard — SQL that isn't `SELECT`/`WITH`/`EXPLAIN`/`SHOW` is refused unless the flag is passed — since there's no human in the loop eyeballing the query before it runs. The `bin/seeker` wrapper resolves its own real path and `cd`s into the repo, so it can be symlinked onto `PATH` and invoked from anywhere. See `AGENTS.md` for the user-facing reference.

### 8. `QueryLive` (`lib/seeker_web/live/query_live.ex`)

The single LiveView that powers the entire UI. Route: `/orgs/:org/:env`.

**Mount flow:**
1. Look up org and env by string slug from `OrgRegistry`
2. Subscribe to `"conn_status"` and `"queries:<org>"` PubSub topics
3. Load grouped queries from `QueryStore`
4. Query `ConnectionMonitor` for each env's current status

**Query execution:**
SQL runs inside `start_async/3` so a slow or hanging query does not block the LiveView process. Results arrive as `handle_async/3` callbacks.

**Query CRUD:**
A modal form in the sidebar lets users create, edit, and delete queries. Events go to `QueryStore`, which persists the change and broadcasts `:queries_updated` — the LiveView receives this via PubSub and refreshes the sidebar without a full reload.

### 9. Supervision tree

```
Seeker.Supervisor (one_for_one)
  ├── SeekerWeb.Telemetry
  ├── Seeker.DynamicRepo (name: :seeker_repo_acme_prod)
  ├── Seeker.DynamicRepo (name: :seeker_repo_acme_staging)
  ├── ... (one entry per org/env loaded from priv/local/)
  ├── DNSCluster
  ├── Phoenix.PubSub
  ├── Seeker.QueryStore          ← must start after PubSub and OrgRegistry
  ├── Seeker.ConnectionMonitor   ← must start after PubSub and all repos
  └── SeekerWeb.Endpoint
```

The repo children are built dynamically in `Application.start/2` from `LocalConfig.load_orgs()`. Adding a new organization JSON file and restarting is all that's needed — no code changes.

`DBConnection` retries failed connections with exponential backoff. If the VPN is down at startup, the repos start but have no live connections — they reconnect automatically when the VPN comes up.

## Data flow: running a query

```
User clicks "Run Query"
        │
        ▼
handle_event("run_query", %{"sql" => sql}, socket)
        │  assigns running: true
        │
        ▼
start_async(socket, :run_query, fn -> SQLRunner.run_sql(repo_name, sql) end)
        │  spawns a linked task
        │
        ▼
DynamicRepo.put_dynamic_repo(repo_name)
DynamicRepo.query(sql, [], timeout: 30_000)
        │  runs in the async task
        │
        ▼
handle_async(:run_query, {:ok, result}, socket)
        │  assigns result: {:ok, %QueryResult{...}}
        │
        ▼
Template re-renders the results table
```

## Data flow: creating a query via the UI

```
User fills form and clicks "Create Query"
        │
        ▼
handle_event("save_query", params, socket)
        │
        ▼
QueryStore.create(org_slug, params)
        │  validates, appends to in-memory list
        │  writes priv/local/queries/<slug>.json
        │  broadcasts {:queries_updated, org_slug} via PubSub
        │
        ▼
handle_info({:queries_updated, _}, socket)  ← received by all connected LiveViews
        │  reloads grouped_queries from QueryStore
        │
        ▼
Sidebar re-renders with new query visible
```

## Key design decisions

**Why `priv/local/` instead of compiled Elixir modules?**
Each developer or team can have their own organizations and queries without creating commits. The JSON files are never tracked by git, so cloning the repo gives a clean slate that each user populates for their own environment.

**Why a single `DynamicRepo` module?**
Per-org Ecto.Repo modules require code changes (and recompilation) to add an org. A single module started with different named processes keeps all configuration at runtime — adding an org is a file drop and a restart.

**Why `put_dynamic_repo/1` instead of passing the repo to every call?**
Ecto's dynamic repo API is the idiomatic way to target named instances of the same module. `put_dynamic_repo` sets process-local state, which is safe here because each query runs in its own process (`start_async` task or `spawn_monitor`).

**Why `QueryStore` instead of reading the JSON file on every request?**
Reading from disk on each query list request adds latency and I/O. Holding the list in a GenServer keeps reads instant and makes real-time sidebar updates (via PubSub) straightforward.

**Why no local database for query persistence?**
Seeker has no data of its own beyond the query definitions, which are simple JSON. A SQLite or Postgres setup would add setup friction (migrations, credentials, schema) for no benefit over plain files.

**Why string keys for org slugs and query keys?**
Org slugs come from filenames; query keys are user-defined strings. Using atoms would require either pre-declaring them (impossible for user-defined queries) or using `String.to_atom/1` on untrusted input (atom table exhaustion risk). Strings are safe and straightforward.
