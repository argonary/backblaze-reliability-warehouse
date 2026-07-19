# Backblaze — Session Primer
Last updated: 2026-07-19

## Phase status
- [x] Phase 1: ingestion, one quarter to parquet, reconciled
- [ ] Phase 2: dbt core, tests green, AFR reconciled
- [ ] Phase 3: 80M+ rows, incremental, benchmarks
- [ ] Phase 4: cohort + trend/anomaly marts, findings.md
- [ ] Phase 5: Power BI dashboard
- [ ] Phase 6: Databricks target, CI, docs

## What was done last session (2026-07-19)
- Verified toolchain: dbt-core 1.12.0, dbt-duckdb 1.10.1, duckdb 1.5.4.
- Finished repo scaffold per Blueprint Section 3: folder skeleton (ingest/, dbt/
  model dirs, analysis/, powerbi/, exports/, docs/), README.md, and the four
  docs logs (benchmarks, reconciliation_log, schema_drift_log, decisions).
- Built `ingest/ingest_quarter.py` (Blueprint Section 4): unzip -> DuckDB
  `read_csv_auto(union_by_name, sample_size=-1)` -> Hive-partitioned Parquet at
  `data/parquet/quarter=YYYYQN/`; casts date/failure/capacity_bytes; keeps all
  197 raw columns; schema-drift snapshot+diff; row-parity reconciliation
  (hard-fail on mismatch); benchmark logging; temp cleanup. No pandas.
- Ran it on Q1 2026 TWICE (idempotent, clean both times):
  - 30,597,484 rows, 90 files, 11.19GB CSV -> 0.85GB Parquet, ~817s then ~754s.
  - Reconciliation PASS (CSV 30,597,484 == Parquet 30,597,484, delta +0).
  - Content sanity: 351,095 distinct drives, dates 2026-01-01..2026-03-31,
    1,030 failures, 0 rows with capacity_bytes <= 0.
- Logs written: docs/benchmarks.md, docs/reconciliation_log.md,
  docs/schema_drift_log.md (baseline, 197 cols), docs/schema_snapshots/2026Q1.txt.

## Phase 1 validation gates (Section 10)
- Gate 1 (dbt build): N/A until Phase 2.
- Gate 2 (row reconciliation CSV=Parquet): PASS.
- Gate 7 (benchmarks current): PASS.
- Gate 8 (defense walkthrough+quiz): NOT DONE — owner still owes the Phase 1
  defense loop (Section 13) before formally closing the phase.

## Exact next action
Begin Phase 2 (Blueprint Section 5.1): `dbt init` a project under dbt/ with a
duckdb profile pointing at a local warehouse.duckdb, then declare the Parquet as
a dbt source with `external_location`
'data/parquet/quarter=*/*.parquet' (hive_partitioning). Then build
`stg_drive_stats` as the explicit schema-drift column contract (Section 5.2:
core columns + curated SMART subset only, no SELECT *).

## Open blockers
None. (Databricks/Power BI are later phases; no action needed now.)
