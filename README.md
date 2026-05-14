# Ecommerce Behavior Analytics

An end-to-end analytics engineering project modeling 42 million ecommerce events using dbt and BigQuery. Raw event data is transformed across three layers into sessionization, funnel conversion, and cohort retention models, with data quality tests at every stage.

## Stack

| Layer | Tools |
|---|---|
| Warehouse | BigQuery |
| Transformation | dbt Core 1.11.8 |
| Source Data | Kaggle — ecommerce-behavior-data-from-multi-category-store |
| Local Development | PostgreSQL |

## Project Structure

### Staging
| Model | Grain | Description |
|---|---|---|
| `stg_events` | One row per user action | Cleaned and selected columns from the raw events source. |

### Intermediate
| Model | Grain | Description |
|---|---|---|
| `int_sessions` | One row per event per session | Session IDs assigned using a 30-minute gap threshold. |
| `int_funnel` | One row per user | First timestamp per funnel step per user. |
| `int_cohorts` | One row per user | Cohort date, the day of each user's first event. |

### Marts
| Model | Grain | Description |
|---|---|---|
| `mrt_conversion` | One row per funnel transition | Conversion rates from view to cart and cart to purchase. |
| `mrt_retention` | One row per cohort | Daily retention counts for days 0 through 4. |

## Architecture Decisions

### Sessionization in the intermediate layer
Session ID assignment requires a business logic decision about what gap threshold defines a new session. That decision (30 minutes) lives in `int_sessions` so it can be changed in one place and propagate to all downstream models. Staging is reserved for cleaning; logic with a defensible alternative belongs in intermediate.

### Grain separation between intermediate and mart
`int_funnel` holds one row per user with first-event timestamps. Conversion rate calculations live in `mrt_conversion`. This separation means the funnel pivot logic is reusable: any mart model can reference `int_funnel` without reimplementing the pivot.

### Long format for mrt_conversion
The conversion model uses long format (one row per funnel transition) rather than wide format (one row with one column per rate). Long format is more extensible: adding a funnel step adds a row, not a column. It is also more compatible with BI tool consumption.

### Wide format for mrt_retention
The retention grid stays wide intentionally. The matrix structure with cohorts on rows and days on columns is the insight. Long format would require the consuming tool to pivot it back before it is readable, which is the wrong layer for that transformation.

### CTE in mrt_conversion
The conversion mart uses a CTE to compute distinct user counts once. Both UNION ALL branches read from the cached result rather than running the aggregation twice against 42 million rows.

### Data quality tests at every layer
Staging tests assert structural integrity of the source data. Intermediate tests confirm grain and business logic: `unique` on `int_cohorts.user_id` confirms one row per user, `not_null` on `int_funnel.view_time` confirms the funnel entry condition is enforced. Mart tests assert that pipeline outputs are complete and constrained to valid values using `accepted_values` on the step label columns in `mrt_conversion`.

## Data

**Source:** [ecommerce-behavior-data-from-multi-category-store](https://www.kaggle.com/datasets/mkechinov/ecommerce-behavior-data-from-multi-category-store) (Kaggle)  
**Scope:** October 2019, 42,448,764 events  
**Event types:** view, cart, purchase  
**Warehouse:** BigQuery (`ecommerce-behavior-analytics.raw.events`)

## Setup

**Requirements:** dbt Core 1.11.8, dbt-bigquery adapter, GCP service account with BigQuery Admin role.

**Activate environment and run:**

```bash
source ~/dbt-env/bin/activate
cd path/to/ecommerce_events
dbt run --profiles-dir .
dbt test --profiles-dir .
```

**Note:** Update `profiles.yml` with your GCP project name and service account key file path before running.
