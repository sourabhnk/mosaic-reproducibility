# Judge fabrication, v2 — pre-registration

> **Registration.** This file is the pre-registration. The commit that adds it is the registration, and it comes before any v2 run. After publication, `PUBLIC_TIMESTAMP.md` records three things: that commit, this file's sha256 (CRLF read as LF) and the public URL where it was published. `run_v2.py --execute` refuses to run unless all three agree with this file. Any edit to this file after that commit is a new pre-registration with a new hash, not a correction to this one.

## 1 · Question

v1 found 86 of 210 judge quotes (41.0%) were not verbatim in either document under a whitespace-and-case rule (`../v1/PROTOCOL.md`). Two readings fit that result:

- **R1, invention.** The judge wrote text that is in neither document.
- **R2, formatting.** The judge copied real text but dropped markup (bold, table pipes) or changed typography. v1's rule cannot see the difference. Only 4 of v1's 124 kept quotes contain any markdown character, which makes R2 plausible.

v2 measures how much of the 41% is each, and whether the rate holds for another judge model, another prompt, and another document type.

## 2 · Outcomes, defined before any run

The unit is one scored rubric parameter: one quote from one judge reply. Each quote goes through `mosaic/verify/quotes.py` (matcher version `quotes-2`). The matcher tries its tiers in order against the documents as a reader sees them, with HTML comments blanked, and the first tier that hits wins:

| tier | rule |
|---|---|
| `exact` | v1's rule: whitespace collapsed, case folded, substring |
| `exact_markup` | the same after removing markdown markup (asterisks, backticks, table pipes, and heading/list/quote markers at line start; not underscores, which join identifiers) and unifying typography (curly quotes, en/em dashes, NBSP, zero-width characters, NFKC) on both sides |
| `stitched` | the quote contains an ellipsis, and every fragment between ellipses (at least 3 words each) is found in order in one document |
| `near` | at least **90** on the `exact_markup` normal form, scored within one record of one document: `rapidfuzz.fuzz.partial_ratio_alignment` when the record is at least as long as the quote, `fuzz.ratio` (whole to whole) when it is shorter; quotes of at least 20 characters (rapidfuzz 3.14.3) |
| `not_found` | none of the above |

**Primary outcome — fabrication rate:** the share of scored parameters whose quote is `not_found`.
**Secondary outcomes**, each reported for every arm:

- **v1-comparable rate:** the share whose quote fails the v1 rule on the raw documents (`v1_rule_kept = false`). For the anchor arm this is the replication of 86/210.
- **Tier shares:** the count and share for each of the five tiers.
- **Misattribution:** a quote that backs winner A or B but is found only in the other document. v1 kept these without noting it.
- **Unscored:** replies that omit a parameter, give a winner other than A/B/TIE, give no quote, or (arm b) answer `NONE`. Each is counted and reported, never folded into either rate.
- **Short quotes:** quotes under 15 normalised characters, flagged. The fabrication rate and the v1-comparable rate are also reported with them excluded.
- **Judge errors:** replies that fail to parse after 3 attempts. Recorded and reported, never dropped.

**Intervals:** Clopper–Pearson 95% for every rate. For the primary outcome, also a 10,000-resample bootstrap clustered by pair (seed `judge-fabrication-v2`). The pair-clustered interval is the one quoted.
**Sensitivity analysis:** the fabrication rate with the `near` threshold set to 80, 85, 90 and 95. **The 90 above is the threshold that counts;** the other three are shown alongside it, not chosen after the fact.

## 3 · Design shared by every arm

- **Pairs.** The 7 targets judged in v1: BRD4, EGFR, EZH2, FLT3, KRAS, PDCD1, RET.
- **Mosaic documents.** v1's dossiers, byte-identical (`../v1/data/documents/mosaic/`), shown to the judge exactly as v1 showed them.
- **Baseline documents.** Generated **once**, before any judging, with v1's baseline prompt, model and settings (`claude-sonnet-4-5`, temperature 1.0, max_tokens 4000). They are stored and hashed, and every arm with `documents = anchor` reads the same baselines.
- **Orientation.** Both orientations, 3 runs each: 7 × 2 × 3 = **42 calls and 210 scored parameters per arm**.
- **Stored per call:** the request (model, parameters, prompt and document hashes), the raw reply, the served model id, the request id, usage, every quote in full, and the matcher's row for it.

## 4 · Arms — each changes exactly one thing from the anchor

