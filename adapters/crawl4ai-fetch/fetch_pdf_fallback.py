"""
PDF fallback for fetch.py failures.

Crawl4AI cannot render direct PDF URLs (no HTML to parse). This script retries
every fetch_log.json failure using httpx + pypdf and updates the log in place.

Usage:
  python fetch_pdf_fallback.py --out-dir <state-root>/grounding [--timeout 60]
"""
import argparse
import datetime as dt
import io
import json
import time
from pathlib import Path

import httpx
from pypdf import PdfReader


UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0 Safari/537.36"
)


def now_iso():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def looks_like_pdf(url, content_type=None, head=b""):
    if url.lower().endswith(".pdf"):
        return True
    if "/dl" in url.lower() or "/download" in url.lower():
        return True
    if content_type and "pdf" in content_type.lower():
        return True
    if head[:4] == b"%PDF":
        return True
    return False


def fetch_pdf(url, timeout):
    with httpx.Client(headers={"User-Agent": UA}, timeout=timeout, follow_redirects=True) as c:
        r = c.get(url)
        r.raise_for_status()
        return r.content, r.headers.get("content-type", "")


def extract_pdf(data):
    reader = PdfReader(io.BytesIO(data))
    parts = []
    for i, page in enumerate(reader.pages):
        try:
            t = page.extract_text() or ""
            if t.strip():
                parts.append(f"## Page {i+1}\n\n{t.strip()}")
        except Exception as e:
            parts.append(f"## Page {i+1}\n\n[extraction error: {e}]")
    return "\n\n".join(parts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", required=True, help="Grounding dir (must contain fetch_log.json)")
    ap.add_argument("--timeout", type=int, default=60)
    args = ap.parse_args()

    out_dir = Path(args.out_dir)
    log_path = out_dir / "fetch_log.json"
    log = json.loads(log_path.read_text(encoding="utf-8"))
    fails = [r for r in log if not r["ok"]]
    print(f"Retrying {len(fails)} failures with PDF fallback\n")

    recovered = 0
    for r in fails:
        url = r["url"]
        h = r["hash"]
        out_path = Path(r["out_path"])
        t0 = time.time()
        try:
            data, ctype = fetch_pdf(url, args.timeout)
            if not looks_like_pdf(url, ctype, data[:8]):
                r["error"] = f"non-pdf fallback ({ctype}, {len(data)}b)"
                print(f"SKIP {h}  {url[:80]}  -- {r['error']}")
                continue
            text = extract_pdf(data)
            if len(text) < 100:
                r["error"] = f"pdf extracted only {len(text)}b"
                print(f"FAIL {h}  {url[:80]}  -- {r['error']}")
                continue
            out_path.write_text(text, encoding="utf-8")
            elapsed = round(time.time() - t0, 2)
            r.update({
                "ok": True,
                "via": "pdf_fallback",
                "bytes": len(text),
                "pdf_bytes": len(data),
                "elapsed_sec": elapsed,
                "fetched_at": now_iso(),
                "error": None,
            })
            recovered += 1
            print(f"OK   {h} {elapsed:5.1f}s {len(text):7d}b  {url[:80]}")
        except Exception as e:
            r["error"] = f"{type(e).__name__}: {str(e)[:200]}"
            print(f"FAIL {h}  {url[:80]}  -- {r['error']}")

    log.sort(key=lambda r: r["url"])
    log_path.write_text(json.dumps(log, indent=2, ensure_ascii=False), encoding="utf-8")
    ok_now = sum(1 for r in log if r["ok"])
    print(f"\nRECOVERED: {recovered}")
    print(f"TOTAL OK: {ok_now}/{len(log)}")


if __name__ == "__main__":
    main()
