#!/usr/bin/env python3
"""
inspect-runner.py — Phase 7.0 test-set evaluator (KB Creation Framework v3.1.15).

Scores the assembled KB against a per-KB curated test set of 10-20 ground-truth
questions. Dual-mode:

  - LLM mode (when `inspect-ai` is installed + API key set): uses Inspect's
    Task/solver/scorer pattern. RAG-style solver retrieves from full/ topic files,
    LLM answers, scorer evaluates.

  - Fallback mode (no pip-install, no API key): deterministic scorers run
    directly against the concatenated full/ KB content. Skips model_graded
    questions (logs as N/A with explanation).

USAGE
    python inspect-runner.py \
        --test-set audit/test-set.yaml \
        --kb-root <kb-root> \
        [--mode auto|llm|fallback]

OUTPUT
    audit/test-set-results.json + audit/test-set-results.md
    Stdout: { status, mode, total, passed, failed, na, passage_rate,
              threshold_passage_rate, threshold_met, results_md, results_json }

EXIT CODES
    0 success, threshold met
    1 success, threshold NOT met (test-set passage rate below required)
    2 test-set file missing or schema-invalid
    3 KB full/ directory missing or empty
    4 LLM mode required but unavailable
"""
from __future__ import annotations
import argparse, datetime, json, os, pathlib, re, sys


# ============ YAML parsing (same minimal subset as Validate-PipelineState) ============
def parse_yaml_simple(text: str) -> dict:
    lines = []
    for raw in text.splitlines():
        stripped = raw; in_s, in_d = False, False
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
                last_key = list(top_cont.keys())[-1] if top_cont else None
                if not last_key: raise ValueError(f"List at indent {indent} but empty parent")
                if top_cont[last_key] is None: list_cont = []; top_cont[last_key] = list_cont
                elif isinstance(top_cont[last_key], list): list_cont = top_cont[last_key]
                else: raise ValueError(f"Parent key {last_key} has scalar")
                stack.append((indent, list_cont, 'list'))
            rest = content[2:]
            kv = re.match(r'^([^:]+?)\s*:\s*(.*)$', rest)
            if kv:
                item = {}; list_cont.append(item)
                stack.append((indent + 2, item, 'map'))
                _set(item, kv.group(1).strip(), kv.group(2))
            else:
                list_cont.append(_scalar(rest))
        else:
            top_ind, top_cont, top_kind = stack[-1]
            last_key = list(top_cont.keys())[-1] if top_cont else None
            if top_ind < indent and last_key and top_cont[last_key] is None:
                new_map = {}; top_cont[last_key] = new_map
                stack.append((indent, new_map, 'map'))
                top_ind, top_cont, top_kind = stack[-1]
            kv = re.match(r'^([^:]+?)\s*:\s*(.*)$', content)
            if not kv: raise ValueError(f"Cannot parse: {content}")
            _set(top_cont, kv.group(1).strip(), kv.group(2))
    return root


def _set(target: dict, key: str, rhs: str):
    if not rhs.strip(): target[key] = None
    elif rhs.strip().startswith('['): target[key] = _flow(rhs)
    else: target[key] = _scalar(rhs)


def _scalar(v: str):
    t = v.strip()
    if not t or t == '~' or t.lower() == 'null': return None
    low = t.lower()
    if low in ('true','yes','on'): return True
    if low in ('false','no','off'): return False
    if re.match(r'^-?\d+$', t): return int(t)
    if re.match(r'^-?\d+\.\d+$', t):
        try: return float(t)
        except ValueError: return t
    if len(t) >= 2 and ((t[0]=='"' and t[-1]=='"') or (t[0]=="'" and t[-1]=="'")):
        return t[1:-1]
    return t


def _flow(v: str) -> list:
    inner = v.strip().lstrip('[').rstrip(']')
    if not inner.strip(): return []
    parts = []; buf = ''; depth = 0; in_s = False; in_d = False
    for ch in inner:
        if ch == "'" and not in_d: in_s = not in_s; buf += ch
        elif ch == '"' and not in_s: in_d = not in_d; buf += ch
        elif not in_s and not in_d:
            if ch in '[{': depth += 1; buf += ch
            elif ch in ']}': depth -= 1; buf += ch
            elif ch == ',' and depth == 0: parts.append(_scalar(buf)); buf = ''
            else: buf += ch
        else: buf += ch
    if buf: parts.append(_scalar(buf))
    return parts


# ============ KB-content loader ============
def load_kb_content(kb_root: pathlib.Path) -> dict[str, str]:
    """Load all full/*.md content keyed by topic filename."""
    full_dir = kb_root / "full"
    if not full_dir.is_dir(): return {}
    content = {}
    for fp in full_dir.glob("*.md"):
        try: content[fp.name] = fp.read_text(encoding="utf-8", errors="replace")
        except Exception: pass
    return content