| arm | what changes | settings |
|---|---|---|
| **anchor** | nothing: v1 exactly, now with everything stored | `claude-sonnet-4-5`, temperature 1.0, max_tokens 1500, v1 system prompt |
| **(a) a_model** | the judge model | `claude-sonnet-5-5` with its own defaults (no temperature sent, adaptive thinking, effort at its default), max_tokens 16000, v1 prompt |
| **(a′) a2_vendor** | the judge vendor | OpenAI `gpt-5.5-2026-04-23` (a pinned dated snapshot), its own defaults (no temperature sent), max_completion_tokens 16000, v1 prompt as the system message. Runs after the anchor and reads the anchor's baselines |
| **(b) b_prompt** | the quote instruction only | anchor settings; system prompt `prompts/b_system.txt`: quotes of at most 40 words, markup kept, `NONE` allowed |
| **(c) c_doctype** | the documents | anchor settings, v1 prompt; two public 2026 press releases per target for five targets (below): 5 × 2 × 3 = 30 calls, **150 scored parameters** |

**(c), fixed 2026-10-31.** The rule (operator, 2026-10-31): two 2026 company press releases per target, from different companies, each about a drug that acts on the target. It could be met for five of the seven targets, EGFR, KRAS, PDCD1, RET and FLT3. BRD4 and EZH2 are not in this arm. The operator chose to run on those five.

- The ten releases are stored as plain text in `documents/press/`. Each is pinned in `documents/press/MANIFEST.json` with its URL, retrieval date and sha256.
- `fetch_documents.py` extracted only the release body.
- GlobeNewswire answered a scripted fetch with 403, so three of the releases were taken from a copy of the same release: Roche's own newsroom (KRAS A) and BioSpace's press-release mirror (EGFR A, FLT3 A). Each record keeps the original URL.
- The arm judges each pair in both orientations, like every arm.
- All five targets are anchor targets, but the documents differ in type, length and authorship, so (c) is compared with the anchor as an arm-level rate, not pair by pair.

## 5 · Predictions, stated before any run

| arm | prediction |
|---|---|
| anchor | v1-comparable rate inside v1's pair-clustered interval, **25.2–59.5%**. Fabrication rate **below** the v1-comparable rate, i.e. some of v1's discards were formatting (R2) |
| (a) | fabrication rate **lower** than the anchor's and **above zero** |
| (a′) | fabrication rate **above zero**; direction relative to the anchor not predicted (no prior on this vendor) |
| (b) | v1-comparable rate **lower** than the anchor's. Fabrication rate lower or unchanged. If it collapses to near zero, v1's rate was mostly a prompt artefact |
| (c) | gap between the v1-comparable and fabrication rates **near zero**, because plain prose has no markup to strip. Fabrication rate **lower** than the anchor's. If it is not lower, invention does not depend on document format |

A prediction is **met** when the point estimate falls on the predicted side and **not met** otherwise. Every prediction is reported as met or not met. A not-met prediction is not grounds for re-running.

## 6 · Stopping rule and exclusions

Fixed n: 42 calls per arm, no interim looks, no early stopping, no extra runs. Nothing is excluded. Judge errors and unscored replies are reported in their own rows (§2). An arm that cannot complete, for example because the model is unavailable, is reported as incomplete with whatever it collected. It is not quietly re-run with a different model.

## 7 · What would make this result wrong, stated in advance

- **One vendor.** The anchor and arms (a), (b) and (c) judge with Claude models, as in v1; (a′) is the only non-Anthropic judge, and every document it reads was written by Claude or by Mosaic's Claude-based synthesis.
- **Blinding.** The Mosaic documents carry an HTML comment naming the model, and their body names Mosaic. Both are kept identical to v1 so the anchor stays comparable. The leak is reported, not fixed silently.
- **Few pairs.** With 7 pairs, the pair-clustered interval is wide. It is reported as wide.
- **The threshold.** The matcher's `near` threshold is fixed at 90 here, before any data, and the sensitivity table shows what changes with it.
- **Temperature 1.0** (anchor, b, c). Every run is a sample, and a re-run gives a new one.

## 8 · Frozen inputs

At commit, paste the output of `python -I eval/judge-fabrication/v2/run_v2.py --print-frozen` here. Gate 2 checks it.

