# Fact-Check: Citation Verification — legal KB-type override

**Phase:** 5.2
**Override of:** `prompts/52-factcheck-citations.md`
**Applies when:** scoping_report.md sets `kb_type: legal_topic`
**Loaded by:** `prompts/01-orchestrator.md` (routes to this override when kb_type matches)

This override file does NOT replace the parent prompt. The parent prompt's full content applies; this override is read by the agent AFTER the parent prompt and adjusts specific behaviors per the KB type.

## What this override changes

The parent prompt verifies whether each citation exists, is correct, says what the KB claims, and preserves cross-reference fidelity. For legal_topic KBs, this override makes primary-law verification the controlling standard: the cited legal authority must be checked against the statute, regulation, court opinion, official agency publication, regulatory filing, or standard itself.

The parent prompt's zero-tolerance rule remains intact, but the search burden is stricter for claims requiring Tier 1 support. A legal cite is not confirmed because a law-firm alert, news article, or general web page repeats it. Those sources can help locate the primary authority; they cannot replace it.

The parent prompt's CROSS-REFERENCE FIDELITY section is especially important for legal KBs because summaries often restate statutory obligations across topics. This override directs the checker to compare cross-references against the canonical statutory or regulatory provision and the canonical KB statement where one exists.

## Adjusted rules

1. For every Tier-1-required legal claim, run at least three targeted searches before exclusion or downgrade. Queries should vary the authority name, citation string, issuing body, and quoted operative phrase.
2. Confirm legal citations only against Tier 1 sources: statute/code text, regulation, court opinion, official docket, agency publication, official enforcement order, official SDO record, or regulatory filing.
3. Treat Tier 2/3 sources as locator aids only for legal propositions. A law-firm article may point to an agency rule; it does not verify the rule's text or current status.
4. Verify citation granularity: title, article, section, subsection, paragraph, annex, rule, footnote, case court/year, and reporter/docket where applicable. A correct source with the wrong subparagraph is a citation failure.
5. For KB cross-references, compare the restatement to the canonical KB passage and then spot-check the canonical passage against primary text if the cross-reference carries operative or definitional content.
6. Preserve the parent prompt's grounding-adapter and Verbatim-Linter requirements; grounding does not relax primary-law review.

## Adjusted thresholds / verdicts

Legal_topic error thresholds: <4% ship after corrections; 4-8% targeted corrections plus re-audit; 8-12% expanded re-audit/high-risk; >12% full rebuild. In Phase 5.2, any fabricated legal cite, wrong section/subsection for the proposition, source that does not say what claimed, or cross-reference qualifier drop is a material finding.

Tier 3 is never sufficient for a legal citation verdict. If only Tier 3 support exists after the three-query minimum and blocked-source escalation, remove the citation or mark the claim unresolved according to the parent prompt's tag discipline.

## Source-tier weighting

Tier 1 carries dispositive weight: official statute/regulation/gazette/code, court opinion or docket, agency publication, regulator database, official standard or SDO declaration, enforcement order, consent decree, or regulatory filing. Tier 2 may support background and subsequent-treatment leads, but cannot independently confirm the cited legal proposition. Tier 3 has no confirmation value for legal claims.

When source text is blocked, follow the parent prompt's blocked-source escalation and grounding rules before treating the cite as unverifiable. Access failure is not citation failure until the escalation chain is exhausted.

## Examples

- A law-firm article quotes a statute accurately but the KB cites only the article for a legal duty. Verdict: citation not confirmed until the statute text is checked and cited.
- Topic 09 summarizes an Article 14 reporting clock but drops one tier that Topic 06 preserves. Verdict: cross-reference fidelity failure; correct the restatement to the canonical/primary structure.
