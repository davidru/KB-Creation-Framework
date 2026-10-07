# Fact-Checker Module — KB Creation Framework
# Version: 1.0 | Created: 2026-04-09
# Scope: Independent verification of ANY document — KBs, memos, emails, briefs, slide decks.
# Dependencies: Reads 01-shared-axioms.md for error patterns and thresholds.
# Independence: Does NOT read the Builder module. Does not know how the document was constructed.
#              This independence is the whole point — it breaks confirmation bias.

---

## PURPOSE

This module takes any document, extracts factual claims, verifies each against primary sources via web search, and produces a verification report with an accuracy score and suggested corrections.

It can be used:
- **In the KB pipeline** — as Phase 5.1-5.5 and Phase 6.4 fact-checking
- **Standalone on any document** — memos, emails, legal briefs, slide decks, analyst reports
- **As a periodic health check** — run against existing KBs on a refresh cycle
- **As a pre-send check** — verify a client memo before sending

The Fact-Checker never reads the Builder's instructions or logic. It doesn't know what the author intended. It only knows what the document says and whether that's true.

---

## SECTION 1: VERIFICATION PROTOCOL

### 1.1 Claim Extraction

Read the entire document. Extract every factual claim that can be independently verified. A "factual claim" is any statement that asserts something about the real world that is either true or false. This includes:

- **Numbers:** Revenue, headcount, market cap, patent counts, damages awarded, fines imposed
- **Dates:** Filing dates, effective dates, enactment dates, verdict dates, founding dates
- **Attributions:** Who said/did/decided something — entity names, person names, court names
- **Legal citations:** Statute numbers, case names, docket numbers, CFR references
- **Status claims:** "enacted," "pending," "proposed," "repealed," "settled," "ongoing"
- **Membership/participation claims:** SDO membership, coalition participation, board seats
- **Causal claims:** "X led to Y," "X was decided because of Z" (verify the factual predicate)

**Not factual claims** (do not verify):
- Analytical conclusions ("this suggests…", "the risk is…")
- Predictions ("likely to…", "expected to…")
- Framing/characterization (unless it mischaracterizes a holding or statute)

### 1.2 Prioritized Verification

Not all claims are equal. Verify in this priority order:

**Priority 1 — High-Volatility Fields** (verify ALL)
- Financial figures less than 12 months old
- Market cap, P/E, headcount, valuations
- Any number that changes quarterly or annually
- Legislative status (proposed/enacted/effective/repealed)
- Case status (pending/decided/appealed/settled)
- Administrative rule status (proposed/final/vacated/stayed)
- Any claim tagged `[VOLATILE:*]` by the Builder

**Priority 1a — Single-Source Claims** (verify ALL)
- Claims that appear in only one builder's output (flagged in the mandatory Phase 4.0 single-source inventory)
- These have the highest fabrication risk because they weren't independently corroborated by the second builder
- Apply the same 3-search-query minimum as the Exclusion Rule (Section 1.4)
- The Phase 4.0 single-source inventory is mandatory output from `prompts/40-lead-comparison.md`; `Validate-Phase4Inventory.ps1` enforces the schema mechanically. If the inventory is missing or malformed, STOP and require Phase 4.0 remediation. Do NOT reconstruct the inventory from builder drafts.

**Priority 2 — Attribution Claims** (verify ALL)
- "Company X committed to…" — verify it was Company X, not a subsidiary or predecessor
- "Court held that…" — verify the holding, not just the case name
- "Statute requires…" — verify the requirement, not just the citation
- "Settlement of $X…" — verify amount, parties, and date

