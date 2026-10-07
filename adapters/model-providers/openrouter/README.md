# OpenRouter model-provider adapter

## Purpose

This adapter lets KB Creation Framework v3.1 dispatch model-provider calls through OpenRouter while keeping the framework's Model Registry abstraction provider-neutral. It implements the provider-side `dispatch.ps1` and `discover.ps1` contract consumed by `Resolve-Model.ps1`, `Refresh-Registry.ps1`, and the Phase 0.0 model-selection flow.

## Required environment variables

| Variable | Required for | Purpose |
|---|---|---|
| `OPENROUTER_API_KEY` | `dispatch.ps1` | Bearer token for `POST https://openrouter.ai/api/v1/chat/completions`. |

`discover.ps1` does not require authentication because OpenRouter's model-listing endpoint is public.

## Strengths

- Cross-provider access to ~300+ models from Anthropic, OpenAI, Google, DeepSeek, Mistral, Meta, Qwen, and other providers through one OpenAI-compatible API.
- Competitive pricing is visible during discovery; `discover.ps1` normalizes OpenRouter's per-token USD prices to per-million-token prices.
- `dispatch.ps1` uses an OpenAI-compatible chat-completions body, so prompts can be sent without provider-specific SDKs.

## Known limitations

- Rate limits vary by OpenRouter account tier and by the routed upstream provider.
- Some models are available only with specific provider-routing settings or provider availability conditions; this thin adapter does not force provider routing.
- Pricing is reported in USD per token by OpenRouter and normalized by discovery to USD per million tokens; actual billing can vary if OpenRouter changes pricing or routing.

## Category filter caveats

OpenRouter supports `GET /api/v1/models?category=<name>` for categories such as `legal`, `programming`, and `finance`. The per-model JSON does not include a `category` field, so the category signal exists only on the listing request that returned the model.

OpenRouter's `legal` classification appears to favor cost-efficient long-context models per OpenRouter customer-routing patterns, not necessarily quality benchmarks. Combine this signal with benchmark-based domain signals in `audit-templates/domain-capabilities.yaml` before recommending legal models.

## Basic usage

```powershell
pwsh .\discover.ps1 -OutPath .\openrouter-models.json
pwsh .\discover.ps1 -Category legal -OutPath .\openrouter-legal-models.json
pwsh .\dispatch.ps1 -ModelId "anthropic/claude-3.5-sonnet" -PromptPath .\prompt.md -OutPath .\completion.json
```
