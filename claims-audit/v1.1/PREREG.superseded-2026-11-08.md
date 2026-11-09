# Claims audit, v1.1: the widened first run. Pre-registration

**Status:** written 2026-11-07, not yet registered. It is registered when this file is committed, published in `sourabhnk/mosaic-reproducibility` and timestamped, and `PUBLIC_TIMESTAMP.md` records the sha256, commit and URL (as for v1). No document dated in the window has been opened.

**Why v1.1 exists.** v1's first run (`docs/audits/claims_audit_2024Q4.md`, Finding 1) had 15 competitive claims from 5 filings, one holding 7. That gives a direction, not a rate (operator, 2026-11-07, `docs/audits/blockers.md` B-P3-11). v1.1 widens the run to four quarters, Q4 2024 (v1) plus Q1 to Q3 2025, so the rate can be estimated and quoted. It selects prospectus competition sections only: in v1, every competitive claim came from one, and the 8 deal releases made none.

**What was seen before this was written.** v1's 29 claims, and the rules written after reading them (verdicts-v1.2: the split no-number reason and the name check, B-P3-11). So v1's quarter is a development quarter, and **the headline comes from Q1 to Q3 2025 alone**. The four-quarter pool is reported beside it, labelled as including the development quarter.

## 1 · Question

**Primary.** Among competitive claims (v1 PREREG class B) about a target, in the competition sections of oncology S-1 and F-1 prospectuses filed 2025-01-01 to 2025-09-30, what share states nothing Mosaic can check? That is the share whose verdict, restated in verdicts-v1.2, is `cannot_verify_unscoped`.

**Secondary.**
- The unscoped claims' reasons: `scope_no_count`, `no_scope_no_count`, `no_scope_stated`, `scope_incompatible`.
- How many name a competitor.
- How many state a scope.
- How many get Mosaic's own count beside them.
- How many have a stated scope that Mosaic's query reproduces.
- How many only name products, and how the name check reads them (confirmed, floor).
- The same figures pooled over four quarters, with v1.

## 2 · Selection rule (fixed before any document is opened)

**Window:** filing dates 2025-01-01 to 2025-09-30 inclusive, US Eastern.

**Source B only:** v1 PREREG §2's Source B rule, unchanged. That is the *Competition* subsection of the Business section of every original **S-1** or **F-1** (not amendments) filed on SEC EDGAR in the window, by an issuer with SIC 2834 or 2836 whose prospectus summary names cancer as the lead programme's indication. The mechanics are also v1's:
- the filings come from EDGAR's quarterly indexes `full-index/2025/QTR1`, `QTR2` and `QTR3`, `form.idx`;
- the SIC comes from `data.sec.gov/submissions`;
- the Competition subsection runs from its heading to the next heading of the same level;
- requests identify themselves as `Mosaic claims audit support@getmosaic.dev`.

**Source A (deal releases) is not selected.** In v1 it yielded no absence or competitive claim from 8 documents. That was v1's sample-composition finding, and this rule is chosen because of it.

**Screening:** as v1: each candidate's text is screened against the rule by Claude, in a recorded session (`selection/data/screening.json`, with the deciding passage for each criterion), and the operator reviews it. `SELECTION.md` and `selection.json` list every qualifying document, with URL, filing date, the reason it qualifies, its retrieval and its sha256. `selection.json` pins the sha256 of every ChEMBL release extract and names file the run reads.

**Size:** every qualifying document is audited. If more than 60 qualify, a seeded random draw of 60 (seed `claims-audit-v1.1`) is audited and the full list reported.

**The order of work** is v1's, enforced by `mosaic/audit/run_v1_1.py`. Each step refuses to run before the one ahead of it:
1. register (this file, then `PUBLIC_TIMESTAMP.md`);
2. select and screen, then the operator reviews;
3. commit `SELECTION.md` and `selection.json`;
4. extract, one recorded model call per document;
5. the operator reviews the spans, blind to any Mosaic result;
6. adjudicate: the first fetch happens here. Every run writes a new `results/run-<UTC time>/` and records the hashes of the recordings, reviews and selection. A later run refuses if any differs.

## 3 · Time anchor

