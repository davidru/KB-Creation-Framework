# KB Quality Scorecard — Example Legal Topic KB v3.0.1

**Generated:** 2026-06-07 18:30 UTC  
**Framework:** KB Creation - Modular v3.0  
**Memo Framework:** v1.0 (used at Phase 8 stress test)  
**KB Type:** legal_topic  
**Weights profile:** kb_type-specific (`legal_topic` from `audit-templates/kb-quality-dimensions.yaml`)

---

## OVERALL VERDICT

# PASS-WITH-CAVEATS

This hypothetical legal-topic KB is reliable for ordinary downstream memo drafting and issue-spotting where the user reads the caveats before reliance. The stress test is clean, the citation base is strong, volatile claims are tagged, and structural compliance is complete. The caveat is cross-reference fidelity: Phase 5e found two canonical-vs-restatement divergences in non-core topic summaries, one fully corrected and one left with a `[CONFIRM CROSS-REFERENCE]` tag pending an exhaustive adjacent-row check at the next refresh.

---

## HEADLINE SCORES

**KB Quality Index (composite, weighted):** 89.2 / 100

| Dimension | Score | Threshold | Verdict | Tags |
|---|---:|---:|---|---|
| Citation density & primary-source rate | 89 | 80 | PASS | — |
| Register-tag coverage & extraction integrity | 88 | 85 | PASS | — |
| Cross-reference fidelity | 86 | 90 | PASS-WITH-CAVEATS | sample-based |
| Qualifier preservation | 84 | 80 | PASS | — |
| Volatile-tag coverage | 96 | 95 | PASS | — |
| Stress-test pass rate | 100 | 100 | PASS | — |
| Structural & size compliance | 92 | 90 | PASS | — |

Tags definition:
- `verification-independence-degraded` — Rule 19 (Model-Family Separation) opt-out affected this dimension's verification independence; reviewer should weigh whether the same content checked itself.
- `sample-based` — score derived from a sample (e.g., Phase 6b P3 spot-check); see Methodology Appendix for confidence interval.
- `build-incomplete` — build did not complete to this phase; the score is partial / not authoritative.

---

## QUALITY DIMENSIONS (DETAILED)

### Citation density & primary-source rate — Score 89 / 100

**What it measures.** Whether the KB cites its legal and operational claims at sufficient density and to sufficiently authoritative sources.

**Measurement method.** Mechanical, derived from `table-of-authorities.md`, Phase 5b citation verification (`sources/factcheck_citations.md`), and Phase 6b post-assembly fact-check (`sources/post_assembly_factcheck.md`).

**Underlying data.**
- Total citations in `table-of-authorities.md`: 214
- Mean citations per topic file: 15.3
- Thinnest topic file citations: 8
- Tier 1 primary source % of total: 73%
- Tier 2 authoritative secondary %: 25%
- Tier 3 general web %: 2%
- Phase 5b PASS rate: 96%
- Phase 6b PASS rate: 94%

**Threshold rationale.** The threshold is 80. For legal-topic KBs, citation quality is weighted at 0.20 because legal claims must be retraceable to primary or authoritative sources before a downstream memo can safely rely on them.

**Provenance.** `table-of-authorities.md`, `sources/factcheck_citations.md`, `sources/post_assembly_factcheck.md`.

---

### Register-tag coverage & extraction integrity — Score 88 / 100

**What it measures.** Whether the triple-view register architecture is being used as intended: `full/` holds the complete discussion, `authority/` excludes practice gloss, and `practice/` preserves usable operational context without leaking unsupported interpretation.

**Measurement method.** Mechanical, derived from `sources/register_lint_report.md` and `sources/authority_view_extraction.md`.

**Underlying data.**
- % paragraphs register-tagged in `full/`: 91%
- `full/` → `authority/` retention: 68%
- `full/` → `practice/` retention: 82%
- Register-lint findings routed to RE-TAG: 5
- Register-lint findings routed to KEEP-UNTAGGED: 11
- Inline-position register tags caught by extraction precheck: 0

**Threshold rationale.** The threshold is 85. The KB clears the threshold because extraction retained the expected range and no inline-position tags blocked automated view generation.

