"""
Refresh the kg_metadata singleton (Move 1, Sprint 1.2, Task 1.2.1).

Why: the scope banner, /kg/metadata endpoint, and mosaic_kg_stats need
honest, current KG scope numbers without running COUNT(*) on every
request. This script computes them once and UPSERTs the single
kg_metadata row (id = 1). Intended to run nightly AND as the Railway
`preDeployCommand` (railway.toml), so the row stays fresh after every
deploy without operator intervention.

Idempotent. --dry-run prints the computed values and writes nothing.

Error handling: this script is non-critical (the API has a graceful
"available: false" fallback when the row is absent), so any DB error
— missing table, connection blip, anything — is logged and **swallowed**.
We always sys.exit(0). That guarantees a Railway preDeployCommand
slot can't block a deploy on a transient or schema-drift error.

Usage:
    DATABASE_URL="..." python -m scripts.refresh_kg_metadata
    DATABASE_URL="..." python -m scripts.refresh_kg_metadata --dry-run
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
from pathlib import Path

project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

try:
    from dotenv import load_dotenv

    load_dotenv(project_root / ".env")
except ImportError:
    pass

from src.db.connection import ConnectionManager

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
)
logger = logging.getLogger(__name__)


def _rollback(conn: ConnectionManager) -> None:
    """A failed statement aborts the psycopg transaction; everything
    after raises InFailedSqlTransaction until we roll back."""
    try:
        if conn._conn is not None and not conn._conn.closed:
            conn._conn.rollback()
    except Exception:  # noqa: BLE001 — best-effort
        pass


def _count(conn: ConnectionManager, table: str) -> int:
    """COUNT(*) on a table, tolerating both 'relation does not exist'
    and any other DB error. Returns 0 on failure and logs the cause."""
    try:
        rows = conn.execute(f"SELECT COUNT(*) AS n FROM {table}")
        return int(rows[0]["n"]) if rows else 0
    except Exception as e:  # noqa: BLE001 — see module docstring
        msg = str(e).splitlines()[0][:120]
        logger.warning("count(%s) skipped (%s)", table, msg)
        _rollback(conn)
        return 0


def _count_oncology_subtypes(conn: ConnectionManager) -> int:
    try:
        rows = conn.execute(
            "SELECT COUNT(*) AS n FROM indications "
            "WHERE is_oncology_subtype"
        )
        return int(rows[0]["n"]) if rows else 0
    except Exception as e:  # noqa: BLE001
        msg = str(e).splitlines()[0][:120]
        logger.warning("count(indications.is_oncology_subtype) skipped (%s)", msg)
        _rollback(conn)
        return 0


# Canonical edge tables summed into kg_metadata.edge_count. Each is a
# typed relation the tools traverse. semantic_relations is intentionally
# excluded — it's already surfaced separately as relation_count, so
# including it here would double-count in the marketing band. Missing
# tables count as 0 via _count's fault-tolerance.
EDGE_TABLES: tuple[str, ...] = (
    "compound_targets",
    "target_indications",
    "target_pathways",
    "target_interactions",
    "target_interactions_ext",
    "target_coessentiality",
    "target_coessentiality_ext",
    "target_variant_pathogenicity",
    "compound_indications",
    "compound_analogs",
    "paper_mentions_target",
    "patent_mentions_target",
    "paper_mentions_compound",
    "patent_mentions_compound",
    "paper_authors",
    "patent_inventors",
    "resistance_relations",
    "paper_validations",
)


def _sum_edges(conn: ConnectionManager) -> int:
    """Sum row counts across all canonical edge tables. Missing tables
    contribute 0 (_count handles that)."""
    return sum(_count(conn, t) for t in EDGE_TABLES)


def _ensure_edge_count_column(conn: ConnectionManager) -> None:
    """Idempotent ALTER. The same migration lives in schema.sql; this
    is a belt-and-braces for environments where the script runs against
    a DB that's lagging schema.sql by one push (e.g. preDeploy on a
    rolling container)."""
    try:
        conn.execute(
            "ALTER TABLE kg_metadata "
            "ADD COLUMN IF NOT EXISTS edge_count BIGINT NOT NULL DEFAULT 0"
        )
    except Exception as e:  # noqa: BLE001
        msg = str(e).splitlines()[0][:120]
        logger.warning("edge_count column ensure skipped (%s)", msg)
        _rollback(conn)


def _therapy_areas(conn: ConnectionManager) -> list[str]:
    try:
        rows = conn.execute(
            """
            SELECT DISTINCT therapeutic_area FROM indications
            WHERE therapeutic_area IS NOT NULL AND therapeutic_area <> ''
            ORDER BY therapeutic_area
            """
        )
        return [r["therapeutic_area"] for r in rows]
    except Exception as e:  # noqa: BLE001
        msg = str(e).splitlines()[0][:120]
        logger.warning("therapy_areas lookup skipped (%s)", msg)
        _rollback(conn)
        return []


def compute_metadata(conn: ConnectionManager) -> dict:
    """Compute the scope numbers. Each query is independently
    fault-tolerant — missing tables return 0; the script never raises."""
    meta = {
        "target_count": _count(conn, "targets"),
        "compound_count": _count(conn, "compounds"),
        "paper_count": _count(conn, "papers"),
        "patent_count": _count(conn, "patents"),
        "relation_count": _count(conn, "semantic_relations"),
        "subindication_count": _count_oncology_subtypes(conn),
        "edge_count": _sum_edges(conn),
    }
    meta["therapy_areas"] = _therapy_areas(conn)
    meta["data_sources"] = {
        "targets": meta["target_count"],
        "compounds": meta["compound_count"],
        "papers": meta["paper_count"],
        "patents": meta["patent_count"],
        "semantic_relations": meta["relation_count"],
        "chembl_activities": _count(conn, "compound_targets"),
        "clinical_trials": _count(conn, "trials"),
    }
    return meta


def _upsert(conn: ConnectionManager, meta: dict) -> bool:
    """Write the singleton row. Returns True on success."""
    try:
        _ensure_edge_count_column(conn)
        conn.execute(
            """
            INSERT INTO kg_metadata
                (id, target_count, compound_count, paper_count,
                 patent_count, relation_count, subindication_count,
                 edge_count,
                 last_refresh_at, therapy_areas, data_sources)
            VALUES
                (1, %(target_count)s, %(compound_count)s, %(paper_count)s,
                 %(patent_count)s, %(relation_count)s,
                 %(subindication_count)s, %(edge_count)s, NOW(),
                 %(therapy_areas)s, %(data_sources)s)
            ON CONFLICT (id) DO UPDATE SET
                target_count        = EXCLUDED.target_count,
                compound_count      = EXCLUDED.compound_count,
                paper_count         = EXCLUDED.paper_count,
                patent_count        = EXCLUDED.patent_count,
                relation_count      = EXCLUDED.relation_count,
                subindication_count = EXCLUDED.subindication_count,
                edge_count          = EXCLUDED.edge_count,
                last_refresh_at     = EXCLUDED.last_refresh_at,
                therapy_areas       = EXCLUDED.therapy_areas,
                data_sources        = EXCLUDED.data_sources,
                kg_version          = kg_metadata.kg_version + 1
            """,
            {
                **{k: meta[k] for k in (
                    "target_count", "compound_count", "paper_count",
                    "patent_count", "relation_count", "subindication_count",
                    "edge_count",
                )},
                "therapy_areas": meta["therapy_areas"],
                "data_sources": json.dumps(meta["data_sources"]),
            },
        )
        return True
    except Exception as e:  # noqa: BLE001
        msg = str(e).splitlines()[0][:200]
        logger.error("kg_metadata UPSERT failed (%s)", msg)
        _rollback(conn)
        return False


def main() -> None:
    parser = argparse.ArgumentParser(description="Refresh kg_metadata")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    try:
        database_url = os.environ.get("DATABASE_URL")
        if not database_url:
            logger.error("DATABASE_URL not set — skipping kg_metadata refresh")
            sys.exit(0)

        with ConnectionManager(database_url) as conn:
            meta = compute_metadata(conn)
            logger.info("Computed kg_metadata:")
            for k, v in meta.items():
                logger.info("  %-22s %s", k, v)

            if args.dry_run:
                logger.info("DRY RUN — kg_metadata not written")
                sys.exit(0)

            ok = _upsert(conn, meta)
            if ok:
                logger.info("kg_metadata refreshed (id=1)")
            else:
                logger.warning(
                    "kg_metadata refresh skipped — see warnings above. "
                    "Endpoint will continue serving the previous row "
                    "(or 'available: false' if the row never existed)."
                )
    except Exception as e:  # noqa: BLE001
        # Last-resort net so a connection failure / driver hiccup can't
        # block the Railway preDeployCommand.
        logger.error("refresh_kg_metadata aborted: %s", e)
    finally:
        # Always exit 0. The endpoint's "available: false" fallback
        # makes a missed refresh non-critical; blocking a deploy on it
        # would be worse than the cosmetic miss.
        sys.exit(0)


if __name__ == "__main__":
    main()
