# Backblaze — Session Primer
Last updated: 2026-07-19

## Phase status
- [x] Phase 1: ingestion, one quarter to parquet, reconciled
- [~] Phase 2: dbt core — staging + int_drive_spans built & tested. Dims/facts/AFR TODO.
- [ ] Phase 3: 80M+ rows, incremental, benchmarks
- [ ] Phase 4: cohort + trend/anomaly marts, findings.md
- [ ] Phase 5: Power BI dashboard
- [ ] Phase 6: Databricks target, CI, docs

## What was done last session (2026-07-19)
- Committed the Phase 2 staging scaffold: `1a05f94 feat: dbt project scaffold
  with parquet sources and staging contract` (dbt project, external Parquet
  source, stg_drive_stats + tests, docs). Confirmed only intended files staged.
- Built `int_drive_spans` (Blueprint Section 5.3) — one row per serial_number:
  - `first_seen` (min date), `last_seen` (max date), `observed_days` (count of
    daily rows; == distinct days given clean grain), `final_day_failure_flag`,
    and `censoring_status`.
  - Censoring logic (survival-analysis honesty; documented fully in the yml):
    `failed` (failure=1 on last observed day) / `exited_without_failure`
    (last_seen < dataset max date, no failure → right-censored, NOT a failure) /
    `active` (last_seen == dataset-wide max date → still observed, outcome
    unknown). CASE checks `failed` before `active` (failure wins on max date).
    `active` anchored to dataset-wide max(snapshot_date), not hardcoded.
  - Materialized as `table` (reused downstream; set in dbt_project.yml
    `intermediate: +materialized: table`).
  - Tests: not_null on serial_number/first_seen/last_seen/observed_days/
    final_day_failure_flag/censoring_status; unique on serial_number;
    accepted_values on censoring_status (3 values) and final_day_failure_flag
    (0,1); singular `assert_failure_only_on_last_seen.sql` (every failure row
    sits on that drive's last_seen).
- `dbt build` GREEN: PASS=18 (2 models + 16 tests), 0 errors, 0 warnings, ~13s
  cold / int model build 2.4s. Logged to docs/benchmarks.md.
- Censoring sanity (Q1 2026), logged to decisions.md: 351,095 drives =
  345,638 active + 4,427 exited_without_failure + 1,030 failed. `failed`
  reconciles EXACTLY to the 1,030 raw failures from Phase 1. observed_days 1–90.

## Phase 2 validation gates (Section 10) — status so far
- Gate 1 (dbt build zero errors/failures): PASS (staging + intermediate scope).
- Gate 2 (row reconciliation raw=parquet=staging): PASS (parity test green).
- Gate 3 (grain, zero dup serial+date): verified 0 dups; formal grain test lands
  on fct_drive_daily (Section 5.7). Still pending the fact.
- Gate 4 (AFR reconciliation): pending mart_model_afr_quarterly.
- Gate 5 (failure only on last_seen): PASS (assert_failure_only_on_last_seen).
- Gate 6 (referential integrity fact→dims): pending dims + facts.
- Gate 7 (benchmarks current): PASS.
- Gate 8 (defense walkthrough+quiz): pending end of Phase 2.

## Exact next action
Build the dimensions (Blueprint Section 5.4), starting with `dim_drive`
(grain = serial_number): model FK, repaired capacity (modal capacity_bytes,
fixing the <=0 sentinels flagged in staging via is_capacity_sentinel),
first/last seen + status + lifetime drive_days (from int_drive_spans). Then
`dim_model` (manufacturer parsed from model-string prefix — needs a seed mapping
table) and `dim_date`. Add the singular test "capacity positive after repair"
on dim_drive (Section 5.7). Run `dbt build`, keep it green; every model needs
tests + a yml description before it's done.

## Open blockers
None. Working tree is clean as of the staging commit; int_drive_spans + docs
updates are UNCOMMITTED (this checkpoint's work). Suggested next commit when
dims land (Section 11 cadence): `feat: dims and facts with generic test coverage`.
