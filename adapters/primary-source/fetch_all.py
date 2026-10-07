#!/usr/bin/env python3
"""
fetch_all.py — Multi-source fetch + drift detection orchestrator (v3.1.13).

Reads sources/source-registry.yaml and invokes the appropriate adapter for each
entry. Used by Phase 1.1 (pre-fetch) and Phase 6.3 (drift detection).

USAGE
    python fetch_all.py --registry <path-to-source-registry.yaml> \
                        --cache <cache-dir> \
                        --kb-root <kb-root> \
                        [--drift-report-only]

OUTPUT
    Writes per-source manifest files to <cache>/<adapter>/<slug>.manifest.json
    (each adapter handles its own caching).
    Writes sources/source_drift_report.md summarizing diff_status across all sources
    (always, unless --no-report). Foundational-criticality changes flagged at top.
    Prints summary JSON to stdout: { total, new, unchanged, changed, errored, drift_blocking }

EXIT CODES
    0 success (no foundational drift)
    1 success but foundational source drifted (operator review required)
    2 schema-invalid registry
    3 adapter invocation error
"""
from __future__ import annotations
import argparse, datetime, json, pathlib, subprocess, sys
import re


def parse_yaml_simple(text: str) -> dict:
    """Tiny YAML subset parser sufficient for source-registry.yaml.
    Same approach as v3.1.11 Validate-PipelineState.ps1: nested maps via indent,
    list items with '-', inline flow lists, scalars."""
    lines = []
    for raw in text.splitlines():
        # Strip comments
        stripped = raw
        in_s, in_d = False, False
        for i, ch in enumerate(raw):
            if ch == "'" and not in_d: in_s = not in_s
            elif ch == '"' and not in_s: in_d = not in_d
            elif ch == '#' and not in_s and not in_d:
                stripped = raw[:i].rstrip(); break
        if not stripped.strip(): continue
        indent = len(stripped) - len(stripped.lstrip(' '))
        content = stripped.lstrip(' ')
        kind = 'list' if content.startswith('- ') else 'map'
        lines.append((indent, content, kind))

    root = {}
    stack = [(-1, root, 'map')]
    for indent, content, kind in lines:
        while len(stack) > 1:
            top_ind, top_cont, top_kind = stack[-1]
            if top_ind > indent: stack.pop(); continue
            if top_ind == indent:
                if top_kind == 'list' and kind == 'list': break
                if top_kind == 'map' and kind == 'map': break
                stack.pop(); continue
            break

        if kind == 'list':
            top_ind, top_cont, top_kind = stack[-1]
            if top_kind == 'list' and top_ind == indent:
                list_cont = top_cont
            else:
                if top_kind != 'map':
                    raise ValueError(f"List item at indent {indent} has no map parent")
                last_key = list(top_cont.keys())[-1] if top_cont else None
                if not last_key: raise ValueError(f"List at indent {indent} but empty parent")
                if top_cont[last_key] is None:
                    list_cont = []; top_cont[last_key] = list_cont
                elif isinstance(top_cont[last_key], list):
                    list_cont = top_cont[last_key]
                else:
                    raise ValueError(f"Parent key {last_key} has scalar; cannot host list")
                stack.append((indent, list_cont, 'list'))
            rest = content[2:]
            kv = re.match(r'^([^:]+?)\s*:\s*(.*)$', rest)
            if kv:
                item = {}
                list_cont.append(item)
                stack.append((indent + 2, item, 'map'))
                key, rhs = kv.group(1).strip(), kv.group(2)
                _set_value(item, key, rhs)
            else:
                list_cont.append(_parse_scalar(rest))
        else:
            top_ind, top_cont, top_kind = stack[-1]
            if top_kind != 'map':
                raise ValueError(f"Map entry at indent {indent} but top is list")
            last_key = list(top_cont.keys())[-1] if top_cont else None
            if top_ind < indent and last_key and top_cont[last_key] is None:
                new_map = {}; top_cont[last_key] = new_map
                stack.append((indent, new_map, 'map'))
                top_ind, top_cont, top_kind = stack[-1]
            kv = re.match(r'^([^:]+?)\s*:\s*(.*)$', content)
            if not kv: raise ValueError(f"Cannot parse map entry: {content}")
            key, rhs = kv.group(1).strip(), kv.group(2)
            _set_value(top_cont, key, rhs)
    return root


def _set_value(target: dict, key: str, rhs: str) -> None:
    if not rhs.strip():
        target[key] = None
    elif rhs.strip().startswith('['):
        target[key] = _parse_flow_list(rhs)
    else:
        target[key] = _parse_scalar(rhs)


