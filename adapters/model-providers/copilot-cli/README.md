# copilot-cli — Model Provider Adapter

**Purpose:** bridge the KB Creation Framework v3.1 Model Registry to Copilot CLI's host-native `task` tool. This adapter validates Copilot-CLI-known model IDs and emits a dispatch envelope the Copilot CLI host can turn into the actual `task` invocation.

**Use this adapter when:** a registry entry resolves to `provider: copilot-cli` and `model_id` is one of the model IDs exposed by the current Copilot CLI `task` model parameter (for example, `claude-opus-4.7`, `gpt-5.5`, or `gemini-3.1-pro-preview`). Existing v3.0 Copilot CLI operation should route through this adapter as the no-op/default provider path.

## Scripts

```powershell
pwsh .\dispatch.ps1 `
  -ModelId claude-opus-4.7 `
  -PromptPath C:\path\to\prompt.md `
  -OutPath C:\path\to\dispatch-envelope.json

pwsh .\discover.ps1 -OutPath C:\path\to\models.json
```

`dispatch.ps1` does **not** call Copilot CLI directly. It writes JSON shaped like:

```json
{
  "status": "ready",
  "adapter": "copilot-cli",
  "model_id": "claude-opus-4.7",
  "host_invocation": {
    "tool": "task",
    "parameters": {
      "model": "claude-opus-4.7",
      "prompt": "<prompt file contents>",
      "mode": "background"
    }
  }
}
```

The Copilot CLI host reads that envelope and performs the real `task` dispatch, adding any phase-specific task metadata it needs.

## Environment variables

None. Copilot CLI authentication, model entitlement, and sub-agent execution are host responsibilities. Unlike direct HTTP adapters, this adapter does not read API keys, endpoints, or deployment credentials.

## Known limitations

- Copilot CLI exposes no provider discovery API to this framework, so `discover.ps1` and `dispatch.ps1` use a hardcoded model list.
- A model ID being hardcoded here does not guarantee the active Copilot CLI account can use it.
- Pricing is `null` because Copilot CLI usage is not exposed as per-token provider pricing to this adapter.
- Context-window estimates are `null` unless Copilot CLI publishes authoritative values in a future version.

## Refreshing the hardcoded model list

When Copilot CLI versions bump or the `task` model menu changes:

1. Read the current Copilot CLI model list from `%USERPROFILE%\.copilot\copilot-instructions.md` `model_information` section or the current CLI task-tool parameter documentation.
2. Update `$KnownModelIds` in `dispatch.ps1`.
3. Update the `$models` array in `discover.ps1`, preserving `created = $null`, `pricing = $null`, and `top_provider = 'copilot-cli'`.
4. Smoke-test a known valid model and a bogus model with `dispatch.ps1`.
5. Run `discover.ps1 -OutPath models.json` and confirm it emits a valid JSON array.
