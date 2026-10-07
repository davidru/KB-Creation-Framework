# Register Lint (Phase 6.2)

**Role:** Deterministic script + Lead review
**Input:** All files in full/
**Output:** sources/register_lint_report.md + Lead-applied re-tags in full/
**Runs:** After Phase 6.1 (assembly critique) and before Phase 6.3 (authority-view extraction)
**Why this exists:** Register tagging is the gatekeeper for what downstream agents cite as authority. The Phase 6.1 critic checks register, but mechanical scanning catches paragraphs the critic missed. Untagged guidance language flowing into authority/ is the failure mode that produced the US Legal Ethics overstatements (April 2026, Lesson 27).

---

## What Register-Lint.ps1 Does

The script (Register-Lint.ps1, sibling to Extract-AuthorityView.ps1) runs with `-IncludeRootFiles` and scans every paragraph in full/ plus root AGENTS.md, index.md, and table-of-authorities.md that is NOT already tagged with `<!-- [GUIDANCE] -->` or `<!-- [INTERPRETATION] -->`. It flags any paragraph containing one or more guidance signals:

**Guidance language signals (paragraphs flagged for review):**
- "as a practical matter"
- "the defensible response"
- "best practice" / "best practices"
- "experienced practitioners" / "experienced counsel"
- "typically" + verb of action ("typically advise," "typically include")
- "generally recommended"
- "the better approach"
- "should consider" / "should evaluate" / "should assess" (without rule cite)
- "one approach is"
- "a common approach"
- "in our experience"
- "we recommend" / "I recommend"
- Imperative-mood action checklists not anchored to a quoted rule
  (e.g., "Step 1: Review… Step 2: Identify…")
- Numbered "best practices" lists not anchored to authority

The script outputs sources/register_lint_report.md listing every flagged paragraph with file, line, the matched signal, and the paragraph text.

---

## Prompt for the Lead (after running Register-Lint.ps1)

```
You are reviewing a register-lint report. The script flagged paragraphs
in full/ that contain guidance-language signals but are NOT tagged as
<!-- [GUIDANCE] --> or <!-- [INTERPRETATION] -->.

INPUTS:
- sources/register_lint_report.md
- sources/verbatim_linter_phase6_2.md

PRE-STEP COMMANDS:

Run:

    & "[FRAMEWORK_ROOT]\Register-Lint.ps1" `
        -FullPath "[STATE_ROOT]\full" `
        -OutPath "[STATE_ROOT]\sources\register_lint_report.md" `
        -IncludeRootFiles

    & "[FRAMEWORK_ROOT]\Verbatim-Linter.ps1" `
        -KBRoot "[STATE_ROOT]" `
        -OutPath "[STATE_ROOT]\sources\verbatim_linter_phase6_2.md"

TASK:

For each flagged paragraph, classify into one of three buckets and
take action:

1. RE-TAG AS GUIDANCE
   The paragraph IS guidance. Open the file, add the
   <!-- [GUIDANCE] --> tag (per 01-shared-axioms.md Section 9 tagging
   rules), save the file. Log the change.

2. RE-TAG AS INTERPRETATION
   The paragraph synthesizes multiple sources into a conclusion none
   individually states. Add <!-- [INTERPRETATION] --> tag.

3. KEEP UNTAGGED (FALSE POSITIVE)
   The paragraph IS authority. The signal language appears but is
   anchored to a quoted rule, holding, or verified fact (e.g., "The
   court typically applies de novo review per [cite]" — "typically"
   here describes a documented standard, not practitioner judgment).
   Document the rationale.

CONSTRAINTS:
- Default lean: when in doubt, tag as GUIDANCE. Over-tagging shrinks
  the authority view but does not produce errors. Under-tagging
  propagates guidance into work product as authority.
- Every "keep untagged" decision must cite the anchoring authority
  in the paragraph itself or one paragraph above/below.
- Do NOT delete or rewrite content. This is a tagging pass only.

OUTPUT:

Update sources/register_lint_report.md to add a "Disposition" column and summarize Verbatim-Linter findings:
| # | File | Line | Signal | Paragraph (excerpt) | Disposition | Rationale (if KEEP) |

Apply all RE-TAG decisions to full/ in the same pass.

If full/ is edited (almost always), Phase 6.3 MUST run after this phase to regenerate both practice/ and authority/.
```

---

## How the Lead Uses This Output

1. **Run Register-Lint.ps1 with `-IncludeRootFiles`** — produces sources/register_lint_report.md
2. **Apply all RE-TAG decisions** to full/ files. This is auto-act — no user approval needed for tag additions, since tagging is conservative (default lean is to tag).
3. **For paragraphs marked KEEP UNTAGGED** — log the rationale in the report.
4. **Re-run Phase 6.3** automatically after this phase, since full/ was almost certainly edited.

---

## Anti-Patterns

- **Treating the lint report as advisory.** Every flagged paragraph requires a disposition. Skipping the report defeats the purpose.
- **Defaulting to KEEP UNTAGGED.** The lint exists because under-tagging is the documented failure mode (Lesson 27). When in doubt, tag.
- **Editing prose during the lint pass.** Tagging only. Prose changes belong to earlier phases.
- **Skipping Phase 6.3 regeneration after re-tagging.** Stale authority/ is the exact problem this whole pipeline exists to prevent.
