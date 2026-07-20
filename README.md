# Backblaze Drive Reliability Warehouse

**Status: in progress.** This is an active portfolio project, being built and
documented in public. Phases 1 and 2 (ingestion and core dbt build) are
complete and reconciled against Backblaze's own published data; later phases
are in progress. See the phase table below for the current state.

A dimensional reliability warehouse built with dbt over the Backblaze Drive
Stats public dataset: daily S.M.A.R.T. telemetry for every drive in
Backblaze's fleet.

Developed locally on DuckDB (handles 100M rows on a laptop, free), promoted to
Databricks by swapping the dbt profile. The transformation logic never
changes; that is the point of dbt. Power BI sits on the gold marts.

Single source of truth for design decisions: `BUILD_BLUEPRINT.md`.

## Architecture

```
Quarterly ZIP  ->  ingest/ingest_quarter.py (Python + DuckDB, no pandas on raw data)
                     unzip -> read_csv_auto(union_by_name) -> partitioned Parquet
                     -> reconcile row counts -> log schema drift -> delete CSVs
                ->  dbt (dbt-duckdb): staging -> intermediate -> dims -> facts -> marts
                ->  exports/ (gold as Parquet/CSV)  ->  Power BI (star schema + DAX)
```

## Layers

| Prefix | Layer | Purpose |
|---|---|---|
| `stg_` | staging | schema-drift contract, typing, quirk handling |
| `int_` | intermediate | per-drive spans, censoring logic |
| `dim_` | dimensions | drive, model, date |
| `fct_` | facts | drive-daily (incremental in Phase 3), failures |
| `mart_` | marts | fleet daily, AFR, cohort survival, trend/anomaly |

## Build phases

| Phase | Deliverable | Status |
|---|---|---|
| 1 | Ingestion ETL: one quarter to partitioned Parquet, reconciled | done |
| 2 | dbt core: staging, dims, facts, AFR mart, full test suite | build complete, AFR reconciled exactly against Backblaze's published Q1 2026 report|
| 3 | Scale to 80M+ rows, incremental models, benchmarks | not started |
| 4 | Cohort survival and trend/anomaly marts, findings | not started |
| 5 | Power BI star-schema dashboard | not started |
| 6 | Databricks target, CI, dbt docs | not started |

## Repo layout

```
ingest/    Python + DuckDB ingestion (Phase 1)
dbt/       dbt project (Phase 2+)
data/      raw ZIPs + partitioned Parquet (gitignored)
exports/   gold outputs for Power BI (gitignored)
analysis/  ad-hoc SQL kept for the writeup
powerbi/   .pbix dashboard
docs/      benchmarks, reconciliation_log, schema_drift_log, decisions, walkthroughs
```

## How to run: ingestion

```bash
# from repo root, with .venv active
python ingest/ingest_quarter.py --quarter 2026Q1

# optional: explicit zip path
python ingest/ingest_quarter.py --quarter 2026Q1 --zip data/raw/data_Q1_2026.zip
```

Idempotent: re-running overwrites the quarter's Parquet partition and
re-reconciles. A row-count mismatch between source CSV and written Parquet is
a hard failure.

## Setup

```bash
python -m venv .venv
.venv/Scripts/activate        # Windows
pip install -r requirements.txt
```
