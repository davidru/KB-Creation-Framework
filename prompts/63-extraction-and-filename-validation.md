# Three-Tier Extraction + Filename Validation (Phase 6.3)

**Role:** Deterministic scripts + Lead verification  
**Input:** Assembled `full/` directory after Phase 6.2 register lint  
**Output:** Derived `practice/` and `authority/` directories; `sources/practice_view_extraction.md`; `sources/authority_view_extraction.md`; `sources/filename_validation.md`  
**Runs:** After Phase 6.2 and after every downstream edit to `full/`

---

## Why This Exists

v3 ships three views:

- `full/` — complete content, including `<!-- [GUIDANCE] -->` and `<!-- [INTERPRETATION] -->`.
- `practice/` — strips `<!-- [INTERPRETATION] -->` but retains `<!-- [GUIDANCE] -->`.
- `authority/` — strips both `<!-- [GUIDANCE] -->` and `<!-- [INTERPRETATION] -->`.

This prompt merges v2 Phase 6.3 authority extraction and v2 Phase 6.3 structural/filename validation. Extraction must happen before validation because validation checks that derived views are present and filename-synchronized.

---

## Procedure

### Step 1 — Precondition check

```powershell
$kbRoot = "[STATE_ROOT]"
$fullDir = Join-Path $kbRoot "full"
$tags = Select-String -Path "$fullDir\*.md" -Pattern "<!--\s*\[(GUIDANCE|INTERPRETATION)\]\s*-->" -AllMatches
if ($tags.Count -eq 0) {
    Write-Output "No register tags found. Verify with scoping report: is this intentional? If not, return to Phase 6.0/6.2 and tag appropriately."
}
```

If `$tags.Count` is 0 and the build produced practice guidance content, the assembler failed to apply register tags. **Go back to assembly/register lint and tag the content before proceeding.**

### Step 2 — Extract practice/

```powershell
& "[FRAMEWORK_ROOT]\Extract-PracticeView.ps1" -KBRoot "[STATE_ROOT]"
```

The script strips only `<!-- [INTERPRETATION] -->` paragraphs and writes `practice/*.md`. It writes `sources/practice_view_extraction.md`.

### Step 3 — Extract authority/

```powershell
& "[FRAMEWORK_ROOT]\Extract-AuthorityView.ps1" -KBRoot "[STATE_ROOT]"
```

The script strips `<!-- [GUIDANCE] -->` and `<!-- [INTERPRETATION] -->` paragraphs and writes `authority/*.md`. It writes `sources/authority_view_extraction.md`. Inline-position register tags are BLOCKING.

### Step 4 — Extraction verification gates

| Gate | Threshold | Action if Failed |
|---|---|---|
| Every `full/*.md` file has a `practice/` counterpart | 100% | Re-run script; check I/O errors |
| Every `full/*.md` file has an `authority/` counterpart | 100% | Re-run script; check I/O errors |
| No inline-position register tags | 0 | Fix tag placement in `full/`, re-run both scripts |
| Practice retention | normally ≥ 60% | Review over-tagging if lower |
| Authority retention | normally ≥ 40% per file and ≥ 60% overall | Review over-tagging or guidance-heavy file |
| No derived file below 12KB unless scoping justifies | ≥ 12KB | Deepen primary/practice content in `full/`, re-extract |

### Step 5 — Structural completeness gate (folded from v2 Phase 6.3)

Test for every required infrastructure artifact. Any missing artifact is BLOCKING.

Required at KB root:
- `AGENTS.md` (5-7KB target)
- `index.md` (10-20KB target)
- `table-of-authorities.md` (10-20KB target)

Required subdirectories:
- `full/` (must contain >= 1 numbered topic file)
- `practice/` (must contain one `.md` peer for every `full/*.md`)
- `authority/` (must contain one `.md` peer for every `full/*.md` when tags exist)
- `sources/` (must contain `pipeline_state.md`, `register_lint_report.md`, extraction reports)

Output Part 1 as:

```text
STRUCTURAL COMPLETENESS REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[✓ / ✗] AGENTS.md               (size: N KB)
[✓ / ✗] index.md                (size: N KB)
[✓ / ✗] table-of-authorities.md (size: N KB)
[✓ / ✗] full/                   (N topic files)
[✓ / ✗] practice/ populated     (N files)
[✓ / ✗] authority/ populated    (N files; tags-in-full/ present: yes/no)
[✓ / ✗] sources/pipeline_state.md
[✓ / ✗] sources/register_lint_report.md
[✓ / ✗] sources/practice_view_extraction.md
[✓ / ✗] sources/authority_view_extraction.md
Status: PASS / BLOCKING
```

### Step 6 — Filename / cross-reference validation

1. LIST all files in the KB directory (`full/`, `practice/`, `authority/`, root files). Record the exact filename of each.
2. SCAN every file for internal cross-references: Markdown links, YAML front matter `cross_references`, inline references to other topic files by filename, and routing table entries in `AGENTS.md` and `index.md`.
3. For each cross-reference, verify the target filename exists EXACTLY as written. Case-sensitive. Extension-sensitive.
4. For broken references, determine the correct target, replace in-place, and log the correction.
5. Write `sources/filename_validation.md`:

| # | Source File | Line | Broken Reference | Corrected To |
|---|---|---:|---|---|

Summary: [N] cross-references checked, [N] correct, [N] fixed.

If any remain unresolvable: report BLOCKING with details.

---

## Regeneration Protocol

`practice/` and `authority/` are derived artifacts. Whenever any `full/*.md` file changes (Phase 6.1 edits, Phase 6.2 tags, Phase 6.4 corrections, Phase 6.5 deepening, Phase 7.0 corrections, patch builds, or refresh-cycle updates), re-run this entire prompt.
