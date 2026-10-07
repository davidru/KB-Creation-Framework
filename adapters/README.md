# Adapters

Adapters are **optional, swappable components** that augment a framework phase with capability the base prompts don't have. They are additive — every prompt in this framework runs correctly without any adapter installed. Adapters add a new input the prompt knows how to use *if it's present*.

## Why adapters live in the framework

- **Discoverability** — anyone reading the framework sees what optional capabilities exist.
- **Versioning** — adapter scripts evolve with the prompts that consume them.
- **Independence** — an adapter is self-contained (its own dir, deps, README, scripts). Removing one is `rm -r adapters/<name>`.

## Adapter contract

Every adapter must:

1. Live in its own subdirectory under `adapters/`.
2. Provide a `README.md` that documents (a) which framework phase it augments, (b) what input it produces, (c) what evidence supports the recommendation to use it, (d) known limits.
3. Be **fully optional** — the prompt files MUST treat the adapter's output as an optional input. No prompt may hard-fail if the adapter wasn't run.
4. Pin its own dependencies (`requirements.txt` or equivalent).
5. Write its outputs to a deterministic path the consuming prompt can reference.

## Current adapters

| Adapter | Augments | Output | Status |
|---------|----------|--------|--------|
| `crawl4ai-fetch/` | Phase 5b (citation fact-check), Phase 5c (classification), Phase 5d (single-source claims), Phase 6b (post-assembly SUPERSET) | Per-cite fetched markdown of primary sources + a fetch manifest | **Recommended for cite-dense KBs** (legal, regulatory, standards). Pilot evidence: `../pilots/crawl4ai-2026-05/report/decision.md` |
