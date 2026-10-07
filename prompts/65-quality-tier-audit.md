# Quality Tier Audit + Mandatory Deepening (Phase 6.5)

**Role:** Lead  
**Input:** `full/`, `authority/`, `practice/`, `sources/post_assembly_factcheck.md`, `sources/register_lint_report.md`, `sources/authority_view_extraction.md`, `sources/practice_view_extraction.md`, `sources/filename_validation.md`  
**Output:** `sources/quality_tier_audit.md` with per-file A/B/C tier classification and deepening plan  
**Runs:** After Phase 6.4; re-runs after every deepening loop

---

## Prompt

```text
You are running Phase 6.5 — Quality Tier Audit for [KB_NAME].

TASK:
1. Compute per-file and aggregate size metrics: file count, total KB, average topic-file size, minimum, maximum, parity ratio (thinnest / thickest), and full→practice / full→authority retention signals.
2. Classify each topic file and the KB overall:
   - A-TIER: average ≥ 35KB, no topic file below 20KB, parity ≥ 50%, required root files present, extraction reports PASS.
   - B-TIER: average ≥ 20KB, no topic file below 12KB, but misses A-tier depth/parity.
   - C-TIER: anything below B-tier, any required root artifact missing, or extraction/filename validation BLOCK.
3. Fetch-Closure substep: scan `full/` for `[NEEDS-FETCH][TIER-A]`. Any remaining flag is BLOCKING unless converted to `RESOLVED-ABSENT` or `TIER-A-OVERRIDE` with rationale and source attempts.
4. Produce `sources/quality_tier_audit.md`.

OUTPUT FORMAT:

# Quality Tier Audit — Phase 6.5

## Summary
- Overall tier: A / B / C
- File count: [N]
- Average topic size: [N] KB
- Smallest topic: [file] ([N] KB)
- Largest topic: [file] ([N] KB)
- Parity ratio: [N]%
- Extraction status: practice [PASS/BLOCK], authority [PASS/BLOCK]
- Filename validation status: [PASS/BLOCK]
- Fetch-Closure status: [PASS/BLOCK]

## Per-File Tier Table
| File | Full KB | Practice KB | Authority KB | Tier | Issues | Required Action |
|---|---:|---:|---:|---|---|---|

## Fetch-Closure Table
| File | Flag | Status | Source attempts / rationale | Disposition |
|---|---|---|---|---|

## Deepening Plan
List 4-6 files to deepen in parallel if the KB is B-tier. List all blocking remediations if C-tier.
```

---

## Decision Rules

| Result | Action |
|---|---|
| A-tier | Proceed to Phase 7.0. |
| B-tier | Mandatory deepening. Dispatch 4-6 files in parallel; target 35-45KB per file; then re-run Phase 6.2, 6.3, 6.4 on edited files and re-classify. |
| C-tier | Cannot ship. Fix structural/extraction/fetch blockers first, then deepen as needed and re-run 6.2 → 6.3 → 6.4 → 6.5. |

Deepened content does not enter the shipped KB until Phase 6.4 verifies the added claims. Do not treat size growth as quality unless the new material is verified and register-tagged.