# ============ Scorers ============
def score_question(q: dict, kb_content: dict[str, str], mode: str, llm_runner=None) -> dict:
    """Returns {id, text, scorer, status: PASS|FAIL|NA|ERROR, score: 0..1, detail, matched_in}."""
    scorer = q.get("scorer", "")
    text = q.get("text", "")
    severity = q.get("severity", "medium")
    topic_hint = q.get("topic_hint")

    # Restrict to topic_hint if specified
    docs = {k: v for k, v in kb_content.items() if not topic_hint or topic_hint in k}
    if not docs and topic_hint:
        return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
                "status": "FAIL", "score": 0.0, "detail": f"No topic file matched topic_hint='{topic_hint}'", "matched_in": []}

    if scorer == "model_graded" and mode != "llm":
        return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
                "status": "NA", "score": None, "detail": "model_graded scorer requires LLM mode; skipped in fallback.", "matched_in": []}

    if scorer == "exact_match":
        expected = (q.get("expected_answer") or "").strip().lower()
        for name, body in docs.items():
            if expected and expected in body.strip().lower():
                return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
                        "status": "PASS", "score": 1.0, "detail": f"Exact match found", "matched_in": [name]}
        return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
                "status": "FAIL", "score": 0.0, "detail": f"Expected answer '{expected}' not found in any topic file", "matched_in": []}

    if scorer == "contains":
        expected = (q.get("expected_answer") or "").lower()
        for name, body in docs.items():
            if expected and expected in body.lower():
                return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
                        "status": "PASS", "score": 1.0, "detail": f"Substring found", "matched_in": [name]}
        return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
                "status": "FAIL", "score": 0.0, "detail": f"Expected substring not found", "matched_in": []}

    if scorer == "contains_all":
        keywords = [k.lower() for k in (q.get("keywords") or []) if k]
        if not keywords:
            return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
                    "status": "ERROR", "score": 0.0, "detail": "No keywords specified", "matched_in": []}
        for name, body in docs.items():
            b_lower = body.lower()
            if all(k in b_lower for k in keywords):
                return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
                        "status": "PASS", "score": 1.0, "detail": f"All {len(keywords)} keywords present", "matched_in": [name]}
        missing_by_topic = {}
        for name, body in docs.items():
            b_lower = body.lower()
            missing = [k for k in keywords if k not in b_lower]
            if len(missing) < len(keywords):
                missing_by_topic[name] = missing
        return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
                "status": "FAIL", "score": 0.0,
                "detail": f"No single topic contains all keywords. Closest gap: " + str(missing_by_topic) if missing_by_topic else "Keywords entirely absent",
                "matched_in": []}

    if scorer == "contains_any":
        keywords = [k.lower() for k in (q.get("keywords") or []) if k]
        for name, body in docs.items():
            b_lower = body.lower()
            matched = [k for k in keywords if k in b_lower]
            if matched:
                return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
                        "status": "PASS", "score": 1.0, "detail": f"Found keyword(s) {matched}", "matched_in": [name]}
        return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
                "status": "FAIL", "score": 0.0, "detail": "None of the keywords appear in any topic", "matched_in": []}

    if scorer == "cite_match":
        expected = (q.get("expected_cite") or "").strip()
        if not expected:
            return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
                    "status": "ERROR", "score": 0.0, "detail": "No expected_cite specified", "matched_in": []}
        # Normalize: lowercase, collapse whitespace + dots
        norm = re.sub(r"[\.\u00a0\s]+", " ", expected).strip().lower()
        for name, body in docs.items():
            body_norm = re.sub(r"[\.\u00a0\s]+", " ", body).lower()
            if norm in body_norm:
                return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
                        "status": "PASS", "score": 1.0, "detail": f"Cite '{expected}' found", "matched_in": [name]}
        return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
                "status": "FAIL", "score": 0.0, "detail": f"Expected cite '{expected}' not found", "matched_in": []}

    if scorer == "numeric_tolerance":
        expected_value = q.get("expected_value")
        tolerance = float(q.get("tolerance", 0) or 0)
        if expected_value is None:
            return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
                    "status": "ERROR", "score": 0.0, "detail": "No expected_value", "matched_in": []}
        expected_value = float(expected_value)
        # Find numeric values in topic files; PASS if any topic has a number within tolerance
        for name, body in docs.items():
            # Find numbers (with optional decimal); also handle written numbers loosely
            for num_match in re.finditer(r"\b(\d+(?:\.\d+)?)\b", body):
                val = float(num_match.group(1))
                if abs(val - expected_value) <= tolerance:
                    # Get context window for evidence
                    s = max(0, num_match.start() - 80); e = min(len(body), num_match.end() + 80)
                    return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
                            "status": "PASS", "score": 1.0,
                            "detail": f"Found value {val} within tolerance of {expected_value}. Context: ...{body[s:e].strip()}...",
                            "matched_in": [name]}
        return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
                "status": "FAIL", "score": 0.0,
                "detail": f"No numeric value within tolerance {tolerance} of {expected_value} found in any topic",
                "matched_in": []}

    if scorer == "model_graded" and mode == "llm":
        if not llm_runner:
            return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
                    "status": "ERROR", "score": 0.0, "detail": "LLM runner not initialized", "matched_in": []}
        return llm_runner(q, docs)

    return {"id": q.get("id"), "text": text, "scorer": scorer, "severity": severity,
            "status": "ERROR", "score": 0.0, "detail": f"Unknown scorer '{scorer}'", "matched_in": []}


