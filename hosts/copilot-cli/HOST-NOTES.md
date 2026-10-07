# Copilot CLI HOST-NOTES
# Version compatibility: Copilot CLI 1.0.60+
# Capability level: L1a — VERIFIED by direct use
# Last verification: 2026-06-07

---

## SECTION 1: STATUS

Copilot CLI is the v3.1 default host. It satisfies `HOST-CONTRACT.md` at **L1a — Full Multi-Agent with Cross-Family** when the active CLI account exposes the required model families and the framework runs through the Copilot CLI provider adapter.

Verification source: direct operator use of Copilot CLI as the v3.0 baseline, plus v3.1 planning validation of per-dispatch `task` model overrides across Claude, GPT, Gemini, MAI/internal, and other Copilot-CLI-visible families. This is evidence-backed host behavior, not a marketing claim. `Validate-Host.ps1` remains authoritative for the observed level at run start.

---

## SECTION 2: CAPABILITY-BY-CAPABILITY SATISFACTION

| HOST-CONTRACT capability | Copilot CLI mechanism | Tool / adapter mechanism | Limitations and caveats |
|---|---|---|---|
| §2.1 File-read with absolute paths | Copilot CLI reads files by absolute Windows paths and preserves the path used in reports. Read failures surface as explicit tool errors. | `view` for file reads; `grep`/`glob` for discovery; adapter-side `Get-Content -LiteralPath` where a script must read a prompt file before dispatch. | Large files may need ranged reads; partial/truncated reads must be treated as incomplete until finished. No guessed content. |
| §2.2 File-write with absolute paths, atomic per-file | Copilot CLI writes by absolute path and can perform all-or-nothing artifact replacement. | `create` for new files; `edit` for exact replacements; framework scripts/adapters use sibling temp-file write plus same-directory replace/move for resumable artifacts such as `sources\pipeline_state.md`. | The framework must use the adapter/script atomic-write path for state files and scorecards. Do not rely on incremental shell redirection for critical artifacts. |
| §2.3 Shell command execution — PowerShell 7+ floor | Copilot CLI executes commands in the operator environment and can invoke `pwsh` for framework scripts. | `powershell` tool running `pwsh -File ...` or inline PowerShell; captures stdout/stderr/exit status and timeout state for logging. | Each shell call is a fresh process. Any environment setup needed for a command must happen in the same invocation. Bash is optional and not a substitute for `pwsh`. |
| §2.4 Sub-agent dispatch | Copilot CLI dispatches prompt-backed sub-agents with per-dispatch model selection. | `task` tool with `prompt`, `agent_type`, `name`, and `model` parameter. The Copilot CLI adapter reads the prompt file, resolves the model handle, passes `model: <resolved model_id>`, and writes the returned Markdown to the framework output path. | The `model` value must be a Copilot-CLI-known model ID. Availability depends on the active Copilot CLI account and model menu. Adapter errors are dispatch failures, not empty successes. |
| §2.5 Parallel sub-agent dispatch — L1a requirement | Copilot CLI supports concurrent background sub-agents and per-sub-agent model overrides, including different model families in one session. | Multiple `task` calls in one tool-use block with `mode: "background"`; later collection through the agent-read mechanism. Blocking work uses `mode: "sync"`. | L1a requires at least four concurrent dispatches and cross-family model assignment. If a runtime account cannot access enough families, `Validate-Host.ps1` must downgrade the observed level. |
| §2.6 Optional streaming progress / steerable mid-flight feedback | Copilot CLI can expose background-agent status and intermediate turns, but streaming is not required for L1a. | Background agent status/result reads; steerable agents where the host exposes mid-flight feedback. | Final structured output remains mandatory. Streaming cannot replace the Markdown artifact and material steering must be logged. |

---

## SECTION 3: MODEL DISPATCH MAPPING

The framework Lead does not hard-code Copilot model names. It works in model handles from `model_assignment` and lets the registry/adapter translate them.

Dispatch contract:

1. Phase 0.0 writes `model_assignment` to `sources\scoping_report.md` and `sources\pipeline_state.md`.
2. Before dispatch, the Lead reads the latest assignment and selects the role handle.
3. `Resolve-Model.ps1 -Handle <handle>` resolves the handle to `provider`, `family`, `model_id`, `endpoint`, capabilities, and notes.
4. If `provider: copilot-cli`, `adapters\model-providers\copilot-cli\dispatch.ps1` is responsible for converting the resolved entry into a Copilot CLI `task` invocation.
5. The adapter passes `model: <model_id>` to `task`, preserves `family` for Rule 19 accounting, and logs prompt file, role, handle, provider, model ID, family, start/end time, success/failure, and output path.

