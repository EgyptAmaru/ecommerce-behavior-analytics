SELECT *
FROM (
    SELECT user_id,
        MIN(CASE WHEN event_type = 'view' THEN event_time END) AS view_time,
        MIN(CASE WHEN event_type = 'cart' THEN event_time END) AS cart_time,
        MIN(CASE WHEN event_type = 'purchase' THEN event_time END) AS purchase_time
    FROM {{ ref('stg_events') }}
    GROUP BY user_id
) funnel
WHERE view_time IS NOT NULL