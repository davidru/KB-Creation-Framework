# crawl4ai-fetch — Grounding Adapter for Phase 5b / 5d / 6b

**Purpose:** Replace the fact-checker's "model recall + ad-hoc web search" with **fetched primary-source markdown** for every cite in a KB. The fact-check prompt then reads the actual cited page rather than guessing from training data or relying on the URL "looking authoritative."

**Augments:** `prompts/09-factcheck-citations.md` (5b), `prompts/09a-factcheck-single-source.md` (5d), `prompts/13-post-assembly-factcheck.md` (6b).

**Status:** Recommended for cite-dense KBs (legal, regulatory, standards). Optional. Framework runs unchanged if you skip it.

---

## Attribution (required by upstream Crawl4AI license)

This adapter uses **Crawl4AI** (https://github.com/unclecode/crawl4ai), authored and maintained by **UncleCode** (https://x.com/unclecode) and the Crawl4AI project contributors. Crawl4AI is distributed under the Apache License 2.0 with an additional Attribution Requirement. Per that requirement, the following acknowledgment is reproduced verbatim in this README:

> "This product includes software developed by UncleCode (https://x.com/unclecode) as part of the Crawl4AI project (https://github.com/unclecode/crawl4ai)."

The full upstream Crawl4AI LICENSE — including the Apache-2.0 base text and the verbatim Attribution Requirement section — lives at `./LICENSE` in this directory (reproduced byte-faithful from upstream; provenance recorded in `./NOTICE-glue-code.md` § 1). Crawl4AI is **not a Microsoft work**; the only Microsoft-authored content in this directory is the Python glue code described in `./NOTICE-glue-code.md` § 2.

Attribution for the five other direct OSS dependencies — Playwright, patchright, httpx, pypdf, and Scrapling — is in `THIRD_PARTY_NOTICES.md`. Anyone redistributing this adapter MUST continue to display the Crawl4AI attribution above in a prominent location (NOTICE file, README, About/Credits page, or CLI help output), per the upstream LICENSE.

---

## Why this exists (evidence)

Pilot run on the SEPs KB (May 2026), 57-cite single-model A/B, controlled for prompt frame and model:

| | Count |
|---|---|
| Verdict agreement (baseline vs. grounded) | 33 / 57 = 57.9% |
| Disagreements where grounded was more skeptical | 21 / 24 (87.5%) |
| Baseline `SUPPORTED/HIGH` → grounded `UNSUPPORTED/HIGH` | 9 |
| Knowledge-cutoff catches resolved by grounding | 3 (incl. live 2025 EWCA judgment) |
| Drift types caught by grounding (`overstated`, `mischaracterized`, `wrong_document`, `no_longer_at_url`, `stale`, etc.) | 21 |
| Drift types caught by baseline | 2 |

Spot-verified 8 disagreements; ~18–19 of the 21 grounded calls were legitimate KB defects (live 404 URL the baseline blessed because the domain "looked authoritative"; PA Consulting URL cited for ArcPrime stats — wrong document; KB called Jorge Contreras a "Distinguished University Professor" when his bio says "Distinguished Researcher Award" — title vs. award).

Full pilot report: `../../../pilots/crawl4ai-2026-05/report/decision.md` (relative to this file).

---

## What it produces

| Artifact | Path | Consumed by |
|---|---|---|
| Cite inventory | `<state-root>/grounding/cites.json` | sampler / fetcher |
| Fetched primary-source markdown | `<state-root>/grounding/sources/<sha1>.md` | fact-check prompts |
| Fetch manifest | `<state-root>/grounding/fetch_log.json` | fact-check prompts (tells them which cites have grounding available) |
| Per-file packets (optional) | `<state-root>/grounding/packets/<file>.md` | sub-agent fact-checkers, if you parallelize 5b across files |

The fact-check prompt's `OPTIONAL GROUNDING` block explains how to consume these.

---

## Pipeline (6 steps)

### 1. Extract cites from the KB or v2 drafts

```powershell
python adapters\crawl4ai-fetch\extract_cites.py `
  --kb "<path-to-KB-or-drafts-dir>" `
  --out "<state-root>\grounding\cites.json"
```

Reads every `.md` under `--kb`, extracts markdown-link cites and bare URLs, writes a JSON inventory with surrounding context (3 lines before, 2 after) and per-domain summary.

### 2. Fetch with Crawl4AI (Playwright + readability)

```powershell
python adapters\crawl4ai-fetch\fetch.py `
  --cites "<state-root>\grounding\cites.json" `
  --out-dir "<state-root>\grounding"
```

Concurrency 5, 60s per-URL timeout, single retry. Writes `<sha1>.md` per unique URL into `grounding/sources/` and `fetch_log.json` at the out-dir root. Renders JS-heavy pages via Chromium and emits readability-trimmed markdown (`fit_markdown` preferred).

### 3. PDF fallback (recovers ~80% of Crawl4AI failures)

```powershell
python adapters\crawl4ai-fetch\fetch_pdf_fallback.py `
  --out-dir "<state-root>\grounding"
```

Crawl4AI cannot render direct-PDF URLs (no HTML). The fallback uses `httpx` (UA spoof) + `pypdf` to recover DOJ business-review letters, FTC case PDFs, Congressional witness materials, etc. Updates `fetch_log.json` in place.

**Empirical coverage from the SEPs pilot:** Crawl4AI alone = 75%. With PDF fallback = **95%**. The remaining ~5% (EU Lex CELEX, W3C anti-bot, JSTOR paywall) is a permanent gap class — flag those for manual verification.

### 4. Cloudflare interactive-challenge fallback (patchright)

```powershell
python adapters\crawl4ai-fetch\fetch_cf_fallback.py `
  --out-dir "<state-root>\grounding"
```

Uses [`patchright`](https://github.com/Kaliiiiiiiiii-Vinyzu/patchright-python) — a maintained Playwright fork (Apache-2.0; Copyright 2024 Vinyzu) with stealth patches baked into the bundled Chromium binary. API is a drop-in replacement for Playwright (`from patchright.sync_api import sync_playwright`). Targets Cloudflare's interactive-challenge ("just a moment...") JS gate that defeats Tier 1-2 fetchers on hardened deployments. Targets failures whose error class is CF-shaped (status 403/503, "challenge"/"forbidden"/"blocked" in the error text, or empty body after JS render). Updates `fetch_log.json` in place; successful retries are marked `via: "patchright"`.

Runs AFTER `fetch_pdf_fallback.py` (those are not CF cases). Use:
- `--include-empty` to also re-check entries Crawl4AI marked ok=true but whose markdown looks like a challenge page
- `--all-failures` to retry every failure regardless of CF-shape detection (slower but exhaustive)
- `--channel chrome` to use system Chrome instead of patchright's bundled patched Chromium

Patchright runs Chrome non-headless by default — Cloudflare's challenge detector flags headless Chrome immediately. Expect a visible browser window during the CF retry pass. Install with `pip install patchright` then `patchright install chromium` (one-time, ~200MB browser deps).

**License note.** Patchright replaced an earlier `nodriver`-based Tier-3 implementation in v3.0.1. nodriver is AGPL-3.0, which was incompatible with the framework's intended distribution model; patchright provides equivalent Cloudflare-interactive-challenge bypass under Apache-2.0.

### 5. Cloudflare Turnstile fallback (recovers Turnstile-shape failures patchright couldn't clear)

```powershell
python adapters\crawl4ai-fetch\fetch_scrapling_fallback.py `
  --out-dir "<state-root>\grounding"
```

Uses [`Scrapling`](https://github.com/D4Vinci/Scrapling)'s `StealthyFetcher` with `solve_cloudflare=True`. Targets a different Cloudflare variant than patchright: patchright clears the **interactive challenge** ("just a moment..." JS gate); Scrapling solves **Cloudflare Turnstile** (the CAPTCHA-style widget on hardened deployments). Different attack vectors, complementary tools.

By default this step retries CF-shaped failures still unresolved after the patchright tier. Successful retries are marked `via: "scrapling"`. Use `--all-failures` to retry every failure regardless of shape detection.

Scrapling uses a patched Playwright (also `patchright`) with anti-fingerprint tooling and a Turnstile solver layered on. Can run headless (Scrapling's anti-fingerprint stack hides the headless signature, unlike patchright direct which needs visible Chrome). Install with `pip install 'scrapling[fetchers]'` then `scrapling install` (one-time, ~200MB browser deps; partially shares the patchright install).

### 6. (Optional) Build per-file packets for parallel sub-agent fact-check

```powershell
python adapters\crawl4ai-fetch\build_packets.py `
  --cites "<state-root>\grounding\cites.json" `
  --out-dir "<state-root>\grounding" `
  --kb-name "[KB_NAME]"
```

Produces one packet per source file containing the cite list + fetched-source text (capped at the configured per-cite byte limit). Useful when you want to dispatch one sub-agent per file rather than running a single Phase 5b session over the whole KB.

If you instead pass the whole grounding/ directory directly into a single 5b session, you can skip this step.

---

## Scope

The adapter handles **URL citations only** — `[text](https://...)` markdown links and bare `https://...` URLs in `.md` files under the path you give to `extract_cites.py`. It does NOT cover:

- Statute / regulation cites without a URL (e.g., "21 C.F.R. § 314.50" with no link)
- Case citations without a URL
- Internal cross-references between KB files
- Footnote-style citations that point to a bibliography

Cites in those forms still go through the standard Tier-1 web-search method in 04-fact-checker.md. For URL-form cites, verification is **cite-occurrence-level, not URL-level** — the same URL can support one claim and fail another, so consumers must join `cites.json` × `fetch_log.json` by URL and verify each occurrence against its surrounding KB context.

---

## Setup

```powershell
# IMPORTANT: create the venv OUTSIDE OneDrive. A .venv inside the
# OneDrive-synced tree triggers Purview DLP scans (the certifi
# package ships cacert.pem, which matches the ".pem" DLP rule) and
# wastes ~600 MB of sync bandwidth. The convention is one venv per
# adapter under %LOCALAPPDATA%\kb-venvs\.
cd adapters\crawl4ai-fetch
python -m venv $env:LOCALAPPDATA\kb-venvs\crawl4ai-fetch
& "$env:LOCALAPPDATA\kb-venvs\crawl4ai-fetch\Scripts\Activate.ps1"
pip install -r requirements.txt
python -m playwright install chromium
patchright install chromium
scrapling install
```

Tested with Python 3.12, crawl4ai 0.8.6, Playwright 147, patchright 1.47+, scrapling 0.3+ on Windows. The Crawl4AI `crawl4ai-setup` post-install does NOT install Playwright Chromium reliably — run the explicit `playwright install chromium` step. If it fails with `ECONNRESET`, retry; first-run downloads occasionally fail.

`patchright install chromium` is a one-time post-install that downloads patchright's bundled Chromium binary with stealth patches baked in (~200MB). Without it, `fetch_cf_fallback.py` will fail at browser launch.

`scrapling install` is a one-time post-install that downloads `patchright` (which Scrapling uses transitively) plus its browser binaries. If you've already run `patchright install chromium` for `fetch_cf_fallback.py`, the Scrapling install may detect the existing patchright and skip the redundant browser download.

PowerShell encoding: Crawl4AI prints emoji to stdout. Set `$env:PYTHONIOENCODING="utf-8"` and `$env:PYTHONUTF8=1` before running, or wrap script invocations through `Start-Process` with UTF-8 redirection. The pilot directory has working examples.

---

## Configuration knobs

All adjustable via `--` flags on the relevant script (run with `--help`):

| Knob | Default | When to change |
|---|---|---|
| Per-cite byte cap (in packets) | 100 KB | Lower for very long PDFs; raise if anchor text is appearing past the cap |
| Concurrency | 5 | Raise cautiously — anti-bot sites may IP-block |
| Per-URL timeout | 60s | Raise for slow gov sites; do not lower |
| Retry attempts | 1 | Raise to 2–3 for known-flaky sources |

---

## Known limits

1. **PDF fallback is required.** Without it, you lose ~25% of tier-1 government/court sources.
2. **JS-heavy single-page apps with auth headers** (e.g., EU Lex CELEX deep links) may render an empty shell. Crawl4AI stealth mode helps in some cases, not all.
3. **Anti-bot 403** — Cloudflare interactive challenges are handled by `fetch_cf_fallback.py` (patchright; Apache-2.0). Cloudflare Turnstile (the CAPTCHA-widget variant) is handled by `fetch_scrapling_fallback.py` (Scrapling's StealthyFetcher with `solve_cloudflare=True`). Other anti-bot systems (Akamai Bot Manager, PerimeterX, JSTOR paywall) remain a hard wall. Flag those for manual verification per Pattern 17 in `01-shared-axioms.md`.
4. **Landing pages cited for paragraph-level holdings** will (correctly) fail grounding — this is itself a KB hygiene finding. Re-cite to the underlying document.
5. **Single-model verification.** This adapter does not address **model-family separation** (axiom in `01-shared-axioms.md` §6). Grounding makes Phase 5b *more accurate* but does not substitute for running 5d (single-source claim check) or 6b (post-assembly SUPERSET) under a different family.

---

## Output schema (fetch_log.json)

```json
[
  {
    "url": "https://...",
    "hash": "ab12cd34...",
    "source_file": "03-us-legal-framework.md",
    "anchor": "...",
    "out_path": ".../grounding/sources/ab12cd34....md",
    "ok": true,
    "via": "crawl4ai" | "pdf_fallback" | "patchright" | "scrapling",
    "bytes": 47221,
    "elapsed_sec": 4.8,
    "error": null
  }
]
```

The fact-check prompt uses `ok` + `out_path` to decide which cites have grounding available. Cites with `ok: false` are flagged in the prompt and routed to manual or to a wider-search fallback per the existing prompt logic.