# ============ LLM-mode runner (Inspect-based; lazily imported) ============
def make_llm_runner(solver_config: dict | None):
    """Returns a function that scores a model_graded question by invoking the LLM."""
    try:
        from inspect_ai.model import get_model
    except ImportError:
        return None
    if not solver_config:
        return None
    llm_cfg = solver_config.get("llm", {}) or {}
    provider = llm_cfg.get("provider", "openrouter")
    api_key_env = {"openrouter": "OPENROUTER_API_KEY", "openai": "OPENAI_API_KEY", "anthropic": "ANTHROPIC_API_KEY"}.get(provider)
    if not api_key_env or not os.environ.get(api_key_env): return None
    model_name = llm_cfg.get("model")
    try:
        model = get_model(model_name) if model_name else get_model()
    except Exception:
        return None

    async def _run(q: dict, docs: dict[str, str]) -> dict:
        # Concatenate first ~10KB of each topic as KB context
        kb_context = "\n\n---\n\n".join(f"## {name}\n{body[:4000]}" for name, body in docs.items())
        prompt = (
            f"You are evaluating a knowledge base. Question: {q['text']}\n\n"
            f"Use ONLY the following KB content to answer:\n\n{kb_context[:30000]}\n\n"
            f"Rubric (PASS/FAIL): {q.get('rubric','')}\n\n"
            "Output strictly in this format on two lines:\n"
            "VERDICT: PASS or FAIL\n"
            "REASONING: <one sentence>"
        )
        try:
            from inspect_ai.model import ChatMessageUser
            resp = await model.generate(input=[ChatMessageUser(content=prompt)])
            text = resp.choices[0].message.content if resp.choices else ""
            text = text if isinstance(text, str) else str(text)
            verdict = "PASS" if re.search(r"VERDICT\s*:\s*PASS", text, re.IGNORECASE) else "FAIL"
            return {"id": q["id"], "text": q["text"], "scorer": "model_graded", "severity": q.get("severity","medium"),
                    "status": verdict, "score": 1.0 if verdict == "PASS" else 0.0,
                    "detail": text[:300], "matched_in": list(docs.keys())[:3]}
        except Exception as e:
            return {"id": q["id"], "text": q["text"], "scorer": "model_graded", "severity": q.get("severity","medium"),
                    "status": "ERROR", "score": 0.0, "detail": f"LLM grading failed: {e}", "matched_in": []}

    def sync_wrap(q, docs):
        import asyncio
        return asyncio.run(_run(q, docs))
    return sync_wrap


