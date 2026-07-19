-- Row-count parity (Blueprint Section 5.7): staged rows must equal the raw
-- Parquet the staging model reads from. No rows dropped or duplicated by the
-- contract. Returns rows only on mismatch, which fails the test.

with staged as (
    select count(*) as n_rows from {{ ref('stg_drive_stats') }}
),

raw_parquet as (
    select count(*) as n_rows from {{ source('raw', 'drive_stats') }}
)

select
    staged.n_rows as staged_rows,
    raw_parquet.n_rows as raw_rows
from staged
cross join raw_parquet
where staged.n_rows != raw_parquet.n_rows
