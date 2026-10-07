# Audit System — KB Creation Framework v3

## PURPOSE

The audit subsystem exists to produce a single rolled-up artifact that a reviewer can read in five minutes to decide whether a KB is fit for downstream use. It serves three audiences at once: operators building the KB need phase-level diagnostics, reviewers evaluating the finished KB need a human-readable quality scorecard, and downstream consumers choosing whether to rely on the KB need a machine-readable verdict and badge. The audit subsystem does not replace source verification or human judgment; it collects the mechanical evidence those judgments rely on.

---

## SECTION 1: WHAT'S NEW IN V3

v3 reorganizes the audit system around the **KB Quality Scorecard** as the headline deliverable. The v2 per-KB audit trail (`verification_log.md`, `audit_trail.md`) is preserved. The framework-level master audit log is preserved. Option C lesson promotion is preserved. v3 adds trend history through append-only `audit/kb-quality-history.json`, so a KB can be evaluated both on its current state and on whether it is improving or degrading over rebuilds.

- **New headline artifact:** `audit/kb-quality-scorecard.md`, with a machine-readable companion at `audit/kb-quality.json`.
- **New trend artifact:** `audit/kb-quality-history.json`, append-only across builds, refreshes, and patches.
- **New scoring model:** seven mechanical dimensions, weighted by `audit-templates/kb-quality-dimensions.yaml`.
- **Preserved v2 audit trail:** `sources/verification_log.md` and `sources/audit_trail.md` remain append-only.
- **Preserved portfolio memory:** `KB Creation Framework/master_audit_log.md` remains the cross-KB aggregator.
- **Preserved learning loop:** Option C still drafts Shared Axioms lessons when the same pattern appears in 3+ KBs, now extended to scorecard trend regressions.

---

## SECTION 2: KB QUALITY SCORECARD — THE HEADLINE DELIVERABLE

### 2.1 Where it lives

Every v3 KB root has an `audit/` folder containing the scorecard subsystem:

```text
[KB Root]/
├── audit/
│   ├── kb-quality-scorecard.md          (human-readable rolled-up artifact)
│   ├── kb-quality.json                  (machine-readable companion)
│   ├── kb-quality-history.json          (append-only trend history)
│   ├── methodology.md                   (scoring formulas and rationale, if separated from the scorecard)
│   └── badges/
│       └── quality-badge.svg            (badge surfaced in AGENTS.md or downstream routing)
└── sources/                             (unchanged v2-style per-phase audit trail)
```

The Markdown scorecard is the reviewer-facing document. The JSON file is the downstream-consumer contract and follows `audit-templates/audit-trail-schema.json`. The history file is the trend ledger. The methodology file and badge folder are supporting artifacts; they make the score explainable and easy to surface outside the KB root.

### 2.2 When it generates

The scorecard generates at the end of every build, refresh, and patch. A mid-build run is provisional; the final shipping scorecard is regenerated after stress-test artifacts exist. Old scorecards are not edited in place; the current measurements are appended to `audit/kb-quality-history.json`, and `audit/kb-quality-scorecard.md` reflects the current state only. Regeneration **MUST** happen after any edit to `full/`, because `full/` is the canonical source for downstream `authority/`, `practice/`, cross-references, volatile tags, and stress-test reliability. A patch that changes only supporting build metadata may regenerate without changing the score, but the run should still be recorded so the history shows that the current score was re-evaluated.

### 2.3 Three audiences, three views

| Audience | Primary artifact | Use |
|---|---|---|
| Operator building a KB | `sources/pipeline_state.md` | Phase-by-phase status, model assignment, blocked phases, missing artifacts, and remediation queue. |
| Reviewer evaluating a finished KB | `audit/kb-quality-scorecard.md` | Five-minute rolled-up quality view: overall verdict, seven dimension scores, open items, model-assignment caveats, and methodology. |
| Downstream consumer choosing whether to rely | `audit/kb-quality.json` + `audit/badges/quality-badge.svg` | Programmatic quality signal for routers, AGENTS.md badges, portfolio dashboards, and downstream reliance decisions. |

---

## SECTION 3: THE SEVEN DIMENSIONS

