# Fact-Check: Citation Verification (Decomposed — Phase 5.2)

**Role:** Lead or dedicated fact-check agent
**Input:** All citations from v2 drafts
**Output:** Citation-by-citation verification
**Runs:** Once per build; can run in parallel with Phases 5.1 and 5.3
**Why decomposed:** Systematic per-citation verification; prevents batch fatigue
**Reference:** 04-fact-checker.md for full verification protocol

---

## Prompt

```
You are verifying every citation in the [KB_NAME] knowledge base.

CITATIONS TO VERIFY:
[Paste the complete list of citations from both v2 drafts — cases,
statutes, regulations, enforcement actions, reports, filings]

TASK:
For each citation, verify via web search:

1. Does the cited source EXIST?
2. Is the citation CORRECT?
   - Case: correct parties, correct reporter, correct year, correct court
   - Statute: correct title, section, subsection
   - Regulation: correct CFR title, part, section
   - Report: correct author, title, date, publisher
3. Does the cited source SAY what the KB claims it says?
   - Verify the specific proposition attributed to the source
4. CROSS-REFERENCE FIDELITY (when the cite is to another section of
   the same KB rather than to a primary source — e.g., a topic
   citing another topic's canonical statement of an operative
   claim): locate the cited KB section and compare the cross-
   reference text against the canonical text. Flag any qualifier,
   exception, threshold variant, scope clause, term-of-art,
   enumerated limb, or numeric/temporal anchor present in the
   canonical but absent from the cross-reference. Treat any
   paraphrase-drop as a verification failure — same severity as a
   primary-source mismatch. Empirical: EU CRA KB Topic 07
   (2026-05-19) cross-referenced Art. 13(8)/13(9)/14 as
   consequences of manufacturer attribution; the cross-references
   dropped the "expected use, whichever is shorter" carveout, the
   "whichever is longer" qualifier, and the 14(2) vs 14(4) timing
   split — qualifiers that the canonical statements in Topics 02
   and 06 correctly preserved.

ZERO TOLERANCE RULE:
If a citation cannot be verified after reasonable search (3+ queries),
it must be REMOVED from the KB. Not flagged — removed.
"Sounds right" is not verification. Confirmed or gone.

EXCLUSION SAFEGUARD:
Before removing any citation, run at least 3 different search queries.
Log the queries. Only exclude if ALL searches return zero results.
(01-shared-axioms.md Pattern 5: Overcautious Exclusion)

VERIFICATION METHOD (per 04-fact-checker.md):
- Primary sources: court databases, official statute text, SEC EDGAR,
  agency press releases, official SDO records
- Source hierarchy: Tier 1 > Tier 2 > Tier 3
- Record the source URL for every verification

DEFAULT-ON GROUNDING (per 04-fact-checker.md §1.3.1):
The Crawl4AI grounding adapter (`adapters/crawl4ai-fetch/`) is DEFAULT-ON for Phase 5.2. Run it before citation verification unless `sources/scoping_report.md` and `sources/pipeline_state.md` record an explicit opt-out rationale. Once a manifest exists, you may not fall back to training-data recall for cites it covers.

If grounding was run, you must be given:
  1. [STATE_ROOT]/grounding/cites.json       (one record per cite occurrence)
  2. [STATE_ROOT]/grounding/fetch_log.json   (one record per unique URL)
  3. [STATE_ROOT]/grounding/sources/         (fetched markdown, one file per URL)
  -- OR --
  the pre-built per-source-file packets at
  [STATE_ROOT]/grounding/packets/ (which already join cites × fetch_log).

If you were not given these inputs and a grounding/ directory exists,
STOP and request them; do not proceed without grounding when grounding
is available.

PREFLIGHT (run before verification, when manifest is present):
  - Total cite occurrences in scope
  - Unique URLs grounded (ok:true)
  - Failed fetches (ok:false), grouped by error class
  - Cite occurrences with no manifest entry at all
  - Oldest fetched_at timestamp

For every cite with ok:true:
  - READ the fetched text and verify the KB claim against THAT cite
    occurrence's surrounding KB context. Verification is cite-occurrence
    -level, not URL-level — the same URL can support one claim and fail
    another.
  - Do NOT substitute training-data recall.
  - Use the drift_type vocabulary in §1.3.1.
For ok:false / missing entries: fall back to the standard 3-query Tier-1
web-search method above. Note these gaps in the report.

The grounding adapter does NOT relax the Tier hierarchy, the Exclusion
Rule, the zero-tolerance fabrication rule, or model-family separation.
If no adapter has been run and no opt-out rationale is recorded, STOP and return to the Lead. If opt-out is recorded, proceed with the standard method and quote the rationale in the report.

EXECUTION CONSTRAINT:
Do NOT delegate or decompose this verification into sub-tasks or
sub-agents. Execute all verifications yourself, sequentially, in this
session. Sub-agent decomposition risks inconsistent verification
standards and makes it harder to track provenance of each verdict.

MECHANICAL PARALLEL CHECK (required):
Run Verbatim-Linter against the grounded source text and include its verdict with this report:

Run:

    & "[FRAMEWORK_ROOT]\Verbatim-Linter.ps1" `
        -KBRoot "[STATE_ROOT]" `
        -OutPath "[STATE_ROOT]\sources\verbatim_linter_phase5_2.md"

If Verbatim-Linter exits 2, treat the finding as BLOCKING for the affected definitional/operative passage.

OUTPUT FORMAT:
| # | Citation | File | Exists? | Correct? | Says what claimed? | Source URL | Verdict | Drift Type |
|---|----------|------|---------|----------|--------------------|-----------|---------|------------|

(The Drift Type column is populated only for cites verified via the
grounding adapter; otherwise leave blank. Vocabulary per
04-fact-checker.md §1.3.1.)

Summary: [N] confirmed, [N] corrected, [N] removed
Grounding: run / opt-out with rationale / unavailable
Verbatim-Linter: PASS / FINDINGS / BLOCKING (path: sources/verbatim_linter_phase5_2.md)
Removed citations (with search queries attempted): [list]
Table of Authorities update: [additions/removals]
```

