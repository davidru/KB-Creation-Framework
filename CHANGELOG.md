# Changelog — KB Creation - Modular v3

All notable changes to the KB Creation Framework — Modular are documented here. The framework follows a versioning convention loosely modeled on Semantic Versioning: MAJOR for invariant-breaking changes, MINOR for new phases/tools/invariants, PATCH for clarifications, bug fixes, and rulebook tightening.

This CHANGELOG is append-only. Older entries are never edited; corrections appear as later entries that supersede earlier ones.

---

## [3.1.16] — 2026-06-08 (patch — audit + cleanup)

### Fixed

- **Quality Scorecard weights summed to 1.05 instead of 1.00** (silent bug present since v3.1.14). Root cause: `audit-templates/kb-quality-dimensions.yaml` still had v3.0/v3.12-era 7-dimension weights with key names spelled `..._and_...` (e.g., `citation_density_and_primary_source_rate`), but `Generate-QualityScorecard.ps1` `Get-Weights` slug generation drops `&` entirely (produces `citation_density_primary_source_rate`). Result: only `stress_test_pass_rate` (whose slug happened to match exactly) loaded from YAML — incrementing default 0.20 → 0.25 and breaking the sum. Other YAML entries silently failed to override defaults. v3.1.14 + v3.1.15 added 2 new dimensions but never updated the YAML. Fix: rewrote `audit-templates/kb-quality-dimensions.yaml` to (a) use the slug convention the script produces (`&` dropped), (b) declare all 9 v3.1.15 dimensions in default_weights summing to 1.00, (c) refresh all 5 `kb_type_weights` profiles (legal_topic, company, litigation, person, technology) to 9 dimensions × correct weights summing to 1.00 each. Verified: weights now sum to 1.0000 exactly.

- **CHANGELOG missing `## [3.1.6]`, `## [3.1.7]`, `## [3.1.3]`, `## [3.1.2]`, `## [3.1.1]` headers.** All 5 patches were shipped (per checkpoints + commit history) but their CHANGELOG entries had lost their version headers — content was present but anchored under prior versions, making the version sequence look like 3.1.5 → 3.1.4 → 3.1.0. Fix: backfilled all 5 headers in place; full v3.1.x sequence is now contiguous (3.1.0, 3.1.1, 3.1.2, 3.1.3, 3.1.4, 3.1.5, 3.1.6, 3.1.7, 3.1.8, 3.1.9, 3.1.10, 3.1.11, 3.1.12, 3.1.13, 3.1.14, 3.1.15, 3.1.16). No content was rewritten — only the section anchors restored.

