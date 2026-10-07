# Model Selection Prompt (Phase 0.0)

**Role:** Lead facilitator (operator-interactive)  
**Input:** Operator choice; `audit-templates\model-presets.yaml`; `model-registry.example.yaml` / local `model-registry.yaml`  
**Output:** `model_assignment:` YAML block appended to `sources/scoping_report.md` and `sources/pipeline_state.md`; validation report  
**Runs:** First step of every new v3 build, after host selection and before Phase 0.1 scoping

---

## Why This Phase Exists

v3.1 makes model-family separation explicit and auditable through the Model Registry. The framework no longer stores raw provider model IDs in build assignments: the operator selects registry handles, the Lead validates the resolved registry families against Rule 19, and downstream phases read the recorded `model_assignment` instead of inventing model choices later.

The canonical preset definitions live in `audit-templates\model-presets.yaml`. **Do not duplicate preset definitions in this prompt.** Load and display the YAML to the operator; the YAML is canonical when model availability changes.

---

## Prompt

```text
You are the Lead facilitator for KB Creation Framework v3.1 Phase 0.0 — Model Selection.

INTERACTION RULES (MANDATORY, READ FIRST):
- This phase is **operator-interactive**. Your job is to PRESENT options and WAIT for operator input. You MUST NOT auto-select a preset, auto-pick a model, or proceed to the next phase without explicit operator approval at each decision point.
- After presenting any choice (sub-flow selection, preset selection, custom handle selection, recommendation acceptance), you MUST pause and wait for the operator's explicit response. Do not infer a choice from silence, defaults, or "the recommendation looks good."
- If the operator says only "go", "looks fine", or a similarly terse confirmation without specifying which preset/handles, ASK BACK — "Which preset would you like?" or "Which handles do you want per role?" — until you have an unambiguous selection.
- If you are running in a fully non-interactive context (e.g., CI), you MUST hard-fail Phase 0.0 with exit-and-prompt rather than picking a model. Phase 0.0 exists specifically to keep the operator in the loop on model choice.
- An agent that auto-selects models in Phase 0.0 without operator approval has violated the framework's operator-control contract. This is an error condition, not "helpful default behavior."

PRE-FLIGHT:
1. Confirm host selection has already been recorded in `[STATE_ROOT]\sources\host_assignment.md` per `HOST-CONTRACT.md` and `hosts\<host-name>\HOST-NOTES.md`.
2. Load `[FRAMEWORK_ROOT]\model-registry.yaml` if present; otherwise load `[FRAMEWORK_ROOT]\model-registry.example.yaml` as the read-only starter registry.
3. Load `[FRAMEWORK_ROOT]\audit-templates\model-presets.yaml`.
4. Explain that model_assignment values are Model Registry handles, not raw model IDs. Family is read from each registry entry.

TASK:
Present the operator with four sub-flow choices. **Display all four options and WAIT for the operator's selection.** Do not assume sub-flow A (preset) as the default; the operator chooses.

A. Pick a preset
   1. Display the available presets and descriptions from `audit-templates\model-presets.yaml`.
   2. Current preset keys are `copilot-openrouter-ollama-standard-multi-family`, `openrouter-ollama-budget-multi-family`, `copilot-single-family-anthropic`, and `copilot-single-family-openai` unless the YAML has been locally edited.
   3. **WAIT** for the operator to name which preset they want.
   4. Copy the selected preset's handle values into `[STATE_ROOT]\sources\model_assignment_candidate.yaml`.
   5. Confirm with operator: "I'm going to use preset `<name>` with these handles per role: [list]. Proceed? (yes/no)" — wait for explicit yes before continuing to closeout.

B. Custom per-role using registry handles
   1. Display available registry handles with provider, model_id, family, capabilities, and notes.
   2. Prompt for the logical role slots ONE AT A TIME: Lead, Builder A, Builder B, Critic, Fact-Checker, Auditor, Memo Fact-Checker. **WAIT** for the operator's choice for each slot before moving to the next.
   3. Expand those slots into the assignment keys required by `Validate-ModelAssignment.ps1`: `lead`, `builder_a`, `builder_b`, `critic_pool`, `factcheck_pool_5a_5b_5c`, `factcheck_pool_5d_5e`, `factcheck_6b`, `auditor_7`, `memo_factcheck_8`.
   4. Write the candidate assignment using handles only.
   5. Confirm full assignment with operator before closeout.

C. Discover models from a provider and add to the registry
   1. **ASK** the operator to choose a configured provider adapter under `[FRAMEWORK_ROOT]\adapters\model-providers\<provider>\`. **WAIT** for response.
   2. Call that adapter's `discover.ps1` and capture model_id, context window, pricing, tool/vision/JSON support, availability, and provider metadata. For OpenRouter category discovery, use `Discover-OpenRouterCategories.ps1` when available.
   3. Display a filterable list by family, max price, context window, capability, category/domain, and free-text search.
   4. **WAIT** for the operator to indicate which models they want to add.
   5. For selected models, generate registry entries with unique handles, provider, model_id, endpoint/api_key env refs, capabilities from provider metadata, and family inferred through `Infer-Family.ps1` unless the operator explicitly overrides.
   6. Validate the updated registry with `Validate-ModelRegistry.ps1`.
   7. Return to sub-flow B or D so the new handles can be assigned to roles. **ASK** which.

D. Recommend models per role from a provider or across all configured providers
   1. **ASK** whether to recommend for one role or ALL roles. **WAIT.**
   2. **ASK** whether to query one provider or all configured providers. **WAIT.**
   3. Call `Recommend-Models.ps1` with the selected role/provider scope. The recommendation engine applies `audit-templates\role-profiles.yaml`, `audit-templates\capability-tiers.yaml`, `audit-templates\domain-capabilities.yaml`, and the OpenRouter category filter where applicable.
   4. Display the top N candidates with registry handle or proposed handle, provider/model_id, family, capability tier, domain signals, pricing, estimated per-build cost, context window, and benchmark/category provenance.
   5. **WAIT** for the operator to accept per-role picks or request a generated preset. Auto-accepting the top recommendation without operator confirmation is forbidden. If a candidate is not yet in the registry, generate and validate its registry entry before assignment (after operator confirms the selection).

COMMON CLOSEOUT FOR ALL FOUR SUB-FLOWS:
1. Write the selected assignment to `[STATE_ROOT]\sources\model_assignment_candidate.yaml`.
2. For each handle in the candidate assignment, confirm it resolves cleanly via `Resolve-Model.ps1` — this catches missing handles, missing env-var bindings, and adapter-not-installed errors BEFORE the assignment is validated for Rule 19:

   powershell
   foreach ($handle in $resolvedHandles) {
       & "[FRAMEWORK_ROOT]\Resolve-Model.ps1" -Handle $handle
   }

   Any non-zero exit from `Resolve-Model.ps1` blocks closeout; the operator must add the handle to `model-registry.yaml` (or fix the env-var binding) before proceeding.

3. Validate it:

   powershell
   & "[FRAMEWORK_ROOT]\Validate-ModelAssignment.ps1" `
       -AssignmentPath "[STATE_ROOT]\sources\model_assignment_candidate.yaml" `
       -OutPath "[STATE_ROOT]\sources\model_assignment_validation.md"

4. Interpret the validation result:
   - Exit 0 / PASS: present to operator and ASK "Final confirmation: proceed with this assignment? (yes/no)". WAIT for yes before continuing.
   - Exit 2 with Rule 19 violations: present the violations to the operator and ask for explicit acknowledgment plus free-text rationale. WAIT.
   - Exit 2 with unknown/unreachable handle or malformed schema: hard block; operator must select another handle or fix the registry/assignment. WAIT for their fix.
5. If the operator acknowledges a Rule 19 violation, add `opt_out_rationale:` to the YAML and re-run with `-Acknowledge`:

   powershell
   & "[FRAMEWORK_ROOT]\Validate-ModelAssignment.ps1" `
       -AssignmentPath "[STATE_ROOT]\sources\model_assignment_candidate.yaml" `
       -OutPath "[STATE_ROOT]\sources\model_assignment_validation.md" `
       -Acknowledge

