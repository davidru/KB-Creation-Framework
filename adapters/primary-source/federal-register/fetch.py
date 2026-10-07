#!/usr/bin/env python3
"""
fetch.py — Federal Register primary-source adapter (KB Creation Framework v3.1.13).

Fetches a Federal Register document by FR cite ("85 FR 12345"), document number
("2020-12345"), or docket ID from https://www.federalregister.gov/api/v1/.

USAGE
    python fetch.py --cite "85 FR 12345" --cache <dir>
    python fetch.py --document-number "2020-12345" --cache <dir>
    python fetch.py --docket-id "SEC-2020-001" --cache <dir>

OUTPUT (stdout, single JSON object) — same envelope shape as ecfr/fetch.py.

EXIT CODES: 0 success, 1 fetch, 2 parse, 3 cache write.

DEPENDENCIES: Python stdlib only.
"""
from __future__ import annotations
import argparse, datetime, hashlib, json, pathlib, re, sys
import urllib.error, urllib.request

FR_BASE = "https://www.federalregister.gov/api/v1"


def emit(payload: dict, code: int = 0) -> None:
    print(json.dumps(payload, indent=2, sort_keys=True)); sys.exit(code)


def emit_error(et: str, msg: str, rem: str, code: int = 1) -> None:
    emit({"status": "error", "adapter": "federal-register", "error_type": et, "error_message": msg, "remediation": rem}, code)


def parse_fr_cite(s: str) -> dict | None:
    m = re.match(r"^(\d+)\s+FR\s+(\d+)$", s.strip(), re.IGNORECASE)
    if m: return {"volume": int(m.group(1)), "page": int(m.group(2))}
    return None


def fetch_url(url: str, accept: str = "application/json") -> bytes:
    req = urllib.request.Request(url, headers={"Accept": accept, "User-Agent": "KB-Framework-v3.1.13/federal-register"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read()
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.reason}") from e
    except urllib.error.URLError as e:
        raise RuntimeError(f"URL error: {e.reason}") from e


def main() -> None:
    ap = argparse.ArgumentParser(description="Federal Register fetcher (v3.1.13)")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--cite", help="FR cite, e.g. '85 FR 12345'")
    g.add_argument("--document-number", help="FR document number, e.g. '2020-12345'")
    g.add_argument("--docket-id", help="Agency docket ID, e.g. 'SEC-2020-001'")
    ap.add_argument("--cache", required=True)
    args = ap.parse_args()

    cache_root = pathlib.Path(args.cache) / "federal-register"
    cache_root.mkdir(parents=True, exist_ok=True)

    if args.cite:
        parsed = parse_fr_cite(args.cite)
        if not parsed:
            emit_error("cite_parse_error", f"Unable to parse '{args.cite}'", "Use 'VOL FR PAGE' format like '85 FR 12345'.", code=2)
        # FR cite -> search for documents matching volume + page
        url = f"{FR_BASE}/documents.json?conditions[volume]={parsed['volume']}&conditions[page]={parsed['page']}&per_page=1"
        slug = f"fr-{parsed['volume']}-{parsed['page']}"
        identifier = args.cite
    elif args.document_number:
        url = f"{FR_BASE}/documents/{args.document_number}.json"
        slug = re.sub(r'[^a-zA-Z0-9-]', '-', args.document_number)
        identifier = args.document_number
    else:
        url = f"{FR_BASE}/documents.json?conditions[docket_id]={args.docket_id}&per_page=10"
        slug = re.sub(r'[^a-zA-Z0-9-]', '-', args.docket_id)
        identifier = args.docket_id

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
        if "HTTP 404" in m: emit_error("source_not_found", f"FR returned 404 for '{identifier}'", "Verify cite / document number / docket ID.")
        elif "HTTP 5" in m: emit_error("upstream_error", m, "Transient Federal Register upstream failure.")
        else: emit_error("fetch_error", m, "Network error.")

    sha = hashlib.sha256(data).hexdigest()
    try: content_path.write_bytes(data)
    except OSError as e: emit_error("cache_write_error", str(e), "Verify --cache is writable.", code=3)

    # Try to extract canonical citation from JSON
    citation = identifier
    try:
        j = json.loads(data)
        if isinstance(j, dict):
            if "citation" in j: citation = j["citation"]
            elif "results" in j and j["results"]: citation = j["results"][0].get("citation", identifier)
    except Exception: pass

    diff_status = "new" if not prior_sha else ("unchanged" if prior_sha == sha else "changed")
    manifest = {
        "status": "success", "adapter": "federal-register", "identifier": identifier,
        "source_url": url, "sha256": sha, "prior_sha256": prior_sha, "size": len(data),
        "diff_status": diff_status, "cache_path": str(content_path), "manifest_path": str(manifest_path),
        "citation": citation, "fetched_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True), encoding="utf-8")
    emit(manifest, code=0)


if __name__ == "__main__":
    main()
