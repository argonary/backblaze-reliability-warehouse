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
| 2026-07-19 23:07 | dbt build | 2 | 16 | 18/18 | 13 | Added int_drive_spans (table). Model build 2.4s (aggregates 30.6M rows → 351,095 drives). |
| 2026-07-19 23:49 | dbt build | 5 | 43 | 49/49 | 22 | Added dim_drive/dim_model/dim_date (tables) + seed_manufacturer. dim_drive 11s (2 view scans). First correct run after replacing mode() with max() — see decisions. |
| 2026-07-20 00:01 | dbt build | 7 | 58 | 66/66 | 40 | Added fct_drive_daily + fct_failures (tables). Grain-uniqueness test on 30.6M-row drive_day_key ~10s; dim_drive 19s under concurrency. Facts verified to stream (projection 2.2s, write 1.7s). |
| 2026-07-20 00:16 | dbt build | 8 | 70 | 79/79 | 69 | Added mart_model_afr_quarterly (table) + AFR reasonableness warn-test. 0 warnings. Full Phase 2 build. AFR reconciled 33/33 vs published (reconciliation_log.md). |
| 2026-07-20 00:46 | dbt build | 8 | 72 | 81/81 | 55 | Upstream fixes: pod_slot_num→dim_model.drive_type, normalize_model macro (WDC/WUH merge). Mart now returns 33 rows / 1.24% directly, no post-hoc scoping. 0 warnings. |
