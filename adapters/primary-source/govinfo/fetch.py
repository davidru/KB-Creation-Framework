#!/usr/bin/env python3
"""
fetch.py — api.govinfo.gov primary-source adapter (KB Creation Framework v3.1.13).

Fetches Federal Register, U.S. Code, public laws via https://api.govinfo.gov.
REQUIRES env var GOVINFO_API_KEY (free from https://api.govinfo.gov/docs/).

USAGE
    python fetch.py --collection FR --package-id "FR-2020-12345" --cache <dir>
    python fetch.py --collection USCODE --year 2024 --title 15 --section 78j --cache <dir>
    python fetch.py --collection PLAW --congress 117 --law-number 103 --cache <dir>

OUTPUT: same envelope shape as other adapters.

EXIT CODES: 0 success, 1 fetch, 2 parse, 3 cache write, 5 missing API key.

DEPENDENCIES: Python stdlib only.
"""
from __future__ import annotations
import argparse, datetime, hashlib, json, os, pathlib, re, sys
import urllib.error, urllib.request

GOVINFO_BASE = "https://api.govinfo.gov"


def emit(payload: dict, code: int = 0) -> None:
    print(json.dumps(payload, indent=2, sort_keys=True)); sys.exit(code)


def emit_error(et: str, msg: str, rem: str, code: int = 1) -> None:
    emit({"status": "error", "adapter": "govinfo", "error_type": et, "error_message": msg, "remediation": rem}, code)


def fetch_url(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"Accept": "application/json", "User-Agent": "KB-Framework-v3.1.13/govinfo"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read()
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.reason}") from e
    except urllib.error.URLError as e:
        raise RuntimeError(f"URL error: {e.reason}") from e


def main() -> None:
    ap = argparse.ArgumentParser(description="api.govinfo.gov fetcher (v3.1.13)")
    ap.add_argument("--collection", required=True, choices=["FR", "USCODE", "PLAW", "BILLS", "STATUTE", "CFR"],
                    help="GovInfo collection code")
    ap.add_argument("--package-id", help="Direct package id (e.g. 'FR-2020-12345', 'PLAW-117publ103')")
    ap.add_argument("--year", type=int, help="Year for USCODE")
    ap.add_argument("--title", help="Title number for USCODE/CFR")
    ap.add_argument("--section", help="Section for USCODE")
    ap.add_argument("--congress", type=int, help="Congress number for PLAW")
    ap.add_argument("--law-number", type=int, help="Public law number for PLAW")
    ap.add_argument("--cache", required=True)
    args = ap.parse_args()

    api_key = os.environ.get("GOVINFO_API_KEY", "").strip()
    if not api_key:
        emit_error("missing_api_key",
                   "GOVINFO_API_KEY env var is not set.",
                   "Get a free key at https://api.govinfo.gov/docs/ and set with: [Environment]::SetEnvironmentVariable('GOVINFO_API_KEY', '<key>', 'User')",
                   code=5)

    cache_root = pathlib.Path(args.cache) / "govinfo"
    cache_root.mkdir(parents=True, exist_ok=True)

    # Resolve package_id from structured args if not provided directly
    if args.package_id:
        package_id = args.package_id
    elif args.collection == "PLAW" and args.congress and args.law_number:
        package_id = f"PLAW-{args.congress}publ{args.law_number}"
    elif args.collection == "USCODE" and args.year and args.title:
        package_id = f"USCODE-{args.year}-title{args.title}"
    else:
        emit_error("cite_parse_error",
                   "Must specify --package-id directly, OR enough structured args for the collection.",
                   "Examples: --package-id PLAW-117publ103, OR --collection PLAW --congress 117 --law-number 103.",
                   code=2)

    # Get the package summary first (small response with available formats)
    summary_url = f"{GOVINFO_BASE}/packages/{package_id}/summary?api_key={api_key}"
    slug = re.sub(r'[^a-zA-Z0-9-]', '-', package_id)

    content_path = cache_root / f"{slug}.json"
    manifest_path = cache_root / f"{slug}.manifest.json"
    prior_sha = None
    if manifest_path.exists():
        try: prior_sha = json.loads(manifest_path.read_text(encoding="utf-8")).get("sha256")
        except Exception: pass

    try:
        data = fetch_url(summary_url)
    except RuntimeError as e:
        m = str(e)
        if "HTTP 401" in m or "HTTP 403" in m: emit_error("auth_failure", m, "GOVINFO_API_KEY rejected. Regenerate at https://api.govinfo.gov/docs/.")
        elif "HTTP 404" in m: emit_error("source_not_found", f"GovInfo returned 404 for '{package_id}'", "Verify package id; check https://www.govinfo.gov/bulkdata for valid IDs.")
        elif "HTTP 429" in m: emit_error("rate_limit", m, "GovInfo rate limit hit. Wait or back off.")
        elif "HTTP 5" in m: emit_error("upstream_error", m, "Transient GovInfo failure.")
        else: emit_error("fetch_error", m, "Network error.")

    sha = hashlib.sha256(data).hexdigest()
    try: content_path.write_bytes(data)
    except OSError as e: emit_error("cache_write_error", str(e), "Verify --cache is writable.", code=3)

    citation = package_id
    try:
        j = json.loads(data)
        if isinstance(j, dict) and "title" in j: citation = j.get("title", package_id)
    except Exception: pass

    diff_status = "new" if not prior_sha else ("unchanged" if prior_sha == sha else "changed")
    manifest = {
        "status": "success", "adapter": "govinfo", "package_id": package_id, "collection": args.collection,
        "source_url": summary_url.split('?api_key=')[0], "sha256": sha, "prior_sha256": prior_sha, "size": len(data),
        "diff_status": diff_status, "cache_path": str(content_path), "manifest_path": str(manifest_path),
        "citation": citation, "fetched_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True), encoding="utf-8")
    emit(manifest, code=0)


if __name__ == "__main__":
    main()
