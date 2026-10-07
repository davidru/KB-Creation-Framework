
# How to Use KB Creation - Modular v3.1

**Version:** 3.1.0; Date: 2026-06-07
**Status:** v3.1 released; L7 post-remediation verdict PASS-WITH-WARNINGS (OpenCode remains L3 pending runtime Validate-Host promotion)

---

## 1. What this is

KB Creation - Modular v3 is an operator-run, prompt-and-script framework for building auditable, practitioner-grade knowledge bases with multi-model isolation, primary-source verification, register-separated output views, mechanical lint/extraction gates, downstream memo stress testing, and a final Quality Scorecard. It is the active framework for new builds; v2 remains available only for in-flight builds or historical reference.

## 2. Quick start

Start with `prompts/01-orchestrator.md`. Give it to the Lead session. The operator selects the active host first, then the orchestrator runs Phase 0.0 model selection, Phase 0.1 scoping, and the builders, critics, fact-checkers, scripts, auditors, and Memo Framework stress tests in order.

### 2.1 Selecting a host

Before Phase 0.0, select the host that is running the build and record it in `sources/host_assignment.md`. Use `HOST-CONTRACT.md` as the normative capability contract and `hosts/<host-name>/HOST-NOTES.md` for the active host's dispatch mechanics, model-handle handling, and verified capability level. If host validation observes L1b, L2, or L3 rather than L1a, continue only with the corresponding Rule 19 and Quality Scorecard degradation path.

## 3. Pipeline phases

| Phase | Name | Prompt / module | What the operator should expect |
|---:|---|---|---|
| 0.0 | Select and validate per-build model assignment | `prompts/00a-model-selection.md` | Select and validate per-build model assignment. |
| 0.1 | Scope KB, audience, sources, Tier A/B density, and model_assignment | `02-info-gather.md` | Scope KB, audience, sources, Tier A/B density, and model_assignment. |
| 0.2 | Pressure-test scoping report | `prompts/00b-rubber-duck-scoping.md` | Pressure-test scoping report. |
| 1.1 | Independent topic research and proposed structure | `prompts/11-builder-research.md` | Independent topic research and proposed structure. |
| 1.2 | Pressure-test merged topic list | `prompts/12-rubber-duck-topics.md` | Pressure-test merged topic list. |
| 1.3 | Per-topic drafting | `prompts/13-builder-draft.md` | Per-topic drafting. |
| 2.0 | Combined structural + depth review | `prompts/20-lead-review.md` | Combined structural + depth review. |
| 3.0 | Revise v1 drafts from Lead review | `prompts/30-builder-revision.md` | Revise v1 drafts from Lead review. |
| 4.0 | Compare v2 drafts, inventory single-source claims, check revision compliance | `prompts/40-lead-comparison.md` | Compare v2 drafts, inventory single-source claims, check revision compliance. |
| 5.1 | Verify currency and operative-hook characterization | `prompts/51-factcheck-currency.md` | Verify currency and operative-hook characterization. |
| 5.2 | Verify citations with grounding default-on + Verbatim-Linter | `prompts/52-factcheck-citations.md` | Verify citations with grounding default-on + Verbatim-Linter. |
| 5.3 | Verify classifications and categories | `prompts/53-factcheck-classification.md` | Verify classifications and categories. |
| 5.4 | Verify Phase 4.0 single-source inventory | `prompts/54-factcheck-single-source.md` | Verify Phase 4.0 single-source inventory. |
| 5.5 | Verify operative mechanisms and cross-reference fidelity | `prompts/55-factcheck-operative-claims.md` | Verify operative mechanisms and cross-reference fidelity. |
| 6.0 | Assemble final KB and required manifests | `prompts/60-lead-assembly.md` | Assemble final KB and required manifests. |
| 6.1 | Pressure-test assembled KB | `prompts/61-rubber-duck-assembly.md` | Pressure-test assembled KB. |
| 6.2 | Run Register-Lint + Verbatim-Linter and disposition findings | `prompts/62-register-lint.md` | Run Register-Lint + Verbatim-Linter and disposition findings. |
| 6.3 | Extract practice/ and authority/, then validate structure and filenames | `prompts/63-extraction-and-filename-validation.md` | Extract practice/ and authority/, then validate structure and filenames. |
| 6.4 | Superset fact-check of assembled full/ | `prompts/64-post-assembly-factcheck.md` | Superset fact-check of assembled full/. |
| 6.5 | A/B/C quality tier classification and mandatory deepening | `prompts/65-quality-tier-audit.md` | A/B/C quality tier classification and mandatory deepening. |
| 7.0 | Final audit and Quality Scorecard generation | `prompts/70-final-audit.md` | Final audit and Quality Scorecard generation. |
| 8.0 | Cooperative memo stress test | `prompts/80-downstream-stress-test.md` | Cooperative memo stress test. |
| 8.5 | Adversarial register/unresolved-item stress test | `prompts/85-adversarial-red-team.md` | Adversarial register/unresolved-item stress test. |

