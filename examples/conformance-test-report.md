# v3.0 Conformance Test Report

**Date:** 2026-06-07  
**Test type:** Synthetic (file integrity + parse + cross-reference + invariant walkthrough)  
**Operator note:** A real reference-KB build is deferred to post-ship operator validation.

## Summary
- Total checks: 10
- PASS: 9
- WARN: 1
- FAIL: 0
- Overall verdict: PASS-WITH-WARNINGS

The synthetic test follows the operator's explicit Layer 8 decision to defer the real reference build and supersedes the older reference-build expectation still present in the technical specification. The two documentation/specification defects found by the initial run were remediated and re-validated mechanically during Layer 9 closeout. The remaining WARN is the previously documented future/out-of-scope portfolio-scorecard reference in Check 5.

## Check results

### Check 1 — File integrity (full directory layout)

**Verdict:** PASS

**Evidence:**
- Required v3 rulebooks, prompts, scripts, adapters, audit templates, specification, and example scorecard are documented in the technical specification implementation inventory (`specification\technical-specification-v3.0.md` lines 153-212) and prompt inventory (`prompts\00-README.md` lines 12-39).
- Memo framework required files are documented in its prompt inventory and contract (`Memo Drafting Framework v1\prompts\00-README.md` lines 12-19; `Memo Drafting Framework v1\02-corpus-contract.md` lines 114-125).
- File-presence probe result: `missing_expected_count=0`, `memo_missing_expected_count=0`, `parent_readme_exists=True`.
- Legacy v2 prompt-name probe result: `legacy_prompt_count=0`.
- Python bytecode cache probe result after cleanup: `pycache_count=0`. The parse test produced bytecode cache files under `adapters\crawl4ai-fetch\__pycache__`; these generated test artifacts were removed.

**Remediation:** None.

### Check 2 — All scripts parse without syntax error

**Verdict:** PASS

**Evidence:**
- PowerShell parser smoke test passed for all 11 v3 root scripts: `Validate-ModelAssignment.ps1`, `Validate-Phase4Inventory.ps1`, `Register-Lint.ps1`, `Verbatim-Linter.ps1`, `Extract-PracticeView.ps1`, `Extract-AuthorityView.ps1`, `Generate-QualityScorecard.ps1`, `Detect-Reattribution.ps1`, `Diff-KBVersions.ps1`, `Detect-CrossKBConflicts.ps1`, and `Migrate-V2KBtoV3.ps1`.
- PowerShell parser smoke test passed for Memo framework scripts: `Detect-MemoLeakage.ps1` and `Detect-Reattribution.ps1`.
- `python -m py_compile` passed for all six Crawl4AI adapter scripts: `build_packets.py`, `extract_cites.py`, `fetch.py`, `fetch_cf_fallback.py`, `fetch_pdf_fallback.py`, and `fetch_scrapling_fallback.py`.

**Remediation:** None.

### Check 3 — All YAML files parse

**Verdict:** PASS

**Evidence:**
- `audit-templates\kb-quality-dimensions.yaml` parsed with `yaml.safe_load`; its thresholds and default weights are visible at lines 20-53.
- `audit-templates\model-presets.yaml` parsed with `yaml.safe_load`.
- No YAML front matter blocks were present in `prompts\*.md`, so no prompt-front-matter YAML required parsing.

**Remediation:** None.

### Check 4 — Phase numbering monotonic

**Verdict:** PASS

**Evidence:**
- `prompts\00-README.md` lists the final execution order at lines 14-37: `00-README`, `00a`, `00b`, `01`, `11`, `12`, `13`, `20`, `30`, `40`, `51`-`55`, `60`-`65`, `70`, `80`, `85`.
- Actual root prompt-file listing matches that sequence exactly.
- No Phase 1.5 or Phase 3.5 prompt files exist. The v2→v3 mapping confirms both were cut or folded into other phases (`prompts\00-README.md` lines 86 and 89).

**Remediation:** None.

### Check 5 — Cross-references resolve

**Verdict:** WARN

