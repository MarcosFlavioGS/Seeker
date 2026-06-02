# Adding a New Organization

Organizations are defined in `priv/local/organizations/` — a directory that is gitignored. Anyone who clones the repo creates their own organizations there without those files ever appearing in version control.

---

## Step 1 — Create the organization file

Create `priv/local/organizations/<slug>.json` where `<slug>` is a lowercase, underscore-separated identifier (e.g. `acme_corp`):

```json
{
  "display": "Acme Corp",
  "environments": {
    "prod": {
      "display": "Production",
      "hostname": "$ACME_PROD_DB_HOST",
      "port": "$ACME_PROD_DB_PORT",
      "username": "$ACME_PROD_DB_USER",
      "password": "$ACME_PROD_DB_PASS",
      "database": "$ACME_PROD_DB_NAME",
      "ssl_mode": "verify_none"
    },
    "staging": {
      "display": "Staging",
      "hostname": "staging.acme.internal",
      "port": 5432,
      "username": "acme_user",
      "password": "$ACME_STAGING_DB_PASS",
      "database": "acme_staging",
      "ssl_mode": "verify_none"
    }
  }
}
```

Values starting with `$` are treated as environment variable references and resolved at startup. Literal strings and integers are used as-is. See `priv/local.example/organizations/acme.json` for a full reference.

**SSL options:**
- `"ssl_mode": "verify_none"` — no certificate verification (default)
- `"ssl_mode": "verify_peer"` — verifies the server certificate; optionally add `"ssl_cacert": "/path/to/ca-bundle.crt"`

---

## Step 2 — Add credentials to `.env`

```dotenv
ACME_PROD_DB_HOST=db.acme.com
ACME_PROD_DB_PORT=5432
ACME_PROD_DB_USER=your_user
ACME_PROD_DB_PASS=your_password
ACME_PROD_DB_NAME=acme_production

ACME_STAGING_DB_PASS=your_staging_password
```

Also add the same variables (with placeholder values) to `.env.example` so the template stays up to date.

---

## Step 3 — Restart the server

```bash
just run
```

Navigate to `http://localhost:4000`. The new organization appears on the home page with connection badges for each environment.

---

## Adding queries

Queries can be created in two ways:

**Via the UI (recommended):** Open any environment for the org, click **New** at the top of the sidebar, fill in the context, name, and SQL, and click Create Query. The query is saved immediately to `priv/local/queries/<slug>.json` and appears in the sidebar without a restart.

**Via the JSON file directly:** Create or edit `priv/local/queries/<slug>.json`. See [queries.md](queries.md) for the file format. Restart the server to pick up changes made outside the UI.
