"""
ingest_quarter.py — Phase 1 ingestion ETL (Blueprint Section 4).

Idempotent, parameterized-by-quarter loader for Backblaze Drive Stats.

Pipeline:
  1. unzip the quarterly ZIP to a temp directory
  2. single DuckDB COPY: read_csv_auto(union_by_name) -> Hive-partitioned Parquet
     (all raw columns kept; date/failure/capacity_bytes explicitly cast)
  3. reconcile source CSV row count vs written Parquet row count (mismatch = hard fail)
  4. introspect the CSV header, snapshot it, diff vs the previous quarter (schema drift)
  5. append wall-clock time to docs/benchmarks.md
  6. delete the extracted CSVs and temp dir
  7. print a one-line summary

HARD RULE: raw data is only ever touched through DuckDB. No pandas. Ever.

Usage:
    python ingest/ingest_quarter.py --quarter 2026Q1
    python ingest/ingest_quarter.py --quarter 2026Q1 --zip data/raw/data_Q1_2026.zip
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
import time
import zipfile
from datetime import datetime
from pathlib import Path

import duckdb

# Repo root is the parent of the ingest/ directory this file lives in.
REPO_ROOT = Path(__file__).resolve().parent.parent
PARQUET_ROOT = REPO_ROOT / "data" / "parquet"
DOCS = REPO_ROOT / "docs"
SNAPSHOT_DIR = DOCS / "schema_snapshots"

# Only these three columns get an explicit cast; everything else keeps DuckDB's
# inferred type from a full-file scan. Raw zone stays raw (Blueprint Section 4).
CAST_COLUMNS = {
    "date": "DATE",
    "failure": "TINYINT",
    "capacity_bytes": "BIGINT",
}

QUARTER_RE = re.compile(r"^(\d{4})Q([1-4])$")


def parse_quarter(quarter: str) -> tuple[int, int]:
    """'2026Q1' -> (2026, 1). Raises on bad format."""
    m = QUARTER_RE.match(quarter)
    if not m:
        raise ValueError(f"--quarter must look like 2026Q1, got {quarter!r}")
    return int(m.group(1)), int(m.group(2))


def default_zip_path(quarter: str) -> Path:
    """'2026Q1' -> data/raw/data_Q1_2026.zip (Backblaze's naming)."""
    year, q = parse_quarter(quarter)
    return REPO_ROOT / "data" / "raw" / f"data_Q{q}_{year}.zip"


def dir_size_gb(path: Path, pattern: str = "**/*") -> float:
    total = sum(p.stat().st_size for p in path.glob(pattern) if p.is_file())
    return total / (1024**3)


def unzip(zip_path: Path, dest: Path) -> Path:
    """Extract the ZIP to dest and return the directory that actually holds the CSVs."""
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    print(f"  unzipping {zip_path.name} -> {dest} ...", flush=True)
    with zipfile.ZipFile(zip_path) as z:
        z.extractall(dest)
    csvs = list(dest.rglob("*.csv"))
    if not csvs:
        raise RuntimeError(f"no CSV files found after extracting {zip_path}")
    # CSVs may sit under a nested folder (e.g. data_Q1_2026/*.csv).
    csv_dir = csvs[0].parent
    print(f"  extracted {len(csvs)} CSV files into {csv_dir}", flush=True)
    return csv_dir


def build_copy_sql(csv_glob: str, quarter: str) -> str:
    """Cast the three known columns, keep the rest, tag with quarter, partition on it."""
    casts = ",\n            ".join(
        f"cast({col} as {typ}) as {col}" for col, typ in CAST_COLUMNS.items()
    )
    excluded = ", ".join(CAST_COLUMNS)
    return f"""
        copy (
            select
            {casts},
            * exclude ({excluded}),
            '{quarter}' as quarter
            from read_csv_auto('{csv_glob}', union_by_name=true, sample_size=-1)
        )
        to '{PARQUET_ROOT.as_posix()}'
        (format parquet, partition_by (quarter), overwrite_or_ignore true, compression zstd);
    """


def snapshot_and_diff_schema(con: duckdb.DuckDBPyConnection, csv_glob: str, quarter: str) -> None:
    """Write this quarter's column list; diff against the most recent prior quarter."""
    cols = [
        r[0]
        for r in con.execute(
            f"describe select * from read_csv_auto('{csv_glob}', union_by_name=true, sample_size=1000)"
        ).fetchall()
    ]
    SNAPSHOT_DIR.mkdir(parents=True, exist_ok=True)
    snapshot_path = SNAPSHOT_DIR / f"{quarter}.txt"

    # Idempotency: only log drift when this quarter's schema is new or changed.
    # A clean re-run of an already-ingested quarter should not re-append to the log.
    new_snapshot = "\n".join(cols) + "\n"
    if snapshot_path.exists() and snapshot_path.read_text(encoding="utf-8") == new_snapshot:
        print(f"  schema: {len(cols)} columns; unchanged since last run (not re-logged)", flush=True)
        return
    snapshot_path.write_text(new_snapshot, encoding="utf-8")

    # Find the most recent prior quarter snapshot (chronological, excluding this one).
    priors = sorted(p.stem for p in SNAPSHOT_DIR.glob("*.txt") if p.stem != quarter)
    priors = [p for p in priors if p < quarter]

    stamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    lines = [f"## {quarter} (logged {stamp})", ""]
    if not priors:
        lines += [
            f"Baseline quarter — no prior snapshot to diff against.",
            f"Column count: {len(cols)}.",
            "",
        ]
    else:
        prev_q = priors[-1]
        prev_cols = (SNAPSHOT_DIR / f"{prev_q}.txt").read_text(encoding="utf-8").split()
        added = [c for c in cols if c not in set(prev_cols)]
        removed = [c for c in prev_cols if c not in set(cols)]
        lines += [
            f"Diff vs {prev_q}: {len(prev_cols)} -> {len(cols)} columns.",
            f"Added ({len(added)}): {', '.join(added) if added else 'none'}",
            f"Removed ({len(removed)}): {', '.join(removed) if removed else 'none'}",
            "",
        ]
    with (DOCS / "schema_drift_log.md").open("a", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"  schema: {len(cols)} columns; drift logged", flush=True)


def append_reconciliation(quarter: str, csv_rows: int, pq_rows: int, ok: bool) -> None:
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    delta = pq_rows - csv_rows
    result = "PASS" if ok else "FAIL"
    row = f"| {stamp} | {quarter} | {csv_rows:,} | {pq_rows:,} | {delta:+,} | {result} |\n"
    with (DOCS / "reconciliation_log.md").open("a", encoding="utf-8") as f:
        f.write(row)


def append_benchmark(
    quarter: str, rows: int, files: int, gb_in: float, gb_out: float, seconds: float
) -> None:
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    row = (
        f"| {stamp} | {quarter} | {rows:,} | {files} | "
        f"{gb_in:.2f} | {gb_out:.2f} | {seconds:.1f} |\n"
    )
    with (DOCS / "benchmarks.md").open("a", encoding="utf-8") as f:
        f.write(row)


def ingest(quarter: str, zip_path: Path) -> int:
    parse_quarter(quarter)  # validate early
    if not zip_path.exists():
        print(f"ERROR: ZIP not found: {zip_path}", file=sys.stderr)
        return 1

    start = time.perf_counter()
    tmp_dir = REPO_ROOT / "data" / f"_tmp_{quarter}"
    duck_tmp = REPO_ROOT / "data" / "_duckdb_tmp"
    quarter_out = PARQUET_ROOT / f"quarter={quarter}"

    print(f"[ingest {quarter}] source: {zip_path.name}", flush=True)

    try:
        csv_dir = unzip(zip_path, tmp_dir)
        csv_glob = (csv_dir / "*.csv").as_posix()
        csv_files = list(csv_dir.glob("*.csv"))
        gb_in = dir_size_gb(csv_dir, "*.csv")

        # Idempotency: drop this quarter's partition before rewriting it.
        if quarter_out.exists():
            shutil.rmtree(quarter_out)
        PARQUET_ROOT.mkdir(parents=True, exist_ok=True)

        con = duckdb.connect()
        duck_tmp.mkdir(parents=True, exist_ok=True)
        con.execute(f"set temp_directory = '{duck_tmp.as_posix()}';")
        con.execute("set preserve_insertion_order = false;")

        # Schema drift: introspect + diff before the heavy COPY.
        snapshot_and_diff_schema(con, csv_glob, quarter)

        # Source row count (independent full scan of the CSVs).
        print("  counting source CSV rows ...", flush=True)
        csv_rows = con.execute(
            f"select count(*) from read_csv_auto('{csv_glob}', union_by_name=true)"
        ).fetchone()[0]

        # The heavy lift: CSV -> partitioned Parquet.
        print("  writing partitioned parquet ...", flush=True)
        con.execute(build_copy_sql(csv_glob, quarter))

        # Parquet row count (cheap — reads parquet metadata).
        pq_rows = con.execute(
            f"select count(*) from read_parquet('{quarter_out.as_posix()}/**/*.parquet')"
        ).fetchone()[0]
        con.close()

        ok = csv_rows == pq_rows
        append_reconciliation(quarter, csv_rows, pq_rows, ok)

        gb_out = dir_size_gb(quarter_out)
        seconds = time.perf_counter() - start
        append_benchmark(quarter, pq_rows, len(csv_files), gb_in, gb_out, seconds)

        if not ok:
            print(
                f"RECONCILIATION FAIL: csv={csv_rows:,} parquet={pq_rows:,} "
                f"(delta {pq_rows - csv_rows:+,})",
                file=sys.stderr,
            )
            return 2

        print(
            f"[done] {quarter}: {pq_rows:,} rows, {len(csv_files)} files, "
            f"{seconds:.1f}s, {gb_in:.2f}GB in -> {gb_out:.2f}GB out — reconciliation PASS"
        )
        return 0
    finally:
        # Delete extracted CSVs and temp dirs (Blueprint hard rule).
        for d in (tmp_dir, duck_tmp):
            if d.exists():
                shutil.rmtree(d, ignore_errors=True)


def main() -> int:
    ap = argparse.ArgumentParser(description="Ingest one quarter of Backblaze Drive Stats.")
    ap.add_argument("--quarter", required=True, help="e.g. 2026Q1")
    ap.add_argument(
        "--zip",
        default=None,
        help="path to the quarterly ZIP (default: data/raw/data_Q<n>_<year>.zip)",
    )
    args = ap.parse_args()
    zip_path = Path(args.zip) if args.zip else default_zip_path(args.quarter)
    if not zip_path.is_absolute():
        zip_path = (REPO_ROOT / zip_path).resolve()
    return ingest(args.quarter, zip_path)


if __name__ == "__main__":
    raise SystemExit(main())