**Provenance.** `sources/register_lint_report.md`, `sources/authority_view_extraction.md`.

---

### Cross-reference fidelity — Score 86 / 100

**What it measures.** Whether internal cross-references resolve and whether re-statements of canonical legal obligations preserve the canonical qualifiers.

**Measurement method.** Mechanical link check from `sources/filename_validation.md`; substantive fidelity from `sources/factcheck_operative_claims.md` Part B.

**Underlying data.**
- Total internal cross-references: 147
- % resolving to existing target files: 100%
- Paraphrase-drops caught at Phase 5e Part B: 2
- Canonical-vs-restatement divergences flagged: 2
- Qualifier-registry rows referenced: 9

**Threshold rationale.** The threshold is 90. This dimension is below threshold but within the 10-point caveat band. The divergences were in summary rows, not canonical provisions; one remains tagged for confirmation, so reviewers should route operative reliance through the canonical sections until the next refresh re-samples adjacent rows.

**Provenance.** `sources/filename_validation.md`, `sources/factcheck_operative_claims.md`, `qualifier-registry.md`.

---

### Qualifier preservation — Score 84 / 100

**What it measures.** Whether operative provisions preserve every qualifier, exception, threshold variant, scope clause, term of art, enumerated limb, and numeric or temporal anchor.

**Measurement method.** Mechanical, derived from `sources/factcheck_operative_claims.md` Part A and cross-referenced against `qualifier-registry.md`.

**Underlying data.**
- Operative provisions checked verbatim: 41
- Operative provisions checked via structured restatement: 13
- Operative provisions checked as paraphrase (lower-rigor): 6
- Paraphrase-drops caught: 1
- Qualifier registry rows covered: 9 of 9 total
- Registry rows that surfaced new failures during this build: 1

**Threshold rationale.** The threshold is 80, but legal-topic KBs weight this dimension at 0.25. The score passes because the single paraphrase-drop was corrected and did not remain in canonical text; the residual score reduction reflects the lower-rigor paraphrase population.

**Provenance.** `sources/factcheck_operative_claims.md`, `qualifier-registry.md`.

---

### Volatile-tag coverage — Score 96 / 100

**What it measures.** Whether time-sensitive claims are tagged so the Refresh Orchestrator knows what to re-verify.

**Measurement method.** Mechanical, derived from `sources/volatile_tag_manifest.md`.

**Underlying data.**
- `[VOLATILE:*]` tags by type: penalty-rate: 6; agency-guidance: 9; enforcement-status: 5; docket-status: 2
- Operative claims plausibly volatile that lack a tag: 1
- `as_of_date` distribution: 17 within 30 days; 4 within 30-90 days; 1 older than 90 days

**Threshold rationale.** The threshold is 95 because missing a volatile tag can let a stale legal claim survive refresh. The one untagged candidate is a low-risk agency webpage reference listed as a minor open item.

**Provenance.** `sources/volatile_tag_manifest.md`.

---

### Stress-test pass rate — Score 100 / 100

**What it measures.** Whether the KB works end-to-end when an independent memo drafter uses `authority/` and an independent fact-checker verifies the resulting memo against sources.

**Measurement method.** Mechanical, derived from `sources/stress_test_report_*.md` and `sources/stress_test_memo_*_leakage.md`.

**Underlying data.**
- Memos stress-tested: 4
- Memos CLEAN at leakage detector: 4 of 4
- Memos PASS at qualifier-preservation review: 4 of 4
- Memo claims confirmed by independent fact-check: 126 of 126 (100%)
- Adversarial red-team stress (Phase 8.5) findings: 0

**Threshold rationale.** The threshold is 100. A legal-topic KB does not ship on a known stress-test leakage or qualifier-preservation failure.

**Provenance.** `sources/stress_test_report_01.md`, `sources/stress_test_report_02.md`, `sources/stress_test_report_03.md`, `sources/stress_test_report_04.md`, `sources/stress_test_memo_*_leakage.md`.

---

### Structural & size compliance — Score 92 / 100

**What it measures.** Whether the KB is physically built to spec.

**Measurement method.** Mechanical, derived from `sources/filename_validation.md`, per-file size measurements, and `sources/quality_tier_audit.md`.

