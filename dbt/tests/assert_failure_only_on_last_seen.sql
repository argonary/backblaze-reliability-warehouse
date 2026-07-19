-- Failure logic (Blueprint Section 5.7 / Gate 5): a failure row must only ever
-- appear on a drive's actual last observed day. Backblaze sets failure = 1 on a
-- drive's final day, after which it disappears; any failure = 1 on an earlier
-- day would break the censoring classification in int_drive_spans and inflate
-- survival/AFR denominators. Returns offending rows only, which fails the test.

select
    stg.serial_number,
    stg.snapshot_date,
    spans.last_seen
from {{ ref('stg_drive_stats') }} as stg
inner join {{ ref('int_drive_spans') }} as spans
    on stg.serial_number = spans.serial_number
where stg.failure_flag = 1
    and stg.snapshot_date <> spans.last_seen
