# Reconciliation Log

Two kinds of reconciliation live here:
1. **Row parity** (Phase 1): raw CSV row count vs written Parquet row count. Mismatch = hard failure.
2. **AFR vs published** (Phase 2): fleet count, failures, and per-model AFR vs Backblaze's published quarterly report.

## Phase 1 — Row parity (CSV vs Parquet)

| Timestamp | Quarter | CSV rows | Parquet rows | Delta | Result |
|---|---|---|---|---|---|
| 2026-07-19 11:43 | 2026Q1 | 30,597,484 | 30,597,484 | +0 | PASS |
| 2026-07-19 12:00 | 2026Q1 | 30,597,484 | 30,597,484 | +0 | PASS |

## Phase 2 — AFR vs published (Backblaze Q1 2026 Drive Stats)

**Method:** `mart_model_afr_quarterly` computes AFR% = failures / (drive_days / 365) * 100
per model, with Backblaze's published cutoff (drive_count > 100 AND drive_days > 10,000).
Compared against the published Q1 2026 per-model table. Model strings normalized for
comparison by stripping the manufacturer prefix (`WDC `/`HGST `/`TOSHIBA `) and merging the
bare `WUH721816ALE6L4` string with its `WDC `-prefixed twin (see decisions.md).

**Result: 33 / 33 models PASS — exact match on drive_days, failures, and AFR%.**

### Fleet-level (my mart restricted to the 33 published models)

| Metric | Mine | Backblaze | Delta | Result |
|---|---:|---:|---:|---|
| Drive-days (analyzed) | 30,203,180 | 30,203,180 | +0 | PASS |
| Failures (analyzed) | 1,030 | 1,030 | +0 | PASS |
| Fleet AFR | 1.24% | 1.24% | +0.00 | PASS |
| Sum of per-model drive_count | 346,596 | 346,596 | +0 | PASS |
| Headline analyzed drive count | 346,596 (sum) / 351,095 (raw distinct) | 341,263 | +5,333 / +9,832 | INVESTIGATE (explained) |

### Per-model comparison

| Manufacturer | Model | Mine drive_days | Pub drive_days | Mine fail | Pub fail | Mine AFR% | Pub AFR% | Result |
|---|---|---:|---:|---:|---:|---:|---:|---|
| HGST | HMS5C4040BLE640 | 15,858 | 15,858 | 0 | 0 | 0.0 | 0.0 | PASS |
| HGST | HUH728080ALE600 | 86,921 | 86,921 | 0 | 0 | 0.0 | 0.0 | PASS |
| HGST | HUH721212ALE600 | 234,350 | 234,350 | 8 | 8 | 1.25 | 1.25 | PASS |
| HGST | HUH721212ALE604 | 1,183,774 | 1,183,774 | 86 | 86 | 2.65 | 2.65 | PASS |
| HGST | HUH721212ALN604 | 870,252 | 870,252 | 95 | 95 | 3.98 | 3.98 | PASS |
| Seagate | ST8000DM002 | 639,473 | 639,473 | 25 | 25 | 1.43 | 1.43 | PASS |
| Seagate | ST8000NM000A | 21,552 | 21,552 | 1 | 1 | 1.69 | 1.69 | PASS |
| Seagate | ST8000NM0055 | 1,176,619 | 1,176,619 | 39 | 39 | 1.21 | 1.21 | PASS |
| Seagate | ST10000NM0086 | 86,667 | 86,667 | 11 | 11 | 4.63 | 4.63 | PASS |
| Seagate | ST12000NM0007 | 87,389 | 87,389 | 11 | 11 | 4.59 | 4.59 | PASS |
| Seagate | ST12000NM0008 | 1,664,558 | 1,664,558 | 129 | 129 | 2.83 | 2.83 | PASS |
| Seagate | ST12000NM000J | 96,887 | 96,887 | 1 | 1 | 0.38 | 0.38 | PASS |
| Seagate | ST12000NM001G | 1,185,545 | 1,185,545 | 33 | 33 | 1.02 | 1.02 | PASS |
| Seagate | ST14000NM000J | 37,258 | 37,258 | 1 | 1 | 0.98 | 0.98 | PASS |
| Seagate | ST14000NM001G | 944,400 | 944,400 | 21 | 21 | 0.81 | 0.81 | PASS |
| Seagate | ST14000NM0138 | 111,709 | 111,709 | 15 | 15 | 4.9 | 4.9 | PASS |
| Seagate | ST16000NM000J | 10,117 | 10,117 | 1 | 1 | 3.61 | 3.61 | PASS |
| Seagate | ST16000NM001G | 3,098,105 | 3,098,105 | 44 | 44 | 0.52 | 0.52 | PASS |
| Seagate | ST16000NM002J | 41,931 | 41,931 | 0 | 0 | 0.0 | 0.0 | PASS |
| Seagate | ST24000NM002H | 820,090 | 820,090 | 74 | 74 | 3.29 | 3.29 | PASS |
| Toshiba | MG07ACA14TA | 3,343,724 | 3,343,724 | 94 | 94 | 1.03 | 1.03 | PASS |
| Toshiba | MG07ACA14TEY | 88,602 | 88,602 | 5 | 5 | 2.06 | 2.06 | PASS |
| Toshiba | MG08ACA16TA | 3,548,250 | 3,548,250 | 102 | 102 | 1.05 | 1.05 | PASS |
| Toshiba | MG08ACA16TE | 553,878 | 553,878 | 21 | 21 | 1.38 | 1.38 | PASS |
| Toshiba | MG08ACA16TEY | 435,063 | 435,063 | 26 | 26 | 2.18 | 2.18 | PASS |
| Toshiba | MG09ACA16TE | 36,988 | 36,988 | 1 | 1 | 0.99 | 0.99 | PASS |
| Toshiba | MG10ACA20TE | 1,665,263 | 1,665,263 | 42 | 42 | 0.92 | 0.92 | PASS |
| Toshiba | MG11ACA24TE | 495,387 | 495,387 | 3 | 3 | 0.22 | 0.22 | PASS |
| Western Digital | WUH721414ALE6L4 | 776,557 | 776,557 | 7 | 7 | 0.33 | 0.33 | PASS |
| Western Digital | WUH721816ALE6L0 | 267,868 | 267,868 | 24 | 24 | 3.27 | 3.27 | PASS |
| Western Digital | WUH721816ALE6L4 | 2,402,732 | 2,402,732 | 64 | 64 | 0.97 | 0.97 | PASS |
| Western Digital | WUH722222ALE6L4 | 3,992,942 | 3,992,942 | 42 | 42 | 0.38 | 0.38 | PASS |
| Western Digital | WUH722626ALE6L4 | 182,471 | 182,471 | 4 | 4 | 0.8 | 0.8 | PASS |
### Models in my mart but NOT in Backblaze's HDD table (all 0 failures)