## 4. The Six Rules

1. **Source-Constrained Specificity** — Never request detail without naming the source type
2. **Zero Tolerance for Fabrication** — Verified or removed. Never flagged, never hedged.
3. **Builder Isolation** — Builders never see each other's output
4. **No Self-Grading** — No model judges its own work
5. **No Silent Skipping** — Every phase runs by default. The Lead does NOT skip, shortcut, or conditionally bypass any phase on its own judgment. Any "skip if…" heuristic in the orchestrator is a flag to pause, surface the proposal to the user, and wait for explicit approval. The user's priority is quality and zero errors — not speed or cost. See 01-shared-axioms.md Rule 17.
6. **Model-Family Separation** — Generation and verification of the same content must use different model families. The Lead and both builders are different families from each other. Critique, fact-check, audit, and stress-test phases use a different family from whoever produced the content being checked. Document the model used at every phase. See 01-shared-axioms.md Section 4 for separation requirements per phase.

### Rule 2 note for v3

The Six Rules are preserved verbatim. In v3, "Verified or removed" means a claim either becomes verified authority, is removed, or is explicitly preserved as unresolved with `[UNVERIFIED]` / `[NEEDS-VERIFICATION]` and routed to the required manifests. Silent hedging is still prohibited.

## 5. What's new in v3

- **Memo Drafting Framework spinoff.** The embedded Grounded Memo Drafter became sibling `Memo Drafting Framework v1` with its own HOW-TO, axioms, corpus contract, prompts, and script ownership.
- **Monotonic phase renumbering.** v2 inserted labels are replaced by 0.0, 0.1, 0.2, 1.1, 1.2, 1.3, 2.0, 3.0, 4.0, 5.1-5.5, 6.0-6.5, 7.0, 8.0, and 8.5.
- **Prompt consolidation.** The execution prompt set is consolidated into 24 final prompt files, including merged Lead review and merged extraction/filename validation.
- **Crawl4AI default-on.** Grounding is default-on for Phase 5.2 citation verification and Phase 6.4 post-assembly fact-check; opt-out must be logged.
- **Verbatim-Linter mainline.** `Verbatim-Linter.ps1` is a root script used by Phase 5.2 and Phase 6.2 for paraphrase-drop and wrong-anchor detection.
- **Three-tier output.** Every v3 KB has `full/`, `practice/`, and `authority/`; `practice/` strips interpretation only, while `authority/` strips guidance and interpretation.
- **Claim reattribution check.** `Detect-Reattribution.ps1` detects memo or claim-map rows that cite the right claim id but characterize the source quote incorrectly.
- **Per-claim volatile refresh cadence.** `[VOLATILE:*]` type, not only KB type or file age, drives refresh cadence and scorecard coverage.
- **Phase 4 inventory validation.** `Validate-Phase4Inventory.ps1` validates the single-source claim inventory schema before Phase 5.4/6.4 consume it.
- **Quality Scorecard subsystem.** `Generate-QualityScorecard.ps1` creates the human scorecard, JSON companion, and history file; methodology may be embedded or separated, and badges are optional support artifacts.
- **KB-type prompt branching.** `prompts/legal/` and `prompts/company/` contain additive overrides for phases 5.1, 5.2, 5.3, 5.5, and 7.0.
- **Cross-KB conflict detector.** `Detect-CrossKBConflicts.ps1` identifies conflicting claims across KBs in a portfolio; advisory, not a ship gate.
- **Version diff.** `Diff-KBVersions.ps1` reports added, removed, changed, and register-reclassified claims between builds.
- **Adversarial Phase 8.5.** `85-adversarial-red-team.md` tests unresolved-item handling, guidance-only entity claims, and guidance-as-rule misuse.
- **Goldeneye/Sonnet rule.** Default Builder B is Sonnet 4.6; Goldeneye is explicit opt-in through Phase 0.0 when reachable.
- **Cost-estimate cleanup.** Old dollar cost estimates were removed from `05-build-orchestrator.md` and replaced with token/capacity guidance.
- **Phase 0.0 model selection.** `00a-model-selection.md`, `Validate-ModelAssignment.ps1`, and `model-presets.yaml` make model assignment explicit and auditable, including Rule 19 opt-outs.
- **v2 to v3 migration.** `Migrate-V2KBtoV3.ps1` mechanically migrates v2-built KBs to v3-derived views, manifests, and scorecards without model calls.

