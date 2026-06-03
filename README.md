# Mosaic reproducibility package

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Companion data archive](https://img.shields.io/badge/Data%20archive-10.5281%2Fzenodo.20529685-blue)](https://doi.org/10.5281/zenodo.20529685)

This repository is the public reproducibility surface for the Mosaic
preprint:

> **Mosaic: a knowledge-graph + MCP-tool layer for pre-clinical R&D
> intelligence.** Sourabh Nyalkalkar, 2026. bioRxiv (DOI pending).

It is the artefact the paper's §8 reproducibility statement points
readers at. **The production source code is held in a separate
private repository** (see §9 of the paper for the release-posture
rationale); this repo contains the minimum public-safe slice needed to
re-run the §5.4 case-study tool outputs against a hand-curated fixture
mini-KG on a fresh VM with only Docker installed.

> **Scope.** Mosaic's production knowledge graph is 363 oncology
> targets, ~12.8K compounds, ~35K papers, ~14K patents — too large
> to redistribute here. The full production data is released as a
> separate versioned public archive (see §9 of the paper). This
> repository ships a **fixture mini-KG** of 10 targets, 24 compounds
> and 30 landmark papers, hand-curated from public sources, and runs
> the production pipeline against that fixture so a reader can
> confirm the *architecture* end-to-end.

---

## Quickstart

```bash
git clone https://github.com/sourabhnk/mosaic-reproducibility.git
cd mosaic-reproducibility
docker compose up --build
```

Expected wall-clock on a fresh VM with 4 vCPU / 8 GB RAM:

- first run (image build + Postgres + AGE init): **~6–10 min on
  Linux**, longer on Windows Docker Desktop because of WSL2
  filesystem overhead
- subsequent runs (cached image, fresh DB): **~30 s**

When the `repro` container exits cleanly you'll find a populated
`./output/` directory:

| file | what it is |
|---|---|
| `MANIFEST.md` | row counts, kg_metadata snapshot, index of artefacts |
| `mosaic_kg_stats.json` | overall scope of the fixture mini-KG |
| `mosaic_get_target_profile_EGFR.json` | canonical "full dossier on EGFR" tool output |
| `mosaic_modality_gaps_BRD4.json` | modality matrix for BRD4 — covalent / degrader / macrocycle absent flags |
| `mosaic_polypharmacology_imatinib.json` | every target imatinib interacts with in the fixture |
| `mosaic_find_similar_targets_BRAF.json` | structural-similarity tool output. **Empty + an "index not built" hint by design** — confirms the tool degrades gracefully when the Foldseek index is absent. In the production deployment the table is populated by an offline Foldseek run; this fixture deliberately ships without it. |

---

## What the fixture contains

### Targets (10)

EGFR, KRAS, BRAF, BRD4, ERBB2 (HER2), PDCD1 (PD-1), CDK4, ABL1,
PARP1, ALK — six kinases, one GTPase, one epigenetic reader, one
immune checkpoint, one DNA-repair enzyme. UniProt IDs and target
classes are from [UniProtKB](https://www.uniprot.org). See
[`fixtures/targets.csv`](fixtures/targets.csv).

### Compounds (24)

Canonical approved or clinical-stage drugs for each target —
erlotinib, gefitinib, osimertinib, afatinib, sotorasib, adagrasib,
vemurafenib, dabrafenib, encorafenib, JQ1, dBET1, trastuzumab,
lapatinib, pembrolizumab, nivolumab, palbociclib, ribociclib,
imatinib, dasatinib, nilotinib, olaparib, niraparib, crizotinib,
alectinib. ChEMBL IDs from [ChEMBL release
34](https://www.ebi.ac.uk/chembl/). See
[`fixtures/compounds.csv`](fixtures/compounds.csv).

### Compound → target activity (27)

Hand-curated IC50 / Kd / DC50 values from the cited primary
literature and FDA labels. See
[`fixtures/compound_targets.csv`](fixtures/compound_targets.csv).

### Papers (30) + paper → target (29)

Three landmark papers per target — first-in-class clinical reports
(Paez 2004 for EGFR/gefitinib, Chapman 2011 for vemurafenib/BRAF,
Hong 2021 for sotorasib/KRAS G12C, …) cited by PMID + DOI. See
[`fixtures/papers.csv`](fixtures/papers.csv) and
[`fixtures/paper_mentions_target.csv`](fixtures/paper_mentions_target.csv).

---

## Data sources cited

| source | use | license |
|---|---|---|
| [UniProtKB](https://www.uniprot.org/help/license) | target IDs, gene names, target classes | CC BY 4.0 |
| [ChEMBL r34](https://chembl.gitbook.io/chembl-interface-documentation/about) | compound IDs, names, max phase | CC BY-SA 3.0 |
| [PubMed](https://www.nlm.nih.gov/databases/download/data_distrib_main.html) | paper PMIDs, titles, DOIs, dates | NIH PubMed terms (public domain metadata) |
| [Crossref](https://www.crossref.org/documentation/retrieve-metadata/rest-api/rest-api-metadata-license-information/) | DOI resolution + journal names | CC0 |

All values shipped in `fixtures/*.csv` are either (a) factual public
metadata or (b) hand-typed by the author from the cited primary
literature (activity values). No proprietary derivative data.

---

## Architecture vs. full-data reproducibility

This package demonstrates **architecture reproducibility**: the same
schema, query layer, and tool surface that back the production
deployment, exercised against the fixture mini-KG so a reader can
confirm the pipeline shape end-to-end. It does not re-run the
production ingestion pipeline (GLiREL relation extraction over 35K
abstracts, AlphaFold + Foldseek over 320 PDBs, DepMap co-essentiality
backfill, etc.) — those require substantial compute and are not
bundled.

**Full-data reproducibility** of the production knowledge graph is
enabled separately, through the public data archive at
<https://github.com/sourabhnk/mosaic-data> (Zenodo DOI
[10.5281/zenodo.20529685](https://doi.org/10.5281/zenodo.20529685)
for the paper-v1 snapshot). A reader can either:

1. Download the versioned production dumps and load them into a
   local Postgres + AGE instance, then re-run the case studies, or
2. Query the live MCP server directly using a free-tier Bearer token,
   which exposes the same numbers without standing up infrastructure.

The live MCP server lives at <https://mcp.getmosaic.dev>; documentation
for the Bearer-token flow is at <https://getmosaic.dev/docs>.

---

## What's in this repository

```
mosaic-reproducibility/
├── README.md                       (this file)
├── LICENSE                          MIT
├── Dockerfile                       slim image for the repro container
├── docker-compose.yml               postgres + repro orchestration
├── fixtures/
│   ├── targets.csv                  10 oncology targets
│   ├── compounds.csv                24 compounds
│   ├── compound_targets.csv         27 activity edges
│   ├── papers.csv                   30 landmark papers
│   └── paper_mentions_target.csv    29 paper→target edges
├── init-scripts/
│   ├── 01_init_graph.sql            AGE extension + graph init
│   ├── 02_graph_schema.sql          graph schema
│   └── 03_target_structure.sql      structural-similarity table
├── scripts/
│   └── run_repro.py                 driver: schema → fixtures → tools → JSON
└── src/
    └── db/
        ├── connection.py            psycopg ConnectionManager (production verbatim)
        ├── schema.sql               full production schema
        └── queries.py               slim query layer (5 reproducibility-relevant methods)
```

`src/db/queries.py` is a **subset** of the production query layer —
just the five methods that `scripts/run_repro.py` invokes
(`get_kg_stats`, `get_target_profile`, `find_modality_gaps`,
`get_polypharmacology`, `find_similar_targets`) plus their immediate
helpers. The other ~40 production tools and the full query helper set
remain in the private production repository.

---

## Verification checklist

A successful end-to-end run produces all six of the following:

- [ ] `docker compose up --build` completes with exit 0
- [ ] `./output/` contains the 6 files listed above
- [ ] `MANIFEST.md` shows `target_count: 10  compound_count: 24  paper_count: 30`
- [ ] `mosaic_get_target_profile_EGFR.json` contains a non-empty `top_compounds` array with the four EGFR drugs (erlotinib, gefitinib, osimertinib, afatinib)
- [ ] `mosaic_modality_gaps_BRD4.json` lists `degrader` in `explored` (dBET1) and `covalent` + `macrocycle` + `peptide_like` in `absent_modalities`
- [ ] `mosaic_find_similar_targets_BRAF.json` returns `{"neighbors": [], "total": 0, "index_loaded": true, …}` — graceful degrade (table exists, empty until the Foldseek index is built)

All checks pass → the pipeline is end-to-end reproducible from public
data on a fresh VM.

---

## License

Code in this repository: MIT License (see `LICENSE`).

Fixture data (`fixtures/*.csv`) is derived from public sources cited
above; their respective upstream licences apply to redistribution.
