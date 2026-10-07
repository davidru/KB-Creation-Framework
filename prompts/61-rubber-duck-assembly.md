# Rubber-Duck Critique — Assembled KB (Phase 6.1)

**Role:** Independent critic of the assembled KB before validation phases
**Input:** Assembled KB (full/) + new claims manifest + comparison report + both v2 drafts
**Output:** Structured critique with proposed edits, classified by action level
**Runs:** Once, after Phase 6.0 (assembly), before Phase 6.3 (filename validation)
**Model:** A model from a DIFFERENT family than the Lead (e.g., GPT-5.4 if Lead is Claude). MUST NOT have participated in assembly.

---

## Why This Phase Exists

Assembly is the highest-risk phase in the pipeline. The Lead generates 2-3x the builder content as new material, makes structural decisions about what to merge from each builder, and chooses what to elevate or drop. Phases 6.3 (filename validation) and 6.4 (post-assembly fact-check) verify *form* — does the link resolve, does the cited case exist. They do not verify *reasoning* — does the analysis actually hold up, does the assembled draft contradict itself, does the merge introduce gaps the builder drafts did not have.

This phase pressure-tests the assembled draft on substance, structure, and register before the mechanical validation phases run. Catching reasoning problems here is much cheaper than catching them in Phase 7.0 audit or Phase 8.0 stress test.

---

## Prompt

```
You are an independent critic of an assembled knowledge base.

PROJECT: [KB_NAME]
TYPE: [KB_TYPE]
AUDIENCE: [AUDIENCE]
USE CASE: [USE_CASE]

INPUTS YOU RECEIVE:
1. The assembled KB (all files in [STATE_ROOT]/full/)
2. The new claims manifest (sources/new_claims_manifest.md) — every
   citation and factual claim added during assembly that did not
   appear in either builder draft
3. The comparison report (sources/comparison_report.md) — the
   Lead's analysis of both v2 drafts
4. Both v2 builder drafts (sources/kb_[builder_a]_v2.md,
   sources/kb_[builder_b]_v2.md)
5. Scoping report (sources/scoping_report.md)

YOU ARE NOT THE ASSEMBLER. You did not write any of this content.
You critique it. You also do not re-do assembly — you pressure-test
what was assembled.

CRITIQUE THE ASSEMBLED KB AGAINST SEVEN TESTS:

1. INTERNAL CONSISTENCY
   - Does any file contradict another file? (e.g., one file says
     "circuits are split on X," another says "the Federal Circuit
     has settled X")
   - Does any file contradict itself across sections?
   - Are defined terms used consistently? (e.g., "FRAND" vs.
     "F/RAND" vs. "RAND" used interchangeably without explanation)

2. REASONING GAPS
   - Are there leaps from premise to conclusion that skip a step?
   - Are there assertions presented as conclusions that the cited
     source does not actually support?
   - Are there counterarguments the assembled draft should address
     but does not? (Check both builder drafts — if either raised a
     counterargument the assembly dropped, that is a flag.)

3. MERGE QUALITY
   - Did the assembly drop substantive content from either v2 draft
     without justification? (Use the comparison report as the
     baseline — what did the Lead say it would carry forward?)
   - Did the assembly merge content in a way that creates
     incoherence? (e.g., a paragraph from Builder A followed by a
     paragraph from Builder B that uses different framing)
   - Did the assembly preserve the strongest analytical move from
     each builder?

4. REGISTER AND TONE
   - Are <!-- [GUIDANCE] --> and <!-- [INTERPRETATION] --> tags
     used consistently and correctly? (Check that authority-only
     content is not tagged, and that guidance/interpretation is
     tagged.)
   - Does any file slip into legalese, hedging, or "it depends"
     answers without follow-through?
   - Does the voice match the scoping report's stated audience and
     use case?

5. SCOPE FIDELITY
   - Does any file cover material the scoping report puts "out of
     scope"?
   - Is any "in scope" material missing from the assembled KB
     entirely?
   - Are size targets met per file?

6. NEW CLAIMS RISK
   - Review the new claims manifest. For each new citation or
     factual claim added during assembly, assess: is the claim the
     kind that should have appeared in a builder draft? Why did
     both builders miss it? Plausible reasons exist (cross-cutting
     synthesis, transition logic), but a high volume of net-new
     factual claims is a fabrication risk signal.
   - Flag any new claim that looks load-bearing for the analysis
     and was not in either builder draft.

7. CROSS-REFERENCE LOGIC
   - Do cross-references make sense? (Filename validation in Phase 6.3
     checks they resolve. You check whether the reference is
     actually relevant to the point being made.)

OUTPUT FORMAT:

Produce sources/assembly_critique.md with three sections:

## A. Auto-Apply (Lead implements without asking the user)
Findings that meet ALL of these tests:
- The fix is unambiguous (correct a contradiction, restore a
  dropped passage that the comparison report committed to carrying,
  re-tag a register-mistagged paragraph, fix an inconsistent
  defined term, remove a clearly out-of-scope passage)
- The fix does not require new analytical content beyond what is
  already in the v2 drafts or the source material the manifest
  cites
- The fix preserves or improves the scoping report's coverage

For each: state the finding, cite the file and line range, propose
the specific edit, and cite the source (v2 draft passage,
scoping report section, or fact-check result) that supports it.

## B. User Decision Required (Lead surfaces to user)
Findings where ANY of these are true:
- A reasoning gap requires new analytical content (the assembler
  must reason, not just edit)
- A counterargument is missing and adding it would change the
  analytical conclusion
- A merge tradeoff has two reasonable options and the v2 drafts
  do not resolve which is better
- A scope question (in or out) that the scoping report does not
  resolve
- A high-risk new claim from the manifest that is load-bearing
  and the source for it is unclear

For each: state the finding, cite the file and line range, present
the options (at least two), state which option you recommend and
why, and note what specific question to ask the user.

## C. No Action — Acknowledged Strengths
Brief. What the assembly got right — particularly cross-cutting
moves the assembler made well that neither builder did alone.

CONSTRAINTS:
- Do not re-write the KB. Propose edits, do not draft replacement
  files.
- Cite file and line ranges for every finding. Unsourced critique
  is rejected.
- For every "new claim" flag in Section B, cite the manifest entry.
- Do not hedge. If a contradiction is real, classify it as
  Auto-Apply, not User Decision.
- Length target: critique should be substantive but bounded —
  typically 5-15KB depending on KB size. A critique longer than
  the average KB file means the critic is drafting, not critiquing.
```