## 6. v2 → v3 cheat sheet

| v2 phase/file | v3 phase | v3 file | Disposition |
|---|---:|---|---|
| NEW | 0.0 Model Selection | `00a-model-selection.md` | New prompt |
| 0 Scoping (`02-info-gather.md`) | 0.1 Scoping | root rulebook `02-info-gather.md` | Preserved outside `prompts/` |
| 0.5 Scoping critique (`00a-rubber-duck-scoping.md`) | 0.2 Scoping critique | `00b-rubber-duck-scoping.md` | Renamed |
| 1a Builder topic research (`02-builder-research.md`) | 1.1 Builder topic research | `11-builder-research.md` | Renamed |
| 1a.5 Topic-list critique (`02a-rubber-duck-topics.md`) | 1.2 Topic-list critique | `12-rubber-duck-topics.md` | Renamed |
| 1b Per-topic drafting (`03-builder-draft.md`) | 1.3 Per-topic drafting | `13-builder-draft.md` | Renamed; Phase 1.5 triage folded in |
| 1.5 Remediation triage | — | `—` | Cut; folded into Phases 1.3 and 2.0 |
| 2a Structural review + 2b Depth review | 2.0 Lead review | `20-lead-review.md` | Merged |
| 3 Builder revision | 3.0 Builder revision | `30-builder-revision.md` | Renamed |
| 3.5 Compliance diff | 4.0 Section 7 | `40-lead-comparison.md` | Folded into comparison |
| 4 Lead comparison | 4.0 Lead comparison + inventory + compliance | `40-lead-comparison.md` | Renamed + expanded |
| 5a Currency | 5.1 Currency | `51-factcheck-currency.md` | Renamed + operative-hook check |
| 5b Citations | 5.2 Citations | `52-factcheck-citations.md` | Renamed + grounding default-on + Verbatim-Linter |
| 5c Classification | 5.3 Classification | `53-factcheck-classification.md` | Renamed |
| 5d Single-source | 5.4 Single-source | `54-factcheck-single-source.md` | Renamed |
| 5e Operative claims | 5.5 Operative claims + xref reconciliation | `55-factcheck-operative-claims.md` | Renamed |
| 6 Lead assembly | 6.0 Lead assembly | `60-lead-assembly.md` | Renamed + manifests/tag preservation |
| 6.25 Assembly critique | 6.1 Assembly critique | `61-rubber-duck-assembly.md` | Renamed |
| 11c Register lint | 6.2 Register lint | `62-register-lint.md` | Renamed + root scan + Verbatim-Linter |
| 6c Authority extraction + 6a Filename validation | 6.3 Three-tier extraction + filename validation | `63-extraction-and-filename-validation.md` | Merged |
| 6b Post-assembly fact-check | 6.4 Post-assembly fact-check | `64-post-assembly-factcheck.md` | Renamed + validation + grounding default-on |
| 6.5 Quality tier audit | 6.5 Quality tier audit + deepening | `65-quality-tier-audit.md` | New dedicated prompt |
| 7 Final audit | 7.0 Final audit + Quality Scorecard | `70-final-audit.md` | New dedicated prompt |
| 8 Downstream stress test | 8.0 Downstream stress test | `80-downstream-stress-test.md` | Renamed + Memo Framework integration |
| NEW | 8.5 Adversarial red-team stress test | `85-adversarial-red-team.md` | New prompt |


