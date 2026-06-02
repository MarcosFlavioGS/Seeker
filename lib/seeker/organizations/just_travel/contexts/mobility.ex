defmodule Seeker.JustTravel.Contexts.Mobility do
  @moduledoc """
  Car rental / mobility queries for Just Travel.
  Corresponds to the "Mobility" query file in BeeKeeper (SMED-2367).

  Queries with :placeholder variables must be edited in the SQL editor
  before running — replace :gateway_payment_id, :order_id, :order_item_id
  with real values.
  """

  @context "Mobility"

  def list_queries do
    [
      %{
        context: @context,
        key: :find_order_by_gateway_payment,
        name: "1. Find Order by Gateway Payment ID",
        sql: """
        -- Starting point when you only have the Malga payment ID.
        -- Replace :gateway_payment_id with the real value before running.
        SELECT
          o.id            AS order_id,
          o.booking_status,
          o.status,
          p.payment_id    AS gateway_payment_id,
          p.name          AS payment_method,
          p.payment_provider_name,
          o.inserted_at   AS order_created_at
        FROM orders o
        JOIN payment p ON p.id = o.payment_id
        WHERE p.payment_id = ':gateway_payment_id';
        """
      },
      %{
        context: @context,
        key: :car_order_items,
        name: "2. Car Order Items for an Order",
        sql: """
        -- Replace 50033 with the real order_id before running.
        SELECT
          oi.id                                         AS order_item_id,
          oi.type,
          oi.product_json->>'car_pickup_date_time'      AS pickup_datetime,
          oi.product_json->>'car_token_jt'              AS car_token,
          oi.product_json->>'car_pickup_store_index'    AS pickup_store,
          oi.product_json->>'car_return_store_index'    AS return_store,
          oi.product_json->>'language'                  AS language,
          oi.inserted_at
        FROM order_items oi
        WHERE oi.order_id = 50033
          AND oi.type = 'car';
        """
      },
      %{
        context: @context,
        key: :oban_jobs_by_order,
        name: "3. Oban Jobs by Order ID",
        sql: """
        -- Replace 50033 with the real order_id before running.
        SELECT
          id,
          queue,
          worker,
          state,
          attempt,
          max_attempts,
          args,
          errors,
          inserted_at,
          scheduled_at,
          attempted_at,
          completed_at
        FROM oban_jobs
        WHERE queue IN ('car_auto_booking', 'car_operations_alert')
          AND (args->>'order_id')::bigint = 50033
        ORDER BY inserted_at DESC;
        """
      },
      %{
        context: @context,
        key: :oban_recent_activity,
        name: "4. Oban Recent Activity (2h)",
        sql: """
        -- Useful when you don't have the order_id yet.
        SELECT
          id,
          queue,
          worker,
          state,
          attempt,
          max_attempts,
          args,
          errors,
          inserted_at,
          attempted_at,
          completed_at
        FROM oban_jobs
        WHERE queue IN ('car_auto_booking', 'car_operations_alert')
          AND inserted_at >= NOW() - INTERVAL '2 hours'
        ORDER BY inserted_at DESC;
        """
      },
      %{
        context: @context,
        key: :oban_failed_retryable,
        name: "5. Oban Failed / Retryable Jobs",
        sql: """
        SELECT
          id,
          queue,
          worker,
          state,
          attempt,
          max_attempts,
          args,
          errors,
          scheduled_at  AS next_retry_at
        FROM oban_jobs
        WHERE queue IN ('car_auto_booking', 'car_operations_alert')
          AND state IN ('retryable', 'discarded')
        ORDER BY inserted_at DESC
        LIMIT 20;
        """
      },
      %{
        context: @context,
        key: :car_bookings_by_item,
        name: "6. Car Bookings by Order Item",
        sql: """
        -- Replace :order_item_id with the real value before running.
        SELECT
          cb.id,
          cb.booking_id,
          cb.order_item_id,
          cb.amount,
          cb.cancellation_deadline,
          cb.deadline_for_payment,
          cb.url_voucher_pt,
          cb.url_voucher_us,
          cb.pickup_city,
          cb.pickup_date,
          cb.return_city,
          cb.return_date,
          cb.form_of_payment,
          cb.inserted_at
        FROM car_bookings cb
        WHERE cb.order_item_id = :order_item_id;
        """
      },
      %{
        context: @context,
        key: :car_bookings_by_order,
        name: "7. Car Bookings by Order (all items)",
        sql: """
        -- Replace :order_id with the real value before running.
        SELECT
          cb.id,
          cb.booking_id,
          cb.order_item_id,
          cb.amount,
          cb.pickup_city,
          cb.pickup_date,
          cb.return_city,
          cb.return_date,
          cb.url_voucher_pt,
          cb.inserted_at
        FROM car_bookings cb
        JOIN order_items oi ON oi.id = cb.order_item_id
        WHERE oi.order_id = :order_id;
        """
      },
      %{
        context: @context,
        key: :malga_webhook_by_payment,
        name: "8. Malga Webhook Logs by Payment ID",
        sql: """
        -- Replace :gateway_payment_id with the real Malga payment ID.
        SELECT
          id,
          router,
          request,
          response,
          inserted_at
        FROM malga_application_logs
        WHERE request->>'id' = ':gateway_payment_id'
           OR request->'data'->>'id' = ':gateway_payment_id'
        ORDER BY inserted_at DESC;
        """
      },
      %{
        context: @context,
        key: :malga_webhook_recent,
        name: "9. Malga Recent Webhooks (2h)",
        sql: """
        -- When you don't know the gateway_payment_id yet.
        SELECT
          id,
          router,
          request->'data'->>'id'    AS gateway_payment_id,
          request->>'event'         AS event_type,
          inserted_at
        FROM malga_application_logs
        WHERE inserted_at >= NOW() - INTERVAL '2 hours'
        ORDER BY inserted_at DESC
        LIMIT 50;
        """
      },
      %{
        context: @context,
        key: :end_to_end_trace,
        name: "10. End-to-End Trace (Full Order)",
        sql: """
        -- Replace 50033 with the real order_id before running.
        SELECT
          o.id                                          AS order_id,
          o.booking_status,
          p.payment_id                                  AS gateway_payment_id,
          p.name                                        AS payment_method,
          oi.id                                         AS order_item_id,
          oi.type,
          oi.product_json->>'car_pickup_date_time'      AS pickup_datetime,
          cb.id                                         AS car_booking_id,
          cb.booking_id                                 AS provider_booking_id,
          cb.inserted_at                                AS booking_created_at,
          jobs.id                                       AS oban_job_id,
          jobs.queue,
          jobs.worker,
          jobs.state                                    AS job_state,
          jobs.attempt,
          jobs.errors,
          jobs.completed_at                             AS job_completed_at
        FROM orders o
        JOIN payment p ON p.id = o.payment_id
        JOIN order_items oi ON oi.order_id = o.id AND oi.type = 'car'
        LEFT JOIN car_bookings cb ON cb.order_item_id = oi.id
        LEFT JOIN oban_jobs jobs
          ON jobs.queue IN ('car_auto_booking', 'car_operations_alert')
          AND (jobs.args->>'order_item_id')::bigint = oi.id
        WHERE o.id = 50033
        ORDER BY jobs.inserted_at DESC;
        """
      },
      %{
        context: @context,
        key: :idempotency_check,
        name: "11. Idempotency Check",
        sql: """
        -- Replace :order_id with the real value.
        -- Should return at most 1 row per item per queue.
        SELECT
          (args->>'order_item_id')::bigint AS order_item_id,
          queue,
          COUNT(*) AS job_count
        FROM oban_jobs
        WHERE queue IN ('car_auto_booking', 'car_operations_alert')
          AND (args->>'order_id')::bigint = :order_id
        GROUP BY 1, 2
        ORDER BY 1, 2;
        """
      },
      %{
        context: @context,
        key: :agency_auto_booking_status,
        name: "12. Agency Auto-Booking Status",
        sql: """
        -- Replace :order_id with the real value.
        SELECT
          o.id AS order_id,
          a.id AS agency_id,
          a.name AS agency_name,
          c.is_automatic_mobility_booking_enabled AS contract_enabled,
          cg.is_automatic_mobility_booking_enabled AS group_enabled
        FROM orders o
        JOIN agencies a ON a.id = o.agency_id
        JOIN contracts c ON c.id = a.contract_id
        LEFT JOIN contracts_groups cg ON cg.id = c.contracts_groups_id
        WHERE o.id = :order_id;
        """
      },
      %{
        context: @context,
        key: :enable_auto_booking_contracts,
        name: "13. [UPDATE] Enable Auto-Booking (Contracts)",
        sql: """
        -- ⚠ This modifies data. Replace agency IDs as needed.
        UPDATE contracts
        SET is_automatic_mobility_booking_enabled = true
        WHERE id IN (
          SELECT contract_id FROM agencies
          WHERE id IN (668, 8, 779, 13, 1104, 1012, 440, 1421, 635, 496, 1, 557)
        );
        """
      },
      %{
        context: @context,
        key: :enable_auto_booking_groups,
        name: "14. [UPDATE] Enable Auto-Booking (Contract Groups)",
        sql: """
        -- ⚠ This modifies data. Replace agency IDs as needed.
        UPDATE contracts_groups
        SET is_automatic_mobility_booking_enabled = true
        WHERE id IN (
          SELECT contracts_groups_id FROM contracts
          WHERE id IN (
            SELECT contract_id FROM agencies
            WHERE id IN (668, 8, 779, 13, 1104, 1012, 440, 1421, 635, 496, 1, 557)
          )
        );
        """
      },
      %{
        context: @context,
        key: :verify_agencies_auto_booking,
        name: "15. Verify Agencies Auto-Booking",
        sql: """
        -- Replace agency IDs as needed.
        SELECT
          a.id AS agency_id,
          a.name,
          c.is_automatic_mobility_booking_enabled AS contract_flag,
          cg.is_automatic_mobility_booking_enabled AS group_flag
        FROM agencies a
        JOIN contracts c ON c.id = a.contract_id
        JOIN contracts_groups cg ON cg.id = c.contracts_groups_id
        WHERE a.id IN (668, 8, 779, 13, 1104, 1012, 440, 1421, 635, 496, 1, 557)
        ORDER BY a.id;
        """
      }
    ]
    |> Enum.map(&Map.update!(&1, :sql, fn s -> String.trim(s) end))
  end
end
