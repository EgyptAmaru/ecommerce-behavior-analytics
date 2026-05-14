WITH step_counts AS (
    SELECT
        COUNT(DISTINCT user_id) AS view_count,
        COUNT(DISTINCT CASE WHEN view_time < cart_time THEN user_id END) AS cart_count,
        COUNT(DISTINCT CASE WHEN view_time < cart_time AND cart_time < purchase_time THEN user_id END) AS purchase_count
    FROM {{ ref('int_funnel') }}
)

SELECT 'view' AS from_step, 'cart' AS to_step,
    ROUND(CAST(cart_count AS NUMERIC) / NULLIF(view_count, 0) * 100, 1) AS conversion_rate
FROM step_counts

UNION ALL

SELECT 'cart' AS from_step, 'purchase' AS to_step,
    ROUND(CAST(purchase_count AS NUMERIC) / NULLIF(cart_count, 0) * 100, 1) AS conversion_rate
FROM step_counts