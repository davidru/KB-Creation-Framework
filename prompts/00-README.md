# Execution Prompts — KB Creation Framework v3.0

**Version:** 3.0-pre | **Date:** 2026-06-06  
**Parent modules:** `03-builder.md`, `04-fact-checker.md`, `05-build-orchestrator.md`, `07-audit-system.md`

## Purpose

These are the copy-paste execution prompts for each step of the KB Creation Framework v3 build pipeline. The parent modules define the rules, anti-patterns, and architecture. These prompts are what you feed to each model session or use as the operator checklist.

## Prompt Inventory (Execution Order)

| File | Phase | Role | Purpose |
|---|---:|---|---|
| `00-README.md` | index | Operator | Prompt inventory, sequencing, v2→v3 mapping |
| `00a-model-selection.md` | 0.0 | Lead facilitator | Select and validate per-build model assignment |
| `00b-rubber-duck-scoping.md` | 0.2 | Independent critic | Pressure-test scoping report |
| `01-orchestrator.md` | all | Lead | Coordinate the full pipeline and gates |
| `11-builder-research.md` | 1.1 | Builder A/B | Independent topic research and proposed structure |
| `12-rubber-duck-topics.md` | 1.2 | Independent critic | Pressure-test merged topic list |
| `13-builder-draft.md` | 1.3 | Builder A/B | Per-topic drafting |
| `20-lead-review.md` | 2.0 | Lead | Combined structural + depth review |
| `30-builder-revision.md` | 3.0 | Builder A/B | Revise v1 drafts from Lead review |
| `40-lead-comparison.md` | 4.0 | Lead | Compare v2 drafts, inventory single-source claims, check revision compliance |
| `51-factcheck-currency.md` | 5.1 | Fact-checker | Verify currency and operative-hook characterization |
| `52-factcheck-citations.md` | 5.2 | Fact-checker | Verify citations with grounding default-on + Verbatim-Linter |
| `53-factcheck-classification.md` | 5.3 | Fact-checker | Verify classifications and categories |
| `54-factcheck-single-source.md` | 5.4 | Independent fact-checker | Verify Phase 4.0 single-source inventory |
| `55-factcheck-operative-claims.md` | 5.5 | Independent fact-checker | Verify operative mechanisms and cross-reference fidelity |
| `60-lead-assembly.md` | 6.0 | Lead | Assemble final KB and required manifests |
| `61-rubber-duck-assembly.md` | 6.1 | Independent critic | Pressure-test assembled KB |
| `62-register-lint.md` | 6.2 | Script + Lead | Run Register-Lint + Verbatim-Linter and disposition findings |
| `63-extraction-and-filename-validation.md` | 6.3 | Scripts + Lead | Extract `practice/` and `authority/`, then validate structure and filenames |
| `64-post-assembly-factcheck.md` | 6.4 | Independent fact-checker | Superset fact-check of assembled `full/` |
| `65-quality-tier-audit.md` | 6.5 | Lead | A/B/C quality tier classification and mandatory deepening |
| `70-final-audit.md` | 7.0 | Auditor | Final audit and Quality Scorecard generation |
| `80-downstream-stress-test.md` | 8.0 | Memo Framework + fact-checkers | Cooperative memo stress test |
| `85-adversarial-red-team.md` | 8.5 | Red-team agents | Adversarial register/unresolved-item stress test |

KB-type override directories: `prompts/legal/` and `prompts/company/` contain additive overrides for the five phases that meaningfully diverge by KB type (5.1, 5.2, 5.3, 5.5, and 7.0). The common prompt remains authoritative; the orchestrator reads an override after the common prompt when `scoping_report.md` sets `kb_type: legal_topic` or `kb_type: company`.

## Sequencing

