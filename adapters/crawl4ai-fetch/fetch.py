"""
Crawl4AI fetcher — generalized version.

Reads cites.json (output of extract_cites.py), fetches each unique URL with
Crawl4AI (Playwright + readability), writes:
  <out-dir>/sources/<sha1>.md  (per unique URL)
  <out-dir>/fetch_log.json     (manifest, sorted by URL)

Concurrency 5, 60s per-URL timeout, single retry. Cached entries are reused
when fresh (per --max-age-days); --refresh forces re-fetch of all URLs.

NOTE: extract_cites.py emits ONE record per cite occurrence (URL × source_file × line).
The fetcher dedupes to unique URLs for efficiency. Downstream consumers MUST join
fetch_log.json (URL-keyed) with cites.json (cite-occurrence-keyed) by URL. The
packet builder (build_packets.py) does this join correctly.

Usage:
  python fetch.py --cites <cites.json> --out-dir <state-root>/grounding
                  [--concurrency 5] [--timeout 60] [--retries 1]
                  [--max-age-days 7] [--refresh]
"""
import argparse
import asyncio
import datetime as dt
import hashlib
import json
import os
import time
from pathlib import Path

from crawl4ai import AsyncWebCrawler, BrowserConfig, CrawlerRunConfig, CacheMode


def url_hash(url: str) -> str:
    return hashlib.sha1(url.encode("utf-8")).hexdigest()[:16]


def now_iso():
    return dt.datetime.now(dt.timezone.utc).isoformat()


async def fetch_one(crawler, entry, sources_dir, sem, results, timeout, retries):
    url = entry["url"]
    h = entry["hash"]
    out_path = sources_dir / f"{h}.md"
    meta = dict(entry)
    cfg = CrawlerRunConfig(
        cache_mode=CacheMode.BYPASS,
        page_timeout=timeout * 1000,
        word_count_threshold=10,
    )
    async with sem:
        for attempt in range(1, retries + 2):
            t0 = time.time()
            try:
                r = await asyncio.wait_for(
                    crawler.arun(url=url, config=cfg),
                    timeout=timeout + 30,
                )
                elapsed = round(time.time() - t0, 2)
                md_obj = getattr(r, "markdown", None)
                if md_obj is None:
                    md_text = ""
                elif isinstance(md_obj, str):
                    md_text = md_obj
                else:
                    md_text = (
                        getattr(md_obj, "fit_markdown", None)
                        or getattr(md_obj, "raw_markdown", None)
                        or str(md_obj)
                    )
                if r.success and md_text and len(md_text) > 50:
                    out_path.write_text(md_text, encoding="utf-8")
                    meta.update({
                        "ok": True,
                        "via": "crawl4ai",
                        "attempt": attempt,
                        "bytes": len(md_text),
                        "status_code": getattr(r, "status_code", None),
                        "elapsed_sec": elapsed,
                        "fetched_at": now_iso(),
                        "error": None,
                    })
                    print(f"OK   {h} {elapsed:5.1f}s {len(md_text):7d}b  {url[:80]}")
                    results.append(meta)
                    return
                err = f"empty_or_failed (success={r.success}, len={len(md_text)})"
                if attempt > retries:
                    meta.update({"ok": False, "via": "crawl4ai", "attempt": attempt, "bytes": len(md_text), "elapsed_sec": elapsed, "fetched_at": now_iso(), "error": err})
                    print(f"FAIL {h} {elapsed:5.1f}s              {url[:80]}  {err}")
                    results.append(meta)
                    return
            except Exception as e:
                elapsed = round(time.time() - t0, 2)
                err = f"{type(e).__name__}: {str(e)[:200]}"
                if attempt > retries:
                    meta.update({"ok": False, "via": "crawl4ai", "attempt": attempt, "bytes": 0, "elapsed_sec": elapsed, "fetched_at": now_iso(), "error": err})
                    print(f"FAIL {h} {elapsed:5.1f}s              {url[:80]}  {err}")
                    results.append(meta)
                    return
            await asyncio.sleep(2)


def dedupe_cites(cites):
    """Collapse cites by URL — fetch each unique URL once.
    Per-occurrence context is preserved in cites.json; consumers join by URL.
    """
    by_url = {}
    for c in cites:
        url = c["url"]
        if url not in by_url:
            by_url[url] = {
                "url": url,
                "hash": url_hash(url),
                "first_source_file": c["source_file"],
                "anchor": c.get("anchor", ""),
                "ref_count": 1,
            }
        else:
            by_url[url]["ref_count"] += 1
    return list(by_url.values())


