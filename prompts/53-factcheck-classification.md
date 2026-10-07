# Fact-Check: Classification Verification (Decomposed — Phase 5.3)

**Role:** Lead or dedicated fact-check agent
**Input:** Classification claims from v2 drafts
**Output:** Classification verification results
**Runs:** Once per build; can run in parallel with Phases 5.1 and 5.2
**Why decomposed:** Highest-impact legal check; deserves full attention
**Reference:** 04-fact-checker.md for full verification protocol

---

## Prompt

```
You are verifying the classifications and categorizations in the
[KB_NAME] knowledge base.

CLASSIFICATIONS TO VERIFY:
[Paste the list of classification claims — statutory tiers, regulatory
categories, entity types, standard designations, commitment types]

TASK:
For each classification claim, verify via web search:

1. STATUTORY TIER MAPPINGS:
   - Is the activity classified under the correct statute section?
   - Is the regulatory tier (e.g., Tier I vs. Tier II) correct?
   - Does the classification match the actual statutory text?

2. ENTITY CLASSIFICATIONS:
   - Corporate structure: parent vs. subsidiary, LLC vs. Inc.
   - Regulatory status: registered vs. exempt, domestic vs. foreign
   - Verify from SEC filings or official registrations

3. STANDARD DESIGNATIONS:
   - RF vs. RAND commitment scope — verify the exact commitment
   - Standard version specificity — don't extrapolate across versions
   - Membership vs. implementation claims
   (01-shared-axioms.md Pattern 10: Version Extrapolation)

4. COMMITMENT TYPE CLAIMS:
   - "Voluntary" vs. "mandatory" — verify the legal basis
   - "Binding" vs. "non-binding" — verify enforceability
   - Consent decree terms — verify exact obligations

VERIFICATION METHOD:
- Primary sources: statute text, regulatory filings, SDO records,
  consent decree text, official patent declarations
- NEVER infer a classification — verify it from source text
- Entity suffix accuracy: verify exact legal name
  (01-shared-axioms.md Pattern 11: Entity Suffix Fabrication)

OPTIONAL GROUNDING (per 04-fact-checker.md §1.3.1):
Classification claims often turn on the exact text of the cited
source (statutory tier, RF/RAND commitment scope, consent decree
obligations, entity status). If a grounding adapter has been run
and a classification claim cites a URL with ok:true in the manifest,
READ the fetched text first and verify the classification against
THAT cite occurrence's surrounding context. Do not substitute model
recall. The fetched text is your primary input for that claim.

If the fetched text does not contain the basis for the
classification (or is a landing page / wrong document), record
ok:true-but-insufficient and fall back to the standard primary-
source verification method above.

Grounding does NOT relax the "NEVER infer" rule, the entity-suffix
discipline, or the model-family separation requirement. If no
adapter has been run, ignore this block.

EXECUTION CONSTRAINT:
Do NOT delegate or decompose this verification into sub-tasks or
sub-agents. Execute all verifications yourself, sequentially, in this
session. Sub-agent decomposition risks inconsistent verification
standards and makes it harder to track provenance of each verdict.

OUTPUT FORMAT:
| # | Claim | Category | As Classified | Correct Classification | Source | Verdict | Drift Type |
|---|-------|----------|--------------|----------------------|--------|---------|------------|

(Drift Type column populated only for claims verified via the
grounding adapter; otherwise leave blank. Vocabulary per
04-fact-checker.md §1.3.1.)

Summary: [N] confirmed, [N] corrected, [N] unverifiable
BLOCKING items (wrong statutory tier or commitment type): [list]
Corrections to apply: [old → new with source citation]
```

