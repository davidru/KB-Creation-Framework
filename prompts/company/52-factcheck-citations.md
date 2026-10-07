# Fact-Check: Citation Verification — company KB-type override

**Phase:** 5.2
**Override of:** `prompts/52-factcheck-citations.md`
**Applies when:** scoping_report.md sets `kb_type: company`
**Loaded by:** `prompts/01-orchestrator.md` (routes to this override when kb_type matches)

This override file does NOT replace the parent prompt. The parent prompt's full content applies; this override is read by the agent AFTER the parent prompt and adjusts specific behaviors per the KB type.

## What this override changes

The parent prompt's existence, correctness, says-what-claimed, grounding, and Verbatim-Linter rules all apply. This company override changes what counts as the best source for different claim types. SEC filings, official company disclosures, signed agreements, regulator filings, official registries, and court dockets are preferred for institutional facts; reputable Tier 2 business sources may be acceptable for public-domain facts that companies do not themselves publish in real time.

Unlike legal_topic KBs, not every company citation must terminate in a statute or official government text. Earnings dates, market data, analyst-call timing, public executive transition reporting, and current stock-market figures may be appropriately verified from Bloomberg, Reuters, exchange data, established trade press, or equivalent Tier 2 sources when the source date and volatility tag are preserved.

The parent prompt's cross-reference fidelity section applies by analogy. Company KBs are less likely to drop statutory qualifiers across topics, but they are prone to corporate-fact divergence: the same entity may be described with different parents, business segments, leadership titles, acquisition status, or fiscal-year numbers in separate files.

## Adjusted rules

1. Use Tier 1 for institutional facts: corporate structure, parent/subsidiary/JV status, leadership roles when officially disclosed, contractual relationships, regulatory status, material transactions, securities filings, docket facts, and signed agreements.
2. Permit Tier 2 without Tier 1 for public-domain and volatile facts that are not normally fixed in filings, such as intraday/current market cap, earnings-call date, routine trade-press event reporting, or current analyst consensus, if the claim is dated and tagged when volatile.
3. Do not use Tier 3 for institutional facts. General web pages, scraped profiles, Wikipedia, and unverified databases cannot confirm corporate structure, leadership, contracts, or Microsoft-facing relationships.
4. For filings, verify form type, filing date, fiscal period, exhibit number, page/section where available, and whether a later filing supersedes the cited proposition.
5. For cross-references, build a same-entity fact map across topics and flag inconsistent leadership years, parent/subsidiary status, acquired/public/private status, segment names, or financial periods.
6. Preserve grounding and Verbatim-Linter requirements where citations quote documents; company prose can still fabricate verbatim language or misattribute filing text.

## Adjusted thresholds / verdicts

Company thresholds: <8% ship after corrections; 8-16% targeted corrections plus re-audit; 16-20% expanded re-audit/high-risk; >20% full rebuild. Citation failures are material when they affect corporate structure, leadership, ownership, litigation posture, material agreements, financial figures, or Microsoft-relevant institutional facts.

A Tier 2-only citation can be Confirmed for public-domain volatile facts if it is reputable, current, dated, and tagged. The same Tier 2-only support is not sufficient for institutional facts unless no public Tier 1 exists and the claim is downgraded or tagged for confirmation.

## Source-tier weighting

Tier 1: SEC/EDGAR filings, official corporate disclosures, investor-relations materials, signed agreements/exhibits, regulator filings, official registries, exchange notices, court dockets, official SDO records. Tier 2: Bloomberg, Reuters, established trade press, reputable market-data providers, recognized industry databases. Tier 3: general news, Wikipedia, scraped corporate-profile pages, blogs, and unverified aggregators.

For volatile fields, record source date and tag: `[VOLATILE:market-data]`, `[VOLATILE:leadership]`, `[VOLATILE:event-date]`, or a more specific existing tag.

## Examples

- A Reuters report of next earnings date may confirm the date if the KB tags it as volatile and records the article date.
- A scraped profile says Company X owns Subsidiary Y, but no filing or official registry supports it. Verdict: not confirmed; remove or mark unresolved.