```text
01-orchestrator.md
  │
  ├─► 00a-model-selection.md          Phase 0.0  (writes model_assignment)
  ├─► 02-info-gather.md               Phase 0.1  (root rulebook; writes scoping_report)
  ├─► 00b-rubber-duck-scoping.md      Phase 0.2
  │
  ├─► 11-builder-research.md          Phase 1.1  (Builder A/B parallel)
  ├─► 12-rubber-duck-topics.md        Phase 1.2
  ├─► 13-builder-draft.md             Phase 1.3  (per topic, parallel)
  │
  ├─► 20-lead-review.md               Phase 2.0  (per builder)
  ├─► 30-builder-revision.md          Phase 3.0  (Builder A/B parallel)
  ├─► 40-lead-comparison.md           Phase 4.0  (+ Section 6 inventory + Section 7 compliance)
  │
  ├─► 51-factcheck-currency.md        Phase 5.1 ┐
  ├─► 52-factcheck-citations.md       Phase 5.2 │  parallel fact-check cluster
  ├─► 53-factcheck-classification.md  Phase 5.3 │
  ├─► 54-factcheck-single-source.md   Phase 5.4 │
  └─► 55-factcheck-operative-claims.md Phase 5.5┘
  │
  ├─► 60-lead-assembly.md             Phase 6.0
  ├─► 61-rubber-duck-assembly.md      Phase 6.1
  ├─► 62-register-lint.md             Phase 6.2
  ├─► 63-extraction-and-filename-validation.md Phase 6.3
  ├─► 64-post-assembly-factcheck.md   Phase 6.4
  ├─► 65-quality-tier-audit.md        Phase 6.5
  │
  ├─► 70-final-audit.md               Phase 7.0  (+ Generate-QualityScorecard.ps1)
  ├─► 80-downstream-stress-test.md    Phase 8.0  (Memo Drafting Framework)
  └─► 85-adversarial-red-team.md      Phase 8.5
```

## v2 → v3 Phase Mapping

| v2 phase/file | v3 phase | v3 file | Disposition |
|---|---:|---|---|
| NEW | 0.0 Model Selection | `00a-model-selection.md` | New prompt |
| 0 Scoping (`02-info-gather.md`) | 0.1 Scoping | root rulebook `02-info-gather.md` | Preserved outside `prompts/` |
| 0.5 Scoping critique (`00a-rubber-duck-scoping.md`) | 0.2 Scoping critique | `00b-rubber-duck-scoping.md` | Renamed |
| 1a Builder topic research (`02-builder-research.md`) | 1.1 Builder topic research | `11-builder-research.md` | Renamed |
| 1a.5 Topic-list critique (`02a-rubber-duck-topics.md`) | 1.2 Topic-list critique | `12-rubber-duck-topics.md` | Renamed |
| 1b Per-topic drafting (`03-builder-draft.md`) | 1.3 Per-topic drafting | `13-builder-draft.md` | Renamed; Phase 1.5 triage discipline folded in |
| 1.5 Remediation triage | — | — | Cut; folded into Phases 1.3 and 2.0 |
| 2a Structural review (`04-lead-review-structure.md`) + 2b Depth review (`05-lead-review-depth.md`) | 2.0 Lead review | `20-lead-review.md` | Merged |
| 3 Builder revision (`06-builder-revision.md`) | 3.0 Builder revision | `30-builder-revision.md` | Renamed |
| 3.5 Compliance diff (`06a-revision-compliance.md`) | 4.0 Section 7 | `40-lead-comparison.md` | Folded into comparison |
| 4 Lead comparison (`07-lead-comparison.md`) | 4.0 Lead comparison + inventory + compliance | `40-lead-comparison.md` | Renamed + expanded |
| 5a Currency (`08-factcheck-currency.md`) | 5.1 Currency | `51-factcheck-currency.md` | Renamed + operative-hook check |
| 5b Citations (`09-factcheck-citations.md`) | 5.2 Citations | `52-factcheck-citations.md` | Renamed + Crawl4AI default-on + Verbatim-Linter |
| 5c Classification (`10-factcheck-classification.md`) | 5.3 Classification | `53-factcheck-classification.md` | Renamed |
| 5d Single-source (`09a-factcheck-single-source.md`) | 5.4 Single-source | `54-factcheck-single-source.md` | Renamed |
| 5e Operative claims (`09b-factcheck-operative-claims.md`) | 5.5 Operative claims + cross-reference reconciliation | `55-factcheck-operative-claims.md` | Renamed |
| 6 Lead assembly (`11-lead-assembly.md`) | 6.0 Lead assembly | `60-lead-assembly.md` | Renamed + manifests/tag preservation |
| 6.25 Assembly critique (`11b-rubber-duck-assembly.md`) | 6.1 Assembly critique | `61-rubber-duck-assembly.md` | Renamed |
| 11c Register lint (`11c-register-lint.md`) | 6.2 Register lint | `62-register-lint.md` | Renamed + root scan + Verbatim-Linter |
| 6c Authority extraction (`11a-authority-view-extraction.md`) + 6a Filename validation (`12-filename-validation.md`) | 6.3 Three-tier extraction + filename validation | `63-extraction-and-filename-validation.md` | Merged |
| 6b Post-assembly fact-check (`13-post-assembly-factcheck.md`) | 6.4 Post-assembly fact-check | `64-post-assembly-factcheck.md` | Renamed + Phase 4.0 inventory validation + grounding default-on |
| 6.5 Quality tier audit | 6.5 Quality tier audit + deepening | `65-quality-tier-audit.md` | New dedicated prompt |
| 7 Final audit (v2 `04-fact-checker.md` Mode 2) | 7.0 Final audit + Quality Scorecard | `70-final-audit.md` | New dedicated prompt |
| 8 Downstream stress test (`14-downstream-stress-test.md`) | 8.0 Downstream stress test | `80-downstream-stress-test.md` | Renamed + Memo Drafting Framework integration |
| NEW | 8.5 Adversarial red-team stress test | `85-adversarial-red-team.md` | New prompt |

