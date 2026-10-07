# Builder Revision Prompt (Monolithic — Phase 3)

**Role:** Builder (revising their own draft)
**Input:** Builder's original draft + Lead's combined review
**Output:** Revised v2 draft
**Runs:** Once per builder
**Why monolithic:** Builder needs full review + full draft in single context

---

## Prompt

```
You are revising your draft of the [KB_NAME] knowledge base based on
the Lead reviewer's feedback.

YOUR ORIGINAL DRAFT:
[Paste or attach the builder's full draft]

LEAD'S COMBINED REVIEW (structural + depth):
[Paste or attach the combined review from Phase 2.0]

TASK:
Revise your draft to address ALL issues raised by the Lead.

REVISION RULES:
1. Address every item in the Lead's review. Do not skip any.
2. Web search to verify any new claims added during revision.
3. Expand thin sections (rated below 3) to at least target size.
4. Add specifics where the Lead flagged "lacks specificity":
   real citations, dollar amounts, dates, holdings, entity names.
5. Resolve or remove [UNVERIFIED] tags where possible.
6. Preserve ALL existing content that wasn't flagged for removal.
   Revision ADDS and CORRECTS — it doesn't summarize or compress.
7. Maintain analytical voice per audience: [AUDIENCE].

ERROR PATTERNS TO WATCH:
When adding new content, avoid these production-validated patterns:
- Date Drift: verify every new date
- Attribution Confusion: verify entity names match the numbers
- Speculative Inflation: no forward-looking numbers without sources
- Terminology Upgrade: don't change informal terms to different precise terms

OUTPUT: Your complete revised draft (v2). Include everything —
sections that changed AND sections that didn't.
Save as: sources/kb_[your_model]_v2.md
```