- **Stale `.opencode/agents/*.md` files deleted from framework root.** 5 hand-crafted agent files (auditor-mistral.md, builder-a-openai.md, builder-b-mistral.md, critic-deepseek.md, factcheck-deepseek.md) were sitting at the framework root, named with registry-handle convention (not the role-based convention v3.1.5's `Render-OpenCodeAgents.ps1` writes). Likely created during pre-v3.1.5 debugging when an operator manually staged OpenCode agents the wrong way (at framework root + handle-based names rather than at KB root + role-based names). With v3.1.5+ they're dead: no orchestrator dispatches to them; if an operator accidentally ran OpenCode at the framework root they would confuse the rendered config. Deleted; `.opencode/` directory also removed (was the only content).

### Audited (no defects found)

- All 44 PowerShell scripts parse OK (including 9 v3.1.13-15 adapter scripts).
- All 13 Python scripts compile OK (including v3.1.13-15 Python sidecars).
- All 5 JSON schemas (model-registry, pipeline-state, phase-contracts, source-registry, test-set) parse OK.
- `Validate-Pipeline.ps1` against current phase-contracts.yaml → VALID (0 ERROR, 0 WARN).
- `Validate-PipelineState.ps1` against pipeline-state.example.yaml → VALID.
- All 23 prompts referenced by `phase-contracts.yaml` exist; only `prompts/00-README.md` (operator overview) and `prompts/01-orchestrator.md` (meta-coordinator) are intentionally not phase-listed.
- End-to-end Generate-QualityScorecard test with all 9 dimensions populated produces correct verdict and composite math (after BUG 1 fix).

### Notes

- **What this audit did NOT find** (already documented elsewhere): the Rule 19 phase-numbering inconsistency between `01-shared-axioms.md` Rule 19 wording (`5.4 ≠ 5.2`) and `phase-contracts.yaml` (uses `5.x ≠ 1.3` correctly) is logged in `framework_proposals` as `v3.1.13-followup`. Not fixed in v3.1.16 because it requires a content rewrite of Rule 19 wording + Quality Scorecard pair list; both legitimate and not silently wrong (just two parallel representations of the same intent — scorecard uses one, axioms uses the other).
- **What this audit did NOT cover**: LLM-mode end-to-end testing of v3.1.14 LlamaIndex CitationQueryEngine + v3.1.15 Inspect framework. These were smoke-tested in fallback mode only. LLM-mode coverage requires pip-install + API spend; deferred to follow-up session.
- **Audit invocation**: triggered by operator request 2026-06-08 "audit the system for any errors" after all v3.1.13/14/15 shipped.

---

## [3.1.15] — 2026-06-08 (patch)

### Added

- **Inspect test-set evaluator (Phase 7.0 enhancement).** Operator curates `audit/test-set.yaml` per KB with 10-20 ground-truth questions covering the highest-stakes operator-facing decisions the KB supports. Phase 7.0 dispatches `adapters/evaluator/inspect-runner.ps1` against the assembled `full/` files; results feed a new Quality Scorecard dimension "Test-set passage rate" with operator-configurable threshold (default 80%). PASS gating: composite verdict forced to FAIL when test-set is present and (a) passage rate below threshold OR (b) any blocker-severity question fails.

- **`adapters/evaluator/inspect-runner.py`** (22KB) — dual-mode adapter:
  - **LLM mode** (when `inspect-ai` is installed + API key set): uses Inspect's Task/solver/scorer pattern; supports the `model_graded` scorer for fuzzy questions
  - **Fallback mode** (no pip-install, no API key): six deterministic scorers run directly against `full/*.md` content. `model_graded` questions logged as N/A in fallback mode (excluded from passage-rate denominator).
  
  Six built-in scorers: `exact_match` | `contains` | `contains_all` | `contains_any` | `cite_match` (normalized whitespace+punctuation comparison) | `numeric_tolerance` (extract numbers from KB, compare with tolerance).

- **`adapters/evaluator/inspect-runner.ps1`** (2.8KB) — PowerShell wrapper.

- **`adapters/evaluator/requirements.txt`** — pinned `inspect-ai` version; only needed for LLM mode.

- **`audit-templates/test-set.schema.json`** — JSON Schema 2020-12 for `audit/test-set.yaml`. Required: version, questions (each with id, text, scorer). Optional: threshold (passage_rate + per_question_severity), solver config (for LLM mode).

- **`examples/test-set.example.yaml`** (3.3KB) — 7-question golden reference covering all 7 scorer types + severity levels (blocker / high / medium / low).

### Changed

- **`Generate-QualityScorecard.ps1`**: new dimension "Test-set passage rate" with weight 0.10. Score = `passage_rate × 100`; threshold = `threshold.passage_rate × 100` (from test-set.yaml). When test-set absent (`data.mode: absent`), dimension scores 0 with FAIL verdict — operator should curate a test-set to improve composite. Weights re-balanced (Citation density 0.15→0.10, Register-tag 0.10→0.05) to sum to 1.00. New PASS-gating section: when test-set is present and either `threshold_met=false` or `blocker_failed=true`, composite verdict forced to FAIL with `test_set_gate_note` recording the reason. Framework version bumped to `v3.1.15`.

- **`audit-templates/phase-contracts.yaml`**: Phase 7.0 consumes `audit/test-set.yaml`; Phase 7.0 produces `audit/test-set-results.md` + `audit/test-set-results.json`. `audit/test-set.yaml` added to `external_inputs` (operator-curated, not produced by any phase).

### Verified

- 8-question test set against synthetic 2-topic KB:
  - `cite_match` (17 CFR 240.10b-5) → PASS
  - `contains_all` (5 keywords: device, scheme, artifice, defraud, material fact) → PASS
  - `contains` (Dodd-Frank Wall Street Reform and Consumer Protection Act) → PASS
  - `numeric_tolerance` (15 days serious incident reporting, tolerance 0) → PASS
  - `contains_any` (Washington | WA) → PASS
  - `model_graded` → NA (fallback mode skips model_graded)
  - `exact_match` (60 days) → PASS
  - `numeric_tolerance` (30% whistleblower bounty) → FAIL (KB doesn't contain this)
  - **Passage rate: 6/7 scored = 85.7% > 80% threshold → exit 0, threshold MET**
- Scorecard PASS gating cases:
  - Case 1 (passage 0.85, threshold 0.80, MET) → test-set dim score=85 PASS; composite unaffected
  - Case 2 (passage 0.60, threshold 0.80, NOT MET) → composite forced to FAIL via gate
  - Case 3 (passage 0.90 but blocker_failed=true) → composite forced to FAIL via blocker gate
  - Case 4 (test-set.yaml absent) → dimension scores 0 with `data.mode: absent`; no gating; back-compat preserved
- `Validate-Pipeline.ps1` VALID after Phase 7.0 + external_inputs updates (0 ERROR, 0 WARN)
- All 13 framework PS1 scripts continue to parse OK

### Notes

- **Why dual-mode**: Inspect (UK AISI's eval framework) is purpose-built for LLM evaluation pipelines — the LLM mode integrates with their Task/solver/scorer abstractions. But operators who don't want to install `inspect-ai` or set up an evaluator-LLM API key still get value from the 6 deterministic scorers; they cover most ground-truth-question types (cite verification, numeric claim verification, presence/absence of key facts). Only `model_graded` truly needs the LLM mode.

- **Cross-family discipline (Rule 19)**: when `model_graded` questions are evaluated in LLM mode, the test-set.yaml `solver.llm.family` MUST differ from Builder A + Builder B + Phase 6.4 fact-checker families. The runner DOESN'T currently enforce this at startup (trust-the-orchestrator pattern, same as v3.1.14); orchestrator validates against `pipeline_state.yaml` before invoking. A follow-up patch could add startup validation.

- **PASS gating is the key feature**: without it, a KB could have a beautiful citation density + qualifier preservation profile but fail to answer half the operator's actual decision questions and still PASS the composite. With it, the test-set is the operator's "this KB MUST get these right" contract. The threshold is operator-configurable per-KB.

- **What v3.1.15 does NOT include**: (a) automatic test-set generation from KB content (operator must curate manually — this is intentional, since the value comes from the operator deciding what matters); (b) per-question scoring confidence (binary PASS/FAIL/NA only — could add nuanced scoring in v3.1.16+); (c) test-set version control hooks; (d) test-set drift detection (KB changes → some questions may need rewording — manual review).

---

## [3.1.14] — 2026-06-08 (patch)

### Added

- **Phase 5.6 — Citation-Engine Fact-Check** (new phase between 5.5 and 6.0). Verifies every cite-string in builder drafts against the primary-source corpus retrieved by v3.1.13 adapters (or operator-staged into `external/primary-sources/cache/`). Dual-mode adapter:

  - **LLM mode** (when `llama-index` + `chromadb` are installed and an API key is set): builds a ChromaDB-backed VectorStoreIndex of primary sources, queries each (cite, claim) pair via LlamaIndex's CitationQueryEngine, classifies based on retrieved source spans + LLM judgment. Verdicts: `VERIFIED` | `WRONG_TEXT` | `NOT_FOUND` | `SUPPORTED_BUT_WRONG_CITE` | `ERRORED`.

  - **Fallback mode** (no pip-install, no API key, no per-call cost): deterministic text-search across all indexed primary-source content + manifest citation metadata. Verdicts: `VERIFIED_BY_PRESENCE` | `NOT_FOUND`. Catches obvious citation hallucinations (cite-string nowhere in indexed sources) but does NOT verify claim-text support.

  Mode auto-detected unless explicitly forced. Same graceful-degradation pattern as v3.1.13 adapters.

- **`adapters/citation-engine/llamaindex-citation.py`** (20KB) — Python adapter. Pure-stdlib for fallback mode; imports llama-index/chromadb dynamically for LLM mode.

- **`adapters/citation-engine/llamaindex-citation.ps1`** (3.4KB) — PowerShell wrapper.

- **`adapters/citation-engine/requirements.txt`** — pinned LlamaIndex + ChromaDB versions; only needed for LLM mode.

- **`prompts/56-factcheck-citation-engine.md`** (5.1KB) — Phase 5.6 orchestrator prompt with mandatory dispatch instructions, output handling, stop conditions (`NOT_FOUND > 10%`, `WRONG_TEXT > 0`, `ERRORED > 5%`).

### Changed

- **`audit-templates/phase-contracts.yaml`**: new Phase 5.6 entry with `rule_19_pair: ['5.6','1.3']` (verifier vs builder draft); Phase 6.0 (Lead Assembly) consumes `sources/factcheck_citation_engine.md`.

- **`Generate-QualityScorecard.ps1`**: new dimension "Citation-engine verification rate" with weight 0.10. Score = `(VERIFIED + 0.7 × VERIFIED_BY_PRESENCE) / (total - ERRORED) × 100`; fallback verifications count at 70% since they don't verify claim-text support. Other weights rebalanced (Citation density 0.20→0.15, Stress-test 0.25→0.20) to sum to 1.00. When `sources/factcheck_citation_engine.json` is absent (KB built before v3.1.14 or Phase 5.6 skipped), dimension scores 0 with `data.mode: absent` and FAIL verdict.

### Verified

- 5-cite smoke test with 3-document primary-source corpus (eCFR XML + Federal Register JSON + Congress public-law JSON) in fallback mode:
  - `17 CFR 240.10b-5` → VERIFIED_BY_PRESENCE (matched eCFR XML via citation metadata)
  - `Pub. L. 111-203` → VERIFIED_BY_PRESENCE (matched congress JSON)
  - `85 FR 38031` → VERIFIED_BY_PRESENCE (matched FR JSON)
  - `42 CFR 999.99-9` → NOT_FOUND (hallucinated cite)
  - `15 USC 78j(b)` → NOT_FOUND (not in test corpus)
  5/5 correct verdicts.
- Scorecard test with mock counts `{VERIFIED: 3, VERIFIED_BY_PRESENCE: 4, NOT_FOUND: 2, ERRORED: 1, total: 10}` produces dimension score 64/100 = (3 + 0.7×4) / (10-1) × 100, FAIL verdict (threshold 80). Matches expected formula.
- Absent-`factcheck_citation_engine.json` regression: scorecard reports dimension score 0 with `data.mode: absent`, doesn't crash. Back-compatible.
- `Validate-Pipeline.ps1` re-validates VALID after Phase 5.6 added (0 ERROR, 0 WARN).
- All 11 framework PS1 scripts continue to parse OK; `Validate-PipelineState.ps1 examples/pipeline-state.example.yaml` continues to validate VALID.

### Notes

- **Bug fixes during development**: (a) initial fallback-mode search only inspected primary-source content, not manifest citation metadata — eCFR XML doesn't include the "NN CFR" prefix in body text, only in the wrapped manifest's `citation` field. Fixed by searching both. (b) Initial draft scanner walked the full `sources/` tree recursively, picking up prior `factcheck_citation_engine.md` as input and double-counting cites. Fixed by excluding files starting with `factcheck_` or in a `factcheck`-named subdirectory.

- **Why dual-mode**: the LLM mode is the gold-standard verification (catches WRONG_TEXT, SUPPORTED_BUT_WRONG_CITE) but requires `pip install llama-index chromadb` and an embedding-model API key. Operator may want fallback mode for: (a) air-gapped builds; (b) avoiding API cost on large draft corpora; (c) first-pass screening before LLM verification; (d) builds where no API key is configured. Fallback alone is sufficient to catch most "the model hallucinated a CFR section that doesn't exist" failures.

- **Rule 19 discipline**: Phase 5.6 declares `rule_19_pair: ['5.6','1.3']`. The LLM that runs the CitationQueryEngine MUST be from a family different from Builder A and Builder B. The adapter doesn't enforce this directly (it trusts the orchestrator's model assignment per Rule 20); the orchestrator must validate against `pipeline_state.yaml` before invoking. In fallback mode, no LLM runs at all, so Rule 19 doesn't apply — but the verification is correspondingly weaker (no semantic claim-text check).

- **What v3.1.14 does NOT include**: (a) on-demand LlamaIndex installation (operator must `pip install -r adapters/citation-engine/requirements.txt` themselves); (b) test against an LLM-mode end-to-end (the smoke test ran fallback-mode only; LLM-mode requires API key + ~30 sec per query at ~$0.001 per cite); (c) integration with Generate-QualityScorecard for the new Phase 5.6 actuals in Rule 19 evaluator (the scorecard's Rule 19 logic already handles arbitrary phase_ids in pipeline_state, so this works automatically once the orchestrator logs Phase 5.6 dispatches).

---

## [3.1.13] — 2026-06-08 (patch)

### Added

- **Primary-source API adapters (4 fetchers + multi-source orchestrator).** Automate fetching and amendment detection for U.S. legal Topic KBs. All adapters use Python sidecar pattern (Python stdlib only, no `pip install`) + PowerShell wrapper; content-addressed cache (SHA256) + diff detection between fetches; graceful degradation (exit 4 on missing Python, exit 5 on missing API key, structured error JSON with `error_type` + `remediation`).

  - **`adapters/primary-source/ecfr/`** — Code of Federal Regulations via `https://www.ecfr.gov/api/versioner/v1/`. No auth. Auto-fallback: if today's date isn't yet indexed (eCFR typically lags 1-3 days), queries titles endpoint and retries with the latest available date. Smoke test: `pwsh fetch.ps1 -CiteString "17 CFR 240.10b-5" -CachePath .\cache` → fetches XML, computes SHA256, writes content + manifest.

  - **`adapters/primary-source/federal-register/`** — Federal Register via `https://www.federalregister.gov/api/v1/`. No auth. Supports FR cite (`85 FR 12345`), document number (`2020-12345`), or docket ID. Smoke test: `pwsh fetch.ps1 -DocumentNumber "2020-12345" -CachePath .\cache` → fetches JSON, extracts citation from response.

  - **`adapters/primary-source/congress/`** — Congress bills + public laws via `https://api.congress.gov/v3/`. Requires `CONGRESS_API_KEY` env var (free 5,000 req/hr at https://api.congress.gov/sign-up/). Supports public law cite (`117-103`) or bill (`117 hr 3076`).

  - **`adapters/primary-source/govinfo/`** — USCODE, PLAW, FR, BILLS, STATUTE, CFR packages via `https://api.govinfo.gov/`. Requires `GOVINFO_API_KEY` env var (free at https://api.govinfo.gov/docs/). Supports direct package ID (`PLAW-117publ103`) or structured args (Congress/law-number for PLAW, year/title for USCODE).

  - **`adapters/primary-source/fetch_all.py` + `.ps1`** — multi-source orchestrator. Reads `sources/source-registry.yaml`, invokes the appropriate adapter for each entry, writes `sources/source_drift_report.md` summarizing diff_status across all sources. Foundational-criticality changes (`changed` diff_status on a source tagged `criticality: foundational`) BLOCK the build with exit code 1 + a `## ⚠️ BLOCKING DRIFT` section at the top of the report.

  - **`audit-templates/source-registry.schema.json`** — JSON Schema 2020-12 for `sources/source-registry.yaml`. Operator-curated per-KB primary-source watchlist with id + adapter + ref + tags + criticality (foundational/supporting/context).

  - **`examples/source-registry.example.yaml`** — golden reference (5 sources across all 4 adapters).

  - **`adapters/primary-source/ADAPTERS-README.md`** — full architecture documentation, operator setup guide, output envelope schema, standalone usage examples, known limitations.

### Changed

- **`audit-templates/phase-contracts.yaml`** — updated for v3.1.13 integration:
  - `external_inputs` adds `external/primary-sources/cache/` and `sources/source-registry.yaml`
  - Phase 1.1 (Builder Research) `consumes` includes both; produces re-emits cache (when `auto_fetch_on_phase_1_1: true` in registry)
  - Phase 6.3 (Extraction) consumes registry + cache; produces `sources/source_drift_report.md` (when `drift_report_on_phase_6_3: true`)
  - Phase 7.0 (Final Audit) consumes the drift report (audit must flag any foundational drift)
- `Validate-Pipeline.ps1` re-runs VALID after these changes (0 ERROR, 0 WARN).

### Verified

- All 4 adapters smoke-tested end-to-end:
  - eCFR: fetched 17 CFR 240.10b-5 (1169 bytes, sha256 ef1ad818...), auto-fallback to as_of=2026-06-04 worked correctly
  - Federal Register: fetched document 2020-12345 (9762 bytes, sha256 d58937cb..., citation "85 FR 38031")
  - Congress: gracefully reported `missing_api_key` with actionable remediation
  - GovInfo: gracefully reported `missing_api_key` with actionable remediation
- `fetch_all.ps1` orchestrator smoke-tested with 2-source registry:
  - First fetch: 2 new, 0 unchanged, 0 changed
  - Second fetch: 0 new, 2 unchanged, 0 changed
  - Tampered prior manifest (simulated drift): 0 new, 1 unchanged, 1 changed (foundational) → exit 1 + drift report's BLOCKING section populated correctly
- Schema validation: `source-registry.example.yaml` Test-Json against `source-registry.schema.json` → VALID
- `Validate-Pipeline.ps1` after phase-contracts updates → VALID (0 errors, 0 warnings)
- `Test-DispatchFingerprint.ps1`, `Generate-QualityScorecard.ps1`, `Render-OpenCodeAgents.ps1`, `Validate-PipelineState.ps1` all parse OK (no regressions).

### Notes

- **Bug fix during development**: initial eCFR adapter loaded `prior_sha` from the cache manifest using the pre-fallback date (e.g., today's date that 404'd), so on re-fetch with auto-fallback, the prior_sha was always None → diff_status always "new". Fixed by computing cache paths + loading prior_sha AFTER the as_of fallback resolves. Verified with re-fetch test: now correctly reports "unchanged" on the second call.
- **eCFR auto-fallback strategy**: when today's date 404s (eCFR lags 1-3 days for new content), the adapter queries `/api/versioner/v1/titles.json` to find each title's `up_to_date_as_of` date and retries. This makes the adapter "just work" without operator-supplied `-AsOf` for common cases. Operator can still override with explicit `-AsOf` for historical research.
- **Drift report blocking semantics**: foundational drift exits 1; supporting/context drift logs but doesn't block. This matches the operator's existing manual workflow of "did the primary source change in a way that affects the KB's claims?" Operator can override criticality per source.
- **No external Python dependencies**: every adapter uses Python stdlib only (urllib.request, json, hashlib, pathlib, re, argparse, subprocess). No `pip install` required. Reduces install friction; downside: no httpx async + no PyYAML (we hand-rolled a minimal YAML parser in `fetch_all.py`).
- **What v3.1.13 does NOT include**: (a) content-only textual diff (just SHA mismatch); (b) full Federal Register XML pull (just the document JSON metadata); (c) GovInfo body content (just summary); (d) EU jurisdictions (CRA, NIS2, AI Act, MDR, etc. need EUR-Lex SPARQL adapter — future patch).

---

## [3.1.12] — 2026-06-08 (patch)

### Added

- **Phase contracts + pipeline DAG validator (`Validate-Pipeline.ps1`).** Modeled on haystack's `pipeline.connect()` type-validation-at-construction pattern. Two new files:
  - `audit-templates/phase-contracts.yaml` — declares consumes/produces for all 22 framework phases (0.0 through 8.5) plus an `external_inputs` block. Each phase entry includes `phase_id`, `name`, `prompt`, `consumes` (artifact paths required as input), `produces` (artifact paths written), and optionally `rule_19_role` (assignment/producer/verifier/neutral) + `rule_19_pair: [verifier, producer]` (for Rule 19 cross-family-verification phases) + `iteration: { max_iterations, termination_condition }` (for loop phases like 3.0 Builder Revision and 6.5 Quality Tier Audit).
  - `audit-templates/phase-contracts.schema.json` — JSON Schema 2020-12 for the contracts file.

- **`Validate-Pipeline.ps1`** — new validator (22 KB). Checks:
  - **DAG-missing-producer**: every `consumes` artifact must be produced by an earlier phase (per phase_id ordering) OR listed in `external_inputs`. Catches "Phase 5.4 needs single-source-inventory.md but no earlier phase produces it" gaps mechanically — BEFORE model spend. Validated the v3.1.12 contracts file end-to-end; surfaced 3 real gaps in the initial cut (model-registry.yaml / model-presets.yaml / sources/ glob needed to be added to external_inputs) which were then fixed.
  - **DAG-orphan-production** (WARN): produced artifacts that no later phase consumes (excluding known deliverables: full/, authority/, practice/, audit/, etc.).
  - **Rule 19 pair consistency**: `rule_19_pair: [v, p]` MUST reference existing phase_ids; verifier `v` MUST execute AFTER producer `p` in canonical phase ordering.
  - **Rule 19 actuals cross-check** (when `-PipelineStatePath` is provided): for every `rule_19_pair` with both phases logged in `pipeline_state.yaml`, the verifier's actual_family MUST differ from the producer's actual_family. Catches the silent-fallback Rule 19 violation pre-build, not just post-build (the v3.1.9 scorecard already catches it post-build).
  - **State-unknown-phase** (WARN): if pipeline_state.yaml logs a phase_id not in phase-contracts.yaml, either the orchestrator invented a phase or contracts is missing one — both are Rule 20 integrity flags.

### Verified

- `Validate-Pipeline.ps1` against the v3.1.12 contracts file → exit 0 VALID after initial-cut gaps were fixed.
- `Validate-Pipeline.ps1 -PipelineStatePath examples\pipeline-state.example.yaml` → exit 0 VALID (Rule 19 enforced in example actuals).
- `Validate-Pipeline.ps1 -PipelineStatePath <broken-state>` (Builder A deepseek + Phase 5.1 fact-check substituted to deepseek) → exit 1 with `[ERROR] rule-19-actuals: Rule 19 violation in actuals: verifier phase '5.1' (family deepseek) overlaps producer phase '1.3' (family deepseek). Cross-family verification was not achieved.`

### Notes

- The 22-phase contracts file is the v3.1.12 initial cut based on the prompt list under `prompts/` and the canonical Rule 19 pairs in `01-shared-axioms.md`. Edge-case consumes/produces (sub-phases, optional intermediate artifacts, in-place revisions where a phase produces the same artifact it consumes) may need refinement based on real-build observations. Operators who notice an out-of-order or missing-producer false-positive should update `audit-templates/phase-contracts.yaml` in the same change as the prompt update that introduced the dependency.

- **Architectural observation surfaced by this work**: the v3.1.9 scorecard's Rule 19 pair list says "Phase 5.4 ≠ Phase 5.2" because 01-shared-axioms.md Rule 19 uses that wording, but per `phase-contracts.yaml` Phase 5.2 is "Fact-Check — Citation Verification", not the build phase. The actual build phase is 1.3 (Builder Draft). So the canonical Rule 19 pair should be "Phase 5.x fact-checks ≠ Phase 1.3 build". This is a legacy-naming issue in 01-shared-axioms.md that pre-dates v3.1.x; v3.1.12 phase-contracts.yaml uses the correct pairing (fact-check pairs all reference Phase 1.3 as producer except 5.4 which references 5.2 per the shared-axioms wording). A v3.1.13+ patch should reconcile 01-shared-axioms.md Rule 19 wording with the actual phase numbering and update the v3.1.9 scorecard's pair list accordingly.

---

## [3.1.11] — 2026-06-08 (patch)

### Added

- **`sources/pipeline_state.yaml` schema + linter (`Validate-PipelineState.ps1`).** Per the haystack-research note, formalizing the orchestrator's per-phase actuals log as structured YAML closes two of the four WA-Law-Firm-KB v2 root causes (orchestrator inventing per-phase `intended_handle` values that aren't in Phase 0.0 assignment; orchestrator dropping per-topic actuals for content-build phases). Files:
  - `audit-templates/pipeline-state.schema.json` — JSON Schema 2020-12. Required fields per phase_log entry: `phase_id`, `role`, `intended_handle`, `actual_model_id`, `actual_provider`, `actual_family`, `dispatch_status` (enum: `dispatched-as-intended` | `dispatched-with-substitution` | `dispatched-after-override` | `failed-then-acknowledged-opt-out`), `timestamp`. Optional: `phase_label`, `topic_id`, `dispatch_fingerprint_match`, `notes`. The model_assignment block at the top required Phase 0.0 role fields, optional `mid_build_overrides` array for atomic re-assignment.
  - `examples/pipeline-state.example.yaml` — golden reference (10 phase entries: 0.0, 0.2, 1.1 ×2, 5.2 ×2, 5.4, 6.4, 7.0, 8.0).
  - `Validate-PipelineState.ps1` (20 KB) — lints the file against (a) JSON Schema via `Test-Json -SchemaFile`, (b) Rule 20 integrity: every `phase_log[].intended_handle` MUST be in `model_assignment` or `mid_build_overrides[].new_handle` (catches per-phase invention), (c) Rule 19 minimum coverage: Phase 0.0 entry present, at least one fact-check/audit phase logged, Builder A AND Builder B both logged if Phase 5.2 has entries, (d) registry family lookup: every `actual_model_id` resolvable from `model-registry.yaml` MUST have matching `actual_family`. Exit codes: 0=VALID, 1=RULE-VIOLATION, 2=SCHEMA-INVALID, 3=FILE-ERROR.

- **YAML mini-parser inlined in both validators.** Handles the subset needed for our schemas: nested maps via indent, scalar + map list items, inline flow lists `[a, b, c]`, quoted strings, ISO 8601 timestamps, true/false/null. Does NOT support anchors/aliases, multi-line scalars (`|` / `>`), flow mappings. Workaround for PowerShell 7 not having native YAML support — avoids the `powershell-yaml` install dependency. Future refactor: extract to `lib/Yaml.psm1` for shared use.

### Changed

- **`Generate-QualityScorecard.ps1` (`Get-PhaseProvenance`) now prefers `sources/pipeline_state.yaml` over `sources/pipeline_state.md`.** YAML format is detected by presence of `phase_log:` at column 0; YAML phase entries are split on `- ` list-item prefix within the `phase_log:` section; required fields are extracted by anchored regex. The legacy markdown path (chunk-by-heading-then-extract-fields) is preserved as fallback for pre-v3.1.11 builds. Verified: example.yaml produces 10 entries, Rule 19 evaluation correctly enforces 5 of 6 cross-phase pairs (the 6th lacks a corresponding Phase 1.2 entry in the example, correctly INSUFFICIENT_DATA).

- **`01-shared-axioms.md` Rule 20** now explicitly references `sources/pipeline_state.yaml` as the v3.1.11+ canonical format, with the legacy `sources/pipeline_state.md` preserved for backward compatibility. Both formats require the same five fields per dispatch.

### Verified

- `Validate-PipelineState.ps1` against `examples/pipeline-state.example.yaml` → exit 0 VALID.
- Against a deliberately broken variant with (a) `intended_handle: builder-openai-gpt51-INVENTED` (not in model_assignment), (b) missing Phase 0.0 entry, (c) no fact-check phases logged, (d) Phase 5.2 missing Builder B, (e) wrong `actual_family` for a known model — caught all 5 violations as `[ERROR]` and `[WARN]` rows with actionable remediation strings.

### Notes

- The YAML mini-parser had several iteration bugs during development that are worth recording for the v3.1.13+ extract-to-shared-module work: (1) `$pid` is a PowerShell auto-variable (process ID), can't be used as a loop variable — renamed to `$phaseIdVal`; (2) `$Json` (switch parameter) and `$json` (variable) are the same identifier in case-insensitive PowerShell — renamed local to `$jsonText`; (3) `${pid}` in string interpolation references the auto-variable too, not a renamed `$phaseIdVal`; (4) the nested-function pattern (Read-Block / Read-Map / Read-List) had script-scope shadowing issues — replaced with an iterative explicit-stack parser; (5) initial promote logic incorrectly re-entered already-completed nested maps when a sibling top-level key appeared — fixed to only promote when last key's value is `$null`. None of these affect external callers (the validator's public interface is just `-Path -SchemaPath -RegistryPath -Strict -Json` and the four exit codes).

---

## [3.1.10] — 2026-06-08 (patch)

### Fixed

- **Dispatch-time silent-fallback detection (DISPATCH-FINGERPRINT mechanism).** A real WA-Law-Firm-KB v2 build (2026-06-08) exposed a critical gap: the v3.1.6 DISPATCH-FAILURE CONTRACT relied on dispatch failures being VISIBLE (errors, exceptions). But OpenCode's Task tool silently falls back to the parent (Lead) model when `subagent_type` doesn't match a configured agent — returns a response, no error. The orchestrator never knew dispatch failed and continued through 23 phases. 62.5% of dispatches (10 of 16) silently substituted; the scorecard's Rule 19 actuals evaluator (v3.1.9) caught the violation at Phase 9, but by then the build was complete. Fix: Render-OpenCodeAgents.ps1 v3.1.10 embeds a deterministic `DISPATCH-FINGERPRINT::<agent-name>::<16-char-hex>` token in each sub-agent's prompt AND in its description field. The orchestrator (per new MANDATORY protocol in `prompts/01-orchestrator.md`) prepends `ECHO-FINGERPRINT` to every Task dispatch; a correctly-routed sub-agent echoes the fingerprint on its first line (it has the prompt; the parent model on silent fallback does not). The new `Test-DispatchFingerprint.ps1` helper script verifies fingerprint match mechanically (exit 0 / 1 / 2 / 3 distinguishing match, fingerprint-mismatch-or-missing, agent-not-in-config, and config-error). On mismatch: DISPATCH-FAILURE CONTRACT fires immediately, at dispatch time rather than at scorecard time.

- **OpenCode subagent_type naming convention enforced.** Same WA-Law-Firm-KB v2 build root cause: the orchestrator was dispatching to registry handle names (`lead-xai-grok43`, `builder-deepseek-v4-flash`, `factcheck-deepseek`, `auditor-mistral`) while the opencode.json rendered by Render-OpenCodeAgents.ps1 used role-based names (`lead`, `builder-a`, `builder-b`, `critic-pool-handle-1`, `factcheck-pool-5a-5b-5c-handle-1`, etc.). These don't match — OpenCode receives an unknown subagent_type, falls back silently to the parent model. Fix: (a) Rule 20 in `01-shared-axioms.md` explicitly states that OpenCode `subagent_type` MUST be a role-based agent name from opencode.json, never a registry handle name. (b) `prompts/01-orchestrator.md` MODEL ASSIGNMENT PLUMBING section now includes a 7-step OPENCODE DISPATCH PROTOCOL (MANDATORY) covering subagent name lookup, ECHO-FINGERPRINT prepending, fingerprint verification, intended_handle integrity, and per-topic logging. (c) Render-OpenCodeAgents.ps1 v3.1.10 injects a "DISPATCH ROUTING TABLE" section directly into the Lead agent's prompt — listing every framework role with its exact subagent_type value, configured model, and expected DISPATCH-FINGERPRINT. The Lead's own prompt is now the authoritative routing source the orchestrator dispatches against.

- **Rule 20 `intended_handle` integrity tightening.** Same build also exhibited a second Rule 20 violation: the orchestrator was rewriting `intended_handle` per phase with whatever handle it dispatched to, instead of preserving the Phase 0.0 role assignment. So `intended_handle: builder-openai-gpt51` appeared in Phase 1.1 even though Phase 0.0's `model_assignment:` said `builder_a: builder-deepseek-v4-flash`. The Rule 20 audit trail became meaningless because both `intended` and `actual` could drift independently. Fix: Rule 20 in `01-shared-axioms.md` now explicitly states `intended_handle` MUST come from the Phase 0.0 `model_assignment:` block; drift without a Mid-Build Override Flow entry is itself a Rule 20 violation (separate from actual-vs-intended divergence).

- **Per-topic actuals logging requirement.** WA-Law-Firm-KB v2 had Phase 5.2 (per-topic build content for 15 topics) with ZERO actuals entries in pipeline_state.md, which caused the Quality Scorecard's Rule 19 cross-phase pair evaluation to return INSUFFICIENT_DATA for every pair anchored to that phase. Fix: Rule 20 + orchestrator prompt now require that content-generation phases log per-dispatch actuals (one entry per builder per topic, OR a single phase header + per-topic actuals table). Phases that draft N topics with no log entries are themselves a Rule 20 violation.

### Added

- **`Test-DispatchFingerprint.ps1`** (NEW, 10KB) — Helper script that takes (-OpenCodeJsonPath, -AgentName, -ResponseText) and verifies the response begins with the expected DISPATCH-FINGERPRINT for the named sub-agent. Returns structured results (text or `-Json`) with `dispatch_status_recommendation` populated for direct logging to pipeline_state.md. Exit codes: 0=match, 1=mismatch, 2=agent/fingerprint not in opencode.json, 3=config error. Used by the orchestrator mechanically after every Task dispatch on OpenCode hosts.

- **DISPATCH ROUTING TABLE injection into Lead's prompt** — Render-OpenCodeAgents.ps1 v3.1.10 now appends a structured routing table (framework role → subagent_type → configured model → expected DISPATCH-FINGERPRINT) directly into the Lead agent's prompt in opencode.json. The Lead reads its own prompt at session start and has the authoritative dispatch routing inline — eliminating the gap where orchestrator and renderer disagreed about subagent names.

### Verified

- End-to-end smoke test: rendered opencode.json from a real assignment, confirmed all 9 per-role agents have unique 16-hex DISPATCH-FINGERPRINT values in their descriptions and prompts, confirmed the Lead's prompt contains the routing table. Then ran Test-DispatchFingerprint.ps1 against 5 scenarios:
  - Match (correct fingerprint in response) → exit 0, dispatch_status: dispatched-as-intended
  - Silent fallback (no fingerprint in response) → exit 1, dispatch_status: dispatched-with-substitution + remediation
  - Wrong fingerprint (routed to a different subagent) → exit 1, dispatch_status: dispatched-with-substitution + remediation
  - Agent name not in opencode.json (registry handle name used as subagent_type) → exit 2, dispatch_status: failed-then-acknowledged-opt-out + remediation listing valid agent names
  - JSON output mode → structured JSON with status, expected/observed fingerprints, remediation
  All 5 scenarios produce the correct verdict + actionable remediation message.

### Notes

- The WA-Law-Firm-KB v2 build (the trigger for this patch) is materially unreliable: 62.5% silent-fallback rate, only 4 actual model families ran (deepseek 8 dispatches, mistral 4, openai 2, x-ai 1) vs the 8 families intended, and Phase 5.2 (per-topic content) was unlogged. The orchestrator's `<2% error rate` summary cannot be trusted because the fact-check phases themselves silently substituted to deepseek. Recovery options for this specific build are documented in `<KB-root>/audit/v3.1.10-recovery-plan.md` (written by this patch into the affected KB folder).
- After applying v3.1.10, operators must re-render opencode.json with `Render-OpenCodeAgents.ps1` and **restart OpenCode** (config loaded at startup, no hot-reload) so the new DISPATCH-FINGERPRINT mechanism takes effect. Pre-v3.1.10 opencode.json files lack the fingerprint and the Lead's routing table — `Test-DispatchFingerprint.ps1` will exit 2 (expected_fingerprint_missing) for any agent in such a file, which is itself an actionable signal to re-render.

---

## [3.1.9] — 2026-06-07 (patch)

### Fixed

- **`Generate-QualityScorecard.ps1` now enforces Rule 19 against Rule 20 actuals.** The v3.1.8 normative rule made model provenance a first-class audit obligation but the scorecard generator still scored Rule 19 family-separation against the *intended* Phase 0.0 assignment (the `model_assignment:` block). A build where the Lead silently substituted for both Builders (the v3.1.6 anti-pattern) would still report Rule 19 ENFORCED based on intent, defeating the integrity that Rule 20 was added to provide. Fix: scorecard now parses per-phase actuals from `sources/pipeline_state.md` and evaluates Rule 19 against actuals, with:
  - **Cross-phase verification pair evaluation** — the six canonical pairs from Rule 19 in `01-shared-axioms.md`: (Phase 1.2 ≠ 1.1), (5.4 ≠ 5.2), (6.4 ≠ 5.2), (7.0 ≠ 5.2), (7.0 ≠ 6.4), (8.0 ≠ 6.4). Each pair verdicts as `ENFORCED` / `SILENTLY_VIOLATED` / `ACKNOWLEDGED_OPT_OUT` / `INSUFFICIENT_DATA`.
  - **Within-phase distinctness checks** — Builder A vs Builder B family distinctness within a build phase, plus a v3.1.6 anti-pattern detector that flags when Lead's `actual_model_id` is identical to either Builder's `actual_model_id` (the Lead-acted-as-both-Builders signature).
  - **Verdict integration**: `silently-violated` forces composite verdict to `FAIL`; `insufficient-data` caps composite at `PASS-WITH-CAVEATS` (cannot confirm Rule 19); `enforced-with-acknowledged-opt-outs` tags the three dimensions named in `audit-templates/kb-quality-dimensions.yaml § family_separation_exception_handling.tagged_dimensions_when_exception_present` (cross_reference_fidelity, qualifier_preservation, citation_density_and_primary_source_rate) but does NOT auto-downgrade per yaml policy.
  - **Markdown report**: new `## MODEL PROVENANCE (RULE 20) AND FAMILY SEPARATION (RULE 19)` section with the pair-results table, within-phase findings table, per-phase actuals table, acknowledged-opt-outs list, and tagged-dimensions list. Rule 19 silent violations and Rule 20 absent-actuals also flow into the OPEN ITEMS table as blocker/material entries.
  - **JSON output**: new `model_provenance` block with `rule20_entry_count`, `per_phase_actuals`, and `rule19_family_separation` (overall_status, pair_results, within_phase_findings, acknowledged_opt_outs, has_silent_violation, tagged_dimensions, methodology_note).
  - **Methodology appendix** updated to explain that Rule 19 is evaluated against actuals only; the intended `model_assignment` excerpt is preserved for context but explicitly marked "NOT used for Rule 19 score".
  - **Framework version** in JSON/markdown header updated from `v3.0` to `v3.1.9`.

- **`prompts/01-orchestrator.md` MODEL ASSIGNMENT PLUMBING section now specifies a recommended format** for per-phase actuals log entries in `pipeline_state.md`, so orchestrators write entries the scorecard's `Get-PhaseProvenance` parser can reliably consume. The parser remains tolerant (accepts any markdown heading + bullet/key-value format containing the five required fields within one chunk), but the recommended format makes intent unambiguous and round-trips cleanly through `ConvertFrom-Yaml` for future tooling.

### Verified

- Tested against three scenarios at `$env:TEMP\v319-test\`: (a) ENFORCED — all 6 cross-phase pairs use cross-family models → composite verdict unaffected; (b) SILENTLY_VIOLATED — Lead-acted-as-both-Builders + Phase 5.4 same-family fact-check → composite forced to FAIL with 4 Rule-19 blocker OPEN ITEMS rows; (c) INSUFFICIENT_DATA — legacy build with no Rule 20 entries → composite capped at PASS-WITH-CAVEATS with material OPEN ITEMS row.
- The detector caught a real Rule 19 violation in the initial ENFORCED test fixture (Phase 7.0 audit using `openai` family while Phase 5.2 Builder B was also `openai` family — Rule 19 requires Phase 7.0 to differ from BOTH families used in Phase 5.2). Fixing the fixture to use a third family for Phase 7.0 (mistral) produced the expected all-ENFORCED result. This is empirical confirmation that the detector enforces Rule 19's "different from Phase X AND Phase Y" pairings correctly, not just one-side-of-the-pair distinctness.

### Notes

- Builds that pre-date v3.1.8 cannot be retroactively scored against actuals (the data wasn't captured). For these, the scorecard reports `rule19_family_separation.overall_status = insufficient-data` and surfaces a material OPEN ITEMS row noting the build pre-dates Rule 20. Operators should regenerate the scorecard after the build is rerun with a v3.1.8+ orchestrator.
- The recommended per-phase actuals format in `01-orchestrator.md` is a *recommendation*, not a hard requirement of the parser. Custom orchestrator implementations may emit any format provided the five required fields (`intended_handle`, `actual_model_id`, `actual_provider`, `actual_family`, `dispatch_status`) appear within a single markdown-heading-delimited chunk and a phase id (`Phase X.Y`) is discoverable in the same chunk.

---

## [3.1.8] — 2026-06-07 (patch)

### Fixed

- **Model Provenance Honesty rule added (`01-shared-axioms.md` Rule 20).** Operator empirically observed (2026-06-07) that v3.1 phase logs were recording the INTENDED model from `model_assignment` even when the ACTUAL dispatch had been Lead-substituted (silent-fallback in v3.1.6, since-forbidden). Recording the intended assignment when the actual model differed is a Quality Scorecard integrity violation — the framework's audit trail becomes a lie about what model produced what content. Fix: new Rule 20 mandates that per-phase logs in `pipeline_state.md` record ACTUAL dispatch results (intended_handle + actual_model_id + actual_provider + actual_family + dispatch_status of `dispatched-as-intended` | `dispatched-with-substitution` | `dispatched-after-override` | `failed-then-acknowledged-opt-out`) alongside the intended assignment. The two fields must be reconciled in the phase log when they differ. Per-phase deliverables (comparison_report.md, factcheck_*.md, scorecard) must include a "Model provenance" section sourced from actuals, not intentions. Quality Scorecard scores Rule 19 family-separation against ACTUALS.

- **`prompts/01-orchestrator.md` MODEL ASSIGNMENT PLUMBING section updated** to reference Rule 20 and require post-dispatch capture of the adapter response (model_id, top_provider, usage) into `pipeline_state.md` per-phase log entries with the actuals-vs-intended schema.

### Out of scope (deferred)

- `Generate-QualityScorecard.ps1` script-level update to consume the new actuals-vs-intended schema and score Rule 19 against actuals — deferred to v3.1.9 (script change with conformance test). The Rule 20 spec is normative now; the scorecard generator will be updated to enforce it in the next patch.
- Backfilling actuals for builds that ran before v3.1.8 — not possible (the data wasn't captured). Affected builds remain Rule 19-degraded with no recoverable provenance; operators should regenerate scorecards with explicit "pre-Rule-20" caveat or rebuild.

---

## [3.1.7] — 2026-06-07 (patch)

### Verified

- **OpenCode Task tool primary-source investigation: OUTCOME 1 (HIGH confidence).** Dispatched a Claude Opus 4.8 research agent to verify against OpenCode source (commit `2006259...`, schema blob `5ca1666...`). Verdict: HOST-NOTES §2.4 was correct — OpenCode's Task tool `subagent_type` parameter is `Schema.String` with NO enum restriction, accepts custom agent names from `opencode.json`'s `agent:` block. The operator's earlier symptom (Task tool "not dispatching") was a config rendering defect, not a fundamental limitation. Three rendering requirements verified: (a) each agent needs a `description` field (LLM uses it to decide dispatch; without it, LLM is instructed NOT to use), (b) `mode: "subagent"` must be explicit on Task-dispatchable agents (and `mode: "primary"` on Lead), (c) parent's `permission.task` must not deny the named subagent.

- **v3.1.5's Render-OpenCodeAgents.ps1 verified to emit all 3 required fields.** Dry-run inspection confirmed: every agent has `description: "Framework role: X — does Y. Model family: Z."`, `mode: "subagent"` on subagents + `mode: "primary"` on lead, and lead's `permission.task` is a per-subagent allow-list (`{ "*": "deny", "<subagent>": "allow" }`) — more secure than blanket allow + correctly defeats default-deny per OpenCode's permission semantics.

- **OpenCode viability verdict: REVISED to viable.** The earlier "OpenCode not viable for v3.1 production" preliminary verdict from session-mid is retracted. With v3.1.5's rendering, OpenCode IS a viable host for v3.1 production work.

### Notes

- This patch is verification-only — no script or prompt changes. The investigation's value was confirming that the v3.1.5 implementation was structurally correct, not that anything needed to change.

---

## [3.1.6] — 2026-06-07 (patch)

### Fixed

- **Orchestrator silent-fallback to single-model FORBIDDEN.** Surfaced by an operator running v3.1 on OpenCode + OpenRouter, mid-Phase-3.0: the orchestrator's Task-tool dispatch to a custom-named sub-agent failed (suspected OpenCode Task-tool limitation with `subagent_type` for custom agents, separate investigation in v3.1.7); the orchestrator's response was *"Let me proceed pragmatically and deepen the topics as the Lead orchestrator (current model DeepSeek — different family from both builders)."* This is the same silent-degradation anti-pattern as v3.1.2 (Phase 0.0 auto-selection) and v3.1.4 (mid-build auto-switching). The Lead being its own backstop defeats Rule 19's independent-verification purpose, regardless of whether the Lead's family differs from the intended sub-agent's declared family. Fix: added a `DISPATCH-FAILURE CONTRACT (MANDATORY)` section to `prompts/01-orchestrator.md` immediately after the HOST-CONTRACT DEFAULT block. It requires the orchestrator to stop on any dispatch failure, record the failure in `sources/pipeline_state.md`, and surface three explicit operator choices (investigate-and-fix / acknowledged-Rule-19-opt-out / abort) — never picking on the operator's behalf. The phrase "I'll proceed pragmatically as the Lead" is explicitly forbidden in orchestrator output.

### Known issue (deferred to v3.1.7)

- **OpenCode Task-tool `subagent_type` may not actually dispatch to custom-named agents** declared in `opencode.json`'s `agent:` block, contrary to what HOST-NOTES §2.4 documented (verified from OpenCode source/docs but not runtime). Operator empirical observation on 2026-06-07: agents appear in `view subagents` list but Task-tool invocation returns dispatch failure. v3.1.7 investigation will primary-source-re-verify Task-tool subagent_type accepted values, runtime-test custom-agent dispatch, and either correct HOST-NOTES (if Task-tool works with parameters we're not setting) or downgrade OpenCode HOST-NOTES capability level.

---

## [3.1.5] — 2026-06-07 (patch)

### Fixed

- **OpenCode static-agent renderer shipped.** `hosts/opencode/HOST-NOTES.md` §5.1 already required Phase 0.0 to render the OpenCode `opencode.json` `agent:` block from `model_assignment`, but the implementation script was missing. This left OpenCode operators with no mechanical way to map framework roles to per-role static agents.
- **Rule 19 OpenCode inheritance gap closed.** Without static per-role agents, OpenCode's Task tool inherits the Lead's model for child sessions, defeating model-family separation across builders, critics, fact-checkers, auditors, and memo fact-checkers. New `Render-OpenCodeAgents.ps1` resolves each assignment handle through `Resolve-Model.ps1` and emits one OpenCode agent per framework role (or per pool member) with the correct `provider/model_id` string.
- **Phase 0.0 and orchestrator prompts now require OpenCode rendering before Phase 0.1.** `prompts/00a-model-selection.md` adds a mandatory OpenCode closeout step and post-phase check; `prompts/01-orchestrator.md` reinforces that OpenCode runs must render `opencode.json` before sub-agent dispatch begins.

### Added

- `Render-OpenCodeAgents.ps1` at framework root, with `-Help`, assignment autodiscovery, registry fallback, dry-run JSON preview, backup-on-overwrite, optional summary log, and restart-required reminder.
- v3.1.5 post-defect audit note in `examples/conformance-test-report-v3.1.md`, documenting the L7 conformance blind spot and requiring future host-specific end-to-end smoke tests.

---

## [3.1.4] — 2026-06-07 (patch)

### Fixed

- **OpenRouter adapter dispatch error envelope now classifies HTTP failures + provides actionable remediation.** Previously, every non-success exit from `adapters/model-providers/openrouter/dispatch.ps1` returned a generic `{ status: error, error: "HTTP NNN: ..." }` envelope, and the orchestrator had to interpret what the status code meant. Updated envelope schema now includes `error_type` (one of: `auth_failure`, `insufficient_credits`, `forbidden_or_model_unavailable`, `model_not_found`, `rate_limit`, `upstream_error`, `network_or_unknown`, `other`), `remediation` (specific operator-actionable instructions), and `http_status` (raw code). HTTP 402 specifically now maps to `error_type: insufficient_credits` with remediation pointing at OpenRouter credits page + the Mid-Build Override Flow.
- **Mid-Build Override Flow in `prompts/00a-model-selection.md` tightened to MANDATORY operator-interactive contract** matching the Phase 0.0 fix from v3.1.2. Previously the flow said "stop the affected phase, surface the failure, prompt for a replacement handle" without explicit WAIT-FOR-OPERATOR language; agents on lower-instruction-following hosts could auto-pick a replacement. Updated section now includes the same INTERACTION RULES (MANDATORY, READ FIRST) preamble, an explicit 3-option choice the operator must make (resolve+retry / switch handle / switch preset), and a parallel-dispatch storm coordination rule (first failure pauses all parallel sub-agents; single consolidated prompt to operator).

### Scope of fix

These changes affect:
- `adapters/model-providers/openrouter/dispatch.ps1` — new `Classify-HttpError` helper + expanded `Write-ErrorJson` signature + updated main-script catch block
- `prompts/00a-model-selection.md` Mid-Build Override Flow section

Other provider adapters (copilot-cli, azure-foundry, ollama) are unaffected by the OpenRouter-specific classification but their dispatch.ps1 files use similar error envelope shapes; future v3.1.x patches should propagate the same classification pattern when those adapters surface specific runtime failures in real builds.

### Out of scope (deferred to v3.2)

- Active OpenRouter balance polling (`Get-OpenRouterBalance.ps1` — would call `/api/v1/credits` periodically and warn at threshold).
- Running cost tally in `pipeline_state.md` (orchestrator should accumulate per-phase `cost_estimate` after each dispatch).
- Cross-provider parallel-dispatch coordinated pause (storm-detection logic is currently advisory in the prompt; mechanical enforcement would require a dispatch coordinator script).

---



## [3.1.3] — 2026-06-07 (patch)

### Fixed

- **Auto-ship language removed from `05-build-orchestrator.md`.** Section 2 "Ship Decision" previously read "Human confirms (for legal KBs) or auto-ships (for lower-risk KBs if configured)" — this gave the orchestrator a potential auto-ship path that violated the operator-control contract clarified in v3.1.2. Replaced with explicit "Operator confirms ship explicitly. No automated ship path is shipped with v3.1." Operators who want auto-shipping for low-risk KB types must build that as a separate opt-in subsystem with their own audit trail; the framework's orchestrator MUST NOT auto-ship.
- **Auto-proceed past provisional scorecard removed from `prompts/70-final-audit.md`.** The Decision Rules table's BUILD-INCOMPLETE row previously said "Proceed to Phase 8.0; regenerate final scorecard after Phase 8.5" without an operator gate. Updated to require the orchestrator to PRESENT the provisional scorecard with the BUILD-INCOMPLETE explanation, WAIT for explicit operator confirmation, then dispatch Phase 8.0.

### Audit basis

These two fixes plus the v3.1.2 Phase 0.0 fix were identified by a focused prompt-interaction audit of all 24 KB framework prompts + 7 rulebooks + 4 memo framework prompts. Audit report: `examples/prompt-interaction-audit-2026-06-07.md` (audit output recorded in v3.1.3 session log; not separately written to disk by the audit agent). Other audited files cleared with no operator-control defects.

---

## [3.1.2] — 2026-06-07 (patch)

### Fixed

- **Phase 0.0 operator-interactive contract clarified — fixes auto-selection regression.** The Phase 0.0 prompt at `prompts/00a-model-selection.md` previously said "Offer the operator four sub-flows" without explicit MUST-WAIT-FOR-OPERATOR language; agents on lower-instruction-following hosts (observed on OpenCode 2026-06-07) were interpreting "offer" as "you pick one" and auto-selecting models without operator input. Fix: added a top-of-prompt `INTERACTION RULES (MANDATORY, READ FIRST)` section with explicit prohibitions ("DO NOT auto-select", "WAIT for operator's explicit response", "auto-acceptance is forbidden") plus a closing `POST-PHASE CHECK` that requires the orchestrator to verify every handle was explicitly named by the operator before yielding to Phase 0.1. `prompts/01-orchestrator.md` Phase 0.0 dispatch instructions updated to reinforce the same operator-control contract. Existing builds that auto-selected can keep running (the selections were within registry constraints and validated Rule 19) but the operator should be aware that the next build will properly prompt for selection.

---

## [3.1.1] — 2026-06-07 (patch)

### Added

- **`Validate-Host.ps1` (43 KB) — host-capability smoke-test script.** Operator-runnable script that verifies the current host (Copilot CLI / OpenCode / etc.) supports the 6 capabilities the v3.1 framework needs: file-read, file-write with atomicity, shell-exec (PowerShell 7+), Task dispatch with handle, parallel Task ≥ 4, and cross-family parallel dispatch. Closes the v3.1.0 gap where `HOST-CONTRACT` referenced this script but it was never shipped. Includes `-SkipLiveDispatch` for environments without API keys; `-UpdateHostNotes` writes the verified capability level back into `hosts/<host>/HOST-NOTES.md`.

---

## [3.0.0-pre] — Unreleased (in progress)

Initial v3.0 release. Forked from v2 baseline (`KB Creation - Modular\`) on 2026-06-06 with v2 preserved unmodified. 18 framework-level changes. See `specification\technical-specification-v3.0.md` (added in Layer 7) for the normative spec; see the v2→v3 cheat sheet section of `HOW-TO-USE.md` (added in Layer 7) for the operator migration guide.

### Added

- **Phase 0.0 — Model Selection.** New first step prompts the operator with 3 preset categories (Standard Multi-Family / Budget Multi-Family / Single-Family, implemented as Anthropic and OpenAI single-family YAML presets) plus a Custom escape. Per-build model assignment is validated against Rule 19 (Model-Family Separation), allows explicit operator opt-out for conflicts, and is persisted in `sources/pipeline_state.md` and the Quality Scorecard. Files: `prompts/00a-model-selection.md`, `Validate-ModelAssignment.ps1`, `audit-templates/model-presets.yaml`.
- **KB Quality Scorecard subsystem.** New `audit/` folder per KB containing required `kb-quality-scorecard.md` (human-readable rolled-up artifact), `kb-quality.json` (machine-readable companion), and `kb-quality-history.json` (append-only version trend), with optional methodology and badge support artifacts where generated. Seven mechanical quality dimensions roll up to a composite KB Quality Index and a PASS / PASS-WITH-CAVEATS / CONDITIONAL / FAIL verdict. Generated by `Generate-QualityScorecard.ps1` from existing phase artifacts; no new model calls. Replaces the ad-hoc evaluation workflow operators previously had to assemble by reading across 12+ `sources/` files.
- **Three-tier output: `full/` + `practice/` + `authority/`.** New middle tier `practice/` = `full/` with `[INTERPRETATION]`-tagged paragraphs stripped but `[GUIDANCE]`-tagged paragraphs retained. Gives downstream drafters access to practice synthesis without dragging in pure interpretation. New `Extract-PracticeView.ps1`; updated `Extract-AuthorityView.ps1`; updated AGENTS.md routing language.
- **`Verbatim-Linter.ps1` promoted from pilots to mainline.** Mechanical paraphrase-drop and wrong-anchor detection against cited source text from `grounding/fetch_log.json`. Integrated at Phase 6.2 alongside `Register-Lint.ps1`.
- **`Validate-Phase4Inventory.ps1`.** Schema validator for the single-source claim inventory produced by Phase 4. Exits 1 if malformed; closes the framework-review Finding 4 contract gap structurally rather than by instruction.
- **`Detect-Reattribution.ps1`.** Claim-reattribution check; complements `Detect-MemoLeakage.ps1`. Hashes the `source_quote` of every paraphrased CLAIM MAP row and confirms the hash appears in `claims.json` under the cited `claim_id`. Catches the case where a writer cites the right claim_id but characterizes it wrong.
- **`Diff-KBVersions.ps1`.** Structured diff between two builds of the same KB. Emits per-topic-file added / removed / changed / register-reclassified claims.
- **`Detect-CrossKBConflicts.ps1`.** Cross-KB advisory tool. Detects when two KBs in the same portfolio opine on the same fact and disagree.
- **Phase 8.5 — Adversarial KB Red-Team.** New stress-test phase that attempts to extract bad content (definitive answers on unresolved topics; institutional facts about illustratively-named entities; memos drafted from `[GUIDANCE]`-only content). Tests whether the dual-view architecture holds under adversarial pressure.
- **KB-type prompt branching.** Reserved `prompts/legal/` and `prompts/company/` subdirectories for Layer 5 KB-type-specific overrides where the discipline meaningfully differs (Phase 5.1, 5.2, 5.3, 5.5, 7.0). Other prompts remain common.
- **`audit-templates/` directory.** Template files for the Quality Scorecard subsystem: `quality-scorecard-template.md`, `kb-quality-dimensions.yaml` (with default weights tunable per KB type), `audit-trail-schema.json`, `model-presets.yaml`.
- **`Migrate-V2KBtoV3.ps1`.** New opt-in migration script for previously developed v2 KBs: validates recognizable v2 structure, archives the existing `authority/` view, regenerates v3 `practice/` and `authority/`, retroactively synthesizes volatile/unverified manifests, invokes the Quality Scorecard, and emits `audit/v2-to-v3-migration.md` without model calls.

### Changed

- **Phase consolidation and prompt rationalization.** Phase 1.5 (Remediation Triage) cut — folded into Phase 2a. Phase 3.5 (Compliance Diff) cut — folded into Phase 4. Phase 2a + 2b merged into a single Lead-review prompt. Phase 6c + 6a merged into a single post-assembly-automated prompt. Phase 11c kept separate from Phase 6.25 to preserve critic independence.
- **Phase renumbering — monotonic.** Non-monotonic v2 numbering (11c between 6.25 and 6c; 6.5 between 6a and 7) replaced with sortable v3 numbering. v2→v3 mapping table in `HOW-TO-USE.md`.
- **Crawl4AI primary-source grounding adapter is DEFAULT-ON for Phase 5b and Phase 6b.** Empirical pilot evidence (9 of 57 SUPPORTED/HIGH citations downgraded when grounded) made the optional behavior an unacceptable silent regression. Opt-out captured in scoping_report.md with rationale; opt-out surfaces in Quality Scorecard.
- **`Register-Lint.ps1` extended `should`-verb vocabulary.** Added `should (ensure|include|maintain|document|establish|verify|confirm|obtain|notify|retain|monitor)`, `\bcounsel should\b`, `\bpractitioners should\b`, `\bclients should\b`. Closes framework-review Finding 22.
- **Register-Lint scans root files (AGENTS.md, index.md, table-of-authorities.md), not only `full/`.** Closes framework-review Finding 1.
- **Per-claim refresh cadence by `[VOLATILE:*]` type.** Refresh Orchestrator now drives cadence per-claim within a KB based on the volatile-type taxonomy, with the KB-type interval as fallback for untagged claims. Cuts refresh load on legal Topic KBs where most content is statutory.
- **Phase 0 acquires explicit `model_assignment` block in `scoping_report.md`.** All downstream phases read the assignment rather than the framework's hardcoded defaults.
- **Memo Drafting moved to a sibling framework.** `Memo Drafting Framework v1\` lives alongside `KB Creation - Modular v3\`. KB v3's Phase 8 stress test invokes the memo framework via the documented contract in `Memo Drafting Framework v1\02-corpus-contract.md`. `Detect-MemoLeakage.ps1` is now canonically owned by the memo framework; KB v3 retains an integration pointer.
- **Goldeneye vs Sonnet 4.6 ambiguity resolved.** Default Builder B is Sonnet 4.6; Goldeneye is explicit opt-in via Phase 0.0 model selection. `01-shared-axioms.md` Section 4 clarified.

### Removed

- **`05-build-orchestrator.md` Section 6 (cost estimates).** Pre-2026 pricing data was creating a false anchor. Replaced with token-cost guidance rather than dollar figures.
- **Phase 1.5** (folded into 2a as a flag-below-12KB check)
- **Phase 3.5** (folded into Phase 4 as a compliance-check section of the comparison report)

### Fixed

- **Framework-review Finding 4 — Phase 4 → Phase 5d contract gap.** Phase 4 prompt updated to produce a machine-parseable single-source claim inventory; `Validate-Phase4Inventory.ps1` enforces the schema mechanically.
- **Framework-review Finding 2 — `[UNVERIFIED]`-at-assembly silent stripping.** Phase 6 assembly prompt now mandatorily escalates unresolved `[UNVERIFIED]` to `sources/unresolved_unverified_manifest.md` with `[UNVERIFIED-AT-ASSEMBLY]` marker; Phase 6b treats these as P1.
- **Framework-review Finding 5 — `[VOLATILE:*]` tag preservation at assembly.** Phase 6 assembly prompt now requires VOLATILE-tag preservation across paraphrasing; `sources/volatile_tag_manifest.md` is a required Phase 6 output; Assembly Completion Checklist updated.
- **Framework-review Finding 3 — Phase 5a characterization vs operative-hook gap.** Phase 5a prompt now includes a sixth check that pulls actual subsection text and compares the KB's characterization against the operative hook verbatim.
- **Framework-review Finding 13 — `Extract-AuthorityView.ps1` inline-tag bug.** Pre-extraction validator rejects inline-position register tags before extraction proceeds.
- **Claim-reattribution leak in `Detect-MemoLeakage.ps1`.** New `Detect-Reattribution.ps1` companion script closes the case where a memo cites the right claim_id but characterizes its source_quote incorrectly.

### Migration notes (v2 → v3)

See `HOW-TO-USE.md` § "v2 to v3 cheat sheet" (added in Layer 7) for the operator-facing migration guide. v2 KBs can complete their builds under v2 without disruption. New KBs should use v3; existing KBs may opt in to v3 via `Migrate-V2KBtoV3.ps1` or full rebuild.

---


## [3.1.0] — Released 2026-06-07

Provider abstraction + Host abstraction + Usability scripts release. Forked from v3.0.1 on 2026-06-07 with v3.0.1 preserved unmodified at `KB Creation - Modular v3\`. This release is hosted in the sibling directory `KB Creation - Modular v3 + OpenCode and OpenRouter\`.

### Added

- **Model Registry layer** — operator-authored `model-registry.yaml` with handle → provider+model_id resolution. Decouples framework prompts from specific provider model IDs. New scripts: `Resolve-Model.ps1`, `Validate-ModelRegistry.ps1`, `Infer-Family.ps1`, `Refresh-Registry.ps1`. New schemas: `audit-templates/model-registry.schema.json`.
- **Provider adapters** under `adapters/model-providers/`: `copilot-cli/` (preserves v3.0 default behavior), `azure-foundry/`, `openrouter/`, `ollama/`. Each adapter ships `dispatch.ps1` + `discover.ps1`.
- **Phase 0.0 enhancements** — model selection now offers (a) preset, (b) custom, (c) discover-from-provider, (d) recommend-models-per-role. Presets reference registry handles instead of raw model IDs.
- **Host abstraction** — `HOST-CONTRACT.md` normative spec; `hosts/copilot-cli/HOST-NOTES.md` (existing default); `hosts/opencode/HOST-NOTES.md` (new, conservative L3 pending runtime `Validate-Host.ps1` promotion to L1a).
- **Capability levels** L1a / L1b / L2 / L3 introduced for graceful degradation. Quality Scorecard records actual capability level when below L1a.
- **Usability scripts** — `Test-Setup.ps1` (pre-flight doctor), `Resume-Build.ps1` (resume from interrupted phase), `Initialize-Framework.ps1` (first-time setup wizard), `Show-BuildStatus.ps1` (live progress), `Estimate-BuildCost.ps1` (pre-fleet cost estimate), `Recommend-Models.ps1` (cross-provider domain-aware recommendation), `Discover-OpenRouterCategories.ps1`, `Invoke-FrameworkDoctor.ps1` (deep diagnostics), `Send-CompletionNotification.ps1`.
- **Domain-aware recommendation** — `audit-templates/role-profiles.yaml`, `capability-tiers.yaml`, `domain-capabilities.yaml`, `openrouter-categories.cached.yaml`. Cross-source signals: OpenRouter's native `/api/v1/models?category=<domain>` filter AND benchmark-based rankings from LegalBench / LawBench / SWE-Bench / LMSYS Chatbot Arena. Both displayed side-by-side.
- **`specification/technical-specification-v3.1.0.md`** — new normative spec with §15 Model Provider Abstraction, §16 Host Contract, §17 Domain-Aware Recommendation. v3.0 spec archived.
- **`specification/llm-recreation-prompt-v3.1.0.md`** — updated recreation prompt.
- **Memo Drafting Framework v1 + Provider Registry** updated for Model Registry consumption (sibling framework parity).
- **`Migrate-V2KBtoV3.ps1`** extended for v3.0→v3.1 migration (synthesizes starter model-registry.yaml from any existing model_assignment block).

### Changed

- **Phase 0.0 model selection** now reads from operator's `model-registry.yaml` instead of hardcoded model IDs.
- **`audit-templates/model-presets.yaml`** presets now reference registry handles. Auto-generated default registry shipped for first-time operators (matches v3.0 hardcoded model list).
- **`prompts/01-orchestrator.md`** dispatch language replaced from Copilot-CLI-specific to HOST-CONTRACT-referenced; works against any L1a-verified host.
- **`01-shared-axioms.md` Rule 19** clarified: family is determined by the Model Registry per entry, not inferred from model name. Cross-provider same-family agreement (e.g., Azure-Foundry-GPT-4o + OpenAI-direct-GPT-4o) is NOT cross-family corroboration.

### Preserved (backwards-compatible)

- Existing v3.0.1 framework remains at `KB Creation - Modular v3\` unmodified; in-flight builds keep working.
- Copilot CLI as default host with zero-config operation (registry auto-generated from existing model list if operator doesn't author one).
- All v3.0.1 invariants (Six Rules, Error Pattern Taxonomy, dual-view extraction, Quality Scorecard, Grounded Memo Drafter protocol).

### Build status

- Built via fleet of 10 background sub-agents across 9 layers (L0 bootstrap through L8 cutover).
- L7 synthetic conformance test: PASS=11 / WARN=1 / FAIL=3 on first run.
- Three FAIL items remediated inline (adapter contract README missing; Resume-Build.ps1 + Initialize-Framework.ps1 missing -Help switch; prompts/00a-model-selection.md missing Resolve-Model.ps1 reference).
- One WARN item remediated (prompts/01-orchestrator.md now names Copilot CLI and OpenCode as the v3.1 supported HOST-NOTES).
- Post-remediation re-verification: PASS for all four remediated items.
- See `examples/conformance-test-report-v3.1.md` for the full L7 report + post-remediation addendum.
- Operator should run `Validate-Host.ps1` against OpenCode at first build to promote its capability level from L3 (conservative) to L1a (production) once runtime checks pass.

---



### Added

- **`specification/llm-recreation-prompt-v3.0.md`** — the LLM recreation prompt that, when pasted into a fresh frontier-LLM session, rebuilds both KB Creation - Modular v3 and Memo Drafting Framework v1 from a self-contained spec. A standalone delivery copy is also kept outside the framework at `<external-archive>` for portability when the framework directory is not directly accessible. Self-references in the in-framework copy point at the sibling `technical-specification-v3.0.md`; self-references in the delivery copy use the delivery-folder filename.
- **`LICENSE.txt` (MIT License)** at the framework root and the adapter root. KB Creation - Modular v3 now ships under the MIT License (Copyright (c) Microsoft Corporation). Adapter glue code under `adapters/crawl4ai-fetch/` is also MIT; the six direct third-party Python dependencies continue under their own upstream licenses as attributed in `adapters/crawl4ai-fetch/THIRD_PARTY_NOTICES.md`. The parent `KB Creation Framework\LICENSE.txt` is a pointer file that delegates to each child framework's own LICENSE.txt (v3 is MIT; Memo Drafting Framework v1 license remains pending).
- **Crawl4AI attribution hardened to upstream-LICENSE-verbatim.** The Crawl4AI upstream LICENSE imposes an Attribution Requirement in addition to its Apache-2.0 base. The adapter now reproduces the full upstream Attribution Requirement section verbatim in `adapters/crawl4ai-fetch/THIRD_PARTY_NOTICES.md` § 1 (not just the attribution string), carries the required attribution string in a top-level "Attribution" section in `adapters/crawl4ai-fetch/README.md`, and surfaces the Apache-2.0 + Attribution Requirement combination explicitly in `adapters/crawl4ai-fetch/LICENSE.txt`. Three of the four upstream-enumerated acceptable display locations are now satisfied; any redistribution of this adapter must continue to display the attribution per upstream rules. **(Superseded same day by the Crawl4AI license restructure noted below — the verbatim Attribution Requirement reproduction moved to a new sibling `LICENSE` file, and the `LICENSE.txt` that opened with "Copyright (c) Microsoft Corporation" was deleted to stop displacing UncleCode's name in a directory built around Crawl4AI.)**

### Changed

- **Crawl4AI license restructure: the adapter directory now leads with upstream-faithful attribution, not Microsoft copyright.** The prior `adapters/crawl4ai-fetch/LICENSE.txt` opened with "Copyright (c) Microsoft Corporation" inside a directory built around Crawl4AI, which displaced UncleCode's name in the most visually prominent license artifact for the directory. Restructure:
  - **DELETED** `adapters/crawl4ai-fetch/LICENSE.txt` (the file that opened with Microsoft copyright).
  - **CREATED** `adapters/crawl4ai-fetch/LICENSE` — reproduces the upstream Crawl4AI LICENSE **byte-faithfully** (Apache-2.0 + Attribution Requirement), pinned to upstream blob SHA `ade44a7824869fe57a3dfa98ad4b7ffb764c3cb0`. Zero Microsoft mention in this file. Copyright remains with UncleCode (https://x.com/unclecode) and Crawl4AI project contributors.
  - **CREATED** `adapters/crawl4ai-fetch/NOTICE-glue-code.md` — documents (a) provenance of the verbatim `LICENSE` file with re-audit obligation, (b) MIT inheritance for the Microsoft-authored Python glue scripts (six scripts named) via the parent framework's `LICENSE.txt`, (c) the rationale for NOT restating Microsoft MIT in this directory.
  - **UPDATED** parent `KB Creation - Modular v3/LICENSE.txt` scope clause to explicitly cover the six glue scripts by name and point at the new sibling `LICENSE` for Crawl4AI's governance.
  - **UPDATED** grandparent pointer `KB Creation Framework/LICENSE.txt` to reflect the new arrangement.
  - **UPDATED** `THIRD_PARTY_NOTICES.md` § 1 to point at the adjacent `LICENSE` as the canonical home for the verbatim Attribution Requirement text (the attribution string is still carried in NOTICES for discoverability; the full Attribution Requirement section is no longer re-reproduced inline because the adjacent `LICENSE` is byte-faithful upstream).
  - **UPDATED** adapter `README.md` Attribution section to attribute UncleCode explicitly by name and link the new `LICENSE` + `NOTICE-glue-code.md` files.

  UncleCode's name is no longer displaced by Microsoft anywhere in the adapter directory. Four upstream-enumerated acceptable display locations are now satisfied (`LICENSE`, `README.md`, `THIRD_PARTY_NOTICES.md`, and the parent-pointer `LICENSE.txt`).

- **Tier-3 Cloudflare-interactive-challenge library swapped: `nodriver` → `patchright`.** `nodriver` is licensed AGPL-3.0, which is incompatible with the framework's intended distribution model. Replaced with `patchright>=1.47.0` (Apache-2.0; Copyright 2024 Vinyzu; https://github.com/Kaliiiiiiiiii-Vinyzu/patchright-python), a maintained Playwright fork with anti-detection patches. The Tier-3 implementation in `adapters/crawl4ai-fetch/fetch_cf_fallback.py` was rewritten against patchright's drop-in Playwright API. Functional equivalent — same Cloudflare-interactive-challenge bypass — under a permissive license matching Playwright upstream. The four-tier fetch cascade is preserved. `requirements.txt`, adapter `README.md`, `THIRD_PARTY_NOTICES.md`, the canonical Primary-Source Access Fallback Chain in `01-shared-axioms.md`, builder/fact-checker rulebooks, and fact-check prompts (`51`, `54`, `55`, `64`) all updated. `fetch_log.json` `via` field enum is now `"crawl4ai" | "pdf_fallback" | "patchright" | "scrapling"`.

### Removed

- **Patent disclosure / IDF artifacts.** The `specification/patent/` directory (containing three IDF drafts, a cover memo to IPG, and a preliminary prior-art sweep) was removed from the framework distribution. References to patent IDFs in rulebooks, prompts, and the research/spec/recreation-prompt delivery artifacts were neutralized to describe the underlying technical inventions (cross-model verification routing, dual-view extraction, volatile-tag preservation) without patent framing. Patent strategy is a separate workstream not appropriately bundled with the framework artifact.

---



Layer 7 specification and operator documentation are complete, and Layer 8 synthetic conformance testing has passed. This release entry supersedes the earlier `[3.0.0-pre] — Unreleased (in progress)` status line above while preserving that pre-release entry for history. The v3.0 framework artifact set is released after the synthetic conformance gate; the real reference build remains deferred to post-ship operator validation.

Conformance gate passed after remediation of 2 documentation defects caught by synthetic conformance test (Checks 6 and 7). See `examples/conformance-test-report.md` for details.

### Release status

- **Released:** v3 rulebooks, prompts, KB-type overrides, scripts, audit templates, Quality Scorecard subsystem, Memo Drafting Framework integration, migration script, technical specification, operator HOW-TO, and top-level README.
- **Conformance:** Layer 8 synthetic conformance test passed with one non-blocking warning for an explicitly future/out-of-scope portfolio-scorecard reference.

---

## [2.0.0] — 2026-04-09

The reference baseline. See `KB Creation - Modular\` (parent directory) for the v2 source. v2 is preserved unmodified for in-flight builds; v3 is forked from this baseline.

Key v2 invariants carried into v3 (unchanged):

- The Six Rules (Source-Constrained Specificity, Zero Tolerance for Fabrication, Builder Isolation, No Self-Grading, No Silent Skipping, Model-Family Separation)
- The 17-pattern Error Pattern Taxonomy
- The dual-view register architecture (`full/` and `authority/`; v3 adds the `practice/` middle tier)
- Option C threshold-based lesson promotion (3+ KBs)
- Append-only audit trails
- The Grounded Memo Drafter four-step protocol (now owned by the Memo Drafting Framework)

---

*End of CHANGELOG.*
