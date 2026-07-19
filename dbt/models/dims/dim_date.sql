-- Calendar dimension covering exactly the date range present in the loaded
-- data (min..max snapshot_date), one row per day. Generated with a DuckDB
-- date spine (no dbt_utils dependency). quarter_label matches the Parquet
-- partition value format (e.g. '2026Q1') so it aligns with the raw partition
-- and downstream quarterly AFR grouping.

with bounds as (

    select
        min(snapshot_date) as min_date,
        max(snapshot_date) as max_date
    from {{ ref('stg_drive_stats') }}

),

spine as (

    select cast(
        unnest(
            generate_series(
                (select min_date from bounds),
                (select max_date from bounds),
                interval 1 day
            )
        ) as date
    ) as date_day

)

select
    date_day,
    extract(year from date_day) as year_number,
    extract(quarter from date_day) as quarter_number,
    cast(extract(year from date_day) as varchar)
        || 'Q'
        || cast(extract(quarter from date_day) as varchar) as quarter_label,
    extract(month from date_day) as month_number,
    strftime(date_day, '%B') as month_name,
    extract(day from date_day) as day_of_month,
    extract(dayofweek from date_day) as day_of_week,  -- 0 = Sunday
    strftime(date_day, '%A') as day_name,
    extract(dayofweek from date_day) in (0, 6) as is_weekend,
    extract(week from date_day) as week_of_year,
    extract(dayofyear from date_day) as day_of_year,
    cast(date_trunc('quarter', date_day) as date) as first_day_of_quarter,
    cast(date_trunc('month', date_day) as date) as first_day_of_month
from spine