## 7. Model selection (Phase 0.0)

Phase 0.0 runs before scoping and after host selection. The Lead loads `model-registry.example.yaml` or the operator's local `model-registry.yaml`, then loads `audit-templates/model-presets.yaml`. Presets and custom assignments use registry handles, not raw model IDs; `Validate-ModelAssignment.ps1` resolves each handle and reads family from the registry entry.

The operator may pick a preset, assign custom per-role handles, discover models from a provider and add registry entries, or ask `Recommend-Models.ps1` for role-by-role recommendations. If validation reports a Rule 19 conflict, choose replacement handles or acknowledge the conflict with a rationale. Unknown/unreachable handles block until replaced or added to the registry. Acknowledged opt-outs are logged in `pipeline_state.md` and surfaced in the scorecard.

## 8. Audit and Quality Scorecard

Phase 7.0 produces `sources/audit_report.md` plus a provisional `audit/kb-quality-scorecard.md`, `audit/kb-quality.json`, and `audit/kb-quality-history.json`. After Phase 8.0 and 8.5, regenerate the scorecard for the final shipping verdict. Badge and separate methodology files are optional support artifacts, not required script outputs. The scorecard dimensions are citation density/primary-source rate, register/extraction integrity, cross-reference fidelity, qualifier preservation, volatile-tag coverage, stress-test pass rate, and structural/size compliance. Verdicts are PASS, PASS-WITH-CAVEATS, CONDITIONAL, FAIL, and BUILD-INCOMPLETE. A prose audit without scorecard artifacts is not Phase 7.0-complete.

## 9. Migration from v2

Use `Migrate-V2KBtoV3.ps1` when a v2 KB is still useful and you want v3 views/manifests/scorecards without a model rebuild. Rebuild from scratch when the v2 KB is stale, thin, source-poor, structurally inconsistent, or materially rescoped. Migration is opt-in and does not create missing verification history.

## 10. Host-contract dispatch default

When a host is acting as Lead, it dispatches Builder A, Builder B, critics, fact-checkers, auditors, and memo reviewers through the mechanism documented in `HOST-CONTRACT.md` and the active `hosts/<host-name>/HOST-NOTES.md`, using the Phase 0.0 `model_assignment`. L1a parallel, per-sub-agent model selection is the default. If the active host is L1b, L2, or L3, record the degradation and use the Rule 19 path required for that capability level.

## 11. Working with the Memo Drafting Framework

