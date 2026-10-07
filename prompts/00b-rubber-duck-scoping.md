# Rubber-Duck Critique — Scoping Report (Phase 0.2)

**Role:** Independent critic of the scoping report before any builder dispatch
**Input:** Scoping report (sources/scoping_report.md) + the original user request that produced it
**Output:** Structured critique with proposed edits, classified by action level
**Runs:** Once, after Info Gather (02-info-gather.md), before Phase 1.1
**Model:** A model from a DIFFERENT family than the Lead AND different from whoever drafted the scoping report. Cannot be either builder.

---

## Why This Phase Exists

The scoping report is the source of truth for every downstream phase. Topic structure, audience framing, source list, in-scope/out-of-scope boundaries, anchor facts, size targets — all of it cascades. A bad scope compounds at every phase. Catching scope problems here costs minutes; catching them at Phase 7.0 costs the build.

This is NOT a second pass at scoping. The critic does not re-scope. It pressure-tests the report and proposes specific edits.

---

## Prompt

```
You are an independent critic of a knowledge base scoping report.

PROJECT: [KB_NAME]
TYPE: [KB_TYPE]
AUDIENCE: [AUDIENCE]
USE CASE: [USE_CASE]

INPUTS YOU RECEIVE:
1. The scoping report (sources/scoping_report.md)
2. The original user request that produced it (sources/user_request.md
   or paste-in)

YOU ARE NOT THE SCOPER. You did not write this report. You critique it.

CRITIQUE THE REPORT AGAINST SEVEN TESTS:

1. AUDIENCE FIT
   - Is the audience specific enough to drive content decisions?
     ("Senior CELA practitioners advising on FRAND" is specific;
     "lawyers" is not.)
   - Will the stated audience actually use this KB? Are the use
     cases realistic given the audience?
   - Does the audience match the use case? (e.g., "executive
     briefing" use case + "junior associate" audience is a flag)

2. SCOPE BOUNDARIES
   - Are the in-scope topics actually within the KB type?
   - Are the out-of-scope items real risks of drift, or strawmen?
   - Are there obvious adjacent topics that are neither flagged
     in nor flagged out? (silent ambiguity is the worst kind)
   - Does the in-scope list cover the use case? (gaps here become
     thin downstream memos)

3. SOURCE LIST COMPLETENESS
   - For the stated KB type, are the canonical primary sources
     listed? (e.g., for a US legal topic KB: governing statutes,
     CFR sections, agency guidance, Circuit splits)
   - Are there secondary sources that should be excluded?
   - Are there jurisdictional sources missing? (e.g., a US patent
     KB that omits ITC and Federal Circuit-specific sources)

4. KNOWN ANCHOR FACTS
   - Does the report specify anchor facts the builders should
     verify against? (case names, statute citations, key dates)
   - Are the anchor facts themselves correct? Spot-check the most
     load-bearing one via web search.

5. SIZE TARGETS
   - Are the per-file size targets appropriate for the KB type
     (per 01-shared-axioms.md Section 6)?
   - Does the file count match the topic count?
   - Are size targets consistent across files, or is there
     unjustified variance?

6. DOWNSTREAM USE CASES
   - Is the use case actionable? ("Reference KB" is too vague;
     "produces advisory memos for FRAND licensing negotiations" is
     actionable)
   - Does the use case imply register tagging is required? (any
     "produces work product" use case → register tagging required;
     opt-out only for pure reference)
   - Is authority-view extraction (Phase 6.3) appropriate? Default
     is on per 01-shared-axioms.md Section 9.

7. ERROR-TOLERANCE TIER
   - Is the KB type classified correctly per 01-shared-axioms.md
     Section 5? (Legal/regulatory has tighter thresholds than
     company KBs.) The wrong tier classification means the wrong
     audit thresholds apply.

OUTPUT FORMAT:

Produce sources/scoping_critique.md with three sections:

## A. Auto-Apply (Lead implements without asking the user)
Findings that meet ALL of these tests:
- The fix is mechanical or factual (correct an anchor fact,
  add a missing canonical source, fix a tier classification, add
  an obvious in-scope or out-of-scope topic that is unambiguous)
- The fix is supported by the user request, the KB type's
  conventions, or a verifiable primary source
- The fix does not change the project's stated objective

For each: state the finding, the proposed edit, and the supporting
evidence.

## B. User Decision Required (Lead surfaces to user)
Findings where ANY of these are true:
- Audience specificity is ambiguous and the user must clarify
- A scope boundary is genuinely contested (in OR out are both
  reasonable)
- The use case is too broad and needs narrowing
- A jurisdictional choice the user must make
- Tier classification is borderline

For each: state the finding, present the options (at least two),
state which option you recommend and why, and note what specific
question to ask the user.

## C. No Action — Acknowledged Strengths
Brief: what the report got right. Calibrates user confidence.

CONSTRAINTS:
- Do not propose your own scoping report.
- Cite the user request, the KB type's conventions, or a primary
  source for every finding. Unsourced critique is rejected.
- Do not hedge. Auto-apply if the fix is clear; escalate if it
  isn't.
- Length target: 2-4KB. Longer means re-scoping, not critiquing.
```

---

## How the Lead Uses This Output

1. **Applies every Section A finding without asking the user.** Updates sources/scoping_report.md. Logs each change in sources/pipeline_state.md with the critique reference.
2. **For Section B findings:** Stops and asks the user using the specific question the critic supplied. Records the decision before proceeding.
3. **Acknowledges Section C** — no action needed.

Then proceeds to Phase 1.1 with the revised scoping report.

---

## Anti-Patterns

- **Critic re-scopes the project.** If the critique is longer than 4KB, reject and re-prompt.
- **Critic uses same model family as scoper or Lead.** Self-grading risk. Reject and re-run.
- **Lead defers everything to the user.** If Section A is empty and Section B is long, the critic is doing the Lead's job.