The seven dimensions are mechanical. They are derived from scriptable checks against existing phase artifacts; no model judgment is required to generate the scorecard. Thresholds are loaded from `audit-templates/kb-quality-dimensions.yaml`. The default thresholds are: citation density 80, register-tag integrity 85, cross-reference fidelity 90, qualifier preservation 80, volatile-tag coverage 95, stress-test pass rate 100, and structural compliance 90.

### 3.1 Citation density & primary-source rate

This dimension measures whether the KB cites its claims at sufficient density and to sufficiently authoritative sources. It matters because a polished KB with thin citations is not safely auditable: the downstream drafter cannot distinguish source-grounded material from plausible synthesis. The measurement is mechanical, derived from `table-of-authorities.md`, Phase 5b citation verification artifacts such as `sources/factcheck_citations.md`, and Phase 6b post-assembly fact-check artifacts such as `sources/post_assembly_factcheck.md`. The score looks at total citation rows, citation density across topic files, primary-source markers, and fact-check failure markers. The default threshold is 80. That threshold aligns with the framework's existing tolerance for legal and regulatory error rates: a score below the low 80s means the positive evidence base is too thin to trust without targeted re-verification. Failure looks like topic files with only one or two citations, Tier 3 general-web sources carrying operative claims, or Phase 5b/6b finding repeated citation mismatches.

### 3.2 Register-tag coverage & extraction integrity

This dimension measures whether the register architecture is working: `full/` contains the complete canonical discussion, while `authority/` and `practice/` receive the right subsets without leaking guidance, interpretation, or untagged material into the wrong view. It matters because downstream memo drafting depends on the view boundary. If `authority/` carries unsupported practice guidance, the stress-test can pass mechanically while still giving the writer the wrong kind of material. The measurement is mechanical, derived from `sources/register_lint_report.md` and `sources/authority_view_extraction.md`. It counts register-lint findings, inline-position register tags caught by extraction precheck, authority extraction blocks, and whether peer views exist. The threshold is 85 because register discipline must be substantially complete before downstream reliance; a few re-tag decisions can remain, but systematic leakage cannot. Failure looks like many paragraphs routed to RE-TAG, extraction retaining far too much or too little content, or inline-position tags blocking clean extraction.

### 3.3 Cross-reference fidelity

This dimension measures both mechanical link validity and substantive honesty of internal re-statements. A cross-reference is not reliable merely because the target file exists; it must also preserve the canonical statement's qualifiers, exceptions, threshold variants, scope clauses, terms of art, and numeric or temporal anchors. The measurement is mechanical from `sources/filename_validation.md` and `sources/factcheck_operative_claims.md` Part B. It counts cross-reference markers, filename/link failures, paraphrase-drop findings, and canonical-vs-restatement divergences. The threshold is 90 because cross-reference drift is a high-severity KB failure: a downstream drafter often reads the topic that maps to the question, not the canonical topic where the obligation originally lives. Failure looks like a services-attribution topic summarizing an Article 13 retention rule but dropping the expected-use carveout, or an enforcement topic collapsing two different reporting clocks into one cross-reference.

### 3.4 Qualifier preservation

This dimension measures whether operative provisions preserve every load-bearing qualifier, exception, threshold variant, scope clause, enumerated limb, and numeric or temporal anchor. It matters because qualifier loss is the same severity as fabrication for downstream use: the source may be real, the cite may be right, and the advice can still be wrong if the condition is missing. Measurement is mechanical from `sources/factcheck_operative_claims.md` Part A and, where present, `qualifier-registry.md`. It counts provisions checked verbatim, provisions restated structurally, lower-rigor paraphrases, paraphrase-drop findings, and registry-row coverage. The threshold is 80 in the default profile, with a higher weight for `legal_topic` KBs, because some low-risk paraphrase remains tolerable only when no operative anchor is dropped. Failure looks like summarizing "minimum five years" while omitting "or expected use time, whichever is shorter," or stating one incident-reporting deadline while the canonical source splits deadlines by event type.

### 3.5 Volatile-tag coverage

