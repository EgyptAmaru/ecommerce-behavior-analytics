SELECT *
FROM (
    SELECT user_id,
        {{ first_event_time('view') }},
        {{ first_event_time('cart') }},
        {{ first_event_time('purchase') }}
    FROM {{ ref('stg_events') }}
    GROUP BY user_id
) funnel
WHERE view_time IS NOT NULL
