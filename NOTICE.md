# Notices

## Scope of the root LICENSE

The MIT `LICENSE` at this directory's root (Copyright (c) Microsoft Corporation.) covers the
original works in this framework: rulebooks (`01-shared-axioms.md` through `07-audit-system.md`),
prompts (`prompts/`), PowerShell scripts, audit templates (`audit-templates/`), host notes
(`hosts/`), the technical specification and LLM recreation prompt (`specification/`), the
HOW-TO-USE operator guide, the CHANGELOG, and the original adapter glue code:

- `adapters/crawl4ai-fetch/` — `extract_cites.py`, `fetch.py`, `fetch_cf_fallback.py`,
  `fetch_pdf_fallback.py`, `fetch_scrapling_fallback.py`, `build_packets.py`
  (see `adapters/crawl4ai-fetch/NOTICE-glue-code.md`)
- `adapters/primary-source/`, `adapters/citation-engine/`, `adapters/evaluator/`
- `adapters/model-providers/*` (each also carries a scoped `LICENSE.txt`)

## Third-party software

No third-party source code is vendored in this tree. Third-party packages are installed by the
operator from `requirements.txt` files and keep their own licenses.

| Adapter | Package | License | Copyright | Notice location |
|---|---|---|---|---|
| crawl4ai-fetch | crawl4ai | Apache-2.0 + Attribution Requirement | UncleCode and Crawl4AI contributors | `adapters/crawl4ai-fetch/LICENSE`, `THIRD_PARTY_NOTICES.md`, `README.md` |
| crawl4ai-fetch | playwright, patchright, httpx, pypdf, scrapling | Apache-2.0 / BSD-3-Clause | see table | `adapters/crawl4ai-fetch/THIRD_PARTY_NOTICES.md` |
| citation-engine | llama-index-* | MIT | Jerry Liu | upstream (not redistributed here) |
| citation-engine | chromadb | Apache-2.0 | Chroma | upstream (not redistributed here) |
| evaluator | inspect-ai | MIT | UK AI Security Institute | upstream (not redistributed here) |

The last three rows are installed on demand and are not redistributed in this tree, so no
license text ships for them; they are listed here for completeness.
