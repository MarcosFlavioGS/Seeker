# Writing and Organizing Queries

## How queries are stored

Queries live in `priv/local/queries/<org_slug>.json` — a gitignored directory. Each org has its own file, and the file is a JSON array of query objects:

```json
[
  {
    "context": "Orders",
    "key": "find_order_by_email",
    "name": "Find Order by Email",
    "sql": "SELECT * FROM orders WHERE email = 'user@example.com';"
  }
]
```

- `context` — groups queries under a section header in the sidebar. All queries with the same context string appear together, sorted alphabetically by context name.
- `key` — must be unique across all queries for the organization. Auto-generated from the name if not supplied via the UI. Use lowercase letters, digits, and underscores only (e.g. `find_order_by_email`).
- `name` — what appears in the sidebar. Numbering (e.g. `"1."`, `"2."`) is optional but helpful for reference.
- `sql` — raw SQL. Comments (`--`) are preserved and shown in the editor. Placeholder syntax (`:order_id`, `:gateway_payment_id`) is just a convention — the user replaces them manually before running.

## Creating queries via the UI

Open any environment for an organization and click **New** at the top of the sidebar. Fill in:

- **Context** — section header (e.g. "Orders", "General")
- **Name** — sidebar label
- **SQL** — the query body

Click **Create Query**. The query is saved to the JSON file immediately and appears in the sidebar without a restart. Existing queries can be edited or deleted using the pencil and trash icons that appear on hover.

## Creating queries via the JSON file

Edit `priv/local/queries/<org_slug>.json` directly and restart the server. This is useful for bulk imports or copying queries between machines.

See `priv/local.example/queries/acme.json` for a reference file.

## SQL conventions

### Placeholders

Use `:snake_case` placeholders for values the user must supply:

```sql
WHERE o.id = :order_id
WHERE p.payment_id = ':gateway_payment_id'
```

Note the quotes around string placeholders — the replacement stays inside the string literal.

### Comments

SQL comments are displayed in the editor and help the user know what to replace:

```sql
-- Replace :order_id with the real value before running.
SELECT * FROM orders WHERE id = :order_id;
```

### UPDATE / DELETE queries

Prefix the query name with `[UPDATE]` or `[DELETE]` as a visual warning:

```
"name": "13. [UPDATE] Deactivate User"
```

There is no write protection — any SQL that executes will run. Be careful on Production environments.

### Hardcoded example values

It is fine to leave example IDs in the SQL (e.g. `WHERE order_id = 50033`) — the user edits them in the textarea before running. Add a comment explaining the replacement:

```sql
-- Replace 50033 with the real order_id before running.
WHERE oi.order_id = 50033
```

## Running ad-hoc SQL

The SQL textarea is always editable. You do not need a predefined query to run SQL. Click a predefined query to pre-fill the editor, edit it, and run — or clear it and write from scratch.

The last-run result stays visible until you run another query or click Clear.
