# Post-Assembly Fact-Check (Phase 6.4) — SUPERSET MODE

**Role:** Lead or dedicated fact-check agent
**Input:** Assembled KB files (full/) + new claims manifest (from Phase 6) + Phase 5 results (5.1/5.2/5.3/5.4)
**Output:** Verification of EVERY citation and factual claim in the assembled KB
**Runs:** Once, after register lint (Phase 6.2) and extraction/filename validation (Phase 6.3)
**Why this exists:** Phase 5 verified claims in the v2 drafts using one model on a different document. Assembly typically generates 2-3x the content (the Trade/Export Controls test build produced 685KB from 193KB of builder drafts — meaning ~490KB / 70% was new content). A delta-only verification leaves both the new content AND any survived-from-v2 errors at risk. Superset mode re-verifies everything in the assembled KB, with manifest claims receiving Priority 1 treatment.
**Reference:** 04-fact-checker.md for verification protocol
**Model:** A model from a DIFFERENT family than whoever ran Phase 5.2. If Phase 5.2 was GPT-5.4, Phase 6.4 should be Goldeneye or Claude Opus.

---

## Mandatory Preflight

Before the fact-checker begins, validate Phase 4.0's single-source claim inventory. This closes the Phase 4 → Phase 5.4 / 6.4 contract gap.

```powershell
& "[FRAMEWORK_ROOT]\Validate-Phase4Inventory.ps1" `
    -ComparisonReportPath "[STATE_ROOT]\sources\comparison_report.md" `
    -OutPath "[STATE_ROOT]\sources\phase4_inventory_validation.md"
```

If validation fails, STOP. Fix `sources/comparison_report.md` Section 6 before Phase 6.4.

## Prompt

