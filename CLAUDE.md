# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
just run                       # start dev server at http://localhost:4000
just iex                       # start server with IEx shell
just setup                     # install deps and build assets (first-time setup)
just deps                      # fetch dependencies only

just test                      # run all tests
just test-file test/my_test.exs  # run a single test file
just test-failed               # re-run previously failing tests

just compile                   # compile the project
just format                    # format code
just precommit                 # compile (warnings-as-errors), clean unused deps, format, and test — run before committing

mix seeker.orgs                          # list configured orgs/envs as JSON
mix seeker.queries --org <slug>          # list saved queries for an org as JSON
mix seeker.query --org <slug> --env <k> (--sql "..." | --key <query_key>)  # run a query, prints JSON
```

No local database — there is no `mix ecto.create` or `mix ecto.migrate`. Seeker queries remote PostgreSQL databases; it has no DB of its own.

The `mix seeker.*` tasks (and the `bin/seeker` wrapper, usually symlinked onto `PATH`) let agents run queries without the web UI. See `AGENTS.md` for the full reference — usage, `--allow-write` semantics, output contract.

## Architecture

Seeker is a single-page Phoenix 1.8 LiveView app. The sole route is `/orgs/:org/:env`, rendered by `QueryLive`.

**Key layers:**

- **`config/runtime.exs`** — loads `.env` via Dotenvy so env vars are available at startup. Shell env vars override `.env` values.
- **`priv/local/`** — gitignored directory. Contains all user-specific data:
  - `organizations/<slug>.json` — org definition (display name, environments, DB credentials)
  - `queries/<slug>.json` — all queries for that org (managed via UI or edited directly)
- **`lib/seeker/local_config.ex`** — reads `priv/local/` at startup. Resolves `"$ENV_VAR"` references in JSON values.
- **`lib/seeker/org_registry.ex`** — runtime registry built from `LocalConfig` and stored in `:persistent_term`. Replaces the old compile-time `RepoRegistry`. Keys are slug strings (`"acme"`).
- **`lib/seeker/dynamic_repo.ex`** — single `Ecto.Repo` module started multiple times (once per org/env) with unique process names (e.g. `:"seeker_repo_acme_prod"`). Uses `put_dynamic_repo/1` for per-call targeting.
- **`lib/seeker/query_store.ex`** — `GenServer` that holds all queries in memory, persists mutations to the JSON files, and broadcasts `:queries_updated` via PubSub.
- **`lib/seeker/sql_runner.ex`** — executes raw SQL against a named `DynamicRepo` instance.
- **`lib/seeker/connection_monitor.ex`** — `GenServer` that pings all repos with `SELECT 1` every 30 seconds, classifies results, and broadcasts on the `"conn_status"` PubSub topic. The LiveView subscribes on mount — no polling.
- **`lib/seeker_web/live/query_live.ex`** — the single LiveView. SQL runs inside `start_async/3` so slow queries don't block the process; results arrive via `handle_async/3`. Includes query CRUD (create/edit/delete via modal form).
- **`lib/seeker/agent_cli.ex`** — shared helpers for the `mix seeker.*` tasks (`lib/mix/tasks/seeker.*.ex`): repo resolution, `:param` substitution, the `--allow-write` guard, JSON-safe row encoding, and JSON output/error formatting.

**Supervision order:** `QueryStore` and `ConnectionMonitor` must start after PubSub and all repos.

## Query structure

Each query is a JSON object in `priv/local/queries/<slug>.json`:
```json
{
  "context": "Orders",
  "key": "find_order_by_id",
  "name": "1. Find Order by ID",
  "sql": "SELECT ..."
}
```

Keys are strings (not atoms). Queries can be created, edited, and deleted via the UI sidebar without restarting.

To add a query: use the **New** button in the sidebar, or edit the JSON file and restart.  
To add a new organization: follow `docs/adding-organizations.md`.  
See `docs/queries.md` for SQL conventions (placeholders, UPDATE/DELETE prefixes).

## Phoenix/LiveView conventions (project-specific)

- LiveView templates must begin with `<Layouts.app flash={@flash} ...>` — `Layouts` is already aliased in `seeker_web.ex`
- Use `<.icon name="hero-x-mark">` for icons, never `Heroicons` modules
- Use `<.input>` from `core_components.ex` for form inputs
- Never call `<.flash_group>` outside `layouts.ex`
- JS: Tailwind CSS only; never use `@apply`; never write inline `<script>` tags (use colocated hooks with `:type={Phoenix.LiveView.ColocatedHook}` and a `.` prefix for inline JS)
- CSS bundling: `app.css` uses the Tailwind v4 import syntax with `source(none)` — maintain it as-is

## Documentation

When making changes that affect behavior, commands, configuration, architecture, or query conventions, update the relevant documentation files alongside the code:

- `README.md` — quick start, requirements, environment variables
- `CLAUDE.md` — commands, architecture overview, conventions
- `docs/architecture.md` — system design, layers, data flow, key decisions
- `docs/configuration.md` — SSL, VPN, environment variable details
- `docs/queries.md` — query structure, SQL conventions, adding queries/contexts
- `docs/adding-organizations.md` — step-by-step guide for new organizations
- `AGENTS.md` — how coding agents should run queries via `mix seeker.*` / `seeker`

Never leave documentation describing behavior that no longer exists.

## Environment

`.env` is gitignored. Copy `.env.example` to `.env` and fill in credentials before starting.

`priv/local/` is gitignored. Copy `priv/local.example/` as a reference to create your own org and query definitions. See `docs/adding-organizations.md` for the full setup steps. SSL mode is configured per-environment inside the org JSON file. See `docs/configuration.md` for SSL details.