**Priority 2a — Operative-Mechanism Claims** (verify ALL in legal/regulatory/standards KBs)
The operative *mechanism* of a rule is as load-bearing as the number attached to it, and it goes wrong the same way. Verify the mechanism against the verbatim provision, not just the value:
- **Indexation / adjustment cadence** — "annually" vs. "every 3 years" vs. fixed schedule. Read the indexation subsection; do NOT assume annual. The value can be right while the cadence is wrong.
- **Reporting / notification clocks** — a multi-tier clock is multiple claims (a 48h / 10d / 30d structure is three). Verify every tier, the trigger that selects each tier, and which actor each binds. A missing tier is a finding.
- **Trigger / threshold logic** — does the obligation key on entity class, claim type, risk tier, or transaction type? "Applies to Class IIb/III devices" vs. "applies to any actor making a restricted claim" are different rules; these are routinely conflated.
- **Duty-holder scope** — verify the exact class the provision binds. When a regulation narrows a statute's broad term to a defined subset (e.g., "hospitals are the prescribed health care institutions"), cite the narrowed term, not the statute's broad term.
- **Penalty structure** — individual vs. body-corporate, civil vs. criminal, strict-liability vs. ordinary, per-event vs. continuing: each variant is a separate claim.
A CONFIRMED verdict requires a verbatim quote of the operative provision OR a preserved `[NEEDS-VERIFICATION]` flag. A plausible-sounding mechanism asserted without the provision text is a finding even when the number is correct. (Shared Axioms Pattern 14, Lesson 33; Phase 5.5 / `prompts/55-factcheck-operative-claims.md`.)

**Priority 2b — Cross-Reference / Cross-Topic Consistency** (verify ALL)
When the same operative or definitional claim appears in more than one file/section, the restatements drift. For every claim that appears in ≥2 places:
- Designate the **canonical** statement (the section that quotes or most fully states the source) and diff every restatement against it.
- A restatement that drops a qualifier, a tier, a threshold variant, an exception, or an enumerated limb the canonical preserves is a finding — treat it identically to a paraphrase-drop in the canonical itself.
- Where two topics state the same obligation differently (e.g., Topic A: 10d+30d; Topic B: 10d+48h), neither is presumed correct: verify both against primary source and reconcile to the full structure.
- **Self-corroboration does not count.** A value that appears in two KB files, in a prior memo, in a persona/instruction file, or in any AI-authored artifact has been copied, not independently confirmed. Operative values require a Tier 1 primary source; exclude the operator's own prior outputs from the corroboration set. (Shared Axioms Patterns 15–16, Lessons 34–35; Phase 5.5 / `prompts/55-factcheck-operative-claims.md`.)

**Priority 3 — Standards & IP** (verify ALL in legal KBs)
- Membership vs. implementation claims
- RF vs. RAND commitment scope
- Standard version specificity
- Patent pledge scope and conditions

**Priority 4 — General Claims** (sample-based)
- Historical facts, founding dates, acquisition details
- Biographical information
- Market descriptions, competitive positioning
- For these, a 25-claim sample is acceptable for audit purposes

### 1.3 Verification Method

For EVERY claim verified:

1. **Search** — Use web search with specific, targeted queries. Search for the primary source, not commentary.
2. **Source hierarchy:**
   - Tier 1: Primary sources (SEC filings, court dockets, agency press releases, official SDO records, statute text)
   - Tier 2: Authoritative secondary (major law firms, Reuters/Bloomberg, official company statements)
   - Tier 3: General secondary (news articles, Wikipedia, analyst reports)
   - Tier 4: Unverifiable — **and only after** the Blocked-Source Escalation rule below has been run to exhaustion. "Unverifiable" means *no source exists* or *the source is behind a permanent wall after the full fetch chain failed* — NOT "the default fetch returned a 403/SPA shell."
3. **Record** — Log the claim, the source used, the source tier, and the verdict.
4. **Do not rely on training data** — Every verification must come from a live web search. Your training data is not a source.

#### 1.3.0 Blocked-Source Escalation (MANDATORY before any access-based "Unverifiable" verdict)

A primary source that *exists* may not be dispositioned `[NEEDS-VERIFICATION]` / Unverifiable for an **access** reason until the full Primary-Source Access Fallback Chain has been attempted and logged. This closes Shared-Axioms **Pattern 17** (Premature Unverifiable). The build-time grounding pass already mandates this chain (`03-builder.md`; `05-build-orchestrator.md` Phase 6.5); the fact-check side now does too.

