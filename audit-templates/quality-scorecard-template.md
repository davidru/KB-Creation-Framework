# KB Quality Scorecard — [KB Name] v[X.Y]

**Generated:** [YYYY-MM-DD HH:MM UTC]
**Framework:** KB Creation - Modular v[X.Y.Z]
**Memo Framework:** v[X.Y.Z] (used at Phase 8 stress test)
**KB Type:** [legal_topic | company | litigation | person | technology | other]
**Weights profile:** [kb_type-specific | default]

---

## OVERALL VERDICT

# [PASS | PASS-WITH-CAVEATS | CONDITIONAL | FAIL | BUILD-INCOMPLETE]

[One-paragraph operator summary: who this KB is reliable for, what it's not yet reliable for, and what would change the verdict. Generated mechanically from the dimension verdicts.]

---

## HEADLINE SCORES

**KB Quality Index (composite, weighted):** [N] / 100

| Dimension | Score | Threshold | Verdict | Tags |
|---|---|---|---|---|
| Citation density & primary-source rate | [N] | [T] | [V] | [tags] |
| Register-tag coverage & extraction integrity | [N] | [T] | [V] | [tags] |
| Cross-reference fidelity | [N] | [T] | [V] | [tags] |
| Qualifier preservation | [N] | [T] | [V] | [tags] |
| Volatile-tag coverage | [N] | [T] | [V] | [tags] |
| Stress-test pass rate | [N] | [T] | [V] | [tags] |
| Structural & size compliance | [N] | [T] | [V] | [tags] |

Tags definition:
- `verification-independence-degraded` — Rule 19 (Model-Family Separation) opt-out affected this dimension's verification independence; reviewer should weigh whether the same content checked itself.
- `sample-based` — score derived from a sample (e.g., Phase 6b P3 spot-check); see Methodology Appendix for confidence interval.
- `build-incomplete` — build did not complete to this phase; the score is partial / not authoritative.

---

## QUALITY DIMENSIONS (DETAILED)

### Citation density & primary-source rate — Score [N] / 100

**What it measures.** Whether the KB cites its claims at sufficient density and to sufficiently authoritative sources.

**Measurement method.** Mechanical, derived from `table-of-authorities.md`, Phase 5b citation verification (`sources/factcheck_citations.md`), and Phase 6b post-assembly fact-check (`sources/post_assembly_factcheck.md`).

**Underlying data.**
- Total citations in table-of-authorities.md: [N]
- Mean citations per topic file: [N]
- Thinnest topic file citations: [N]
- Tier 1 primary source % of total: [N]%
- Tier 2 authoritative secondary %: [N]%
- Tier 3 general web %: [N]%  (should approach zero for legal/regulatory KBs)
- Phase 5b PASS rate: [N]%
- Phase 6b PASS rate: [N]%

**Threshold rationale.** Set at 80 (the framework's error-rate threshold for legal KBs is 4-12%; corresponds roughly to a citation-quality floor in the 80s when expressed as positive score). For Company KBs, the threshold is the same but the weight is higher (citation quality is the most reliable signal of a Company KB's trustworthiness).

**Provenance.** `table-of-authorities.md`, `sources/factcheck_citations.md`, `sources/post_assembly_factcheck.md`.

---

### Register-tag coverage & extraction integrity — Score [N] / 100

**What it measures.** Whether the dual-view (now triple-view) register architecture is being used as intended. Specifically: are paragraphs that should be tagged actually tagged; is `authority/` actually authoritative (not leaking guidance content); is `practice/` actually practice-tier (not leaking interpretation).

**Measurement method.** Mechanical, derived from `register_lint_report.md` and `authority_view_extraction.md`.

**Underlying data.**
- % paragraphs register-tagged in `full/`: [N]%
- `full/` → `authority/` retention %: [N]% (target: 60-80%; too high may indicate under-tagging; too low may indicate over-tagging)
- `full/` → `practice/` retention %: [N]% (target: 75-90%)
- Register-lint findings routed to RE-TAG: [N]
- Register-lint findings routed to KEEP-UNTAGGED: [N]
- Inline-position register tags caught by extraction precheck: [N] (should be 0)

**Provenance.** `sources/register_lint_report.md`, `sources/authority_view_extraction.md`.

---

### Cross-reference fidelity — Score [N] / 100

**What it measures.** Whether internal cross-references resolve (mechanical link validity) and whether re-statements of a canonical claim preserve the canonical's qualifiers (substantive fidelity).

**Measurement method.** Mechanical link check from `filename_validation.md`; substantive fidelity from `factcheck_operative_claims.md` Part B.

**Underlying data.**
- Total internal cross-references: [N]
- % resolving to existing target files: [N]%
- Paraphrase-drops caught at Phase 5e Part B: [N]
- Canonical-vs-restatement divergences flagged: [N]
- Qualifier-registry rows referenced (if registry present): [N]

**Provenance.** `sources/filename_validation.md`, `sources/factcheck_operative_claims.md`.

---

### Qualifier preservation — Score [N] / 100

**What it measures.** Whether operative provisions are stated with their full set of qualifiers, exceptions, threshold variants, scope clauses, and enumerated limbs preserved. This is the dimension that fails when a KB summarizes "at least five years" instead of "at least five years from placing on the market, OR, where the PDE is expected to be in use for less than five years, the expected use time."

**Measurement method.** Mechanical, derived from `factcheck_operative_claims.md` Part A; cross-referenced against `qualifier-registry.md` rows if present.

**Underlying data.**
- Operative provisions checked verbatim: [N]
- Operative provisions checked via structured restatement: [N]
- Operative provisions checked as paraphrase (lower-rigor): [N]
- Paraphrase-drops caught: [N]
- Qualifier registry rows covered: [N] of [M] total
- Registry rows that surfaced new failures during this build: [N]

**Provenance.** `sources/factcheck_operative_claims.md`, `qualifier-registry.md` (if present).

---

### Volatile-tag coverage — Score [N] / 100

**What it measures.** Whether the KB has flagged its time-sensitive claims appropriately so the Refresh Orchestrator knows what to re-verify.

**Measurement method.** Mechanical, derived from `volatile_tag_manifest.md`.

**Underlying data.**
- Total `[VOLATILE:*]` tags by type: [docket-count: N, penalty-rate: N, exchange-rate: N, ...]
- Operative claims plausibly volatile that lack a tag (heuristic): [N] (estimated by Pattern 14 detector)
- `as_of_date` distribution: [N] within 30 days, [N] 30-90 days, [N] 90+ days

**Provenance.** `sources/volatile_tag_manifest.md`.

---

### Stress-test pass rate — Score [N] / 100

**What it measures.** Whether the dual-view architecture actually works end-to-end: an independent agent drafting a memo from `authority/` produces a memo that an independent fact-checker confirms against primary sources.

**Measurement method.** Mechanical, derived from `stress_test_report_*.md` + `stress_test_memo_*_leakage.md`.

**Underlying data.**
- Memos stress-tested: [N] (target: 3-6)
- Memos CLEAN at leakage detector: [N] of [M]
- Memos PASS at qualifier-preservation review: [N] of [M]
- Memo claims confirmed by independent fact-check: [N] of [M] ([X]%)
- Adversarial red-team stress (Phase 8.5) findings: [N] (0 expected for PASS)

**Provenance.** `sources/stress_test_report_*.md`, `sources/stress_test_memo_*_leakage.md`.

---

### Structural & size compliance — Score [N] / 100

**What it measures.** Whether the KB is physically built to spec.

**Measurement method.** Mechanical, derived from `filename_validation.md`, per-file size measurements, `quality_tier_audit.md`.

**Underlying data.**
- Quality tier achieved: [A | B | C]
- Topic file count vs scoping target: [N actual] / [M target]
- Size distribution: mean [N]KB, thinnest [N]KB, thickest [N]KB
- Parity ratio (thinnest/thickest): [N]%
- All required root files present: [yes/no]

**Provenance.** `sources/filename_validation.md`, `sources/quality_tier_audit.md`.

---

## OPEN ITEMS

| ID | Severity | Item | Source artifact | Recommended action |
|---|---|---|---|---|
| OQ-1 | [minor/material/critical] | [description] | [file] | [action] |
| ... | | | | |

---

## MODEL ASSIGNMENT

This build used the following model assignment (from Phase 0.0):

```yaml
preset: [standard-multi-family | budget-multi-family | single-family-anthropic | single-family-openai | custom]
lead: [model]
builder_a: [model]
builder_b: [model]
critic_pool: [model, model]
factcheck_pool_5a_5b_5c: [model]
factcheck_pool_5d_5e: [model]
factcheck_6b: [model]
auditor_7: [model]
memo_factcheck_8: [model]
```

**Rule 19 (Model-Family Separation) exceptions:** [None | List with conflicting phases, shared family, operator rationale, acknowledgment timestamp.]

If exceptions are present, the dimensions marked `verification-independence-degraded` in the headline scores table above were affected.

---

## VERSION HISTORY

| Version | Generated | KB Quality Index | Verdict | Notes |
|---|---|---|---|---|
| [v3.0.0] | [YYYY-MM-DD] | [N] | [verdict] | Initial v3 build |
| ... | | | | |

(Appended from `audit/kb-quality-history.json` on each rebuild/refresh.)

---

## METHODOLOGY APPENDIX

### Scoring formulas

Each dimension is computed mechanically from its source artifacts. The exact formula for each dimension is documented in this section. Reviewers may verify any score by retracing the formula against the cited source artifacts.

[Formulas — emitted dynamically by Generate-QualityScorecard.ps1 based on the kb_type and weights profile loaded at generation time.]

### Sampling methodology

Where a dimension is derived from a sample (typically Phase 6b P3 spot-check at 1-in-5), the confidence interval is reported. Sample-based dimensions are tagged `sample-based` in the headline scores.

### Family-separation exceptions

If `model_assignment.rule_19_exceptions` is non-empty, the affected dimensions are tagged `verification-independence-degraded` per the policy in `audit-templates/kb-quality-dimensions.yaml`. The composite KB Quality Index is NOT auto-downgraded; reviewers should weigh whether the same content checked itself when deciding whether to rely on the KB.

### Framework version provenance

This scorecard was generated by KB Creation Framework v[X.Y.Z] using weights profile from `audit-templates/kb-quality-dimensions.yaml` v[X]. The Memo Drafting Framework v[X.Y.Z] was invoked at Phase 8 stress test.

---

*End of Quality Scorecard. Companion machine-readable artifact: `audit/kb-quality.json`.*
