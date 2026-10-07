#!/usr/bin/env python3
"""
llamaindex-citation.py — Phase 5.6 citation-engine fact-check (KB Creation Framework v3.1.14).

Verifies cite-strings in builder drafts against retrieved source spans from
external/primary-sources/cache/. Dual-mode:

  - LLM mode (if `llama-index` + `chromadb` + embedding-model API key are
    available): builds a ChromaDB-backed VectorStoreIndex of primary sources,
    queries each draft cite+claim pair via CitationQueryEngine, classifies via
    LLM-graded semantic match against retrieved source_nodes.

  - Fallback mode (deterministic, no dependencies): scans primary-source cache
    for literal cite-string presence; classifies based on string match alone.
    Catches obvious citation hallucinations (cite-string nowhere in the
    indexed sources) but does NOT verify claim-text support.

The two modes write the same output schema; the scorecard treats fallback-mode
results with a degraded confidence flag.

USAGE
    python llamaindex-citation.py \
        --drafts-dir <path-to-sources/builder-a-drafts and -b-drafts roots> \
        --sources-dir external/primary-sources/cache \
        --kb-root <kb-root> \
        [--mode auto|llm|fallback] \
        [--llm-provider openrouter|openai|anthropic] \
        [--llm-model <model-id>] \
        [--embedding-model <model-id>]

OUTPUT
    Writes sources/factcheck_citation_engine.md (operator-readable report) and
    sources/factcheck_citation_engine.json (machine-readable).
    Stdout: single JSON envelope { status, mode, total, verified, wrong_text,
    not_found, supported_but_wrong_cite, errored, factcheck_report }.

EXIT CODES
    0 success (LLM or fallback mode completed cleanly).
    1 partial — some cites errored.
    2 no cites found in drafts (nothing to verify).
    3 no primary-source cache (nothing to verify against).
    4 LLM mode requested but llama-index not installed.
    5 LLM mode requested but no API key.
"""
from __future__ import annotations
import argparse, datetime, json, os, pathlib, re, sys, hashlib


# ============ Cite-string extraction ============
# Patterns we recognize as citations in markdown drafts.
CITE_PATTERNS = [
    # CFR: "17 CFR 240.10b-5", "17 CFR Part 240"
    r"\b(\d+)\s+CFR\s+(?:Part\s+)?(\d+(?:\.\w+(?:-\w+)?)?)",
    # USC: "15 U.S.C. § 78j(b)", "15 USC 78j", "15 U.S.C. 78j(b)"
    r"\b(\d+)\s+U\.?S\.?C\.?\s*§?\s*(\d+\w*(?:\([a-z0-9]+\))*)",
    # Public Law: "Pub. L. 117-103", "P.L. 117-103"
    r"\b(?:Pub\.?\s+L\.?|P\.L\.)\s*(?:No\.?\s*)?(\d+-\d+)",
    # Federal Register: "85 FR 12345", "85 Fed. Reg. 12345"
    r"\b(\d+)\s+(?:FR|Fed\.?\s*Reg\.?)\s+(\d+)",
    # Federal Register doc number: "2020-12345" — too generic alone; need context
    # CFR with subparts: "17 C.F.R. § 240.10b-5"
    r"\b(\d+)\s+C\.?F\.?R\.?\s*§?\s*(\d+\.\w+(?:-\w+)?)",
]


def extract_cites_from_draft(draft_text: str, source_file: str) -> list[dict]:
    """Find cite-strings + surrounding-paragraph claim text in a draft."""
    cites = []
    seen = set()
    for pattern in CITE_PATTERNS:
        for m in re.finditer(pattern, draft_text):
            cite_str = m.group(0).strip()
            # Normalize for dedup
            key = re.sub(r"\s+", " ", cite_str.lower())
            if key in seen:
                continue
            seen.add(key)
            # Surrounding paragraph as claim context (200 chars each side)
            start = max(0, m.start() - 250)
            end = min(len(draft_text), m.end() + 250)
            context = draft_text[start:end].strip()
            # Find the sentence containing the cite
            sent_start = max(start, draft_text.rfind('.', start, m.start()) + 1, draft_text.rfind('\n', start, m.start()) + 1)
            sent_end_dot = draft_text.find('.', m.end())
            sent_end_nl = draft_text.find('\n', m.end())
            sent_ends = [e for e in (sent_end_dot, sent_end_nl) if e >= 0]
            sent_end = min(sent_ends) if sent_ends else end
            sentence = draft_text[sent_start:sent_end+1].strip()
            cites.append({
                "cite_string": cite_str,
                "source_file": source_file,
                "claim_sentence": sentence,
                "context": context,
                "offset": m.start(),
            })
    return cites


