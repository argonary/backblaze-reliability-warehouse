# Benchmarks

Every pipeline run and dbt run gets a wall-clock entry here, from day one.
Numbers in resume bullets come only from this file, reconciliation_log.md, and findings.md.

## Phase 1 — Ingestion (ingest_quarter.py)

| Timestamp | Quarter | Rows | CSV files | GB in | GB out | Wall-clock (s) |
|---|---|---|---|---|---|---|
| 2026-07-19 11:43 | 2026Q1 | 30,597,484 | 90 | 11.19 | 0.85 | 816.9 |
| 2026-07-19 12:00 | 2026Q1 | 30,597,484 | 90 | 11.19 | 0.85 | 754.4 |

## Phase 2 — dbt build

`dbt build` = build all models + run all tests. Staging materialized as a view
over the external Parquet, so the model itself is ~0.3s; the numbers below are
dominated by test scans over 30.6M rows.

| Timestamp | Command | Models | Tests | PASS | Wall-clock (s) | Notes |
|---|---|---|---|---|---|---|
| 2026-07-19 22:54 | dbt build | 1 | 6 | 7/7 | 13 | Staging only. First run (full parse, no partial-parse cache). |
| 2026-07-19 22:55 | dbt build | 1 | 6 | 7/7 | 6 | Staging only. Warm parse cache; accepted_values arg-nesting warning cleared. |