def load_prior_log(log_path):
    if not log_path.exists():
        return {}
    try:
        prior = json.loads(log_path.read_text(encoding="utf-8"))
        return {r["url"]: r for r in prior if "url" in r}
    except Exception:
        return {}


def is_cache_fresh(prior, max_age_days):
    if not prior or not prior.get("ok"):
        return False
    fa = prior.get("fetched_at")
    if not fa:
        return False
    try:
        ts = dt.datetime.fromisoformat(fa)
    except Exception:
        return False
    age = dt.datetime.now(dt.timezone.utc) - ts
    return age <= dt.timedelta(days=max_age_days)


async def run(cites_path, out_dir, concurrency, timeout, retries, max_age_days, refresh):
    cites = json.loads(Path(cites_path).read_text(encoding="utf-8"))
    entries = dedupe_cites(cites)

    sources_dir = out_dir / "sources"
    sources_dir.mkdir(parents=True, exist_ok=True)
    log_path = out_dir / "fetch_log.json"
    prior_by_url = load_prior_log(log_path)

    todo, kept = [], []
    for e in entries:
        out_p = sources_dir / f"{e['hash']}.md"
        e["out_path"] = str(out_p)
        prior = prior_by_url.get(e["url"])
        if not refresh and prior and is_cache_fresh(prior, max_age_days) and out_p.exists():
            merged = {**e, **{k: v for k, v in prior.items() if k not in e}}
            merged["via"] = (prior.get("via") or "cached") + "+cached"
            kept.append(merged)
        else:
            todo.append(e)

    print(f"Fetching {len(todo)} URLs (kept-fresh {len(kept)} cached, max_age={max_age_days}d, refresh={refresh}); concurrency={concurrency}, timeout={timeout}s\n")
    results = list(kept)
    if todo:
        sem = asyncio.Semaphore(concurrency)
        browser = BrowserConfig(headless=True, verbose=False)
        async with AsyncWebCrawler(config=browser) as crawler:
            await asyncio.gather(*(fetch_one(crawler, e, sources_dir, sem, results, timeout, retries) for e in todo))

    results.sort(key=lambda r: r["url"])
    log_path.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    ok = sum(1 for r in results if r["ok"])

    # Summary artifact
    fails = [r for r in results if not r["ok"]]
    error_classes = {}
    for r in fails:
        cls = (r.get("error") or "unknown").split(":")[0][:80]
        error_classes[cls] = error_classes.get(cls, 0) + 1
    summary = {
        "generated_at": now_iso(),
        "total_unique_urls": len(results),
        "ok": ok,
        "failed": len(fails),
        "success_rate": round(ok / len(results), 3) if results else None,
        "via_breakdown": {},
        "error_classes": error_classes,
        "cites_input": str(cites_path),
        "total_cite_occurrences_in_input": len(cites),
    }
    via_counter = {}
    for r in results:
        v = r.get("via", "unknown")
        via_counter[v] = via_counter.get(v, 0) + 1
    summary["via_breakdown"] = via_counter
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

    print(f"\nDONE: {ok}/{len(results)} succeeded")
    print(f"WROTE: {log_path}")
    print(f"WROTE: {out_dir / 'summary.json'}")
    if fails:
        print(f"\n{len(fails)} FAILURES (try fetch_pdf_fallback.py):")
        for r in fails[:20]:
            print(f"  {r['url'][:100]}  -- {r['error']}")
        if len(fails) > 20:
            print(f"  ... and {len(fails) - 20} more")


def main():
    os.environ.setdefault("PYTHONIOENCODING", "utf-8")
    os.environ.setdefault("PYTHONUTF8", "1")

    ap = argparse.ArgumentParser()
    ap.add_argument("--cites", required=True, help="Path to cites.json")
    ap.add_argument("--out-dir", required=True, help="Grounding output dir (e.g., <state-root>/grounding)")
    ap.add_argument("--concurrency", type=int, default=5)
    ap.add_argument("--timeout", type=int, default=60)
    ap.add_argument("--retries", type=int, default=1)
    ap.add_argument("--max-age-days", type=int, default=7,
                    help="Re-use cached entries younger than this. Phase 6b should set this low (1) or use --refresh.")
    ap.add_argument("--refresh", action="store_true",
                    help="Force re-fetch of every URL, bypassing cache. Use before Phase 6b SUPERSET to avoid stale-cache false positives.")
    args = ap.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    asyncio.run(run(args.cites, out_dir, args.concurrency, args.timeout, args.retries, args.max_age_days, args.refresh))


if __name__ == "__main__":
    main()

