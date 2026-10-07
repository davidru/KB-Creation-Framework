# adapters/citation-engine/ — LlamaIndex CitationQueryEngine (v3.1.14 — SCAFFOLDED, NOT YET IMPLEMENTED)

**Status:** v3.1.14 SCAFFOLD ONLY. The Python implementation lands in a follow-up session after operator approval at Gate 1.

## What this will be (v3.1.14 scope)

A new Phase 5.6 fact-check adapter that uses [LlamaIndex's CitationQueryEngine](https://docs.llamaindex.ai/en/stable/examples/query_engine/citation_query_engine/) to verify every cite-string in builder drafts against retrieved source spans.

### Architecture
- **Index**: ChromaDB-backed vector store at `sources/citation-engine-index/`, built from `external/primary-sources/cache/` content (fetched by v3.1.13 adapters or operator-staged).
- **Query**: for each cite-string + adjacent claim in `sources/builder-a-drafts/` + `sources/builder-b-drafts/`, query the CitationQueryEngine; inspect `response.source_nodes`.
- **Classification**:
  - `VERIFIED` — cite present in source, span text supports claim
  - `WRONG_TEXT` — cite present but span text contradicts or doesn't support claim
  - `NOT_FOUND` — cite-string not in any indexed source
  - `SUPPORTED_BUT_WRONG_CITE` — span text supports claim but cite-string points to a different source
- **Output**: `sources/factcheck_citation_engine.md` (per-cite verdict + evidence) + summary JSON.

### Integration
- New Phase 5.6 prompt at `prompts/56-factcheck-citation-engine.md`
- `audit-templates/phase-contracts.yaml`: new Phase 5.6 entry with rule_19_pair: [5.6, 1.3]
- `Generate-QualityScorecard.ps1`: new dimension "Citation-engine verification rate" with weight 0.10
- Cross-family discipline: embedding model + LLM evaluator declared in source-registry.yaml MUST differ from Builder A + Builder B families

## Files this directory will contain (when implemented)

- `llamaindex-citation.py` — main Python entrypoint
- `llamaindex-citation.ps1` — PowerShell wrapper
- `requirements.txt` — pinned versions of llama-index, chromadb, embed-model client
- `README.md` — this file (will be expanded)

## Why scaffolded but not implemented

Per operator-approved plan (2026-06-08): v3.1.14 implementation requires Gate 1 approval after v3.1.13 ships. This directory exists with documentation so the next session can pick up immediately without re-planning. The CHANGELOG entry [3.1.14] in the framework root documents the planned scope.

## Operator setup (when implemented)

- Python 3.12 (already in bootstrap)
- `pip install -r requirements.txt` (llama-index, chromadb, embedding-model client)
- Embedding API key (OpenAI / Voyage / Anthropic — depending on chosen embedding model)
- Index build cost: ~1 minute per 100 documents (depends on corpus size + embedding model)

## Reference

- LlamaIndex CitationQueryEngine: https://docs.llamaindex.ai/en/stable/examples/query_engine/citation_query_engine/
- ChromaDB: https://www.trychroma.com/
- Plan: `~/.copilot/session-state/2aa57d9f-4496-4e79-bc21-1eb4a51fa1c5/plan.md` § v3.1.14
