"""
Reproducibility driver — Move 3 Task 3.6.3.

Boots a minimal Mosaic stack from a fixture dataset (10 oncology targets,
24 compounds, 30 papers, 27 compound→target edges, 29 paper→target edges)
and emits representative tool outputs to `/output/`. The point isn't to
demonstrate the full KG — it's to demonstrate that the same code paths
that built the production graph work end-to-end on a fresh DB with
public data the reader can audit.

What this script does:
  1. Apply src/db/schema.sql to whatever DATABASE_URL points at.
  2. Bulk-INSERT fixtures from paper/reproducibility/fixtures/*.csv.
  3. Refresh the kg_metadata singleton (so /kg/metadata + mosaic_kg_stats
     report honest counts for the mini-KG).
  4. Invoke a handful of MCP tools and write their JSON responses to
     /output/, plus a MANIFEST.md describing what was produced.

What this script DOES NOT do (deliberately):
  - GLiREL extraction: requires GPU and ~6 hr of compute. The KG already
    holds the schema for `semantic_relations` so the tools that read it
    degrade gracefully (return empty + a populate hint).
  - Foldseek index build: requires Docker + AlphaFold PDBs. Same graceful-
    empty path as `mosaic_find_similar_targets`.
  - DepMap / AlphaMissense / STRING-ext: optional auxiliary edge tables.

These are the operator-only steps; the small fixture pipeline is
sufficient to verify the *architecture* end-to-end.

Usage (inside the repro container):
    DATABASE_URL=... python -m scripts.run_repro --output /output

Local quick-test (against a localhost Postgres):
    DATABASE_URL=postgres://mosaic:mosaic@localhost:5432/mosaic_db \
        python -m scripts.run_repro --output ./output --dry-run
"""

from __future__ import annotations

import argparse
import csv
import json
import logging
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
)
logger = logging.getLogger(__name__)


FIXTURES_DIR = project_root / "fixtures"
SCHEMA_PATH = project_root / "src" / "db" / "schema.sql"


# ---------------------------------------------------------------------------
# DB helpers
# ---------------------------------------------------------------------------


def wait_for_postgres(url: str, max_wait_s: int = 60) -> None:
    """Block until the DB accepts connections. Containers start before
    Postgres is ready."""
    import psycopg
    start = time.time()
    last_err: Exception | None = None
    while time.time() - start < max_wait_s:
        try:
            with psycopg.connect(url, connect_timeout=5) as conn:
                conn.execute("SELECT 1")
                logger.info(
                    "Postgres reachable after %.1fs",
                    time.time() - start,
                )
                return
        except Exception as e:  # noqa: BLE001
            last_err = e
            time.sleep(1.5)
    raise RuntimeError(
        f"Postgres unreachable after {max_wait_s}s: {last_err}"
    )


