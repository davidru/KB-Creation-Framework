"""
Cite extractor — generalized version.

Reads every .md file under --kb (recursive), extracts:
  - markdown links: [anchor](https://url)
  - bare URLs: https://...

Writes a JSON inventory to --out with per-cite context (3 lines before, 2 after)
and prints per-file + per-domain summaries.

Usage:
  python extract_cites.py --kb <kb-or-drafts-dir> --out <path-to-cites.json>
"""
import argparse
import json
import re
from collections import Counter
from pathlib import Path
from urllib.parse import urlparse


MD_LINK = re.compile(r"\[([^\]]+)\]\((https?://[^)\s]+)\)")
BARE_URL = re.compile(r"(?<![(\[\"])\bhttps?://[^\s)\]>'\"]+", re.IGNORECASE)


def extract(kb_root: Path, recursive: bool = True):
    cites = []
    seen_pairs = set()
    glob_pat = "**/*.md" if recursive else "*.md"
    files = sorted(kb_root.glob(glob_pat))
    for md in files:
        text = md.read_text(encoding="utf-8", errors="replace")
        lines = text.splitlines()
        rel = str(md.relative_to(kb_root))
        for i, line in enumerate(lines, 1):
            for m in MD_LINK.finditer(line):
                anchor, url = m.group(1).strip(), m.group(2).rstrip(".,;:")
                key = (rel, url)
                if key in seen_pairs:
                    continue
                seen_pairs.add(key)
                ctx_start = max(0, i - 3)
                ctx_end = min(len(lines), i + 2)
                cites.append({
                    "url": url,
                    "anchor": anchor,
                    "source_file": rel,
                    "line": i,
                    "context": "\n".join(lines[ctx_start:ctx_end]),
                    "kind": "md_link",
                })
            captured = {m.group(2).rstrip(".,;:") for m in MD_LINK.finditer(line)}
            for m in BARE_URL.finditer(line):
                url = m.group(0).rstrip(".,;:)")
                if url in captured:
                    continue
                key = (rel, url)
                if key in seen_pairs:
                    continue
                seen_pairs.add(key)
                ctx_start = max(0, i - 3)
                ctx_end = min(len(lines), i + 2)
                cites.append({
                    "url": url,
                    "anchor": "",
                    "source_file": rel,
                    "line": i,
                    "context": "\n".join(lines[ctx_start:ctx_end]),
                    "kind": "bare_url",
                })
    return cites, files


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kb", required=True, help="Path to KB or drafts directory")
    ap.add_argument("--out", required=True, help="Output cites.json path")
    ap.add_argument("--no-recursive", action="store_true", help="Only top-level .md files")
    args = ap.parse_args()

    kb = Path(args.kb)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)

    cites, files = extract(kb, recursive=not args.no_recursive)

    domains = Counter()
    for c in cites:
        try:
            domains[urlparse(c["url"]).netloc.lower()] += 1
        except Exception:
            pass

    out.write_text(json.dumps(cites, indent=2, ensure_ascii=False), encoding="utf-8")

    per_file = Counter(c["source_file"] for c in cites)
    print(f"TOTAL_CITES: {len(cites)}")
    print(f"UNIQUE_URLS: {len({c['url'] for c in cites})}")
    print(f"FILES_SCANNED: {len(files)}")
    print(f"WROTE: {out}")
    print()
    print("PER-FILE:")
    for f, n in sorted(per_file.items()):
        print(f"  {n:4d}  {f}")
    print()
    print("TOP DOMAINS:")
    for d, n in domains.most_common(20):
        print(f"  {n:4d}  {d}")


if __name__ == "__main__":
    main()
