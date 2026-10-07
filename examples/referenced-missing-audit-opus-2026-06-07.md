# Referenced-But-Missing Audit (v3.1.6 re-run, Opus 4.8)

Read-only audit. No framework files were modified. Scan date: 2026-06-07.

## Inventory totals
- **v3.1 framework** (`KB Creation - Modular v3 + OpenCode and OpenRouter`): 116 files in Set A (.ps1/.yaml/.json/.md/.txt, excluding .git/node_modules/sources/audit/grounding/temp/.kbframework/.opencode build dirs). ~70 unique referenced .ps1/.yaml/.json filenames in Set B (plus many .md cross-refs).
- **Memo framework** (`Memo Drafting Framework v1 + Provider Registry`): 14 files in Set A. ~10 unique referenced .ps1/.yaml/.json filenames in Set B (several are deliberate cross-framework references into the sibling v3.1 root).

Method: enumerated every shipped `.ps1/.yaml/.json/.md/.txt` (Set A) and regex-scanned every shipped `.md/.txt` for file-extension tokens (Set B), then cross-referenced basenames programmatically. Each Set B entry not present in Set A was inspected in source context.

## GAP-HIGH findings (operator-blocking)
**NONE.**

The two known historical defects of this class are now both shipped and resolved:
- `Validate-Host.ps1` — **PRESENT** in Set A (43,125 bytes). Fixed in v3.1.1 as expected.
- `Render-OpenCodeAgents.ps1` — **PRESENT** in Set A (19,069 bytes). The v3.1.5 patch has landed; treat as Set A per audit instructions. Not a gap.

No new operator-invocable reference resolves to a missing file. Every `&`-invoked or "must invoke / run / call" script reference resolves to a shipped file (verified for all 28 top-level `.ps1`, the 8 `audit-templates/*.yaml`, both schema `.json`, and the per-provider `discover.ps1`/`dispatch.ps1` across all 4 adapters: azure-foundry, copilot-cli, ollama, openrouter — all 8 present).

## GAP-MEDIUM findings (operator-confusing)
**NONE that rise to a real defect.** Three referenced scripts do not ship, but each is *explicitly* disclaimed as future/optional in the very prose that names it, so an operator is not misled:

1. `Generate-PortfolioScorecard.ps1` — `07-audit-system.md:440` calls it "A future ... can aggregate ..." and "out of scope for v3.0 and targeted for the follow-on KB Operations v1 framework." Also flagged by the prior conformance report as a known future ref. **Not a defect.** (Optional: drop the speculative name to remove any temptation, but harmless.)
2. `Get-OpenRouterBalance.ps1` — `CHANGELOG.md:53` lists it in a parenthetical describing a *deferred* feature ("`Get-OpenRouterBalance.ps1` — would call `/api/v1/credits` ..."). Aspirational, not instructional. **Not a defect.**
3. `Invoke-BuildPhase.ps1` — `technical-specification-v3.1.0.md:470` says Resume-Build "either calls `Invoke-BuildPhase.ps1` **if present** or emits a manual dispatch plan." Verified in `Resume-Build.ps1:66-67`: a real `Test-Path` guard exists and the absence path emits `manual_dispatch_required` with a warning. This is a deliberate optional extension point, not a missing required dependency. **Not a defect.**

## ORPHAN-LOW findings (possibly dead code)
No orphaned `.ps1`, `.yaml`, or `.json` in either framework — every shipped script and data file is referenced in prose at least once. Three `.md` files are never referenced by basename, all benign:

- v3.1: `specification/framework-review-archive/framework-review-2026-04-27.md` — a dated, archived historical review. Intentionally standalone; not meant to be invoked.
- Memo: `prompts/00-README.md` — index/landing doc that points outward but is not itself pointed to. Benign.
- Memo: `CHANGELOG.md` — standard changelog, not cross-referenced. Benign.

