SELECT
    product_id,
    category_id,
    brand
FROM {{ source('ecommerce', 'events') }}
WHERE product_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY event_time DESC) = 1
