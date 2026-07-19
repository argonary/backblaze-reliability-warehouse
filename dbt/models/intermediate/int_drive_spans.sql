-- One row per drive (serial_number): its observed lifespan within the loaded
-- data, and the survival-analysis censoring classification. This is where the
-- honesty of any downstream survival/AFR work lives: a drive that stops
-- appearing is NOT the same as a drive that failed.
--
-- Censoring logic (three mutually exclusive states):
--   failed                  -> failure = 1 on the drive's last observed day
--   exited_without_failure  -> last observed before the dataset's max date, no
--                              failure flag (removed/migrated => right-censored)
--   active                  -> still observed on the dataset's max date (its
--                              outcome is unknown as of end of loaded data)
-- 'failed' is tested first so a drive that fails on the very last date of the
-- dataset is counted as a failure, not as active.

with staged as (

    select
        serial_number,
        snapshot_date,
        failure_flag
    from {{ ref('stg_drive_stats') }}

),

bounds as (

    -- dataset-wide max date across all loaded quarters (generalizes as more
    -- quarters are added in Phase 3).
    select max(snapshot_date) as dataset_max_date
    from staged

),

spans as (

    select
        serial_number,
        min(snapshot_date) as first_seen,
        max(snapshot_date) as last_seen,
        -- grain is clean (0 duplicate serial+date rows verified at build time),
        -- so count(*) == distinct days observed.
        count(*) as observed_days
    from staged
    group by serial_number

),

last_day as (

    -- failure flag on the drive's actual last observed day. failure = 1 only
    -- ever appears on that day (enforced by the singular test), so max() here
    -- resolves the flag on last_seen.
    select
        staged.serial_number,
        max(staged.failure_flag) as final_day_failure_flag
    from staged
    inner join spans
        on staged.serial_number = spans.serial_number
        and staged.snapshot_date = spans.last_seen
    group by staged.serial_number

)

select
    spans.serial_number,
    spans.first_seen,
    spans.last_seen,
    spans.observed_days,
    coalesce(last_day.final_day_failure_flag, 0) as final_day_failure_flag,
    case
        when coalesce(last_day.final_day_failure_flag, 0) = 1 then 'failed'
        when spans.last_seen < bounds.dataset_max_date then 'exited_without_failure'
        else 'active'
    end as censoring_status
from spans
cross join bounds
left join last_day
    on spans.serial_number = last_day.serial_number