## Adjacent finds (missing directories, broken paths)
- All `adapters/model-providers/<provider>/` template directories referenced in prose exist (4 providers, each with discover.ps1 + dispatch.ps1 + README.md + LICENSE.txt).
- Memo framework references the sibling v3.1 root extensively (`../KB Creation - Modular v3 + OpenCode and OpenRouter/Resolve-Model.ps1`, `.../model-registry.example.yaml`, `.../Validate-ModelAssignment.ps1`, `.../HOST-CONTRACT.md`). All targets exist in the sibling Set A. These are correct cross-framework references, not gaps — but they create a hard directory-name coupling: if the sibling folder is renamed or absent, every Memo model-resolution path breaks. Worth a one-line note in Memo HOW-TO-USE about the required sibling layout (it is already partially documented).
- `Detect-MemoLeakage.ps1` is referenced in v3.1 specs/conformance as the Memo framework's canonical script; it lives in the Memo Set A. Cross-framework, resolves. Not a gap.

## False-positive filtering applied
Excluded as runtime/operator-created build artifacts (not shipped, not expected to ship): `cites.json`, `claims.json`, `_claims.json`, `_summary.json`, `completion.json`, `config.json`, `fetch_log.json`, `kb-quality.json`, `kb-quality-history.json`, `model_recommendations.json`, `models.json`, `ollama-models.json`, `openrouter-models.json`, `openrouter-legal-models.json`, `recs.json`, `resolved-lead.json`, `response.json`, `opencode.json`, `model_assignment_candidate.yaml`, `kb-manifest.yaml` (per-KB tunable), `notify.yaml` (optional `~/.kbframework` config, no-ops when unconfigured), `dispatch-envelope.json` (an `-OutPath` example value in copilot-cli README), `Activate.ps1` (python venv artifact). Also excluded `model-registry.yaml` (operator-created from `model-registry.example.yaml`, which DOES ship) and `<placeholder>`/`[NN]-*` parameter-style tokens.

## Methodology notes
- **Set A**: `Get-ChildItem -Recurse` over both roots, filtered to the five extensions and excluding build/output dirs. Exhaustive (not sampled).
- **Set B**: regex `[A-Za-z0-9_\-\.]+\.(ps1|yaml|json)` (and a parallel `.md` pass) over every shipped `.md`/`.txt`, with per-file/line capture, then a basename set-difference against Set A. Exhaustive.
- Every Set B entry absent from Set A was opened in source context (Select-String with line numbers) before classification — no entry was dismissed purely on name.
- Adapter completeness verified by direct `Test-Path` per provider rather than by trusting prose.
- The single intentionally-optional dependency (`Invoke-BuildPhase.ps1`) was confirmed by reading the guard logic in `Resume-Build.ps1`, not inferred from the spec wording alone.
- **Suspected false negatives**: low. The regex would miss a script named only without its extension in prose (e.g., "the resolver" with no `.ps1`), but such a reference is not operator-actionable by the defect definition. Markdown-link paths with spaces inside parentheses could in principle be split, but spot-checks of the sibling cross-references (which contain spaces) showed they were still captured by basename.

## Summary
- **GAP-HIGH: 0** (the two prior known defects, Validate-Host.ps1 and Render-OpenCodeAgents.ps1, are both now shipped).
- **GAP-MEDIUM: 0** genuine (3 future/optional scripts, each self-disclaimed in-prose; no operator failure path).
- **ORPHAN-LOW: 3** `.md` files (1 archived review, 1 README index, 1 CHANGELOG) — all benign, no action.
- **Recommended remediation priority order:**
  1. (Optional, cosmetic) None blocking. If desired, strip the speculative `Generate-PortfolioScorecard.ps1` / `Get-OpenRouterBalance.ps1` names from prose to avoid future audit re-flags, or add a one-line "(not shipped; future)" tag inline.
  2. (Optional, robustness) Add a one-line note in Memo `HOW-TO-USE.md` that the sibling v3.1 folder name is a hard dependency for model resolution.

**Bottom line:** This framework pair is currently clean of the referenced-but-not-shipped defect class. The prior thin gpt-5.4-mini result happened to reach the correct *count* (zero real gaps) but for the wrong reason (it mis-flagged `role-profiles.yaml`, which ships at 3,752 bytes in the Memo framework — confirmed present). This exhaustive re-run finds no operator-blocking gaps and confirms the v3.1.1 and v3.1.5 fixes both landed.
