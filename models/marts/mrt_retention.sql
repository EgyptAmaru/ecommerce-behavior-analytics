SELECT 
	cohort,
	COUNT (DISTINCT CASE WHEN days_since = 0 THEN user_id END) day_0_count,
	COUNT (DISTINCT CASE WHEN days_since = 1 THEN user_id END) day_1_count,
	COUNT (DISTINCT CASE WHEN days_since = 2 THEN user_id END) day_2_count, 
	COUNT (DISTINCT CASE WHEN days_since = 3 THEN user_id END) day_3_count,
	COUNT (DISTINCT CASE WHEN days_since = 4 THEN user_id END) day_4_count
FROM (
	SELECT 
		e.user_id,
		cohort_date AS cohort,
		DATE_DIFF(DATE(event_time), DATE(cohort_date), DAY) AS days_since
	FROM {{ ref('stg_events') }} e
	JOIN {{ ref('int_cohorts') }} c ON e.user_id = c.user_id) activity
GROUP BY cohort