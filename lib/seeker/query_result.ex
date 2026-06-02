defmodule Seeker.QueryResult do
  @enforce_keys [:columns, :rows]
  defstruct [:columns, :rows, num_rows: 0, duration_ms: 0]
end
