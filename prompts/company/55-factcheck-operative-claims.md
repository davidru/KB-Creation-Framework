# Fact-Check: Operative-Claim & Cross-Reference Fidelity — company KB-type override

**Phase:** 5.5
**Override of:** `prompts/55-factcheck-operative-claims.md`
**Applies when:** scoping_report.md sets `kb_type: company`
**Loaded by:** `prompts/01-orchestrator.md` (routes to this override when kb_type matches)

This override file does NOT replace the parent prompt. The parent prompt's full content applies; this override is read by the agent AFTER the parent prompt and adjusts specific behaviors per the KB type.

## What this override changes

The parent prompt says Phase 5.5 is skippable only for KBs with no operative provisions. This override clarifies that company KBs often do contain operative or quasi-operative claims even when they are not regulatory topic KBs: SEC filing windows, M&A milestones, covenant thresholds, listing-suspension triggers, consent-decree obligations, securities-law penalties, settlement obligations, and entity-level duties.

Part A applies, but the dimensions skew toward company mechanics. Indexation usually means quarterly or annual financial cadence rather than statutory penalty-unit adjustments. Reporting clocks often mean SEC form deadlines, exchange-notice windows, or contractual milestone dates. Trigger logic often turns on transaction status, financial thresholds, covenant metrics, listing rules, or regulatory registration status.

Part B shifts from statutory qualifier-drop to corporate-fact divergence. Company KBs commonly restate the same entity facts across business model, financials, litigation, corporate history, and Microsoft-relationship topics. The operative check should reconcile conflicting years, roles, entity scope, transaction milestones, and filing-period anchors.

## Adjusted rules

1. Run Part A for company claims that create or describe obligations, deadlines, thresholds, or conditions: SEC filing windows, exchange deadlines, merger covenants, financing covenants, consent decrees, settlement obligations, licensing commitments, regulatory registrations, or securities-law penalties.
2. Translate indexation/adjustment cadence into company cadence where appropriate: quarterly earnings, annual reports, proxy cycles, market-data refresh dates, headcount/segment reporting periods, or scheduled covenant tests.
3. For reporting clocks, verify form type, trigger event, due date/window, reporting entity, fiscal period, and whether an extension, amendment, or late filing changed the status.
4. For trigger/threshold logic, verify the threshold source: financial ratio, ownership percentage, deal condition, listing rule, materiality trigger, covenant event, or regulator action.
5. For duty-holder scope, distinguish parent vs subsidiary, issuer vs guarantor, registrant vs acquired target, operating company vs holding company, and entity-level vs group-level obligations.
6. For Part B, reconcile same-entity claims across topics: leadership dates, parent/subsidiary status, transaction stage, fiscal-year values, segment labels, litigation posture, and standards/IP commitments.

## Adjusted thresholds / verdicts

Company thresholds: <8% ship after corrections; 8-16% targeted corrections plus re-audit; 16-20% expanded re-audit/high-risk; >20% full rebuild. A company KB with no operative provisions may document a skip, but the presence of filing windows, deal covenants, penalties, consent decrees, or listing triggers means Phase 5.5 must run.

A CONFIRMED Part A verdict requires an official or high-authority source for the mechanism. A CONSISTENT Part B verdict requires that the same company fact use the same entity scope and time anchor across files. Conflicting values are RECONCILED findings even when both are plausible snapshots from different dates.

## Source-tier weighting

Tier 1: SEC filings, exchange rules/notices, signed agreements/exhibits, court orders/settlements/consent decrees, regulator filings, official corporate disclosures, official registries. Tier 2 can support volatile public-domain values or event reporting, but Tier 1 is required for obligations, covenants, filing clocks, penalties, and entity-scope mechanics. Tier 3 does not confirm operative company claims.

When a volatile fact is reconciled using Tier 2, preserve source date and `[VOLATILE:*]` tag so refresh cadence can catch drift.

## Examples

- A KB says a target "was acquired" based on signing announcement, but filings show closing conditions still pending. Verdict: RECONCILED; state signed/pending, not acquired.
- A filing deadline is stated for the parent, but the obligation binds only a subsidiary registrant. Verdict: CORRECTED-MECHANISM; duty-holder scope changed.
