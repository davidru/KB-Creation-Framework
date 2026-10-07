# KB Creation Framework v3.1 L7 Synthetic Conformance Test Report

- Date: 2026-06-07
- Framework version under test: v3.1.0
- Active host: GitHub Copilot CLI; PowerShell 7.6.2 (`pwsh`) for script smoke tests
- Framework root: `<framework-root>`
- Initial L7 verdict: **FAIL**
- Initial L7 check counts: **PASS=11; WARN=1; FAIL=3**
- Post-remediation verdict: **PASS-WITH-WARNINGS**

Note: The plan's `/tmp` output paths were not used because this session is under a no-`/tmp` file-operation constraint. Equivalent project-local scratch paths under `examples\_l7-conformance-scratch` were used for transient JSON/YAML outputs and removed after evidence collection. `Invoke-FrameworkDoctor.ps1` also exercised its normal cache-refresh behavior.

## Check 1: Directory + file inventory — FAIL

Evidence:
- Phase 1 inventory expected 22 file-level artifacts when adapter README/dispatch/discover files are counted; 21/22 were present.
- Phase 2 inventory: 7/7 present (`HOST-CONTRACT.md`, `hosts\README.md`, host notes, and prompt/document updates).
- Phase 1.5 inventory: 13/13 present (9 usability scripts + 4 YAML audit-template files).
- Phase 3 inventory: 3/3 root files present, and the sibling memo framework exists at `<memo-framework-root>` with required prompt/changelog files.
- Missing blocking artifact: `adapters\model-providers\README.md`.

Recommended remediations:
- Add `adapters\model-providers\README.md` documenting the provider adapter contract for `dispatch.ps1` and `discover.ps1`, including args, outputs, and error semantics.

## Check 2: PowerShell script parse cleanliness — PASS

Evidence:
- Parsed 34 PowerShell scripts with `[scriptblock]::Create((Get-Content X -Raw))`.
- Scope included framework-root `.ps1`, `adapters\model-providers\*\*.ps1`, and memo-framework root `.ps1` files.
- Parse failures: 0.

## Check 3: Model Registry end-to-end resolution — PASS

Evidence:
- `Validate-ModelRegistry.ps1 -RegistryPath model-registry.example.yaml` exited 0 and reported `Model Registry validation: PASS`; non-fatal warnings were limited to missing optional environment variables.
- Handles declared in `model-registry.example.yaml`: 14.
- `Resolve-Model.ps1 -Handle <handle> -RegistryPath model-registry.example.yaml` resolved 14/14 handles with provider/model/family output.
- `Infer-Family.ps1 -ModelId 'claude-opus-4.7'` returned `anthropic`.
- `Infer-Family.ps1 -ModelId 'gpt-5.4'` returned `openai`.
- `Infer-Family.ps1 -ModelId 'gemini-3-pro'` returned `google`.

## Check 4: Provider adapter discovery (LIVE) — PASS

Evidence:
- `copilot-cli\discover.ps1` exited 0 and returned 19 models (threshold: ≥15).
- `openrouter\discover.ps1` exited 0 and returned 341 models (threshold: ≥200).
- `openrouter\discover.ps1 -Category legal` exited 0 and returned 18 models (threshold: ≥5).
- `ollama\discover.ps1` exited 0 and returned 2 local models, so it did not crash when queried.
- `azure-foundry\discover.ps1` was run with `AZURE_FOUNDRY_ENDPOINT`/`AZURE_FOUNDRY_API_KEY` cleared; it exited 1 with informative JSON: `Required environment variable is not set: env:AZURE_FOUNDRY_ENDPOINT`.

## Check 5: Provider adapter dispatch error handling — PASS

Evidence:
- `azure-foundry\dispatch.ps1` with env vars cleared exited 1 and wrote error JSON with `status: error` and missing `AZURE_FOUNDRY_ENDPOINT` detail.
- `openrouter\dispatch.ps1` with `OPENROUTER_API_KEY` cleared exited 1 and wrote error JSON: `OPENROUTER_API_KEY is not set`.
- `copilot-cli\dispatch.ps1 -ModelId claude-opus-4.7` exited 0 and returned a dispatch envelope with `status: ready` and `host_invocation.tool: task`.
- `copilot-cli\dispatch.ps1 -ModelId bogus-model` exited 1 and returned `status: error`, `error.code: unknown_model_id`.

## Check 6: Usability scripts smoke — FAIL

