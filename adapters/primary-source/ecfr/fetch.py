#!/usr/bin/env python3
"""
fetch.py — eCFR primary-source adapter (KB Creation Framework v3.1.13).

Fetches a CFR section / part / title from https://www.ecfr.gov/api/versioner/v1/
and writes content-addressed cache + manifest JSON for downstream framework use.

USAGE
    python fetch.py --cite "17 CFR 240.10b-5" --cache <dir> [--as-of YYYY-MM-DD]

OUTPUT (stdout, single JSON object)
    {
        "status": "success" | "error",
        "adapter": "ecfr",
        "cite_string": "17 CFR 240.10b-5",
        "title": 17, "part": "240", "section": "10b-5",
        "as_of": "2026-06-08",
        "source_url": "...",
        "sha256": "abc...", "size": 1234,
        "diff_status": "new" | "unchanged" | "changed",
        "cache_path": "<dir>/ecfr/...",
        "manifest_path": "<dir>/ecfr/...manifest.json",
        "citation": "...",
        "fetched_at": "2026-06-08T..."
    }
    On error: status=error + error_type + error_message + remediation.

EXIT CODES
    0 success, 1 fetch error, 2 parse / cite error, 3 cache write error.

DEPENDENCIES
    Python stdlib only (urllib.request, json, hashlib, re, pathlib, argparse).
"""
from __future__ import annotations
import argparse
import datetime
import hashlib
import json
import pathlib
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

ECFR_BASE = "https://www.ecfr.gov/api/versioner/v1"


def emit(payload: dict, code: int = 0) -> None:
    print(json.dumps(payload, indent=2, sort_keys=True))
    sys.exit(code)


def emit_error(error_type: str, message: str, remediation: str, code: int = 1) -> None:
    emit(
        {
            "status": "error",
            "adapter": "ecfr",
            "error_type": error_type,
            "error_message": message,
            "remediation": remediation,
        },
        code,
    )


def parse_cite(cite_string: str) -> dict:
    """Accept '17 CFR 240.10b-5' or '17 CFR Part 240' or '17 CFR 240'. Returns dict."""
    text = cite_string.strip()
    m_section = re.match(r"^(\d+)\s+CFR\s+(\d+(?:\.\w+)?(?:-\w+)?)$", text, re.IGNORECASE)
    m_section_with_subdash = re.match(
        r"^(\d+)\s+CFR\s+(\d+)\.(\w+(?:-\w+)?)$", text, re.IGNORECASE
    )
    m_part = re.match(r"^(\d+)\s+CFR\s+Part\s+(\d+)$", text, re.IGNORECASE)
    m_title = re.match(r"^(\d+)\s+CFR$", text, re.IGNORECASE)

    if m_section_with_subdash:
        return {"title": int(m_section_with_subdash.group(1)),
                "part": m_section_with_subdash.group(2),
                "section": m_section_with_subdash.group(3),
                "kind": "section"}
    if m_part:
        return {"title": int(m_part.group(1)), "part": m_part.group(2), "kind": "part"}
    if m_title:
        return {"title": int(m_title.group(1)), "kind": "title"}
    if m_section:
        # Ambiguous: "17 CFR 240" — treat as part
        return {"title": int(m_section.group(1)), "part": m_section.group(2), "kind": "part"}
    return {}


