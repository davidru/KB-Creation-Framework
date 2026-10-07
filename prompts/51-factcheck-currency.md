# Fact-Check: Currency Verification (Decomposed — Phase 5.1)

**Role:** Lead or dedicated fact-check agent
**Input:** Claim list from v2 drafts (statutes, cases, regulations)
**Output:** Currency verification results
**Runs:** Once per build; can run in parallel with Phases 5.2 and 5.3
**Why decomposed:** Discrete verification task; full attention prevents "run out of steam"
**Reference:** 04-fact-checker.md for full verification protocol

---

## Prompt

```
You are verifying the currency of legal authorities cited in the
[KB_NAME] knowledge base.

CLAIMS TO VERIFY:
[Paste the list of statutes, cases, regulations, agency guidance,
 and administrative rules from both v2 drafts]

TASK:
For each authority cited, verify via web search:

1. STATUTES:
   - Is the statute still in force?
   - Has it been amended since the date cited?
   - Has it been repealed or superseded?
   - Is the section number cited correct?

2. CASES:
   - Is the case still good law?
   - Has it been reversed, vacated, or superseded by a higher court?
   - Has it been distinguished, narrowed, or limited by later
     decisions in the same circuit or by the Supreme Court?
   - Has it been overruled (explicitly or implicitly)?
   - Is the holding as characterized in the KB still the holding
     after subsequent treatment?

3. REGULATIONS:
   - Is the regulation current?
   - Has the CFR section been updated, recodified, or removed?
   - Are any proposed rules pending that would change it?
   - Is the rule status correct? (proposed / interim final / final /
     vacated / stayed / withdrawn) — match against any
     [VOLATILE:rule-status] tags in the v2 drafts.

4. AGENCY GUIDANCE:
   - Is the guidance still in effect?
   - Has it been withdrawn, superseded, rescinded, or replaced?
   - Has the issuing office been reorganized in a way that affects
     the guidance's authority?
   - For sub-regulatory guidance (FAQs, policy statements, no-action
     letters): does the document still appear on the agency's site?

5. ADMINISTRATIVE PROCEEDINGS / ENFORCEMENT:
   - Have ongoing proceedings cited as "pending" reached resolution?
   - Have settlements or consent decrees been modified or terminated?

6. CHARACTERIZATION VS. OPERATIVE HOOK (MANDATORY):
   - Pull the actual subsection text for every load-bearing statutory/regulatory/standard provision.
   - Compare the KB's characterization against the operative hook verbatim: trigger verb, duty-holder, scope clause, exception, timing, and threshold.
   - Flag cases where the cite exists but the KB describes the wrong hook. This closes framework-review Finding 3.

VERIFICATION METHOD (per 04-fact-checker.md):
- Web search with specific, targeted queries
- Use primary sources: official statute text, court databases, CFR
- Source hierarchy: Tier 1 (primary) > Tier 2 (authoritative) > Tier 3 (general)
- BLOCKED-SOURCE ESCALATION IS MANDATORY (04-fact-checker.md §1.3.0;
  Shared Axioms Pattern 17): currency checks routinely hit regulator
  portals that 403, render as JS-SPAs, or sit behind Cloudflare. A
  blocked fetch is an ACCESS-FAILURE, not evidence the authority lapsed
  or was superseded. Walk the fetch fallback chain (Tier 0 API →
  web_search/Wayback → curl_cffi [try /download or static-PDF endpoints]
  → cloudscraper → Playwright → Camoufox → patchright → Scrapling) per
  ../host-registry.md before recording an authority as stale,
  superseded, or unverifiable. Log the working tier to the registry.
- Do NOT rely on training data

EXECUTION CONSTRAINT:
Do NOT delegate or decompose this verification into sub-tasks or
sub-agents. Execute all verifications yourself, sequentially, in this
session. Sub-agent decomposition risks inconsistent verification
standards and makes it harder to track provenance of each verdict.

VERDICT CLASSIFICATIONS:
- Confirmed: still current and accurately described
- Stale: was correct, now outdated
- Superseded: replaced by newer authority
- Distinguished/Narrowed: still good law but limited in scope
- Overruled/Vacated/Withdrawn: no longer authoritative
- Wrong: never correct, or materially mischaracterized

OUTPUT FORMAT:
| # | Authority | Type | As Cited | Current Status | Subsequent Treatment | Operative hook text checked? | Source | Verdict |
|---|-----------|------|----------|---------------|----------------------|---|--------|---------|

Summary: [N] confirmed, [N] stale, [N] superseded, [N] distinguished/narrowed, [N] overruled/vacated/withdrawn, [N] wrong
BLOCKING items (repealed statutes, overruled cases, withdrawn guidance, vacated rules cited as current): [list]
```

