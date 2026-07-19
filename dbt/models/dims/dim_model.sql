-- One row per drive model string. Adds manufacturer (parsed from the model
-- prefix via the seed_manufacturer mapping), a capacity class label, and the
-- fleet drive count.
--
-- Manufacturer parsing uses a LONGEST-prefix match against the seed so that,
-- e.g., 'WDC ...' resolves via prefix 'WDC' rather than the shorter 'WD'.
-- Models matching no prefix fall through to 'Unknown' (surfaces new vendors
-- to add to the seed).

with staged as (

    select
        serial_number,
        model,
        capacity_bytes,
        is_capacity_sentinel
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

model_fleet as (

    select
        model,
        count(distinct serial_number) as fleet_drive_count
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
    model_fleet.fleet_drive_count
from model_manufacturer
left join model_capacity
    on model_manufacturer.model = model_capacity.model
inner join model_fleet
    on model_manufacturer.model = model_fleet.model
