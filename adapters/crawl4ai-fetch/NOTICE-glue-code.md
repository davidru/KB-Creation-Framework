# Notices for `adapters/crawl4ai-fetch/`

This file documents two things:

1. The **provenance** of the `LICENSE` file in this directory (which is the upstream Crawl4AI license, reproduced verbatim — not a Microsoft work).
2. The **license inheritance** for the original Python glue scripts in this directory (which ARE Microsoft works, but their MIT license is documented in the parent framework's `LICENSE`, not here, to avoid displacing the upstream Crawl4AI author's name in this directory).

---

## 1. The `LICENSE` file in this directory

`LICENSE` in this directory is the upstream Crawl4AI project's LICENSE file, reproduced **verbatim**. Crawl4AI is **not a Microsoft work** — it is authored and maintained by UncleCode (https://x.com/unclecode) and the Crawl4AI project contributors. Microsoft does not claim copyright over Crawl4AI, and the `LICENSE` file in this directory contains no Microsoft copyright statement.

The upstream Crawl4AI license is Apache License 2.0 with an additional Attribution Requirement (see the bottom of the `LICENSE` file for the verbatim Attribution Requirement section).

### Provenance

| Field | Value |
|---|---|
| Source | https://github.com/unclecode/crawl4ai |
| Specific file | https://github.com/unclecode/crawl4ai/blob/main/LICENSE |
| Upstream git blob SHA | `ade44a7824869fe57a3dfa98ad4b7ffb764c3cb0` |
| Retrieved | 2026-06-06 |
| Reproduction | Byte-faithful (re-fetched from upstream 2026-10-07; git blob SHA verified identical; LF line endings, no trailing newline, as upstream) — no edits, no Microsoft additions, no headers prepended to the upstream text |

### Re-audit obligation

The local `LICENSE` file must be re-fetched and diff-compared against upstream on every framework version bump. The Apache-2.0 boilerplate does not change, but the maintainer may edit the Attribution Requirement section (the part after the `END OF TERMS AND CONDITIONS` / `---` marker). On re-audit:

1. Fetch the current upstream `LICENSE` from the repo.
2. Diff against the local copy.
3. If different, update the local copy verbatim and bump the provenance fields above.
4. Confirm the attribution string carried in `README.md` and `THIRD_PARTY_NOTICES.md` still matches upstream.

---

## 2. License of the original Python glue scripts in this directory

The original Python scripts authored by Microsoft for this adapter are:

- `extract_cites.py`
- `fetch.py`
- `fetch_cf_fallback.py`
- `fetch_pdf_fallback.py`
- `fetch_scrapling_fallback.py`
- `build_packets.py`

These scripts are part of the parent `KB Creation - Modular v3` framework and are licensed under that framework's MIT License. The MIT license text and Microsoft copyright statement live in the parent's `LICENSE`, not here:

> `..\..\LICENSE` — parent framework MIT License (Copyright (c) Microsoft Corporation)

This file deliberately does not restate the MIT license text in this directory. The reason: this directory is named `crawl4ai-fetch` and is built around a third-party dependency (Crawl4AI). The most visually prominent license artifact in a directory should reflect the dependency the directory is built around, not the Microsoft glue code. Placing a Microsoft copyright statement at the top of a file in this directory was the failure mode that triggered this restructure on 2026-06-06.

---

## 3. The five other third-party Python dependencies

This adapter also depends on five third-party Python packages other than Crawl4AI:

- `playwright` (Apache-2.0)
- `patchright` (Apache-2.0)
- `httpx` (BSD-3-Clause)
- `pypdf` (BSD-3-Clause)
- `scrapling[fetchers]` (BSD-3-Clause)

Their verbatim licenses, copyright statements, and attribution requirements are in `THIRD_PARTY_NOTICES.md` in this directory.

---

## 4. Summary of license files in this directory

| File | Author | License | What it covers |
|---|---|---|---|
| `LICENSE` | UncleCode and Crawl4AI contributors | Apache-2.0 + Attribution Requirement | The upstream Crawl4AI project, reproduced verbatim |
| `THIRD_PARTY_NOTICES.md` | (attribution document) | (n/a) | Attribution for all six direct third-party dependencies including Crawl4AI |
| `NOTICE-glue-code.md` (this file) | (notice document) | (n/a) | Provenance of the LICENSE file + inheritance pointer for the Microsoft-authored glue code |
| `..\..\LICENSE` (parent) | Microsoft Corporation | MIT | The original framework works, including the original Python glue scripts in this directory |
