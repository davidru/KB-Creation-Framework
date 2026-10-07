# Fact-Check: Currency Verification — company KB-type override

**Phase:** 5.1
**Override of:** `prompts/51-factcheck-currency.md`
**Applies when:** scoping_report.md sets `kb_type: company`
**Loaded by:** `prompts/01-orchestrator.md` (routes to this override when kb_type matches)

This override file does NOT replace the parent prompt. The parent prompt's full content applies where relevant to company/entity facts; legal-authority subsections apply when the company KB itself contains legal-authority claims. This override is read by the agent AFTER the parent prompt and adjusts specific behaviors per the KB type.

## What this override changes

The parent prompt is written around legal authorities: statutes, cases, regulations, agency guidance, and administrative proceedings. For company KBs, apply the same currency discipline to company facts, but translate the focal objects to filings, official disclosures, leadership, market data, corporate transactions, litigation posture, and earnings-cycle updates.

The legal-style "still in force" and "still good law" subsections do not apply unless the company KB itself contains a legal-authority claim. Instead, the checker verifies that company facts match the latest 10-K, 10-Q, 8-K, proxy, investor-relations release, official corporate page, regulator filing, docket, or exchange notice. Volatile fields must carry current-source dates and tags where needed.

The parent prompt's CHARACTERIZATION VS. OPERATIVE HOOK check still matters, but the company version asks whether the fact has been attached to the right corporate hook: correct entity, reporting period, transaction status, role title, financial metric, subsidiary, or agreement.

## Adjusted rules

1. For public companies, verify recency against the latest applicable SEC filing cadence: annual report, most recent quarterly report, material 8-Ks, proxy statement, and current investor-relations disclosures.
2. For private, acquired, foreign, or subsidiary entities, verify against official registries, parent filings, regulator databases, corporate disclosures, or signed/announced transaction documents.
3. For company sections with no court-case or legal-authority claim, substitute executive-transition, board-composition, headquarters, listing status, acquisition/merger, bankruptcy, and material-business-line currency checks for the parent prompt's case-law good-law check.
4. Verify market cap, revenue, headcount, segment data, patent counts, litigation counts, and standards-membership data with source dates. Tag volatile values such as `[VOLATILE:market-data]`, `[VOLATILE:leadership]`, or equivalent when the fact will age quickly.
5. Apply the characterization-vs-hook discipline to corporate facts: the right number attached to the wrong fiscal year, entity, segment, subsidiary, transaction step, or filing period is Wrong.

## Adjusted thresholds / verdicts

Company KB audit tolerance is broader than legal_topic tolerance: error rate <8% may ship after corrections; 8-16% requires targeted corrections and re-audit; 16-20% is high-risk and presumptively requires expanded re-audit; >20% requires full rebuild. In Phase 5.1, stale leadership, stale listing/acquisition status, or stale financial data is material when the KB presents it as current.

Use the parent prompt's verdict vocabulary by analogy: Confirmed, Stale, Superseded, Withdrawn, Wrong. "Distinguished/Narrowed" normally does not apply to company facts unless the cited legal authority is itself being checked.

## Source-tier weighting

Tier 1 for company currency means SEC/EDGAR filings, official corporate disclosures, exchange notices, signed agreements, regulator filings, court dockets, and official registries. Tier 2 sources such as Bloomberg, Reuters, established trade press, exchange data vendors, or reputable market-data providers may confirm public-domain volatile facts when Tier 1 does not publish the exact current value.

Tier 3 general web is insufficient for institutional facts such as corporate structure, leadership, subsidiaries, contractual relationships, or Microsoft-facing posture. Volatile market or leadership facts verified from Tier 2 should be tagged with the appropriate `[VOLATILE:*]` marker and source date.

## Examples

- A KB lists an executive as CFO based on last year's 10-K, but a later 8-K reports a successor. Verdict: Stale; correction must cite the later 8-K.
- A market cap is sourced from a reputable market-data page rather than an SEC filing. Verdict: acceptable if dated and tagged `[VOLATILE:market-data]`.
