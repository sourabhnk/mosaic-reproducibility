"""
Slim query layer for the public reproducibility package.

Exposes only the methods that `scripts/run_repro.py` invokes:
  - get_kg_stats()
  - get_target_profile(symbol)
  - find_modality_gaps(target_or_family)
  - get_polypharmacology(compound_name)
  - find_similar_targets(target, k)

The full production query layer (44+ tools, 3.7K LOC) is held in the
private production repository — see §9 of the Mosaic paper for the
release-posture rationale. The five methods reproduced here are the
ones a reader needs to verify the §5.4 case-study tool outputs against
the fixture mini-KG (or any DATABASE_URL the operator points the
driver at).

Method bodies are vendored verbatim from the production source so the
outputs match field-for-field.
"""

from __future__ import annotations

import logging
from typing import Any

import psycopg

from src.db.connection import ConnectionManager, get_read_pool

logger = logging.getLogger(__name__)


class GraphQueries:
    """The subset of the production GraphQueries class needed to
    reproduce the §5.4 case studies on the fixture mini-KG.

    Method signatures and return shapes are identical to production
    so the outputs match field-for-field.
    """

    KNOWN_MODALITIES = (
        "small_molecule", "covalent", "degrader", "macrocycle", "peptide_like",
    )

    def __init__(self, db: ConnectionManager | None = None) -> None:
        self.db = db or get_read_pool()

    # ---- internal helpers -------------------------------------------------

    def _execute_safe(
        self,
        sql: str,
        params: dict[str, Any] | None = None,
    ) -> list[dict[str, Any]]:
        try:
            return self.db.execute(sql, params)
        except psycopg.OperationalError:
            raise  # connection errors bubble up
        except Exception as e:  # noqa: BLE001
            logger.warning("%s (%s)", str(e).splitlines()[0], sql.split()[0])
            return []

    def _resolve_target(self, symbol: str) -> str:
        """Resolve a target symbol or name to its canonical ID.

        Direct ID match → gene-name alias → fuzzy name LIKE.
        Returns the canonical ID, or the original symbol if no match.
        """
        symbol = symbol.strip().upper()
        direct = self._execute_safe(
            "SELECT id FROM targets WHERE id = %(s)s", {"s": symbol},
        )
        if direct:
            return symbol
        alias = self._execute_safe(
            "SELECT id FROM targets WHERE gene_names @> to_jsonb(%(s)s::text) LIMIT 1",
            {"s": symbol},
        )
        if alias:
            return alias[0]["id"]
        name_query = symbol.lower()
        name_match = self._execute_safe(
            """
            SELECT id FROM targets
            WHERE LOWER(name) LIKE %(q)s OR LOWER(name) = %(exact)s
            ORDER BY LENGTH(name) ASC LIMIT 1
            """,
            {"q": f"%{name_query}%", "exact": name_query},
        )
        if name_match:
            return name_match[0]["id"]
        return symbol

    # ---- the five reproduced tool methods ---------------------------------

    def get_kg_stats(self) -> dict[str, Any]:
        """Overall KG statistics — entity counts, relation counts, coverage."""
        stats: dict[str, Any] = {}
        for table, label in [
            ("targets", "targets"), ("compounds", "compounds"),
            ("papers", "papers"), ("patents", "patents"),
        ]:
            rows = self._execute_safe(f"SELECT COUNT(*) AS cnt FROM {table}")
            stats[label] = rows[0]["cnt"] if rows else 0

        rows = self._execute_safe("SELECT COUNT(*) AS cnt FROM semantic_relations")
        stats["semantic_relations"] = rows[0]["cnt"] if rows else 0

        rows = self._execute_safe(
            "SELECT COUNT(DISTINCT source_doc_id) AS cnt FROM semantic_relations"
        )
        stats["docs_with_relations"] = rows[0]["cnt"] if rows else 0

        rows = self._execute_safe(
            """SELECT relation_type, COUNT(*) AS cnt
               FROM semantic_relations
               GROUP BY relation_type ORDER BY cnt DESC"""
        )
        stats["relation_breakdown"] = {r["relation_type"]: r["cnt"] for r in rows}

        rows = self._execute_safe(
            """SELECT COUNT(DISTINCT object_id) AS cnt
               FROM semantic_relations WHERE object_type = 'target'"""
        )
        stats["targets_with_relations"] = rows[0]["cnt"] if rows else 0

        rows = self._execute_safe("SELECT COUNT(*) AS cnt FROM compound_targets")
        stats["chembl_activities"] = rows[0]["cnt"] if rows else 0

        # Optional auxiliary tables — surfaced only when populated, gated
        # with to_regclass so absent tables don't generate Postgres ERROR logs.
        for table, label in [
            ("compound_selectivity",         "compound_selectivity"),
            ("compound_indications",         "compound_indications"),
            ("compound_analogs",             "compound_analogs"),
            ("paper_mentions_compound",      "paper_compound_mentions"),
            ("patent_mentions_compound",     "patent_compound_mentions"),
            ("patent_inventors",             "patent_inventors"),
            ("target_interactions_ext",      "ppi_extended"),
            ("target_essentiality",          "depmap_essentiality"),
            ("target_coessentiality",        "depmap_coess_within_mosaic"),
            ("target_coessentiality_ext",    "depmap_coess_extended"),
            ("target_variant_pathogenicity", "alphamissense_targets"),
        ]:
            chk = self._execute_safe(
                "SELECT to_regclass(%(t)s) AS t", {"t": table}
            )
            if chk and chk[0].get("t"):
                rows = self._execute_safe(f"SELECT COUNT(*) AS cnt FROM {table}")
                stats[label] = rows[0]["cnt"] if rows else 0
        return stats

    def get_target_profile(self, target_symbol: str) -> dict[str, Any] | None:
        target = self._resolve_target(target_symbol)

        info = self._execute_safe(
            """SELECT id AS gene_symbol, name AS target_name,
                      target_class, uniprot_id, chembl_id, druggability_tier
               FROM targets WHERE id = %(target)s""",
            {"target": target},
        )
        if not info:
            return None
        profile = dict(info[0])

        counts = self._execute_safe(
            """SELECT
                  (SELECT COUNT(*) FROM compound_targets WHERE target_id = %(t)s) AS compound_count,
                  (SELECT COUNT(*) FROM patent_mentions_target WHERE target_id = %(t)s) AS patent_count,
                  (SELECT COUNT(*) FROM paper_mentions_target WHERE target_id = %(t)s) AS paper_count,
                  (SELECT COUNT(DISTINCT o.id)
                   FROM patent_mentions_target pmt
                   JOIN patent_organizations po ON po.patent_id = pmt.patent_id
                   JOIN organizations o ON o.id = po.org_id
                   WHERE pmt.target_id = %(t)s) AS organization_count""",
            {"t": target},
        )
        if counts:
            profile.update(counts[0])

        top_compounds = self._execute_safe(
            """SELECT c.id AS compound_id, c.name AS compound_name,
                      c.chembl_id, ct.value AS activity_value,
                      ct.activity_type, c.max_phase
               FROM compound_targets ct
               JOIN compounds c ON c.id = ct.compound_id
               WHERE ct.target_id = %(target)s
               ORDER BY ct.value ASC NULLS LAST LIMIT 5""",
            {"target": target},
        )
        profile["top_compounds"] = top_compounds

        # Optional genetic-evidence layers — only surfaced when the
        # auxiliary tables exist (graceful degrade on the fixture KG).
        ess = self._execute_safe(
            "SELECT to_regclass('target_essentiality') AS t"
        )
        if ess and ess[0].get("t"):
            row = self._execute_safe(
                """SELECT mean_gene_effect, dependency_fraction, n_models
                   FROM target_essentiality WHERE target_id = %(t)s""",
                {"t": target},
            )
            if row:
                profile["depmap"] = {
                    "mean_gene_effect": float(row[0]["mean_gene_effect"] or 0),
                    "dependency_fraction": float(row[0]["dependency_fraction"] or 0),
                    "n_models": int(row[0]["n_models"] or 0),
                }
        am = self._execute_safe(
            "SELECT to_regclass('target_variant_pathogenicity') AS t"
        )
        if am and am[0].get("t"):
            row = self._execute_safe(
                """SELECT n_variants, pct_pathogenic, hotspot_residues
                   FROM target_variant_pathogenicity WHERE target_id = %(t)s""",
                {"t": target},
            )
            if row:
                profile["alphamissense"] = {
                    "n_missense_variants": int(row[0]["n_variants"] or 0),
                    "pct_pathogenic": float(row[0]["pct_pathogenic"] or 0),
                    "hotspot_residues": row[0]["hotspot_residues"] or [],
                }
        return profile

    def find_modality_gaps(self, target_or_family: str) -> dict[str, Any]:
        """Which compound modalities are explored vs absent for a target.

        Target-level only: `targets.protein_family` is unpopulated in
        the production schema, so family-level rollups are not
        available (documented, not silently wrong). Modality is the
        heuristic SMILES classification on the top-N compounds —
        coverage is partial by design; unclassified compounds are
        reported separately.
        """
        t = self._resolve_target(target_or_family)
        exists = self._execute_safe(
            "SELECT 1 FROM targets WHERE id = %(t)s", {"t": t}
        )
        if not exists:
            return {
                "query": target_or_family,
                "resolved_target": None,
                "explored": {}, "absent_modalities": list(self.KNOWN_MODALITIES),
                "note": (
                    "Target not in the KG. Family-level modality rollups "
                    "are unavailable (protein_family not populated)."
                ),
            }
        rows = self._execute_safe(
            """SELECT COALESCE(c.modality, 'unclassified') AS modality,
                      COUNT(DISTINCT c.id) AS n
               FROM compound_targets ct
               JOIN compounds c ON c.id = ct.compound_id
               WHERE ct.target_id = %(t)s
               GROUP BY COALESCE(c.modality, 'unclassified')""",
            {"t": t},
        )
        explored = {r["modality"]: int(r["n"]) for r in rows}
        present = {m for m in explored if m in self.KNOWN_MODALITIES}
        absent = [m for m in self.KNOWN_MODALITIES if m not in present]
        return {
            "query": target_or_family,
            "resolved_target": t,
            "explored": explored,
            "absent_modalities": absent,
            "unclassified_compounds": explored.get("unclassified", 0),
            "note": (
                "Heuristic SMILES modality on top-ranked compounds; "
                "target-level only (no protein_family data for family rollups)."
            ),
        }

    def get_polypharmacology(self, compound_name: str) -> dict[str, Any]:
        """All targets a compound interacts with and the nature of each.

        Matches by pref_name, name, chembl_id, or any synonym so users
        can pass any common identifier. Returns target_name + target_class
        for each interacting target rather than bare gene symbols.
        """
        name_lower = compound_name.strip().lower()
        compound = self._execute_safe(
            """SELECT id, COALESCE(pref_name, name, chembl_id, id) AS display_name,
                      name, pref_name, chembl_id, max_phase, first_approval, molecule_type
               FROM compounds
               WHERE LOWER(pref_name) = %(name)s
                  OR LOWER(name) = %(name)s
                  OR LOWER(chembl_id) = %(name)s
                  OR EXISTS (
                       SELECT 1 FROM jsonb_array_elements_text(COALESCE(synonyms, '[]'::jsonb)) s
                       WHERE LOWER(s) = %(name)s
                  )
               LIMIT 1""",
            {"name": name_lower},
        )
        if not compound:
            return {"compound": compound_name, "found": False, "targets": []}
        cid = compound[0]["id"]
        cinfo = compound[0]

        rels = self._execute_safe(
            """SELECT sr.object_id AS target_id,
                      COALESCE(t.name, t.symbol, sr.object_id) AS target_name,
                      t.target_class,
                      sr.relation_type,
                      MAX(sr.confidence) AS max_conf,
                      COUNT(*) AS evidence_count,
                      array_agg(DISTINCT sr.source_doc_type) AS source_types
               FROM semantic_relations sr
               LEFT JOIN targets t ON t.id = sr.object_id
               WHERE sr.subject_id = %(cid)s
                 AND sr.subject_type = 'compound'
                 AND sr.object_type = 'target'
               GROUP BY sr.object_id, t.name, t.symbol, t.target_class, sr.relation_type
               ORDER BY max_conf DESC""",
            {"cid": cid},
        )

        target_profiles: dict[str, dict] = {}
        for r in rels:
            tid = r["target_id"]
            if tid not in target_profiles:
                target_profiles[tid] = {
                    "target_id": tid,
                    "target_name": r.get("target_name") or tid,
                    "target_class": r.get("target_class"),
                    "moa_types": [],
                    "max_confidence": 0,
                    "evidence_count": 0,
                }
            target_profiles[tid]["moa_types"].append(r["relation_type"])
            target_profiles[tid]["max_confidence"] = max(
                target_profiles[tid]["max_confidence"], r["max_conf"]
            )
            target_profiles[tid]["evidence_count"] += r["evidence_count"]

        targets_sorted = sorted(
            target_profiles.values(), key=lambda x: -x["max_confidence"]
        )

        indications: list[dict[str, Any]] = []
        ind_chk = self._execute_safe(
            "SELECT to_regclass('compound_indications') AS t"
        )
        if ind_chk and ind_chk[0].get("t"):
            ind_rows = self._execute_safe(
                """SELECT ci.indication_id, i.name AS indication_name,
                          ci.max_phase, ci.clinical_status
                   FROM compound_indications ci
                   LEFT JOIN indications i ON i.id = ci.indication_id
                   WHERE ci.compound_id = %(cid)s
                   ORDER BY ci.max_phase DESC NULLS LAST""",
                {"cid": cid},
            )
            for r in ind_rows:
                indications.append({
                    "indication_id": r["indication_id"],
                    "name": r.get("indication_name") or r["indication_id"],
                    "max_phase": int(r["max_phase"] or 0),
                    "clinical_status": r["clinical_status"],
                })

        analogs: list[dict[str, Any]] = []
        ana_chk = self._execute_safe(
            "SELECT to_regclass('compound_analogs') AS t"
        )
        if ana_chk and ana_chk[0].get("t"):
            ana_rows = self._execute_safe(
                """SELECT a.compound_b_id AS analog_id, c.name AS analog_name,
                          c.pref_name, c.max_phase,
                          a.tanimoto_similarity AS similarity
                   FROM compound_analogs a
                   LEFT JOIN compounds c ON c.id = a.compound_b_id
                   WHERE a.compound_a_id = %(cid)s
                   ORDER BY a.tanimoto_similarity DESC LIMIT 10""",
                {"cid": cid},
            )
            for a in ana_rows:
                analogs.append({
                    "compound_id": a["analog_id"],
                    "name": a.get("pref_name") or a.get("analog_name"),
                    "max_phase": a.get("max_phase"),
                    "tanimoto": round(float(a["similarity"]), 3),
                })

        return {
            "compound": cinfo.get("display_name") or cinfo.get("pref_name") or cinfo.get("name"),
            "compound_id": cinfo.get("id"),
            "chembl_id": cinfo.get("chembl_id"),
            "max_phase": cinfo.get("max_phase"),
            "first_approval": cinfo.get("first_approval"),
            "molecule_type": cinfo.get("molecule_type"),
            "found": True,
            "target_count": len(target_profiles),
            "targets": targets_sorted[:30],
            "indications": indications,
            "top_analogs": analogs,
        }

    def find_similar_targets(
        self, target: str, k: int = 10,
    ) -> dict[str, Any]:
        """Structurally similar targets ranked by Foldseek TM-score.

        Reads `target_structure_neighbors`. Empty payload + populate-hint
        when the table is absent or has no rows for this target; never
        raises.
        """
        t = self._resolve_target(target)
        has_table = self._execute_safe(
            "SELECT to_regclass('target_structure_neighbors') AS t"
        )
        loaded = bool(has_table and has_table[0].get("t"))

        if not loaded:
            return {
                "target": t,
                "neighbors": [],
                "total": 0,
                "k": k,
                "index_loaded": False,
                "method": (
                    "Foldseek 3Di+AA all-vs-all over AlphaFold PDBs. "
                    "Index not yet built — production deployments populate "
                    "this table from `data/alphafold/*.pdb`."
                ),
            }

        rows = self._execute_safe(
            """SELECT tsn.neighbor_id        AS symbol,
                      tsn.tm_score,
                      tsn.alntmscore,
                      tsn.evalue,
                      tsn.lddt,
                      tsn.rmsd,
                      tb.name                AS name,
                      tb.target_class        AS target_class,
                      tb.druggability_tier   AS druggability_tier
               FROM target_structure_neighbors tsn
               JOIN targets tb ON tb.id = tsn.neighbor_id
               WHERE tsn.target_id = %(t)s
               ORDER BY tsn.tm_score DESC NULLS LAST LIMIT %(k)s""",
            {"t": t, "k": max(1, min(int(k), 50))},
        )
        neighbors = [
            {
                "neighbor": {
                    "symbol": r["symbol"],
                    "name": r["name"],
                    "target_class": r["target_class"],
                    "druggability_tier": r["druggability_tier"],
                },
                "tm_score":  float(r["tm_score"])  if r["tm_score"]  is not None else None,
                "alntmscore": float(r["alntmscore"]) if r["alntmscore"] is not None else None,
                "evalue":    float(r["evalue"])    if r["evalue"]    is not None else None,
                "lddt":      float(r["lddt"])      if r["lddt"]      is not None else None,
                "rmsd":      float(r["rmsd"])      if r["rmsd"]      is not None else None,
            }
            for r in rows
        ]
        return {
            "target": t,
            "neighbors": neighbors,
            "total": len(neighbors),
            "k": k,
            "index_loaded": True,
            "method": (
                "Foldseek 3Di+AA all-vs-all over AlphaFold PDBs; "
                "tm_score normalised over query length"
            ),
        }


# ---------------------------------------------------------------------------
# Module-level factory (singleton)
# ---------------------------------------------------------------------------

_default_queries: GraphQueries | None = None


def get_graph_queries() -> GraphQueries:
    global _default_queries
    if _default_queries is None:
        _default_queries = GraphQueries()
    return _default_queries
