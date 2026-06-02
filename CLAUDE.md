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
```

No local database — there is no `mix ecto.create` or `mix ecto.migrate`. Seeker queries remote PostgreSQL databases; it has no DB of its own.

## Architecture

Seeker is a single-page Phoenix 1.8 LiveView app. The sole route is `/orgs/:org/:env`, rendered by `QueryLive`.

**Key layers:**

- **`config/runtime.exs`** — loads all credentials from `.env` via Dotenvy at startup. Shell env vars override `.env` values.
- **`lib/seeker/organizations/<org>/`** — one directory per organization, containing:
  - `prod_repo.ex` / `homo_repo.ex` — `Ecto.Repo` modules (pool size 2, no schemas/migrations)
  - `queries.ex` — aggregates all context modules; exposes `run_sql/2`
  - `contexts/*.ex` — each file is a context (e.g. `mobility.ex`) returning a list of query maps
- **`lib/seeker/repo_registry.ex`** — compile-time map from URL-friendly names (atoms) to repo/queries modules. `QueryLive` calls `RepoRegistry.get(org, env)` with `String.to_existing_atom/1` (safe: only succeeds for atoms already defined in the registry).
- **`lib/seeker/connection_monitor.ex`** — `GenServer` that pings all repos with `SELECT 1` every 30 seconds, classifies results, and broadcasts on the `"conn_status"` PubSub topic. The LiveView subscribes on mount — no polling.
- **`lib/seeker_web/live/query_live.ex`** — the single LiveView. SQL runs inside `start_async/3` so slow queries don't block the process; results arrive via `handle_async/3`.

**Supervision order matters:** `ConnectionMonitor` must start after PubSub and all repos — it connects to them on `init`.

## Query structure

Each query is a map:
```elixir
%{
  context: "Mobility",              # sidebar section header
  key: :find_order_by_gateway,      # unique atom across the org
  name: "1. Find Order by Gateway", # sidebar label
  sql: "SELECT ..."
}
```

To add a query: add an entry to the relevant context file (e.g. `contexts/mobility.ex`).  
To add a new context: create `contexts/<name>.ex` and register it in `queries.ex`.  
See `docs/queries.md` for the full pattern and SQL conventions (placeholders, UPDATE/DELETE prefixes).

To add a new organization: follow `docs/adding-organizations.md`.

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

Never leave documentation describing behavior that no longer exists.

## Environment

`.env` is gitignored. Copy `.env.example` to `.env` and fill in credentials before starting. SSL mode is configured via `JUST_TRAVEL_DB_SSL_MODE` (`verify_peer` or `verify_none`). See `docs/configuration.md` for SSL details.
