-- The central fact: one row per drive-day (serial_number + snapshot_date).
-- Foreign keys to dim_drive (serial_number) and dim_date (snapshot_date =>
-- date_day). Carries the failure event flag and the curated predictive SMART
-- measures from the staging contract.
--
-- Tier 1: materialized as a table. Phase 3 converts this to an incremental
-- model with a date-based filter (that conversion is the optimization story).
--
-- drive_day_key is a surrogate over the grain, used by the grain-uniqueness
-- test (Gate 3, deferred from staging to land here).

with staged as (

    select
        serial_number,
        snapshot_date,
        failure_flag,
        smart_5_reallocated_sectors_raw,
        smart_187_reported_uncorrectable_raw,
        smart_188_command_timeout_raw,
        smart_197_pending_sectors_raw,
        smart_198_offline_uncorrectable_raw,
        smart_9_power_on_hours_raw,
        smart_194_temperature_celsius_raw
    from {{ ref('stg_drive_stats') }}

)

select
    serial_number || '|' || cast(snapshot_date as varchar) as drive_day_key,
    serial_number,
    snapshot_date,
    failure_flag,
    smart_5_reallocated_sectors_raw,
    smart_187_reported_uncorrectable_raw,
    smart_188_command_timeout_raw,
    smart_197_pending_sectors_raw,
    smart_198_offline_uncorrectable_raw,
    smart_9_power_on_hours_raw,
    smart_194_temperature_celsius_raw
from staged