def _parse_scalar(v: str):
    t = v.strip()
    if not t or t == '~' or t.lower() == 'null': return None
    low = t.lower()
    if low in ('true','yes','on'): return True
    if low in ('false','no','off'): return False
    if re.match(r'^-?\d+$', t): return int(t)
    # Strip quotes
    if len(t) >= 2 and ((t[0] == '"' and t[-1] == '"') or (t[0] == "'" and t[-1] == "'")):
        return t[1:-1]
    return t


def _parse_flow_list(v: str) -> list:
    inner = v.strip().lstrip('[').rstrip(']')
    if not inner.strip(): return []
    parts = []
    buf = ''
    depth = 0
    in_s, in_d = False, False
    for ch in inner:
        if ch == "'" and not in_d: in_s = not in_s; buf += ch
        elif ch == '"' and not in_s: in_d = not in_d; buf += ch
        elif not in_s and not in_d:
            if ch in '[{': depth += 1; buf += ch
            elif ch in ']}': depth -= 1; buf += ch
            elif ch == ',' and depth == 0:
                parts.append(_parse_scalar(buf)); buf = ''
            else: buf += ch
        else: buf += ch
    if buf: parts.append(_parse_scalar(buf))
    return parts


def main() -> None:
    ap = argparse.ArgumentParser(description="Multi-source fetch + drift detection")
    ap.add_argument("--registry", required=True, help="Path to source-registry.yaml")
    ap.add_argument("--cache", required=True, help="Cache directory root")
    ap.add_argument("--kb-root", required=True, help="KB root (for writing source_drift_report.md)")
    ap.add_argument("--drift-report-only", action="store_true",
                    help="Don't fetch; just read existing manifests and write drift report (assumes Phase 1.1 already ran)")
    ap.add_argument("--no-report", action="store_true", help="Skip writing source_drift_report.md")
    args = ap.parse_args()

    registry_path = pathlib.Path(args.registry)
    if not registry_path.is_file():
        print(json.dumps({"status": "error", "error_type": "registry_not_found",
                          "error_message": f"source-registry.yaml not found at '{registry_path}'",
                          "remediation": "Operator must create sources/source-registry.yaml before Phase 1.1. See examples/source-registry.example.yaml."}, indent=2))
        sys.exit(2)

    try:
        registry = parse_yaml_simple(registry_path.read_text(encoding="utf-8"))
    except Exception as e:
        print(json.dumps({"status": "error", "error_type": "yaml_parse",
                          "error_message": f"Cannot parse source-registry.yaml: {e}",
                          "remediation": "Validate against audit-templates/source-registry.schema.json."}, indent=2))
        sys.exit(2)

    adapter_dir = pathlib.Path(__file__).parent
    cache = pathlib.Path(args.cache); cache.mkdir(parents=True, exist_ok=True)
    sources = registry.get("sources", [])

    results = []
    counts = {"total": len(sources), "new": 0, "unchanged": 0, "changed": 0, "errored": 0, "drift_blocking": 0}

    for source in sources:
        sid = source.get("id", "<unnamed>")
        adapter = source.get("adapter", "")
        ref = source.get("ref", {}) or {}
        criticality = source.get("criticality", "supporting")
        adapter_script = adapter_dir / adapter / "fetch.py"
        if not adapter_script.is_file():
            results.append({"id": sid, "adapter": adapter, "status": "error",
                            "error_type": "unknown_adapter",
                            "error_message": f"Adapter '{adapter}' not found at {adapter_script}",
                            "remediation": "Check spelling; valid adapters: ecfr, federal-register, congress, govinfo."})
            counts["errored"] += 1
            continue

        if args.drift_report_only:
            # Read existing manifest from cache instead of re-fetching
            adapter_cache = cache / adapter
            manifests = sorted(adapter_cache.glob(f"*.manifest.json")) if adapter_cache.is_dir() else []
            if not manifests:
                results.append({"id": sid, "adapter": adapter, "status": "skipped",
                                "reason": "no_prior_manifest", "criticality": criticality})
                continue
            # Just take the most recent
            latest = max(manifests, key=lambda p: p.stat().st_mtime)
            try:
                m = json.loads(latest.read_text(encoding="utf-8"))
                results.append({**m, "id": sid, "criticality": criticality})
                counts[m.get("diff_status", "errored")] = counts.get(m.get("diff_status", "errored"), 0) + 1
            except Exception as e:
                results.append({"id": sid, "adapter": adapter, "status": "error", "error_type": "manifest_read",
                                "error_message": str(e), "criticality": criticality})
                counts["errored"] += 1
            continue

        # Build args for the adapter
        adapter_args = [sys.executable, str(adapter_script), "--cache", str(cache)]
        if adapter == "ecfr":
            adapter_args += ["--cite", ref.get("cite_string", "")]
            if ref.get("as_of"): adapter_args += ["--as-of", ref["as_of"]]
        elif adapter == "federal-register":
            if ref.get("cite_string"): adapter_args += ["--cite", ref["cite_string"]]
            elif ref.get("document_number"): adapter_args += ["--document-number", ref["document_number"]]
            elif ref.get("docket_id"): adapter_args += ["--docket-id", ref["docket_id"]]
        elif adapter == "congress":
            if ref.get("public_law"): adapter_args += ["--public-law", ref["public_law"]]
            elif ref.get("congress") and ref.get("bill_type") and ref.get("bill_number"):
                adapter_args += ["--congress", str(ref["congress"]), "--bill-type", ref["bill_type"], "--bill-number", str(ref["bill_number"])]
        elif adapter == "govinfo":
            adapter_args += ["--collection", ref.get("collection", "")]
            if ref.get("package_id"): adapter_args += ["--package-id", ref["package_id"]]
            if ref.get("year"): adapter_args += ["--year", str(ref["year"])]
            if ref.get("title"): adapter_args += ["--title", str(ref["title"])]
            if ref.get("section"): adapter_args += ["--section", str(ref["section"])]
            if ref.get("congress"): adapter_args += ["--congress", str(ref["congress"])]
            if ref.get("law_number"): adapter_args += ["--law-number", str(ref["law_number"])]

        try:
            proc = subprocess.run(adapter_args, capture_output=True, text=True, timeout=60)
            try: m = json.loads(proc.stdout)
            except Exception: m = {"status": "error", "error_type": "adapter_output_parse",
                                   "error_message": "Adapter did not emit valid JSON",
                                   "raw_stdout": proc.stdout[:500], "raw_stderr": proc.stderr[:500]}
            m["id"] = sid; m["criticality"] = criticality
            results.append(m)
            if m.get("status") == "success":
                counts[m.get("diff_status", "unknown")] = counts.get(m.get("diff_status", "unknown"), 0) + 1
                if m.get("diff_status") == "changed" and criticality == "foundational":
                    counts["drift_blocking"] += 1
            else:
                counts["errored"] += 1
        except subprocess.TimeoutExpired:
            results.append({"id": sid, "adapter": adapter, "status": "error", "error_type": "timeout",
                            "error_message": "Adapter timed out (60s)", "criticality": criticality})
            counts["errored"] += 1

    # Write drift report
    if not args.no_report:
        kb_root = pathlib.Path(args.kb_root)
        sources_dir = kb_root / "sources"; sources_dir.mkdir(parents=True, exist_ok=True)
        report_path = sources_dir / "source_drift_report.md"
        lines = ["# Source Drift Report",
                 f"Generated: {datetime.datetime.now(datetime.timezone.utc).isoformat()}",
                 f"Registry: {args.registry}",
                 f"Cache: {args.cache}",
                 "", "## Summary",
                 f"- Total sources watched: {counts['total']}",
                 f"- New (first fetch): {counts['new']}",
                 f"- Unchanged: {counts['unchanged']}",
                 f"- Changed: {counts['changed']}",
                 f"- Errored: {counts['errored']}",
                 f"- **Drift blocking (foundational + changed): {counts['drift_blocking']}**",
                 ""]
        if counts["drift_blocking"] > 0:
            lines += ["## ⚠️ BLOCKING DRIFT", "",
                      "The following foundational sources have changed since prior fetch.",
                      "The KB was drafted against an older version. Operator review required before proceeding.", ""]
            for r in results:
                if r.get("status") == "success" and r.get("diff_status") == "changed" and r.get("criticality") == "foundational":
                    lines.append(f"- **{r.get('id')}** ({r.get('adapter')}): {r.get('citation', r.get('source_url',''))}")
                    lines.append(f"  - Prior SHA: `{(r.get('prior_sha256') or '')[:12]}` → Current SHA: `{(r.get('sha256') or '')[:12]}`")
                    lines.append(f"  - Cache: `{r.get('cache_path')}`")
            lines.append("")
        lines += ["## All sources", "",
                  "| ID | Adapter | Criticality | Status | Diff | SHA (12) | Citation |",
                  "|---|---|---|---|---|---|---|"]
        for r in results:
            lines.append("| {} | {} | {} | {} | {} | `{}` | {} |".format(
                r.get("id", ""), r.get("adapter", ""), r.get("criticality", ""),
                r.get("status", ""), r.get("diff_status", ""),
                (r.get("sha256") or "")[:12],
                (r.get("citation") or r.get("identifier") or r.get("error_type") or "").replace("|", "\\|")[:80]))
        report_path.write_text("\n".join(lines), encoding="utf-8")

    print(json.dumps({"status": "success", "counts": counts,
                      "drift_report": str(kb_root / "sources" / "source_drift_report.md") if not args.no_report else None,
                      "results": results}, indent=2))
    sys.exit(1 if counts["drift_blocking"] > 0 else 0)


if __name__ == "__main__":
    main()