KB v3 Phase 8.0 invokes `..\Memo Drafting Framework v1 + Provider Registry\` through `02-corpus-contract.md`. For each memo, the Lead should create a corpus packet directory containing `authority\` plus `index.md`, `table-of-authorities.md`, and `qualifier-registry.md` if present, and pass that packet as `source_corpus_path`. For each stress-test memo, KB v3 supplies the authority corpus, memo topic, working directory, memo label, model assignment, and qualifier registry path. The Memo Framework returns a claims manifest, memo, leakage report, reattribution report, qualifier-preservation report, and summary JSON.

Use the Memo Framework standalone when you need a memo from any defined corpus outside a KB build. Start with `Memo Drafting Framework v1 + Provider Registry\HOW-TO-USE.md`. Ship only when leakage = CLEAN, reattribution = CLEAN, and qualifier preservation = PASS.

## 12. Common operator failure modes

| Failure mode | Why it matters | Correct response |
|---|---|---|
| Silent skipping | Missing phases make later clean artifacts misleading. | Stop, log proposed skip/rationale/risk, get explicit approval, record compensating controls. |
| No acknowledged Rule 19 opt-out | Same-family verification becomes hidden self-grading. | Run validation; acknowledge with rationale or choose different models. |
| Paraphrasing volatile-tagged claims at assembly time | Refresh hook gets detached from the claim that moves. | Preserve `[VOLATILE:*]` adjacent to the claim and list it in `sources/volatile_tag_manifest.md`. |
| Stripping `[UNVERIFIED]` during assembly | Uncertainty becomes false authority. | Preserve or verify; unresolved items go to `sources/unresolved_unverified_manifest.md`. |
| Treating `practice/` as cite-safe authority | Practice retains guidance. | Use `authority/` for cite-bearing deliverables and stress tests. |
| Treating a migrated v2 scorecard as a full v3 build | Migration cannot invent missing verification history. | Use caveats to decide whether to rebuild. |
| Forgetting to regenerate derived views after `full/` edits | `practice/`/`authority/` drift. | Re-run Phase 6.3 after every `full/` edit. |


## 13. Detailed operator walkthrough

### 13.1 Before opening the Lead prompt

Create or identify the target KB root. Decide whether this is a new v3 build, a v2 migration, or an in-flight v2 build that should stay on v2. Confirm the operator has access to at least two model families for ordinary builds and three families for the cleanest high-stakes legal/regulatory build. If the environment is constrained to one family, do not improvise; use the Phase 0.0 single-family preset and document the opt-out.

### 13.2 Phase 0.0 and 0.1 practical flow

The Lead first runs `00a-model-selection.md`, writes `sources/model_assignment_candidate.yaml`, and validates it. Only after the model assignment is recorded should the Lead run `02-info-gather.md` for scoping. The scoping report should be concrete enough that a builder can start without asking follow-up questions: KB type, audience, use case, source hierarchy, jurisdiction/time boundaries, topic candidates, known anchors, known controversies, and Tier A/B density by topic.

### 13.3 Human gates

v3 preserves human gates where they matter most. The operator should expect to review the topic list after Phase 1.2, the comparison report after Phase 4.0, and the final audit/scorecard before stress testing. A human gate is not a permission slip to skip later phases; it is an opportunity to prevent the build from optimizing around the wrong scope.

### 13.4 Running parallel phases

Builder research, per-topic drafting, builder revision, the Phase 5 fact-check cluster, and stress-test memos can run in parallel. Parallelism does not relax artifact requirements. Each sub-agent writes its own output, and the Lead records the model/family used. If a parallel agent fails or returns a malformed artifact, rerun that sub-agent or return to the prior phase; do not fill the gap from memory.

### 13.5 Capability-level degradation

The Quality Scorecard records the active host name, declared and observed capability level, unavailable capabilities, affected phases, and whether Rule 19 was fully enforced, sequentially enforced, or not enforced. L1b is parallel same-family work and does not satisfy cross-family independence without a workaround. L2 can preserve quality through sequential family separation, with runtime degradation. L3 cannot enforce Rule 19 for generation-plus-verification and must produce a `CONDITIONAL` methodology disclosure.

### 13.6 After any correction

Any correction to `full/` after assembly triggers a cascade. Re-run Phase 6.2 if register or verbatim fidelity could be affected, Phase 6.3 always, Phase 6.4 for changed claims, Phase 6.5 if size/deepening changed, and Phase 7.0 scorecard generation before relying on the KB. If the correction affects a stress-test memo, rerun that memo through the Memo Framework end-to-end.

## 14. Scorecard interpretation examples

| Scenario | Likely verdict | Operator action |
|---|---|---|
| Composite 94, all dimensions above threshold, stress-test 100% | PASS | Ship for scoped audience; preserve scorecard. |
| Composite 87, qualifier preservation 74 with no stress-test errors | PASS-WITH-CAVEATS or CONDITIONAL depending threshold delta | Surface caveat in `AGENTS.md`; fix qualifier findings if legal/regulatory. |
| Composite 91, stress-test 83% | CONDITIONAL or FAIL | Stress-test failures are not cosmetic; trace memo errors back to KB source. |
| BUILD-INCOMPLETE from missing `volatile_tag_manifest.md` on migrated KB | BUILD-INCOMPLETE | Run migration synthesis or rebuild; do not treat as full v3 score. |
| PASS with `verification-independence-degraded` tags | PASS with methodology caveat | Human reviewer decides whether acknowledged Rule 19 opt-out is acceptable. |

The scorecard is mechanical evidence, not a replacement for judgment. A PASS score means the framework's required evidence is present and above thresholds. It does not mean every possible downstream question is safe without reading the relevant source sections.

## 15. Migration decision tree

1. **Is the KB currently mid-build under v2?** If yes, finish under v2 unless the operator explicitly opts into migration.
2. **Is the v2 KB substantively current and useful?** If no, rebuild under v3.
3. **Does it have recognizable `full/`, root files, and source/audit trail?** If no, rebuild or manually normalize before migration.
4. **Is the goal to add `practice/`, regenerated `authority/`, manifests, and scorecard without model calls?** If yes, run `Migrate-V2KBtoV3.ps1`.
5. **Does migration produce major BUILD-INCOMPLETE caveats?** If yes, use the caveats as a rebuild plan.
6. **Did the scorecard pass but reveal weak dimensions?** Treat weak dimensions as patch targets before relying on the KB for high-stakes drafting.

## 16. Memo Framework standalone quick reference

Use the Memo Drafting Framework outside KB v3 when you have a defined source corpus and need a memo with operative claims. Provide `source_corpus_path`, `memo_topic`, `working_dir`, `memo_label`, `model_assignment`, and optional `qualifier_registry_path`. Run the four steps in order: Claim Extractor, Memo Writer, Mechanical Leakage/Reattribution Audit, and Qualifier-Preservation Review. Do not let the writer read the corpus directly; the writer gets only the claim manifest. Do not ship unless Step 3 is CLEAN and Step 4 is PASS.

## 17. What not to do

- Do not start at a fact-check prompt because the scope seems obvious.
- Do not let Builder B read Builder A's topic list or drafts before the Lead-mediated revision point.
- Do not treat the single-family preset as a convenience default; it is an explicit exception path.
- Do not manually edit `authority/` or `practice/`; edit `full/` and regenerate.
- Do not use `practice/` for cite-bearing memo claims.
- Do not remove `[UNVERIFIED]` or `[VOLATILE:*]` because it makes the prose cleaner.
- Do not mark a blocked source as absent until the primary-source fallback chain has been attempted and logged.
- Do not call Phase 7.0 complete until the scorecard and JSON companion exist.
- Do not call Phase 8.0 complete until the Memo Framework outputs and independent fact-check reports exist for every memo.
- Do not treat Phase 8.0 as the final ship gate; v3 adds Phase 8.5.

## 18. Minimal file checklist before ship

At minimum, a shippable v3 KB has:

```text
AGENTS.md
index.md
table-of-authorities.md
full\*.md
practice\*.md
authority\*.md
sources\host_assignment.md
sources\pipeline_state.md
sources\scoping_report.md
sources\comparison_report.md
sources\factcheck_*.md
sources\new_claims_manifest.md
sources\unresolved_unverified_manifest.md
sources\volatile_tag_manifest.md
sources\register_lint_report.md
sources\practice_view_extraction.md
sources\authority_view_extraction.md
sources\filename_validation.md
sources\post_assembly_factcheck.md
sources\quality_tier_audit.md
sources\audit_report.md
sources\stress_test_memos_index.md
sources\adversarial_stress_test_report.md
audit\kb-quality-scorecard.md
audit\kb-quality.json
audit\kb-quality-history.json
sources\model_assignment_candidate.yaml
sources\model_assignment_validation.md
sources\verbatim_lint_report.md
sources\build_manifest.md
```

The exact fact-check filenames may vary by local convention, but the artifacts must be present and traceable from `pipeline_state.md`. This checklist is a minimum operator checklist; the technical specification remains the controlling conformance list.

## 18.1 Recreating v3.1 from scratch (separate LLM)

The complete LLM recreation prompt lives at `specification\llm-recreation-prompt-v3.1.0.md` alongside the normative spec. Paste it into a fresh frontier-LLM session with file-write capability to produce a conformant rebuild of both KB Creation - Modular v3.1 and Memo Drafting Framework v1 + Provider Registry in a target root directory. The companion `specification\technical-specification-v3.1.0.md` is the authoritative reference for invariants, the Six Rules, and the register grammar.


## 19. Operator command snippets

These snippets are examples; substitute real framework and KB paths.

### 19.1 Validate a model assignment

```powershell
& "C:\...\KB Creation - Modular v3 + OpenCode and OpenRouter\Validate-ModelAssignment.ps1" `
  -AssignmentPath "C:\...\My KB\sources\model_assignment_candidate.yaml" `
  -OutPath "C:\...\My KB\sources\model_assignment_validation.md"
