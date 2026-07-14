{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by={
            'field': 'event_time',
            'data_type': 'timestamp',
            'granularity': 'day'
        }
    )
}}

-- event_time is occurrence time (when the user action happened), not ingestion time.
-- A dedicated ingested_at column would be preferable in production: late-arriving
-- events with old event_times would be captured by a lookback on ingested_at rather
-- than requiring a longer event_time window.

SELECT
    event_time,
    event_type,
    category_id,
    price,
    user_id,
    user_session
FROM {{ ref('stg_events') }}

{% if is_incremental() %}
WHERE event_time >= (
    SELECT TIMESTAMP_SUB(MAX(event_time), INTERVAL 3 DAY)
    FROM {{ this }}
)
{% endif %}