**Distinguish two failure modes — they get different verdicts:**
- **Access-failure** — the source exists but the default fetch was blocked (HTTP 403, JS-SPA/`<app-root>` shell, Cloudflare "just a moment…" / Turnstile, legacy IUAM stub, PDF link loaded async). → **You MUST escalate the fetch chain** before any verdict. This is not optional and not "route to manual."
- **Genuine absence** — the source does not exist publicly (e.g., executive regulations not yet published, a guidance document never issued). → Legitimately `[NEEDS-VERIFICATION]`, but the flag text must name the specific tiers attempted and why each failed (do not write a bare "unverifiable").

**Escalation procedure:**
1. **Consult `../host-registry.md`** for the host's recorded minimum tier; start there, not at Tier 1.
2. **Walk the chain** until the source renders or the chain is exhausted: Tier 0 structured API → 1 `web_search`/Wayback → 2 `curl_cffi` (TLS impersonation; also try a `/download` or static-PDF endpoint directly) → 2.5 `cloudscraper` → 3 Playwright → 4 Camoufox → 5 patchright (Cloudflare interactive challenge) → 6 Scrapling StealthyFetcher (Cloudflare Turnstile). The `adapters/crawl4ai-fetch/` scripts automate Tiers 2–6.
3. **Validate fetch shape, not HTTP status** (host-registry content-shape validators: TOC-only shell, SPA shell, CF challenge, Turnstile, IUAM stub, empty regulator page).
4. **Log every escalation** in the verification report (host, attempted tier, failure mode, successful tier) and **append the discovery to `../host-registry.md`** so the next build inherits the working tier.
5. **Only after the chain is exhausted** may the claim be marked Unverifiable. Permanent walls (Akamai Bot Manager, PerimeterX, authenticated-session, true paywall) are the only legitimate access-based Unverifiable — name the wall and the tiers attempted. For older content, also try Wayback / archive.today; for current content behind a permanent wall, request user-paste.

**Empirical basis (June 2026):** SFDA `sfda.gov.sa` JS-SPA cracked with Scrapling Tier 6 (exposed the Implementing Regulation + MDS-REQ 11 reporting-clock PDFs); UAE `uaelegislation.gov.ae` full decree-law PDF retrieved with curl_cffi Tier 2 on the first attempt from the `/download` endpoint after the prior round had marked it "403/blocked." Both had been carried as NEEDS-VERIFICATION purely because the default fetch was blocked.

### 1.3.1 Optional Grounding Adapter

When a grounding adapter (see `adapters/`) has been run for the document under review, the Fact-Checker MUST prefer the **fetched primary-source text** over its own training-data recall for any cite that has grounding available. Grounding is **optional at the pipeline level** (you choose whether to run the adapter) but **mandatory at consumption** — once a manifest exists, the fact-checker may not ignore it for cites it covers.

**Why it matters.** Pilot evidence (SEPs KB, May 2026, single-model controlled A/B over 57 cites): the model-recall baseline returned `SUPPORTED/HIGH` on 9 cites that the grounded variant correctly flagged as `UNSUPPORTED` — including a live 404 GovInfo URL the baseline blessed because the domain "looked authoritative," and several landing-page URLs cited as authority for paragraph-level holdings the landing pages don't contain. Grounding also resolves knowledge-cutoff conservatism on post-cutoff cases (the pilot's `[2025] EWCA Civ 182` example moved baseline `UNCERTAIN` → grounded `SUPPORTED/HIGH` after reading the judgment). Full report: `../pilots/crawl4ai-2026-05/report/decision.md`.

**What the consuming session receives.**

The grounding adapter produces three artifacts at `<state-root>/grounding/`:

