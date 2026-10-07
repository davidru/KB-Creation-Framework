# Single-Source Claim Verification (Phase 5.4)

**Role:** Independent fact-check agent
**Input:** Single-source claim inventory from Phase 4.0 comparison report
**Output:** sources/factcheck_single_source.md
**Runs:** In parallel with Phases 5.1/5.2/5.3
**Model:** Different family than the Lead AND different than whoever runs Phase 5.2. If Phase 5.2 is GPT-5.4, Phase 5.4 should be Goldeneye or Claude Opus.

---

## Why This Phase Exists

Per 01-shared-axioms.md Lesson 30: claims that appear in only one builder's output have the highest fabrication risk because they were not independently corroborated. The CDPR "February 2025 second attack" fabrication survived the pipeline because it appeared only in Builder A and was plausible-sounding. Phase 4's comparison report flags these as a separate inventory, but verification still happens in the standard Phase 5.2 citation check, where they get the same treatment as multi-source claims. This phase gives them dedicated, model-independent, primary-source-required treatment.

---

## Prompt

```
You are verifying a high-risk subset of claims in the [KB_NAME]
knowledge base: claims that appeared in ONLY ONE builder's draft.
Single-source claims have the highest fabrication risk in this
pipeline.

CLAIMS TO VERIFY:
[Paste the single-source claim inventory from
 sources/comparison_report.md, Section "Single-source claim inventory"]

For each claim, the inventory must specify:
- The claim text
- Which builder originated it (A or B)
- The KB section where it appears in that builder's v2 draft

If the inventory is missing any of these fields, STOP and report the
gap before proceeding. Phase 4.0 must produce a complete inventory.

TASK:

For each single-source claim:

1. PRIMARY-SOURCE REQUIREMENT
   You must verify against a Tier 1 source (per 04-fact-checker.md):
   official statute text, court opinion, agency publication,
   regulatory filing, or company SEC filing.
   - Tier 2 (authoritative secondary, e.g., established legal
     treatise) is acceptable ONLY if Tier 1 is unavailable AND the
     Tier 2 source itself cites Tier 1.
   - Tier 3 (general web sources, news aggregators, Wikipedia) is
     NEVER sufficient for a single-source claim. If only Tier 3
     sources exist, treat the claim as unverified.

2. CORROBORATION REQUIREMENT
   Run AT LEAST 3 distinct search queries for each claim. Log every
   query and the top results. Single-query verification is not
   acceptable for this phase.

3. SPECIFICITY REQUIREMENT
   For numbers, dates, entity names, and citations: the source must
   match exactly. "Approximately matches" is not a verification.
   - Date drift (Pattern 1): exact date or remove
   - Attribution confusion (Pattern 2): exact entity or remove
   - Wrong jurisdiction (Pattern 7): exact court or remove
   - Entity suffix fabrication (Pattern 11): exact corporate name
     or remove

4. EXCLUSION SAFEGUARD (Pattern 5)
   Before classifying a claim as fabricated, exhaust your search:
   - At least 3 search queries
   - Search the originating builder's plausible source candidates
   - Note search terms used and results returned
   Implausibility is not evidence of fabrication. Many real events
   look implausible. Document the search before excluding.

OPTIONAL GROUNDING (per 04-fact-checker.md §1.3.1):
Single-source claims are the highest-fabrication-risk subset and
benefit most from primary-source grounding.

If a grounding adapter is in use:
  - You must be given [STATE_ROOT]/grounding/cites.json,
    fetch_log.json, sources/ (or pre-built packets/). If a grounding/
    directory exists in state but you were not given these inputs,
    STOP and request them.
  - Run the coverage preflight (cite-occurrence count, ok:true /
    ok:false counts, unmanifested cites, oldest fetched_at) before
    verification.
  - For each single-source claim that cites a URL with ok:true, READ
    the fetched text and verify the claim against THAT cite
    occurrence's surrounding context BEFORE running additional web
    searches. The fetched text is your primary input.
  - For claims with no URL, ok:false fetches, or missing manifest
    entries, FIRST apply Blocked-Source Escalation (04-fact-checker.md
    §1.3.0; Shared Axioms Pattern 17): an ok:false is usually an
    access-failure (403/SPA/Cloudflare/async-PDF), not a missing source.
    Walk the fetch fallback chain (curl_cffi → cloudscraper → Playwright
    → Camoufox → patchright → Scrapling; try /download and static-PDF
    endpoints) per ../host-registry.md before running the standard
    3-query protocol. Only after the chain is exhausted does the
    standard 3-query Tier-1-required protocol apply in full.
  - Use the drift_type vocabulary in §1.3.1 in the output table.

Grounding does NOT relax the model-family separation requirement
(this Phase 5.4 checker MUST still come from a different family than Phase 5.2),
the 3-query minimum for non-grounded cites, the Tier-1 requirement,
or the FABRICATED → REMOVE rule. If no adapter has been run, ignore
this block.

VERDICT CLASSIFICATIONS:
- CONFIRMED — Tier 1 source matches the claim exactly. Cite URL.
- CORRECTED — Claim is approximately right but specifics are wrong.
  Provide the corrected version with source URL.
- FABRICATED — No Tier 1 or sufficient Tier 2 source after
  exhaustive search. Claim must be REMOVED from the KB. Not flagged.
  Removed. NOTE: "exhaustive search" REQUIRES that Blocked-Source
  Escalation (§1.3.0) was walked to exhaustion — never label a claim
  FABRICATED because the source's default fetch returned 403/SPA/
  Cloudflare. A source that is confirmed to EXIST but is access-blocked
  is not fabricated; it is UNVERIFIABLE-ACCESS-BLOCKED (below).
- UNVERIFIABLE-LEGITIMATE — The claim is plausibly true (e.g.,
  internal corporate process, private SDO membership) but no public
  source exists. Claim must be either REMOVED or tagged
  [UNVERIFIED] in the assembled KB. Default is removal; tag only
  with explicit Lead approval.
- UNVERIFIABLE-ACCESS-BLOCKED — A specific public source is known to
  EXIST and support the claim, but it sits behind a permanent wall
  (Akamai/PerimeterX/auth/paywall) AFTER the §1.3.0 fetch chain was
  walked to exhaustion. Distinct from FABRICATED (no source) and from
  UNVERIFIABLE-LEGITIMATE (no public source). Retain the claim with a
  [NEEDS-VERIFICATION] flag naming the source and the tiers attempted;
  do NOT remove a true-but-walled provision. Surface to the Lead.

ZERO TOLERANCE RULE:
For single-source claims, the threshold for retention is higher than
for multi-source claims. If you cannot verify with a Tier 1 source
or a Tier 1-citing Tier 2 source, the claim is removed from the
assembled KB.

EXECUTION CONSTRAINT:
Do NOT delegate or decompose this verification into sub-tasks.
Execute all verifications yourself, sequentially, in this session.

OUTPUT FORMAT:

# Single-Source Claim Verification

## Summary
- Claims verified: [N]
- Confirmed: [N]
- Corrected: [N]
- Fabricated (REMOVE): [N]
- Unverifiable-legitimate: [N]

## Per-Claim Verification
| # | Claim | Originating Builder | Search Queries | Source Tier | URL | Verdict | Drift Type | Correction (if any) |
|---|-------|--------------------|-----------------|-------------|-----|---------|------------|----------------------|

(Drift Type column populated only for claims verified via the
grounding adapter; otherwise leave blank. Vocabulary per
04-fact-checker.md §1.3.1.)

## BLOCKING for Phase 6.0 Assembly
List every claim with verdict FABRICATED. These MUST be removed from
the assembled KB regardless of which builder is used as backbone.

## Lead Review Required
List every claim with verdict UNVERIFIABLE-LEGITIMATE. The Lead
decides whether to remove or tag [UNVERIFIED] for each.
```

---

## Decision Logic for the Lead

| Verdict | Action |
|---------|--------|
| Confirmed | Claim survives to assembly |
| Corrected | Apply correction in Phase 6.0 assembly; verify the correction in Phase 6.4 |
| Fabricated | Remove from assembly. Mandatory. No exceptions. |
| Unverifiable-legitimate | Lead decides per claim: remove (default) or tag [UNVERIFIED] in assembled KB |

---

## Anti-Patterns

- **Treating a Tier 3 source as verification.** Wikipedia, news aggregators, secondary blog posts do not verify single-source claims. The whole point of this phase is heightened verification.
- **Skipping the 3-query minimum.** One query is fast but insufficient. The 3-query rule exists to prevent both false-positive fabrication calls and false-negative confirmations.
- **Tagging instead of removing.** [UNVERIFIED] in the assembled KB is a last resort, not a default. Removal is the default.
- **Same model as Phase 5.2.** If Phase 5.2 and Phase 5.4 use the same model family, the independent-corroboration value is lost.

