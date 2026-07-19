# Schema Drift Log

On first ingestion of each quarter, the script introspects the actual CSV header
(`DESCRIBE SELECT * FROM read_csv_auto(...)`), diffs it against the previous quarter's
snapshot, and appends the diff here. Per-quarter column snapshots live in
`docs/schema_snapshots/`. This log is itself a portfolio artifact — it is the evidence
behind the staging schema-drift contract (Blueprint Section 5.2).

## 2026Q1 (logged 2026-07-19 11:30)

Baseline quarter — no prior snapshot to diff against.
Column count: 197.

