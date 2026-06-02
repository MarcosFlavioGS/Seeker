# Configuration

## The `.env` file

All database credentials are stored in `.env` at the project root. This file is listed in `.gitignore` and must never be committed.

Copy the template to get started:

```bash
cp .env.example .env
```

Then open `.env` and fill in your values.

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

## SSL troubleshooting

### `Unknown CA` error

```
TLS client: Fatal - Unknown CA
```

The database's certificate is signed by a private CA that Erlang doesn't trust. Switch to `verify_none`:

```dotenv
JUST_TRAVEL_DB_SSL_MODE=verify_none
```

Restart the server after changing `.env` — config is only loaded at boot.

### `verify_peer` with a custom CA bundle

If you have the CA certificate file from your DB provider:

```dotenv
JUST_TRAVEL_DB_SSL_MODE=verify_peer
JUST_TRAVEL_DB_SSL_CACERT=/path/to/your/ca-bundle.crt
```

The CA cert file must be readable by the OS user running the Elixir process.

### SSL and BeeKeeper parity

BeeKeeper's "Require SSL" toggle maps to `verify_none` in most self-hosted or cloud RDS setups where a private CA is used. If BeeKeeper connected with SSL enabled but without cert validation, use `verify_none` in Seeker.

## VPN

Seeker itself has no VPN awareness. If the database requires VPN:

1. Connect to the VPN **before** running `mix phx.server`
2. The `ConnectionMonitor` pings repos every 30 seconds — if you connect VPN after startup, the badge will turn green within ~30 seconds automatically (DBConnection retries in the background)

If the VPN disconnects while the server is running, the badge turns red and queries will return a "Cannot reach database" error. Reconnect VPN and the badge recovers on its own.

## Restart requirement

Any change to `.env` requires restarting the server:

```bash
# Ctrl+C to stop, then:
mix phx.server
```

Config is loaded once at boot by `config/runtime.exs` — it is not hot-reloaded.

## Environment variable precedence

Dotenvy loads sources in order: `.env` first, then actual shell environment variables. Shell variables always win. This means you can temporarily override a value without editing the file:

```bash
JUST_TRAVEL_DB_SSL_MODE=verify_none mix phx.server
```

## Port

The server listens on port `4000` by default. Override with:

```dotenv
PORT=8080
```