**Underlying data.**
- Quality tier achieved: B+
- Topic file count vs scoping target: 14 actual / 14 target
- Size distribution: mean 24KB, thinnest 17KB, thickest 39KB
- Parity ratio (thinnest/thickest): 44%
- All required root files present: yes

**Threshold rationale.** The threshold is 90. The KB clears the structural gate, but the parity ratio is weaker than ideal and should be watched if new topics are added.

**Provenance.** `sources/filename_validation.md`, `sources/quality_tier_audit.md`.

---

## OPEN ITEMS

| ID | Severity | Item | Source artifact | Recommended action |
|---|---|---|---|---|
| OQ-1 | material | Topic 09 practice summary retains a `[CONFIRM CROSS-REFERENCE]` tag after Phase 5e found canonical-vs-restatement qualifier drift; canonical `authority/` text is reliable, but the summary row should not carry operative reliance yet. | `sources/factcheck_operative_claims.md` Part B | Re-sample all cross-reference summary rows at the next refresh; promote a qualifier-registry row if the pattern recurs. |
| OQ-2 | minor | One agency-guidance webpage reference is plausibly volatile but lacks a final `[VOLATILE:agency-guidance]` tag pending URL normalization. | `sources/volatile_tag_manifest.md` | Add the tag when URL canonicalization is complete. |
| OQ-3 | minor | Topic 11 is structurally compliant but remains the thinnest file by citation density. | `sources/quality_tier_audit.md` | Deepen if the next build adds adjacent scope; otherwise leave for scheduled refresh. |

---

## MODEL ASSIGNMENT

This build used the following model assignment (from Phase 0.0):

```yaml
preset: standard-multi-family
lead: claude-opus-4.7
builder_a: gpt-5.4
builder_b: claude-sonnet-4.6
critic_pool:
  - gpt-4.1
  - gpt-5.4
factcheck_pool_5a_5b_5c:
  - gpt-5.4
factcheck_pool_5d_5e:
  - gemini-3.1-pro-preview
factcheck_6b:
  - gemini-3.1-pro-preview
auditor_7:
  - gpt-5.4
memo_factcheck_8:
  - gpt-5.4
```

**Rule 19 (Model-Family Separation) exceptions:** None.

If exceptions were present, affected dimensions would be marked `verification-independence-degraded` in the headline scores table above. No such tag applies here.

---

## BUILD PHASE SUMMARY

| Phase | Exit status | Model / tool | Completed at | Notes |
|---|---|---|---|---|
| 0.0 Model selection | PASS | claude-opus-4.7 | 2026-06-07T08:10:00Z | Standard multi-family preset selected. |
| 0.1 Availability preflight | PASS | scripts | 2026-06-07T08:12:00Z | All selected models reachable. |
| 1 Scoping | PASS | claude-opus-4.7 | 2026-06-07T08:35:00Z | 14-topic legal-topic scope approved. |
| 2 Source acquisition | PASS | gpt-5.4 | 2026-06-07T09:20:00Z | Primary-source pull complete. |
| 3 Source normalization | PASS | gpt-5.4 | 2026-06-07T09:55:00Z | All source records normalized. |
| 4 Skeleton build | PASS | claude-sonnet-4.6 | 2026-06-07T10:25:00Z | Root files and topic shells created. |
| 5a Definitional fidelity check | PASS | gpt-5.4 | 2026-06-07T10:55:00Z | No definitional paraphrase-drop. |
| 5b Citation verification | PASS-WITH-FINDINGS | gpt-5.4 | 2026-06-07T11:30:00Z | Four citation strings corrected. |
| 5c Operative claim audit | PASS-WITH-FINDINGS | gpt-5.4 | 2026-06-07T12:05:00Z | One lower-rigor paraphrase rewritten. |
| 5d Qualifier registry check | PASS-WITH-FINDINGS | gemini-3.1-pro-preview | 2026-06-07T12:35:00Z | One new registry-triggered fix applied. |
| 5e Cross-reference fidelity check | PASS-WITH-FINDINGS | gemini-3.1-pro-preview | 2026-06-07T13:05:00Z | Two summary-row divergences corrected. |
| 6 Assembly | PASS | claude-sonnet-4.6 | 2026-06-07T13:40:00Z | `full/`, `authority/`, and `practice/` generated. |
| 6a Register lint | PASS-WITH-FINDINGS | scripts | 2026-06-07T14:05:00Z | Five RE-TAG findings fixed. |
| 6b Post-assembly fact-check | PASS-WITH-FINDINGS | gemini-3.1-pro-preview | 2026-06-07T14:45:00Z | Sample passed after citation corrections. |
| 6c Filename validation | PASS | scripts | 2026-06-07T15:00:00Z | 100% internal link resolution. |
| 6d Volatile-tag manifest | PASS-WITH-FINDINGS | scripts | 2026-06-07T15:20:00Z | One low-risk tag deferred. |
| 6e Quality-tier audit | PASS | scripts | 2026-06-07T15:35:00Z | B+ tier achieved. |
| 7 Audit assembly | PASS | gpt-5.4 | 2026-06-07T16:00:00Z | Per-KB audit trail updated. |
| 8 Stress memo 1-2 | PASS | Memo Framework v1 | 2026-06-07T16:45:00Z | Both memos CLEAN. |
| 8.1 Stress memo 3-4 | PASS | Memo Framework v1 | 2026-06-07T17:20:00Z | Both memos CLEAN. |
| 8.5 Adversarial red-team stress | PASS | gpt-5.4 | 2026-06-07T17:55:00Z | No blocker or material findings. |
| 9 Scorecard generation | PASS-WITH-FINDINGS | `Generate-QualityScorecard.ps1` | 2026-06-07T18:30:00Z | Overall PASS-WITH-CAVEATS. |

