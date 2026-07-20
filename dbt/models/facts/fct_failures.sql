-- One row per failure event. Built from stg_drive_stats where failure_flag = 1:
-- Backblaze sets failure = 1 on a drive's final observed day, so each such row
-- IS a failure event, carrying the SMART sensor readings AS OF the failure day
-- (more useful for "what did the drive look like when it failed" than a drive-
-- level summary would be). Each drive fails at most once (verified: 0 drives
-- with >1 failure row), so serial_number is unique here and the count (1,030)
-- reconciles exactly with int_drive_spans censoring_status = 'failed'.
--
-- Foreign keys to dim_drive (serial_number) and dim_date (failure_date =>
-- date_day).

with failures as (

    select
        serial_number,
        snapshot_date as failure_date,
        smart_5_reallocated_sectors_raw,
        smart_187_reported_uncorrectable_raw,
        smart_188_command_timeout_raw,
        smart_197_pending_sectors_raw,
        smart_198_offline_uncorrectable_raw,
        smart_9_power_on_hours_raw,
        smart_194_temperature_celsius_raw
    from {{ ref('stg_drive_stats') }}
    where failure_flag = 1

)

select
    serial_number || '|' || cast(failure_date as varchar) as failure_event_key,
    serial_number,
    failure_date,
    smart_5_reallocated_sectors_raw,
    smart_187_reported_uncorrectable_raw,
    smart_188_command_timeout_raw,
    smart_197_pending_sectors_raw,
    smart_198_offline_uncorrectable_raw,
    smart_9_power_on_hours_raw,
    smart_194_temperature_celsius_raw
from failures
