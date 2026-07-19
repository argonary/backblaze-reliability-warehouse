# Backblaze Drive Reliability Warehouse

## What this is
dbt dimensional warehouse over Backblaze Drive Stats (daily drive telemetry).
Dev on DuckDB (dbt-duckdb), promote to Databricks at the end. Power BI on gold.
The blueprint is BUILD_BLUEPRINT.md — reference sections by name; do not re-derive
decisions that are already made there.

## Hard rules
- NEVER load raw CSVs with pandas. All raw-data ops go through DuckDB.
- Process one quarter at a time. Delete CSVs after Parquet conversion.
- Every pipeline or dbt run: append wall-clock time to docs/benchmarks.md.
- Every model gets tests and a yml description before it is "done".
- A task is complete only when `dbt build` passes.
- Judgment calls get one line in docs/decisions.md.
- Do not start a later phase until the current phase's validation gates
  (Blueprint Section 10) pass.

## Conventions
- Layers: stg_ / int_ / dim_ / fct_ / mart_
- One model per file; explicit column lists in staging (no SELECT *)
- SQL style: lowercase keywords, trailing commas, CTEs over subqueries

## Environment
- Windows machine; shell commands run in Git Bash
- Raw quarterly ZIPs live in data/raw/ (gitignored); Q1 2026 is already downloaded
- Python venv at .venv/

## Session rule
End of every session: rewrite primer.md completely — what was built, exact
phase status, single next action, open blockers. Then stop.
(A Stop hook enforces this: the session will not end cleanly until primer.md
has been rewritten today.)
