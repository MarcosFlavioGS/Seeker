defmodule Seeker.LocalConfig.QueriesTest do
  use ExUnit.Case, async: true

  alias Seeker.LocalConfig

  @org_slug "just_travel"

  describe "load_queries/1" do
    test "returns a non-empty list for just_travel" do
      queries = LocalConfig.load_queries(@org_slug)
      assert is_list(queries)
      assert length(queries) > 0
    end

    test "each query has required fields with correct types" do
      Enum.each(LocalConfig.load_queries(@org_slug), fn q ->
        assert is_binary(q.key) and q.key != ""
        assert is_binary(q.name) and q.name != ""
        assert is_binary(q.sql) and q.sql != ""
        assert is_binary(q.context) and q.context != ""
      end)
    end

    test "returns empty list for unknown org" do
      assert [] = LocalConfig.load_queries("nonexistent_org_xyzzy")
    end
  end
end
