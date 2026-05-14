SELECT
	*,
    SUM(new_session) OVER (
      PARTITION BY user_id
      ORDER BY event_time
    ) AS session_id
FROM (
  SELECT *,
  	 CASE
		WHEN previous_time is NULL then 1
  		WHEN TIMESTAMP_DIFF(event_time, previous_time, MINUTE) > 30 THEN 1 ELSE 0
      END AS new_session
  FROM (
    SELECT *,
     LAG(event_time) OVER (
      PARTITION BY user_id
      ORDER BY event_time ASC) AS previous_time
    FROM {{ ref('stg_events') }}
    ) t1 ) t2