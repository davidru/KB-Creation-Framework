# Final Audit + Quality Scorecard Generation — legal KB-type override

**Phase:** 7.0
**Override of:** `prompts/70-final-audit.md`
**Applies when:** scoping_report.md sets `kb_type: legal_topic`
**Loaded by:** `prompts/01-orchestrator.md` (routes to this override when kb_type matches)

This override file does NOT replace the parent prompt. The parent prompt's full content applies; this override is read by the agent AFTER the parent prompt and adjusts specific behaviors per the KB type.

## What this override changes

The parent prompt requires the auditor to rate every shipped file, calculate error rate, classify findings, confirm Phase 6.5 A-tier conditions, write `sources/audit_report.md`, and generate the Quality Scorecard. This legal override tells the auditor how to apply those instructions to a legal_topic KB.

The final audit must emphasize statute-version currency, holding accuracy, regulatory status, classification correctness, operative-mechanism fidelity, qualifier preservation, and cross-reference fidelity. Legal KBs fail when a correct-looking citation points to the wrong subsection, a case holding is overstated after subsequent treatment, or a summary drops a qualifier from canonical legal text.

The Quality Scorecard profile for legal_topic weights qualifier_preservation at 0.25 and cross_reference_fidelity at 0.20. The auditor should explicitly discuss those dimensions in the Summary and Findings rather than treating them as secondary details.

## Adjusted rules

1. In the parent prompt's error-rate numerator, count stale statutory/regulatory text, wrong section/subsection, holding overstatement, unsupported legal conclusion, wrong classification, wrong operative trigger, missing qualifier, and cross-reference drift as material unless clearly minor.
2. Sample legal claims to cover every authority type present: statutes, regulations, cases, agency guidance, enforcement orders, standards, and regulatory filings. Do not let financial/company-style claims crowd out legal authority checks.
3. Confirm statute and regulation version currency where the KB presents current legal requirements. Check amendment/effective dates and rule status for high-impact authorities.
4. Confirm case-law claims by holding, court, year, posture, and subsequent treatment where the KB relies on them.
5. Confirm classification claims against source text: statutory tier, regulatory class, duty-holder category, RF/RAND or commitment scope, binding/non-binding status.
6. Treat any source-tag removal, unresolved-verification erasure, or qualifier drop from canonical text as a blocker or material finding depending on scope.

## Adjusted thresholds / verdicts

Legal_topic thresholds for the parent prompt's Quality Rating Scale verdict:

| Error rate / findings | Decision |
|---|---|
| <4%, no blockers, scorecard PASS or PASS-WITH-CAVEATS | Ship after corrections; proceed to Phase 8.0. |
| 4-8%, or localized material legal findings | Targeted corrections and re-audit corrected claims plus affected Phase 6.2/6.3/6.4/6.5 gates. |
| 8-12%, systemic legal-authority weakness, or repeated qualifier/cross-reference drift | Expanded targeted re-audit; presume rebuild unless errors are tightly localized. |
| >12%, blockers unresolved, C-tier regression, or scorecard FAIL | Full multi-model rebuild or return to Phase 2.0/4.0 depending on root cause. |

A single wrong controlling statute, overruled case cited as good law, wrong regulatory class, or wrong operative duty-holder may require targeted re-audit even if the percentage is below 4%.

## Source-tier weighting

Tier 1 legal authorities control audit findings: official statute/regulation/code/gazette, court opinion/docket, agency publication, official standard/SDO record, enforcement order, consent decree, or regulatory filing. Tier 2 can explain or locate, but cannot cure a missing Tier 1 check for a legal claim. Tier 3 carries no audit-confirmation weight.

The generated Quality Scorecard must use the legal_topic weights in `audit-templates/kb-quality-dimensions.yaml` when `kb_type: legal_topic` is present.

## Examples

- Error rate is 3%, but the sole error is a wrong duty-holder for the core compliance obligation. Verdict: targeted correction plus re-audit of affected topic, not casual ship.
- Scorecard PASS-WITH-CAVEATS with qualifier_preservation just above threshold may ship only if all identified qualifier fixes are applied and logged.
