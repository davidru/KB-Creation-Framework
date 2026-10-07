"""
Patchright fallback for Cloudflare interactive-challenge pages.

Cloudflare's interactive challenge ("just a moment...") is a JS-gated wait page
that runs a fingerprint and integrity check before redirecting to the requested
content. Vanilla Playwright + Chromium is detected and held at the challenge
page indefinitely; the wait page never clears.

This script uses `patchright` (https://github.com/Kaliiiiiiiiii-Vinyzu/patchright-python)
— a maintained Playwright fork with stealth patches baked in — to clear the
challenge. Patchright's API is a drop-in replacement for Playwright; the
difference is the patched Chromium binary that ships with it, which evades
the detection vectors Cloudflare uses against vanilla Playwright.

Patchright is licensed Apache-2.0 (Copyright 2024 Vinyzu).

This script is Tier 3 of the adapter cascade. It runs after `fetch.py` (Tier 1
Crawl4AI/Playwright) and `fetch_pdf_fallback.py` (Tier 2 PDF). Tier 4 is
`fetch_scrapling_fallback.py` (Cloudflare Turnstile / CAPTCHA widget) which
solves a different challenge variant.

Targets failures whose error class is CF-shaped (status 403/503,
"challenge"/"forbidden"/"blocked" in the error text, or empty body after JS
render). Updates `fetch_log.json` in place; successful retries are marked
`via: "patchright"`.

Usage:
  python fetch_cf_fallback.py --out-dir <state-root>/grounding
                              [--timeout 60] [--max-wait 30]
                              [--include-empty] [--all-failures]
                              [--channel chrome]

Flags:
  --timeout         Per-URL hard timeout in seconds (default 60).
  --max-wait        Max poll time after navigation for CF challenge clearance
                    (default 30s). Polls page body every 2s.
  --include-empty   Re-check ok=true entries whose body looks like a
                    challenge page.
  --all-failures    Retry every failure regardless of CF-shape detection.
  --channel         Browser channel: "chrome" (uses installed Chrome) or
                    "chromium" (patchright's bundled patched Chromium).
                    Default: "chromium" — no dependence on system Chrome.

Requires:
  pip install patchright
  patchright install chromium    # one-time, downloads patched Chromium
"""
import argparse
import datetime as dt
import hashlib
import json
import re
import time
from pathlib import Path

from patchright.sync_api import sync_playwright


CF_CHALLENGE_TOKENS = (
    "checking your browser",
    "just a moment",
    "challenge-platform",
    "cf-browser-verification",
    "cf_chl_opt",
    "__cf_chl_tk",
    "cloudflare",
    "ray id",
    "attention required",
    "enable javascript and cookies",
)


def now_iso():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def looks_like_cloudflare_failure(entry: dict) -> bool:
    err = (entry.get("error") or "").lower()
    status = entry.get("status_code")
    if status in (403, 503):
        return True
    if any(tok in err for tok in ("403", "forbidden", "cloudflare", "challenge", "blocked")):
        return True
    if "empty_or_failed" in err and entry.get("bytes", 0) == 0:
        return True
    return False


def looks_like_challenge_body(text: str) -> bool:
    if not text:
        return True
    if len(text) > 4000:
        return False
    low = text.lower()
    return any(tok in low for tok in CF_CHALLENGE_TOKENS)


def fetch_with_patchright(url: str, timeout: int, max_wait: int, channel: str):
    """Returns (ok: bool, text: str, error: str)."""
    try:
        with sync_playwright() as p:
            launch_kwargs = {"headless": False}  # Headless flagged by CF; non-headless clears more
            if channel == "chrome":
                launch_kwargs["channel"] = "chrome"
            browser = p.chromium.launch(**launch_kwargs)
            try:
                context = browser.new_context()
                page = context.new_page()
                page.goto(url, timeout=timeout * 1000, wait_until="domcontentloaded")

                # Poll body for challenge clearance — every 2s up to max_wait.
                elapsed = 0
                poll_interval = 2
                while elapsed < max_wait:
                    body_text = page.evaluate("document.body ? document.body.innerText : ''")
                    if body_text and len(body_text) > 1000 and not looks_like_challenge_body(body_text):
                        # Challenge cleared
                        html = page.content()
                        return True, html, ""
                    time.sleep(poll_interval)
                    elapsed += poll_interval

                # Final check
                body_text = page.evaluate("document.body ? document.body.innerText : ''")
                if body_text and len(body_text) > 1000 and not looks_like_challenge_body(body_text):
                    html = page.content()
                    return True, html, ""

                return False, "", f"cf_challenge_not_cleared (waited {max_wait}s, body_len={len(body_text)})"
            finally:
                browser.close()
    except Exception as e:
        return False, "", f"patchright_exception: {type(e).__name__}: {str(e)[:200]}"