# ============ Source-cache indexing ============
def load_source_cache(sources_dir: pathlib.Path) -> dict[str, dict]:
    """Walk external/primary-sources/cache/ and load all .json + .xml + .txt content.
    Returns {file_path: {content, citation, source_adapter}}."""
    result = {}
    if not sources_dir.is_dir():
        return result
    for fp in sources_dir.rglob("*"):
        if not fp.is_file(): continue
        if fp.name.endswith(".manifest.json"):
            # Use manifest to find associated content + citation
            try:
                mf = json.loads(fp.read_text(encoding="utf-8"))
                content_path = pathlib.Path(mf.get("cache_path", ""))
                if content_path.is_file():
                    body = content_path.read_text(encoding="utf-8", errors="replace")
                    result[str(content_path)] = {
                        "content": body,
                        "citation": mf.get("citation", str(content_path.name)),
                        "source_adapter": mf.get("adapter", "unknown"),
                        "source_url": mf.get("source_url", ""),
                        "sha256": mf.get("sha256", ""),
                    }
            except Exception:
                pass
    return result


# ============ Fallback-mode classification ============
def classify_cite_fallback(cite: dict, sources: dict[str, dict]) -> dict:
    """Deterministic text-search classification — no LLM.
    Searches BOTH content text AND citation metadata (the latter is critical for eCFR
    XML which only contains section text, not the full 'NN CFR XXX.YY' cite prefix)."""
    cite_str = cite["cite_string"]
    normalized = re.sub(r"[\.\u00a0\s]+", " ", cite_str).strip().lower()
    variants = {normalized}
    if "cfr" in normalized:
        no_part = normalized.replace("part ", "")
        variants.add(no_part)
        variants.add(no_part.replace("cfr ", "cfr \u00a7 "))
        # Strip the title prefix → leaves just the section, e.g. "240 10b-5"
        m = re.match(r"^(\d+)\s+cfr\s+(.+)$", no_part)
        if m:
            variants.add(m.group(2).strip())
    if "u s c" in normalized or "usc" in normalized:
        variants.add(normalized.replace("u s c", "usc"))
        variants.add(normalized.replace("usc", "u.s.c."))

    matched_sources = []
    for fp, sd in sources.items():
        # Search both content body AND citation metadata (handles eCFR XML which lacks title prefix in text)
        content_norm = re.sub(r"[\.\u00a0\s]+", " ", sd["content"]).lower()
        citation_norm = re.sub(r"[\.\u00a0\s]+", " ", sd.get("citation", "")).lower()
        haystack = content_norm + " ||CITATION|| " + citation_norm
        if any(v in haystack for v in variants):
            matched_sources.append({
                "source_file": fp,
                "citation": sd["citation"],
                "source_adapter": sd["source_adapter"],
            })
    if matched_sources:
        return {**cite, "verdict": "VERIFIED_BY_PRESENCE", "matched_sources": matched_sources,
                "verdict_note": "Cite-string literally present in indexed source content or citation metadata; claim-text support NOT verified (fallback mode)."}
    return {**cite, "verdict": "NOT_FOUND", "matched_sources": [],
            "verdict_note": "Cite-string not found in any indexed primary source."}