```json frozen-inputs
{
  "eval/judge-fabrication/common.py": "535a37ede929653046bcdbb47720c4be59613155cda8d1810d43a8f6cd868517",
  "eval/judge-fabrication/stats.py": "7885b4447da5a5765c80acc3e94f3a3b1f6e0051fde2e399fd7f8dac1e6eca62",
  "eval/judge-fabrication/v1/data/documents/mosaic/BRD4.md": "fb8b20cfb3e2edd7c8198423f838b4c237d4fead695abba0838f8d83d864b413",
  "eval/judge-fabrication/v1/data/documents/mosaic/EGFR.md": "51919d05079a52fa6f1a1a5fbccd23f014655ab5ae6c6ed23b5971145c9c66ad",
  "eval/judge-fabrication/v1/data/documents/mosaic/EZH2.md": "f9b311631297a5b50bf01295a0c298b7e6dc110241e36067cabd016cb4d6f0e8",
  "eval/judge-fabrication/v1/data/documents/mosaic/FLT3.md": "ff35b72656ee46d74e2810806ff9622bfe514d18dcba5801b674293817457db2",
  "eval/judge-fabrication/v1/data/documents/mosaic/KRAS.md": "0d099b46503c425c672a5e25b80671a31ecf5f72838141d056d61d1a20d4ce33",
  "eval/judge-fabrication/v1/data/documents/mosaic/PDCD1.md": "ead608080b87b5a95b06f51e6e2e7085ba232a739c8e2c4a065ed9b98759d4b7",
  "eval/judge-fabrication/v1/data/documents/mosaic/RET.md": "19495306778fe85fca71c3f8bf3274193fc30f94d0e71db09666f8d4a81fbee6",
  "eval/judge-fabrication/v1/harness/PROMPT_SYSTEM.txt": "dfea09e530a77598244ce08cb4e8d37eff23d99b955b81efd5bf079e507e1aca",
  "eval/judge-fabrication/v2/arms.json": "e5dfb3b9f04878997825a3730f836cbc6500cf7d6deb0d17ab5d83e4bec02e24",
  "eval/judge-fabrication/v2/documents/press/EGFR_A.txt": "8d594cf0fa002bf51a670dc193fc5356464bf7b05fd98b98e597a607fbee57b4",
  "eval/judge-fabrication/v2/documents/press/EGFR_B.txt": "eb9a9d7cb7fb556968c0e1c84d602f18e0a55fecb4f8ea277ab200ac9c2d30af",
  "eval/judge-fabrication/v2/documents/press/FLT3_A.txt": "1ce23a70fb122a845278f46f843d3b20a51c52fca12e6e5a0e3d910a8860d5fa",
  "eval/judge-fabrication/v2/documents/press/FLT3_B.txt": "a04ad65179610ee96c4bb03df87629ad9d3e8dcc968aaf2271e2bfdcda91fff1",
  "eval/judge-fabrication/v2/documents/press/KRAS_A.txt": "f178ce7450b4c2a2dbe40f7fde451ec965e6730edf3cd46fb241a95b394c6f30",
  "eval/judge-fabrication/v2/documents/press/KRAS_B.txt": "e006025bb16fb5514d5250636e6bcdd0df35b8de8d8a18f49f46c06149829758",
  "eval/judge-fabrication/v2/documents/press/MANIFEST.json": "200a612aad6db3a1baff478fa52fe524d258344092555ed8ca7144dbfd9ef68f",
  "eval/judge-fabrication/v2/documents/press/PDCD1_A.txt": "369b90cb770df4aa04ab1f87f7f082f98e7782a89cad24e48174cdc5002b1cb4",
  "eval/judge-fabrication/v2/documents/press/PDCD1_B.txt": "eeec86a7ed34d2ef650780cdefc67da93eba404569d947253f88dfc3bfe732a2",
  "eval/judge-fabrication/v2/documents/press/RET_A.txt": "a91ef138e1e9e6ee7c1cb804341d5bf825169e74c7863b8b786cfcfe2258b44d",
  "eval/judge-fabrication/v2/documents/press/RET_B.txt": "f551fefb0095d7194ccd24044e30b3bbc3f017783851b4105d4ec9cd4e87b425",
  "eval/judge-fabrication/v2/fetch_documents.py": "fff3f43636c0e5b9f06e6722814c4816888c4b248f5128838df4e737cf2c6fc5",
  "eval/judge-fabrication/v2/prompts/b_system.txt": "33ce163d9ca5ff1c2709280ee00fbfbfe51b1a442db6dd60e52f62e0bf30e38c",
  "eval/judge-fabrication/v2/prompts/baseline_user.txt": "d30c6aa7def1c9314464112e596d8a6aa83ec5f50c1a72665cb9e0fcf319cca7",
  "eval/judge-fabrication/v2/run_v2.py": "8b888f85df3b55e6b8e5abc948b7cd593fbc4e50f22f784dc4583d8276febae7",
  "mosaic/verify/quotes.py": "756f20fb8afe37c1f9a1e5dab73427f030099807c33c535ea9cfe582276847d8"
}
```

## 9 · Operator decisions

Decided 2026-10-31 (operator: "go with recommendations"):

1. **A non-Anthropic judge:** yes, arm (a′). The OpenAI SDK is pinned in `eval/judge-fabrication/requirements.txt`, not in the product.
2. **Where to publish:** `sourabhnk/mosaic-reproducibility`, as a commit with an OpenTimestamps proof of the sha256. The operator publishes. Decide first whether arm (c)'s press-release texts go in the public repository or only their URLs and hashes.
3. **Budget:** the four Claude arms come to about $8.50 (offline estimate). (a′) is at most $9.70; that bound uses a price chosen above any plausible list price. Check both against the pricing pages before setting `--max-usd`.

4. **Arm (c)'s documents:** the five targets where the rule holds (§4), fixed and stored.
5. **Budget, updated:** the four Claude arms now total about $7.70 (arm c is smaller: 150 judgments, about $1.14), plus at most $9.70 for (a′).
