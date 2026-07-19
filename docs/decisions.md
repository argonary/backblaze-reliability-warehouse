# Decisions (ADR-lite)

One line per judgment call. Newest at the bottom.

- 2026-07-19 — Ingestion keeps ALL 197 raw columns as-is (raw zone is raw); column curation to the SMART subset happens in dbt staging, not here (Blueprint Section 4 step 3).
- 2026-07-19 — Parquet is Hive-partitioned by `quarter` (`data/parquet/quarter=YYYYQN/`) to enable partition pruning in Phase 3; the `quarter` column is encoded in the path, not stored in the files.
- 2026-07-19 — Only `date`, `failure`, `capacity_bytes` are explicitly cast at ingestion (DATE / TINYINT / BIGINT). All other columns keep DuckDB's inferred types from a full-file type scan (`sample_size=-1`) so sparse SMART columns are typed correctly across schema drift.
- 2026-07-19 — Ingestion parquet compression is zstd (better ratio than snappy, fast enough) to stay within the ~15GB disk budget.
- 2026-07-19 — Q1 2026 actual row count (30,597,484) exceeded blueprint's ~27M estimate. No issue found; pre-run estimate was rough. Real number is what's used going forward in all benchmarks/reconciliation/resume citations.
- 2026-07-19 — dbt project created by writing config files directly (not interactive `dbt init`), because the `dbt/` folder skeleton from the Phase 1 scaffold already existed; `dbt init` would have nested a second project under it. `dbt debug` = all checks passed confirms the hand-authored setup is valid.
- 2026-07-19 — Parquet declared as a dbt-duckdb external source via `meta.external_location: read_parquet('../data/parquet/quarter=*/*.parquet', hive_partitioning = true)`. Relative path resolves against the `dbt/` working dir, so dbt must be invoked from `dbt/`. hive_partitioning exposes the path-encoded `quarter` column to the models.
- 2026-07-19 — Staging materialized as a `view` (not table): it is a thin rename/cast contract over the external Parquet, so a table copy would just duplicate 30.6M rows on disk for no query benefit at this scale. Revisit if downstream repeatedly rescans it.
- 2026-07-19 — `capacity_bytes` sentinel (<= 0) is FLAGGED at staging via a boolean `is_capacity_sentinel`, not repaired. Repair to modal capacity is deferred to dim_drive (Blueprint 5.2). Keeps staging a pure contract layer with no business logic.
- 2026-07-19 — Staging carries no grain-uniqueness test; per Blueprint 5.7 that test lives on fct_drive_daily. Any (serial_number, snapshot_date) dedupe is deferred to the fact layer so staging stays a faithful 1:1 mirror of the raw Parquet (row-parity test enforces this).
- 2026-07-19 — Source freshness declared with generous thresholds (warn 120d / error 400d) on `date`. The dataset is quarterly and historical, so freshness documents cadence rather than gating; it is not part of the `dbt build` completion gate.