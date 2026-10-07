# Host Contract — KB Creation Framework
# Version: 3.1.0 | Created: 2026-06-06
# Scope: Normative host requirements for running the v3.1 KB Creation Framework.
# Dependencies: Model Registry, Resolve-Model.ps1, Validate-Host.ps1, hosts/<host-name>/HOST-NOTES.md.

---

## SECTION 1: PURPOSE + SCOPE

This contract defines what an agent host must provide before it can run the KB Creation Framework.

A **host** is the execution harness that reads framework prompts, writes framework artifacts, runs framework scripts, and dispatches model-backed sub-agents. Examples in v3.1 are Copilot CLI and OpenCode. Provider adapters and the Model Registry decide which model is used; the host decides how the framework actually executes work in the operator's environment.

The contract is deliberately narrow. It specifies the minimum behavior required for the framework to run with auditable model-family separation, resumable file state, and repeatable build artifacts.

### 1.1 Non-goals

1. This contract does **not** define model quality tiers. Model quality belongs in `audit-templates/capability-tiers.yaml` and role profiles.
2. This contract does **not** define provider authentication. Secrets remain provider-adapter concerns and use env-var indirection.
3. This contract does **not** require a host to expose the same UI, tool names, or orchestration syntax as another host.
4. This contract does **not** bless same-family verification. If the host cannot enforce Rule 19, the Quality Scorecard MUST say so.

---

## SECTION 2: REQUIRED CAPABILITIES

A supported host MUST satisfy the capabilities below at the level declared in its `hosts/<host-name>/HOST-NOTES.md`.

### 2.1 File-read with absolute paths

1. The host MUST read files by absolute path.
2. The host MUST preserve path identity in reports. If a source was read from `C:\...\file.md`, the output MUST cite that path rather than a host-local alias.
3. The host MUST surface read failures as explicit errors. Silent substitution, partial reads without warning, and guessed content are contract failures.

### 2.2 File-write with absolute paths, atomic per-file

1. The host MUST write files by absolute path.
2. The host MUST support atomic per-file writes: each framework artifact is either the prior complete file or the new complete file, never a half-written intermediate.
3. Atomic writes SHOULD be implemented by writing a temporary sibling file in the same directory and replacing the target in a single move/rename operation.
4. Atomicity is mandatory for `sources/pipeline_state.md`, scorecards, phase outputs, and any artifact used by `Resume-Build.ps1`.
5. If a host cannot guarantee atomic per-file writes, it MUST NOT be declared above L3 and the Quality Scorecard MUST record the limitation.

### 2.3 Shell command execution — PowerShell 7+ floor

1. The host MUST execute shell commands in the operator's environment.
2. The host MUST support PowerShell 7+ (`pwsh`) as the floor for framework scripts and CLI-wrapping adapters.
3. The host MAY support bash or other shells, but bash support is not a substitute for the PowerShell floor in v3.1.
4. The host MUST return command exit code, stdout, stderr, and timeout status in a form the orchestrator can record.
5. The host MUST NOT hide script failures behind successful natural-language summaries.

### 2.4 Sub-agent dispatch

1. The host MUST dispatch a sub-agent from a prompt file path.
2. The host MUST accept a model handle selected by Phase 0.0 and resolved through the Model Registry.
3. The Model Registry resolves `handle -> provider + family + model_id + endpoint + adapter path`. The host receives or invokes against the resolved `(model_id, endpoint)` pair and MUST preserve the resolved `family` for Rule 19 accounting.
4. The host MUST return structured output. Markdown is required. JSON MAY be returned when the prompt or adapter requests a machine-readable companion artifact.
5. The host MUST record enough dispatch metadata for audit: prompt file, role, model handle, resolved family, provider, model_id, start time, end time, success/failure, and output path.
6. The host MUST treat provider-adapter errors as dispatch failures, not as empty successful outputs.

### 2.5 Parallel sub-agent dispatch — L1a requirement

1. An L1a host MUST support at least four concurrent sub-agent dispatches.
2. The concurrent sub-agents MUST be able to use different model families within the same framework session.
3. Parallel dispatch that forces all sub-agents to inherit the parent session's model is L1b, not L1a.
4. Parallel dispatch is required for the framework's intended wall-clock profile, but cross-family parallel dispatch is required for full Rule 19 enforcement.

### 2.6 Optional streaming progress / steerable mid-flight feedback

1. A host MAY expose streaming progress, partial output, or mid-flight steering.
2. Streaming is not required for L1a.
3. If provided, streaming MUST NOT replace the final structured output artifact.
4. Mid-flight steering MUST be logged when it materially changes a sub-agent's task, scope, or model assignment.

---

## SECTION 3: CAPABILITY LEVELS

Capability level is a property of the active host configuration, not the marketing name of the tool. `Validate-Host.ps1` records the actual level observed at session start.

| Level | Name | Required host behavior | Rule 19 implication | Scorecard treatment |
|---|---|---|---|---|
| L1a | Full Multi-Agent with Cross-Family | Parallel sub-agent dispatch and per-sub-agent model selection across model families in one session. Minimum four concurrent dispatches. | Rule 19 fully enforced as designed. Generation and verification can run in different families without serial workarounds. | Normal methodology statement. No degradation flag. |
| L1b | Parallel Single-Family | Parallel sub-agent dispatch exists, but sub-agents inherit the parent session's model family or otherwise cannot be assigned cross-family models concurrently. | Same-session parallel outputs do not satisfy Rule 19. The orchestrator MUST either rerun verification sequentially with a different family where the host supports model switching, or record a family-separation exception. | Scorecard records `L1b` and identifies each phase where parallel same-family work was used. |
| L2 | Sequential Multi-Model | No usable parallel sub-agent fleet, but the host can switch model handles between phases or dispatches. | Rule 19 can be enforced sequentially. Wall-clock increases; independence is preserved if the model-family log confirms separation. | Scorecard records `L2` degradation for performance only, unless a phase still lacks family separation. |
| L3 | Single-Model | Host cannot switch model families for framework work. | Rule 19 cannot be enforced. Same-family generation and verification is self-grading risk. | Scorecard MUST mark the verdict `CONDITIONAL` and list the affected dimensions. |