def fetch_url(url: str, accept: str = "text/xml") -> tuple[bytes, str]:
    req = urllib.request.Request(url, headers={"Accept": accept, "User-Agent": "KB-Framework-v3.1.13/ecfr"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = resp.read()
            content_type = resp.headers.get("Content-Type", "application/octet-stream")
            return data, content_type
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.reason}") from e
    except urllib.error.URLError as e:
        raise RuntimeError(f"URL error: {e.reason}") from e


def build_ecfr_url(parsed: dict, as_of: str) -> tuple[str, str]:
    """Returns (xml_url, source_citation_url). The XML endpoint returns content; citation URL is human-readable."""
    title = parsed["title"]
    base = f"{ECFR_BASE}/full/{as_of}/title-{title}.xml"
    if parsed["kind"] == "section":
        # eCFR uses query params for part + section filtering
        url = f"{base}?part={parsed['part']}&section={parsed['part']}.{parsed['section']}"
        citation_url = f"https://www.ecfr.gov/current/title-{title}/chapter-/part-{parsed['part']}/section-{parsed['part']}.{parsed['section']}"
    elif parsed["kind"] == "part":
        url = f"{base}?part={parsed['part']}"
        citation_url = f"https://www.ecfr.gov/current/title-{title}/chapter-/part-{parsed['part']}"
    else:
        url = base
        citation_url = f"https://www.ecfr.gov/current/title-{title}"
    return url, citation_url


def get_latest_available_date(title: int) -> str | None:
    """Query eCFR titles endpoint to discover the latest indexed date for a title."""
    url = f"{ECFR_BASE}/titles.json"
    try:
        data, _ = fetch_url(url, accept="application/json")
        titles = json.loads(data).get("titles", [])
        for t in titles:
            if t.get("number") == title:
                return t.get("up_to_date_as_of") or t.get("latest_amended_on")
    except Exception:
        return None
    return None


def main() -> None:
    ap = argparse.ArgumentParser(description="eCFR fetcher (v3.1.13)")
    ap.add_argument("--cite", required=True, help="CFR cite string, e.g. '17 CFR 240.10b-5'")
    ap.add_argument("--cache", required=True, help="Cache directory root")
    ap.add_argument("--as-of", default=None,
                    help="Effective date YYYY-MM-DD (default: today)")
    args = ap.parse_args()

    parsed = parse_cite(args.cite)
    if not parsed:
        emit_error(
            "cite_parse_error",
            f"Unable to parse cite string '{args.cite}'",
            "Use formats like '17 CFR 240.10b-5', '17 CFR Part 240', '17 CFR 240', or '17 CFR'.",
            code=2,
        )

    as_of = args.as_of or datetime.date.today().isoformat()

    cache_root = pathlib.Path(args.cache) / "ecfr"
    cache_root.mkdir(parents=True, exist_ok=True)
    slug = re.sub(r"[^a-z0-9]+", "-", args.cite.lower()).strip("-")

    url, citation_url = build_ecfr_url(parsed, as_of)

    try:
        data, content_type = fetch_url(url)
    except RuntimeError as e:
        msg = str(e)
        if "HTTP 404" in msg and args.as_of is None:
            # Auto-fallback: today's date isn't indexed yet; try the latest available date for this title.
            fallback_date = get_latest_available_date(parsed["title"])
            if fallback_date and fallback_date != as_of:
                as_of = fallback_date
                url, citation_url = build_ecfr_url(parsed, as_of)
                try:
                    data, content_type = fetch_url(url)
                except RuntimeError as e2:
                    emit_error("source_not_found",
                               f"eCFR returned error for '{args.cite}' even on fallback date {as_of}: {e2}",
                               "Verify cite string is current; the title or section may have been removed.")
            else:
                emit_error("source_not_found",
                           f"eCFR returned 404 for '{args.cite}' as of {as_of} and no fallback date available.",
                           "Verify cite string is current; eCFR may not yet have indexed the requested as_of date. Try an explicit --as-of YYYY-MM-DD.")
        elif "HTTP 404" in msg:
            emit_error("source_not_found",
                       f"eCFR returned 404 for '{args.cite}' as of {as_of}",
                       "Verify cite string is current; the requested as_of date may not be indexed. Omit --as-of to auto-discover latest available.")
        elif "HTTP 5" in msg:
            emit_error("upstream_error", msg, "Transient eCFR upstream failure; retry shortly.")
        else:
            emit_error("fetch_error", msg, "Network error or invalid URL.")

    # Compute paths + prior hash AFTER URL/as_of resolution (post-fallback)
    content_path = cache_root / f"{slug}.{as_of}.xml"
    manifest_path = cache_root / f"{slug}.{as_of}.manifest.json"
    prior_sha = None
    if manifest_path.exists():
        try:
            with manifest_path.open("r", encoding="utf-8") as f:
                prior_sha = json.load(f).get("sha256")
        except Exception:
            prior_sha = None

    sha = hashlib.sha256(data).hexdigest()

    try:
        content_path.write_bytes(data)
    except OSError as e:
        emit_error("cache_write_error", str(e), "Verify --cache directory is writable.", code=3)

    diff_status = "new"
    if prior_sha:
        diff_status = "unchanged" if prior_sha == sha else "changed"

    fetched_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
    manifest = {
        "status": "success",
        "adapter": "ecfr",
        "cite_string": args.cite,
        "title": parsed.get("title"),
        "part": parsed.get("part"),
        "section": parsed.get("section"),
        "kind": parsed["kind"],
        "as_of": as_of,
        "source_url": url,
        "citation_url": citation_url,
        "content_type": content_type,
        "sha256": sha,
        "prior_sha256": prior_sha,
        "size": len(data),
        "diff_status": diff_status,
        "cache_path": str(content_path),
        "manifest_path": str(manifest_path),
        "citation": f"{args.cite} (eCFR as of {as_of})",
        "fetched_at": fetched_at,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True), encoding="utf-8")
    emit(manifest, code=0)


if __name__ == "__main__":
    main()
