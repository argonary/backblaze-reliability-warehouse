# Backblaze — Session Primer
Last updated: 2026-07-20

## Phase status
- [x] Phase 1: ingestion, one quarter to parquet, reconciled
- [~] Phase 2: dbt core — staging, int_drive_spans, 3 dims, 2 facts built & tested. AFR mart TODO.
- [ ] Phase 3: 80M+ rows, incremental, benchmarks
- [ ] Phase 4: cohort + trend/anomaly marts, findings.md
- [ ] Phase 5: Power BI dashboard
- [ ] Phase 6: Databricks target, CI, docs

## Model DAG so far
raw (parquet source) → stg_drive_stats (view) → int_drive_spans (table) → dim_drive (table)
seed_manufacturer → dim_model (table);  stg → dim_date (table)
stg → fct_drive_daily (table, → incremental in P3);  stg → fct_failures (table)
fct_drive_daily FK→ dim_drive, dim_date;  fct_failures FK→ dim_drive, dim_date

## What was done last session (2026-07-19 → 00:01 2026-07-20)
- Re-verified the mode()→max() fix independently: 0 drives have >1 distinct
  non-sentinel capacity, so max() is provably safe (constant, not just usual).
- Committed dims checkpoint: `806813d feat: dims (drive, model, date) with
  capacity repair and seed-based manufacturer mapping`. check_phase2.py stays
  untracked (owner's verify script).
- Built the facts (Blueprint Section 5.5), both `table`:
  - `fct_drive_daily` (grain serial_number + snapshot_date): surrogate
    drive_day_key, FKs to dim_drive + dim_date, failure_flag, 7 curated SMART
    raw columns. Table in Tier 1; converts to incremental in Phase 3.
  - `fct_failures` (one row per failure event): built from
    stg_drive_stats WHERE failure_flag = 1 (event grain + SMART-at-failure;
    logged rationale). FKs to dim_drive + dim_date.
- Tests: grain-uniqueness (unique on drive_day_key = Gate 3, deferred from
  staging to land here); relationships fct_drive_daily → dim_drive & dim_date,
  fct_failures → dim_drive & dim_date (Gate 6); not_null on FKs + failure_flag;
  accepted_values failure_flag (0,1); unique serial_number on fct_failures.
- Timed each step BEFORE the build (per instruction, given the mode() hang):
  projection scan 2.2s, CTAS write 1.7s, failure filters 0.1s — all streaming.
- `dbt build` GREEN: PASS=66 (7 models + 58 tests + 1 seed), 0 errors, 0
  warnings, ~40s. Grain-uniqueness test ~10s over 30.6M keys. Logged.
- Fact reconciliation (logged): fct_drive_daily = 30,597,484 == raw Parquet;
  failures triple-reconcile at 1,030 (fct_failures == int_spans 'failed' == sum
  fct_drive_daily.failure_flag); 0 orphan dates.

## Phase 2 validation gates (Section 10) — status
- Gate 1 (dbt build zero errors/failures): PASS (through facts).
- Gate 2 (row reconciliation raw=parquet=staging=fact): PASS (fct_drive_daily == 30,597,484).
- Gate 3 (grain, zero dup serial+date): PASS (unique on fct_drive_daily.drive_day_key).
- Gate 4 (AFR reconciliation vs published): PENDING — this is the next checkpoint.
- Gate 5 (failure only on last_seen): PASS.
- Gate 6 (referential integrity fact→dims): PASS (all 4 relationships tests green).
- Gate 7 (benchmarks current): PASS.
- Gate 8 (defense walkthrough+quiz): pending end of Phase 2.

## Exact next action
DEDICATED CHECKPOINT — do not start without owner review. Build Section 5.6
`mart_model_afr_quarterly` (the blueprint's "killer story"):
  - AFR per model per quarter = failures / (drive_days / 365) * 100.
  - drive_days = count of daily observations (sum fct_drive_daily rows or
    dim_drive.drive_days) per model per quarter; failures from fct_failures.
  - Exclude models below a minimum drive-day threshold — DOCUMENT the threshold
    in decisions.md (match Backblaze's report cutoff when reconciling).
  - Join through dim_model (manufacturer, capacity_class) and dim_date
    (quarter_label) as needed.
Then Section 5.8: reconcile computed AFR vs Backblaze's published Q1 2026 report
(fleet count, total failures, top-model AFR) → reconciliation_log.md, explain
mismatches in decisions.md (Gate 4).

## Open blockers
None. This checkpoint's work (2 facts + docs) is UNCOMMITTED in the working
tree; check_phase2.py still untracked. Suggested next commit (Section 11
cadence pairs dims+facts, but dims already shipped): a facts-only message such
as `feat: fct_drive_daily and fct_failures with grain and referential tests`.
Ask owner before committing.
