defmodule Seeker.AgentCLI do
  @moduledoc """
  Shared helpers for the `mix seeker.*` tasks that let agents (and humans)
  run queries against org/environment databases from the command line.

  Kept separate from the tasks themselves so the logic is unit-testable
  without going through `Mix.Task.run/1`.
  """

  alias Seeker.{OrgRegistry, QueryResult}

  @read_only_keywords ~w(SELECT WITH EXPLAIN SHOW)

  @doc "Resolves the repo process name for an org/env pair, or an error tuple."
  def fetch_repo(org, env) do
    case OrgRegistry.get(org, env) do
      nil -> {:error, "Unknown org/env: #{org}/#{env}"}
      %{repo: repo} -> {:ok, repo}
    end
  end

  @doc """
  Replaces `:name` placeholders in `sql` with the given params.
  `params` is a list of `{name, value}` string pairs.
  """
  def substitute_params(sql, params) do
    Enum.reduce(params, sql, fn {name, value}, acc ->
      String.replace(acc, ":#{name}", value)
    end)
  end

  @doc """
  Refuses non-read-only statements unless `allow_write?` is true.
  Read-only is judged by the first keyword after stripping `--` comments.
  """
  def check_writable(sql, allow_write?) do
    if allow_write? or first_keyword(sql) in @read_only_keywords do
      :ok
    else
      {:error,
       "Refusing to run a non-SELECT statement without --allow-write " <>
         "(first keyword: #{first_keyword(sql)})"}
    end
  end

  defp first_keyword(sql) do
    sql
    |> String.split("\n")
    |> Enum.reject(&(&1 |> String.trim() |> String.starts_with?("--")))
    |> Enum.join("\n")
    |> String.trim_leading()
    |> String.split(~r/\s+/, parts: 2)
    |> List.first()
    |> to_string()
    |> String.upcase()
  end

  @doc "Prints a `QueryResult` in the requested format (\"json\" or \"table\")."
  def print_result(%QueryResult{} = result, "table") do
    Mix.shell().info(format_table(result))
  end

  def print_result(%QueryResult{} = result, _json) do
    payload = %{
      columns: result.columns,
      rows: jsonify_rows(result.rows),
      num_rows: result.num_rows,
      duration_ms: result.duration_ms
    }

    Mix.shell().info(Jason.encode!(payload))
  end

  @doc "Prints a JSON error object to stderr and halts with exit code 1."
  def fail(message) do
    IO.puts(:stderr, Jason.encode!(%{error: message}))
    System.halt(1)
  end

  defp format_table(%QueryResult{columns: columns, rows: rows}) do
    header = Enum.join(columns, " | ")
    separator = String.duplicate("-", String.length(header))
    body = Enum.map_join(rows, "\n", fn row -> Enum.map_join(row, " | ", &inspect/1) end)

    Enum.join([header, separator, body], "\n")
  end

  # Postgrex returns raw types (16-byte UUID binaries, non-UTF8 bytea, etc.)
  # that Jason.encode! would otherwise crash on.
  defp jsonify_rows(rows), do: Enum.map(rows, fn row -> Enum.map(row, &jsonify_value/1) end)

  defp jsonify_value(v) when is_binary(v) do
    cond do
      String.valid?(v) -> v
      byte_size(v) == 16 -> uuid_string(v)
      true -> Base.encode16(v, case: :lower)
    end
  end

  defp jsonify_value(v) when is_list(v), do: Enum.map(v, &jsonify_value/1)

  defp jsonify_value(%_struct{} = v) do
    if Jason.Encoder.impl_for(v), do: v, else: inspect(v)
  end

  defp jsonify_value(v), do: v

  defp uuid_string(<<a::32, b::16, c::16, d::16, e::48>>) do
    [a, b, c, d, e]
    |> Enum.zip([8, 4, 4, 4, 12])
    |> Enum.map_join("-", fn {part, width} ->
      part |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(width, "0")
    end)
  end
end