The prompt-file requirement in HOST-CONTRACT §2.4 is satisfied by the adapter: it reads the prompt file from an absolute path, passes the prompt content to `task`, and records the original prompt path in dispatch metadata.

---

## SECTION 4: PARALLEL DISPATCH SEMANTICS

Copilot CLI supports two dispatch modes the orchestrator uses deliberately:

- `mode: "sync"` — blocking dispatch for single checks, smoke tests, and phases where the Lead needs the result before moving on.
- `mode: "background"` — fire-and-collect dispatch for independent agents. The Lead launches the fleet, continues non-overlapping work, then collects each result and writes the phase artifacts.

Phase 1.3 builder-draft fanout uses background mode. The Lead dispatches per-topic `13-builder-draft.md` prompts to Builder A and Builder B, normally **4-6 topic prompts concurrently per builder** with a total cap of **8-12 concurrent**. This exceeds the HOST-CONTRACT §2.5 L1a minimum of four concurrent sub-agents while preserving builder isolation.

Failure rule: a failed background task is a failed phase item. The Lead records the failure, reruns or remediates under the phase prompt, and does not summarize a missing artifact into existence.

---

## SECTION 5: RULE 19 ENFORCEMENT

Rule 19 is enforced before host dispatch and audited during dispatch.

- `Validate-ModelAssignment.ps1` checks the assignment for model-family separation: Lead, Builder A, Builder B, critics, fact-checkers, auditors, and memo fact-checkers must resolve to distinct families where the framework requires separation.
- `Resolve-Model.ps1` and the model registry carry the provider/model/family data that the Copilot CLI adapter logs for each dispatch.
- Copilot CLI-accessible models already span the families needed for L1a operation, including Claude/Anthropic, GPT/OpenAI, Gemini/Google, MAI/internal Microsoft, and other registry-defined families where available.
- Same-family generation and verification requires an explicit Rule 19 opt-out. Without that opt-out, validation blocks or the observed host level is downgraded.

The host's job is not to infer family separation from model names at runtime. The host must preserve and log the resolved family supplied by the registry/validator path.

---

## SECTION 6: VALIDATE-HOST.PS1 EXPECTATIONS ON COPILOT CLI

`Validate-Host.ps1` should smoke-test Copilot CLI end-to-end before Phase 0.0. Expected sequence:

1. **File-read:** read a known test prompt by absolute path and confirm the output reports that path.
2. **File-write:** write a temporary sibling file, replace the target atomically, read it back, and delete the scratch artifact after validation.
3. **Shell exec:** run a trivial `pwsh` command, capture stdout, stderr, exit code, and timeout status.
4. **Model resolution:** resolve at least two registry handles from different families through `Resolve-Model.ps1`.
5. **Single dispatch:** dispatch a minimal prompt through `task` using one known-good Copilot CLI model handle; require a one-token or similarly trivial Markdown response.
6. **Cross-family parallel dispatch:** dispatch two parallel `task` calls with different resolved families and confirm both return structured Markdown.
7. **L1a concurrency:** dispatch four concurrent trivial tasks when claiming L1a and record `max_concurrency_observed >= 4`.
8. **Report:** emit machine-readable fields required by HOST-CONTRACT §5: declared level, observed level, passed capabilities, model families tested, max concurrency, failures, and timestamp.

If any required step fails, the observed level controls. The framework must not proceed on a higher declared level.

---

## SECTION 7: KNOWN LIMITATIONS / NON-GOALS

- Copilot CLI does not provide persistent framework agent memory across sessions. The framework does not need it; resumability lives in files such as `sources\pipeline_state.md`.
- Copilot CLI does not provide authoritative per-call cost accounting for framework scoring. `Estimate-BuildCost.ps1` should use provider pricing metadata and model registry data instead.
- The `task` model override can only use model IDs known to the active Copilot CLI installation/account. Not all model families are guaranteed to be available to every operator at every time.
- Copilot CLI is the host, not the model registry. Provider credentials, endpoints, pricing, and fallback policy remain registry/provider-adapter concerns.
- Streaming and mid-flight steering are optional conveniences. They are not relied on for L1a and cannot replace final artifacts.

---

## SECTION 8: VERIFICATION PROVENANCE

Verified by direct use 2026-06-07. Operator runs this framework on Copilot CLI as the v3.0 baseline; cross-family dispatch confirmed end-to-end.
