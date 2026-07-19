# Decisions (ADR-lite)

One line per judgment call. Newest at the bottom.

- 2026-07-19 — Ingestion keeps ALL 197 raw columns as-is (raw zone is raw); column curation to the SMART subset happens in dbt staging, not here (Blueprint Section 4 step 3).
- 2026-07-19 — Parquet is Hive-partitioned by `quarter` (`data/parquet/quarter=YYYYQN/`) to enable partition pruning in Phase 3; the `quarter` column is encoded in the path, not stored in the files.
- 2026-07-19 — Only `date`, `failure`, `capacity_bytes` are explicitly cast at ingestion (DATE / TINYINT / BIGINT). All other columns keep DuckDB's inferred types from a full-file type scan (`sample_size=-1`) so sparse SMART columns are typed correctly across schema drift.
- 2026-07-19 — Ingestion parquet compression is zstd (better ratio than snappy, fast enough) to stay within the ~15GB disk budget.
- 2026-07-19 — Q1 2026 actual row count (30,597,484) exceeded blueprint's ~27M estimate. No issue found; pre-run estimate was rough. Real number is what's used going forward in all benchmarks/reconciliation/resume citations.