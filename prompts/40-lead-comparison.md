# Lead Comparison + Single-Source Inventory + Compliance Check (Phase 4.0)

**Role:** Lead reviewer  
**Input:** Both builders' v2 drafts; v1 drafts; Phase 2.0 review reports  
**Output:** `sources/comparison_report.md` with dispute resolutions, single-source claim inventory, and v1-vs-v2 compliance check  
**Runs:** Once, after Phase 3.0 revisions

---

## Prompt

```text
You are the Lead reviewer comparing two independently-built revised drafts of the [KB_NAME] knowledge base.

BUILDER A ([model name]) v2 DRAFT:
[Paste or attach Builder A's v2 draft]

BUILDER B ([model name]) v2 DRAFT:
[Paste or attach Builder B's v2 draft]

PHASE 2.0 REVIEWS:
[Paste or attach sources/review_[builder_a].md and sources/review_[builder_b].md]

V1 DRAFTS:
[Paste or attach sources/kb_[builder].md for each builder]

SCOPING REPORT TOPICS: [TOPICS_IN_SCOPE]

TASK:
Produce `sources/comparison_report.md`. The report has seven required sections.

## Section 1 — Section-by-section comparison
For each section, evaluate:

1. AGREEMENTS — Claims both builders make. These are likely correct. Note them with confidence level.
2. DISPUTES — Claims where builders disagree. For each:
   - State what Builder A says.
   - State what Builder B says.
   - Web search to resolve the dispute.
   - Record your resolution with source citation.
   Do NOT just flag disputes — SETTLE them.
3. UNIQUE CONTENT — Material in one builder but not the other.
   - Evaluate: is it accurate? (web search)
   - Evaluate: is it in scope?
   - Recommend: include, exclude, or verify further.
4. FABRICATION CHECK — Claims appearing in only one builder that seem implausible. SEARCH FIRST. Run at least 3 queries before excluding. (See 01-shared-axioms.md Pattern 5: Overcautious Exclusion.)
5. BACKBONE RECOMMENDATION — For each section, which builder's version should be the backbone for assembly? Consider factual accuracy, depth, citation quality, and analytical value.

## Section 2 — Dispute resolutions
Detailed table of every dispute and the source used to resolve it.

## Section 3 — Unique content routing
Table of unique A / unique B content with include / exclude / Phase 5 verification routing.

## Section 4 — Backbone recommendation
Overall backbone recommendation: Builder A / Builder B / mixed, with per-section rationale.

## Section 5 — Assembly instructions
Specific instructions the Phase 6.0 assembler must follow, including fact-check dependencies and unresolved issues.

## Section 6 — Single-Source Claim Inventory (REQUIRED; machine-validated)
This section is the contract for Phase 5.4. It MUST use this exact heading and table schema because `Validate-Phase4Inventory.ps1` parses it.

| claim_id | claim_text | originating_builder | v2_location | claim_type | risk_notes |
|---|---|---|---|---|---|
| SSC-0001 | [verbatim or tight paraphrase of claim] | A/B | [file/section] | citation/date/number/entity/legal-status/classification/membership/institutional-fact/other | [why single-source or high-risk] |

Rules:
- Every claim appearing in only one builder's draft and carrying factual, legal, numeric, date, entity, classification, citation, institutional-fact, or membership specificity gets a row.
- `claim_id` MUST match `SSC-0000` shape.
- `originating_builder` MUST be `A` or `B`.
- Do not omit a single-source claim because it seems plausible; Phase 5.4 exists to verify it.

After writing the report, run:

powershell
& "[FRAMEWORK_ROOT]\Validate-Phase4Inventory.ps1" `
    -ComparisonReportPath "[STATE_ROOT]\sources\comparison_report.md" `
    -OutPath "[STATE_ROOT]\sources\phase4_inventory_validation.md"

A failed validation is BLOCKING. Fix Section 6 and re-run before Phase 5.4 or Phase 6.4.

## Section 7 — v1-vs-v2 Compliance Check (folded from v2 Phase 3.5)
For each builder, mechanically diff v1 vs v2 against `sources/review_[builder].md`. You are NOT re-reviewing the draft; you are checking that each item in the Lead's review was actually addressed.

For each review item, classify:
1. ADDRESSED — v2 made the requested change. Cite v1 location, v2 location, and nature of change.
2. PARTIALLY ADDRESSED — v2 changed the area but did not fully resolve the issue. Cite what's still outstanding.
3. NOT ADDRESSED — v2 contains the same problem as v1. Cite v1 and v2 location.
4. INTENTIONALLY DECLINED — v2 explicitly explains why the item was not addressed. Cite the explanation.
5. NEW PROBLEM INTRODUCED — v2 fixed the original item but introduced a new problem.

Output table:
| Builder | Review Item (verbatim short excerpt) | Disposition | v1 Evidence | v2 Evidence | Phase 6.0 Assembly Treatment |
|---|---|---|---|---|---|

BLOCKING rule: every NOT ADDRESSED, PARTIALLY ADDRESSED, or NEW PROBLEM INTRODUCED item becomes a mandatory comparison-report flag and a mandatory Phase 6.0 assembly correction unless a targeted re-revision closes it first. The Lead reviews every INTENTIONALLY DECLINED item; weak decline reasons reopen the item as NOT ADDRESSED.
```
