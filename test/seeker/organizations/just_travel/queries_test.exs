defmodule Seeker.JustTravel.QueriesTest do
  use ExUnit.Case, async: true

  alias Seeker.JustTravel.Queries

  describe "list_queries/0" do
    test "returns a non-empty list of query descriptors" do
      queries = Queries.list_queries()
      assert is_list(queries)
      assert length(queries) > 0
    end

    test "each query has required fields with correct types" do
      Enum.each(Queries.list_queries(), fn q ->
        assert is_atom(q.key)
        assert is_binary(q.name) and q.name != ""
        assert is_binary(q.sql) and q.sql != ""
      end)
    end
  end

  describe "get_sql/1" do
    test "returns sql for known query keys" do
      for %{key: key} <- Queries.list_queries() do
        assert {:ok, sql} = Queries.get_sql(key)
        assert is_binary(sql)
      end
    end

    test "returns error for unknown key" do
      assert {:error, _msg} = Queries.get_sql(:nonexistent_query_xyzzy)
    end
  end
end
