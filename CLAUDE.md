# CLAUDE.md — Dimensional Modeling Decisions

## stg_events
**Grain:** One row per user action (view, cart, or purchase) from the raw `events` source table.  
**Column selection:** Retained `event_time`, `event_type`, `category_id`, `price`, `user_id`, `user_session`. Dropped `product_id`, `category_code`, and `brand` — not needed for downstream sessionization, funnel, and cohort models.  
**Deduplication:** None — all rows from the source are included.  
**Filtering:** None — all event types and date ranges are retained.  
**Data tests:** `not_null` on `user_id` and `event_time`; `accepted_values` on `event_type` restricted to `view`, `cart`, `purchase`.  
**Source:** `source('ecommerce', 'events')`

## int_sessions
**Grain:** One row per event per user session.  
**Session definition:** A session is a continuous sequence of events by a single user with no gap exceeding 30 minutes between consecutive events.  
**Session ID logic:** LAG retrieves the previous event timestamp. CASE flags a new session when the gap exceeds 30 minutes or when previous_time is NULL (first event). SUM as a running total over the flag assigns the session ID.  
**Gap threshold:** 30 minutes.  
**Deduplication:** None.  
**Filtering:** None — all events from stg_events are included. 
**Data tests:** `not_null` on `session_id` and `user_id`.  
**Source:** `ref('stg_events')`  
**Performance note:** Materialized as a view. If query times become problematic at scale, change materialization to table in `dbt_project.yml`.

## int_funnel
**Grain:** One row per user who has at least one view event, with the first timestamp for each funnel step.  
**Funnel steps:** view, cart, purchase.  
**Logic:** MIN(event_time) per event_type per user, pivoted into columns using CASE WHEN. Users with no view event are excluded via WHERE view_time IS NOT NULL.  
**Ordering constraint:** Conversion is enforced downstream in the mart — view_time < cart_time < purchase_time. This model does not enforce ordering.  
**Source:** `ref('stg_events')`  
**Data tests:** `not_null` on `user_id` and `view_time`.

## int_cohorts
**Grain:** One row per user.  
**Logic:** MIN(event_time) per user truncated to day. Produces the cohort date — the day each user first appeared in the dataset.  
**Downstream use:** Mart layer joins activity events against this model to calculate days_since and build the retention grid.  
**Source:** `ref('stg_events')`
**Data tests:** `not_null` and `unique` on `user_id`; `not_null` on `cohort_date`.

## mrt_retention
**Grain:** One row per cohort, defined by the date of the user's first event, truncated by day.
**Logic:**  Retention grid is grouped by cohort.
**Sources:** `ref('stg_events')`, `ref('int_cohorts')`
**Data test:** `not_null` and `unique` on `cohort`
**Date Truncation:** `cohort_date` was truncated in int layer, `event_time` is truncated in mrt layer prior to calculating the difference for the `days_since` column.
**Multi-Sources:** To add `cohort_date`, 2 sources are referenced during the JOIN operation.

## stg_products
**Grain:** One row per `product_id`.
**Column selection:** Retained `product_id`, `category_id`, `brand`. Excluded `category_code` — sparsely populated, mostly null.
**Deduplication:** `QUALIFY ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY event_time DESC) = 1` — keeps the most recent row per product.
**Filtering:** `WHERE product_id IS NOT NULL` — null product_ids excluded before deduplication.
**Source:** `source('ecommerce', 'events')`

## snap_products
**Strategy:** `check` on `check_cols: [category_id]`. Detects changes by comparing current and prior values of `category_id`.
**Unique key:** `product_id`.
**Target schema:** `snapshots` (separate from the `ecommerce_events` model dataset).
**Column handling:** `brand` is included in the snapshot but not in `check_cols` — changes to `brand` do not open a new record, making it effectively Type 1 (overwrite in place).
**Hard deletes:** `invalidate_hard_deletes=True` — products that disappear from `stg_products` will have `dbt_valid_to` closed rather than left open.
**Performance trade-off:** `check` strategy performs a full table scan on every run — 1.2 GiB on this dataset. Consider `timestamp` strategy if scan cost becomes prohibitive.
**Baseline:** First run (2026-06-04) establishes the initial snapshot. History tracking begins from this point; no prior change history is captured.
**Source:** `ref('stg_products')`

## int_events_incremental
**Materialization:** Incremental, `insert_overwrite` strategy.  
**Partition:** `event_time`, data type `timestamp`, day granularity.  
**Incremental filter:** On each run, replaces partitions where `event_time >= MAX(event_time) - 3 days` from `{{ this }}`. The lookback window is anchored to the latest timestamp already in the table, not wall-clock time, so backfills and delayed runs behave correctly.  
**Why insert_overwrite:** `append` is not supported on the BigQuery dbt adapter (valid strategies: `merge`, `insert_overwrite`, `microbatch`). `insert_overwrite` is idempotent — reruns over the same window replace rather than duplicate partitions — and leverages BigQuery partition pruning to limit scan cost.  
**Production caveat:** `event_time` is occurrence time (when the user action happened), not ingestion time. A dedicated `ingested_at` column would be preferable in production: late-arriving events with old `event_time` values would be captured by a lookback on `ingested_at` rather than requiring a wider `event_time` window.  
**First run:** Full `CREATE TABLE` — 42.4M rows, 3.0 GiB processed. Incremental logic activates on subsequent runs.  
**Source:** `ref('stg_events')`

## mrt_conversion
**Grain:** One row per funnel transition (view→cart, cart→purchase).  
**Format:** Long format — each row represents one transition with `from_step`, `to_step`, and `conversion_rate` columns. Wide format was rejected because long format is more extensible (adding a funnel step adds a row, not a column) and more compatible with BI tool consumption.   
**Logic:** CTE computes distinct user counts per funnel step once. Two SELECTs reference the CTE — one per transition — stacked with UNION ALL. Order enforced via view_time < cart_time < purchase_time.  
**CTE rationale:** Aggregation runs once against 42M rows rather than twice. Both UNION ALL branches read from the cached result.  
**NULLIF:** Applied to both denominators to prevent divide-by-zero errors when a funnel step has zero users.  
**Source:** `ref('int_funnel')`  
**Data tests:** `not_null` and `accepted_values` on `from_step` and `to_step`; `not_null` on `conversion_rate`.

## Git
**Remote:** https://github.com/EgyptAmaru/ecommerce-behavior-analytics  
**Commit practice:** Commit after each build session with a meaningful message describing what was built.