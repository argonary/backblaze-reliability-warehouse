# Reconciliation Log

Two kinds of reconciliation live here:
1. **Row parity** (Phase 1): raw CSV row count vs written Parquet row count. Mismatch = hard failure.
2. **AFR vs published** (Phase 2): fleet count, failures, and per-model AFR vs Backblaze's published quarterly report.

## Phase 1 — Row parity (CSV vs Parquet)

| Timestamp | Quarter | CSV rows | Parquet rows | Delta | Result |
|---|---|---|---|---|---|
| 2026-07-19 11:43 | 2026Q1 | 30,597,484 | 30,597,484 | +0 | PASS |
| 2026-07-19 12:00 | 2026Q1 | 30,597,484 | 30,597,484 | +0 | PASS |
