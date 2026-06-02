# Writing and Organizing Queries

## How queries are structured

Every query is a map with four fields:

```elixir
%{
  context: "Mobility",                    # sidebar section header
  key:     :find_order_by_gateway_payment, # unique atom, used by load_query event
  name:    "1. Find Order by Gateway Payment ID", # display label in sidebar
  sql:     "SELECT ..."                   # the SQL string
}
```

- `context` — groups queries under a section header in the sidebar. All queries with the same context string appear together.
- `key` — must be unique across ALL contexts for the organization. It is used internally when a predefined query is selected.
- `name` — what appears in the sidebar button. Numbering (e.g. `"1."`, `"2."`) is optional but helpful for reference.
- `sql` — raw SQL. Comments (`--`) are preserved and shown in the editor. Placeholder syntax (`:order_id`, `:gateway_payment_id`) is just a convention — the user replaces them manually in the editor before running.

## Adding a query to an existing context

Open the context file and add an entry to the list:

```elixir
# lib/seeker/organizations/just_travel/contexts/insurances.ex

%{
  context: @context,
  key: :my_new_query,
  name: "2. My New Query",
  sql: """
  SELECT id, name FROM some_table WHERE condition = true LIMIT 100;
  """
}
```

Restart the server — the query appears in the sidebar immediately.

## Creating a new context

1. Create the context file:

```
lib/seeker/organizations/just_travel/contexts/hotels.ex
```

```elixir
defmodule Seeker.JustTravel.Contexts.Hotels do
  @context "Hotels"

  def list_queries do
    [
      %{
        context: @context,
        key: :hotel_bookings_recent,
        name: "1. Recent Hotel Bookings",
        sql: """
        SELECT id, hotel_name, check_in, check_out, status, inserted_at
        FROM hotel_bookings
        ORDER BY inserted_at DESC
        LIMIT 50;
        """
      }
    ]
    |> Enum.map(&Map.update!(&1, :sql, fn s -> String.trim(s) end))
  end
end
```

2. Register it in `queries.ex`:

```elixir
# lib/seeker/organizations/just_travel/queries.ex

alias Seeker.JustTravel.Contexts.{Hotels, Insurances, Mobility}

def list_queries do
  (@general_queries ++
   Hotels.list_queries() ++
   Insurances.list_queries() ++
   Mobility.list_queries())
  |> Enum.map(&Map.update!(&1, :sql, fn s -> String.trim(s) end))
end
```

The sidebar section order follows the order they appear in `list_queries/0`. Within each context, queries appear in list order.

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

```elixir
name: "13. [UPDATE] Enable Auto-Booking (Contracts)",
```

There is no write protection — any SQL that executes will run. Be careful on the Production environment.

### Hardcoded test values

It is fine to leave example IDs in the SQL (e.g. `WHERE order_id = 50033`) — the user edits them in the textarea before running. Add a comment explaining the replacement:

```sql
-- Replace 50033 with the real order_id before running.
WHERE oi.order_id = 50033
```

## Running ad-hoc SQL

The SQL textarea is always editable. You do not need a predefined query to run SQL. Click a predefined query to pre-fill the editor, edit it, and run — or clear it and write from scratch.

The last-run result stays visible until you run another query or click Clear.