# ============ LLM-mode classification ============
def classify_cites_llm(cites: list[dict], sources: dict[str, dict], llm_config: dict) -> list[dict]:
    """LlamaIndex CitationQueryEngine path. Requires llama-index + chromadb + API key."""
    try:
        from llama_index.core import VectorStoreIndex, Document, StorageContext, Settings
        from llama_index.core.query_engine import CitationQueryEngine
        from llama_index.vector_stores.chroma import ChromaVectorStore
        import chromadb
    except ImportError as e:
        raise RuntimeError(f"llama-index / chromadb not installed: {e}. Run: pip install -r adapters/citation-engine/requirements.txt")

    # Build embedding model + LLM
    provider = llm_config.get("provider", "openrouter")
    api_key_env = {"openrouter": "OPENROUTER_API_KEY", "openai": "OPENAI_API_KEY", "anthropic": "ANTHROPIC_API_KEY"}[provider]
    api_key = os.environ.get(api_key_env, "").strip()
    if not api_key:
        raise RuntimeError(f"{api_key_env} env var not set; required for LLM mode with provider={provider}.")

    # OpenRouter speaks the OpenAI protocol, so we use llama-index's OpenAI client with a custom base URL.
    if provider in ("openrouter", "openai"):
        from llama_index.llms.openai import OpenAI
        from llama_index.embeddings.openai import OpenAIEmbedding
        base_url = "https://openrouter.ai/api/v1" if provider == "openrouter" else None
        llm = OpenAI(model=llm_config.get("model", "openai/gpt-4o-mini"), api_key=api_key, api_base=base_url)
        embed_model = OpenAIEmbedding(model=llm_config.get("embedding_model", "text-embedding-3-small"),
                                       api_key=api_key, api_base=base_url)
    elif provider == "anthropic":
        from llama_index.llms.anthropic import Anthropic
        # Anthropic has no embedding model; need separate embedding provider (OpenAI / Voyage / local)
        raise RuntimeError("Anthropic LLM with cross-family embedding requires explicit --embedding-model + separate OPENAI_API_KEY. Not yet auto-configured.")

    Settings.llm = llm
    Settings.embed_model = embed_model

    # Build documents
    docs = []
    for fp, sd in sources.items():
        docs.append(Document(text=sd["content"][:50000],
                             metadata={"source_file": fp, "citation": sd["citation"], "source_adapter": sd["source_adapter"]}))

    # Chroma client (in-memory; persistent would need explicit path)
    client = chromadb.EphemeralClient()
    collection = client.get_or_create_collection("kb_citation_engine")
    vector_store = ChromaVectorStore(chroma_collection=collection)
    storage_context = StorageContext.from_defaults(vector_store=vector_store)
    index = VectorStoreIndex.from_documents(docs, storage_context=storage_context)
    query_engine = CitationQueryEngine.from_args(index, similarity_top_k=3, citation_chunk_size=512)

    results = []
    for cite in cites:
        try:
            # Query: "Does the claim X find support in the source containing cite Y?"
            q = f"Verify the following claim against the source. Claim: \"{cite['claim_sentence']}\". The claim cites \"{cite['cite_string']}\". Answer: (a) is the cite found in the indexed sources? (b) does the source text support the claim?"
            response = query_engine.query(q)
            source_nodes = [{
                "text": (n.node.text or "")[:500],
                "score": getattr(n, "score", None),
                "metadata": dict(n.node.metadata) if n.node.metadata else {},
            } for n in (response.source_nodes or [])[:3]]
            # Classify based on LLM response + source_nodes
            answer_text = str(response).strip()
            # Heuristic verdict — could be refined with structured-output LLM call
            cite_str_lower = cite["cite_string"].lower()
            cite_in_any_node = any(cite_str_lower.replace(".", "").replace(" ", "") in (n["text"].lower().replace(".", "").replace(" ", "")) for n in source_nodes)
            answer_lower = answer_text.lower()
            supports = any(k in answer_lower for k in ["supports the claim", "supports", "consistent with", "is found in", "yes,"])
            contradicts = any(k in answer_lower for k in ["does not support", "contradicts", "not found", "no,"])
            if cite_in_any_node and supports and not contradicts:
                verdict = "VERIFIED"
            elif cite_in_any_node and contradicts:
                verdict = "WRONG_TEXT"
            elif not cite_in_any_node and supports:
                verdict = "SUPPORTED_BUT_WRONG_CITE"
            else:
                verdict = "NOT_FOUND"
            results.append({**cite, "verdict": verdict, "llm_response": answer_text[:600],
                            "source_nodes": source_nodes, "verdict_note": "LLM-classified via CitationQueryEngine."})
        except Exception as e:
            results.append({**cite, "verdict": "ERRORED", "error": str(e), "verdict_note": f"LLM query failed: {e}"})
    return results


