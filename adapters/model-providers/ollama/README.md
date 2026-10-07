# Ollama model-provider adapter

**Purpose:** Provides a local Ollama provider adapter for the KB Creation Framework v3.1 Model Registry. It dispatches prompts to models already pulled into the operator's local Ollama runtime and discovers those local models for registry population.

## Environment variables

| Variable | Default | Required | Notes |
|---|---:|---:|---|
| `OLLAMA_ENDPOINT` | `http://localhost:11434` | No | Base URL for the local Ollama server. |

No API key is required; Ollama is local and unauthenticated by default.

## Prerequisites

1. Install Ollama locally from https://ollama.com.
2. Start the local runtime (`ollama serve`, or the desktop app/service).
3. Pull each model before use:

```powershell
ollama pull llama3.1:70b
ollama pull qwen2.5:32b
```

## Strengths

- Free local inference with no per-token pricing.
- No network dependency after the model is pulled.
- Prompt and source data never leave the operator's machine.
- Useful for privacy-preserving critic / rubber-duck passes and offline smoke tests.

## Known limitations

- Discovery only returns models the operator has already pulled.
- Output quality varies widely by model, quantization, and local hardware.
- Long-context use requires enough system RAM / VRAM for the selected model and quantization.
- Local models may lack tool-use reliability or reasoning depth needed for lead / builder roles.

## Recommended framework role fit

| Role | Recommended local models | Notes |
|---|---|---|
| Builders | `llama3.1:70b` / `llama3.3:70b` if hardware permits; `qwen2.5:32b` as a smaller alternative | Use only when local hardware can sustain the required context and output length. |
| Fact-check / auditor | Large Llama, Qwen, Mistral, or DeepSeek models with adequate context | Validate quality against hosted-family outputs before relying on them. |
| Critic pool | Smaller local models can be useful for cheap challenge passes | Use smaller models only with an explicit Rule 19 / quality opt-out when they cannot meet the role's capability tier. |

## Scripts

```powershell
pwsh .\discover.ps1 -OutPath .\ollama-models.json
pwsh .\dispatch.ps1 -ModelId llama3.1:70b -PromptPath .\prompt.txt -OutPath .\response.json -MaxTokens 4096 -Temperature 1.0
```

`discover.ps1` writes an empty JSON array and exits successfully if Ollama is not running, so setup scripts can continue gracefully. `dispatch.ps1` exits non-zero with an actionable error if the endpoint is unreachable or the requested model is not pulled.