```

If the only findings are Rule 19 conflicts and you choose to proceed:

```powershell
& "C:\...\KB Creation - Modular v3 + OpenCode and OpenRouter\Validate-ModelAssignment.ps1" `
  -AssignmentPath "C:\...\My KB\sources\model_assignment_candidate.yaml" `
  -OutPath "C:\...\My KB\sources\model_assignment_validation.md" `
  -Acknowledge
```

### 19.2 Regenerate derived views

```powershell
& "C:\...\KB Creation - Modular v3 + OpenCode and OpenRouter\Extract-PracticeView.ps1" -KBRoot "C:\...\My KB"
& "C:\...\KB Creation - Modular v3 + OpenCode and OpenRouter\Extract-AuthorityView.ps1" -KBRoot "C:\...\My KB"
```

Run these after every `full/` edit. Do not edit `practice/` or `authority/` directly.

### 19.3 Generate the Quality Scorecard

```powershell
& "C:\...\KB Creation - Modular v3 + OpenCode and OpenRouter\Generate-QualityScorecard.ps1" -KBRoot "C:\...\My KB"
```

If a custom weights file is approved for the build:

```powershell
& "C:\...\KB Creation - Modular v3 + OpenCode and OpenRouter\Generate-QualityScorecard.ps1" `
  -KBRoot "C:\...\My KB" `
  -WeightsPath "C:\...\KB Creation - Modular v3 + OpenCode and OpenRouter\audit-templates\kb-quality-dimensions.yaml"
```

