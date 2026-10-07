# Fact-Check: Classification Verification — legal KB-type override

**Phase:** 5.3
**Override of:** `prompts/53-factcheck-classification.md`
**Applies when:** scoping_report.md sets `kb_type: legal_topic`
**Loaded by:** `prompts/01-orchestrator.md` (routes to this override when kb_type matches)

This override file does NOT replace the parent prompt. The parent prompt's full content applies; this override is read by the agent AFTER the parent prompt and adjusts specific behaviors per the KB type.

## What this override changes

The parent prompt already covers statutory tier mappings, entity classifications, standard designations, and commitment-type claims. For legal_topic KBs, the classification check is primarily a text-bound legal classification exercise: the checker must confirm that the KB maps activities, actors, products, obligations, commitments, and standards to the exact legal category the source creates.

This override narrows the parent prompt's company-style entity checks to the legal classification issues that matter in regulatory KBs: regulated party status, product class, risk tier, duty-holder category, mandatory/voluntary status, binding/non-binding status, and standard or commitment scope. The checker never infers classification from functional similarity, industry shorthand, or common practice.

Legal classification errors are often cite-shaped: the citation exists, but the KB maps the claim to the wrong class, title, rule, Annex, article, or commitment. The override treats those as material even when the broad topic is correct.

## Adjusted rules

1. Verify statutory tier mappings from source text: title, chapter, article, section, part, rule, annex, schedule, and defined term. Do not accept a secondary summary of the mapping.
2. For regulatory classes, verify the criteria that assign the class or tier, not merely an example list. Device class, risk class, data category, duty-holder role, sector designation, and exemption status must match the source's classification logic.
3. For commitment-type claims, distinguish voluntary vs mandatory, binding vs non-binding, guidance vs rule, recommended practice vs enforceable duty, RF vs RAND, and declaration scope vs implementation claim.
4. For standards designations, verify exact standard version, patent-policy scope, declaration record, and membership vs implementation. Do not extrapolate a commitment across versions or families.
5. If the KB says an activity falls under a category, pull the provision that defines the category and the provision that applies it when those are separate.
6. Treat a classification supported only by inference, analogy, or industry shorthand as Unverifiable or Wrong unless the primary source supplies the mapping.

## Adjusted thresholds / verdicts

Legal_topic thresholds: <4% ship after corrections; 4-8% targeted corrections plus re-audit; 8-12% expanded re-audit/high-risk; >12% full rebuild. In Phase 5.3, wrong statutory tier, wrong regulatory class, wrong duty-holder classification, wrong commitment type, or wrong standard-designation scope is BLOCKING until corrected.

Use the parent prompt's Confirmed/Corrected/Unverifiable verdicts, but classify "correct general area, wrong legal category" as Corrected rather than Confirmed. If a classification cannot be verified from primary or official source text, do not preserve it as a definitive category.

## Source-tier weighting

Tier 1 controls: statute, regulation, official guidance treated as operative, court order, consent decree, official SDO record, patent declaration, official regulator classification database, or regulatory filing. Tier 2 may help locate a classification issue but cannot confirm a legal classification alone. Tier 3 has no confirmation value.

Where grounding has fetched the cited source, read the exact occurrence context before running external searches. The grounded text is useful only if it contains the classification basis; landing pages or broad guidance pages are insufficient.

## Examples

- A KB says a requirement applies to Class IIb/III devices, but the source keys it to a restricted claim regardless of class. Verdict: Corrected classification; wrong trigger/class mapping.
- A standards file reports RAND obligations for a later version because the company declared to an earlier version. Verdict: Wrong unless the declaration expressly covers both versions.