Evidence:
- `Test-Setup.ps1` exited 0 and produced a setup report: `Verdict: PASS (FAIL=0 WARN=10)`.
- The 10 `Test-Setup.ps1` warnings were environment/default-live-test warnings, not separate synthetic conformance defects: missing optional env vars for handles (`COPILOT_CLI_ENDPOINT`, `COPILOT_CLI_TOKEN`, `AZURE_FOUNDRY_ENDPOINT`, `AZURE_FOUNDRY_API_KEY`, `OPENROUTER_ENDPOINT`, `OPENROUTER_API_KEY`, `OLLAMA_ENDPOINT`, `OLLAMA_API_KEY`), Azure provider reachability not configured, and live dispatch tests skipped by default.
- `Discover-OpenRouterCategories.ps1 -OutPath <scratch>\openrouter-categories.cached.yaml` exited 0 and wrote the category cache.
- `Recommend-Models.ps1 -Provider openrouter -Role lead -Domain legal -TopN 5 -OutPath <scratch>\recs.json` exited 0 and wrote ranked JSON recommendations.
- `Invoke-FrameworkDoctor.ps1` exited 0 and ran through diagnostics/cache refresh.
- Blocking defect under user Check 6: `Resume-Build.ps1 -Help` exited 1 with `A parameter cannot be found that matches parameter name 'Help'`.
- Blocking defect under user Check 6: `Initialize-Framework.ps1 -Help` exited 1 with `A parameter cannot be found that matches parameter name 'Help'`. `Initialize-Framework.ps1` also did not expose a `-DryRun` switch, so the accepted fallback path was `-Help`, which failed.

Recommended remediations:
- Add a `-Help` switch to `Resume-Build.ps1` that prints usage/help and exits 0.
- Add either `-DryRun` or `-Help` support to `Initialize-Framework.ps1`; for L7 parity, `-Help` should print non-interactive help and exit 0.

## Check 7: HOST-CONTRACT.md normative validation — PASS

Evidence:
- `HOST-CONTRACT.md` exists at the framework root.
- Required sections are present: §1 Purpose/Scope, §2 Required Capabilities, §3 Capability Levels, §4 HOST-NOTES contract, §5 Validate-Host contract, §6 Degradation Handling.
- §2.4 Sub-agent dispatch is normative and says the host `MUST` accept a model handle selected by Phase 0.0 and resolved through the Model Registry.
- L1a/L1b distinction is documented; L1b is explicitly not L1a for Rule 19 purposes.

## Check 8: HOST-NOTES per-host coherence — PASS

Evidence:
- `hosts\copilot-cli\HOST-NOTES.md` declares `Capability level: L1a — VERIFIED by direct use` and references `HOST-CONTRACT.md` sections.
- `hosts\opencode\HOST-NOTES.md` declares `L3 — not production-validated, conservative`, documents the L1a promotion target, and references `HOST-CONTRACT` sections.

## Check 9: Phase 0.0 prompt updates — FAIL

Evidence:
- `prompts\00a-model-selection.md` references all four sub-flows: preset, custom, discover, recommend.
- It references `Validate-ModelAssignment.ps1`, `Recommend-Models.ps1`, and `Discover-OpenRouterCategories.ps1`.
- Blocking defect under user Check 9: it does **not** reference `Resolve-Model.ps1`, despite the L7 acceptance criterion requiring that script to be named in the Phase 0.0 prompt.
- It does correctly state that `model_assignment` values are Model Registry handles, not raw model IDs.

Recommended remediations:
- Update `prompts\00a-model-selection.md` to explicitly reference `Resolve-Model.ps1` in pre-flight/closeout, e.g., require resolving selected handles before final assignment validation and before displaying provider/model/family details.

## Check 10: Orchestrator host-neutrality — WARN

Evidence:
- `prompts\01-orchestrator.md` does not assume Copilot CLI is the sole host.
- It references `HOST-CONTRACT.md` and `hosts/<host-name>/HOST-NOTES.md` and describes lower-capability host degradation.
- Warning: the prompt does not explicitly name Copilot CLI as one example among multiple hosts (nor OpenCode by name). The core host-neutrality requirement is satisfied, but the parenthetical acceptance language expected Copilot CLI to be named as one of multiple.

Recommended remediations:
- Add a short neutral example such as: `Supported HOST-NOTES currently include Copilot CLI and OpenCode; always follow the active host's HOST-NOTES rather than assuming a host-specific tool shape.`

## Check 11: Domain-aware recommendation — PASS

Evidence:
- `Recommend-Models.ps1` reads `audit-templates\domain-capabilities.yaml` and queries the OpenRouter provider adapter with `-Category <domain>` when applicable.
- The `legal` recommendation output included both signals: `openrouter_category_signal` and `benchmark_domain_signal`.
- `audit-templates\domain-capabilities.yaml` includes `legal`, `coding`, and `general` domains.
- `audit-templates\role-profiles.yaml` defines all six framework role profiles required by user Check 11: `lead`, combined `builder_a_b`, `critic_rubber_duck`, `fact_checker`, `auditor`, `memo_writer`.
- `audit-templates\capability-tiers.yaml` includes populated default tier labels: `premium`, `advanced`, `mid`, and `budget`.