This dimension measures whether time-sensitive claims are marked so the Refresh Orchestrator knows what to re-check. It matters because a correct build can become wrong without any structural change: penalty units change, docket status changes, guidance finalizes, officials leave roles, and exchange rates move. Measurement is mechanical from `sources/volatile_tag_manifest.md`. It counts `[VOLATILE:*]` tags by type, heuristic findings for plausibly volatile claims that lack a tag, and `as_of_date` distribution. The threshold is 95 because volatility is an operations problem: one missing tag can cause a stale claim to survive multiple refresh cycles. Failure looks like a penalty amount with no `[VOLATILE:penalty-rate]` tag, a proceeding status without an as-of date, or a company leadership claim carried from a press release without a refresh trigger. A high score does not prove freshness; it proves the refresh system has the hooks needed to test freshness.

### 3.6 Stress-test pass rate

This dimension measures whether the KB works end-to-end for its intended downstream use. The build can look clean phase by phase and still fail when an independent agent drafts from `authority/` and an independent fact-checker compares the memo to primary sources. Measurement is mechanical from `sources/stress_test_report_*.md` and `sources/stress_test_memo_*_leakage.md`. It counts stress memos, leakage-detector CLEAN results, qualifier-preservation PASS results, independently confirmed memo claims, and red-team findings. The threshold is 100 because the stress test is the proof of the pudding: a known leakage or qualifier failure in a stress memo is not a caveat; it is evidence that downstream use is unsafe until the source KB or extraction layer is fixed. Failure looks like a memo claim unsupported by the source corpus, a leakage report with fabricated specifics, or a qualifier-preservation review finding that the memo dropped a carveout preserved in `authority/`.

### 3.7 Structural & size compliance

This dimension measures whether the KB is physically built to spec. It matters less than source fidelity but still matters operationally: routers, generators, and reviewers expect the root files, directories, topic naming, and peer views to exist. Measurement is mechanical from `sources/filename_validation.md`, per-file size checks, peer-view counts, and `sources/quality_tier_audit.md`. The threshold is 90 because structural problems should be rare by the time the scorecard runs; a missing required root file or unmatched `authority/` peer can break downstream automation even when content is substantively sound. Failure looks like missing `AGENTS.md`, missing `table-of-authorities.md`, an `authority/` folder with fewer peer files than `full/`, topic files below the quality-tier floor, or a parity ratio showing one topic is too thin to support reliable coverage.

---

## SECTION 4: COMPOSITE INDEX AND VERDICTS

### 4.1 KB Quality Index formula

The KB Quality Index is the weighted sum of the seven dimension scores. The authoritative weights live in `audit-templates/kb-quality-dimensions.yaml`. Default weights are:

| Dimension | Default weight |
|---|---:|
| Citation density & primary-source rate | 0.20 |
| Register-tag coverage & extraction integrity | 0.10 |
| Cross-reference fidelity | 0.15 |
| Qualifier preservation | 0.20 |
| Volatile-tag coverage | 0.05 |
| Stress-test pass rate | 0.25 |
| Structural & size compliance | 0.05 |

Formula:

```text
Composite = Σ(dimension_score × dimension_weight)
```

If `scoping_report.md` or equivalent KB metadata declares `kb_type`, the corresponding `kb_type_weights` profile in `kb-quality-dimensions.yaml` overrides the defaults. The v3 profiles tune the weights for `legal_topic`, `company`, `litigation`, `person`, and `technology` KBs. For example, `legal_topic` raises cross-reference fidelity to 0.20 and qualifier preservation to 0.25 because those KBs most often fail through qualifier and cross-reference drift.

### 4.2 Verdict thresholds

Verdicts are computed from the composite score, the per-dimension thresholds, stress-test performance, and critical audit findings:

| Verdict | Criteria |
|---|---|
| **PASS** | Composite ≥ 90 AND no dimension below its threshold AND stress-test = 100% |
| **PASS-WITH-CAVEATS** | Composite ≥ 80 AND no dimension > 10 points below threshold AND stress-test = 100% |
| **CONDITIONAL** | Composite ≥ 70 AND stress-test ≥ 80% AND no critical-tier finding in audit |
| **FAIL** | Anything else |

A mid-build or migrated KB can also receive **BUILD-INCOMPLETE** when required v3 artifacts are missing. That is not a shipping verdict; it is a diagnostic status telling the operator what remains to be produced.

