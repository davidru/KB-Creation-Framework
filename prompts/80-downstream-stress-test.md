# Downstream Stress Test (Phase 8.0)

**Role:** KB v3 Lead invokes Memo Drafting Framework v1, then independent fact-checkers  
**Input:** Shipped KB candidate (`authority/`, `index.md`, `table-of-authorities.md`), scoping report, Phase 0.0 model assignment  
**Output:** `sources/stress_test_memos_index.md`, per-memo Memo Framework outputs, per-memo independent verification reports  
**Runs:** After Phase 7.0 final audit and Quality Scorecard generation; before Phase 8.5 adversarial red-team

---

## Overview

Phase 8.0 is the cooperative downstream-use test. It invokes the sibling Memo Drafting Framework v1 via its stable corpus contract (`..\Memo Drafting Framework v1\02-corpus-contract.md`). The old in-KB `15-grounded-memo-drafter.md` no longer exists here.

Default: run **3-6 memos**. The operator chooses the exact count within that range based on scoping report use cases. Single-memo stress testing is allowed only with explicit scoping opt-out and `pipeline_state.md` rationale.

---

## Corpus Contract Inputs

For each memo, provide the Memo Drafting Framework:

```yaml
source_corpus_path: <absolute path to a corpus packet directory containing authority\ plus index.md/table-of-authorities.md>
memo_topic: <natural-language question>
working_dir: <absolute path to [STATE_ROOT]\sources\stress-test\memo_N_label>
memo_label: stress_test_memo_N_<short_label>
model_assignment:
  step1_claim_extractor: <from Phase 0.0; choose a fact-check/extractor-capable model>
  step2_memo_writer: <from Phase 0.0; use memo writer assignment or Lead-selected writer>
  step4_qualifier_reviewer: <from Phase 0.0; independent if available>
qualifier_registry_path: <[STATE_ROOT]\qualifier-registry.md if present>
```

A corpus packet directory is a temporary or persistent directory prepared by the KB Lead for one memo run. It contains an `authority\` subdirectory and copies or stable pointers for `index.md`, `table-of-authorities.md`, and `qualifier-registry.md` if present. The KB Lead maps Phase 0.0 `model_assignment` into the memo contract and records the mapping in `sources/stress_test_memos_index.md`. Step 3 in the Memo Framework is mechanical and has no model assignment.

---

## Topic Selection — Multi-Memo Protocol

1. One memo per distinct use case in the scoping report, capped at 6.
2. Plus one high-risk memo for the most failure-prone advisory scenario.
3. Plus one user-specified memo if provided, still capped at 6 unless operator overrides.
4. Minimum: 3 memos for any KB with downstream work-product use.
5. Maximum: 6 memos unless the operator documents a broader stress-test rationale.

Maintain `sources/stress_test_memos_index.md`:

| Memo | Topic | Working dir | Claim extractor | Writer | Qualifier reviewer | Leakage | Reattribution | Qualifier | Independent fact-check | Status |
|---|---|---|---|---|---|---|---|---|---|---|

---

## Memo Framework Expected Outputs

For each memo, verify the framework produced:

| Output | Required? |
|---|---:|
| `<working_dir>\<memo_label>_claims.json` | Yes |
| `<working_dir>\<memo_label>.md` | Yes |
| `<working_dir>\<memo_label>_leakage.md` | Yes |
| `<working_dir>\<memo_label>_reattribution.md` | Yes |
| `<working_dir>\<memo_label>_qualifier.md` | Yes |
| `<working_dir>\<memo_label>_summary.json` | Yes |

Memo Framework success requires leakage = CLEAN, reattribution = CLEAN, and qualifier-preservation = PASS. Do not start independent web verification for a memo until its framework run passes.

---

## Independent Verification (per memo)

Use a fact-checker model from `model_assignment.memo_factcheck_8`, different from Phase 6.4. The fact-checker receives only:

- the memo;
- the memo claim map / claims manifest;
- web access.

No KB files. No builder drafts. No other memo reports.

Prompt:

```text
You are running an independent verification pass on a memo generated from a KB. You have the memo and its claim map only. You do NOT have access to the KB. Verify every factual claim against primary sources via web search. If the memo is wrong, identify the correct answer and source. If a claim is unsupported, say so.

OUTPUT:
| # | Claim | Claim Map # | Verdict | Correct Answer (if wrong) | Source URL |
|---|---|---|---|---|---|

Summary: claims checked, confirmed, errors found, unverifiable.
```

Save as `sources/stress_test_report_[N]_[short_label].md` or inside the memo working directory with a pointer from the index.

---

## Applying Results

When a memo or independent verification exposes an error:

1. Use the claim map to trace the error to the KB file/section.
2. Fix the KB source, not just the memo.
3. Re-run Phase 6.2, 6.3, 6.4, 6.5, and Phase 7.0 on edited material as applicable.
4. Re-run the affected memo through the Memo Drafting Framework end-to-end.
5. If the same KB section is flagged in 2+ memos, treat it as systemic and escalate to patch/rebuild.

---

## Decision Logic

| Result | Action |
|---|---|
| All Memo Framework runs pass and all independent fact-checks clean | Proceed to Phase 8.5 adversarial red-team. |
| Any memo framework output missing/non-clean | Fix KB or rerun framework step; do not proceed. |
| Any independent fact-check error | Fix KB, rerun affected phases and memo. |
| Same KB section flagged in 2+ memos | Systemic issue; patch/rebuild decision before ship. |

**Trigger:** After Phase 8.0 passes, dispatch `85-adversarial-red-team.md` immediately. Phase 8.0 alone is not the ship gate in v3.
