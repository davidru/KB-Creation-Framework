# Azure Foundry model-provider adapter

## Purpose

This adapter lets the KB Creation Framework v3.1 dispatch prompts to Azure AI Foundry / Azure OpenAI chat-completions deployments through the Model Registry provider abstraction.

In `model-registry.yaml`, the Azure Foundry `model_id` is the **deployment name** configured in the Azure resource, not necessarily the underlying base model name.

## Required environment variables

Dispatch requires:

| Variable | Purpose |
|---|---|
| `env:AZURE_FOUNDRY_ENDPOINT` | Resource endpoint, for example `https://<resource>.openai.azure.com` |
| `env:AZURE_FOUNDRY_API_KEY` | API key for the Azure Foundry / Azure OpenAI resource |

Optional:

| Variable | Purpose | Default |
|---|---|---|
| `env:AZURE_FOUNDRY_API_VERSION` | Azure OpenAI API version used by both scripts | `2024-10-21` |
| `env:AZURE_RESOURCE_NAME` | Azure resource name used by `discover.ps1` when calling `az cognitiveservices account deployment list` | none |
| `env:AZURE_RESOURCE_GROUP` | Resource group used by `discover.ps1` with `env:AZURE_RESOURCE_NAME` | none |

## Prerequisites

1. An Azure subscription with an Azure AI Foundry / Azure OpenAI resource.
2. Chat-completions deployments configured in that resource. The deployment names are the values to use as registry `model_id` entries.
3. PowerShell 7+.
4. Optional: Azure CLI (`az`) authenticated to the subscription. `discover.ps1` prefers Azure CLI when `env:AZURE_RESOURCE_NAME` and `env:AZURE_RESOURCE_GROUP` are set; otherwise it falls back to the resource REST endpoint.

## Setting up deployments

Create deployments in Azure AI Foundry or Azure OpenAI Studio, then copy each deployment name into the Model Registry as the Azure Foundry `model_id`. See Microsoft Learn for current setup guidance: <https://learn.microsoft.com/azure/ai-foundry/> and <https://learn.microsoft.com/azure/ai-services/openai/how-to/create-resource>.

Example registry entry:

```yaml
- handle: azure-gpt4o-production
  family: openai
  provider: azure-foundry
  model_id: gpt-4o-prod
  endpoint: env:AZURE_FOUNDRY_ENDPOINT
  api_key: env:AZURE_FOUNDRY_API_KEY
  capabilities: [text, tools, vision, enterprise-control]
```

## Scripts

- `dispatch.ps1` posts a prompt file as a single user message to `.../openai/deployments/<deployment>/chat/completions` and writes the normalized completion JSON requested by the framework.
- `discover.ps1` lists deployments configured in the current resource. Preferred path: Azure CLI deployment list. Fallback path: `GET .../openai/models` using the configured endpoint and API key.

## Known limitations

- Discovery returns models/deployments visible from the configured resource. It is **not** a full Azure model catalog.
- Pricing is returned as `null`; Azure deployment pricing is operator-configured and not exposed by these APIs.
- Metadata differs by discovery path. Azure CLI usually returns richer deployment metadata than the REST fallback.
- `dispatch.ps1` targets chat completions only. Embedding or image deployments may be discoverable but are not dispatchable by this adapter.
