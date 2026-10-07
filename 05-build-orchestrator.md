# Build Orchestrator — KB Creation Framework
# Version: 1.0 | Created: 2026-04-09
# Scope: Manages the build pipeline for new or rebuilt KBs. Project-based — starts and ends.
# Dependencies: Reads 01-shared-axioms.md. Invokes 02-info-gather, 03-builder, 04-fact-checker.
# Independence: Can operate as a standalone runbook for anyone picking up a build mid-stream.

---

## PURPOSE

This module manages the end-to-end KB creation pipeline. It handles:

- Pipeline sequencing and handoff between modules
- Decision logic (rebuild vs. patch, which builder is backbone, ship vs. reject)
- Concurrency management
- Failure handling and retries
- Progress tracking
- Session handoff (so a fresh agent can pick up mid-pipeline)

It is the only module that knows about all the others. The other modules are self-contained.

---

## SECTION 1: PIPELINE SEQUENCE

### Standard Build (New KB)

```
Phase 0.0: MODEL SELECTION
  → Prompt: prompts/00a-model-selection.md
  → Output: model_assignment block in sources/scoping_report.md and sources/pipeline_state.md
  → Mechanical gate: Validate-ModelAssignment.ps1
  → Decision: PASS proceeds; Rule 19 WARN requires acknowledged opt-out + rationale; unreachable model FAIL blocks.

Phase 0.1: INFO GATHER / SCOPING
  → Input: User request + model_assignment
  → Output: sources/scoping_report.md, including audience_fit matrix
  → Decision: Is scope clear? If no, ask user before builders run.

Phase 0.2: RUBBER-DUCK SCOPING CRITIQUE
  → Prompt: prompts/00b-rubber-duck-scoping.md
  → Output: sources/scoping_critique.md + applied scoping fixes
  → Launch: Independent critic from the assigned critic_pool

Phase 1.1: BUILDER TOPIC RESEARCH
  → Prompt: prompts/11-builder-research.md
  → Input: scoping_report.md + shared-axioms.md
  → Output: independent topic research / proposed structure from Builder A and Builder B
  → Launch: Both builders in parallel per model_assignment

Phase 1.2: RUBBER-DUCK TOPIC-LIST CRITIQUE
  → Prompt: prompts/12-rubber-duck-topics.md
  → Output: topic-list critique and Lead disposition

Phase 1.3: PER-TOPIC BUILDER DRAFTING
  → Prompt: prompts/13-builder-draft.md
  → Output: sources/kb_[model_a].md, sources/kb_[model_b].md
  → Requirement: builders preserve [UNVERIFIED] and [VOLATILE:*] tags

Phase 2.0: LEAD REVIEW
  → Prompt: prompts/20-lead-review.md
  → Output: review_[a].md and review_[b].md

Phase 3.0: BUILDER REVISION
  → Prompt: prompts/30-builder-revision.md
  → Output: sources/kb_[model_a]_v2.md, sources/kb_[model_b]_v2.md
  → Launch: Both builders in parallel

Phase 4.0: LEAD COMPARISON + SINGLE-SOURCE INVENTORY
  → Prompt: prompts/40-lead-comparison.md
  → Output: sources/comparison_report.md with mandatory single-source inventory
  → Mechanical gate: Validate-Phase4Inventory.ps1 validates the inventory schema before Phase 5.4 or 6.4 may rely on it. Missing/malformed inventory BLOCKS; do not reconstruct from builder drafts.

Phase 5.1-5.5: PARALLEL FACT-CHECK CLUSTER
  → 5.1 prompts/51-factcheck-currency.md
  → 5.2 prompts/52-factcheck-citations.md
  → 5.3 prompts/53-factcheck-classification.md
  → 5.4 prompts/54-factcheck-single-source.md (requires validated Phase 4.0 inventory)
  → 5.5 prompts/55-factcheck-operative-claims.md
  → Output: fact-check artifacts and correction queues

Phase 6.0: LEAD ASSEMBLY
  → Prompt: prompts/60-lead-assembly.md
  → Input: revised drafts + comparison + fact-check corrections
  → Output: full/ KB files, root infrastructure, and required manifests (new_claims, unresolved_unverified, volatile tags)

Phase 6.1: RUBBER-DUCK ASSEMBLY CRITIQUE
  → Prompt: prompts/61-rubber-duck-assembly.md
  → Output: assembly critique and Lead disposition

Phase 6.2: REGISTER / VERBATIM LINT
  → Prompt: prompts/62-register-lint.md
  → Scripts: Register-Lint.ps1 -IncludeRootFiles; Verbatim-Linter.ps1
  → Output: sources/register_lint_report.md and linter dispositions

Phase 6.3: EXTRACTION + FILENAME / STRUCTURE VALIDATION
  → Prompt: prompts/63-extraction-and-filename-validation.md
  → Scripts: Extract-PracticeView.ps1; Extract-AuthorityView.ps1
  → Output: practice/, authority/, sources/authority_view_extraction.md, sources/filename_validation.md

Phase 6.4: POST-ASSEMBLY FACT-CHECK
  → Prompt: prompts/64-post-assembly-factcheck.md
  → Preflight gate: Validate-Phase4Inventory.ps1 confirms the Phase 4.0 inventory before the superset check proceeds
  → Output: sources/post_assembly_factcheck.md and in-place corrections
  → If corrections applied to full/: re-run Phase 6.3 to re-sync practice/ and authority/.

Phase 6.5: QUALITY-TIER AUDIT + DEEPENING
  → Prompt: prompts/65-quality-tier-audit.md
  → Output: sources/quality_tier_audit.md and any required deepening

Phase 7.0: FINAL AUDIT + QUALITY SCORECARD
  → Prompt: prompts/70-final-audit.md
  → Script: Generate-QualityScorecard.ps1
  → Output: final audit report, audit/kb-quality-scorecard.md, audit/kb-quality.json, audit/kb-quality-history.json
  → DECISION GATE: Check error rate and Quality Scorecard verdict against thresholds.

Phase 8.0: DOWNSTREAM STRESS TEST
  → Prompt: prompts/80-downstream-stress-test.md
  → Invokes: Memo Drafting Framework v1 with model_assignment passthrough
  → Output: stress-test memo artifacts and reports; KB defects route back to remediation.

Phase 8.5: ADVERSARIAL RED-TEAM
  → Prompt: prompts/85-adversarial-red-team.md
  → Output: adversarial findings; blockers must be fixed before ship.
```

