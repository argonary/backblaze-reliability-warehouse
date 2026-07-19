# Backblaze — Session Primer
Last updated: 2026-07-19

## Phase status
- [x] Phase 1: ingestion, one quarter to parquet, reconciled
- [~] Phase 2: dbt core — staging built + tested (checkpoint). Dims/facts/AFR still TODO.
- [ ] Phase 3: 80M+ rows, incremental, benchmarks
- [ ] Phase 4: cohort + trend/anomaly marts, findings.md
- [ ] Phase 5: Power BI dashboard
- [ ] Phase 6: Databricks target, CI, docs

## What was done last session (2026-07-19)
Phase 2 Section 5.1 + 5.2 (staging only — stopped at the agreed checkpoint):
- Created the dbt project by hand under `dbt/` (files written directly, not
  interactive `dbt init`, since the scaffold folders already existed):
  - `dbt/dbt_project.yml` — profile `backblaze`, staging `+materialized: view`.
  - `dbt/profiles.yml` — duckdb target, `path: warehouse.duckdb` (relative to
    `dbt/`; ALWAYS run dbt from inside `dbt/`). `dbt debug` = all checks passed.
- Declared the Parquet as a dbt-duckdb external source
  (`dbt/models/staging/_staging__sources.yml`): source `raw`, table
  `drive_stats`, `meta.external_location: read_parquet('../data/parquet/quarter=*/*.parquet',
  hive_partitioning = true)`. hive_partitioning exposes the `quarter` column.
  Source + table descriptions written; freshness declared (warn 120d/error 400d
  on `date`, informational only — not a build gate).
- Built `stg_drive_stats` (Section 5.2 schema-drift contract): explicit column
  list (no SELECT *) = 5 core cols + curated SMART subset
  (5/187/188/197/198/9/194 _raw), renamed to warehouse conventions, typed.
  `capacity_bytes` sentinel FLAGGED via `is_capacity_sentinel` (repair deferred
  to dim_drive). Materialized as a view. Full column-level yml descriptions.
- Tests (Section 5.7, staging subset): `not_null` on snapshot_date /
  serial_number / model / failure_flag; `accepted_values` failure_flag in (0,1);
  singular `assert_row_parity_stg_drive_stats.sql` (staged count == raw parquet).
- `dbt build` GREEN: PASS=7 (1 model + 6 tests), 0 errors, 0 warnings, ~6s warm.
- Logged: docs/benchmarks.md (Phase 2 section), docs/decisions.md (7 new lines).
- Staged content sanity == Phase 1: 30,597,484 rows, 351,095 drives,
  2026-01-01..2026-03-31, 1,030 failures, 0 capacity sentinels, 1 quarter.

## Phase 2 validation gates (Section 10) — status so far
- Gate 1 (dbt build zero errors/failures): PASS (staging scope only).
- Gate 2 (row reconciliation raw=parquet=staging): PASS (parity test green).
- Gate 3 (grain, zero dup serial+date): NOT YET — grain test lives on
  fct_drive_daily per 5.7; deferred to fact layer. Verify then.
- Gates 4/5/6 (AFR / failure logic / referential integrity): pending dims+facts+mart.
- Gate 7 (benchmarks current): PASS.
- Gate 8 (defense walkthrough+quiz): pending end of Phase 2.

## Exact next action
Build the intermediate model `int_drive_spans` (Blueprint Section 5.3): one row
per serial_number with first_seen, last_seen, observed_days, final-day failure
flag, and censoring classification (`failed` / `exited_without_failure` /
`active` as of max date). Document the censoring logic in its yml. Then proceed
to dims (5.4). Keep running `dbt build` after each model; every model needs
tests + a yml description before it's "done".

## Open blockers
None. Uncommitted: the whole dbt/ scaffold + staging + docs updates are staged
in the working tree, NOT yet committed. Suggested commit (Section 11 cadence):
`feat: dbt project scaffold with parquet sources and staging contract`.
