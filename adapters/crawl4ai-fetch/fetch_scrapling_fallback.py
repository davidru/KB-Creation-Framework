"""
Scrapling StealthyFetcher fallback for Cloudflare Turnstile and other anti-bot
walls that defeat both Crawl4AI/Playwright and the patchright tier.

Cloudflare runs at least two challenge variants in 2026 — the "interactive
challenge" / "just a moment..." JS gate (handled by `fetch_cf_fallback.py`
using patchright), and the Cloudflare Turnstile widget (handled by this
script).

Scrapling's StealthyFetcher (https://github.com/D4Vinci/Scrapling) wraps a
patched Playwright build (also patchright under the hood) with anti-
fingerprint tooling and advertises Turnstile bypass out of the box
(`solve_cloudflare=True`).

This script is Tier 4 of the adapter cascade (after Crawl4AI, PDF fallback,
and patchright). It reads fetch_log.json and picks failures that:
  (a) look CF-shaped (403/503 status, body shows "checking your browser"
      or similar challenge tokens), OR
  (b) look Turnstile-shaped specifically (body contains cf-turnstile,
      __cf_chl_tk, etc.).
Successful retries write the rendered text to grounding/sources/<sha1>.md
and mark via="scrapling".

Usage:
  python fetch_scrapling_fallback.py --out-dir <state-root>/grounding
                                     [--timeout 90] [--include-empty]
                                     [--all-failures]

Flags:
  --include-empty   Re-check ok=true entries whose body looks like a
                    challenge page.
  --all-failures    Retry every failure regardless of shape detection.

Requires:
  pip install 'scrapling[fetchers]'
  scrapling install      # downloads patchright + browser deps (~200MB)
"""
import argparse
import datetime as dt
import json
import re
import time
from pathlib import Path


CF_CHALLENGE_TOKENS = (
    "just a moment",
    "checking your browser",
    "cf-challenge",
    "cf_chl_opt",
    "cloudflare",
    "ray id",
    "attention required",
    "enable javascript and cookies",
)

TURNSTILE_TOKENS = (
    "cf-turnstile",
    "__cf_chl_tk",
    "turnstile",
    "challenges.cloudflare.com",
)


def now_iso():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def looks_like_cloudflare_failure(entry: dict) -> bool:
    err = (entry.get("error") or "").lower()
    status = entry.get("status_code")
    if status in (403, 503):
        return True
    if any(tok in err for tok in ("403", "forbidden", "cloudflare", "challenge", "blocked", "turnstile")):
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


def looks_like_turnstile_body(text: str) -> bool:
    if not text:
        return False
    low = text.lower()
    return any(tok in low for tok in TURNSTILE_TOKENS)


def fetch_with_scrapling(url: str, timeout: int) -> tuple[bool, str, str]:
    """Use Scrapling's StealthyFetcher with solve_cloudflare=True.

    Returns (ok, text, error). text is the rendered DOM as text.
    """
    try:
        from scrapling.fetchers import StealthyFetcher
    except ImportError as e:
        return False, "", f"scrapling_not_installed: {e}"

    try:
        # solve_cloudflare=True activates the Turnstile / interactive-challenge
        # solver. headless=True is acceptable here because Scrapling's
        # patchright + anti-fingerprint stack hides the headless signature
        # (unlike stock Playwright which Cloudflare detects immediately).
        # network_idle gives JS time to render after the challenge clears.
        response = StealthyFetcher.fetch(
            url,
            headless=True,
            solve_cloudflare=True,
            network_idle=True,
            timeout=timeout * 1000,  # Scrapling expects milliseconds
            block_ads=True,
            disable_resources=False,  # we want the full DOM
        )
    except Exception as e:
        return False, "", f"{type(e).__name__}: {str(e)[:200]}"

    status = getattr(response, "status", None)
    html = getattr(response, "html_content", "") or ""

    # Try to extract visible text. Scrapling's Response is a parsel-style
    # selector; .get_all_text() returns concatenated text content.
    try:
        text = response.get_all_text() if hasattr(response, "get_all_text") else ""
    except Exception:
        text = ""
    if not text:
        # Fall back to stripping HTML naively
        text = re.sub(r"<[^>]+>", " ", html)
        text = re.sub(r"\s+", " ", text).strip()

    if status and status >= 400:
        return False, "", f"http_{status}"

    if not text or looks_like_challenge_body(text):
        return False, "", f"cf_challenge_not_cleared (body_len={len(text)}, status={status})"

    text = re.sub(r"\n{3,}", "\n\n", text).strip()
    return True, text, ""


def run(out_dir: Path, timeout: int, include_empty: bool, all_failures: bool):
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
                    if looks_like_challenge_body(body) or looks_like_turnstile_body(body):
                        candidates.append(r)
            continue
        if all_failures:
            candidates.append(r)
            continue
        if looks_like_cloudflare_failure(r):
            candidates.append(r)

    if not candidates:
        print("No candidates for Scrapling retry. Use --all-failures to retry every failure.")
        return

    print(f"Retrying {len(candidates)} URLs via Scrapling StealthyFetcher (timeout={timeout}s)...\n")
    recovered = 0
    for i, entry in enumerate(candidates, 1):
        url = entry["url"]
        print(f"[{i}/{len(candidates)}] {url[:100]}")
        t0 = time.time()
        ok, text, err = fetch_with_scrapling(url, timeout)
        elapsed = round(time.time() - t0, 2)

        target = by_url.get(url)
        if target is None:
            continue

        if ok and text:
            out_path = sources_dir / f"{entry['hash']}.md"
            out_path.write_text(text, encoding="utf-8")
            target.update({
                "ok": True,
                "via": "scrapling",
                "bytes": len(text),
                "elapsed_sec": elapsed,
                "fetched_at": now_iso(),
                "error": None,
            })
            recovered += 1
            print(f"  OK   {len(text):7d}b  {elapsed:5.1f}s  via=scrapling")
        else:
            target["scrapling_attempt"] = {
                "elapsed_sec": elapsed,
                "fetched_at": now_iso(),
                "error": err,
            }
            print(f"  FAIL              {elapsed:5.1f}s  {err}")

    log_sorted = sorted(by_url.values(), key=lambda r: r["url"])
    log_path.write_text(json.dumps(log_sorted, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nDONE: {recovered}/{len(candidates)} recovered via Scrapling")
    print(f"WROTE: {log_path}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out-dir", required=True, help="Grounding output dir (same as fetch.py --out-dir)")
    ap.add_argument("--timeout", type=int, default=90,
                    help="Per-URL hard timeout (seconds). Scrapling+Turnstile-solve can take 30-60s.")
    ap.add_argument("--include-empty", action="store_true",
                    help="Also retry entries marked ok=true whose body looks like a challenge or Turnstile page")
    ap.add_argument("--all-failures", action="store_true",
                    help="Retry every failure regardless of shape detection")
    args = ap.parse_args()

    out_dir = Path(args.out_dir)
    if not out_dir.exists():
        raise SystemExit(f"out-dir does not exist: {out_dir}")

    run(out_dir, args.timeout, args.include_empty, args.all_failures)


if __name__ == "__main__":
    main()
