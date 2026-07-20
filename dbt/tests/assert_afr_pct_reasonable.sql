-- Reasonableness bound on AFR (Blueprint Section 5.7). AFR% should sit within a
-- generous physical range; values outside it are worth a look but are NOT
-- necessarily errors (a real spike on a small population is legitimate), so this
-- is configured as a WARN, not a hard failure. Returns offending rows.

{{ config(severity='warn') }}

select
    model,
    quarter_label,
    drive_count,
    drive_days,
    failures,
    afr_pct
from {{ ref('mart_model_afr_quarterly') }}
where afr_pct < 0
    or afr_pct > 50
