# Phase 5.6 — Citation-Engine Fact-Check (v3.1.14+)

**Role:** Fact-checker (Phase 5.6 verifier). Per Rule 19, dispatched to a model family DIFFERENT from Builder A + Builder B (Phase 1.3).
**Input:** `sources/builder-a-drafts/`, `sources/builder-b-drafts/`, `external/primary-sources/cache/`.
**Output:** `sources/factcheck_citation_engine.md` + `sources/factcheck_citation_engine.json`.
**Tooling:** Invokes `adapters/citation-engine/llamaindex-citation.ps1` (Python sidecar).

## Operator-visible context

Phase 5.6 verifies every cite-string in builder drafts against the primary-source corpus retrieved by v3.1.13 adapters (or operator-staged). Two modes:

- **LLM mode** (when `llama-index` + `chromadb` are installed and an API key is set): builds a ChromaDB-backed VectorStoreIndex, queries each (cite, claim) pair via LlamaIndex's CitationQueryEngine, classifies based on retrieved source spans + LLM judgment. Verdict: `VERIFIED` | `WRONG_TEXT` | `NOT_FOUND` | `SUPPORTED_BUT_WRONG_CITE` | `ERRORED`.

- **Fallback mode** (no pip-install, no API key, no cost): deterministic text-search across all indexed primary-source content + manifest citation metadata. Verdict: `VERIFIED_BY_PRESENCE` | `NOT_FOUND`. Catches obvious citation hallucinations (cite-string nowhere in indexed sources) but does NOT verify claim-text support.

The adapter chooses mode automatically (`--mode auto`); operator can force `--mode llm` or `--mode fallback`.

## Mandatory dispatch instructions

```pwsh
# From KB root:
pwsh "<framework-root>\adapters\citation-engine\llamaindex-citation.ps1" `
    -DraftsDir ".\sources" `
    -SourcesDir ".\external\primary-sources\cache" `
    -KBRoot "." `
    -Mode auto `
    -LlmProvider openrouter `
    -LlmModel "anthropic/claude-opus-4.8" `
    -EmbeddingModel "openai/text-embedding-3-large"
```

- `LlmModel` MUST be from a family different from Builder A and Builder B per Rule 19 (Model-Family Separation). Validate against `sources/pipeline_state.yaml` Phase 1.3 entries.
- If the adapter exits 4 (`llm_unavailable`), the orchestrator MAY proceed with the fallback report but MUST log a Rule 19 degradation finding (the fallback mode does NOT use a model at all, so it cannot violate Rule 19 — but it provides weaker verification).

## Output handling

- Read `sources/factcheck_citation_engine.json` to get per-cite verdicts.
- Aggregate `counts.{VERIFIED, VERIFIED_BY_PRESENCE, WRONG_TEXT, SUPPORTED_BUT_WRONG_CITE, NOT_FOUND, ERRORED}`.
- Append a Phase 5.6 entry to `sources/pipeline_state.yaml` per Rule 20 (actuals: which LLM ran; what mode was used).
- Per Rule 20 deliverable provenance, include a "Model provenance" section in `factcheck_citation_engine.md` — the adapter already prefixes its output with the mode + LLM model used.

## Quality Scorecard integration

Generate-QualityScorecard.ps1 v3.1.14+ reads `sources/factcheck_citation_engine.json` and adds dimension "Citation-engine verification rate" with weight 0.10:

- Numerator: `VERIFIED + (0.7 * VERIFIED_BY_PRESENCE)` — fallback verifications count at 70% weight since they don't verify claim-text support
- Denominator: `total - ERRORED`
- Score: `(numerator / denominator) * 100`
- Threshold: ≥80 to PASS the dimension

Other dimensions are re-weighted to sum to 1.00 (citation weight comes proportionally from Stress-test which drops from 0.25 to 0.20, and from Citation-density which drops from 0.20 to 0.15).

## Stop conditions

Stop and surface to operator (do NOT auto-proceed to Phase 6.0 Lead Assembly) when:

- `NOT_FOUND` rate > 10% — drafts contain a meaningful fraction of cites not in the indexed primary-source corpus. Either the operator's source-registry.yaml is incomplete (missing relevant primary sources), the builders hallucinated cites, or both.
- `WRONG_TEXT` rate > 0% — the cited source exists but the builder claim contradicts the source text. Always surface; never auto-proceed.
- `SUPPORTED_BUT_WRONG_CITE` rate > 0% — same.
- `ERRORED` rate > 5% — adapter is failing intermittently; investigate before continuing.

When stopping, present the operator with three choices (per DISPATCH-FAILURE CONTRACT pattern in 01-orchestrator.md):
1. Investigate-and-fix (review the cited findings, correct the drafts, re-run Phase 5.6)
2. Acknowledged degradation (operator accepts the failure rate; logged in pipeline_state.yaml as Phase 5.6 dispatch_status: failed-then-acknowledged-opt-out)
3. Abort the build

## Why this phase exists

Empirical observation from WA-Law-Firm-KB v2 (2026-06-08 build): 62.5% silent-fallback rate meant the existing fact-check phases verified content using same-family models. Even with v3.1.10 fingerprint enforcement closing that gap, the existing fact-checks (Phase 5.1 currency, 5.2 citation, 5.3 classification, 5.4 single-source, 5.5 operative-claim) rely on the LLM's self-reported confidence about cite-strings. Phase 5.6 grounds this in the actual primary-source content — every cite is verified against text the operator has authoritatively staged (or auto-fetched via v3.1.13 adapters).