v1 PREREG §3, unchanged. Each filing's date is its as-of date. The ChEMBL release in force is ChEMBL 35 through 2025-09-18 and ChEMBL 36 from 2025-09-19 (`connectors/chembl_release.RELEASES`).
- **Extracts:** `chembl_35.sqlite` (sha256 `824342b4f60a12785c900e4bacf35817eacaf3ca20a0fd070a5e33c0cbd87254`) and `chembl_36.sqlite` (sha256 `22ef51aaf764a75ef18a8238691a7cfdff2f42f2a9000f13ad7766553b96b799`). Both were trimmed by v1's `trim_chembl_version.py`.
- **Names files:** `chembl_35_names.sqlite` (sha256 `a32c39097166c877e51fb50e542dcb7b643b50188db9f8d624da6faa4887f9f0`) and `chembl_36_names.sqlite` (sha256 `2e53a5f9e4b94bbfaddf2555c1ddd0177c8898ddeb23b2ae44403dde00052a3c`). Both were built by `scripts/build_chembl_names.py` from the same releases.

`selection.json` pins all four, and the run refuses a file that differs.

## 4 · Claims: what is extracted, and how each is classified

v1 PREREG §4, unchanged: the same extractor, model, prompt, schema and class definitions (frozen in §9), and the same blind span review by the operator.

## 5 · Verdicts

The registered adjudicator (`verify/verdicts.py`, v1 PREREG §5, tolerance absolute 0 or relative 0.1) and the seven-state restatement, **verdicts-v1.2** (`verify/restate.py`):
- every registered verdict but `cannot_verify_unavailable` passes through;
- an unavailable one splits by the branch of rule 3 that produced it: Mosaic's side stays `cannot_verify_unavailable`, and the claim's side becomes `cannot_verify_unscoped`, with one of four reasons (§1);
- **the name check** (`verify/name_match.py`) applies to a class B claim with no count whose span names a molecule the release lists with a mechanism on the claim's target, and contains none of its fixed words (several, multiple, many, numerous, various, other, number, companies, company, candidates, programs, programmes). It reads `confirmed` when every named molecule meets the claim's stage, and `cannot_verify_floor` when one is listed below it. It never reads `contradicted`.

## 6 · Outcomes

**Primary:** the share in §1, over the class B claims of the Q1 to Q3 2025 documents. It is reported with n, and the **quoted** 95% interval is a percentile bootstrap that resamples filings (10,000 draws, seed `claims-audit-v1.1`), because claims cluster within a filing. Clopper–Pearson is reported beside it.

**Secondary:** each count in §1, by the functions in `mosaic/audit/restated.py`:
- `names_a_competitor`;
- `scope_reproduced`;
- Mosaic's count shown when it has one;
- the name check's results, from the run's `name_checks.json`.

The four-quarter pool (v1's restated rows plus v1.1's) is reported beside the primary, with its own filing-resampled interval, labelled "includes the development quarter".

**Graceful failure, as v1:**
- a document that yields no auditable claims is excluded, with the reason;
- a source unavailable for the date is `cannot_verify_unavailable`, never dropped from the denominator.

## 7 · Predictions, stated before any document is opened

| # | prediction |
|---|---|
| V11-P1 | the primary share is **at least 50%** |
| V11-P2 | `scope_no_count` is the **most common** reason among the unscoped claims |
| V11-P3 | Mosaic's query reproduces the stated scope for **under 20%** of the claims that state one |
| V11-P4 | **none** of the claims is `contradicted` |
| V11-P5 | the Q1 to Q3 2025 documents yield **at least 30** class B claims |

A prediction is met when the point estimate falls on its side. Not met is reported in those words, and is not grounds for re-running.

## 8 · Stopping rule

- **One registered run.** After the first 2025 document is opened, nothing in §2 to §6 changes. A change is a v1.2 with its own pre-registration.
- **Fewer than 30 class B claims:** the run is reported as underpowered, with its n and interval, and no rate is quoted from it. No quarter is added to reach a number without a new registration.
- **No re-running to a result.** A fetch that fails is retried once, then stands as unavailable.

## 9 · Frozen inputs

`python -m audit.run_v1_1 frozen` prints this block, and the registration gate (`python -m audit.run_v1_1 check`) refuses if any file, extractor setting or constant differs from it.

