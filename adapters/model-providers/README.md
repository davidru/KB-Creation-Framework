# Model Provider Adapter Contract

This directory contains one subdirectory per provider adapter. Each adapter wraps a single model provider (Copilot CLI, Azure AI Foundry, OpenRouter, Ollama, etc.) and exposes a stable contract that the framework's `Resolve-Model.ps1` and `Recommend-Models.ps1` scripts consume.

Operators who want to add a new provider implement this contract in a new subdirectory.

---

## Required files per adapter

| File | Purpose | Required? |
|---|---|---|
| `README.md` | Operator-facing documentation (env vars, prerequisites, limitations) | MUST |
| `dispatch.ps1` | Sub-agent dispatch primitive — sends a prompt to the provider, returns completion | MUST |
| `discover.ps1` | Model catalog enumeration — returns available models with metadata | MUST |
| `LICENSE.txt` | License covering the original glue code in this directory | MUST |
| `requirements.txt` | Python deps (if Python-based) | OPTIONAL |
| `NOTICES.md` | Third-party OSS attribution if the adapter pulls in OSS deps | OPTIONAL |

---

## `dispatch.ps1` contract

### Inputs (parameters)

| Parameter | Type | Required? | Purpose |
|---|---|---|---|
| `-ModelId` | string | Mandatory | The provider-specific model identifier (e.g., `claude-opus-4.7` for copilot-cli; `anthropic/claude-3.5-sonnet` for openrouter; deployment name for azure-foundry) |
| `-PromptPath` | string | Mandatory | Absolute path to a file containing the prompt body for the sub-agent |
| `-OutPath` | string | Mandatory | Absolute path where the JSON response envelope is written |
| `-MaxTokens` | int | Optional | Max tokens in completion. Default: 4096 |
| `-Temperature` | double | Optional | Sampling temperature. Default: 1.0 |
| `-MaxRetries` | int | Optional | Retry attempts for 429/transient errors. Default: 3 |

### Outputs (JSON envelope written to `-OutPath`)

On success (exit code 0):

```json
{
  "status": "success",
  "adapter": "<provider-name>",
  "model_id": "<resolved model id>",
  "completion": "<text from the model>",
  "usage": {
    "prompt_tokens": <int>,
    "completion_tokens": <int>,
    "total_tokens": <int>
  },
  "cost_estimate": <float|null>,
  "top_provider": "<actual provider that served the request>"
}
```

On host-mediated dispatch (e.g., copilot-cli — the host performs the actual model call):

```json
{
  "status": "ready",
  "adapter": "copilot-cli",
  "model_id": "<validated model id>",
  "host_invocation": {
    "tool": "task",
    "parameters": { "model": "<model id>", "prompt": "<prompt body>", "mode": "background" }
  }
}
```

On failure (exit code 1):

```json
{
  "status": "error",
  "adapter": "<provider-name>",
  "error_type": "auth|network|model_not_found|invalid_request|rate_limit|other",
  "error_message": "<human-readable message>",
  "remediation": "<what the operator should do>"
}
```

### Error semantics

- Exit code 0: success or `status: ready` (host-mediated).
- Exit code 1: error. The JSON envelope at `-OutPath` MUST include `error_type` and `remediation`.
- Adapters MUST retry transient errors (429, 503) with exponential backoff up to `-MaxRetries` attempts before exiting 1.
- Adapters MUST NOT silently fall back to a different model or provider — exit 1 with `model_not_found` if the requested `ModelId` is unavailable.

---

## `discover.ps1` contract

### Inputs (parameters)

| Parameter | Type | Required? | Purpose |
|---|---|---|---|
| `-OutPath` | string | Mandatory | Absolute path where the JSON array of model metadata is written |
| `-Category` | string | Optional | Provider-specific category filter (e.g., OpenRouter's `legal`/`programming`/`finance`). Adapter MAY ignore if not supported |
| `-Refresh` | switch | Optional | Bypass any cache and re-query the provider |

### Outputs (JSON array written to `-OutPath`)

```json
[
  {
    "model_id": "<provider-specific model id>",
    "family_hint": "anthropic|openai|google|meta-llama|mistral|deepseek|internal-microsoft|other|null",
    "context_window": <int|null>,
    "capabilities": ["text", "tools", "response_format", ...],
    "pricing": {
      "prompt_per_million": <float|null>,
      "completion_per_million": <float|null>
    },
    "top_provider": "<provider name>",
    "notes": "<short description, max 200 chars>"
  },
  ...
]
```

### Error semantics

- Exit code 0: success. If the provider is unreachable (e.g., Ollama not running locally), discover MUST gracefully emit `[]` rather than crash.
- Exit code 1: hard error (missing required env var, bad API key when key required, malformed response).
- `family_hint` is best-effort — `Infer-Family.ps1` applies its pattern matching against the returned `model_id` if `family_hint` is `null`.
- `pricing` fields are `null` when the provider doesn't expose per-token pricing (e.g., copilot-cli is usage-based; ollama is local/free).

---

## Discovery vs. dispatch separation

`discover.ps1` is consulted at registry-population time (Phase 0.0 discovery sub-flow, or by `Refresh-Registry.ps1`) to enumerate what's available. `dispatch.ps1` is consulted at every sub-agent call to actually invoke a model. They are independent — `discover.ps1` can require no auth (OpenRouter listing endpoint), while `dispatch.ps1` typically needs full credentials.

---

## Adding a new provider adapter

1. Create `adapters/model-providers/<provider-name>/` (lowercase, hyphenated).
2. Implement `dispatch.ps1` and `discover.ps1` per the contracts above.
3. Add `README.md` documenting env vars, prerequisites, known limitations.
4. Add `LICENSE.txt` (MIT recommended; cover original glue code only).
5. If pulling in OSS deps, add `NOTICES.md` per `adapters/crawl4ai-fetch/THIRD_PARTY_NOTICES.md` pattern.
6. Add the provider name to the `provider:` enum in `audit-templates/model-registry.schema.json`.
7. Run `Test-Setup.ps1` to confirm the adapter is discoverable.
8. Run `Validate-ModelRegistry.ps1 -RegistryPath model-registry.example.yaml` after adding example entries that reference your new provider.

---

## Current adapters

| Adapter | Provider | Auth required | Pricing exposed | Notes |
|---|---|---|---|---|
| `copilot-cli/` | GitHub Copilot CLI (host-mediated) | No (uses host's auth) | No (usage-based) | Returns hardcoded list of ~15 known model IDs; dispatch returns envelope for host to execute |
| `azure-foundry/` | Azure AI Foundry | `AZURE_FOUNDRY_ENDPOINT` + `AZURE_FOUNDRY_API_KEY` | Operator-configured per deployment | Discovery returns operator's configured deployments, not full Azure catalog |
| `openrouter/` | OpenRouter | `OPENROUTER_API_KEY` for dispatch (no auth for discovery) | Yes, per-token USD | Supports `?category=<name>` filter (legal/programming/finance verified) |
| `ollama/` | Ollama (local) | None | No (free, local) | Returns locally-pulled models via `/api/tags`; gracefully returns `[]` if Ollama not running |
