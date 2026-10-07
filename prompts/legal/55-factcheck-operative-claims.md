# Fact-Check: Operative-Claim & Cross-Reference Fidelity — legal KB-type override

**Phase:** 5.5
**Override of:** `prompts/55-factcheck-operative-claims.md`
**Applies when:** scoping_report.md sets `kb_type: legal_topic`
**Loaded by:** `prompts/01-orchestrator.md` (routes to this override when kb_type matches)

This override file does NOT replace the parent prompt. The parent prompt's full content applies; this override is read by the agent AFTER the parent prompt and adjusts specific behaviors per the KB type.

## What this override changes

The parent prompt already makes operative-mechanism and cross-reference checks mandatory for legal, regulatory, and standards KBs carrying operative provisions. This legal override sets the expected depth. Every operative provision must be verified against pulled primary text, either quoted verbatim or restated with full qualifier preservation.

Part A of the parent prompt is applied in its strongest form: indexation cadence, multi-tier reporting clocks, trigger/threshold logic, duty-holder scope, and penalty structure are separate load-bearing dimensions. A correct number attached to the wrong trigger, wrong duty-holder, or incomplete tier structure is not confirmed.

Part B receives equal emphasis. Legal KBs frequently restate statutory or regulatory obligations across topics, quick references, authority views, and summary tables. Cross-reference drift is a real legal error, not a style issue, because downstream drafters may work from the summary layer.

## Adjusted rules

1. For every operative legal provision, pull the primary text and include either a verbatim quote or a structured restatement that preserves every qualifier, exception, threshold variant, scope clause, enumerated limb, duty-holder, trigger, and numeric/temporal anchor.
2. Treat each indexation rule, reporting tier, penalty variant, effective date, sunset, transition rule, notification clock, and conformity route as its own claim. Do not verify multi-tier structures as a single claim.
3. Confirm the mechanism, not just the value. If the dollar figure/day count is correct but the cadence, trigger, duty-holder, scope, or exception is wrong, use CORRECTED-MECHANISM or CORRECTED-VALUE as applicable.
4. Build the parent prompt's cross-reference map across all legal topics and derived views. Designate a canonical statement and diff every restatement against it.
5. Flag any dropped qualifier or collapsed tier as a material finding even if the short summary is directionally true.
6. If the source is blocked, complete blocked-source escalation before any UNVERIFIABLE disposition; legal operative text normally requires Tier 1.

## Adjusted thresholds / verdicts

Legal_topic thresholds: <4% ship after corrections; 4-8% targeted corrections plus re-audit; 8-12% expanded re-audit/high-risk; >12% full rebuild. In Phase 5.5, wrong mechanism, incomplete reporting clock, stale indexed value, missing penalty variant, wrong duty-holder, or cross-reference qualifier drop is BLOCKING until corrected or preserved as unresolved.

A CONFIRMED Part A verdict requires primary text and preserved mechanism. A CONSISTENT Part B verdict requires that every restatement preserve the canonical qualifiers, thresholds, and anchors. Summaries that omit material limits are RECONCILED findings, not acceptable compression.

## Source-tier weighting

Tier 1 only can confirm legal operative mechanisms: statute, regulation, official guidance where operative, court/order/consent decree, official standard, official regulator publication, or filing. Tier 2 can locate or explain but cannot confirm an operative mechanism or value. Tier 3 is not support.

For cross-references, the canonical KB statement is not primary support. Use it to detect internal drift, then verify the reconciled statement against Tier 1 primary text.

## Examples

- A summary states "support for five years" but the article says "five years or expected use, whichever is shorter." Verdict: RECONCILED; the qualifier must be restored wherever the summary appears.
- A penalty table gives the correct maximum amount but omits individual/body-corporate variants. Verdict: CORRECTED-MECHANISM; variants must be split into separate claims.