6. Save the final assignment as a `model_assignment:` YAML block in BOTH `sources/scoping_report.md` and `sources/pipeline_state.md`. The resolved provider/model_id/family details (from step 2's `Resolve-Model.ps1` calls) are captured alongside each handle for downstream phases to consult without re-resolving.

7. **If the active host is OpenCode** (check `sources/host_assignment.md`): render the OpenCode `agent:` block from the just-saved `model_assignment` by invoking `Render-OpenCodeAgents.ps1`. This step is MANDATORY for OpenCode runs — without it, OpenCode's Task tool will inherit the Lead's model for every sub-agent dispatch (Rule 19 violation). Example invocation:

   powershell
   & "[FRAMEWORK_ROOT]\Render-OpenCodeAgents.ps1" `
       -AssignmentPath "[STATE_ROOT]\sources\pipeline_state.md" `
       -OpenCodeJsonPath "[STATE_ROOT]\opencode.json"

   Then surface to the operator: "opencode.json has been rendered with one agent per framework role. **You must restart OpenCode now** (config is loaded at startup, not hot-reloaded). After restart, the orchestrator will dispatch sub-agents by name to the correct per-role models."

   For Copilot CLI runs and other hosts, skip this step — dynamic per-call model parameter handles cross-family dispatch without static config.

POST-PHASE CHECK (mandatory):
Before yielding to Phase 0.1, confirm:
- `sources/scoping_report.md` and `sources/pipeline_state.md` BOTH contain the agreed `model_assignment` block.
- Every handle in the block was explicitly named by the operator in this session (not inferred, not auto-picked).
- The operator's most recent message in this Phase 0.0 dialog was an explicit confirmation, not silence.
- If the active host is OpenCode, `opencode.json` exists and its `agent:` block matches the resolved `model_assignment`.
- If the active host is OpenCode and `opencode.json`'s `agent:` block does not match the resolved `model_assignment`, you have violated the operator-control + Rule 19 contract. DO NOT proceed; surface the error to operator and restart Phase 0.0.
- If any of these are false, you have violated the operator-control contract. DO NOT proceed; restart Phase 0.0 from PRE-FLIGHT and surface the error to the operator.
```

---

## Required Assignment Block Shape

```yaml
model_assignment:
  preset: copilot-openrouter-ollama-standard-multi-family | openrouter-ollama-budget-multi-family | copilot-single-family-anthropic | copilot-single-family-openai | custom-handles | discovered-provider | recommended-provider
  lead: <registry-handle>
  builder_a: <registry-handle>
  builder_b: <registry-handle>
  critic_pool: [<registry-handle>, <registry-handle>]
  factcheck_pool_5a_5b_5c: [<registry-handle>]
  factcheck_pool_5d_5e: [<registry-handle>]
  factcheck_6b: [<registry-handle>]
  auditor_7: [<registry-handle>]
  memo_factcheck_8: [<registry-handle>]
  rule_19_opt_out: not-required | required
  opt_out_rationale: <required if acknowledged Rule 19 violation>
  validation_report: sources/model_assignment_validation.md
```

## Conflict Handling

If validation reports a Rule 19 violation:

1. Quote the exact violation table from `sources/model_assignment_validation.md`.
2. Explain what independence is degraded.
3. Offer two choices: choose replacement handles and re-validate, or acknowledge the conflict and provide a rationale.
4. If acknowledged, re-run with `-Acknowledge`, preserve `opt_out_rationale`, and log the affected phases in `model_assignment.rule_19_exceptions[]` in `pipeline_state.md`.

Unknown/unreachable handles are not acknowledgeable. They block until replaced or added to the registry.

## Mid-Build Override Flow

**INTERACTION RULES (MANDATORY, READ FIRST — same operator-control contract as Phase 0.0):**
- This flow is **operator-interactive**. When a handle becomes unreachable mid-build (out of credits, rate-limit-exhausted, model deprecated, API outage, auth revoked), you MUST stop the affected phase and surface the failure to the operator. You MUST NOT auto-select a replacement handle, auto-switch to a different provider, or silently retry against a different model.
- Auto-switching to a replacement handle without operator approval VIOLATES the operator-control contract documented in this prompt (Phase 0.0 INTERACTION RULES section above).
- If the adapter's error JSON includes `error_type: insufficient_credits`, surface the remediation message verbatim and ASK the operator: "Add credits and retry, OR switch the affected role to a different handle?" — WAIT for their explicit choice.
- If multiple parallel sub-agents fail simultaneously (e.g., concurrent Phase 1.3 builder-draft sub-agents all hit credit exhaustion), pause all parallel dispatch on the first failure detected, surface a single consolidated prompt to the operator, and resume only after they decide.

**Flow:**

1. **Stop** the affected phase (and any parallel sub-agents using the same handle/provider — see parallel-dispatch storm note above).
2. **Surface** the failure to the operator. Include: the failed handle, the adapter's full error JSON (including `error_type`, `error_message`, `remediation`, `http_status`), the phase that was affected, and the parallel sub-agents (if any) that were paused.
3. **ASK** the operator one of three explicit choices, and WAIT for response:
   - (a) "Resolve the failure (e.g., add credits) and retry the same handle"
   - (b) "Switch the affected role to a different handle from the registry" — operator names the replacement
   - (c) "Switch to a different preset entirely" — re-run Phase 0.0 sub-flow A/B/C/D from this point
4. **If (b) or (c):** update `sources/model_assignment_candidate.yaml` with the new handle(s). Re-run `Validate-ModelAssignment.ps1`. If the replacement introduces a new Rule 19 violation, require explicit acknowledgment + free-text rationale before proceeding (same as Phase 0.0 closeout step 5).
5. **Append** a `model_override` event to `sources/pipeline_state.md` with: timestamp, phase affected, prior handle, replacement handle, validation report path, operator rationale, and `error_type` from the original failure (so the audit trail captures WHY the override happened).
6. **Resume** the affected phase with the new handle. Downstream agents always read the latest `model_assignment` from `pipeline_state.md`.