## Universal Principles (from `01-shared-axioms.md`)

These six rules apply to EVERY prompt:

1. **Source-Constrained Specificity** — Never request detail without naming the source type
2. **Zero Tolerance for Fabrication** — Verified or removed. Never flagged, never hedged.
3. **Builder Isolation** — Builders never see each other's output
4. **No Self-Grading** — No model judges its own work
5. **No Silent Skipping** — Every phase runs by default. The Lead does NOT skip, shortcut, or conditionally bypass any phase on its own judgment. Any "skip if…" heuristic in the orchestrator is a flag to pause, surface the proposal to the user, and wait for explicit approval. The user's priority is quality and zero errors — not speed or cost. See 01-shared-axioms.md Rule 17.
6. **Model-Family Separation** — Generation and verification of the same content must use different model families. The Lead and both builders are different families from each other. Critique, fact-check, audit, and stress-test phases use a different family from whoever produced the content being checked. Document the model used at every phase. See 01-shared-axioms.md Section 4 for separation requirements per phase.

## Required Mechanical Tools

| Tool | Used by | Purpose |
|---|---|---|
| `Validate-ModelAssignment.ps1` | Phase 0.0 | Validate model assignment and Rule 19 opt-outs |
| `Validate-Phase4Inventory.ps1` | Phase 4.0 / 6.4 preflight | Validate single-source claim inventory schema |
| `Register-Lint.ps1 -IncludeRootFiles` | Phase 6.2 | Scan `full/` and root files for untagged guidance signals |
| `Verbatim-Linter.ps1` | Phases 5.2 and 6.2 | Mechanical paraphrase-drop / wrong-anchor detection |
| `Extract-PracticeView.ps1` | Phase 6.3 | Generate `practice/` from `full/` |
| `Extract-AuthorityView.ps1` | Phase 6.3 | Generate `authority/` from `full/` |
| `Generate-QualityScorecard.ps1` | Phase 7.0 | Generate `audit/kb-quality-scorecard.md` and JSON companions |

## Optional Adapters Now Default-On Where Applicable

The Crawl4AI grounding adapter (`adapters/crawl4ai-fetch/`) is **default-on** for Phase 5.2 citation verification and Phase 6.4 post-assembly superset fact-check. Opt-out is permitted only with an explicit rationale captured in `sources/scoping_report.md` and `sources/pipeline_state.md`; the Quality Scorecard surfaces the opt-out.

## KB-Type Overrides

`prompts/legal/` and `prompts/company/` provide additive KB-type overrides for Phase 5.1, 5.2, 5.3, 5.5, and 7.0. Read the common prompt first, then the matching override when `scoping_report.md` sets `kb_type: legal_topic` or `kb_type: company`; if no matching override exists, use the common prompt as-is.
