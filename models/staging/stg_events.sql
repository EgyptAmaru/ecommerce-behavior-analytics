SELECT event_time, 
	  event_type,
	  category_id,
	  price,
	  user_id,
	  user_session
FROM {{ source('ecommerce', 'events') }}