1. `cites.json` — one record per **cite occurrence** (`url × source_file × line × surrounding context`). A given URL appears once per occurrence; the same URL cited at three places in two files yields three records.
2. `fetch_log.json` — one record per **unique URL** (the fetcher dedupes for efficiency). Fields: `url`, `hash`, `ok`, `via`, `bytes`, `out_path`, `fetched_at`, `error`.
3. `sources/<sha1>.md` — fetched primary-source markdown, one file per unique URL.
4. (Optional) `packets/<file>.md` — pre-built per-source-file packets that already join `cites.json` × `fetch_log.json` and inline the fetched text under each cite occurrence's KB context. **Use packets when running the fact-check via copy-paste or as one sub-agent per source file.**

**Verification is cite-occurrence-level, not URL-level.** A single URL can support one proposition and fail another. Always evaluate each cite occurrence against the fetched text in light of *that occurrence's surrounding KB context*. Joining `cites.json` × `fetch_log.json` by URL is required if you are not consuming the pre-built packets.

**How the fact-checker consumes the grounding.**

1. **Coverage preflight** (mandatory before verification, when a manifest is present). Report:
   - Total cite occurrences in scope
   - Unique URLs fetched (`ok: true`)
   - Failed fetches (`ok: false`) grouped by error class
   - Cite occurrences without any manifest entry at all
   - Cache freshness (oldest `fetched_at` timestamp; for Phase 6.4 SUPERSET, max age should be ≤24h or the adapter should be re-run with `--refresh`)
2. For every cite with `ok: true`, READ the fetched text and verify the KB claim against it. Do **not** substitute training-data recall.
3. For every cite with `ok: false` or no manifest entry, **first apply the Blocked-Source Escalation rule (§1.3.0)** — an `ok: false` is usually an *access-failure*, not a genuine gap, so walk the fetch chain (curl_cffi → … → Scrapling) per `../host-registry.md` before anything else. Only if the chain is exhausted do you fall back to the standard web-search method (Tier 1 source preferred, 3-query minimum) and note the cite so the Lead can route the residual to manual. Do NOT route an unescalated `ok: false` straight to manual or to an Unverifiable verdict.
4. The adapter does NOT replace any other v3 fact-check protocol element. The Tier 1/2/3 source hierarchy, the Exclusion Rule, the model-family separation requirement, and the SUPERSET re-verification at Phase 6.4 all still apply. Grounding gives the fact-checker better *primary inputs*; it does not relax independence requirements.