---

## VERSION HISTORY

| Version | Generated | KB Quality Index | Verdict | Notes |
|---|---|---:|---|---|
| v3.0.0 | 2026-06-07 16:10 UTC | 86.4 | PASS-WITH-CAVEATS | Initial v3 build; cross-reference fidelity at 82 before summary-row fixes. |
| v3.0.1 | 2026-06-07 18:30 UTC | 89.2 | PASS-WITH-CAVEATS | Notional rebuild after correcting two cross-reference summary rows and re-running stress tests. |

(Appended from `audit/kb-quality-history.json` on each rebuild/refresh.)

---

## METHODOLOGY APPENDIX

### Scoring formulas

Each dimension is computed mechanically from its source artifacts. Reviewers may verify any score by retracing the formula against the cited source artifacts.

For this example, the legal-topic composite uses the `legal_topic` profile from `kb-quality-dimensions.yaml`:

```text
Composite =
  (89 × 0.20) +
  (88 × 0.10) +
  (86 × 0.20) +
  (84 × 0.25) +
  (96 × 0.05) +
  (100 × 0.15) +
  (92 × 0.05)
= 89.2
```

The cross-reference fidelity score is illustrative of the underlying dimension mechanics: link validity contributes positively because 147 of 147 internal references resolved; two Phase 5e canonical-vs-restatement divergences reduce the score; registry coverage mitigates but does not erase the caveat because the divergences occurred in summary rows that downstream drafters are likely to read.

### Sampling methodology

Phase 6b used the standard P3 spot-check sample: one in five assembled claims plus all claims carrying `[NEEDS-VERIFICATION]`, `[VOLATILE:*]`, or qualifier-registry triggers. Cross-reference fidelity is tagged `sample-based` because adjacent summary rows were spot-checked rather than exhaustively re-read after the two divergences. The illustrative confidence interval for the adjacent-row sample is ±7 percentage points at 95% confidence. The sample found no blocker or critical failures, but the caveat remains until the next refresh expands the sample.

### Family-separation exceptions

No Rule 19 exceptions were used. The standard multi-family preset assigned Phase 5d/5e and Phase 6b checks to Gemini-family models while build and citation-check phases used Anthropic and OpenAI-family models. No dimension is tagged `verification-independence-degraded`.

### Framework version provenance

This example scorecard was generated as a reference artifact for KB Creation Framework v3.0 using weights profile from `audit-templates/kb-quality-dimensions.yaml` v1.0. The Memo Drafting Framework v1.0 was invoked at Phase 8 stress test.

---

*End of Quality Scorecard. Companion machine-readable artifact: `audit/kb-quality.json`.*