# ============ Output writing ============
def write_report(results: list[dict], counts: dict, kb_root: pathlib.Path, mode: str) -> tuple[str, str]:
    sources_dir = kb_root / "sources"
    sources_dir.mkdir(parents=True, exist_ok=True)
    md_path = sources_dir / "factcheck_citation_engine.md"
    json_path = sources_dir / "factcheck_citation_engine.json"

    lines = [
        "# Phase 5.6 — Citation-Engine Fact-Check",
        f"Generated: {datetime.datetime.now(datetime.timezone.utc).isoformat()}",
        f"Mode: **{mode}**",
        f"Total cites checked: {counts['total']}",
        "",
        "## Summary",
        f"- VERIFIED: {counts.get('VERIFIED', 0)}",
        f"- VERIFIED_BY_PRESENCE (fallback only): {counts.get('VERIFIED_BY_PRESENCE', 0)}",
        f"- WRONG_TEXT: {counts.get('WRONG_TEXT', 0)}",
        f"- SUPPORTED_BUT_WRONG_CITE: {counts.get('SUPPORTED_BUT_WRONG_CITE', 0)}",
        f"- NOT_FOUND: {counts.get('NOT_FOUND', 0)}",
        f"- ERRORED: {counts.get('ERRORED', 0)}",
        "",
    ]
    if mode == "fallback":
        lines += [
            "> **Fallback mode caveat**: classifications are based on literal cite-string presence in indexed sources only. ",
            "> Claim-text support is NOT verified. To enable LLM-mode semantic verification, install ",
            "> `pip install -r adapters/citation-engine/requirements.txt` and set OPENROUTER_API_KEY (or similar).",
            "",
        ]
    lines += [
        "## Per-cite verdicts",
        "",
        "| Source file | Cite | Verdict | Note |",
        "|---|---|---|---|",
    ]
    for r in results:
        src = pathlib.Path(r.get("source_file", "?")).name
        cite = r.get("cite_string", "?").replace("|", "\\|")
        verdict = r.get("verdict", "?")
        note = r.get("verdict_note", "").replace("|", "\\|").replace("\n", " ")[:120]
        lines.append(f"| `{src}` | `{cite}` | **{verdict}** | {note} |")
    # Detailed evidence per cite (limit to first 30 to keep file readable)
    lines += ["", "## Detailed evidence (first 30 cites)", ""]
    for r in results[:30]:
        lines.append(f"### `{r.get('cite_string', '?')}` ({r.get('verdict', '?')})")
        lines.append(f"- Source: `{r.get('source_file', '?')}`")
        lines.append(f"- Claim sentence: {r.get('claim_sentence', '')[:300]}")
        if r.get("matched_sources"):
            lines.append("- Matched sources:")
            for ms in r["matched_sources"][:3]:
                lines.append(f"  - `{ms.get('source_file', '?')}` — {ms.get('citation', '?')}")
        if r.get("source_nodes"):
            lines.append("- LLM-retrieved source spans:")
            for n in r["source_nodes"][:3]:
                lines.append(f"  - score {n.get('score'):.3f}: {n.get('text', '')[:200]}")
        if r.get("llm_response"):
            lines.append(f"- LLM response: {r['llm_response']}")
        if r.get("error"):
            lines.append(f"- ERROR: {r['error']}")
        lines.append("")

    md_path.write_text("\n".join(lines), encoding="utf-8")
    json_path.write_text(json.dumps({"mode": mode, "counts": counts, "results": results}, indent=2), encoding="utf-8")
    return str(md_path), str(json_path)


