# Backblaze Drive Reliability Warehouse
## Master Build Blueprint & Technical Specification

**dbt + DuckDB (dev) → Databricks (promote) · Power BI · 6 build phases**

> **Status:** This is the master document and single source of truth. Claude Code sessions
> should reference sections of this file by name rather than re-deriving decisions.

---

# 1. Project overview and goals

An analytics engineering portfolio project: a dimensional reliability warehouse built with
dbt over the Backblaze Drive Stats public dataset (daily S.M.A.R.T. telemetry snapshots for
every drive in Backblaze's fleet, published quarterly since 2013).

The project exists to earn a specific set of resume bullets. Every phase maps to bullet
tags (Section 14). If work does not serve a bullet, it is out of scope.

**Build philosophy: finish line first.** A fully tested dbt project on DuckDB with one
quarter of data is worth more than a half-built lakehouse with ten quarters. Scale and
Databricks come only after the core works end to end.

**Defense rule (non-negotiable):** a phase is not complete until the owner can explain
every model in it without notes. Each phase ends with Claude Code generating a walkthrough
and quiz (Section 13). This project's value is interview defense, not the code.

## The three-tier build plan

| Tier | What you build | Engine | Status |
|---|---|---|---|
| 1 — Core | Ingestion → Parquet → dbt project (staging, dims, facts, marts) with full test suite and AFR reconciliation, on ONE quarter | DuckDB via dbt-duckdb | Build first. Non-negotiable. |
| 2 — Scale + BI | Add quarters to 80M+ rows, incremental models, benchmarks, analytics marts, Power BI dashboard | DuckDB | After Tier 1 checklist passes |
| 3 — Promote + polish | Swap profile to Databricks Free Edition, CI, dbt docs, writeup | Databricks | Last. Profile swap, not rebuild. |

## Why the engine is swappable

All transformation logic lives in dbt models. dbt-duckdb and dbt-databricks share the same
project structure; promotion means adding a new target in `profiles.yml` and fixing minor
SQL dialect differences. Nothing structural changes.

Interview framing: "I developed locally on DuckDB because it handles 100M rows on a laptop
for free, then promoted to Databricks by swapping the dbt profile. The models didn't
change — that's the point of dbt."

## What this project demonstrates

- ETL/ELT engineering — real multi-gigabyte raw data, ingested and landed as partitioned Parquet
- dbt craft — dimensional modeling, tests, docs, incremental materializations, lineage
- Data quality and integrity — validation as code, reconciliation against published ground truth
- Query optimization — measured, logged, before/after runtimes
- Analytics — AFR, cohort survival, trend and anomaly detection
- BI delivery — Power BI star-schema semantic model with DAX measures

---

# 2. The dataset

**Source:** https://www.backblaze.com/cloud-storage/resources/hard-drive-test-data
Quarterly ZIP files of daily CSVs. One CSV per day; one row per operational drive per day.

**Grain:** drive-day (`serial_number` + `date`).

**Core columns (stable across all eras):**

| Column | Type | Notes |
|---|---|---|
| date | DATE | Snapshot date |
| serial_number | VARCHAR | Drive identity. Grain key with date |
| model | VARCHAR | Manufacturer model string (e.g. ST12000NM0008) |
| capacity_bytes | BIGINT | Known quirk: occasionally -1 or 0 (sentinel/error). Must be handled |
| failure | INTEGER | 0 or 1. Set to 1 only on the drive's final day, then the drive disappears |

**S.M.A.R.T. columns:** pairs of `smart_N_normalized` and `smart_N_raw` for many attribute
numbers. **This is where schema drift lives** — the column set has grown over the years
(roughly 90 columns in 2013 to 175+ in recent quarters) as new attributes were added.

**Curated S.M.A.R.T. subset** (the only ones carried past staging; all else dropped):

| Attribute | Meaning | Why it matters |
|---|---|---|
| smart_5_raw | Reallocated sector count | One of Backblaze's five failure-predictive attributes |
| smart_187_raw | Reported uncorrectable errors | Predictive |
| smart_188_raw | Command timeout | Predictive |
| smart_197_raw | Current pending sector count | Predictive |
| smart_198_raw | Offline uncorrectable | Predictive |
| smart_9_raw | Power-on hours | Drive age; enables vintage/cohort analysis |
| smart_194_raw | Temperature (Celsius) | Range-testable; good for anomaly work |

> **Verification rule for Claude Code:** do NOT hardcode the column list from this
> document. On first ingestion of each quarter, introspect the actual CSV header
> (`DESCRIBE SELECT * FROM read_csv_auto(...)`), diff it against the previous quarter,
> and append the diff to `docs/schema_drift_log.md`. That log is itself a portfolio
> artifact.

**Known data quirks to handle explicitly (each becomes a test or documented decision):**

1. `capacity_bytes` of -1 or 0 on some rows → coalesce from the drive's modal capacity in `dim_drive`
2. Rare duplicate serial numbers across models → grain test on (serial_number, date), dedupe rule documented
3. Drives that disappear without a failure flag → censored observations (removed/migrated), not failures. Critical for honest survival analysis
4. A failed drive's final-day row may contain nulls in some SMART fields → tests must tolerate this
5. Schema drift → staging contract (Section 5)

**Scale plan:** Start with Q1 2026 only (~27M rows, ~10GB CSV, ~1GB Parquet). Tier 2
extends backwards one quarter at a time until total rows exceed 80M (approximately 3-4
quarters). Do not download more than one quarter ahead of need. Delete CSVs after
Parquet conversion. Disk budget: ~15GB peak during a single quarter's conversion.

---

# 3. Architecture

```
Quarterly ZIP (manual or scripted download)
        │
        ▼
ingest/ingest_quarter.py          ← Python + DuckDB. No pandas on raw data. Ever.
  - unzip to temp
  - read_csv_auto(union_by_name=true), normalize types
  - write data/parquet/quarter=YYYYQN/*.parquet   (partitioned)
  - log source row count + parquet row count to docs/reconciliation_log.md
  - delete CSVs and temp
        │
        ▼
dbt project (dbt-duckdb)
  sources:   parquet files as external source
  staging:   stg_drive_stats           (schema-drift contract, typing, quirk handling)
  intermediate: int_drive_spans        (per-drive first/last seen, censoring logic)
  dims:      dim_drive · dim_model · dim_date
  facts:     fct_drive_daily (incremental) · fct_failures
  marts:     mart_fleet_daily · mart_model_afr_quarterly ·
             mart_cohort_survival · mart_trend_anomaly
        │
        ▼
exports/ (gold marts as Parquet/CSV)  →  Power BI Desktop (star schema + DAX)
```

Repository layout:

```
backblaze-reliability-warehouse/
├── README.md
├── CLAUDE.md                  # static charter (Section 12)
├── primer.md                  # living handoff, rewritten each session
├── memory.sh                  # git-state injection at session start
├── requirements.txt           # dbt-core, dbt-duckdb, duckdb
├── .gitignore                 # data/, exports/, *.duckdb
├── ingest/
│   └── ingest_quarter.py
├── data/                      # gitignored
│   └── parquet/quarter=.../
├── dbt/
│   ├── dbt_project.yml
│   ├── profiles.yml           # duckdb target + databricks target (Tier 3)
│   ├── models/
│   │   ├── staging/
│   │   ├── intermediate/
│   │   ├── dims/
│   │   ├── facts/
│   │   └── marts/
│   ├── tests/                 # custom singular tests
│   └── macros/
├── analysis/                  # ad-hoc SQL kept for the writeup
├── exports/                   # gitignored gold outputs for Power BI
├── powerbi/                   # .pbix file
└── docs/
    ├── benchmarks.md          # every runtime, from day one
    ├── reconciliation_log.md  # row counts + AFR vs published
    ├── schema_drift_log.md
    └── decisions.md           # one line per judgment call (ADR-lite)
```

---

# 4. Phase 1 — Ingestion ETL

*Python + DuckDB · one quarter · target: 1-2 days*

**Deliverable:** `ingest/ingest_quarter.py` — idempotent, parameterized by quarter.

Spec:

1. Accept `--quarter 2026Q1` and a path to the downloaded ZIP (scripting the download is optional polish; manual download is fine)
2. Unzip to a temp directory
3. Single DuckDB statement: `COPY (SELECT ... FROM read_csv_auto('tmp/*.csv', union_by_name=true)) TO 'data/parquet/quarter=2026Q1' (FORMAT PARQUET, ...)`
   - Cast `date` to DATE, `failure` to TINYINT, `capacity_bytes` to BIGINT
   - Keep ALL columns at this layer (raw zone is raw); curation happens in dbt staging
4. Reconciliation: count rows in source CSVs and in written Parquet; both go to `docs/reconciliation_log.md` with a PASS/FAIL. Mismatch = hard failure
5. Record wall-clock time for the run in `docs/benchmarks.md`
6. Delete CSVs and temp directory
7. Print a one-line summary: quarter, rows, files, seconds, GB in → GB out

**Definition of done:** script runs clean twice (idempotent), reconciliation PASS,
benchmark logged, committed.

---

# 5. Phase 2 — dbt core build (the heart of the project)

*dbt-duckdb · staging → dims → facts → AFR mart · target: 3-4 days*

## 5.1 Setup

- `dbt init` with duckdb profile pointing at a local `warehouse.duckdb`
- Parquet declared as a dbt source with `external_location`
- Freshness/metadata description on the source

## 5.2 Staging: `stg_drive_stats` — the schema-drift contract

The design decision that anchors the whole project: **staging selects an explicit,
documented column contract** (core columns + curated SMART subset from Section 2) rather
than `SELECT *`. Columns missing in older quarters surface as NULL via `union_by_name`;
columns added in future quarters are ignored until deliberately added to the contract.

Also in staging:
- Type casts and column renames to warehouse conventions
- `capacity_bytes` sentinel handling flagged (repair happens in dim_drive)
- Deduplication on grain with a documented keep-rule, if the grain test ever fails

## 5.3 Intermediate: `int_drive_spans`

One row per serial_number: first_seen, last_seen, observed_days, final-day failure flag,
censoring classification (`failed` vs `exited_without_failure` vs `active` as of max date).
This model is where the survival-analysis honesty lives; document the censoring logic
in its yml description.

## 5.4 Dimensions

| Model | Grain | Key content |
|---|---|---|
| dim_drive | serial_number | model FK, repaired capacity (modal), first/last seen, status, lifetime drive_days |
| dim_model | model | manufacturer (parsed from model-string prefix; mapping table in a seed), capacity class, fleet count |
| dim_date | date | calendar + quarter attributes; generated with a dbt utility macro or seed |

## 5.5 Facts

| Model | Grain | Materialization |
|---|---|---|
| fct_drive_daily | serial_number + date | `table` in Tier 1; converted to `incremental` in Phase 3 (that conversion IS the optimization story) |
| fct_failures | one row per failure event | table |

## 5.6 Mart: `mart_model_afr_quarterly`

AFR per model per quarter using Backblaze's published methodology:

```
AFR = failures / (drive_days / 365) * 100
```

drive_days = count of daily observations. Exclude models below a minimum drive-day
threshold (document the threshold in decisions.md; Backblaze uses a cutoff in their
reports — match it when reconciling).

## 5.7 Test suite (minimum bar)

| Test | Type | Target |
|---|---|---|
| Grain uniqueness | generic (unique on surrogate of serial+date) | fct_drive_daily |
| not_null | generic | all keys, date, failure |
| accepted_values failure in (0,1) | generic | staging |
| relationships fct → dim_drive, fct → dim_date | generic | facts |
| smart_194 temperature within physical bounds | singular | staging |
| capacity positive after repair | singular | dim_drive |
| failure rows exist only on last_seen date | singular | int_drive_spans |
| row count parity staging vs raw parquet | singular | staging |

Every model gets a description in its `.yml`. No exceptions — this is the docs bullet.

## 5.8 Reconciliation against published ground truth (the killer story)

Backblaze publishes quarterly Drive Stats reports with computed AFR per model and fleet
drive counts. Protocol:

1. Fetch the published report for each loaded quarter (blog post / table)
2. Compare: fleet drive count, total failures, AFR for the top ~10 models by drive_days
3. Log each comparison in `docs/reconciliation_log.md` with delta and PASS (within
   tolerance) / INVESTIGATE
4. Investigate every mismatch; the explanation (e.g. their minimum drive-day cutoff,
   their handling of a specific model) goes in decisions.md. **Mismatches you can
   explain are worth more in interviews than perfect matches.**

**Definition of done:** `dbt build` green (all models + all tests), AFR reconciliation
logged for the loaded quarter, lineage graph renders via `dbt docs generate`, owner can
whiteboard the DAG from memory.

---

# 6. Phase 3 — Scale and optimization

*Extend to 80M+ rows · incremental models · benchmarks · target: 2-3 days*

1. Ingest additional quarters ONE AT A TIME (2025Q4, 2025Q3, ... until > 80M rows),
   running the Phase 1 script and reconciliation for each; append schema diffs to the
   drift log
2. **Before converting anything, benchmark the baseline:** full `dbt build` wall-clock
   at full scale, plus 3 representative analytical queries. Log to benchmarks.md
3. Convert `fct_drive_daily` to `materialized='incremental'` with a date-based filter
   and appropriate `incremental_strategy`; re-run and log the delta
4. Optimization experiments (each one = benchmark entry + one line in decisions.md):
   - Parquet partition pruning: query one month with/without partition filter
   - Window function vs self-join formulation of a rolling metric
   - DuckDB `EXPLAIN ANALYZE` on the worst query; act on what it shows
5. Target artifact: a benchmarks.md table that directly feeds the #query-optimization
   bullets ("cut build time X%", "reduced query from Xs to Ys")

**Definition of done:** ≥80M rows loaded and reconciled, incremental model proven
(second run touches only new partitions), benchmarks.md has real before/after numbers.

---

# 7. Phase 4 — Analytics marts

*Cohort survival · trend · anomaly detection · target: 2-3 days*

## 7.1 `mart_cohort_survival`

Cohort = model (and optionally deployment-vintage quarter). For each cohort and
drive-age bucket (e.g. 90-day buckets of power-on age or observed age): drives at risk,
failures, cumulative survival proportion. Censored drives exit the risk set without
counting as failures (uses int_drive_spans classification). This is deliberately framed
as **cohort analysis** — the same mechanics as customer retention cohorts.

## 7.2 `mart_trend_anomaly`

- Rolling 30-day failure rate per model (window functions over fct_drive_daily aggregates)
- Anomaly flag: rolling rate vs trailing baseline mean ± 3 standard deviations
  (SPC-style control limits — connect to statistical process control vocabulary in the
  writeup)
- Same treatment on fleet-average temperature (smart_194) as a second, sensor-flavored
  anomaly example

## 7.3 Findings document

`analysis/findings.md`: 3-5 concrete findings with the SQL that produced them
(e.g. "model X shows Nx fleet-average AFR", "cohort vintage Y degrades faster after
Z days"). These become resume-bullet numbers and interview stories. Findings must be
re-derivable by running the saved SQL.

**Definition of done:** both marts tested and documented, findings.md written by the
owner (not generated), at least one finding with a specific number.

---

# 8. Phase 5 — Power BI

*Star-schema semantic model + DAX · Power BI Desktop · target: 2 days*

1. Export gold layer (dims + marts + a filtered fact aggregate) to `exports/` as
   Parquet or CSV via a dbt post-hook or small script. Import into Power BI Desktop
   (Desktop-only constraint: no service, no scheduled refresh — fine for portfolio)
2. Model view: proper star schema — marts/fact aggregate related to dim_model and
   dim_date, single-direction filters. Screenshot goes in the README
3. DAX measures (minimum): Fleet AFR, AFR by model, Rolling 90-day failure rate,
   Drive-days, Failure count, YoY AFR delta
4. Two pages:
   - **Fleet health** (exec view): headline AFR, trend line, top/bottom models, anomaly flags
   - **Model drill-down**: cohort survival curves, SMART attribute context
5. The exec page must answer one business question on sight: *"which drive models
   should we stop buying?"*

**Definition of done:** .pbix committed (or linked), README screenshots, every DAX
measure explainable.

---

# 9. Phase 6 — Promote, CI, and polish (Tier 3)

*Databricks Free Edition · GitHub Actions · docs · target: 2 days*

1. Databricks Free Edition workspace; upload Parquet to a volume; register tables
2. Add `databricks` target to profiles.yml (dbt-databricks); run `dbt build`; fix
   dialect issues (log each fix in decisions.md — they're interview material about
   engine portability)
3. GitHub Action: on push, run `dbt build` against DuckDB with a small fixture sample
   of the data (a 100K-row sample committed under `tests/fixtures/` or generated) so
   CI is fast and free
4. `dbt docs generate` output linked or screenshotted in README (lineage graph)
5. README final pass: architecture diagram, findings summary, benchmarks summary,
   how-to-run, and the honest framing of DuckDB-dev/Databricks-promote

**Definition of done:** CI badge green, Databricks target builds, README complete.

---

# 10. Validation gates (run at every phase boundary)

All must pass before advancing. Mirrors the Meridian "validation is not optional" rule.

| # | Check | Expectation |
|---|---|---|
| 1 | `dbt build` | Zero errors, zero test failures |
| 2 | Row reconciliation | Raw CSV = Parquet = staging counts per quarter |
| 3 | Grain | Zero duplicate (serial, date) pairs post-staging |
| 4 | AFR reconciliation | Within tolerance of published report, or mismatch explained in decisions.md |
| 5 | Failure logic | Every failure row is that drive's last observed day |
| 6 | Referential integrity | Zero orphan keys fact → dims |
| 7 | Benchmarks current | Every pipeline run this phase has a benchmarks.md entry |
| 8 | Defense | Owner has completed the walkthrough + quiz for the phase (Section 13) |

---

# 11. Commit cadence

| When | Commit message |
|---|---|
| Project start | chore: scaffold repo, CLAUDE.md, primer.md, memory.sh, blueprint |
| Phase 1 | feat: quarterly ingestion to partitioned parquet with reconciliation |
| Phase 2 start | feat: dbt project scaffold with parquet sources and staging contract |
| Phase 2 cont. | feat: dims and facts with generic test coverage |
| Phase 2 complete | feat: AFR mart reconciled against published Q1 2026 report |
| Phase 3 | perf: incremental fct_drive_daily, 80M+ rows, benchmarks logged |
| Phase 4 | feat: cohort survival and trend/anomaly marts with findings |
| Phase 5 | feat: Power BI star-schema model with fleet health dashboard |
| Phase 6 | chore: databricks target, CI workflow, dbt docs, final README |

Conventional-commit style throughout; small commits per model where natural. The git
log is part of the #eng-practice evidence.

---

# 12. Claude Code session memory system

Same three-file system as Meridian. Set up before the first session.

## CLAUDE.md — static charter (write once)

```markdown
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

## Session rule
End of every session: rewrite primer.md completely — what was built, exact
phase status, single next action, open blockers. Then stop.
```

## primer.md — living handoff (rewritten every session)

```markdown
# Backblaze — Session Primer
Last updated: [DATE]

## Phase status
- [ ] Phase 1: ingestion, one quarter to parquet, reconciled
- [ ] Phase 2: dbt core, tests green, AFR reconciled
- [ ] Phase 3: 80M+ rows, incremental, benchmarks
- [ ] Phase 4: cohort + trend/anomaly marts, findings.md
- [ ] Phase 5: Power BI dashboard
- [ ] Phase 6: Databricks target, CI, docs

## What was done last session
(nothing yet)

## Exact next action
Create ingest/ingest_quarter.py per Blueprint Section 4.

## Open blockers
None.
```

## memory.sh

```bash
#!/bin/bash
echo '=== BACKBLAZE SESSION START ==='
echo "Branch: $(git branch --show-current)"
git log --oneline -5
git status --short
echo '--- primer.md ---'
cat primer.md
echo '=== END ==='
```

---

# 13. Defense loop (per phase)

At the end of each phase, before validation gate 8 can pass:

1. Claude Code produces `docs/walkthroughs/phase_N.md`: every model explained in plain
   language — what it does, why it exists, what breaks without it
2. Claude Code quizzes the owner: 8-10 interview-style questions (mix of "explain this
   model", "why this materialization", "what does this test catch", "defend this
   design decision against alternative X")
3. Owner answers out loud or in writing; wrong/shaky answers get flagged and re-quizzed
   next session
4. Owner writes (not generates) the short public writeup section for the phase

---

# 14. Bullet map (why each phase exists)

| Phase | Bullet tags earned |
|---|---|
| 1 | #etl-pipeline, integrity groundwork |
| 2 | #dbt-modeling · #data-quality · #integrity-reconciliation |
| 3 | #query-optimization · scale claim (80M+) |
| 4 | #analytics (cohort, trend, anomaly) |
| 5 | #bi-dashboard |
| 6 | #eng-practice |

Slot-2 resume cut is complete after Phase 3; Phases 4-6 upgrade it. Numbers in bullets
come only from benchmarks.md, reconciliation_log.md, and findings.md — never estimated.

---

# 15. Demo questions and interview narrative

| Question | What it demonstrates |
|---|---|
| "Walk me through what happens to a raw CSV." | ETL, schema-drift contract, lineage |
| "How do you know your numbers are right?" | Tests + reconciliation vs published AFR — the signature answer |
| "Why incremental? Show me the difference." | benchmarks.md, materialization judgment |
| "Which drive model would you stop buying?" | Findings, exec framing, dashboard |
| "What's a censored observation and why does it matter?" | Survival honesty, analytical depth |
| "Why DuckDB locally and Databricks at the end?" | Architectural judgment, cost awareness |

**Narrative:** "I built a dbt dimensional warehouse over 80M+ daily drive-telemetry
records — real, messy public data with schema drift across quarters. The pipeline
enforces quality with an automated test suite and, the part I'm proudest of, reconciles
its computed failure rates against Backblaze's own published reports, so the numbers
are verified against ground truth. I developed on DuckDB, promoted to Databricks with
a profile swap, and shipped a Power BI fleet-health dashboard on top."

---

*This document supersedes all prior planning notes. Amendments are appended below with
dates, Meridian-style, rather than edited silently.*
