# Backblaze — Session Primer
Last updated: 2026-07-19

## Phase status
- [x] Phase 1: ingestion, one quarter to parquet, reconciled
- [~] Phase 2: dbt core — staging + int_drive_spans + 3 dims built & tested. Facts/AFR mart TODO.
- [ ] Phase 3: 80M+ rows, incremental, benchmarks
- [ ] Phase 4: cohort + trend/anomaly marts, findings.md
- [ ] Phase 5: Power BI dashboard
- [ ] Phase 6: Databricks target, CI, docs

## Model DAG so far
raw (parquet source) → stg_drive_stats (view) → int_drive_spans (table)
                                              ↘ dim_drive (table)
seed_manufacturer → dim_model (table);  stg → dim_date (table)

## What was done last session (2026-07-19)
- Committed int_drive_spans checkpoint: `252b53e feat: int_drive_spans
  intermediate model with censoring logic` (plus the observed_days-vs-span
  decisions.md line from independent verification). Left check_phase2.py
  (owner's ad-hoc verify script) untracked on purpose.
- Built the three dimensions (Blueprint Section 5.4), all materialized as tables:
  - `dim_drive` (grain serial_number): model FK, REPAIRED capacity_bytes,
    first_seen/last_seen, drive_days, status. Capacity repair imputes the drive's
    own non-sentinel capacity, falling back to its model's capacity if all rows
    were sentinels — guarantees positive capacity.
  - `dim_model` (grain model): manufacturer parsed from model prefix via
    seed_manufacturer (longest-prefix LIKE match), capacity_bytes, capacity_class
    (TB/GB label), fleet_drive_count.
  - `dim_date` (grain date_day): calendar + quarter attrs via a native DuckDB
    date spine; quarter_label 'YYYYQn' matches the parquet partition value.
  - Added seed `seeds/seed_manufacturer.csv` (prefix → manufacturer, 15 rows).
- Tests: not_null + unique PKs on all three dims; relationships
  dim_drive.model → dim_model.model; accepted_values on dim_drive.status and
  dim_date.quarter_number; singular `assert_dim_drive_capacity_positive.sql`
  (capacity positive after repair, Section 5.7).
- IMPORTANT FIX: initial dims used `mode()` for capacity/model repair → `dbt
  build` HUNG (>8 min, killed twice). Root cause: 3 concurrent holistic mode()
  aggregations over the 30.6M-row staging view. Verified model + non-sentinel
  capacity are constant per drive/model, so switched to `max()` (== modal here,
  but streams). Build dropped to ~22s. Logged in decisions.md.
- `dbt build` GREEN: PASS=49 (5 models + 43 tests + 1 seed), 0 errors, 0
  warnings, ~22s. Logged to benchmarks.md.
- Dim sanity (logged): dim_drive 351,095; dim_date 90 days; dim_model 80 models,
  0 Unknown manufacturer; fleet counts sum to 351,095 (Toshiba 117,902 /
  Seagate 116,850 / WDC 88,089 / HGST 27,005 / …).

## Phase 2 validation gates (Section 10) — status so far
- Gate 1 (dbt build zero errors/failures): PASS (through dims).
- Gate 2 (row reconciliation raw=parquet=staging): PASS.
- Gate 3 (grain, zero dup serial+date): verified 0 dups; formal grain test lands
  on fct_drive_daily. Pending the fact.
- Gate 4 (AFR reconciliation vs published): pending mart_model_afr_quarterly.
- Gate 5 (failure only on last_seen): PASS.
- Gate 6 (referential integrity fact→dims): dim_drive→dim_model PASS; fact→dims
  pending the facts.
- Gate 7 (benchmarks current): PASS.
- Gate 8 (defense walkthrough+quiz): pending end of Phase 2.

## Exact next action
Build the facts (Blueprint Section 5.5) — NEXT CHECKPOINT, do not start without
confirming:
  - `fct_drive_daily` (grain serial_number + date, `table` in Tier 1; becomes
    incremental in Phase 3). One row per drive-day; FKs to dim_drive and
    dim_date; carries failure_flag + curated SMART columns. Add grain-uniqueness
    test (unique on a surrogate of serial+date) and relationships tests to
    dim_drive and dim_date (Gate 3 + Gate 6).
  - `fct_failures` (one row per failure event; `table`).
Then Section 5.6 mart_model_afr_quarterly + 5.8 AFR reconciliation.

## Open blockers
None. This checkpoint's work (3 dims + seed + docs) is UNCOMMITTED in the
working tree. check_phase2.py remains untracked. Suggested next commit
(Section 11 cadence): `feat: dims and facts with generic test coverage` — but
per instruction that covers dims AND facts, so may wait until facts land, or
commit dims now as an interim. Ask owner.
