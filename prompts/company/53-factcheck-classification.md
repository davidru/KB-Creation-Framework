# Fact-Check: Classification Verification — company KB-type override

**Phase:** 5.3
**Override of:** `prompts/53-factcheck-classification.md`
**Applies when:** scoping_report.md sets `kb_type: company`
**Loaded by:** `prompts/01-orchestrator.md` (routes to this override when kb_type matches)

This override file does NOT replace the parent prompt. The parent prompt's full content applies; this override is read by the agent AFTER the parent prompt and adjusts specific behaviors per the KB type.

## What this override changes

The parent prompt mixes legal tier mappings with entity classifications. For company KBs, classification verification centers on corporate and market identity: parent/subsidiary/JV structure, public/private/acquired status, domestic/foreign registration, regulated/exempt status, listing venue, reporting issuer status, industry classification, business-segment categorization, and standards or IP-position labels.

This override makes official filings and registrations the default proof for structural classifications. Corporate press releases can announce facts, but they are insufficient by themselves for stable structural classifications when filings, registry records, exchange notices, or transaction documents should exist.

Company classification errors often arise from stale or overbroad labels: former parent treated as current parent, acquired company described as public, business unit treated as legal entity, or secondary product line treated as primary industry. This override directs the checker to verify the exact entity and time period.

## Adjusted rules

1. Verify corporate structure from SEC filings, annual reports, official registries, transaction documents, regulator filings, or parent-company disclosures. Distinguish parent, subsidiary, affiliate, JV, division, brand, and product line.
2. Verify listing status from exchange notices, filings, official corporate disclosures, or regulator databases. Mark public/private/acquired/delisted status with the relevant date.
3. Verify regulatory status from official registrations or filings: registered/exempt, domestic/foreign, reporting/non-reporting, licensed/unlicensed, issuer/non-issuer, or sector-specific categories.
4. Verify industry classifications from NAICS/SIC in filings where available, and distinguish primary vs secondary lines of business from segment reporting or company disclosures.
5. Verify standards, patent, FRAND, or SDO classifications against official membership lists, declarations, patent-policy records, or filings; do not infer participation from implementation or vice versa.
6. Corporate press-release-only sourcing is insufficient for stable structural classifications unless no filing/registry source should exist and the claim is framed as company-announced.

## Adjusted thresholds / verdicts

Company thresholds: <8% ship after corrections; 8-16% targeted corrections plus re-audit; 16-20% expanded re-audit/high-risk; >20% full rebuild. Wrong parent/subsidiary status, public/private/acquired status, registered/exempt status, or primary industry classification is material because it changes how downstream readers understand the entity.

Use the parent prompt's Confirmed/Corrected/Unverifiable verdicts. Classify ambiguous press-release-only labels as Unverifiable or as a narrower "company describes itself as..." statement rather than a definitive structural classification.

## Source-tier weighting

Tier 1: SEC/EDGAR filings, annual reports, official registries, exchange notices, regulator databases, signed transaction documents, court dockets, official SDO and patent-declaration records. Tier 2: Bloomberg/Reuters, established trade press, reputable industry databases, company press releases for announced but not yet filed events. Tier 3: general web, scraped profiles, Wikipedia, blogs, and unverifiable aggregators.

For structural classifications, Tier 1 is required unless the fact is genuinely not recorded in a public official source; then downgrade the claim or preserve an explicit verification tag.

## Examples

- A KB calls a business a subsidiary, but filings show it is a division with no separate legal entity. Verdict: Corrected; revise to division/product-line language.
- A company press release announces an acquisition, but no closing filing exists yet. Verdict: company-announced pending transaction, not acquired/current subsidiary.
