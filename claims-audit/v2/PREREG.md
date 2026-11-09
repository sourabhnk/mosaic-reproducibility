# Claims audit, v2: scope imputation. Pre-registration

**Status: pre-registered, not run.** Nothing in this directory has been run. There is no runner: v2 is written down, not implemented.

**Amendment 1 (operator, 2026-11-07, before any v2 run; `docs/audits/blockers.md` B-P3-11).** Nothing below has been run, so it is amended rather than re-registered. Each change and its reason:
1. **Prospectus competition sections only.** v1's 8 deal releases yielded no competitive claim, so v2's sample drops Source A, as v1.1 does.
2. **The confirmatory window moves to Q4 2025 (2025-10-01 to 2025-12-31).** Q1 to Q3 2025 is now v1.1's sample (`eval/claims-audit/v1.1/PREREG.md`). Those quarters will have been read before v2 runs, so they join the development set. The compounds axis reads ChEMBL 36 throughout the new window (in force from 2025-09-19).
3. **The reasons are verdicts-v1.2's.** `no_count_stated` is now `scope_no_count` (a scope, no number) or `no_scope_no_count` (neither). A claim that only names products is checked by name before imputation (`verify/name_match.py`), so v2 imputes only for what is still unscoped after that.
4. **The figures quoted below are v1's as first restated** (11 of 15). They are kept as history, not updated.

**Amendment 2 (operator, 2026-11-09, before any v2 run; `docs/audits/blockers.md` B-P3-12).** One change, and its reason:
5. **The confirmatory window moves to Q1 2026 (2026-01-01 to 2026-03-31).**
   - v1.1's amendment 1 pre-registers a contingency: if its Q1 to Q3 2025 filings yield fewer than 30 competitive claims, v1.1 adds Q4 2025. Q4 2025 may then be read before v2 runs, so it can no longer be v2's confirmatory window.
   - If v1.1 reads Q4 2025, it joins v2's development set. If v1.1 does not read it, Q4 2025 is left unused.
   - The compounds axis reads ChEMBL 36 throughout the new window, with the same extract and names file. ChEMBL 37 was released on 2026-05-29, by EBI's FTP listing as read on 2026-11-09.

**Prerequisite, before any v2 document is opened or any v2 fetch is made:** v1's report is published. "Published" means both of these hold:
1. `docs/audits/claims_audit_2024Q4.md`, with Finding 1 at the top, is on `main`;
2. the operator has recorded its public URL and the date it went public in `eval/claims-audit/v2/V1_PUBLISHED.md`.

That file does not exist at registration. A v2 runner must refuse to start without it.

**Why v2 exists.** v1 (`eval/claims-audit/v1/`, run 2026-11-05, restated 2026-11-06, `docs/audits/blockers.md` B-P3-7) found Finding 1: 11 of its 15 competitive claims stated nothing Mosaic could check (73%; 95% 44.9% to 92.2%). All 11 were `no_count_stated`: no number, though 8 stated a scope. v2 asks how many such claims become checkable when Mosaic proposes the narrowest scope (and, where the words give one, the count) that the claim's own words support.

**These rules were written after reading v1's 29 claims.** So v1's sample is v2's **development set**, and is reported only as that. The confirmatory sample is new (§3).

## 1 · Question

Of the competitive claims (PREREG v1 class B) that the seven-state vocabulary restates as `cannot_verify_unscoped`, what share becomes **comparable**, meaning it reaches the registered rule 5 (`confirmed` or `contradicted`), when Mosaic imputes the narrowest scope the claim's words support?

## 2 · What v2 inherits from v1, unchanged

- **Rules:** v1's extraction rules (`audit/extract.py`, `prompts/extract_v1.md`), class definitions, measures, tolerance and time anchor (v1 PREREG §3 to §5).
- **Verdicts:** the registered verdict rules (`verify/verdicts.py`), and the seven-state restatement (`verify/restate.py`, `verdicts-v1.1`).
- **Files:** every file pinned by v1 PREREG §9, at the hashes it pins. A change to any of them is a new registration, not v2.

