# Critical Review: KB Creation Framework (Modular)

**Subject:** `<framework-root>`
**Date:** 2026-04-27
**Scope:** Full read of all 7 root modules (`01-shared-axioms.md` through `07-audit-system.md`), `HOW-TO-USE.md`, both PowerShell scripts (`Extract-AuthorityView.ps1`, `Register-Lint.ps1`), and all 22 prompt files in `prompts\`.

---

## Executive Summary

The framework is architecturally serious and substantively addresses the prior fabrication-incident class of failure (Lesson 32, the dual-view KB with `authority/` extraction, and the multi-stage rubber-duck critiques). The biggest correctness risks are not in the high-level architecture but in **handoff contracts between stages** — specifically, several places where the prompt that consumes an artifact requires a field that the prompt that produces it does not actually generate, and several places where honest source-uncertainty markers (`[UNVERIFIED]`, `[VOLATILE:*]`) can be silently stripped during assembly with no audit trail. There is also a **structural coverage gap** in the fabrication-defense system: when both builders independently pattern-match the same illustrative entity name from shared training data, the comparison stage classifies this as "agreement" and routes it to lower scrutiny, which is exactly the wrong direction. Five issues are flagged as high-stakes (directly produce bad deliverables); the rest are structural integrity, operational friction, and concrete contract mismatches. Several stages are well-designed and should not be touched.

---

## Part 1 — Highest-Stakes Findings (Direct Deliverable-Quality Risk)

### 1. The fabricated-institutional-fact protection has a structural coverage hole

Lesson 32 and the `authority/` extraction are the right response to the prior incident. The three-guardrail system (sourced, framed as illustrative, lives in `[GUIDANCE]`) plus authority-stripping is sound for the case where a **single** builder generates a firm name without the other.

**Coverage gap:** If Builder A and Builder B independently produce the same firm names — likely for well-known firms in a specialty area, because both models trained on the same trade press and rankings — Phase 4's comparison report classifies this as "agreement." Agreement-classified claims receive **lower** scrutiny in Phase 5 (general-claim spot-check) versus single-source claims (Phase 5d, primary-source required). A fabricated firm name appearing in both builders because both pattern-match from training data to the same Chambers/Legal 500 lists passes Phase 5d entirely and flows into `full/` with a sourced-sounding citation generated from memory.[^1]

**Second hole:** `Register-Lint.ps1` scans only `full/*.md`. `AGENTS.md`, `index.md`, and `table-of-authorities.md` live at the KB root and are never register-linted or authority-extracted. Phase 14's stress test (`14-downstream-stress-test.md` Step A) attaches these root files directly to the drafter's context — bypassing the authority filter entirely.[^2]

**Fix:** Phase 4's comparison prompt should add a category — "Both builders name the same real-world entities as examples: flag ALL such agreements for Phase 5b citation verification regardless of agreement status, because agreement between models on illustrative entity names is not independent corroboration — it is shared training-data recall." Mirror in `09-factcheck-citations.md`. Run `Register-Lint.ps1` against root markdown files in addition to `full/`, or add an explicit constraint to `11-lead-assembly.md` prohibiting illustrative entity examples and guidance-register content in root files.

### 2. `[UNVERIFIED]` tags are stripped at assembly with no audit trail

`03-builder-draft.md`: "Mark unverifiable claims with `[UNVERIFIED]`." `11-lead-assembly.md`: "No `[UNVERIFIED]` tags in final output — resolve or remove." The pipeline has no verification that resolution actually happened; it only sees the tag is gone.[^3]

Under context pressure during a large assembly, the assembler can drop the `[UNVERIFIED]` tag and keep the claim — converting an honest uncertainty marker into an untagged assertion. This is the exact contamination chain for the prior incident.

**Fix:** Assembly prompt needs a third option — escalate to a `sources/unresolved_unverified.md` manifest (required output) with a `[UNVERIFIED-AT-ASSEMBLY]` marker for mandatory Phase 6b Priority 1 treatment. Phase 6b currently only knows about claims **added** during assembly (via the new claims manifest), not unverified claims that **survived** from builders.

### 3. Phase 5a verifies currency but not proposition accuracy — Lesson 24 not closed

`08-factcheck-currency.md` asks: Is the statute still in force? Has the CFR section been amended? Is the case still good law? It does **not** ask: Does the specific subsection cited contain what the KB claims? Does the KB's paraphrase preserve the operative trigger?[^4]

Lesson 24: "Paraphrasing statutory provisions can lose the operative trigger. 'Applies to X' is wrong if the text says 'applies to Y with commentary extending to X.'" Phase 5b is closer but its template (`| Citation | Exists? | Correct? | Says what claimed? |`) treats "says what claimed" as binary, not as textual comparison of paraphrase vs. operative hook.

**For a legal KB feeding client advice, a current-but-mischaracterized statute is more dangerous than a repealed statute** — the latter gets caught in 5a; the former passes both 5a and 5b.

**Fix:** Add a sixth check to 5a: pull the actual text of the cited subsection and compare the KB's characterization against the operative hook verbatim. Flag any paraphrase that omits, narrows, or extends the trigger. Same place to add RFC number verification (currently absent everywhere) for technology KBs.

### 4. Phase 4 comparison prompt does not produce the inventory Phase 5d requires

`07-lead-comparison.md` asks for: Agreements, Disputes, Unique Content, Fabrication Check, Backbone Recommendation. Full prompt.

`01-orchestrator.md` says: "The comparison report MUST include the single-source claim inventory required by 03-builder.md Section 3.2 (Lesson 30). Phase 5d depends on this inventory."

`09a-factcheck-single-source.md` says: "If the inventory is missing any of these fields, STOP and report the gap before proceeding."

The comparison prompt **never asks for it as a distinct, formatted artifact.**[^5] "Unique Content" is coverage-gap analysis (one builder covered a topic the other missed). The single-source inventory is **claim-level**: specific factual assertions, dates, dollar amounts, citations, entity names that appear in only one builder. A topic uniquely covered by Builder A might contain 20 specific factual claims, all needing 5d treatment.

**Result:** Phase 5d either has no input or relies on the fact-checker constructing it from builder drafts — which Phase 4 independence rules prohibit (see finding #8).

**Fix:** Add to `07-lead-comparison.md` a required Section 6 that produces a `| Claim | Originating Builder | v2 Draft Location |` table. One-sentence prompt addition; closes a gap that breaks Phase 5d on every build.

### 5. `[VOLATILE:*]` tags are not preserved at assembly

`03-builder-draft.md` requires builders to tag volatile claims with `[VOLATILE:type]` markers. `06-refresh-orchestrator.md` scans for these markers to drive staleness scans. **`11-lead-assembly.md` says nothing about preserving them.**[^6]

If the assembler paraphrases a sentence containing `[VOLATILE:market-data]`, the tag disappears. The Refresh Orchestrator then finds no volatile tags and skips the verification, defeating the entire staleness-detection system.

**Fix:** Add VOLATILE tag preservation to the assembly prompt's rules list and to the Assembly Completion Checklist. "Do not paraphrase away a volatile-tagged claim without also transferring the tag to the revised phrasing."

---

## Part 2 — Architecture Coherence

### 6. Phase numbering is incoherent and creates operational risk

`01-shared-axioms.md` Rule 17 lists phases as: "0, 0.5, 1a, 1a.5, 1b, 1.5, 2a, 2b, 3, 3.5, 4, 5, 5a, 5b, 5c, 5d, 6, 6.25, **11c**, 6c, 6a, 6b, 6.5, 7, 8."[^7]

Phase 11c (register lint) physically executes between Phase 6.25 and Phase 6c but retains its old "11c" name from when it was associated with assembly. The list also includes "Phase 5" with no corresponding stage — there are only 5a–5d. The pipeline checklist is the operational heartbeat; cosmetic confusion here causes real mis-sequencing.

**Fix:** Renumber 11c → 6.25a; remove phantom "Phase 5"; update all cross-references in `HOW-TO-USE.md`, `00-README.md`, orchestrator.

### 7. Module duplication with diverging size targets

Three authoritative sources, three different per-topic file size targets:

| Source | Per-Topic Target |
|---|---|
| `03-builder.md` Section 5.2 | 18-30KB |
| `01-shared-axioms.md` Section 6 | 18-30KB |
| `11-lead-assembly.md` | 35-45KB |
| `05-build-orchestrator.md` Phase 6.5 (A-TIER) | ≥35KB average |

An operator reading only `03-builder.md` builds to 30KB and passes the local size gate while failing the orchestrator's A-TIER threshold.[^8]

**Fix:** Reconcile to 35-45KB (the production-validated number; "3x larger builder draft" is empirical). 18-30KB is a v1.x artifact.

### 8. Fact-Checker contradicts itself on builder-draft access

`04-fact-checker.md` Section 6, Rule 2: "Never read builder drafts."
`04-fact-checker.md` Section 1, Priority 1a: "If the comparison report does not include a single-source inventory, the Fact-Checker should construct one by comparing the builder drafts in `sources/`."[^9]

Directly contradictory. Independence is violated whenever Phase 4 fails to produce the inventory (i.e., always — see finding #4).

**Fix:** Delete the fallback. Replace with: "If the inventory is missing, STOP and require the Lead to re-run Phase 4." Enforces fix #4; removes self-contradiction.

### 9. Claim list curation for Phase 5a/5b/5c is an undocumented manual step

The Phase 5 prompts say `[Paste the list of statutes...]` and `[Paste the complete list of citations from both v2 drafts]`. **Nothing in any prompt instructs an agent to extract these lists.**[^10] In practice the fact-check agents receive full v2 draft text and self-curate — meaning the fact-checker decides what to verify rather than the framework specifying it.

**Fix:** Add Phase 4.5: Claim Extraction. Lead extracts a manifest from both v2 drafts (citations, dollar amounts, dates, entity names, status claims). This feeds 5a/5b/5c/5d.

### 10. Phase 7 and Phase 6.5 have no execution prompts

Phase 7 (Mode 2 audit, 25-claim spot-check) and Phase 6.5 (quality tier audit + deepening) are described in the orchestrator but have **no dedicated prompt files**. Operators improvise at the phases with the highest cost consequences. Deepening is described as "re-run 03 for gaps" but `03-builder-draft.md` is designed for fresh drafting, not deepening assembled files.[^11]

**Fix:** Add `15-quality-tier-audit.md` (deepening logic distinct from Phase 1b) and `16-audit.md` (Mode 2 spot-check prompt).

---

## Part 3 — Audience Scoping

### 11. Topic structure requirements don't force operational coverage

`02-info-gather.md` Section 2.2 lists for Legal Topic KBs: regulatory landscape, key statutes, leading cases, compliance frameworks, emerging issues, cross-references. **All doctrinal.**[^12]

A practitioner advising a client on day one needs operational mechanics (forms, deadlines, procedural steps), the compliance tail (ongoing obligations), edge cases, and failure modes (what happens if you miss a deadline). These are absent. The scoping rubber-duck (00a) tests against the stated use case but not against an operational checklist.

The downstream stress test (Phase 8) verifies factual accuracy of memos drafted from the KB but not operational completeness. A KB with strong doctrinal coverage and no day-one mechanics produces a good-sounding but operationally incomplete memo, and Step B's fact-checker won't catch the omission.

**Fix:** Add a fourth required element to 02-info-gather.md Section 2.2: "Operational mechanics — for each compliance framework, what are the specific procedural steps, forms, deadlines, and filing requirements? If 'it depends,' enumerate the dependencies." Add a corresponding test to 00a SCOPE BOUNDARIES.

---

## Part 4 — Rubber-Duck Stages

### 12. Substantively designed; one positioning gap

The three stages (00a scoping, 02a topics, 11b assembly) are correctly positioned and substantive. A/B/C classification (auto-apply / escalate / acknowledge) is well-designed. Model-family independence is explicit. **Not ceremonial.**

**Positioning gap:** Phase 6.25 (assembly critique) includes Register/Tone as Test 4. Phase 11c (register lint) runs after, mechanically. Sequence is correct (qualitative before mechanical), but the critic isn't told to stay out of the lint scanner's lane. The critic flags individual untagged paragraphs that the lint catches anyway (duplicate work) — or declares "register tagging is consistent" qualitatively, giving false confidence before the lint runs.[^13]

**Fix:** Add to `11b-rubber-duck-assembly.md` Test 4: "Evaluate overall tagging strategy and systematic failures (e.g., 'Key Takeaways sections are systematically untagged'). Do not enumerate individual untagged paragraphs — that is the lint script's job. Surface patterns; let the script find instances."

---

## Part 5 — Assembly and Downstream Usability

### 13. `Extract-AuthorityView.ps1` has a block-continuation bug for inline tag placement

When the script encounters `<!-- [GUIDANCE] -->` on its own line, it sets `$inStrippedBlock = $true` and skips through the next blank line / heading / `---`. Standard pattern handled correctly.

**Bug:** If a builder produces the tag mid-line (`This is guidance. <!-- [GUIDANCE] --> More guidance text.`), the inline handler strips only the tag markers, **keeps the text**, and never enters block-stripping mode. Guidance content flows into `authority/` stripped of its tags, undetected.[^14]

**Fix:** Require leading-line placement. Add to builder draft prompt and assembly prompt: "Register tags must appear on their own line as the first line of the paragraph they tag." Add a pre-extraction check to `11a` that scans for tags appearing after non-whitespace on the same line.

### 14. Phase 6a filename fixes should trigger Phase 6c regeneration — prompt doesn't say so

`12-filename-validation.md` Part 2 says "FIX all broken references in-place." Editing `full/` files triggers Phase 6c regeneration per `01-shared-axioms.md` Section 9 Rule 3 — but the validation prompt doesn't include the reminder. The prompt runs, fixes links, reports PASS, and `authority/` is now stale with no flag.[^15]

**Fix:** Add a closing block: "If any cross-references were fixed in `full/` files: `authority/` is now stale. Re-run `Extract-AuthorityView.ps1` before proceeding to Phase 6b."

### 15. Stress-test Step B prompt uses single-memo filename — multi-memo upgrade incomplete

`14-downstream-stress-test.md` Step B template: `MEMO: [paste sources/stress_test_memo.md]` — singular. The multi-memo protocol (default 3-6 memos) uses indexed filenames `stress_test_memo_1_[label].md` through `_N_`. Step B template was carried over from the single-memo design.[^16]

**Fix:** Update to `MEMO: [paste sources/stress_test_memo_[N]_[LABEL].md]` with reminder that each Step B runs in a separate session verifying only its paired memo.

---

## Part 6 — Operational Friction

### 16. Pipeline requires ~50-70+ model sessions per build

A 14-topic KB end-to-end: ~28 per-topic drafting sessions per builder × 2 builders, plus reviews, comparisons, fact-checks, assembly, validation = 50-70+ sessions. A 3-5 KB portfolio refresh: 150-350 sessions. The "no silent skipping" rule adds user gates at each decision point.[^17]

This is the correct tradeoff (a fabricated firm name in a client memo is much more expensive than 70 sessions), but the friction creates real pressure to cut corners. The framework doesn't help operators identify which stages have the highest marginal risk reduction.

**Fix:** Add a Risk-Ranked Phase Criticality Table to `HOW-TO-USE.md`:

| Phase | Non-Negotiable? | Consequence of Skip |
|---|---|---|
| 5d single-source | Yes | Highest fabrication risk undetected |
| 6b SUPERSET | Yes | Assembly-generated content unverified |
| 00a scoping critique | Yes | Scope errors compound at every phase |
| 3.5 compliance diff | Recommended | Review items silently dropped |
| 2a/2b structural/depth | Yes (can merge) | Weak sections unidentified |

### 17. Stages that can be merged without quality loss

| Merge | Rationale | Sessions Saved |
|---|---|---|
| 2a + 2b (structural + depth review) | Same Lead, same builder draft, same session — parallelism is decomposition-for-attention, not multi-model independence | 4 per build |
| 6.25 + 11c (assembly critique + register lint) | Run lint first, give report to critic with the assembled KB; critic evaluates strategy with specific flagged paragraphs in hand | 1 per build |
| 6c + 6a (authority extraction + filename validation) | Independent post-assembly checks; no cross-dependency | 1 per build |

Total: ~7-9 sessions saved per build with no quality gate lost.

---

## Part 7 — Specific Contract Mismatches and Bugs

### 18. `03-builder.md` calls assembly "Phase 4+5"; orchestrator calls it Phase 6
Within-module phase numbering (Builder module's local Phase 4/5) collides with pipeline-global numbering (Phase 6). Operator reading `03-builder.md` for assembly guidance must reconcile.[^18]

### 19. Phase 6b's "no sub-agent delegation" is physically incompatible with "verify EVERY claim" in a 500KB+ KB
`13-post-assembly-factcheck.md`: "Do NOT delegate or decompose into sub-tasks or sub-agents" + "Verify EVERY citation and factual claim." For a 500KB KB with thousands of claims, these are incompatible in a single session. The fact-checker silently processes what fits and stops, with no flag.[^19]

**Fix:** Modify constraint: "Do not decompose into PARALLEL sub-agents using different verification standards. If claim volume exceeds single-session capacity, decompose SEQUENTIALLY by file — one sub-agent per `full/` file, same prompt, same standards. Sub-agents must not share context."

### 20. Cost table in `05-build-orchestrator.md` references Sonnet 4.5 (deprecated)
Section 6: "Phase 1A | Sonnet 4.5 | $3-5." Shared Axioms Section 4 says Builder B is Sonnet 4.6. Stale.[^20]

### 21. Phase 5d dependency on comparison report not met by comparison prompt
Already covered in finding #4. Listed here as the concrete contract mismatch: orchestrator says 5d depends on the inventory; Phase 4 prompt doesn't produce it. Broken handoff on every build.

### 22. `Register-Lint.ps1` "should" verb coverage is incomplete
Signal list includes "should consider/evaluate/assess/review/identify" but **not**: "should ensure/include/maintain/document/establish/verify/confirm/obtain." Action-imperative guidance is exactly the register-blurring pattern Lesson 27 identified.[^21]

**Fix:** Expand `$signals` to include `'should (ensure|include|maintain|document|establish|verify|confirm|obtain|notify|retain|monitor)'`. Add `'\bcounsel should\b'`, `'\bpractitioners should\b'`, `'\bclients should\b'`.

---

## Prioritized Action List

### Fix immediately (directly produce bad deliverables)
1. Add formatted single-source claim inventory to Phase 4 comparison prompt → fixes broken Phase 5d input contract (#4)
2. Add `[VOLATILE:*]` tag preservation to assembly prompt → prevents staleness detection from silently failing (#5)
3. Resolve `[UNVERIFIED]`-at-assembly false-confidence problem with mandatory escalation manifest (#2)
4. Extend register lint scope to root files OR prohibit guidance-register content there (#1)
5. Add Phase 5a check for KB characterization vs. statutory operative hook — not just currency (#3)

### Fix soon (structural integrity)
6. Resolve `04-fact-checker.md` self-contradiction on builder-draft access (#8)
7. Delete Priority 1a fallback from Fact-Checker (paired with #4)
8. Add VOLATILE tag preservation to Assembly Completion Checklist (paired with #5)
9. Add Phase 6c re-run reminder to Phase 6a filename validation prompt (#14)
10. Fix Step B stress-test prompt to use indexed memo filenames (#15)
11. Expand `Register-Lint.ps1` "should" verb coverage (#22)
12. Renumber Phase 11c → 6.25a; remove phantom "Phase 5" (#6)

### Fix at next revision cycle
13. Reconcile per-topic size targets across `03-builder.md`, Shared Axioms §6, `11-lead-assembly.md` (#7)
14. Add Phase 4.5 claim-extraction step (#9)
15. Add dedicated prompts for Phase 6.5 (quality tier audit/deepening) and Phase 7 (audit) (#10)
16. Merge Phase 2a+2b into single prompt; optionally merge 6c+6a (#17)
17. Add operational mechanics as required element for legal topic KBs (#11)
18. Add Risk-Ranked Phase Criticality Table to `HOW-TO-USE.md` (#16)
19. Fix `Extract-AuthorityView.ps1` mid-paragraph tag edge case + leading-line requirement (#13)

---

## What's Genuinely Well-Designed (Don't Touch)

- **Three-tier rubber-duck critique structure** with auto-apply / escalate / acknowledge — substantive and correctly positioned. Don't add more rubber-duck passes; critique fatigue is a real risk.
- **`authority/` extraction architecture (dual-view KB)** — the right structural response to the contamination chain. Tag discipline and script are sound for the standard use case (the inline-tag bug in finding #13 is a defect of the standard, not a flaw in the architecture).
- **Phase 5d (single-source verification)** with primary-source-required + 3-query minimum — correctly designed and positioned.
- **Lesson 32's three-guardrail system for illustrative entity examples** — right policy. The gap (#1) is coverage, not design.
- **Correction Application Verification Gate** in Refresh Orchestrator §2.5 — directly closes Pattern 12 (Correction Decay). One of the strongest additions in the framework.
- **Assembly Completion Checklist** (mandatory print-before-declaring-done) — addresses the Employment Immigration KB incident cleanly.

---

## Confidence Assessment

| Finding Type | Confidence | Basis |
|---|---|---|
| Contract mismatches between prompts (#4, #5, #8, #9, #14, #15, #18, #21) | High | Direct cross-reference between prompt texts; the conflict is on the page |
| Strip-on-assembly defects (#2, #5) | High | Assembly prompt explicitly removes tags with no escalation path |
| Coverage gap in fabrication defense (#1) | High | Independent corroboration assumption is theoretically sound but training-data correlation breaks it; the Phase 4/5d pipeline routes accordingly |
| Currency-vs-accuracy gap in 5a (#3) | High | 5a prompt enumerates currency checks, omits paraphrase-vs-operative-hook check; Lesson 24 names this exact failure |
| Phase numbering / size target inconsistencies (#6, #7) | High | Direct comparison of values across files |
| Authority extraction bug (#13) | Medium-High | Inferred from script logic; would benefit from a unit test confirming the inline-tag case |
| Register lint coverage (#22) | High | Direct read of `$signals` array vs. common legal imperatives |
| Operational sessions estimate (#16) | Medium | Estimated from per-phase session counts; not measured against actual builds |
| Stage-merge candidates (#17) | Medium-High | Argued from independence requirements and resource ownership; final merge decisions depend on operator preference |
| "Well-designed" findings | High | Reflect substantive structural choices that match stated risks |

The review did not run any prompts end-to-end; findings are based on static analysis of the prompts, scripts, and orchestrator specifications.

---

## Footnotes

[^1]: `prompts\07-lead-comparison.md` (Phase 4 comparison prompt — produces Agreements / Disputes / Unique Content / Fabrication Check / Backbone Recommendation, no entity-agreement-as-shared-recall flag); `prompts\09a-factcheck-single-source.md` (Phase 5d input contract requires single-source inventory; "agreement" claims routed to general spot-check instead).

[^2]: `Register-Lint.ps1` (path scope is `full\*.md`); `prompts\14-downstream-stress-test.md` Step A (root-file attachments include `AGENTS.md`, `index.md`, `table-of-authorities.md`); `prompts\11-lead-assembly.md` (no constraint on guidance-register content in root files).

[^3]: `prompts\03-builder-draft.md` (instruction to mark `[UNVERIFIED]`); `prompts\11-lead-assembly.md` ("No [UNVERIFIED] tags in final output — resolve or remove" with no third option for unresolved-but-survived claims; no `unresolved_unverified.md` required output); `prompts\13-post-assembly-factcheck.md` (Phase 6b new-claims manifest scope does not include surviving builder `[UNVERIFIED]` claims).

[^4]: `prompts\08-factcheck-currency.md` (currency checks enumerated; no paraphrase-vs-operative-hook check); `prompts\09-factcheck-citations.md` ("Says what claimed?" treated as binary in output template); `01-shared-axioms.md` Lesson 24 (paraphrasing-loses-trigger failure mode).

[^5]: `prompts\07-lead-comparison.md` (full prompt has no Section 6 / single-source inventory); `01-orchestrator.md` ("comparison report MUST include the single-source claim inventory"); `prompts\09a-factcheck-single-source.md` ("If the inventory is missing any of these fields, STOP"); `03-builder.md` Section 3.2 (defines the inventory but doesn't say who produces it at Phase 4).

[^6]: `prompts\03-builder-draft.md` (`[VOLATILE:type]` markers required); `06-refresh-orchestrator.md` (consumes VOLATILE markers for staleness scans); `prompts\11-lead-assembly.md` (rules cover YAML / `[GUIDANCE]` / `[INTERPRETATION]` / `[NEW]` — VOLATILE absent); Assembly Completion Checklist in same file (no VOLATILE preservation gate).

[^7]: `01-shared-axioms.md` Rule 17 (verbatim phase list including `11c` mid-sequence and standalone `5`).

[^8]: `03-builder.md` Section 5.2 (18-30KB per topic); `01-shared-axioms.md` Section 6 (18-30KB); `prompts\11-lead-assembly.md` (35-45KB; "A-tier KBs average 40KB+ per topic file"; "at least 3x the larger builder draft"); `05-build-orchestrator.md` Phase 6.5 (A-TIER ≥ 35KB).

[^9]: `04-fact-checker.md` Section 6 Rule 2 ("Never read builder drafts"); `04-fact-checker.md` Section 1 Priority 1a (instruction to construct inventory by reading `sources/` builder drafts when comparison report is incomplete).

[^10]: `prompts\08-factcheck-currency.md`, `prompts\09-factcheck-citations.md`, `prompts\10-factcheck-classification.md` (all use `[Paste the list of...]` placeholders); no upstream prompt assigns the extraction step.

[^11]: `01-orchestrator.md` (Phase 7 references `04-fact-checker.md` Mode 2; no `16-audit.md` exists in `prompts\`); `05-build-orchestrator.md` Phase 6.5 (deepening described as "re-run 03 for gaps"; `prompts\03-builder-draft.md` is fresh-drafting only, no deepening mode).

[^12]: `02-info-gather.md` Section 2.2 (required elements for Legal Topic KBs — all doctrinal); `prompts\00a-rubber-duck-scoping.md` (SCOPE BOUNDARIES test against stated use case, not operational checklist).

[^13]: `prompts\11b-rubber-duck-assembly.md` Test 4 (Register and Tone — no instruction to stay out of paragraph-level enumeration); `Register-Lint.ps1` (handles paragraph-level enumeration mechanically).

[^14]: `Extract-AuthorityView.ps1` (block detection sets `$inStrippedBlock = $true` only when tag is on its own line; inline regex `<!--\s*\[(GUIDANCE|INTERPRETATION)\]\s*-->\s*` strips markers but keeps adjacent text and never enters block-stripping mode).

[^15]: `prompts\12-filename-validation.md` Part 2 (instruction to fix references in-place; no Phase 6c regeneration reminder); `01-shared-axioms.md` Section 9 Rule 3 (any edit to `full/` requires `authority/` regeneration); `prompts\11a-authority-view-extraction.md` Step 5 (regeneration trigger).

[^16]: `prompts\14-downstream-stress-test.md` Step B (template: `MEMO: [paste sources/stress_test_memo.md]`); same file's multi-memo protocol uses `stress_test_memo_1_[label].md` through `_N_`.

[^17]: Estimated from `01-orchestrator.md` per-phase session counts and `05-build-orchestrator.md` Phase 1A parallel batch sizing for a 14-topic KB; not measured against an actual build.

[^18]: `03-builder.md` Section 1 pipeline diagram (Phase 1 → 2 → 3 → 4 → 5 with assembly = Phase 5); `01-orchestrator.md` (assembly = Phase 6).

[^19]: `prompts\13-post-assembly-factcheck.md` (execution constraint "Do NOT delegate or decompose" + scope "Verify EVERY citation and factual claim"; no overflow handling).

[^20]: `05-build-orchestrator.md` Section 6 (Phase 1A | Sonnet 4.5); `01-shared-axioms.md` Section 4 (Builder B = Sonnet 4.6).

[^21]: `Register-Lint.ps1` (`$signals` array — "should consider/evaluate/assess/review/identify" present; ensure/include/maintain/document/establish/verify/confirm/obtain absent); `01-shared-axioms.md` Lesson 27 (action-imperative guidance is the register-blurring pattern).