```
You are verifying the factual accuracy of the ASSEMBLED [KB_NAME]
knowledge base. This is a SUPERSET verification: every citation and
factual claim in the assembled KB is in scope, not just claims added
during assembly.

INPUTS:
- Assembled KB files (full/ directory)
- NEW CLAIMS MANIFEST: [paste from sources/new_claims_manifest.md]
  (Claims in the manifest receive Priority 1 treatment.)
- Phase 5 results: [paste from sources/factcheck_currency.md,
  factcheck_citations.md, factcheck_classification.md,
  factcheck_single_source.md]
  (Claims previously CONFIRMED in Phase 5 receive Priority 3
  treatment — re-verify against the assembled-KB phrasing, but
  exhaustive re-search is not required unless the assembled phrasing
  changes the claim's meaning.)

TASK:

Verify EVERY citation and factual claim in the assembled KB,
prioritized as follows:

PRIORITY 1 — Claims in the new claims manifest (added during assembly)
  - Full verification per Phase 5.2/5.4 protocol (3+ search queries,
    Tier 1 source preferred, exact specificity required).

PRIORITY 2 — Claims NOT in the manifest but for which the assembled
  phrasing materially differs from the v2 phrasing (paraphrase,
  trimmed context, combined with another claim)
  - Full verification: the rephrasing may have changed the meaning
    even if the underlying claim was previously verified. (Lesson 24:
    paraphrasing statutory provisions can lose the operative trigger.)

PRIORITY 3 — Claims that survived verbatim or near-verbatim from a
  Phase 5-CONFIRMED v2 claim
  - Lighter-touch verification: confirm the claim still appears
    intact in the assembled KB, spot-check 1 in 5 against the prior
    Phase 5 result. If any spot-check fails, escalate ALL Priority 3
    claims to Priority 2 treatment.

VERIFICATION DIMENSIONS (apply at the appropriate priority level):

1. CITATIONS:
   - Does the cited source exist?
   - Is the citation correct (parties, reporter, year, section)?
   - Does the source say what the KB claims?
   - Apply zero-tolerance standard.

2. FACTUAL CLAIMS:
   - Dollar amounts, dates, percentages, thresholds
   - Entity names, agency names, program names
   - Statutory section numbers, CFR references
   - Verify each via web search against primary sources.

3. ENFORCEMENT CASES:
   - Does the case exist?
   - Are the parties, amounts, and dates correct?
   - Is the holding/outcome accurately described?

4. CLASSIFICATIONS:
   - Statutory tier mappings
   - Regulatory categories
   - Entity type classifications
   - Verify against source text.

5. REGISTER FIDELITY (cross-check with Phase 6.2):
   - Does any unmarked paragraph (presented as authority) actually
     synthesize from multiple sources or apply practitioner
     judgment? If yes, flag for re-tag.

6. CROSS-REFERENCE FIDELITY:
   - Identify every passage that re-states an operative or
     definitional claim whose canonical statement lives in another
     topic, section, or derived view within the assembled KB
     (topic-to-topic, full-to-authority, full-to-Quick-Reference,
     full-to-table-of-authorities).
   - For each cross-reference, locate the canonical statement and
     compare. Flag any qualifier, exception, threshold variant,
     scope clause, term-of-art, enumerated limb, or numeric/temporal
     anchor present in the canonical but absent from the
     cross-reference.
   - Treat any paraphrase-drop as a MATERIAL finding — same severity
     as a Priority 2 paraphrase-introduced primary-source drift. The
     failure mode this dimension exists to catch: the canonical
     correctly states "at least five years, or the expected use time
     where shorter"; a cross-reference summary in another topic says
     "minimum five years" and drops the carveout; a drafter working
     from the cross-reference inherits the drop. (Empirical: EU CRA
     KB Topic 07, 2026-05-19.)
   - Fix by either (a) restoring the dropped qualifier in the
     cross-reference text, or (b) replacing the cross-reference with
     a verbatim quote of the canonical and an attributed pointer
     ("canonical: Topic 02 §4.1").

VERIFICATION METHOD (per 04-fact-checker.md):
- Web search with specific, targeted queries
- Use primary sources: official statute text, court databases, CFR,
  agency press releases
- Source hierarchy: Tier 1 (primary) > Tier 2 (authoritative) > Tier 3
- BLOCKED-SOURCE ESCALATION IS MANDATORY (04-fact-checker.md §1.3.0;
  Shared Axioms Pattern 17): if a primary source returns a 403, a
  JS-SPA shell, a Cloudflare/Turnstile challenge, or an async PDF link,
  that is an ACCESS-FAILURE, not a missing source. Walk the fetch
  fallback chain (Tier 0 API → web_search/Wayback → curl_cffi [try a
  /download or static-PDF endpoint] → cloudscraper → Playwright →
  Camoufox → patchright → Scrapling) per ../host-registry.md BEFORE
  treating the claim as unverifiable. Log the working tier; append it
  to the registry.
- Do NOT rely on training data
- Record the source URL for every Priority 1 and Priority 2
  verification

DEFAULT-ON GROUNDING (per 04-fact-checker.md §1.3.1):
Phase 6.4 is the highest-leverage place for grounding because it is a SUPERSET pass. Re-run the Crawl4AI grounding adapter with `--refresh` (or `--max-age-days 0`) against assembled `full/` unless `sources/scoping_report.md` and `sources/pipeline_state.md` record an explicit opt-out rationale. If a grounding adapter is in use:
  - You must be given [STATE_ROOT]/grounding/cites.json,
    fetch_log.json, sources/ (or pre-built packets/). If a grounding/
    directory exists in state but you were not given these inputs,
    STOP and request them.
  - Before Phase 6.4, the adapter SHOULD have been re-run with
    --refresh (or --max-age-days 0) against the assembled full/ —
    stale cache silently masks no_longer_at_url drift, which is one
    of the failure modes Phase 6.4 exists to catch.
  - Run the coverage preflight (cite-occurrence count, ok:true /
    ok:false counts, unmanifested cites, oldest fetched_at) before
    verification.
  - For every cite with ok:true, READ the fetched text and verify
    each cite occurrence against its surrounding assembled-KB context.
    Verification is cite-occurrence-level — same URL × different KB
    context = different verdict possible.
  - For ok:false / missing entries, FIRST apply Blocked-Source
    Escalation (§1.3.0) — an ok:false is usually an access-failure, so
    walk the fetch chain (curl_cffi → … → Scrapling) per host-registry
    before anything else. Only if the chain is exhausted, fall back to
    the standard web-search method and note any cite the adapter could
    not resolve so the Lead can route the residual to manual.
  - Use the drift_type vocabulary in §1.3.1 in the Verification Table.
The adapter does NOT relax the Tier hierarchy, the Exclusion Rule,
the Priority 1 / 2 / 3 staging, or the model-family-separation
requirement (this Phase 6.4 checker MUST still come from a different family
than Phase 5.2). If no adapter has been run and no opt-out rationale is recorded, STOP and return to the Lead. If opt-out is recorded, quote the rationale in the report and proceed with the standard method.

EXECUTION CONSTRAINT:
Do NOT delegate or decompose this verification into sub-tasks or
sub-agents. Execute all verifications yourself, sequentially, in this
session. Sub-agent decomposition risks inconsistent verification
standards and makes it harder to track provenance of each verdict.

ZERO TOLERANCE RULE:
If any Priority 1 or Priority 2 claim cannot be verified after
reasonable search (3+ queries) AND after Blocked-Source Escalation
(§1.3.0) — i.e., the fetch fallback chain has been walked to
exhaustion — it must be REMOVED from the KB. Not flagged — removed.
EXCEPTION: do NOT remove a claim merely because the default fetch was
blocked (403/SPA/Cloudflare) — that is an access-failure, not a
verification failure. Escalate the chain first. If the source is
confirmed to EXIST but sits behind a permanent wall (Akamai/PerimeterX/
auth/paywall) after the chain is exhausted, retain the claim with a
[NEEDS-VERIFICATION] flag naming the tiers attempted, rather than
deleting a true-but-walled provision.

EXCLUSION SAFEGUARD:
Before removing any claim, run at least 3 different search queries.
Log the queries. Only exclude if ALL searches return zero results.
(01-shared-axioms.md Pattern 5: Overcautious Exclusion)

OUTPUT FORMAT:

## Summary
- Priority 1 claims (manifest): [N] checked, [N] confirmed, [N] corrected, [N] removed
- Priority 2 claims (rephrased from v2): [N] checked, [N] confirmed, [N] corrected, [N] removed
- Priority 3 claims (survived intact): [N] spot-checked, [N] confirmed, [N] escalated
- Register-fidelity flags: [N] paragraphs
- Grounding: run/refreshed or opt-out rationale quoted
- Phase 4 inventory validation: PASS (path: sources/phase4_inventory_validation.md)

## Verification Table
| # | Priority | Claim | File | Type | Verification | Source URL | Verdict | Drift Type |
|---|----------|-------|------|------|-------------|-----------|---------|------------|

(Drift Type column populated only for cites verified via the
grounding adapter; otherwise leave blank. Vocabulary per
04-fact-checker.md §1.3.1.)

## BLOCKING items
Fabricated citations, wrong amounts, incorrect classifications,
overruled cases cited as current — list with corrections.

## Non-Blocking items
Minor date imprecision, format inconsistency, register flags for
re-tag review.

## If full/ Is Edited
Any blocking-item correction that touches full/ MUST trigger:
1. Re-run register lint (Phase 6.2) on edited files
2. Re-run authority-view extraction (Phase 6.3)
3. Re-run filename validation (Phase 6.3) on edited files
```

---

## Prompt
[REPLACED IN SUPERSET MODE — see prompt block above. The content below this line is retained for historical reference only.]

```
[Legacy delta-only prompt removed. Use the SUPERSET prompt above.]
```