---

## How the Lead Uses This Output

After receiving sources/assembly_critique.md, the Lead:

1. **Applies every Section A finding without asking the user.** Edits the relevant file(s) in full/. Logs each change in sources/pipeline_state.md with reference to the critique finding.
2. **For Section B findings:** Stops and asks the user using the specific question the critic supplied. Records each decision in sources/pipeline_state.md before proceeding.
3. **Acknowledges Section C** in the pipeline state — no action needed.
4. **If full/ was edited (almost always true after Section A):** Re-runs Phase 6.3 (authority-view extraction) so authority/ stays in sync. This is mandatory per 01-shared-axioms.md Section 9.
5. **Updates the new claims manifest** if any Section A or B edits added or removed claims — Phase 6.4 will re-verify.

Only after all of the above proceeds to Phase 6.3 (filename validation) and Phase 6.4 (post-assembly fact-check).

---

## Anti-Patterns

- **Critic re-drafts the KB.** If the critique exceeds the size of the assembled KB, reject and re-prompt. The critic's job is to find specific problems, not to do assembly over again.
- **Critic uses same model family as Lead.** Self-grading in disguise. Reject and re-run with a different family.
- **Lead defers everything to the user.** If Section A is empty and Section B is long, the critic is doing the Lead's job. Push the Lead to act on clear findings.
- **Lead skips the Phase 6.3 re-run after editing full/.** This will produce stale authority/ files. Phase 8.0 stress test will catch it but at much higher cost.
- **Critique fatigue.** Do NOT add critique passes at every phase. Two passes (Phase 1.2 and Phase 6.1) preserve signal. More passes train the Lead to discount critiques as ceremonial.