These 9 pass the drive-day/count threshold but are SSDs or boot devices, which Backblaze
excludes from its HDD Drive Stats table (SSDs are reported separately; boot drives are
non-qualifying). Total 3,506 drives.

| Model | drive_count | drive_days | failures |
|---|---:|---:|---:|
| BarraCuda 120 SSD ZA250CM10003 | 1,075 | 96,480 | 0 |
| CT250MX500SSD1 | 718 | 63,051 | 0 |
| BarraCuda SSD ZA250CM10002 | 486 | 43,281 | 0 |
| DELLBOSS VD | 431 | 38,653 | 0 |
| IronWolf ZA250NM10002 | 192 | 16,540 | 0 |
| WDS250G2B0A | 171 | 15,207 | 0 |
| ST500LM030 | 162 | 14,291 | 0 |
| Blue SA510 2.5 250GB | 147 | 12,829 | 0 |
| MQ01ABF050 | 124 | 10,546 | 0 |

### Drive-count gap (351,095 raw vs 341,263 Backblaze) — explained, not chased

- The substantive reliability metrics — drive-days, failures, AFR — reconcile EXACTLY, so
  the pipeline's failure accounting is verified against ground truth.
- The drive-count gap is definitional/scope, not an error:
  - My mart includes SSD + boot devices (9 models above, 3,506 drives) that Backblaze
    excludes from the HDD table (Backblaze's stated ~3,907 boot + 492 non-qualifying).
  - Backblaze's headline 341,263 is a fleet-level analyzed count; the sum of the per-model
    table's own drive-count column is 346,596, which my mart matches exactly.
  - Remaining drives sit in HDD models below the drive-day/count threshold, excluded by
    both sides.

### UPDATE 2026-07-20 — mart now reproduces the published table DIRECTLY

The comparison above was originally run against a mart that included SSD/boot
models and split one model by naming, requiring post-hoc scoping in an analysis
script. Both issues were fixed upstream (see decisions.md):
- `dim_model.drive_type` (from `pod_slot_num`) marks boot drives; the mart scopes
  to `drive_type = 'data'`.
- `normalize_model` macro strips WD's redundant `WDC ` prefix, merging the
  `WUH721816ALE6L4` split in dim_drive/dim_model.

`select count(*), sum(drive_days), sum(failures), fleet_afr from mart_model_afr_quarterly`
now returns **33 models / 30,203,180 drive-days / 1,030 failures / 1.24% AFR**
with NO filtering, and all 33 models match the published table on drive_count,
drive_days, failures, and AFR% (33/33 exact, verified digit-by-digit). The 9
SSD/boot models no longer appear (correctly excluded, as Backblaze does).