def run(out_dir: Path, timeout: int, max_wait: int, include_empty: bool, all_failures: bool, channel: str):
    log_path = out_dir / "fetch_log.json"
    sources_dir = out_dir / "sources"
    if not log_path.exists():
        print(f"No fetch_log.json at {log_path}")
        return

    log = json.loads(log_path.read_text(encoding="utf-8"))
    by_url = {r["url"]: r for r in log if "url" in r}

    candidates = []
    for r in log:
        if r.get("ok"):
            if include_empty:
                op = r.get("out_path")
                if op and Path(op).exists():
                    body = Path(op).read_text(encoding="utf-8", errors="ignore")
                    if looks_like_challenge_body(body):
                        candidates.append(r)
            continue
        if all_failures:
            candidates.append(r)
            continue
        if looks_like_cloudflare_failure(r):
            candidates.append(r)

    if not candidates:
        print("No candidates for patchright retry. Use --all-failures to retry every failure.")
        return

    print(f"Retrying {len(candidates)} URLs via patchright (timeout={timeout}s, max_wait={max_wait}s, channel={channel})...\n")
    recovered = 0
    for i, entry in enumerate(candidates, 1):
        url = entry["url"]
        print(f"[{i}/{len(candidates)}] {url[:100]}")
        t0 = time.time()
        ok, text, err = fetch_with_patchright(url, timeout, max_wait, channel)
        elapsed = round(time.time() - t0, 2)

        target = by_url.get(url)
        if target is None:
            continue

        if ok and text:
            out_path = sources_dir / f"{entry['hash']}.md"
            out_path.write_text(text, encoding="utf-8")
            target.update({
                "ok": True,
                "via": "patchright",
                "bytes": len(text),
                "elapsed_sec": elapsed,
                "fetched_at": now_iso(),
                "error": None,
            })
            recovered += 1
            print(f"  OK   {len(text):7d}b  {elapsed:5.1f}s  via=patchright")
        else:
            target["patchright_attempt"] = {
                "elapsed_sec": elapsed,
                "fetched_at": now_iso(),
                "error": err,
            }
            print(f"  FAIL              {elapsed:5.1f}s  {err}")

    log_sorted = sorted(by_url.values(), key=lambda r: r["url"])
    log_path.write_text(json.dumps(log_sorted, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nDONE: {recovered}/{len(candidates)} recovered via patchright")
    print(f"WROTE: {log_path}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out-dir", required=True, help="Grounding output dir (same as fetch.py --out-dir)")
    ap.add_argument("--timeout", type=int, default=60,
                    help="Per-URL hard timeout (seconds). Patchright + CF clearance can take 20-40s.")
    ap.add_argument("--max-wait", type=int, default=30,
                    help="Max poll time (seconds) for CF challenge clearance after navigation.")
    ap.add_argument("--include-empty", action="store_true",
                    help="Also retry entries marked ok=true whose body looks like a challenge page")
    ap.add_argument("--all-failures", action="store_true",
                    help="Retry every failure regardless of CF-shape detection")
    ap.add_argument("--channel", default="chromium", choices=["chromium", "chrome"],
                    help="Browser channel: 'chromium' (patchright's bundled) or 'chrome' (system Chrome). Default: chromium.")
    args = ap.parse_args()

    out_dir = Path(args.out_dir)
    if not out_dir.exists():
        raise SystemExit(f"out-dir does not exist: {out_dir}")

    run(out_dir, args.timeout, args.max_wait, args.include_empty, args.all_failures, args.channel)


if __name__ == "__main__":
    main()
