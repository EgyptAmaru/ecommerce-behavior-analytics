SELECT
    user_id,
    DATE_TRUNC(MIN(event_time), DAY) AS cohort_date
FROM {{ ref('stg_events') }}
GROUP BY user_id