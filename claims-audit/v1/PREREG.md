# Claims audit, v1: time-anchored, Q4 2024. Pre-registration

> **REGISTERED 2026-11-05 (amendment 1).** The commit that makes this version of the file is the registration. It supersedes the registration of 2026-11-04 (commit `27b04160`, sha256 `f230f6d45682197ed241c1782921593f4290864b27e8ff85f6f96a62db78ac45`).
>
> **Why it was superseded:** that registration's Source A query could not run on either site (§2, D10). Only these parts changed:
> - Source A;
> - two new paragraphs in §2, on screening and on Source B's mechanics;
> - §10's D10;
> - one risk in §11;
> - this banner.
>
> Every other rule and every pinned input in §9 is unchanged. The operator approved the content on 2026-11-04, and amendment 1 on 2026-11-05 (§10).
>
> What was frozen before it:
> - the verdict engine (PR #84);
> - the extractor (PR #85);
> - the run script, with its connectors (PR #86).
>
> §9 pins their sha256.
>
> **No document in the window was opened before this commit.** The extractor and the run were developed on a release dated 2026. Amendment 1's filters were tested on listing pages outside the window, and only those pages' dates were read.
>
> `PUBLIC_TIMESTAMP.md` records three things, as in `../../judge-fabrication/v2/`:
> - this commit;
> - this file's sha256 (CRLF read as LF);
> - the public URL where it was published.
>
> The run script refuses to go on unless all three agree with this file. Any edit after this commit is a new pre-registration with a new hash, not a correction to this one.

## 1 · Question

When a biotech deal announcement or an IPO prospectus makes a claim about a drug target's competitive landscape (who else is there, whether anyone is, how crowded it is), how often did the evidence available **on that date** support it? And how often could nobody have checked it, because the only evidence was incomplete?

This is the source of the plan's new headline (§3.3a): **the share of absence or competitive claims whose verdict is `cannot_verify_floor` or `contradicted`.**

## 2 · Selection rule (fixed before any document is opened)

**Window:** publication dates 2024-10-01 to 2024-12-31 inclusive, US Eastern time.

**Source A: deal announcements.** Press releases are listed by each site's own subject and industry filters, read newest first back to before the window (amendment 1, D10):
- **GlobeNewswire** (the globenewswire.com search): Industry **Biotechnology**, and separately **Pharmaceuticals**, each with Subject **Licensing Agreements**, **Mergers and Acquisitions**, **Partnerships**, **Business Contracts** and **Joint Venture**, one subject at a time. That is 10 listings.
- **Business Wire** (the businesswire.com newsroom): Industry **Health › Oncology**, with Subject **Merger/Acquisition**, and separately **Contract/Agreements**. That is 2 listings.

Neither site filters by date. So each listing is paged newest first until it passes releases dated before 2024-10-01. Every release dated in the window (US Eastern) is a candidate. The candidates are the union of the listings, by URL. `SELECTION.md` records the URL of every listing page read.

The registered query, `(license OR licensing OR collaboration OR acquire OR acquisition OR merger OR option) AND (oncology OR cancer OR tumor OR tumour)`, cannot run on either site. GlobeNewswire's search box takes at most 35 characters and has no boolean syntax; passed in the URL, the full query returns 3 releases, all outside the window. Business Wire's keyword filter reads it as one phrase and returns none.

A release is in if all four hold:
1. it announces a new licensing, collaboration-with-licence, option-to-licence, acquisition or merger agreement;
2. the asset, or the acquired company's lead asset, is for cancer;
3. the stated total value is at least US$100M (upfront plus milestones, "up to" amounts included, other currencies converted at the release date's rate);
4. it is in English.

A release is out if it amends or extends an existing deal, reports a financing round or earnings, or states no value.

One document per deal: the earliest release; if two releases share a timestamp, the licensor's (or the acquired company's).

**Screening** (amendment 1). Each candidate's text is read and screened against criteria 1–4 and the exclusions by Claude, in a recorded session. For each criterion, `screening.json` records:
- the decision;
- the verbatim passage that decides it: the stated value, the words that make the deal new, the cancer indication.

Another currency is converted to US$ at the release date's rate, and the rate and its source are recorded. Before `SELECTION.md` is committed, the operator reviews every included document, and every exclusion on criterion 1 (deal type) or criterion 3 (value). A change made in review is logged with its reason.

**Source B: IPO prospectuses.** The *Competition* subsection of the Business section of every original **S-1** or **F-1** (not amendments) filed on SEC EDGAR in the window by an issuer with SIC 2834 or 2836 whose prospectus summary names cancer as the lead programme's indication. If none qualifies, Source B contributes zero, and the report says so.

**Source B mechanics** (amendment 1; the rule is unchanged):
- **Which filings:** form type exactly `S-1` or `F-1` in EDGAR's quarterly index (`full-index/2024/QTR4/form.idx`), with a filing date in the window.
- **The issuer's SIC:** read from its EDGAR company record (`data.sec.gov/submissions`).
- **The Competition subsection:** the text from its heading, inside the Business section, to the next heading of the same level.
- **SEC requests** identify themselves as `Mosaic claims audit support@getmosaic.dev`, as SEC's fair-access policy requires.

**Size:** every qualifying document is listed in `SELECTION.md`, with URL, date, the reason it qualifies, its retrieval and sha256. If more than **60** qualify, a seeded random draw of 60 (seed `claims-audit-v1`, stratified by source in proportion) is audited, and the full list is reported.

**The order of work** (each step is a gate in `mosaic/audit/run.py`, which refuses to run a step before the one ahead of it):
1. Register (this file, then `PUBLIC_TIMESTAMP.md`).
2. Run the selection: documents are screened against the rule, which needs their text (`screening.json`, reviewed by the operator).
3. Commit `SELECTION.md` and `selection.json` before any claim is extracted. `selection.json` lists each document's id, source, URL, as-of date, text file and sha256. It also lists, as `chembl_release_sha256`, the sha256 of each ChEMBL release file the run will read. The run refuses a selection committed in, or before, the registration commit.
4. Extract: one recorded model call per document (`audit.run extract`). Commit the recordings (`extractions/<id>.cassette.json`).
5. Review the spans, blind to any Mosaic result, and commit `review/<id>.json` for every document (§4). Each review names the sha256 of the recording it was made on.
6. Fetch and adjudicate (`audit.run adjudicate`); the first fetch happens here.
   - Every document's claims are checked before that fetch.
   - Each run writes a new `results/run-<UTC time>/` and never overwrites one.
   - Before it fetches, each run records the hashes of the recordings, the reviews and the selection. A later run refuses if any of them differs from the first run's, so no review changes after verdicts are seen.
   - Each results directory is committed.
7. Report (`audit.run report`): recomputed from one registered run's rows, never from a development run.

Development runs (`audit.run dev`) refuse any document dated inside the window and never write under `eval/claims-audit/`.

The selection does not depend on what Mosaic later finds.

**No hand-picking.** The mix of programmes that later succeeded and failed is whatever the rule yields. Outcomes are not a selection criterion and are not looked up before the main report is written (§7).

## 3 · Time anchor

Each document's date (the release timestamp, or the EDGAR filing date) is its **as-of date**. Every Mosaic fetch for its claims runs with the cutoff set to that date. Each verdict states that its evidence set was reconstructed to that date, and names what could not be.

| axis | reconstructed to the as-of date by | what cannot be reconstructed |
|---|---|---|
| papers | PubMed publication date `[dp]` ≤ as-of | papers dated earlier but indexed later are included; PubTator3's annotations are today's |
| trials | ClinicalTrials.gov first-posted date ≤ as-of (`AREA[StudyFirstPostDate]RANGE[MIN,as-of]`) | the trial's status on that date (current status is shown). **The trials axis is a permanent floor (operator, 2026-08-18): a search that finds anything is a floor, so a trials claim compared on it reads `cannot_verify_floor`.** A zero reads `cannot_verify_unavailable`: the search is on the HGNC symbol, and the target's other names are not searched (on this window, CLDN18 finds 0 studies where "Claudin18.2" finds 43). So a trials claim reads floor or unavailable, never confirmed or contradicted. A known search-hazard symbol is not sent (`cannot_verify_unavailable`). |
| patents | EPO publication date ≤ as-of | filings unpublished on that date (≈18-month lag) are absent for everyone; stated, not adjusted. Publications dated earlier but indexed later are included |
| compounds | the ChEMBL release in force on the as-of date: the latest whose files EBI's FTP had published by then. **ChEMBL 34 from 2024-04-15; ChEMBL 35 from 2024-12-11.** It is loaded from EBI's archive. Its file must hash to the sha256 that `selection.json` pins for it, and its own `version` table must name that release | if that release is not loaded before the run, the axis is `cannot_verify_unavailable` for that document |
| organizations | (none) | no dated count of patent assignees exists: `cannot_verify_unavailable` |
| bulk axes (ppi, essentiality, coessentiality, constraint, genetic association) | the pinned release in force on the as-of date | the current pins postdate Q4 2024; without an earlier pin, `cannot_verify_unavailable` |
| structure | (none) | AlphaFold DB keeps no dated snapshots: `cannot_verify_unavailable` |

**Mosaic's papers and patents queries carry their own limits.** Papers: published 2020-01-01 onwards, with a drug-topic filter. Patents: published 2020-01-01 onwards, oncology CPC classes, title match. Under §4's scope rule, a claim is compared on these axes only when it states the same limits. In practice these claims read `cannot_verify_unavailable`. The fetch is still made, and both queries are shown on the row.

**Built before this registration (PR #86):**
- `connectors/ctgov.py` and `connectors/pubmed.py` take the as-of date;
- `connectors/chembl_release.py` reads a dated release.

The ChEMBL 34 and 35 files are loaded after it, and pinned in `selection.json`. None of this changes a rule above.

## 4 · Claims: what is extracted, and how each is classified

**Unit:** one assertion, about one target (a gene or protein, or a target class named by its members), made by the document itself. Assertions about the issuer's own compound's data, financial terms, regulatory designations and forward-looking statements are not extracted.

**Extraction:** §3.3's extractor (`mosaic/audit/extract.py`), with its model, prompt and version frozen in §9, runs once per document. Every claim stores its verbatim source span. A reviewer checks spans against the document blind to any Mosaic result. Each document's review is `review/<id>.json`, committed before any fetch. It records:
- each claim removed, by number, with the reason;
- each claim added, with the reason. An added claim passes the same verbatim-span and classification checks as the model's;
- or the whole document excluded, with the reason.

Each run lists every review change in its `review_log.json`.

**Classification, before any fetch:**

| class | what it asserts | adjudicated how |
|---|---|---|
| **A · absence** | no one else is there, stated outright: "first-in-class", "no approved therapy targets X", "the only clinical-stage". A lack of therapy that is hedged ("often", "most") or qualified ("safe", "durable", "effective") is class E: no count settles it (D8) | count 0 on the axis and measure named in the claim (below) |
| **B · competitive** | how many or who: "N competitors", "a crowded field", "a leading patent position" | its stated count; no number stated → `cannot_verify_unavailable` ("the claim states no count"), kept in the denominator |
| **C · quantitative evidence** | a number about the target's evidence: "over 400 publications" | its stated count |
| **D · qualitative science** | mechanism, validation, rationale: "KRAS is a validated target" | `out_of_scope`: Mosaic counts evidence; it does not adjudicate a mechanism's truth |
| **E · not a target claim** | prevalence, toxicity, unmet need, the issuer's own data | not extracted (or `out_of_scope` if extracted) |

**Measures for classes A to C:**
- **Approved or clinical-stage molecules on the target:** ChEMBL mechanisms in the dated release, distinct parent molecules with `max_phase` at least 4 (approved) or at least 0.5, Early Phase 1 and later (clinical). A parent whose phase ChEMBL marks unknown is counted only at `any`. A zero at `approved` is compared. A zero at `clinical` or `any` reads `cannot_verify_unavailable`: ChEMBL curates mechanisms for named drugs, and a code-named candidate may have none. Every claim on this axis states which: `approved`, `clinical` or `any`. These are carried as the units `approved molecules`, `clinical-stage molecules` and `compounds`. A claim whose stage is unclear reads `cannot_verify_unavailable` and is never compared with every compound on the target (D8).
- **Competitor organisations:** no dated count of patent assignees exists, so claims on this axis read `cannot_verify_unavailable`.
- **Trials:** the trials axis; a floor, or unavailable on a zero (§3).
- **Papers and patents:** their axes, each with its own limits (§3).

**One target per comparison.** Every target is resolved by HGNC. A class A to C claim that names several targets reads `cannot_verify_unavailable`, because Mosaic counts one target at a time. So does a claim on a target HGNC cannot resolve.

**Modality-scoped claims.** A claim scoped to a modality ("first antibody–drug conjugate against X") is classified A or B only if its target-level reading is stated. Otherwise it is `out_of_scope`, because Mosaic does not classify modality. It is out of the headline denominator. The extractor records what it asserts (`claim_class`) and its class here (`prereg_class` = `out_of_scope`).

**Scope must be reproducible.** A count is compared only when its stated scope is one Mosaic's declared query reproduces. The scope travels as the claim's unit (`verdict_unit` in the extractor), and a different unit reads `cannot_verify_unavailable` (§3.2's unit rule). The scope includes:
- period;
- field or indication;
- variant or mutation;
- patient group or line of therapy;
- phase;
- geography;
- source.

A class B or C count stated with no scope is unscoped and is not compared. A class A or B claim with a limit Mosaic cannot reproduce ("the first KRAS G12D inhibitor") stays in the headline denominator as `cannot_verify_unavailable` (D8).

## 5 · Verdicts and tolerance

The six verdicts of `mosaic/verify/verdicts.py` (§3.2, operator rulings B-P3-1 and B-P3-2), applied in its order, at the commit pinned in §9:

1. `out_of_scope`;
2. `cannot_verify_same_source` (any same-source pair);
3. `cannot_verify_unavailable`;
4. `cannot_verify_floor`;
5. `confirmed` or `contradicted`.

**Tolerance:** relative **10%**, absolute 0. Zero is compared exactly, so "none" against one is a contradiction.

**"At least N" claims are lower bounds (D2).** A complete count of N or more, less the 10% slack, confirms "at least N", and a smaller one contradicts it. Against a floor on Mosaic's side, it stays `cannot_verify_floor`.

Every row of the report carries both queries, both counts and units, both sources, the cutoff, the evidence-set hash and the rule that fired.

## 6 · Outcomes

**Headline:** among class A and B claims, the share whose verdict is `cannot_verify_floor` or `contradicted`.

**The denominator is every class A and B claim,** including `cannot_verify_unavailable` and `cannot_verify_same_source`. Nothing is dropped from it. A source unavailable for a historical date is a verdict, not an exclusion.

**Interval:** a 10,000-resample bootstrap clustered by document (seed `claims-audit-v1`) is the one quoted; Clopper–Pearson 95% is shown beside it.

**Secondary, each reported:**
- **The verdict distribution:** overall, by class, by source (A or B) and per document.
- **Where the floor came from:** Mosaic's side, the claim's side, or both. A headline driven by Mosaic's own floors says something different from one driven by the documents'. Since D2, a document's own "at least" is a lower bound, not a floor, and documents carry no relays. So every floor is expected to come from Mosaic's side; the split is still reported.
- **The headline without trials claims**, which read floor or unavailable by standing decision.
- **`floor_exceeds_claim`:** how many floor verdicts held more items than the claim allows (§10, D4).
- **Exclusions:** documents yielding no target claim, logged with the reason and counted.

## 7 · Exploratory appendix (labelled so, never the headline)

Whether the headline share differed between programmes that later advanced and those that did not. A programme **advanced** if the deal's lead asset started a later clinical phase or was approved by **2026-10-31**, per ClinicalTrials.gov and company releases. It did **not advance** otherwise, including if it was terminated or returned.

Outcomes are looked up only after the main report is written. The result is reported either way. If there is no difference, the appendix says so.

## 8 · Predictions, stated before any document is opened

| # | prediction (§10, D5) |
|---|---|
| P1 | the headline share is **at least 50%** |
| P2 | `contradicted` is **under 15%** of class A and B claims: documents are rarely wrong on what was checkable, but often unverifiable |
| P3 | `cannot_verify_same_source` is **under 5%** of all claims: releases rarely name their sources |
| P4 | `out_of_scope` is **at least 30%** of all claims (class D is common) |
| P5 | Source B (prospectus competition sections) yields **more** class A and B claims per document than Source A |

A prediction is **met** when the point estimate falls on the predicted side and **not met** otherwise. Each is reported as met or not met. A not-met prediction is not grounds for re-running.

## 9 · Frozen inputs

At registration, the output of `python -m audit.run frozen` is pasted below as a ```json block. The run refuses to go on if any pinned file or constant differs from it. It pins the sha256 (CRLF read as LF) of each of these:
- `mosaic/verify/verdicts.py`, as PR #84 merged it (`7fe48731`), unchanged since;
- `mosaic/audit/extract.py`, with its model id, prompt and schema (`python -m audit.extract --print-frozen`);
- `mosaic/verify/quotes.py`, the matcher that decides what "verbatim" means;
- the run script, `mosaic/audit/run.py`;
- the connectors it calls: `connectors/base.py`, `chembl_release.py`, `ctgov.py`, `pubmed.py` and `epo.py`;
- the query builders those call: `src/ingestion/connectors/epo.py`, `src/db/alias_resolution.py`, `config/axis_queries.yaml` and `scripts/axis_query_registry.py`.

It also pins the constants: the window, the tolerance, the seed, the bootstrap size, the headline verdicts and the ChEMBL release dates.

`SELECTION.md` and `selection.json` are frozen by their own commit, before extraction.

The output of `python -m audit.run frozen` at `main` = `d5518148` (PR #86 merged):

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
    "mosaic/scripts/axis_query_registry.py": "bb55621316eb44f1d543ca62a33d0449319efdf078fd4aa32411675af4b6408e"
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
      "2024-10-01",
      "2024-12-31"
    ],
    "tolerance": {
      "absolute": 0,
      "relative": 0.1
    },
    "seed": "claims-audit-v1",
    "bootstrap_n": 10000,
    "headline_verdicts": [
      "cannot_verify_floor",
      "contradicted"
    ],
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

## 10 · Operator decisions

**Decided 2026-11-04 (operator): every recommendation below.** D2 is "compare as a lower bound", built into `verdicts.py` in PR #84 (`meets_lower_bound`; `blockers.md` B-P3-3). D5's predictions go in as drafted. D8, the extractor's rules, and D9, the run's rules, were approved later the same day, each after its review. D10, amendment 1, was approved on 2026-11-05.

| # | decision | decided |
|---|---|---|
| D1 | the selection rule in §2, with the 60-document cap and a seeded draw | as written |
| D2 | **"At least N" claims.** The engine today reads a claim's own "at least N" as a floor (`cannot_verify_floor`), so "over 400 papers" against a complete 1,764 counts toward the headline. Alternative: compare it as a lower bound (complete M ≥ N → `confirmed`; M < N → `contradicted`; a floor on Mosaic's side stays a floor). That is a change to `verdicts.py` before PR #84 merges. | **compare as a lower bound** (built, PR #84) |
| D3 | tolerance: relative 10%, zero compared exactly | as written |
| D4 | report `floor_exceeds_claim` as a labelled secondary sub-row (never moves a verdict) | yes |
| D5 | the predictions in §8 | as written |
| D6 | the scope rule in §4: an unscoped count is not compared (unavailable) | as written |
| D7 | where to publish the timestamp: `sourabhnk/mosaic-reproducibility`, as in Phase 1 | as written |
| D8 | the extractor's four rules (`blockers.md` B-P3-4): a hedged or qualified lack of therapy is class E; a claim's limits travel in its unit; a compounds claim states its stage; a modality-scoped A or B claim is out of scope and out of the headline | **approved as written, 2026-11-04** |
| D9 | the run's nine rules (`blockers.md` B-P3-5): ChEMBL release dates and identity; trials never confirm or contradict; ChEMBL zeros confirm only at approved; clinical = max_phase ≥ 0.5; papers and patents carry their own limits; no dated assignee count; one target per comparison; the review pinned and locked; the order of work enforced | **approved as written, 2026-11-04** |
| D10 | **Amendment 1.** Source A is listed by each site's own subject and industry filters, read back to the window, because the registered query cannot run on either site (§2). Added with it: the recorded screening, reviewed by the operator, and Source B's mechanics, with SEC requests identified as `Mosaic claims audit support@getmosaic.dev` | **approved, 2026-11-05** |

## 11 · What would make this result wrong, stated in advance

- **Extraction is model-assisted.** Spans are verbatim, and review is blind to verdicts, but which sentences count as claims is a judgement. The review files and each run's `review_log.json` make every change visible.
- **Scope matching** decides whether a count is comparable at all. Many claims will be unavailable for that reason alone, and the report shows how many.
- **Mosaic's own floors** (trials, permanently) push claims into `cannot_verify_floor` whatever the document said. Papers and patents read unavailable, because their scopes rarely match a claim's. The floor-origin split and the headline without trials claims (§6) are there so a reader can see that.
- **Reconstruction is partial:** see §3's right-hand column.
- **Few comparisons can confirm.** A trials zero, and a ChEMBL zero below the approved stage, read unavailable (§3, §4). Papers and patents rarely match a claim's scope. Most comparable claims are on compounds. A `confirmed` on approved molecules rests on ChEMBL's curation of approved drugs.
- **The timestamp's URL is recorded, not fetched by the run.** `PUBLIC_TIMESTAMP.md` is committed, and the run checks it against the registration commit. That the URL serves the same bytes is checked by hand.
- **Source A depends on the issuers' own tags** (amendment 1). A deal tagged only "Company Announcement" on GlobeNewswire, or not tagged Oncology on Business Wire, is not found. GlobeNewswire has no oncology industry, so its cancer criterion is screened from the text. The selection describes deals their issuers filed under these subjects, not every oncology deal of the quarter.
- **One quarter, one field, two sources.** The result describes Q4 2024 oncology deals above $100M and IPO prospectuses, not biotech claims in general.
