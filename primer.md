# Backblaze — Session Primer
Last updated: 2026-07-20

## Phase status
- [x] Phase 1: ingestion, one quarter to parquet, reconciled
- [~] Phase 2: dbt core COMPLETE + AFR reconciled EXACTLY (33/33). Only Gate 8 defense loop remains.
- [ ] Phase 3: 80M+ rows, incremental, benchmarks
- [ ] Phase 4: cohort + trend/anomaly marts, findings.md
- [ ] Phase 5: Power BI dashboard
- [ ] Phase 6: Databricks target, CI, docs

## Model DAG (complete for Phase 2)
raw (parquet) → stg_drive_stats (view) → int_drive_spans (table) → dim_drive (table)
seed_manufacturer → dim_model (table);  stg → dim_date (table)
stg → fct_drive_daily (table, → incremental P3);  stg → fct_failures (table)
facts + dims → mart_model_afr_quarterly (table)
macro: normalize_model (used by dim_drive + dim_model)

## What was done last session (2026-07-20)
- Committed the AFR mart's first build (309d8ee was facts; mart was uncommitted).
- Independent verification exposed that the mart, as first built, was a SUPERSET
  of Backblaze's HDD table: 43 rows incl. 9 SSD/boot models + a naming split, so
  raw fleet AFR was 1.23%, not 1.24%. Chose Option A: fix both causes UPSTREAM.
- Fix 1 — drive-type exclusion via a GENUINE source attribute (not a hardcoded
  list): raw data has no media-type column, but `pod_slot_num` is NULL for all 9
  boot/SSD models and populated for data drives. Added pod_slot_num to the
  staging contract; dim_model now derives `drive_type` ('data'/'boot'); the mart
  scopes to drive_type='data'. Correctly excludes the 2 boot HDDs a media filter
  would miss.
- Fix 2 — naming merge via `normalize_model` macro (strips WD's redundant 'WDC '
  prefix), applied in dim_drive + dim_model, merging the WUH721816ALE6L4 split
  once upstream. 0 Unknown manufacturers; dim_model 80→79 models.
- `dbt build` GREEN: PASS=81 (8 models + 72 tests + 1 seed), 0 errors, 0 WARN, ~55s.
- RE-VERIFIED with no post-hoc scoping: `mart_model_afr_quarterly` now returns
  DIRECTLY 33 models / drive_days 30,203,180 / failures 1,030 / fleet AFR 1.24%,
  and **all 33 models match Backblaze's published Q1 2026 table EXACTLY on
  drive_count, drive_days, failures, AFR% (33/33, digit-by-digit, 0 mismatches)**.
- Logs: reconciliation_log.md (dated correction note), decisions.md (3 lines),
  benchmarks.md. Committed (this checkpoint).

## Section 10 validation gates — Phase 2 status
| # | Gate | Status |
|---|------|--------|
| 1 | dbt build zero errors/failures | PASS (81/81) |
| 2 | Row reconciliation raw=parquet=staging=fact | PASS (30,597,484 through fct_drive_daily) |
| 3 | Grain, zero dup (serial,date) | PASS (unique on fct_drive_daily.drive_day_key) |
| 4 | AFR reconciliation vs published | PASS (33/33 EXACT, mart reproduces table directly) |
| 5 | Failure only on last_seen | PASS |
| 6 | Referential integrity fact→dims | PASS (all relationships tests green) |
| 7 | Benchmarks current | PASS |
| 8 | Defense walkthrough + quiz (Section 13) | NOT DONE — owner step, remains to close Phase 2 |

**7 of 8 gates PASS. dbt build of Phase 2 is done and AFR-reconciled; only the
Gate 8 defense loop remains before Phase 3.**

## Exact next action
Owner kicks off the Section 13 defense loop to close Gate 8: generate
docs/walkthroughs/phase_2.md (every model explained — what it does, why it
exists, what breaks without it), then an 8-10 question interview-style quiz;
owner answers; owner writes the public writeup. Only after Gate 8 passes may
Phase 3 (Section 6: ingest 2025Q4 → reconcile → convert fct_drive_daily to
incremental → benchmark) begin (CLAUDE.md hard rule).

## Open blockers
None. Working tree clean except untracked helper scripts check_phase2.py and
check_afr_mart.py (owner's verification scripts, intentionally untracked).
