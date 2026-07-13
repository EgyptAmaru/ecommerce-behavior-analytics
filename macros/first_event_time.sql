{% macro first_event_time(event_type) %}
    MIN(CASE WHEN event_type = '{{ event_type }}' THEN event_time END) AS {{ event_type }}_time
{% endmacro %}
