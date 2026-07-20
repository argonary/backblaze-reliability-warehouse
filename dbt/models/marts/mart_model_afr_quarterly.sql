-- Annualized Failure Rate (AFR) per model per quarter, using Backblaze's
-- published methodology:
--
--     AFR% = failures / (drive_days / 365) * 100
--
-- drive_days is the count of fct_drive_daily rows for the model in the quarter
-- (one row = one drive observed for one day). We count fact rows per quarter
-- rather than summing dim_drive.drive_days because dim_drive.drive_days is a
-- drive's LIFETIME across all loaded quarters; counting the fact per quarter is
-- the correct per-quarter denominator and generalizes when Phase 3 adds quarters
-- (with a single quarter loaded the two are numerically identical).
--
-- Model and quarter are resolved by joining the facts through dim_drive
-- (serial_number -> model) and dim_date (date -> quarter_label), keeping the
-- mart a proper star-schema consumer rather than reaching back into staging.
--
-- Threshold (Backblaze's published Q1 2026 cutoff): a model is included only if
-- drive_count > 100 AND drive_days > 10,000. Models below the cutoff are
-- excluded from AFR reporting because their rates are statistically unstable.

with drive_days as (

    select
        drv.model,
        dt.quarter_label,
        count(*) as drive_days,
        count(distinct fdd.serial_number) as drive_count
    from {{ ref('fct_drive_daily') }} as fdd
    inner join {{ ref('dim_drive') }} as drv
        on fdd.serial_number = drv.serial_number
    inner join {{ ref('dim_date') }} as dt
        on fdd.snapshot_date = dt.date_day
    group by drv.model, dt.quarter_label

),

failures as (

    select
        drv.model,
        dt.quarter_label,
        count(*) as failures
    from {{ ref('fct_failures') }} as ff
    inner join {{ ref('dim_drive') }} as drv
        on ff.serial_number = drv.serial_number
    inner join {{ ref('dim_date') }} as dt
        on ff.failure_date = dt.date_day
    group by drv.model, dt.quarter_label

),

combined as (

    select
        drive_days.model,
        drive_days.quarter_label,
        drive_days.drive_count,
        drive_days.drive_days,
        coalesce(failures.failures, 0) as failures
    from drive_days
    left join failures
        on drive_days.model = failures.model
        and drive_days.quarter_label = failures.quarter_label

)

select
    combined.model || '|' || combined.quarter_label as model_quarter_key,
    combined.model,
    combined.quarter_label,
    dim_model.manufacturer,
    dim_model.capacity_class,
    combined.drive_count,
    combined.drive_days,
    combined.failures,
    round(combined.failures / (combined.drive_days / 365.0) * 100, 2) as afr_pct
from combined
inner join {{ ref('dim_model') }} as dim_model
    on combined.model = dim_model.model
-- data-drive scope: Backblaze's Drive Stats reports HDD data drives only, so we
-- exclude boot drives via the dim attribute (dim_model.drive_type) rather than
-- any model-name special-casing in this mart.
where dim_model.drive_type = 'data'
    and combined.drive_count > 100
    and combined.drive_days > 10000
