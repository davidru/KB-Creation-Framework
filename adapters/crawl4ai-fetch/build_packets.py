"""
Build per-file fact-check packets — generalized version.

For each source file referenced by cites.json, write:
  <out-dir>/packets/<file-stem>.md   (cite list + fetched markdown + verdict prompt)

Only includes cites whose fetch succeeded (per fetch_log.json).
Per-cite text capped at --cap-bytes (default 100KB).

Usage:
  python build_packets.py --cites <cites.json> --out-dir <state-root>/grounding
                          --kb-name "[KB_NAME]" [--cap-bytes 100000]
"""
import argparse
import json
from pathlib import Path


PROMPT = """\
You are a fact-checker auditing citations in the [{kb_name}] knowledge base.

For each numbered citation below, you are given:
  - The KB context (the surrounding passage in which the URL is cited)
  - The cited URL
  - The fetched text of the cited page (Markdown extracted from HTML or PDF)

Your job: for each citation, determine whether the URL — interpreted in good faith — actually supports the claim made in the KB context. Use the fetched text. Do not rely on outside knowledge: if the fetched text does not address the claim, mark UNSUPPORTED or UNCERTAIN.

Verdicts (use exactly one):
  - SUPPORTED          : The source clearly supports the claim as stated.
  - PARTIALLY_SUPPORTED: The source supports part of the claim but the KB overstates, mischaracterizes, or extrapolates.
  - CONTRADICTED       : The source actually contradicts the claim or attributes the fact differently.
  - UNSUPPORTED        : The source does not address the claim (off-topic, wrong document, or generic landing page).
  - UNCERTAIN          : Insufficient information to decide (be honest; do not guess).

Confidence: HIGH / MEDIUM / LOW. Base your confidence on whether the fetched text actually addresses the claim.

Output STRICTLY this JSON, with no surrounding prose, no markdown code fences, nothing else:

{{
  "findings": [
    {{
      "id": "<cite id>",
      "verdict": "SUPPORTED|PARTIALLY_SUPPORTED|CONTRADICTED|UNSUPPORTED|UNCERTAIN",
      "confidence": "HIGH|MEDIUM|LOW",
      "rationale": "<one or two sentences explaining the verdict>",
      "drift_type": "<null OR one of: wrong_provision, wrong_jurisdiction, wrong_document, overstated, mischaracterized, attribution_error, missing_attribution, stale, no_longer_at_url, unsupported, other>"
    }}
  ]
}}

Be precise. Be honest about uncertainty. Do not invent details that are not present in the inputs.
"""


def build_cite_block(idx, cite, fetched_path, fetched_via, fetched_bytes, cap):
    parts = [
        f"### Citation {idx}",
        "",
        f"**Cite ID:** `{cite['source_file']}:L{cite['line']}-{idx}`",
        "",
        f"**KB context (from `{cite['source_file']}` line {cite['line']}):**",
        "```",
        cite["context"],
        "```",
        "",
        f"**Cited URL:** {cite['url']}",
    ]
    if cite.get("anchor"):
        parts.append(f"**Anchor text:** {cite['anchor']}")
    parts.append("")

    text = Path(fetched_path).read_text(encoding="utf-8", errors="replace")
    truncated = ""
    if len(text) > cap:
        truncated = f"\n\n[...truncated; original {len(text)} bytes]"
        text = text[:cap]
    parts.append(f"**Fetched source text** (via {fetched_via}, {fetched_bytes} bytes; capped at {cap}):")
    parts.append("```")
    parts.append(text + truncated)
    parts.append("```")
    parts.append("")
    return "\n".join(parts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cites", required=True)
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--kb-name", required=True)
    ap.add_argument("--cap-bytes", type=int, default=100_000)
    args = ap.parse_args()

    out_dir = Path(args.out_dir)
    packets = out_dir / "packets"
    packets.mkdir(parents=True, exist_ok=True)

    cites = json.loads(Path(args.cites).read_text(encoding="utf-8"))
    log = json.loads((out_dir / "fetch_log.json").read_text(encoding="utf-8"))
    by_url = {r["url"]: r for r in log}

    by_file = {}
    skipped_no_fetch = 0
    for c in cites:
        f = by_url.get(c["url"])
        if not f or not f.get("ok"):
            skipped_no_fetch += 1
            continue
        by_file.setdefault(c["source_file"], []).append({**c, "fetch": f})

    preamble = PROMPT.format(kb_name=args.kb_name)

    written = 0
    for fname, file_cites in sorted(by_file.items()):
        out = [preamble, "", "---", "", f"## Citations to verify ({len(file_cites)} from `{fname}`)", ""]
        for i, c in enumerate(file_cites, 1):
            out.append(build_cite_block(
                i, c,
                fetched_path=c["fetch"]["out_path"],
                fetched_via=c["fetch"].get("via", "crawl4ai"),
                fetched_bytes=c["fetch"]["bytes"],
                cap=args.cap_bytes,
            ))
            out.append("")
        # Use a stem that is a flat, FS-safe form of the source file path
        stem = fname.replace("/", "__").replace("\\", "__").replace(".md", "")
        (packets / f"{stem}.md").write_text("\n".join(out), encoding="utf-8")
        written += 1

    print(f"Wrote {written} packets to {packets}")
    print(f"Cites grounded: {sum(len(v) for v in by_file.values())}")
    print(f"Cites skipped (no successful fetch): {skipped_no_fetch}")
    print()
    for fname, cs in sorted(by_file.items()):
        print(f"  {len(cs):4d}  {fname}")


if __name__ == "__main__":
    main()
