-- One row per (canonical) drive model string. Adds manufacturer (parsed from
-- the model prefix via the seed_manufacturer mapping), a capacity class label,
-- the fleet drive count, and drive_type (data vs boot).
--
-- Model strings are normalized (WDC prefix stripped, see normalize_model macro)
-- so the same physical model is not split across rows.
--
-- Manufacturer parsing uses a LONGEST-prefix match against the seed so that,
-- e.g., 'WDC ...' resolves via prefix 'WDC' rather than the shorter 'WD'.
-- Models matching no prefix fall through to 'Unknown' (surfaces new vendors).
--
-- drive_type distinguishes DATA drives from BOOT drives using pod_slot_num, a
-- genuine source attribute: data drives occupy numbered pod slots, boot drives
-- do not (their slot is NULL). This reproduces Backblaze's boot-drive exclusion
-- (the correct criterion — it catches boot HDDs too, not just SSDs). A model is
-- 'data' if the majority of its observations carry a slot, else 'boot'.

with staged as (

    select
        serial_number,
        {{ normalize_model('model') }} as model,
        capacity_bytes,
        is_capacity_sentinel,
        pod_slot_num
    from {{ ref('stg_drive_stats') }}

),

distinct_models as (

    select distinct model
    from staged

),

manufacturer_match as (

    select
        distinct_models.model,
        mfr.manufacturer,
        row_number() over (
            partition by distinct_models.model
            order by length(mfr.model_prefix) desc
        ) as prefix_rank
    from distinct_models
    left join {{ ref('seed_manufacturer') }} as mfr
        on distinct_models.model like mfr.model_prefix || '%'

),

model_manufacturer as (

    select
        model,
        coalesce(manufacturer, 'Unknown') as manufacturer
    from manufacturer_match
    where prefix_rank = 1

),

-- capacity is constant per model (verified: 0 models with >1 distinct
-- non-sentinel capacity), so max() equals the modal capacity and streams cheaply.
model_capacity as (

    select
        model,
        max(capacity_bytes) as capacity_bytes
    from staged
    where not is_capacity_sentinel
    group by model

),

model_stats as (

    select
        model,
        count(distinct serial_number) as fleet_drive_count,
        -- 'data' if most observations carry a pod slot, else 'boot'
        case
            when count(pod_slot_num) >= 0.5 * count(*) then 'data'
            else 'boot'
        end as drive_type
    from staged
    group by model

)

select
    model_manufacturer.model,
    model_manufacturer.manufacturer,
    model_capacity.capacity_bytes,
    case
        when model_capacity.capacity_bytes is null then 'Unknown'
        when model_capacity.capacity_bytes < 1000000000000
            then cast(cast(round(model_capacity.capacity_bytes / 1e9) as bigint) as varchar) || 'GB'
        else cast(cast(round(model_capacity.capacity_bytes / 1e12) as bigint) as varchar) || 'TB'
    end as capacity_class,
    model_stats.fleet_drive_count,
    model_stats.drive_type
from model_manufacturer
left join model_capacity
    on model_manufacturer.model = model_capacity.model
inner join model_stats
    on model_manufacturer.model = model_stats.model