```json
{
  "files": {
    "mosaic/audit/run.py": "0add9d02da22f4446b270eefb821ce3c52fd2b3f5b34090ecf5babc1ee63c1c5",
    "mosaic/audit/extract.py": "6cb79d19791c6be4318dbcc203f4ad48a628b7c7b6eb1a01ef80f0855828aa03",
    "mosaic/audit/prompts/extract_v1.md": "9ca71f726b1a85ac470f5425109bfbaeb3c4fdb34d9126ca936b5582d72d2db9",
    "mosaic/verify/verdicts.py": "34c0577643bcfd5965875f3fc8be108e4a8a0add8a82b8b43739e7624daab07b",
    "mosaic/verify/quotes.py": "756f20fb8afe37c1f9a1e5dab73427f030099807c33c535ea9cfe582276847d8",
    "mosaic/connectors/base.py": "85ef3551a36a63ee438282dada2c08bc7e05c12fa2965beee7788f7dfda6bc6c",
    "mosaic/connectors/chembl_release.py": "674a0a4f30d6ef2cd429afcd17f236d37fc341d0a94225de4943edd6ae62024c",
    "mosaic/connectors/ctgov.py": "98db64eb58201f80c9ab272af2dcfb63f0a435f905c0f3fea53ee7413129094e",
    "mosaic/connectors/pubmed.py": "a45b68803e2fc0170b4d5058983cf6d55aa2429339941b5ddb2ee97e15001643",
    "mosaic/connectors/epo.py": "e8464ed0754cce3df44efe53b7b97a4c12af2590a5fd232e464d5871f410e431",
    "mosaic/src/ingestion/connectors/epo.py": "237156ce83f1ac6887a97d459d7ea1afe1a33e74669b4b765741e9c5d195f8c0",
    "mosaic/src/db/alias_resolution.py": "b502e729c4388371cfd0129be94233c244d18aff207e7c3fbac8e7dcdaa414d5",
    "mosaic/config/axis_queries.yaml": "52a4dc92d160428dfab627ae8fe72a827f2a82f2dc90fffdffb4455181a5a9c4",
    "mosaic/scripts/axis_query_registry.py": "bb55621316eb44f1d543ca62a33d0449319efdf078fd4aa32411675af4b6408e",
    "mosaic/audit/run_v1_1.py": "d1c9b113bcda2c610bfca5a8d373d6a9a9ff384a03ebb8099aa4d61f150853c1",
    "mosaic/verify/restate.py": "5536bdc539ff3368936bed695676e8e3094b68d2011f639e6aa5fdf47ca1359f",
    "mosaic/verify/name_match.py": "21fe66ebad727d34d282fb99df672b364b03dbce67ea1d24b3d2b9e16428882d",
    "mosaic/audit/restated.py": "ed61f4badc615de72c68e9137b2cce810d8436baa0fd99ae825d3e033f80d861",
    "mosaic/scripts/build_chembl_names.py": "a0b62faa7cb429393712c78f675791b2c88ae42ffa218ac3d8c6401110c4eb69"
  },
  "extractor": {
    "model": "claude-opus-5-5",
    "effort": "high",
    "max_tokens": 32000,
    "prompt_version": "extract-v1",
    "schema_sha256": "de8c8fbb493f2ca81fa7b3b44bd9fb46524e8fbd98dfeecfda4721c0e620d7f9",
    "matcher_version": "quotes-2",
    "span_methods_accepted": [
      "exact",
      "exact_markup"
    ]
  },
  "constants": {
    "window": [
      "2025-01-01",
      "2025-09-30"
    ],
    "sources": [
      "B"
    ],
    "tolerance": {
      "absolute": 0,
      "relative": 0.1
    },
    "seed": "claims-audit-v1.1",
    "bootstrap_n": 10000,
    "vocabulary": "verdicts-v1.2",
    "chembl_releases": [
      [
        "chembl_34",
        "2024-04-15"
      ],
      [
        "chembl_35",
        "2024-12-11"
      ],
      [
        "chembl_36",
        "2025-09-19"
      ]
    ]
  }
}
```

## 10 · Prerequisites, checked before any document is opened

1. **v1's restated report is on `main`:** `docs/audits/claims_audit_2024Q4.md`, Finding 1 as a first run, with the corrected sentence.
2. **`PUBLIC_TIMESTAMP.md` exists** and passes the registration gate.

## 11 · What would make this result wrong, stated in advance

- **The rules were written after reading v1's claims.** That is why the headline excludes v1's quarter.
- **"Names a competitor" and "reproduces the stated scope" are mechanical rules** (`audit/restated.py`), not readings. A person could read a span differently. Both rules are printed in the report, and every row shows the span.
- **The name check can only confirm, or floor.** A product ChEMBL lists below its approval reads as a floor, which is ChEMBL lagging the record, not the document being wrong.
- **2025's IPO market may yield few prospectuses.** §8's stopping rule handles a small n honestly.