**Evidence:**
- Live prompt references in execution sections resolve to existing prompt files; historical v2 filenames appear only in the v2→v3 mapping (`prompts\00-README.md` lines 76-104) and are not expected to exist in v3.
- Required script references in rulebooks resolve to existing v3 or Memo framework scripts except one explicitly future/out-of-scope reference: `07-audit-system.md` line 440 mentions future `Generate-PortfolioScorecard.ps1`, which does not exist in v3.0 and is described on the same line as "out of scope for v3.0".

**Remediation:** No v3.0 fix applied. Optional future cleanup: style the portfolio-scorecard reference as a non-file placeholder or future tool name so mechanical reference scans do not flag it.

### Check 6 — Invariant coverage

**Verdict:** PASS

**Evidence:**
- The 27 invariants remain defined in `specification\technical-specification-v3.0.md` §2.1-2.5.
- `specification\technical-specification-v3.0.md` now includes §12.1, "Invariant Enforcement Matrix," with one row for each of AF-1 through AF-7, PV-1 through PV-5, IN-1 through IN-6, AU-1 through AU-5, and RF-1 through RF-4.
- Each row includes a one-line statement, enforcing v3 prompt(s) and/or script(s), and the phase or mechanical artifact where compliance is verified.
- Mechanical re-validation result: all 27 invariant IDs have exactly one matrix row with a populated `Enforced by` cell and a populated `Verified at` cell.

**Remediation:** Fixed in `specification\technical-specification-v3.0.md` by adding the full 27-row invariant enforcement matrix.

### Check 7 — Six Rules consistency

**Verdict:** PASS

**Evidence:**
- `HOW-TO-USE.md` lines 48-53 remain the canonical Six Rules wording.
- `prompts\00-README.md` now contains the same six-line block byte-for-byte.
- `01-shared-axioms.md` now contains an operator-facing Six Rules summary near Rules 17 and 19, marked as a summary that points to `HOW-TO-USE.md` for the canonical form; the six numbered lines are byte-identical to `HOW-TO-USE.md`.
- Mechanical re-validation result: canonical block occurrences are `prompts/00-README.md = 1` and `01-shared-axioms.md = 1`.

**Remediation:** Fixed in `prompts\00-README.md` and `01-shared-axioms.md` by aligning to the canonical `HOW-TO-USE.md` wording.

### Check 8 — Model assignment plumbing end-to-end

**Verdict:** PASS

**Evidence:**
- Phase 0.0 writes `model_assignment` to both `sources\scoping_report.md` and `sources\pipeline_state.md` (`prompts\00a-model-selection.md` lines 5 and 48-69).
- The orchestrator requires reading the latest `model_assignment` before every dispatch and prohibits inventing old defaults (`prompts\01-orchestrator.md` lines 31-38).
- Dispatch separation rules are documented in the orchestrator (`prompts\01-orchestrator.md` lines 55-63).
- Phase 8.0 maps the assignment into the Memo framework contract (`prompts\80-downstream-stress-test.md` lines 22-34) and uses `model_assignment.memo_factcheck_8` for independent memo verification (`prompts\80-downstream-stress-test.md` lines 70-78).
- Phase 8.5 selects red-team agents using the Phase 0.0 assignment (`prompts\85-adversarial-red-team.md` line 14).

**Remediation:** None.

### Check 9 — Quality Scorecard data sources exist

**Verdict:** PASS

**Evidence:**
- The seven quality dimensions are defined in `audit-templates\kb-quality-dimensions.yaml` lines 20-27 and generated in `Generate-QualityScorecard.ps1` lines 197-205.
- Generator inputs are source artifacts produced by earlier phases: `pipeline_state.md`, manifests, post-assembly fact-check, quality-tier audit, audit report, register-lint report, authority extraction report, filename validation, table of authorities, fact-check reports, stress-test reports, and derived-view directories (`Generate-QualityScorecard.ps1` lines 113-143 and 177-205).
- Producer prompts/spec entries exist for those artifacts: Phase 5 fact-check reports, Phase 6 manifests/lint/extraction/filename validation, Phase 6.5 quality tier audit, Phase 7 audit report, and Phase 8 stress-test reports (`specification\technical-specification-v3.0.md` lines 247-271; `prompts\80-downstream-stress-test.md` lines 46-64 and 92).

**Remediation:** None.

### Check 10 — Memo framework integration contract

