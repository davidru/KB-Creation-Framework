# adapters/evaluator/ — Inspect Test-Set Runner (v3.1.15 — SCAFFOLDED, NOT YET IMPLEMENTED)

**Status:** v3.1.15 SCAFFOLD ONLY. The Python implementation lands in a follow-up session after operator approval at Gate 2.

## What this will be (v3.1.15 scope)

A Python adapter that uses [Inspect](https://github.com/UKGovernmentBEIS/inspect_ai) (UK AI Safety Institute's open-source evaluation framework) to score the assembled KB against a per-KB curated test set.

### Architecture
- Operator curates `audit/test-set.yaml` per KB with 10-20 ground-truth questions
- Phase 7.0 (Final Audit) dispatches `inspect-runner.py` against the assembled `full/` files
- Inspect's `Task` + `solver` + `scorer` pattern evaluates each question; scorers: exact-match, contains-all/any, semantic-similarity, cite-string-match, numeric-tolerance, model-graded
- Writes `audit/test-set-results.json` + `audit/test-set-results.md`
- `Generate-QualityScorecard.ps1` reads the JSON and adds 8th dimension "Test-set passage rate" with operator-configurable threshold (default 80%)
- A KB cannot reach PASS verdict unless test-set passage rate meets threshold (configurable per-KB; N/A for KBs without a test set)

### Cross-family discipline
The test-set evaluator LLM family declared in `test-set.yaml` MUST differ from KB build Builder A + Builder B + Phase 6.4 fact-checker families. `inspect-runner.py` validates against `sources/pipeline_state.yaml` at startup; refuses to run with same-family.

## Files this directory will contain (when implemented)

- `inspect-runner.py` — main Python entrypoint
- `inspect-runner.ps1` — PowerShell wrapper
- `requirements.txt` — pinned versions of inspect-ai + LLM client libraries
- `README.md` — this file (will be expanded)

## test-set.yaml schema (planned)

Schema file: `audit-templates/test-set.schema.json` (also v3.1.15)
Example: `examples/test-set.example.yaml`

```yaml
version: 1.0
kb_root: <auto-filled>
threshold:
  passage_rate: 0.80
  per_question_severity: medium
solver:
  type: rag
  llm:
    provider: openrouter
    model: anthropic/claude-opus-4.8
    family: anthropic   # MUST differ from Builder A/B + Phase 6.4 families
questions:
  - id: q1
    text: "What is the day-count for vigilance reporting under MDR Article 87?"
    expected_answer: "15 days for serious incidents..."
    scorer: contains_all
    keywords: ["15 days", "2 days", "10 days"]
  - id: q2
    text: "Cite the EU regulation governing IVDs."
    expected_cite: "Regulation (EU) 2017/746"
    scorer: cite_match
  ...
```

## Why scaffolded but not implemented

Per operator-approved plan (2026-06-08): v3.1.15 implementation requires Gate 2 approval after v3.1.14 ships. This directory exists with documentation so the next session can pick up immediately without re-planning. The CHANGELOG entry [3.1.15] in the framework root documents the planned scope.

## Operator setup (when implemented)

- Python 3.12 (already in bootstrap)
- `pip install -r requirements.txt` (inspect-ai + LLM client)
- Per-KB: curate `audit/test-set.yaml` with 10-20 ground-truth questions BEFORE Phase 0.0; can iterate during build
- LLM provider API key for the evaluator model (different family from KB build models)

## Reference

- Inspect: https://github.com/UKGovernmentBEIS/inspect_ai
- Plan: `~/.copilot/session-state/2aa57d9f-4496-4e79-bc21-1eb4a51fa1c5/plan.md` § v3.1.15
