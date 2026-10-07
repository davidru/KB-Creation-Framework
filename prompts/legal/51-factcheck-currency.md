# Fact-Check: Currency Verification — legal KB-type override

**Phase:** 5.1
**Override of:** `prompts/51-factcheck-currency.md`
**Applies when:** scoping_report.md sets `kb_type: legal_topic`
**Loaded by:** `prompts/01-orchestrator.md` (routes to this override when kb_type matches)

This override file does NOT replace the parent prompt. The parent prompt's full content applies; this override is read by the agent AFTER the parent prompt and adjusts specific behaviors per the KB type.

## What this override changes

The parent prompt's STATUTES, CASES, REGULATIONS, AGENCY GUIDANCE, and CHARACTERIZATION VS. OPERATIVE HOOK checks apply at full strength. For legal_topic KBs, those checks are not generic freshness checks; they are the highest-priority shipping gate because the KB is expected to support legal analysis and downstream work product.

This override makes the parent prompt's lines on statute force, case treatment, CFR currency, rule status, and operative-hook comparison stricter. The checker must verify not only that an authority exists, but that the cited version, amendment state, holding, regulatory status, and operative hook are the current load-bearing authority for the KB's claim.

The override also keeps Phase 5.1 focused on legal-authority currency rather than company-style volatile-data refresh. A legal currency miss includes stale statutory text, wrong subsequent treatment, a vacated/stayed rule cited as operative, or a correct cite attached to the wrong legal trigger.

## Adjusted rules

1. Treat every statute, regulation, agency guidance document, case, enforcement order, standard, and regulatory filing as potentially version-sensitive. Verify current effective text, amendment date, recodification history, and pending amendments where the parent prompt asks whether the authority is current.
2. For case law, expand the parent prompt's good-law check to include later appellate treatment, vacatur, settlement-driven mootness where relevant, jurisdictional limitation, and whether the KB's stated holding survives subsequent narrowing.
3. For CFR and analogous regulatory provisions, verify section number, part/subpart, effective date, rule status, and any stay/vacatur. A proposed, stayed, withdrawn, or vacated rule may be discussed only with the matching status label.
4. Apply the parent prompt's CHARACTERIZATION VS. OPERATIVE HOOK check to every load-bearing legal provision, not just obvious statutes. Compare trigger verb, duty-holder, scope clause, exception, timing, and threshold against pulled text.
5. If the cite exists but the KB maps the claim to the wrong operative hook, classify the result as Wrong; cite existence does not cure a characterization error.

## Adjusted thresholds / verdicts

Legal_topic audit tolerance: error rate <4% may ship after corrections; 4-8% requires targeted corrections and re-audit; 8-12% is high-risk and presumptively requires expanded re-audit; >12% requires full multi-model rebuild. In Phase 5.1, any stale statute cited as current, overruled/vacated case cited as good law, vacated/stayed rule cited as operative, or wrong operative hook is BLOCKING until corrected.

Use the parent prompt's verdict vocabulary, but treat Distinguished/Narrowed as material when the KB omitted the limitation. Treat Superseded, Overruled/Vacated/Withdrawn, and Wrong as blockers for legal_topic KBs unless the assembled text preserves that status explicitly.

## Source-tier weighting

Tier 1 controls: official statute text, official code or gazette, court opinion/docket, agency publication, official regulator database, authoritative standard text, or regulatory filing. Tier 2 may help identify subsequent treatment but cannot confirm legal currency alone. Tier 3 general web/news is never sufficient for a legal currency verdict.

When primary access is blocked, run the parent prompt's blocked-source escalation path before recording any access-based gap. Do not downgrade to secondary summaries merely because a regulator or court site is hard to fetch.

## Examples

- A KB says a rule is "final" and cites the right CFR section, but the current docket shows the rule is stayed. Verdict: Stale/Wrong; correction must label the stay.
- A statute section exists, but the KB says it applies to "providers" when the text binds only "manufacturers." Verdict: Wrong operative hook; cite existence does not cure the characterization error.