def apply_schema(url: str) -> None:
    """Apply schema.sql via psycopg's multi-statement execution. The file
    is fully idempotent (CREATE TABLE IF NOT EXISTS, ALTER ... IF NOT
    EXISTS) so re-runs are safe."""
    import psycopg
    sql_text = SCHEMA_PATH.read_text(encoding="utf-8")
    with psycopg.connect(url, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(sql_text)
    logger.info("Schema applied from %s", SCHEMA_PATH.name)


# ---------------------------------------------------------------------------
# Fixture loaders
# ---------------------------------------------------------------------------


def load_targets(cur, path: Path) -> int:
    n = 0
    with path.open(newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            cur.execute(
                """
                INSERT INTO targets (id, symbol, name, uniprot_id,
                                     target_class, druggability_tier)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (id) DO UPDATE SET
                    symbol = EXCLUDED.symbol,
                    name = EXCLUDED.name,
                    uniprot_id = EXCLUDED.uniprot_id,
                    target_class = EXCLUDED.target_class,
                    druggability_tier = EXCLUDED.druggability_tier
                """,
                (
                    r["target_id"], r["gene_symbol"], r["name"],
                    r["uniprot_id"], r["target_class"],
                    r["druggability_tier"],
                ),
            )
            n += 1
    return n


def load_compounds(cur, path: Path) -> int:
    n = 0
    with path.open(newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            cur.execute(
                """
                INSERT INTO compounds (id, name, chembl_id, max_phase, modality)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (id) DO UPDATE SET
                    name = EXCLUDED.name,
                    max_phase = EXCLUDED.max_phase,
                    modality = EXCLUDED.modality
                """,
                (
                    r["id"], r["name"], r["chembl_id"],
                    int(r["max_phase"]) if r.get("max_phase") else None,
                    r.get("modality"),
                ),
            )
            n += 1
    return n


def load_compound_targets(cur, path: Path) -> int:
    n = 0
    with path.open(newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            cur.execute(
                """
                INSERT INTO compound_targets
                    (compound_id, target_id, activity_type, value, unit, source)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (compound_id, target_id) DO NOTHING
                """,
                (
                    r["compound_id"], r["target_id"], r["activity_type"],
                    float(r["activity_value_nm"]) if r.get("activity_value_nm") else None,
                    "nM",
                    "fixture",
                ),
            )
            n += 1
    return n


def load_papers(cur, path: Path) -> int:
    n = 0
    with path.open(newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            cur.execute(
                """
                INSERT INTO papers (id, title, pmid, doi, publication_date, journal)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (id) DO UPDATE SET
                    title = EXCLUDED.title,
                    journal = EXCLUDED.journal,
                    publication_date = EXCLUDED.publication_date
                """,
                (
                    r["id"], r["title"], r["pmid"], r["doi"],
                    r["publication_date"], r["journal"],
                ),
            )
            n += 1
    return n


def load_paper_mentions_target(cur, path: Path) -> int:
    n = 0
    with path.open(newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            cur.execute(
                """
                INSERT INTO paper_mentions_target
                    (paper_id, target_id, confidence, context_type)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (paper_id, target_id) DO NOTHING
                """,
                (
                    r["paper_id"], r["target_id"],
                    float(r["confidence"]),
                    r["evidence_type"],
                ),
            )
            n += 1
    return n


# ---------------------------------------------------------------------------
# Bulk load
# ---------------------------------------------------------------------------


def bulk_load(url: str) -> dict[str, int]:
    import psycopg
    counts: dict[str, int] = {}
    with psycopg.connect(url) as conn:
        with conn.cursor() as cur:
            counts["targets"] = load_targets(cur, FIXTURES_DIR / "targets.csv")
            counts["compounds"] = load_compounds(cur, FIXTURES_DIR / "compounds.csv")
            counts["papers"] = load_papers(cur, FIXTURES_DIR / "papers.csv")
            counts["compound_targets"] = load_compound_targets(
                cur, FIXTURES_DIR / "compound_targets.csv"
            )
            counts["paper_mentions_target"] = load_paper_mentions_target(
                cur, FIXTURES_DIR / "paper_mentions_target.csv"
            )
        conn.commit()
    for table, n in counts.items():
        logger.info("loaded %4d row(s) into %s", n, table)
    return counts


# ---------------------------------------------------------------------------
# Tool invocations
# ---------------------------------------------------------------------------


def run_representative_tools(url: str, out_dir: Path) -> list[Path]:
    """Invoke a handful of MCP tools and dump their JSON to /output/.
    These are the artifacts the operator points the paper reader at to
    confirm the pipeline produced sensible output on the fixture data."""
    os.environ["DATABASE_URL"] = url  # for the queries module
    from src.db.queries import get_graph_queries
    gq = get_graph_queries()

    artifacts: list[Path] = []

    def write(name: str, payload: Any) -> None:
        p = out_dir / f"{name}.json"
        p.write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")
        artifacts.append(p)
        logger.info("wrote %s", p)

    # 1. kg_stats: confirms ingest worked at all.
    try:
        write("mosaic_kg_stats", gq.get_kg_stats())
    except Exception as e:  # noqa: BLE001
        logger.warning("kg_stats failed: %s", e)

    # 2. target profile for EGFR — the canonical demo target.
    try:
        write("mosaic_get_target_profile_EGFR", gq.get_target_profile("EGFR"))
    except Exception as e:  # noqa: BLE001
        logger.warning("get_target_profile failed: %s", e)

    # 3. modality gaps on BRD4 — exercises compound.modality + the
    #    fixture's degrader signal.
    try:
        write("mosaic_modality_gaps_BRD4", gq.find_modality_gaps("BRD4"))
    except Exception as e:  # noqa: BLE001
        logger.warning("find_modality_gaps failed: %s", e)

    # 4. compound polypharmacology — exercises the compound→target edge.
    try:
        write("mosaic_polypharmacology_imatinib",
              gq.get_polypharmacology("imatinib"))
    except Exception as e:  # noqa: BLE001
        logger.warning("polypharmacology failed: %s", e)

    # 5. find_similar_targets — Foldseek index path. Expected to return
    #    empty + a hint here (no index built in the repro fixture); the
    #    point is to confirm the tool degrades cleanly.
    try:
        write("mosaic_find_similar_targets_BRAF",
              gq.find_similar_targets("BRAF", k=10))
    except Exception as e:  # noqa: BLE001
        logger.warning("find_similar_targets failed: %s", e)

    return artifacts


# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------


def write_manifest(
    out_dir: Path,
    counts: dict[str, int],
    artifacts: list[Path],
    metadata: dict[str, Any] | None,
) -> None:
    lines: list[str] = []
    lines.append("# Mosaic reproducibility — output manifest")
    lines.append("")
    lines.append(
        f"Run started at {datetime.now(timezone.utc).isoformat()}"
    )
    lines.append("")
    lines.append("## Fixture row counts")
    lines.append("")
    lines.append("| table | rows |")
    lines.append("|---|---:|")
    for table, n in counts.items():
        lines.append(f"| `{table}` | {n} |")
    lines.append("")
    lines.append("## kg_metadata snapshot")
    lines.append("")
    if metadata:
        for k in (
            "target_count", "compound_count", "paper_count",
            "patent_count", "relation_count", "edge_count",
            "subindication_count", "kg_version",
        ):
            if k in metadata:
                lines.append(f"- `{k}`: {metadata[k]}")
    else:
        lines.append("- (kg_metadata not refreshed — see run log)")
    lines.append("")
    lines.append("## Tool outputs")
    lines.append("")
    for p in artifacts:
        lines.append(f"- [`{p.name}`]({p.name})")
    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append(
        "These are tool outputs against the fixture mini-KG (10 targets, "
        "24 compounds, 30 papers). The same code paths run against the "
        "production graph (363 targets / 12,756 compounds / 35,430 papers) "
        "live at https://mosaic-production-6260.up.railway.app — that "
        "deployment is what the preprint reports headline numbers from."
    )

    (out_dir / "MANIFEST.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    logger.info("wrote %s/MANIFEST.md", out_dir)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run the Mosaic reproducibility pipeline on a fixture mini-KG.",
    )
    parser.add_argument(
        "--output", default="/output",
        help="Output directory (default /output, mounted by docker-compose)",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Print what would happen; don't touch the DB.",
    )
    args = parser.parse_args()

    url = os.environ.get("DATABASE_URL")
    if not url:
        logger.error("DATABASE_URL is required")
        return 1

    out_dir = Path(args.output)
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.dry_run:
        logger.info("DRY RUN — schema/load/tools would run against %s", url[:60])
        logger.info("fixtures dir: %s", FIXTURES_DIR)
        logger.info("output dir:   %s", out_dir)
        return 0

    try:
        wait_for_postgres(url)
        apply_schema(url)
        counts = bulk_load(url)

        # Refresh kg_metadata so kg_stats reports real counts.
        from scripts.refresh_kg_metadata import compute_metadata, _upsert
        from src.db.connection import ConnectionManager
        with ConnectionManager(url) as conn:
            meta = compute_metadata(conn)
            _upsert(conn, meta)
        logger.info(
            "kg_metadata refreshed (targets=%s compounds=%s papers=%s)",
            meta["target_count"], meta["compound_count"], meta["paper_count"],
        )

        artifacts = run_representative_tools(url, out_dir)
        write_manifest(out_dir, counts, artifacts, meta)

        logger.info("=" * 60)
        logger.info("REPRO COMPLETE — %d output files in %s",
                    len(artifacts) + 1, out_dir)
        return 0
    except Exception as e:
        logger.exception("repro pipeline failed: %s", e)
        return 1


if __name__ == "__main__":
    sys.exit(main())