### 4.3 Verdict semantics for shipping

`PASS` ships to any audience. `PASS-WITH-CAVEATS` ships with the caveats surfaced in `AGENTS.md`, the scorecard open-items table, and any downstream badge or router note. `CONDITIONAL` ships only to the operator with explicit acknowledgment; it is not suitable for routine downstream reliance until the condition is resolved. `FAIL` does not ship — return to Phase 6.5 deepening or earlier, depending on whether the failure is thin source coverage, structural incompleteness, register extraction, qualifier loss, stress-test leakage, or missing audit artifacts.

---

## SECTION 5: FAMILY-SEPARATION EXCEPTION HANDLING

Rule 19 (Model-Family Separation) opt-outs do **not** automatically downgrade the composite verdict. Per the v3 model-selection design, an operator may acknowledge a family-separation conflict and proceed. That acknowledgment is recorded in `sources/pipeline_state.md` under `model_assignment.rule_19_exceptions[]` with the conflicting phases, shared family, operator rationale, and timestamp. The Quality Scorecard surfaces the exception in its methodology appendix and tags affected dimension scores as `verification-independence-degraded`.

The tag is not cosmetic. It tells the reviewer that the same model family may have built content and then checked that content. The composite score remains mechanical, but the downstream reliance decision must weigh whether the independence tradeoff matters for the KB's use case. A `PASS` scorecard with degraded verification independence may still be shippable; it is not the same risk profile as a `PASS` scorecard produced under the standard multi-family preset.

---

## SECTION 6: GENERATING THE SCORECARD

### 6.1 Invocation

Generate the scorecard from the v3 root script:

```powershell
.\Generate-QualityScorecard.ps1 -KBRoot <path> [-WeightsPath <yaml>]
```

The script reads the KB root, expected root files, `sources/` phase artifacts, `table-of-authorities.md`, and the weights file. It writes `audit/kb-quality-scorecard.md`, `audit/kb-quality.json`, and `audit/kb-quality-history.json`. Console output is a one-line summary with the verdict, composite score, and scorecard path, for example:

```text
Quality scorecard: PASS-WITH-CAVEATS (89/100) — C:\...\audit\kb-quality-scorecard.md
```

The script is deterministic and makes no model calls. Its exit codes are: `0` for PASS, `1` for PASS-WITH-CAVEATS, CONDITIONAL, or BUILD-INCOMPLETE, and `2` for FAIL.

### 6.2 Partial scorecards

Mid-build runs emit a **BUILD-INCOMPLETE** scorecard with a missing-artifact list. They do not error merely because upstream phases have not finished. This is intentional: operators can use the scorecard as a diagnostic view during a build, not only as a final shipping gate. Missing required structure or missing phase artifacts appear as open items. Scores generated from partial evidence are tagged `build-incomplete` in the scorecard methodology or dimension tags.

### 6.3 Scorecard for v2-built KBs

v2 KBs lack some required v3 Phase 6 manifests, especially `sources/unresolved_unverified_manifest.md` and `sources/volatile_tag_manifest.md`. `Generate-QualityScorecard.ps1` handles missing artifacts gracefully; affected dimensions are marked build-incomplete rather than causing a runtime failure. For a complete v3 scorecard against a v2 KB, run `Migrate-V2KBtoV3.ps1` first. The migration script synthesizes the missing manifests from existing tags in `full/`, preserving the v2 audit trail while creating the v3 scorecard inputs.

---

## SECTION 7: PER-KB AUDIT TRAIL (PRESERVED FROM V2)

### Location

Every KB maintains two files in `sources/`:

1. **`verification_log.md`** — append-only log of every fact-check and verification event
2. **`audit_trail.md`** — append-only log of every structural decision, correction, and status change

### Verification Log Format

```markdown
# Verification Log — [KB Name]
# Created: [date]
# Entries: [count]

---

## [Date] — [Event Type]
**Agent:** [model used]
**Mode:** [pipeline / post-ship / refresh / document / correction]
**Claims checked:** [N]
**Results:** [N confirmed] / [N corrected] / [N removed] / [N unverifiable]
**Error rate:** [%]
**Corrections applied:**
- [File]: [old claim] → [new claim] (source: [URL])
- [File]: [removed claim] (reason: [fabricated/stale/unverifiable])
**Patterns noted:** [any recurring issues]

---
```