## Check 12: Memo framework parity — PASS

Evidence:
- Sibling directory exists: `Memo Drafting Framework v1 + Provider Registry\`.
- Memo prompts reference handle/model-assignment concepts and do not contain raw model IDs matching `claude-*`, `gpt-*`, or `gemini-*` patterns.
- Memo `CHANGELOG.md` documents the provider-registry fork from v1.

## Check 13: v3.0 spec + recreation prompt archived — PASS

Evidence:
- `specification\technical-specification-v3.0.md` has an archived header pointing to v3.1.0.
- `specification\llm-recreation-prompt-v3.0.md` has an archived header pointing to v3.1.0.
- `specification\technical-specification-v3.1.0.md` and `specification\llm-recreation-prompt-v3.1.0.md` both exist.

## Check 14: Migrate script v3.0→v3.1 path — PASS

Evidence:
- `Migrate-V2KBtoV3.ps1 -Help` exited 0.
- Help documents `-FromVersion v2|v3.0` and explains auto-detection.
- Top-of-script content contains auto-detection indicators for `FromVersion`/`v3.0`.
- v2 migration-path indicators remain present, including `v2`, `model_assignment`, `pipeline_state`, and `sources` logic.

## Check 15: CHANGELOG completeness — PASS

Evidence:
- `CHANGELOG.md` contains a `[3.1.0]` section.
- The section includes `Added`, `Changed`, and `Preserved` subsections.
- Major v3.1 additions are documented: Model Registry, Host Abstraction/HOST-CONTRACT, usability scripts, and Memo framework fork.

## Final verdict

**FAIL.** L7 found blocking synthetic conformance defects. Promotion should stop until the missing adapter contract README, usability-script help support, and Phase 0.0 `Resolve-Model.ps1` reference are remediated. The orchestrator host-neutrality warning is non-blocking but should be cleaned up before rerun.

Summary counts: **PASS=11; WARN=1; FAIL=3**.

## Post-remediation re-verification (2026-06-07)

The parent agent remediated all blocking FAIL items inline and cleaned up the one WARN item. Re-verification evidence:

| ID | Original disposition | Fix applied | Re-verification command | Result |
|---|---:|---|---|---:|
| `adapter-README` | FAIL | Created `adapters\model-providers\README.md`; documents the full `dispatch.ps1` + `discover.ps1` adapter contract, including parameters, JSON envelope schemas, and error semantics. | `Get-Item adapters\model-providers\README.md` | PASS — file exists, 7005 bytes. |
| `Resume-Build-Help` | FAIL | Added `-Help` switch parameter plus a top-of-script help block that prints usage and exits 0. | `pwsh -NoProfile -File .\Resume-Build.ps1 -Help` | PASS — exits 0 and prints usage block. |
| `Initialize-Framework-Help` | FAIL | Added `-Help` switch parameter plus a top-of-script help block that prints usage and exits 0. | `pwsh -NoProfile -File .\Initialize-Framework.ps1 -Help` | PASS — exits 0 and prints usage block. |
| `00a-references-Resolve-Model` | FAIL | Updated COMMON CLOSEOUT step 2 to require per-handle resolution via `Resolve-Model.ps1` before validation. | `(Select-String -LiteralPath .\prompts\00a-model-selection.md -Pattern 'Resolve-Model.ps1').Count` | PASS — 4 matches. |
| `orchestrator-host-examples` | WARN | Updated `prompts\01-orchestrator.md` HOST-CONTRACT DEFAULT section to name "Copilot CLI and OpenCode" explicitly as v3.1 supported HOST-NOTES. | `Select-String -LiteralPath .\prompts\01-orchestrator.md -Pattern 'Copilot CLI and OpenCode'` | PASS — expected sentence present. |

### Updated aggregate verdict

**PASS-WITH-WARNINGS**. All original FAIL items are resolved, and the original WARN item has been addressed. The remaining caveat is intentional: the OpenCode HOST-NOTES retain a conservative L3 capability assignment pending first-build runtime promotion through `Validate-Host.ps1` to L1a. That conservative assignment follows the primary-source verification gate and is not a defect.

## v3.1.5 post-defect audit (2026-06-07)

The original L7 conformance test missed an OpenCode end-to-end rendering gap: HOST-NOTES §5.1 required rendering `opencode.json` from `model_assignment`, but no `Render-OpenCodeAgents.ps1` script existed. File-existence and prompt-reference checks did not prove that OpenCode static agents were actually generated.

The verification that should have caught the defect: run Phase 0.0, invoke `Render-OpenCodeAgents.ps1`, and verify that it produces a valid `opencode.json` with per-role `agent` entries whose `model` values match the resolved `model_assignment` provider/model_id pairs.

Recommendation: future conformance tests should include host-specific end-to-end smoke tests for each declared L1a/L1b host, not just file-existence checks.
