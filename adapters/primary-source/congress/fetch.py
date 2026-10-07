#!/usr/bin/env python3
"""
fetch.py — api.congress.gov primary-source adapter (KB Creation Framework v3.1.13).

Fetches bills, public laws, and amendments from https://api.congress.gov/v3/.
REQUIRES env var CONGRESS_API_KEY (free from https://api.congress.gov/sign-up/).

USAGE
    python fetch.py --congress 117 --bill-type hr --bill-number 3076 --cache <dir>
    python fetch.py --public-law "117-103" --cache <dir>

OUTPUT: same envelope as ecfr/fetch.py.

EXIT CODES: 0 success, 1 fetch, 2 parse, 3 cache write, 5 missing API key.

DEPENDENCIES: Python stdlib only.
"""
from __future__ import annotations
import argparse, datetime, hashlib, json, os, pathlib, re, sys
import urllib.error, urllib.parse, urllib.request

CONGRESS_BASE = "https://api.congress.gov/v3"


def emit(payload: dict, code: int = 0) -> None:
    print(json.dumps(payload, indent=2, sort_keys=True)); sys.exit(code)


def emit_error(et: str, msg: str, rem: str, code: int = 1) -> None:
    emit({"status": "error", "adapter": "congress", "error_type": et, "error_message": msg, "remediation": rem}, code)


def fetch_url(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"Accept": "application/json", "User-Agent": "KB-Framework-v3.1.13/congress"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read()
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.reason}") from e
    except urllib.error.URLError as e:
        raise RuntimeError(f"URL error: {e.reason}") from e


def main() -> None:
    ap = argparse.ArgumentParser(description="api.congress.gov fetcher (v3.1.13)")
    ap.add_argument("--congress", type=int, help="Congress number (e.g. 117)")
    ap.add_argument("--bill-type", choices=["hr", "s", "hjres", "sjres", "hconres", "sconres", "hres", "sres"], help="Bill type")
    ap.add_argument("--bill-number", type=int, help="Bill number")
    ap.add_argument("--public-law", help="Public law cite, e.g. '117-103'")
    ap.add_argument("--cache", required=True)
    args = ap.parse_args()

    api_key = os.environ.get("CONGRESS_API_KEY", "").strip()
    if not api_key:
        emit_error("missing_api_key",
                   "CONGRESS_API_KEY env var is not set.",
                   "Get a free key at https://api.congress.gov/sign-up/ and set with: [Environment]::SetEnvironmentVariable('CONGRESS_API_KEY', '<key>', 'User')",
                   code=5)

    cache_root = pathlib.Path(args.cache) / "congress"
    cache_root.mkdir(parents=True, exist_ok=True)

    if args.public_law:
        m = re.match(r"^(\d+)-(\d+)$", args.public_law.strip())
        if not m: emit_error("cite_parse_error", f"Unable to parse public law '{args.public_law}'", "Use 'CONGRESS-NUMBER' format like '117-103'.", code=2)
        congress, law_num = m.group(1), m.group(2)
        url = f"{CONGRESS_BASE}/law/{congress}/pub/{law_num}?format=json&api_key={api_key}"
        slug = f"pl-{congress}-{law_num}"
        identifier = f"Pub. L. {args.public_law}"
    elif args.congress and args.bill_type and args.bill_number:
        url = f"{CONGRESS_BASE}/bill/{args.congress}/{args.bill_type}/{args.bill_number}?format=json&api_key={api_key}"
        slug = f"bill-{args.congress}-{args.bill_type}{args.bill_number}"
        identifier = f"{args.bill_type.upper()} {args.bill_number} (Congress {args.congress})"
    else:
        emit_error("cite_parse_error",
                   "Must specify either --public-law OR all of --congress + --bill-type + --bill-number.",
                   "Examples: --public-law 117-103, OR --congress 117 --bill-type hr --bill-number 3076.",
                   code=2)

    content_path = cache_root / f"{slug}.json"
    manifest_path = cache_root / f"{slug}.manifest.json"
    prior_sha = None
    if manifest_path.exists():
        try: prior_sha = json.loads(manifest_path.read_text(encoding="utf-8")).get("sha256")
        except Exception: pass

    try:
        data = fetch_url(url)
    except RuntimeError as e:
        m = str(e)
        if "HTTP 401" in m or "HTTP 403" in m: emit_error("auth_failure", m, "CONGRESS_API_KEY rejected. Verify or regenerate at https://api.congress.gov/sign-up/.")
        elif "HTTP 404" in m: emit_error("source_not_found", f"Congress API returned 404 for '{identifier}'", "Verify bill / public law identifier.")
        elif "HTTP 429" in m: emit_error("rate_limit", m, "5,000 req/hr limit hit. Wait or back off.")
        elif "HTTP 5" in m: emit_error("upstream_error", m, "Transient Congress API failure.")
        else: emit_error("fetch_error", m, "Network error.")

    sha = hashlib.sha256(data).hexdigest()
    try: content_path.write_bytes(data)
    except OSError as e: emit_error("cache_write_error", str(e), "Verify --cache is writable.", code=3)

    diff_status = "new" if not prior_sha else ("unchanged" if prior_sha == sha else "changed")
    manifest = {
        "status": "success", "adapter": "congress", "identifier": identifier,
        "source_url": url.split('&api_key=')[0], "sha256": sha, "prior_sha256": prior_sha, "size": len(data),
        "diff_status": diff_status, "cache_path": str(content_path), "manifest_path": str(manifest_path),
        "citation": identifier, "fetched_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True), encoding="utf-8")
    emit(manifest, code=0)


if __name__ == "__main__":
    main()