# ============ Main ============
def main() -> None:
    ap = argparse.ArgumentParser(description="Inspect test-set runner (v3.1.15)")
    ap.add_argument("--test-set", required=True, help="Path to audit/test-set.yaml")
    ap.add_argument("--kb-root", required=True)
    ap.add_argument("--mode", choices=["auto","llm","fallback"], default="auto")
    args = ap.parse_args()

    ts_path = pathlib.Path(args.test_set)
    kb_root = pathlib.Path(args.kb_root)

    if not ts_path.is_file():
        print(json.dumps({"status": "error", "error_type": "test_set_missing",
                          "error_message": f"test-set not found at '{ts_path}'",
                          "remediation": "Create audit/test-set.yaml with 10-20 questions; see examples/test-set.example.yaml."}))
        sys.exit(2)
    try:
        ts = parse_yaml_simple(ts_path.read_text(encoding="utf-8"))
    except Exception as e:
        print(json.dumps({"status": "error", "error_type": "yaml_parse",
                          "error_message": f"test-set parse failed: {e}",
                          "remediation": "Validate against audit-templates/test-set.schema.json."}))
        sys.exit(2)

    questions = ts.get("questions", [])
    if not questions:
        print(json.dumps({"status": "error", "error_type": "no_questions",
                          "error_message": "test-set contains no questions",
                          "remediation": "Add at least 1 question; recommend 10-20 per KB."}))
        sys.exit(2)

    threshold = (ts.get("threshold") or {}).get("passage_rate", 0.80) or 0.80
    per_question_severity = (ts.get("threshold") or {}).get("per_question_severity", "medium")
    solver_cfg = ts.get("solver") or {}

    kb_content = load_kb_content(kb_root)
    if not kb_content:
        print(json.dumps({"status": "error", "error_type": "kb_empty",
                          "error_message": f"No .md files found in {kb_root}/full/",
                          "remediation": "Run Phase 6.0 Lead Assembly first to produce full/."}))
        sys.exit(3)

    mode = args.mode
    if mode == "auto":
        try:
            import inspect_ai  # noqa: F401
            mode = "llm" if any(os.environ.get(e) for e in ("OPENROUTER_API_KEY","OPENAI_API_KEY","ANTHROPIC_API_KEY")) else "fallback"
        except ImportError:
            mode = "fallback"

    llm_runner = None
    if mode == "llm":
        llm_runner = make_llm_runner(solver_cfg)
        if not llm_runner:
            # Fall back gracefully — Inspect or model unavailable
            mode = "fallback"

    results = [score_question(q, kb_content, mode, llm_runner) for q in questions]
    total = len(results)
    passed = sum(1 for r in results if r["status"] == "PASS")
    failed = sum(1 for r in results if r["status"] == "FAIL")
    errored = sum(1 for r in results if r["status"] == "ERROR")
    na = sum(1 for r in results if r["status"] == "NA")
    scored = max(1, total - na - errored)
    passage_rate = passed / scored
    threshold_met = passage_rate >= threshold

    # Blocker check
    blocker_failed = any(r["status"] == "FAIL" and r.get("severity") == "blocker" for r in results)
    if per_question_severity == "blocker" and blocker_failed:
        threshold_met = False

    # Write outputs
    audit_dir = kb_root / "audit"; audit_dir.mkdir(parents=True, exist_ok=True)
    md_path = audit_dir / "test-set-results.md"
    json_path = audit_dir / "test-set-results.json"

    lines = [
        "# Phase 7.0 — Test-Set Evaluation Results",
        f"Generated: {datetime.datetime.now(datetime.timezone.utc).isoformat()}",
        f"Test-set: {ts_path}",
        f"Mode: **{mode}**",
        "",
        "## Summary",
        f"- Total questions: {total}",
        f"- PASS: {passed}",
        f"- FAIL: {failed}",
        f"- ERROR: {errored}",
        f"- N/A (skipped): {na}",
        f"- Passage rate (passed / scored): **{passage_rate:.1%}** (threshold: {threshold:.0%})",
        f"- Threshold met: **{'YES' if threshold_met else 'NO'}**",
    ]
    if blocker_failed:
        lines.append(f"- ⚠️ **BLOCKER FAILURES**: {sum(1 for r in results if r['status']=='FAIL' and r.get('severity')=='blocker')} blocker-severity question(s) failed.")
    lines += ["",
        "## Per-question results",
        "",
        "| ID | Severity | Scorer | Status | Question |",
        "|---|---|---|---|---|"]
    for r in results:
        status_marker = {"PASS":"✅","FAIL":"❌","ERROR":"⚠️","NA":"–"}.get(r["status"], "?")
        lines.append(f"| `{r.get('id')}` | {r.get('severity','-')} | {r.get('scorer','-')} | {status_marker} {r['status']} | {r.get('text','')[:120].replace('|','\\|')} |")
    lines += ["", "## Details (FAIL + ERROR only)", ""]
    for r in results:
        if r["status"] not in ("FAIL","ERROR"): continue
        lines.append(f"### `{r.get('id')}` — {r['status']}")
        lines.append(f"- Question: {r.get('text')}")
        lines.append(f"- Scorer: {r.get('scorer')}")
        lines.append(f"- Severity: {r.get('severity')}")
        lines.append(f"- Detail: {r.get('detail','')}")
        lines.append("")
    md_path.write_text("\n".join(lines), encoding="utf-8")
    json_path.write_text(json.dumps({
        "mode": mode, "total": total, "passed": passed, "failed": failed, "errored": errored, "na": na,
        "passage_rate": passage_rate, "threshold_passage_rate": threshold, "threshold_met": threshold_met,
        "blocker_failed": blocker_failed, "results": results
    }, indent=2), encoding="utf-8")

    print(json.dumps({
        "status": "ok", "mode": mode, "total": total, "passed": passed, "failed": failed, "errored": errored, "na": na,
        "passage_rate": passage_rate, "threshold_passage_rate": threshold, "threshold_met": threshold_met,
        "blocker_failed": blocker_failed,
        "results_md": str(md_path), "results_json": str(json_path)
    }, indent=2))
    sys.exit(0 if threshold_met else 1)


if __name__ == "__main__":
    main()