### 19.4 Migrate a v2 KB

```powershell
& "C:\...\KB Creation - Modular v3 + OpenCode and OpenRouter\Migrate-V2KBtoV3.ps1" -KBRoot "C:\...\Existing v2 KB"
```

Use `-DryRun` first when you are unsure what the script will touch. Use `-Force` only after reviewing existing v3 artifacts that would be overwritten.

## 20. Reading generated reports

| Report | What to look for first | Common next action |
|---|---|---|
| `model_assignment_validation.md` | BLOCK vs PASS/WARN; exact Rule 19 conflicts. | Replace model or acknowledge with rationale. |
| `comparison_report.md` | Single-source high-risk claims and revision-compliance misses. | Validate inventory; route high-risk claims to Phase 5.4/5.5. |
| `factcheck_citations.md` | Unsupported or wrong-document citations. | Remove or correct; rerun affected checks. |
| `factcheck_operative_claims.md` | Dropped qualifiers, wrong clocks, cross-reference drift. | Fix canonical and cross-reference statements. |
| `register_lint_report.md` | Untagged guidance language in `full/` or root files. | Retag as GUIDANCE/INTERPRETATION or rewrite as authority. |
| `practice_view_extraction.md` | Missing peers, low retention, stripped interpretation count. | Fix extraction blockers or review over-tagging. |
| `authority_view_extraction.md` | Guidance/interpretation leakage and retention ratio. | Fix tags; rerun extraction. |
| `post_assembly_factcheck.md` | Assembly-added claims that bypassed Phase 5. | Verify, remove, or route to correction. |
| `kb-quality-scorecard.md` | Overall verdict, weakest dimensions, open items. | Decide ship/caveat/remediate/rebuild. |
| `adversarial_stress_test_report.md` | Any attack FAIL. | Harden tags/index/prompts and rerun relevant phases. |

## 21. When to stop and escalate

Stop the build and surface the issue to the operator when: a selected model is unreachable and no validated replacement exists; a Rule 19 conflict has not been acknowledged; Phase 4 inventory is missing or malformed; a fact-check phase reports systemic citation or operative-claim failure; extraction scripts report inline-position tags or missing peers; the scorecard is FAIL; a stress-test memo leaks unsupported specifics; or Phase 8.5 produces an adversarial FAIL. In each case, the next step is remediation or explicit operator decision, not continuing the pipeline optimistically.

## 22. Operator mental model

Think of v3 as three nested safety loops. The first loop builds content through independent builders and Lead comparison. The second loop verifies content through fact-checkers, lints, extraction, and audit. The third loop tests downstream use through memo drafting and adversarial red-team prompts. The KB is not shippable because the prose looks polished; it is shippable only when all three loops leave persistent artifacts showing what was checked, by whom, with which model family, and what happened to every material finding.