### 3.1 Level rules

1. L1a is the v3.1 design target.
2. L1b is not "almost L1a" for Rule 19. Parallel-but-same-family is fast, but it is still same-family verification.
3. L2 is acceptable for quality if model-family separation is actually achieved across phases. It is a runtime degradation, not automatically a quality degradation.
4. L3 is a quality degradation. It MAY be used for exploratory builds, but any deliverable built at L3 MUST carry the conditional methodology disclosure.
5. A host MAY support multiple levels depending on configuration. The active run level is the one observed by `Validate-Host.ps1`, not the best possible configuration.

---

## SECTION 4: PER-HOST HOST-NOTES CONTRACT

Each supported host MUST have a `hosts/<host-name>/HOST-NOTES.md` file before it is used for a production framework run.

The HOST-NOTES file MUST document:

1. **Declared level** — L1a, L1b, L2, or L3.
2. **Verification source** — direct use, primary host documentation, repository source file, or another verifiable source. Secondary summaries are not enough for new-host promotion.
3. **File-read implementation** — exact host mechanism for absolute-path reads.
4. **File-write implementation** — exact host mechanism for atomic per-file absolute-path writes.
5. **Shell implementation** — how the host runs `pwsh` and captures exit code/stdout/stderr.
6. **Sub-agent dispatch implementation** — how the host invokes a prompt-file-backed sub-agent and where output is written.
7. **Model Registry integration** — how the host receives or calls `Resolve-Model.ps1`, and how the resolved `family`, `provider`, `model_id`, and `endpoint` are logged.
8. **Parallelism semantics** — maximum tested concurrency, whether sub-agents can use different families in the same session, and how failures are reported.
9. **Streaming / steering support** — present, absent, or not tested.
10. **Known degradations** — any capability that forces L1b, L2, or L3 treatment.
11. **Last verification date** — date and method of the most recent successful `Validate-Host.ps1` smoke test.

HOST-NOTES are evidence files, not marketing blurbs. If the host's behavior is uncertain, the notes MUST say uncertain and the host MUST be scored at the lower verified level.

---

## SECTION 5: VALIDATE-HOST.PS1 CONTRACT

`Validate-Host.ps1` is the smoke test for this contract. It runs before Phase 0.0 in new v3.1 builds and whenever `Test-Setup.ps1` or `Invoke-FrameworkDoctor.ps1` checks framework health.

The validator MUST test:

1. Absolute-path file-read.
2. Absolute-path file-write with atomic replacement semantics.
3. PowerShell 7+ shell execution.
4. Trivial sub-agent dispatch from a prompt file.
5. Model Registry resolution for at least two handles from different families.
6. Cross-family sub-agent dispatch where the host claims L1a.
7. Four-way concurrent dispatch where the host claims L1a or L1b.
8. Structured output capture: Markdown required, JSON optional when requested.

The validator MUST output a machine-readable result and a human-readable summary. At minimum, it records:

| Field | Meaning |
|---|---|
| `host_name` | Host under test. |
| `declared_level` | Level claimed by HOST-NOTES. |
| `observed_level` | Level demonstrated by the smoke test. |
| `capabilities_passed` | Capability checklist with pass/fail/skipped. |
| `model_families_tested` | Families used for cross-family dispatch. |
| `max_concurrency_observed` | Highest successful concurrent dispatch count. |
| `failures` | Failure messages with command/output references. |
| `validated_at` | Timestamp of the smoke test. |

If `observed_level` is lower than `declared_level`, the observed level controls the run. The orchestrator MUST NOT proceed on the higher declared level.

---

## SECTION 6: DEGRADATION HANDLING

The framework degrades honestly. It does not pretend an L1b, L2, or L3 run had L1a independence.

### 6.1 Required scorecard disclosure

When the active host runs below L1a, the Quality Scorecard MUST record:

1. Active host name.
2. Declared capability level.
3. Observed capability level from `Validate-Host.ps1`.
4. Which capabilities failed or were unavailable.
5. Which phases were affected.
6. Whether Rule 19 was fully enforced, sequentially enforced, or not enforced.
7. Any operator-approved opt-out path used.
8. Consequence for verdict: normal, tagged dimension score, or `CONDITIONAL`.

### 6.2 Degradation rules

1. L1b MUST be disclosed as parallel same-family execution. It cannot be described as full multi-agent cross-family review.
2. L2 MUST be disclosed as sequential execution. If Rule 19 is preserved, the scorecard SHOULD treat the degradation as runtime-only.
3. L3 MUST produce a `CONDITIONAL` scorecard verdict for any build that uses model output for both generation and verification.
4. Any phase that cannot produce a structured output because of host limitations MUST be rerun on a capable host or marked incomplete. It MUST NOT be silently summarized into existence.
5. Degradation does not waive source fidelity, fact-checking, or audit obligations. It only changes how the framework records independence and runtime limitations.