# ============ Main ============
def main() -> None:
    ap = argparse.ArgumentParser(description="LlamaIndex CitationQueryEngine fact-check (v3.1.14)")
    ap.add_argument("--drafts-dir", required=True, help="Directory containing builder draft .md files (recursive)")
    ap.add_argument("--sources-dir", required=True, help="Primary-source cache directory (e.g. external/primary-sources/cache)")
    ap.add_argument("--kb-root", required=True, help="KB root (for writing factcheck_citation_engine.md)")
    ap.add_argument("--mode", choices=["auto", "llm", "fallback"], default="auto",
                    help="auto: try llm, fall back to fallback if deps missing. llm: require llama-index. fallback: deterministic text search.")
    ap.add_argument("--llm-provider", choices=["openrouter", "openai", "anthropic"], default="openrouter")
    ap.add_argument("--llm-model", default="openai/gpt-4o-mini")
    ap.add_argument("--embedding-model", default="text-embedding-3-small")
    args = ap.parse_args()

    drafts_dir = pathlib.Path(args.drafts_dir)
    sources_dir = pathlib.Path(args.sources_dir)
    kb_root = pathlib.Path(args.kb_root)

    if not drafts_dir.is_dir():
        print(json.dumps({"status": "error", "error_type": "drafts_dir_missing",
                          "error_message": f"Drafts directory not found: {drafts_dir}"})); sys.exit(2)
    if not sources_dir.is_dir():
        print(json.dumps({"status": "error", "error_type": "sources_dir_missing",
                          "error_message": f"Sources directory not found: {sources_dir}",
                          "remediation": "Run Phase 1.1 with sources/source-registry.yaml configured (v3.1.13) to populate external/primary-sources/cache/."}))
        sys.exit(3)

    # Extract cites from all drafts — exclude factcheck output files to avoid self-referential loops
    all_cites = []
    for draft_file in drafts_dir.rglob("*.md"):
        if draft_file.name.startswith("factcheck_") or "factcheck" in draft_file.parent.name:
            continue
        try:
            text = draft_file.read_text(encoding="utf-8", errors="replace")
            all_cites.extend(extract_cites_from_draft(text, str(draft_file)))
        except Exception:
            pass

    if not all_cites:
        print(json.dumps({"status": "ok", "mode": "n/a", "total": 0,
                          "message": "No cite-strings found in drafts; nothing to verify."}))
        sys.exit(2)

    # Load primary-source cache
    sources = load_source_cache(sources_dir)
    if not sources:
        print(json.dumps({"status": "error", "error_type": "no_indexed_sources",
                          "error_message": f"No manifest+content found in {sources_dir}",
                          "remediation": "Run v3.1.13 adapters to populate the cache, or stage source files manually."}))
        sys.exit(3)

    # Choose mode
    mode = args.mode
    if mode == "auto":
        try:
            import llama_index.core  # noqa: F401
            import chromadb  # noqa: F401
            # Check API key
            api_key = os.environ.get({"openrouter": "OPENROUTER_API_KEY", "openai": "OPENAI_API_KEY", "anthropic": "ANTHROPIC_API_KEY"}[args.llm_provider], "").strip()
            mode = "llm" if api_key else "fallback"
        except ImportError:
            mode = "fallback"

    # Classify
    if mode == "llm":
        try:
            results = classify_cites_llm(all_cites, sources, {
                "provider": args.llm_provider, "model": args.llm_model, "embedding_model": args.embedding_model
            })
        except RuntimeError as e:
            print(json.dumps({"status": "error", "error_type": "llm_unavailable",
                              "error_message": str(e),
                              "remediation": "Either set --mode fallback or install llama-index + set API key."}))
            sys.exit(4)
    else:
        results = [classify_cite_fallback(c, sources) for c in all_cites]

    counts = {"total": len(results)}
    for r in results:
        counts[r["verdict"]] = counts.get(r["verdict"], 0) + 1

    md_path, json_path = write_report(results, counts, kb_root, mode)
    print(json.dumps({"status": "ok", "mode": mode, "total": len(results), "counts": counts,
                      "factcheck_report_md": md_path, "factcheck_report_json": json_path}, indent=2))
    sys.exit(0 if counts.get("ERRORED", 0) == 0 else 1)


if __name__ == "__main__":
    main()
