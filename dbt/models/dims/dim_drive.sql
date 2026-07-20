-- One row per physical drive (serial_number). Combines the observed lifespan
-- and censoring status from int_drive_spans with a repaired capacity.
--
-- Capacity repair (Blueprint quirk #1): staging FLAGS sentinel capacities
-- (<= 0) but does not fix them. Here we impute: use the drive's own non-sentinel
-- capacity, falling back to its model's capacity when every row for the drive
-- was a sentinel. This guarantees a positive capacity for every drive (enforced
-- by a singular test).
--
-- A drive's model and its (non-sentinel) capacity are constant across its life
-- (verified: 0 drives with >1 distinct model or capacity), so max() selects that
-- single value and equals the modal value — while streaming cheaply, unlike the
-- holistic mode() aggregate.

with staged as (

    select
        serial_number,
        model,
        capacity_bytes,
        is_capacity_sentinel
    from {{ ref('stg_drive_stats') }}

),

spans as (

    select
        serial_number,
        first_seen,
        last_seen,
        observed_days,
        censoring_status
    from {{ ref('int_drive_spans') }}

),

-- per-drive canonical model + own non-sentinel capacity (null if all-sentinel).
-- model is normalized (WDC prefix stripped) so it matches dim_model's key.
drive_attrs as (

    select
        serial_number,
        max({{ normalize_model('model') }}) as model,
        max(case when not is_capacity_sentinel then capacity_bytes end) as drive_capacity_bytes
    from staged
    group by serial_number

),

-- per-model non-sentinel capacity, used only as the fallback
model_capacity as (

    select
        {{ normalize_model('model') }} as model,
        max(capacity_bytes) as model_capacity_bytes
    from staged
    where not is_capacity_sentinel
    group by {{ normalize_model('model') }}

)

select
    drive_attrs.serial_number,
    drive_attrs.model,
    -- repaired: drive's own capacity, else its model's capacity (fallback)
    coalesce(
        drive_attrs.drive_capacity_bytes,
        model_capacity.model_capacity_bytes
    ) as capacity_bytes,
    spans.first_seen,
    spans.last_seen,
    spans.observed_days as drive_days,
    spans.censoring_status as status
from drive_attrs
inner join spans
    on drive_attrs.serial_number = spans.serial_number
left join model_capacity
    on drive_attrs.model = model_capacity.model
