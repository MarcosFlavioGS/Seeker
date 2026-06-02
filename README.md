<p align="center">
  <img src="priv/static/images/seeker-logo.svg" width="200" alt="Seeker logo — a tamanduá"/>
</p>

<h1 align="center">Seeker</h1>

<p align="center">
  A personal PostgreSQL query tool built with Elixir and Phoenix LiveView.<br/>
  Run queries against remote databases from your browser — no GUI client required.
</p>

---

## What it is

Seeker is a lightweight web app that replaces tools like BeeKeeper Studio for day-to-day database querying. You configure one or more remote PostgreSQL connections, write (or pick) a query, and see the results as a table — all in the browser, with live connection-status badges that tell you whether the VPN is up.

It is designed to be:

- **Personal** — runs on `localhost`, not deployed anywhere
- **Organized** — queries are grouped by organization and context (e.g. Mobility, Insurances)
- **Extensible** — adding a new database or a new query context is a handful of lines

## Features

- Live connection health badges (Connected / VPN down / Auth error)
- Predefined named queries, grouped by context, selectable from the sidebar
- Ad-hoc SQL editor — edit any predefined query or write your own
- Results rendered as a scrollable table with row count and timing metadata
- SSL support (`verify_peer` or `verify_none`)
- Dark / light / system theme toggle
- Credentials loaded from `.env` — never committed

## Requirements

- Elixir 1.19+ / Erlang 28+ (see `.tool-versions`)
- The target database must be reachable (VPN, firewall, etc.)
- A `.env` file with your connection credentials (see [Configuration](docs/configuration.md))

## Quick start

```bash
# 1. Install dependencies
mix deps.get

# 2. Copy the example env file and fill in your credentials
cp .env.example .env
# edit .env — set host, port, user, password, database name

# 3. Connect the VPN (if required by your database)

# 4. Start the server
mix phx.server
```

Open [http://localhost:4000](http://localhost:4000). It redirects to `/orgs/just_travel/prod`.

You can also open an IEx session alongside the server:

```bash
iex -S mix phx.server
```

## Environment variables

All credentials live in `.env` at the project root. The file is gitignored — never commit it.

| Variable | Description |
|---|---|
| `JUST_TRAVEL_PROD_DB_HOST` | Production database hostname |
| `JUST_TRAVEL_PROD_DB_PORT` | Port (default `5432`) |
| `JUST_TRAVEL_PROD_DB_USER` | Username |
| `JUST_TRAVEL_PROD_DB_PASS` | Password |
| `JUST_TRAVEL_PROD_DB_NAME` | Database name |
| `JUST_TRAVEL_HOMO_DB_*` | Same fields for Homologation |
| `JUST_TRAVEL_DB_SSL_MODE` | `verify_peer` or `verify_none` |
| `JUST_TRAVEL_DB_SSL_CACERT` | Path to CA bundle (only for `verify_peer`) |

See [docs/configuration.md](docs/configuration.md) for SSL troubleshooting.

## Adding queries

Create a new context file under the organization's `contexts/` directory:

```
lib/seeker/organizations/just_travel/contexts/hotels.ex
```

Then register it in `lib/seeker/organizations/just_travel/queries.ex`.
See [docs/queries.md](docs/queries.md) for the full pattern.

## Adding a new organization

See [docs/adding-organizations.md](docs/adding-organizations.md) for a step-by-step guide.

## Project structure

```
lib/
  seeker/
    organizations/
      just_travel/
        contexts/
          mobility.ex       ← car-rental queries
          insurances.ex     ← insurance queries
        queries.ex          ← aggregates all contexts
        prod_repo.ex        ← Ecto.Repo for production
        homo_repo.ex        ← Ecto.Repo for homologation
    connection_monitor.ex   ← pings repos every 30s, publishes status
    repo_registry.ex        ← maps org/env names to modules
    query_result.ex         ← result struct
  seeker_web/
    live/
      query_live.ex         ← main LiveView
config/
  runtime.exs               ← credentials loaded here via dotenvy
.env                        ← your secrets (gitignored)
.env.example                ← template to copy from
```

See [docs/architecture.md](docs/architecture.md) for a deeper explanation.

## Documentation

| Document | Description |
|---|---|
| [docs/architecture.md](docs/architecture.md) | How the system is designed and why |
| [docs/configuration.md](docs/configuration.md) | SSL, VPN, and environment variables |
| [docs/queries.md](docs/queries.md) | How to write and organize query contexts |
| [docs/adding-organizations.md](docs/adding-organizations.md) | Step-by-step guide for new organizations |