### Rebuild (Existing KB, Failed Audit)

Same as Standard Build, except:
- Phase 0.1 uses the existing KB's index.md and AGENTS.md as scoping input (still verify scope — don't build blind)
- Builders receive the existing KB files as reference (but must generate fresh drafts, not patch)
- The audit report from the failed prior version informs the scoping report's "known controversies" section

### Patch (Existing KB, Minor Corrections)

```
Step 1: Apply corrections from audit report directly to KB files
Step 2: FACT-CHECKER — Correction Verification (Mode 5)
  → Verify only the corrected claims
  → If new errors introduced: escalate to Rebuild
  → If clean: regenerate Quality Scorecard and SHIP
```

---

## SECTION 2: DECISION LOGIC

### Rebuild vs. Patch vs. Ship

| Signal | Action |
|--------|--------|
| Error rate ≤ ship threshold | **Ship** with corrections |
| Error rate > ship but ≤ rebuild threshold | **Patch** + re-audit |
| Error rate > rebuild threshold | **Full rebuild** |
| Size gate failure (any file < 12KB) | **Deepen** then re-assess |
| Structural issues (missing index, no AGENTS.md) | **Patch** — add missing artifacts |
| Scope mismatch (KB covers wrong topics) | **Rebuild** with new scoping report |

### Which Builder Is Backbone?

The Lead's comparison report recommends the backbone. Default heuristics:
- **GPT-5.4 (Builder A) is backbone** in >90% of cases — better sourcing, fewer fabrications
- **Builder B (Claude Sonnet 4.6 by default, or Goldeneye when explicitly selected) is backbone** only when: (a) it has significantly more coverage, AND (b) its factual accuracy is comparable
- When in doubt, use Builder A. The cost of enriching A with B's content is lower than de-fabricating B.