### Audit Trail Format

```markdown
# Audit Trail — [KB Name]
# Created: [date]
# Entries: [count]

---

## [Date] — [Event Type]
**Action:** [built / rebuilt / refreshed / patched / deepened / audited]
**Pipeline version:** [v1.0 / v1.4 / v1.5 / modular]
**Models used:** [list]
**Key decisions:**
- [decision]: [rationale]
**Outcome:** [ship / re-verify / rebuild]
**Error rate:** [% if applicable]
**Files affected:** [list]

---
```

### What Gets Logged

| Event | Logged In | Required Fields |
|-------|-----------|----------------|
| Fact-check (any mode) | verification_log | Claims, results, corrections, error rate |
| Post-ship audit | Both | Full audit results + ship/rebuild decision |
| Refresh cycle | Both | Staleness findings + updates applied |
| Build decision | audit_trail | Rebuild vs. patch rationale |
| Correction applied | verification_log | Old → new with source |
| Deepening | audit_trail | Files deepened, sizes before/after |
| Error pattern detected | audit_trail | Pattern, count, KB list |

### Immutability

Both logs are **append-only**. Entries are never edited or deleted. If a prior entry was wrong, add a new entry correcting it with a reference to the original entry date.

---

## SECTION 8: MASTER AUDIT LOG (PRESERVED FROM V2)

### Location

`<framework-root>\master_audit_log.md`

This is a framework-level file. It aggregates findings across all KBs.

### Format

```markdown
# Master Audit Log — KB Creation Framework
# Last updated: [date]
# KBs tracked: [N]
# Total audits: [N]

---

## Portfolio Summary

| KB | Type | Last Audit | Error Rate | Status | Build Version |
|----|------|-----------|------------|--------|---------------|
| [name] | [company/legal/litigation] | [date] | [%] | [ship/re-verify/rebuild] | [v1.0/v1.4/v1.5/modular] |

## Error Rate Trends

| KB | Build | Post-Audit 1 | Rebuild | Post-Audit 2 |
|----|-------|-------------|---------|---------------|
| Adobe | 32% | — | 8% | — |
| MS Gaming Legal | 16% | — | 8% | — |

---

## Cross-KB Error Patterns

### Pattern: [Name]
- **Occurrences:** [N] KBs
- **KBs affected:** [list]
- **Description:** [what the pattern is]
- **Root cause:** [why it keeps happening]
- **Lesson status:** [not yet / drafted / promoted to Shared Axioms as Lesson N]

---

## Audit History (Reverse Chronological)

### [Date] — [KB Name] — [Event]
**Error rate:** [%]
**Key findings:** [brief]
**Corrections:** [N applied]
**Patterns detected:** [any]

---
```

### What Gets Aggregated

The master log pulls from per-KB logs:
- Error rates from every post-ship audit
- Correction counts and types
- Recurring error descriptions
- Build/rebuild decisions and rationale

### Update Frequency

Updated after every:
- Post-ship audit
- Refresh cycle that includes verification
- Rebuild completion
- Cross-KB pattern detection

---

## SECTION 9: OPTION C — THRESHOLD-BASED LESSON PROMOTION (PRESERVED FROM V2, EXTENDED)

### 9.1 The mechanism

When the same error pattern appears in 3 or more KBs, the Audit System:
1. **Detects** the pattern from per-KB verification logs
2. **Drafts** a candidate lesson for Shared Axioms
3. **Presents** it to the human for review
4. **Promotes** it to Shared Axioms upon human confirmation

### Why 3 KBs?

- 1 occurrence = noise (could be one-off)
- 2 occurrences = emerging signal (worth noting, not codifying)
- 3 occurrences = systemic pattern (warrants a process change)

This threshold balances sensitivity (catching real patterns) with specificity (not over-fitting to random errors).

### 9.2 Pattern detection

Compare error descriptions across per-KB verification logs. Patterns to watch for:

| Pattern Type | Detection Signal | Example |
|-------------|-----------------|---------|
| Fabrication cluster | Same type of claim fabricated in 3+ KBs | Fabricated settlement amounts |
| Stale data persistence | Same type of data found stale in 3+ KBs | FY projections surviving into next FY |
| Overcautious exclusion | Real facts removed as fabrication in 3+ KBs | Confirmed events flagged as implausible |
| Source rot | Same type of citation gone dead in 3+ KBs | Press release URLs returning 404 |
| Model-specific error | Same model makes same mistake in 3+ KBs | Sonnet inventing case citations |
| Structural deficiency | Same structural gap in 3+ KBs | Missing table of authorities |

### 9.3 NEW IN V3 — Integration with kb-quality-history.json trends

Option C pattern detection now also watches dimension-score trends in `audit/kb-quality-history.json`. If a dimension regresses on 3+ KBs across consecutive builds, Option C drafts a candidate lesson investigating the regression. This is a portfolio-level signal, not merely a single-KB remediation queue.

Example: if Cross-reference fidelity drops on three KBs after a framework update, the Audit System should draft a candidate Shared Axioms lesson or framework correction explaining the likely cause, the affected artifacts, and the required prevention step. The lesson is still not auto-promoted; the trend only triggers a draft.

### 9.4 Lesson draft format

```markdown
## Candidate Lesson — [Draft Number]

**Pattern:** [Name]
**Occurrences:** [N KBs]
**Evidence:**
- [KB 1]: [specific instance]
- [KB 2]: [specific instance]
- [KB 3]: [specific instance]

**Proposed Lesson Text:**
> Lesson [N]: [Title]. [Body text — 2-4 sentences describing the pattern and the rule to prevent it.]

**Proposed Placement:** Shared Axioms Section [N], after Lesson [N]

**Status:** PENDING HUMAN REVIEW
```

### 9.5 Promotion workflow

```text
Pattern detected in 3+ KBs
  │
  ▼
Audit System drafts candidate lesson
  │
  ▼
Human reviews draft
  │
  ├─► Approve → Lesson added to Shared Axioms, numbered, effective immediately
  ├─► Modify → Human edits text → added to Shared Axioms
  └─► Reject → Logged as "reviewed, not promoted" with rationale
```

### 9.6 Anti-pattern: never auto-promote

Option C drafts lessons automatically but NEVER promotes them without human confirmation. The human confirms because: (a) they may see context the system doesn't, (b) the lesson text may need refinement, (c) not every pattern deserves a permanent rule.

### 9.7 Current lessons

Reference: `01-shared-axioms.md` Section 7 (Lessons Learned). As of framework creation, 23 lessons exist from the v1.0-v1.5 lifecycle. Option C adds to this list going forward.

---

## SECTION 10: ERROR CLASSIFICATION (PRESERVED FROM V2)

### Severity Levels

| Level | Definition | Impact | Example |
|-------|-----------|--------|---------|
| **Critical** | Factually wrong claim that could mislead legal advice | Immediate correction required | Wrong court ruling date, fabricated settlement amount |
| **Major** | Stale data or significantly inaccurate characterization | Correction before next use | Outdated market share, wrong executive title |
| **Minor** | Imprecise but not wrong, or cosmetic issues | Correct at next refresh | Rounded dollar amount, minor date discrepancy |
| **Cosmetic** | Formatting, style, or structural issues | No urgency | Missing YAML metadata, inconsistent header levels |

### Error Rate Calculation

Error rate = (Critical + Major errors) / total claims sampled × 100

Minor and cosmetic errors are tracked but do NOT count toward the error rate that determines ship/rebuild decisions.

---

## SECTION 11: PORTFOLIO HEALTH METRICS (PRESERVED FROM V2, EXTENDED)

### 11.1 Per-KB metrics

| Metric | Definition | Healthy Range |
|--------|-----------|---------------|
| **Portfolio error rate** | Average error rate across all KBs | < 8% for legal, < 12% for company |
| **Freshness score** | % of KBs within their refresh interval | > 80% |
| **Size compliance** | % of KBs passing all size gates | > 90% |
| **Lesson velocity** | New lessons promoted per quarter | 1-3 (more suggests systemic issues) |
| **Rebuild rate** | % of KBs requiring full rebuild at audit | < 10% after initial build cycle |
| **Correction density** | Average corrections per audit | Declining over time |

