-- Capacity positive after repair (Blueprint Section 5.7): every drive in
-- dim_drive must have a positive capacity once the sentinel (<= 0) values from
-- staging have been imputed. Returns offending rows only, which fails the test.

select
    serial_number,
    model,
    capacity_bytes
from {{ ref('dim_drive') }}
where capacity_bytes is null
    or capacity_bytes <= 0
