defmodule Seeker.JustTravel.Contexts.Insurances do
  @context "Insurances"

  def list_queries do
    [
      %{
        context: @context,
        key: :gta_catalog_sync_jobs,
        name: "1. GTA Catalog Sync Jobs",
        sql: """
        SELECT
          id,
          state,
          attempt,
          max_attempts,
          inserted_at,
          scheduled_at,
          attempted_at,
          completed_at,
          errors
        FROM oban_jobs
        WHERE queue = 'gta_catalog_sync'
        ORDER BY inserted_at DESC
        LIMIT 20;
        """
      }
    ]
    |> Enum.map(&Map.update!(&1, :sql, fn s -> String.trim(s) end))
  end
end
