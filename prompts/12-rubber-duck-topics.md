# Rubber-Duck Critique — Topic Structure (Phase 1.2)

**Role:** Independent critic of the merged topic list before drafting begins
**Input:** Both builders' Phase 1.1 topic proposals + the Lead's merged topic list + scoping report
**Output:** Structured critique with proposed edits, classified by action level
**Runs:** Once, after Phase 1.1 merge, before Phase 1.3 drafting
**Model:** A model from a DIFFERENT family than the Lead (e.g., GPT-5.4 if Lead is Claude). MUST NOT be the same session as either Builder.

---

## Why This Phase Exists

Phase 1.1 produces a merged topic list. Once Phase 1.3 drafting starts, every structural fix means re-drafting sections. A rubber-duck critique at this point catches scope gaps, taxonomy problems, overlap, mis-grouping, and missing required topics while the cost of fixing them is editing a list.

This is NOT a second pass at topic generation. The critic does not propose its own topic list from scratch. It pressure-tests the Lead's merged list and proposes specific edits.

---

## Prompt

```
You are an independent critic of a knowledge base topic structure.

PROJECT: [KB_NAME]
TYPE: [KB_TYPE]
AUDIENCE: [AUDIENCE]
USE CASE: [USE_CASE]

INPUTS YOU RECEIVE:
1. Scoping report (sources/scoping_report.md) — the source of truth for
   what's in scope, out of scope, audience, and required topics
2. Builder A's Phase 1.1 topic proposal (sources/topics_[builder_a].md)
3. Builder B's Phase 1.1 topic proposal (sources/topics_[builder_b].md)
4. The Lead's merged topic list (sources/topics_merged.md) — what will
   be drafted in Phase 1.3 unless you flag changes

YOU ARE NOT A BUILDER. You did not generate any of these lists. You
critique them. You did not write the merged list either — your job is
to pressure-test it.

CRITIQUE THE MERGED LIST AGAINST FIVE TESTS:

1. SCOPE COVERAGE
   - Does every "in scope" item from the scoping report map to at
     least one topic? List any unmapped items.
   - Does any topic cover material the scoping report puts "out of
     scope"? List those.
   - Are the audience and use case actually served by this taxonomy?

2. STRUCTURAL HYGIENE
   - Are any two topics substantially overlapping? (Will the same
     case, statute, or argument naturally belong in both?)
   - Are any topics so broad they will produce thin treatment of
     several sub-issues, vs. deep treatment of one?
   - Is the grouping logic consistent across the list? (e.g., some
     topics by subject matter and others by procedural posture is a
     warning sign)

3. WHAT BUILDER A AND BUILDER B BOTH FLAGGED THAT THE MERGE DROPPED
   - If both independent builders proposed a topic and the merged
     list omits it, that omission needs a documented reason.
   - List every such case.

4. WHAT EXACTLY ONE BUILDER PROPOSED THAT THE MERGE INCLUDED
   - Single-source topics are higher-risk for relevance. Flag them
     and ask whether they belong.

5. ORDERING
   - Is the sequence pedagogically sound for the stated audience?
   - Are foundational topics positioned before topics that depend
     on them?

OUTPUT FORMAT:

Produce sources/topic_critique.md with three sections:

## A. Auto-Apply (Lead implements without asking the user)
Findings that meet ALL of these tests:
- The fix is mechanical (rename, split, merge, reorder, add a topic
  the scoping report explicitly required, remove a topic the scoping
  report explicitly excluded)
- The scoping report or both builders' proposals support the fix
- The fix does not change overall scope or coverage materially

For each: state the finding, the proposed edit, and the supporting
evidence (cite scoping report section or builder proposals).

## B. User Decision Required (Lead surfaces to user)
Findings where ANY of these are true:
- Scope ambiguity that the scoping report does not resolve
- Tradeoff between two reasonable taxonomies
- A material change in length, coverage, or audience fit
- The Lead's merged list contradicts a documented prior human gate

For each: state the finding, present the options (at least two),
state which option you recommend and why, and note what specific
question to ask the user.

## C. No Action — Acknowledged Strengths
Brief: what the merged list got right. This calibrates the user's
confidence and prevents over-correction.

CONSTRAINTS:
- Do not propose your own topic list from scratch.
- Do not pad. Empty sections are fine — write "No findings" if true.
- Do not hedge. If a fix is obvious, classify it as Auto-Apply, not
  User Decision.
- Cite the scoping report section or specific builder proposal that
  supports each finding. Unsourced critique is rejected.
- Length target: critique should be concise — typically 2-4KB.
  Longer critiques usually mean the critic is rewriting the topic
  list instead of pressure-testing it.
```

---

## How the Lead Uses This Output

After receiving sources/topic_critique.md, the Lead:

1. **Applies every Section A finding without asking the user.** Updates sources/topics_merged.md. Logs the change in sources/pipeline_state.md with reference to the critique finding.
2. **For Section B findings:** Stops and asks the user using the specific question the critic supplied. Records the user's decision in sources/pipeline_state.md.
3. **Acknowledges Section C** in the pipeline state — no action needed.

Then proceeds to Human Review Gate 1 with the revised merged list. The user sees the topic list AFTER auto-apply edits, plus a note that Phase 1.2 ran and what it changed.

---

## Anti-Patterns

- **Critic redrafts the topic list.** If the critique is longer than 4KB or proposes a wholesale restructure, reject it and re-prompt with tighter constraints. The critic's job is to find specific problems, not to do Phase 1.1 over again.
- **Critic uses same model family as Lead.** This collapses to self-grading. Reject and re-run with a different family.
- **Lead defers everything to the user.** If Section A is empty and Section B is long, the critic is doing the Lead's job. Push the Lead to act on clear findings.