**Drift-type vocabulary** (use in the verification report's `drift_type` column when grounding is in use):

`wrong_provision` · `wrong_jurisdiction` · `wrong_document` · `overstated` · `mischaracterized` · `attribution_error` · `missing_attribution` · `stale` · `no_longer_at_url` · `unsupported` · `other`

These map to and refine the existing verdict taxonomy in Section 2; they do not replace it.

**Cache staleness — important for Phase 6.4.** The fetcher writes `fetched_at` on every record and reuses cached entries within `--max-age-days` (default 7). For Phase 6.4 SUPERSET verification, run the adapter with `--refresh` (or `--max-age-days 0`) to force re-fetch. Otherwise stale cache can silently mask `no_longer_at_url` / live-404 drift that is the whole point of grounded verification.

**Adapter scope.** Currently a single adapter exists (`adapters/crawl4ai-fetch/`) which uses Crawl4AI + a PDF fallback, and bundles the Tier 2–6 fetch-chain scripts (curl_cffi, cloudscraper, patchright, Scrapling). Coverage on tier-1 government/court sources reaches ~95% with the PDF fallback bundled. The residual (~5%) is mostly **access-failure, not genuine absence** — anti-bot 403s, JS-SPA shells, and Cloudflare-gated portals are recoverable by escalating the fetch chain (§1.3.0), and MUST be escalated before being treated as gaps. (Empirical: the SaMD survey's "EU Lex CELEX deep links / anti-bot 403 sites" that had been written off were later cracked at Tier 2 curl_cffi and Tier 6 Scrapling.) Only Akamai Bot Manager / PerimeterX / authenticated-session / true paywall hosts are **permanent** gaps after the chain is exhausted; those are flagged in the manifest and routed to manual. The current adapter grounds **URL citations only** — non-URL legal citations (statute citations, case reporters, treatises) are not in scope and are verified by the standard method.


### 1.4 Exclusion Rule (CRITICAL)

If you are about to exclude a claim as fabricated:

**STOP. Search first.**

- Run at least 3 different search queries targeting the claim
- Log all queries and results
- Only exclude if ALL searches return zero corroborating results
- If ANY credible source corroborates, the claim stays (possibly with correction)

This rule exists because overcautious exclusion is the #1 critical error pattern (see Shared Axioms, Pattern 5). Real events that seem implausible have been incorrectly removed. The cost of keeping a true claim is zero. The cost of removing one is permanent information loss.

---

## SECTION 2: VERDICT CLASSIFICATIONS

| Verdict | Definition | Action |
|---------|-----------|--------|
| **Confirmed** | Claim matches primary/secondary source | Retain as-is |
| **Wrong** | Claim contradicts primary source | Correct with source citation |
| **Stale** | Claim was correct but is now outdated | Update to current value |
| **Superseded** | Legal authority has been replaced by newer one | Update to current authority |
| **Partially Correct** | Directionally right but imprecise or missing context | Add precision or context |
| **Unverifiable** | Cannot confirm or deny after reasonable search | Tag [UNVERIFIABLE] with explanation |
| **Misattributed** | Correct fact, wrong entity/source | Correct the attribution |

### Error Rate Calculation

```
Error Rate = (Wrong + Stale + Superseded + Misattributed) / Total Claims Verified
```

Partially Correct and Unverifiable do NOT count toward the error rate but are reported separately.

---

## SECTION 3: REPORT FORMAT

Every fact-check produces a verification report in this format:

```markdown
# Fact-Check Report — [Document Name]
# Date: [date]
# Checker: [model name and version]
# Document type: [KB / memo / email / brief / other]
# Claims verified: [N]
# Error rate: [X%]

## Summary
- Confirmed: [N] ([%])
- Wrong: [N] ([%])
- Stale: [N] ([%])
- Superseded: [N] ([%])
- Misattributed: [N] ([%])
- Partially Correct: [N] ([%])
- Unverifiable: [N] ([%])

## Disposition
[Based on error rate and document type, per Shared Axioms Section 5:]
- SHIP / SHIP WITH CORRECTIONS / RE-AUDIT / REBUILD

## Findings

### Priority 1: High-Volatility Fields
| # | Claim | File/Location | Source | Source Tier | Verdict | Correction |
|---|-------|--------------|--------|-------------|---------|------------|
| 1 | [claim text] | [file:line or section] | [URL] | [1-4] | [verdict] | [if needed] |

### Priority 2: Attribution Claims
[same table format]

### Priority 3: Standards & IP
[same table format]

### Priority 4: General Claims
[same table format]

## Error Patterns Detected
[Tag each error with a pattern from Shared Axioms Section 3]
| Pattern | Count | Examples |
|---------|-------|---------|
| [pattern name] | [N] | [brief description] |

## Corrections Summary
[Ordered list of all corrections to apply, with file locations and exact old→new text]

## Pattern Promotion Candidates
[If any pattern appears 3+ times in this document, or if this is the 3rd+ KB
where a pattern has appeared, flag for Shared Axioms promotion]
```

---

## SECTION 4: VERIFICATION LOG

In addition to the report, the Fact-Checker produces a **verification log** — a per-KB append-only record of every claim ever verified. This provides claim-level provenance.

```markdown
# Verification Log — [KB Name]
# Append-only. Do not delete entries.

| Date | Claim | File | Source URL | Source Tier | Verdict | Checker Model |
|------|-------|------|-----------|-------------|---------|--------------|
| 2026-04-09 | FY2025 revenue $23.77B | 09-financial-analysis.md | [SEC link] | 1 | Confirmed | GPT-5.4 |
```

This log enables:
- **Traceability:** For any claim, trace back to when it was verified, by whom, against what source
- **Staleness detection:** The Refresh Orchestrator can query "claims last verified >90 days ago"
- **Confidence scoring:** Claims verified against Tier 1 sources have higher confidence than Tier 3

---

## SECTION 5: OPERATING MODES

### Mode 1: Full Pipeline Fact-Check
- Triggered by: Builder handoff or Orchestrator
- Scope: Entire KB, minimum 50 claims
- Output: Full report + verification log entries
- Used during: KB creation pipeline (Phases 5.1-5.5 and 6.4)

### Mode 2: Final Audit (Phase 7.0)
- Triggered by: Build Orchestrator after assembly, post-assembly fact-check, and quality-tier audit
- Scope: Dedicated final audit per `prompts/70-final-audit.md`, including a 25-claim spot-check across the required categories and review of required v3 artifacts
- Output: Final audit report, error-rate disposition, and Quality Scorecard artifacts
- Used during: KB creation pipeline Phase 7.0
- Completion: Mode 2 culminates in automatic invocation of `Generate-QualityScorecard.ps1` to produce `audit/kb-quality-scorecard.md`, `audit/kb-quality.json`, and `audit/kb-quality-history.json` updates

### Mode 3: Refresh Audit
- Triggered by: Refresh Orchestrator on cadence
- Scope: Focus on high-volatility fields and recently changed legal authorities
- Output: Audit report + development log entries (for breaking news detection)
- Used during: Periodic maintenance

### Mode 4: Document Verification
- Triggered by: User request (any document)
- Scope: All factual claims in the document
- Output: Verification report with accuracy score
- Used for: Memos, emails, briefs, presentations — anything with factual claims

### Mode 5: Correction Verification
- Triggered by: After corrections are applied to a KB
- Scope: Only the corrected claims (verify the fixes didn't introduce new errors)
- Output: Targeted report
- Used during: Post-correction re-audit (addresses Pattern 22: "prior audits can introduce new errors")

---

## SECTION 6: INDEPENDENCE REQUIREMENTS

The Fact-Checker's value comes from its independence. These rules protect that independence:

1. **Never read the Builder module.** You don't know how the document was built. You don't care.
2. **Never read builder drafts.** You verify the finished product, not the working papers.
3. **Never read comparison reports except the Phase 4.0 single-source inventory supplied for Phase 5.4.** The Lead's judgment about which builder was better is irrelevant to whether a claim is true; only the mandatory inventory is a fact-check input.
4. **Read Shared Axioms only for:** error pattern taxonomy, error-rate thresholds, voice/tone guidance, and model behavior profiles. Not for build process details.
5. **Treat every document the same** regardless of how it was produced — same protocol for a KB, a memo, or a slide deck.
6. **Do not assume prior verification.** Even if a claim has a source citation in the document, verify it independently. Citations can be wrong, stale, or fabricated.

---

## SECTION 7: FEEDBACK TO SHARED AXIOMS

### Option C Promotion Process

After every fact-check:

1. **Tag each error** with a pattern from the taxonomy (Shared Axioms Section 3)
2. **Append pattern counts** to the master audit log
3. **Check threshold:** Has this pattern now appeared in 3+ KBs?
4. **If yes:** Draft a lesson for Shared Axioms Section 7. Format:
   ```
   [N]. (v[version]) [One-sentence lesson title].
   [2-3 sentence explanation with specific examples from the KBs where the pattern appeared].
   [Recommended detection/prevention method].
   ```
5. **Flag for human review.** The draft lesson is a suggestion, not an automatic addition.

### Master Audit Log Entry

After every fact-check, append to the master audit log:

```
| Date | Document | Type | Claims | Error Rate | Top Patterns | Disposition | Promotions |
```

This creates a longitudinal record of accuracy across the entire portfolio.

---

*This module operates independently on any document. It produces verification reports and feeds findings back to Shared Axioms through the Option C process. It never reads the Builder module.*