Imputation runs **after** v1's pipeline has given a row its restated verdict, and only on rows restated `cannot_verify_unscoped`. It never changes a row's author-stated fields.

## 3 · Sample

- **Confirmatory (the headline), as amended:** v1's Source B rule (v1 PREREG §2), unchanged, applied to the window **2026-01-01 to 2026-03-31** (US Eastern). Prospectus competition sections only. The compounds axis reads ChEMBL 36 (`22ef51aa…`) and its names file (`2e53a5f9…`).
  - *As registered:* 2025-01-01 to 2025-03-31, both sources, ChEMBL 35.
  - *Amendment 1:* 2025-10-01 to 2025-12-31, prospectuses only.
  - *Amendment 2:* 2026-01-01 to 2026-03-31.
- **Development (reported, never the headline):** v1's registered rows and, by amendment 1, v1.1's (including Q4 2025, if v1.1 reads it, by amendment 2). Imputation is applied to every claim still unscoped after the name check. Labelled "development set: the rules were written after reading these claims".
- **No document from the confirmatory window has been opened** at registration.

## 4 · The imputation rule (scope)

For each unscoped claim, Mosaic proposes the **narrowest scope that the claim's own span supports**, on four dimensions:

| dimension | read from the span | if the span says nothing |
|---|---|---|
| target | the target v1 resolved for the claim | not imputed. A claim with no single resolved target keeps its verdict (it is `cannot_verify_unavailable`, Mosaic's gap). |
| modality | a word from the fixed list in §4a ("inhibitor", "antibody", "ADC", "degrader", "molecular glue", "vaccine", "cell therapy") | any modality |
| stage | a phrase from the fixed list in §4a ("approved", "marketed", "commercial" → approved; "in clinical development", "clinical-stage", "in clinical trials", "Phase 1/2/3" → clinical) | any stage |
| date window | the document's as-of date, as in v1 (all records up to it) | the as-of date |

Three rules bound it:
1. **The author's scope wins.** A dimension the author stated is never replaced or widened. A `scope_incompatible` claim (the author stated a scope Mosaic's query does not share) is **not imputed**. It is recorded unchanged.
2. **Only what a declared Mosaic query reproduces is compared.** The compounds query (`connectors/chembl_release`) measures target × stage × date window. It has no modality or indication filter. An imputed or stated modality narrower than "any", or any indication, line of therapy, mutation selectivity or combination, makes the claim's unit differ from Mosaic's. So it stays `scope_incompatible`, with both scopes shown. v2 declares no new query.
3. **Narrowest, not most convenient.** Where the span supports two readings, the narrower is taken, even when only the wider one is comparable.
4. **A stated stage is a stage, not a limit.** v1 appends every stated limit to the unit (D8). So a limit that is exactly a stage phrase from §4a ("in clinical development") would make a clinical-stage count incompatible with Mosaic's clinical-stage count. Such a limit sets the stage and is not carried as a limit. Every other limit is carried as v1 carries it.

### 4a · The fixed word lists

The lists are exactly those in the table above, matched case-insensitively as whole words in the span. No other words count. The lists are not extended after any confirmatory document is opened.

## 5 · The count reading (for `no_count_stated`)

v1's unscoped claims lacked a number. Scope alone makes none of them comparable, so v2 also pre-registers one count reading:
- **A named list of k distinct molecules** on the claim's target and scope reads as **"at least k"** (a claim-side lower bound, compared by the registered rule 5 against a complete Mosaic count, as in B-P3-3). A molecule is named by an INN, a code (e.g. `RLY-2608`) or a brand name, and two names for one molecule count once.
- **Named companies or programmes without molecules** give no number. A company is not a molecule.
- **Vague quantities** ("several", "multiple", "a number of", "an increasing number of") give no number.

## 6 · Labelling, and never merging

- **Every imputed row carries `scope: imputed_by_mosaic`**, and `count: imputed_by_mosaic` where §5 read a count. It also carries the imputed scope and count beside the author-stated ones, which stay as extracted.
- **No count anywhere adds an imputed row to an author-stated one.** The v2 report has two separate tables, author-stated and imputed, and no headline, share or interval is computed over their union. Every report, sidecar and credential field built from imputed rows has "imputed" in its name.
- The checker for this is written with the runner, and it is part of v2's done-when: a test feeds a mixed set and fails if any tally mixes the two.

