{{
    config(
        materialized='view',
    )
}}

-- The schema-drift contract for the whole warehouse.
-- We select an explicit column list from the raw source rather than SELECT *:
--   - the five stable core columns, plus the curated predictive SMART subset
--   - columns absent in some quarters arrive as NULL (union_by_name at ingest)
--   - attributes added in future quarters are ignored until added here
-- Only renames and type casts happen here. capacity_bytes sentinels are FLAGGED,
-- not repaired (repair to modal capacity lives in dim_drive).

with source as (

    select
        date,
        serial_number,
        model,
        capacity_bytes,
        failure,
        smart_5_raw,
        smart_187_raw,
        smart_188_raw,
        smart_197_raw,
        smart_198_raw,
        smart_9_raw,
        smart_194_raw,
        quarter
    from {{ source('raw', 'drive_stats') }}

)

select
    -- core grain + identity
    cast(date as date) as snapshot_date,
    serial_number,
    model,

    -- capacity: sentinel (<= 0) flagged, not repaired (repair in dim_drive)
    capacity_bytes,
    capacity_bytes <= 0 as is_capacity_sentinel,

    -- failure event flag (1 only on the drive's final observed day)
    cast(failure as tinyint) as failure_flag,

    -- curated predictive S.M.A.R.T. subset (raw values only)
    smart_5_raw   as smart_5_reallocated_sectors_raw,
    smart_187_raw as smart_187_reported_uncorrectable_raw,
    smart_188_raw as smart_188_command_timeout_raw,
    smart_197_raw as smart_197_pending_sectors_raw,
    smart_198_raw as smart_198_offline_uncorrectable_raw,
    smart_9_raw   as smart_9_power_on_hours_raw,
    smart_194_raw as smart_194_temperature_celsius_raw,

    -- hive partition (path-encoded, exposed by hive_partitioning)
    quarter
from source
