# Configuration

## The `.env` file

Database credentials are stored in `.env` at the project root. This file is gitignored — never commit it.

Copy the template to get started:

```bash
cp .env.example .env
```

Then open `.env` and fill in your values. Any variable can be referenced from an organization JSON file using the `"$VAR_NAME"` syntax — see the Organization files section below.

## Variables reference

### Just Travel — Production

```dotenv
JUST_TRAVEL_PROD_DB_HOST=your-host.rds.amazonaws.com
JUST_TRAVEL_PROD_DB_PORT=5432
JUST_TRAVEL_PROD_DB_USER=your_username
JUST_TRAVEL_PROD_DB_PASS=your_password
JUST_TRAVEL_PROD_DB_NAME=your_database_name
```

### Just Travel — Homologation

```dotenv
JUST_TRAVEL_HOMO_DB_HOST=your-homo-host.rds.amazonaws.com
JUST_TRAVEL_HOMO_DB_PORT=5432
JUST_TRAVEL_HOMO_DB_USER=your_username
JUST_TRAVEL_HOMO_DB_PASS=your_password
JUST_TRAVEL_HOMO_DB_NAME=your_homo_database_name
```

### SSL

```dotenv
# "verify_peer" — validates the server certificate (recommended for prod)
# "verify_none" — skips cert validation (use for self-signed or private CA certs)
JUST_TRAVEL_DB_SSL_MODE=verify_peer

# Only needed when SSL_MODE=verify_peer
JUST_TRAVEL_DB_SSL_CACERT=/etc/ssl/certs/ca-certificates.crt
```

## Organization files (`priv/local/organizations/`)

Each organization is defined in a JSON file in `priv/local/organizations/` (gitignored). Credential values in these files can be literal strings or `"$VAR_NAME"` references that are resolved from the system environment at startup:

```json
{
  "display": "My Org",
  "environments": {
    "prod": {
      "display": "Production",
      "hostname": "$MY_ORG_PROD_DB_HOST",
      "port": "$MY_ORG_PROD_DB_PORT",
      "username": "$MY_ORG_PROD_DB_USER",
      "password": "$MY_ORG_PROD_DB_PASS",
      "database": "$MY_ORG_PROD_DB_NAME",
      "ssl_mode": "verify_none"
    }
  }
}
```

You can also embed literal values directly in the JSON (both are gitignored equally):

```json
{
  "hostname": "db.internal",
  "port": 5432,
  "username": "admin",
  "password": "secret"
}
```

**SSL options per environment:**

| `ssl_mode` | Behavior |
|---|---|
| `"verify_none"` (default) | No certificate validation |
| `"verify_peer"` | Validates the server certificate against a CA bundle |

For `verify_peer`, add `"ssl_cacert": "/path/to/ca-bundle.crt"` (or use a `$VAR` reference).

See `priv/local.example/organizations/acme.json` for a full reference file.

## SSL troubleshooting

### `Unknown CA` error

```
TLS client: Fatal - Unknown CA
```

The database's certificate is signed by a private CA that Erlang doesn't trust. Set `ssl_mode` to `verify_none` in the org JSON:

```json
"ssl_mode": "verify_none"
```

Restart the server after changing any configuration file.

### `verify_peer` with a custom CA bundle

```json
"ssl_mode": "verify_peer",
"ssl_cacert": "/path/to/your/ca-bundle.crt"
```

The CA cert file must be readable by the OS user running the Elixir process.

### SSL and BeeKeeper parity

BeeKeeper's "Require SSL" toggle maps to `verify_none` in most self-hosted or cloud RDS setups where a private CA is used. If BeeKeeper connected with SSL enabled but without cert validation, use `verify_none` in Seeker.

## VPN

Seeker itself has no VPN awareness. If the database requires VPN:

1. Connect to the VPN **before** running `just run`
2. The `ConnectionMonitor` pings repos every 30 seconds — if you connect VPN after startup, the badge will turn green within ~30 seconds automatically (DBConnection retries in the background)

If the VPN disconnects while the server is running, the badge turns red and queries will return a "Cannot reach database" error. Reconnect VPN and the badge recovers on its own.

## Restart requirement

Any change to `.env` or the organization JSON files requires restarting the server:

```bash
# Ctrl+C to stop, then:
just run
```

Config is loaded once at boot — it is not hot-reloaded.

Query files (`priv/local/queries/*.json`) **do not** require a restart — changes made via the UI are applied immediately.

## Environment variable precedence

Dotenvy loads sources in order: `.env` first, then actual shell environment variables. Shell variables always win. This means you can temporarily override a value without editing the file:

```bash
JUST_TRAVEL_DB_SSL_MODE=verify_none just run
```

## Port

The server listens on port `4000` by default. Override with:

```dotenv
PORT=8080
```