### Ship Decision

The Orchestrator does NOT make the ship decision unilaterally. The decision flow:
1. Fact-Checker produces audit report with error rate
2. Orchestrator checks against thresholds (Shared Axioms Section 5)
3. If within threshold: Orchestrator presents the ship recommendation to the operator with the error-rate evidence + the Quality Scorecard verdict
4. **Operator confirms ship explicitly.** No automated ship path is shipped with v3.1 — every ship requires an explicit operator "yes" in the session. Operators who want automated shipping for low-risk KB types must build that as a separate opt-in subsystem outside the framework (with their own audit trail and risk acceptance); the framework's orchestrator MUST NOT auto-ship.

---

## SECTION 3: CONCURRENCY RULES

| Phase | Max Concurrent Agents | Rationale |
|-------|----------------------|-----------|
| Phase 0.0-0.2 (selection / scoping / scoping critique) | 1 Lead + 1 critic | Operator-interactive and scope-sensitive |
| Phase 1.1 and 1.3 (Builders) | 2 per KB (the two builders) | High context per agent |
| Phase 1.2 and 6.1 (Rubber-duck critiques) | 1 critic per pass | Fresh-context critique |
| Phase 2.0 and 4.0 (Lead review / comparison) | 1 per KB | Full-context read of both drafts |
| Phase 3.0 (Revision) | 2 per KB | Medium context |
| Phase 5.1-5.5 (Fact-check cluster) | 3-5 if model/family capacity allows | Independent, separable verification tracks |
| Phase 6.0 (Assembly) | 1 per KB | Highest context — merging everything |
| Phase 6.2-6.4 (Lint / extraction / post-assembly fact-check) | 1-3 | Scripted gates plus independent verification |
| Phase 6.5 (Quality tier / deepening) | 4-6 files in parallel for deepening | Low context per file |
| Phase 7.0 (Final audit) | 1 auditor | Full KB read |
| Phase 8.0-8.5 (Stress test / red team) | Per memo / red-team scenario | Independent downstream reliance tests |

### Multi-KB Batch Rules

When building multiple KBs simultaneously:
- **Max 6 total agents** across all KBs (validated: 20+ causes persistent rate limiting)
- **Stagger pipeline phases** — don't launch 6 Lead Reviews simultaneously
- **Prefer: 2-3 KBs in Phase 1.1/1.3 while 1 KB is in Phase 6.0** — mix high-concurrent builder work with low-concurrent assembly
- **Monitor rate limits** — if web search starts throttling, reduce concurrency

### Failure Handling

| Failure | Action |
|---------|--------|
| Agent timeout (>30 min) | Relaunch with same prompt |
| File write error (OneDrive sync) | Retry — usually transient |
| Rate limit on web search | Agent self-heals with backoff. If persistent, reduce concurrency |
| Agent produces empty/truncated output | Relaunch. If 2nd failure, switch models |
| Path error (directory moved) | Verify paths, relaunch with corrected paths |

---

## SECTION 4: PROGRESS TRACKING

### Pipeline State File

Maintain `sources/pipeline_state.md` in each KB being built:

