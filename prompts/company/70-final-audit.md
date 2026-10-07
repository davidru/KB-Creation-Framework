# Final Audit + Quality Scorecard Generation — company KB-type override

**Phase:** 7.0
**Override of:** `prompts/70-final-audit.md`
**Applies when:** scoping_report.md sets `kb_type: company`
**Loaded by:** `prompts/01-orchestrator.md` (routes to this override when kb_type matches)

This override file does NOT replace the parent prompt. The parent prompt's full content applies; this override is read by the agent AFTER the parent prompt and adjusts specific behaviors per the KB type.

## What this override changes

The parent prompt's audit report, error-rate calculation, severity classification, Phase 6.5 confirmation, and Quality Scorecard generation all apply. This company override tells the auditor which failure modes matter most for a company/entity KB: corporate-structure correctness, leadership currency, filing-cadence verification, market-data currency, volatile-tag coverage, and citation density.

Company KBs tolerate more stale peripheral data than legal_topic KBs, but they are not loose. Wrong parent/subsidiary status, stale acquisition posture, invented institutional relationships, unsupported leadership claims, or mismatched filing-period financial data can mislead downstream strategy and must be counted as material.

The Quality Scorecard profile for company weights citation_density_and_primary_source_rate at 0.25 and volatile_tag_coverage at 0.15. The auditor should explicitly report whether high-volatility facts are dated, sourced, and tagged.

## Adjusted rules

1. In the parent prompt's numerator, count wrong corporate structure, stale leadership, stale listing/acquisition status, wrong fiscal period, unsupported institutional relationship, wrong litigation posture, missing volatile tag, and material citation gap as errors.
2. Sample to cover the full company profile: overview/business model, ownership and subsidiaries, leadership, financials, litigation, IP/patents, standards participation, policy positions, and Microsoft-relevant relationships if present.
3. Verify filings cadence: latest 10-K, 10-Q, 8-K, proxy, annual report, investor release, exchange notice, or registry source for current claims as applicable.
4. Verify volatile fields with source dates: market cap, headcount, revenue, segment data, executive roles, litigation counts, patent counts, standards participation, and pending transaction status.
5. Audit entity scope carefully. Parent facts, subsidiary facts, business-unit facts, and acquired-target facts are not interchangeable.
6. Treat unsourced named institutional relationships as material findings unless the source is user-provided in-session or an official/public record.

## Adjusted thresholds / verdicts

Company thresholds for the parent prompt's Quality Rating Scale verdict:

| Error rate / findings | Decision |
|---|---|
| <8%, no blockers, scorecard PASS or PASS-WITH-CAVEATS | Ship after corrections; proceed to Phase 8.0. |
| 8-16%, or localized material company/entity findings | Targeted corrections and re-audit corrected claims plus affected Phase 6.2/6.3/6.4/6.5 gates. |
| 16-20%, repeated stale volatile fields, or broad citation-density weakness | Expanded targeted re-audit; presume rebuild if corrections touch many topics. |
| >20%, blockers unresolved, C-tier regression, or scorecard FAIL | Full rebuild or return to Phase 2.0/4.0 depending on root cause. |

A low aggregate error rate does not excuse a wrong control/ownership classification, stale acquisition status, or fabricated institutional relationship.

## Source-tier weighting

Tier 1: SEC/EDGAR filings, official corporate disclosures, annual reports, investor-relations materials, exchange notices, signed agreements/exhibits, regulator filings, official registries, court dockets, and official SDO records. Tier 2: Bloomberg, Reuters, established trade press, reputable market-data or industry databases. Tier 3 does not support institutional facts.

The generated Quality Scorecard must use the company weights in `audit-templates/kb-quality-dimensions.yaml` when `kb_type: company` is present, with particular attention to citation density and volatile-tag coverage.

## Examples

- Error rate is 6%, but one error says an acquired company remains public. Verdict: targeted correction and re-audit of ownership/listing references.
- Market cap appears without date or volatile tag. Verdict: material volatile-tag coverage finding even if the number was accurate when written.