### Trend Tracking

After each audit cycle, update the master log with:
- Current metric values
- Comparison to prior cycle
- Direction of trend (improving / stable / degrading)

A degrading trend in any metric should be flagged for human review.

### 11.2 NEW IN V3 — Portfolio-level rollup

A future `Generate-PortfolioScorecard.ps1` can aggregate per-KB scorecards into portfolio-level metrics: count of KBs at each verdict tier, mean Quality Index, distribution of weakest dimensions, and trend by dimension across the portfolio. This is out of scope for v3.0 and targeted for the follow-on KB Operations v1 framework. Manual aggregation is possible today using the metrics in Section 11.1 plus each KB's `audit/kb-quality.json` and `audit/kb-quality-history.json`.

---

## SECTION 12: ANTI-PATTERNS

### Don't edit historical entries

The logs are append-only. If entry #5 was wrong, don't change it — add entry #12 that says "Correction to entry #5: [explanation]."

### Don't promote lessons prematurely

Two occurrences is a signal, not a pattern. Wait for the third. Premature lessons create rules that don't generalize.

### Don't conflate error types

A fabricated claim and a stale data point are both errors, but they have different root causes and different fixes. Track them separately.

### Don't ignore the denominator

An error rate of 20% on 5 claims (1 wrong) is very different from 20% on 100 claims (20 wrong). Always report both the rate and the sample size.

### Don't auto-promote lessons

Option C drafts lessons automatically but NEVER promotes them without human confirmation. The human confirms because: (a) they may see context the system doesn't, (b) the lesson text may need refinement, (c) not every pattern deserves a permanent rule.

### Logging is not application

Corrections must be applied to source files, not just logged. A `verification_log.md` entry that says a claim was wrong does not make the KB safer if the wrong claim still appears in `full/`, `authority/`, `practice/`, the table of authorities, or downstream examples.

### Scorecard score is not the truth

The scorecard is a signal, not the truth. It tells the reviewer what the mechanical evidence shows. Reviewer judgment governs the reliance decision, especially where the open-items table, family-separation tags, or sample-based methodology reveal uncertainty that a composite number can hide.

### Never edit a past scorecard

Do not revise an old scorecard to make history cleaner. Append a new entry to `audit/kb-quality-history.json` and regenerate the current scorecard. Trend history is evidence; editing it destroys the audit function.

### Family-separation exceptions are not a free pass

Rule 19 opt-outs do not auto-downgrade the verdict, but they must be surfaced prominently in any downstream reliance decision. A reviewer should know when the same model family checked content it helped build.

---

## SECTION 13: BOOTSTRAPPING

For a fresh framework instance, the master audit log starts empty. The first three builds produce no Option C lessons by definition, because one or two occurrences are signals rather than systemic patterns. Portfolio metrics stabilize after roughly five KBs; before that point, report the raw denominator and treat trend claims cautiously.

For existing pre-v3 KBs, bootstrap the preserved v2 audit trail before relying on portfolio metrics: create `sources/verification_log.md`, create `sources/audit_trail.md`, import existing audit data into the master audit log, and then run `Migrate-V2KBtoV3.ps1` if a complete v3 scorecard is needed.

---

## CROSS-REFERENCES

- `01-shared-axioms.md` Section 3 (Error Patterns)
- `01-shared-axioms.md` Section 7 (Lessons Learned)
- `04-fact-checker.md` (Mode 2)
- `06-refresh-orchestrator.md` (refresh cycle Step 3.5)
- `sources/verification_log.md`
- `sources/audit_trail.md`
- `KB Creation Framework/master_audit_log.md`
- `audit/kb-quality-scorecard.md`
- `audit/kb-quality.json`
- `audit/kb-quality-history.json`
- `audit-templates/kb-quality-dimensions.yaml`
- `Generate-QualityScorecard.ps1`
- `Migrate-V2KBtoV3.ps1`

---

*This module is the framework's memory and the reviewer-facing quality gate. It records what happened, detects what keeps happening, rolls mechanical evidence into a Quality Scorecard, and proposes changes to prevent recurring failure. It never substitutes for applying corrections to the source KB.*