## 7 · Outcomes

- **Primary:** among the confirmatory sample's competitive claims restated `cannot_verify_unscoped`, the share that becomes comparable under §4 to §5 (reaches rule 5). It is reported with n and a 95% Clopper–Pearson interval, plus a bootstrap interval resampling documents, as in v1.
- **Secondary:**
  - the verdicts of the claims made comparable, `confirmed` and `contradicted`;
  - for the claims that stay uncomparable, why: no count read, an unreproducible scope (`scope_incompatible`), or Mosaic's gap (`unavailable`);
  - the same on the development set, labelled so.

## 8 · Predictions, stated before any confirmatory document is opened

| # | prediction |
|---|---|
| V2-P1 | **fewer than half** (< 50%) of the unscoped competitive claims become comparable |
| V2-P2 | of those that stay uncomparable, **fewer than half** stay so because the scope they state cannot be reproduced by a declared Mosaic query (`scope_incompatible`); the rest lack a countable number |

**The development-set estimate behind them.** It was made by hand from v1's spans while writing §4 and §5, so it is not a run. Of v1's 11 `no_count_stated` claims, about 2 would become comparable:
- venetoclax on BCL2: at least 1, at any stage (the span says "marketing", which is not in §4a's list);
- the three approved FLT3 drugs: at least 3 approved.

The other 9 split:
- **5 have no countable number:** companies, or vague quantities;
- **4 name molecules but state a scope Mosaic cannot reproduce.** All 4 say "inhibitor", a modality the compounds query cannot filter on, and 3 also state an indication or a mutation selectivity.

So about 2 of 11 (18%) become comparable. Of the 9 that stay uncomparable, 4 (44%) do so for scope, which is fewer than half. **On that estimate both predictions hold, V2-P2 narrowly.** The confirmatory sample could differ in either direction. Press releases may state modality and indication more often than these prospectus sections did, which would push V2-P2 the other way. A prediction is met when the point estimate falls on its side. Not met is reported in those words and is not grounds for re-running.

## 9 · Stopping rule

- **One confirmatory run.** After the first confirmatory document is opened, nothing in §3 to §6 changes: no rule, word list or reading. A change is a v3 with its own pre-registration.
- **Fetch failures** are retried once, then stand as `cannot_verify_unavailable`, as in v1. They are never dropped from the denominator.
- **Small samples.** If the confirmatory sample yields fewer than 10 unscoped competitive claims, v2 stops there. It is reported as underpowered, with its n. No second window is added to reach a number.
- **Merging voids the run.** If any imputed row is found counted with an author-stated one (§6), that run is void and is reported as void. The fault is fixed and a fresh run made, with the void run disclosed.
- **No re-running to a result.** A not-met prediction, or an unwelcome share, does not justify a re-run.

## 10 · Registration

- This file is registered by its commit. Before any v2 run, the operator publishes it in `sourabhnk/mosaic-reproducibility` as `claims-audit/v2/PREREG.md`, stamps it with OpenTimestamps, and records the sha256, commit and URL in `eval/claims-audit/v2/PUBLIC_TIMESTAMP.md`, as for v1.
- **Two gates, both checked by the runner before it opens a document:**
  - `V1_PUBLISHED.md`, the prerequisite at the top;
  - `PUBLIC_TIMESTAMP.md`.

## 11 · What would make this result wrong, stated in advance

- **The word lists are a judgement.** A claim's scope could be read more narrowly by a person than by §4a's lists. Mosaic would then compare a claim at a wider scope than its author meant. Rule 3 of §4 limits it, and every imputed row shows both scopes, so a reader can check.
- **"At least k" from a named list is a floor the author did not state.** A claim can name examples ("including") without meaning that only those exist. So a `contradicted` against an imputed floor is weak evidence: it can only mean Mosaic found fewer than the named molecules. That is a Mosaic coverage gap far more often than a document error. The report says so on every such row.
- **The development set shaped the rules.** That is why the headline comes only from the confirmatory window.