**Verdict:** PASS

**Evidence:**
- Phase 8.0 explicitly invokes `..\Memo Drafting Framework v1\02-corpus-contract.md` (`prompts\80-downstream-stress-test.md` line 12).
- Phase 8.0 passes required contract inputs: `source_corpus_path`, `memo_topic`, `working_dir`, `memo_label`, `model_assignment`, and optional `qualifier_registry_path` (`prompts\80-downstream-stress-test.md` lines 18-34), matching the contract's required inputs (`Memo Drafting Framework v1\02-corpus-contract.md` lines 18-28).
- Phase 8.0 expects the required outputs listed by the contract: claims JSON, memo, leakage report, reattribution report, qualifier report, and summary JSON (`prompts\80-downstream-stress-test.md` lines 53-66; contract lines 118-125).
- Model passthrough aligns with the contract: Step 1, Step 2, and Step 4 use model assignment fields; Step 3 is mechanical (`Memo Drafting Framework v1\02-corpus-contract.md` lines 79-104; `Memo Drafting Framework v1\prompts\01-claim-extractor.md` line 7; `prompts\02-memo-writer.md` line 7; `prompts\04-qualifier-preservation-review.md` line 7).

**Remediation:** None.

## Remediation re-validation

**Date:** 2026-06-07  
**Method:** Mechanical re-run of Checks 6 and 7 after documentation edits.

| Check | New verdict | Note |
|---|---|---|
| Check 6 — Invariant coverage | PASS | `specification\technical-specification-v3.0.md` §12.1 now maps all 27 invariants to enforcing prompts/scripts and verification phases. |
| Check 7 — Six Rules consistency | PASS | The canonical `HOW-TO-USE.md` Six Rules block is byte-identical in `prompts\00-README.md` and `01-shared-axioms.md`. |

Overall conformance verdict after remediation: **PASS-WITH-WARNINGS**. The only remaining warning is Check 5's future/out-of-scope `Generate-PortfolioScorecard.ps1` reference.

## L9 cutover verification

### L9.1 — Parent README promotes v3

**Verdict:** PASS / verified only

Evidence:
- The parent README describes both active frameworks (`README.md` lines 23-38).
- v2 is preserved for in-flight builds and historical reference, with new builds pointed to v3 (`README.md` lines 42-47).
- Entry points point to v3 `HOW-TO-USE.md` and Memo framework `HOW-TO-USE.md` (`README.md` lines 91-99).

No README edit was needed.

### L9.2 — Reference build deferred

The reference build remains deferred to operator post-ship validation because a real reference build would require approximately 50-70 model sessions, 30-90 minutes of model time, and material token cost. The synthetic test is the appropriate Layer 8 gate for internal consistency: file integrity, script parse tests, YAML parse tests, cross-reference checks, invariant walkthrough, model-assignment plumbing, scorecard source checks, and Memo framework contract verification. The operator can run an empirical reference build next against a small KB of their choosing.

### L9.3 — Final CHANGELOG update

**Verdict:** PASS

After Checks 6 and 7 passed on mechanical re-validation, `CHANGELOG.md` was updated to mark v3.0.0 as Released on 2026-06-07 and to note the two remediated documentation defects.

## Recommendations for operator-conducted reference build

1. **Small Company KB (~14 topics, well-bounded):** good first empirical run because company facts exercise volatile-tagging, citation density, and institution-fact discipline without a dense statute corpus.
2. **Single-regulator enforcement tracker Topic KB:** compact enough for a fast build while stressing currency, source hierarchy, and post-assembly fact-checking.
3. **Person KB:** small artifact count and clear source hierarchy; useful to validate structural/size compliance and table-of-authorities behavior.
4. **Narrow standards-organization policy KB:** exercises version specificity, source-corpus boundaries, and model-family separation without requiring a full legal-regulatory build.

## Defects remediated during Layer 9 closeout

1. **Missing per-invariant enforcement matrix in the v3 technical specification** (Check 6) — fixed by adding the 27-row §12.1 invariant enforcement matrix.
2. **Six Rules wording not byte-identical across required files** (Check 7) — fixed by aligning `prompts\00-README.md` and adding a canonical Six Rules block to `01-shared-axioms.md`.