```markdown
# Pipeline State — [KB Name]
# Last updated: [timestamp]

## Current Phase: [phase number and name]
## Status: [running / waiting / complete / blocked]

## Phase Log
| Phase | Started | Completed | Agent | Model | Notes |
|-------|---------|-----------|-------|-------|-------|
| 0.0 | [time] | [time] | Lead | Opus 4.7 | model_assignment validated |
| 1.1 | [time] | [time] | [id A/B] | GPT-5.4 / Sonnet 4.6 | topic research complete |
| 4.0 | [time] | [time] | [id] | Opus 4.7 | single-source inventory valid |
| 6.0 | [time] | [pending] | [id] | Opus 4.7 | assembling full/ and manifests |

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Builder B backbone | Lead scored B at 4.7 vs A at 3.4 |
| No deepening needed | All files >18KB, avg 23KB |

## Pending
- [ ] Phase 0.0 model assignment validated (`Validate-ModelAssignment.ps1`)
- [ ] Phase 0.1 scoping report with audience_fit matrix
- [ ] Phase 0.2 scoping critique
- [ ] Phase 1.1 topic research (both builders)
- [ ] Phase 1.2 topic-list critique
- [ ] Phase 1.3 per-topic drafts
- [ ] Phase 2.0 lead review
- [ ] Phase 3.0 revision (both builders)
- [ ] Phase 4.0 comparison + single-source inventory (`Validate-Phase4Inventory.ps1`)
- [ ] Phase 5.1-5.5 fact-check cluster
- [ ] Phase 6.0 assembly + manifests
- [ ] Phase 6.1 assembly critique
- [ ] Phase 6.2 register/verbatim lint
- [ ] Phase 6.3 practice/authority extraction + filename validation
- [ ] Phase 6.4 post-assembly fact-check (re-run 6.3 if full/ edited; revalidate Phase 4.0 inventory first)
- [ ] Phase 6.5 quality tier audit / deepening
- [ ] Phase 7.0 final audit + Quality Scorecard
- [ ] Phase 8.0 downstream stress test
- [ ] Phase 8.5 adversarial red-team

## Blocked
[None / description of blocking issue]
```

### SQL Tracking (for multi-KB orchestration)

When managing multiple KBs, use SQL for queryable state:

```sql
CREATE TABLE kb_pipeline (
  kb_name TEXT PRIMARY KEY,
  kb_type TEXT,           -- company / legal_topic / litigation
  current_phase TEXT,
  status TEXT,            -- running / complete / blocked / ship / rebuild
  error_rate REAL,
  builder_a_size REAL,
  builder_b_size REAL,
  assembled_size REAL,
  started_at TEXT,
  completed_at TEXT
);
```

---

## SECTION 5: SESSION HANDOFF

When a session ends or a new agent picks up a build:

### What the New Agent Needs

1. **This module** (for pipeline logic)
2. **Shared Axioms** (for principles and standards)
3. **The KB's `sources/pipeline_state.md`** (for current progress)
4. **The KB directory** (to read existing artifacts)

### Handoff Checklist

Before ending a session with active builds:
- [ ] Update pipeline_state.md for every active KB
- [ ] Note all running agent IDs and what they're doing
- [ ] Record any decisions made and their rationale
- [ ] List what the next agent should do first

### Resumption Protocol

When picking up a build mid-stream:
1. Read pipeline_state.md
2. Check which artifacts exist in sources/
3. Determine current phase from artifact inventory:
   - No `model_assignment` in pipeline_state.md → Phase 0.0 needed
   - Builder topic research missing → Phase 1.1 needed
   - Builder drafts exist but no lead review → Phase 2.0 needed
   - Revised drafts exist but no comparison report / single-source inventory → Phase 4.0 needed
   - Comparison exists but `Validate-Phase4Inventory.ps1` fails → remediate Phase 4.0 before fact-check
   - Fact-check artifacts incomplete → Phase 5.1-5.5 needed
   - Assembled files exist but no required manifests → Phase 6.0 remediation needed
   - full/ changed after extraction → re-run Phase 6.3
   - No Quality Scorecard → Phase 7.0 needed
4. Continue from the current phase

---

## SECTION 6: COST ESTIMATION

Cost estimation depends on current model pricing, which moves faster than this rulebook's release cadence. For up-to-date cost figures, operators should multiply estimated per-phase token counts (documented per prompt at the top of each `prompts/*.md` file) by the operator's current model pricing. Per-build token estimate ranges: scoping + topic research ~50K-200K tokens; per-topic drafting ~30K-80K per builder per topic; assembly ~100K-300K; fact-check phases ~50K-150K each; stress-test ~30K-80K per memo. A 14-topic KB end-to-end is in the low millions of tokens total.

---

*This module orchestrates KB builds. It knows the pipeline, manages concurrency, tracks progress, and makes threshold-based decisions. It invokes Info Gather, Builder, and Fact-Checker but does not do their work.*
