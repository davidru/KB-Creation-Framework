# Builder Module — KB Creation Framework
# Version: 1.0 | Created: 2026-04-09
# Scope: Builds knowledge bases from a scoping report. Multi-model pipeline with quality gates.
# Dependencies: Reads 01-shared-axioms.md for voice, principles, error patterns, model profiles.
# Input: A scoping_report.md from the Info Gather module (or equivalent human-provided scope).
# Output: Assembled KB files ready for Fact-Checker verification.
# Independence: Does not read the Fact-Checker module. Does not verify its own claims.

---

## PURPOSE

This module takes a scoping report and produces a complete knowledge base through a multi-model build pipeline. It handles:

- Dual-builder draft generation
- Lead review and dispute resolution
- Builder revision
- Assembly into individual topic files
- Deepening to meet size gates

It does NOT fact-check its own output. That's the Fact-Checker's job. The Builder's job is to produce the most comprehensive, well-structured draft it can, using web search during construction to minimize errors — but the Fact-Checker has final authority on accuracy.

---

## GROUNDING DISCIPLINE (applies to every Phase that fetches primary sources)

Before any builder, fact-checker, or assembly agent fetches a primary source from the web, it must:

1. **Consult the host registry** at `../host-registry.md`. If the host is listed, use the recorded minimum tier as the first attempt. Do not start with a lower tier — that is wasted work for hosts whose protections are already known.
2. **Validate fetch shape, not just HTTP status.** A 200 response with non-empty body is NOT sufficient. Reject and escalate when any of the content-shape validators in `host-registry.md` fires (TOC-only shell, SPA shell, Cloudflare challenge page, Turnstile widget, legacy IUAM stub, or empty regulator portal page).
3. **Escalate tiers on validator hit.** Walk up the Primary-Source Access Fallback Chain (Tier 0 API → 1 web_search/Wayback → 2 curl_cffi → 2.5 cloudscraper → 3 Playwright → 4 Camoufox → 5 patchright → 6 Scrapling) per the rule in `~/.copilot/copilot-instructions.md`. Do not give up at Tier 2 because "the fetch returned content."
4. **Log every escalation** in `sources/pipeline_state.md` with host, attempted tier, failure mode, successful tier. After a successful escalation, **append the discovery to `../host-registry.md`** so the next build inherits the working tier (see registry's "Feedback loop").
5. **Tag fetched material with Tier A/Tier B classification** per `../tier-a-b-classification.md` and the scoping report's per-topic Tier-A density designation. Tier A material that cannot be closed at the verbatim level remains `[NEEDS-FETCH][TIER-A]` and **blocks Phase 6.0 assembly / Phase 6.5 quality-tier closure** (see `05-build-orchestrator.md`).

The honest-flagging discipline ("if you can't verify it, flag it as `[NEEDS-FETCH]`") remains. What changes is that Tier-A flags now gate the build instead of being deferred.

---

## SECTION 1: PIPELINE OVERVIEW

```
Phase 1.1 ─► Phase 1.2 ─► Phase 1.3 ─► Phase 2.0 ─► Phase 3.0 ─► Phase 4.0
Research      Topic Critic   Drafts        Lead Review   Revision      Compare + inventory
(parallel)                  (parallel)                  (parallel)         │
                                                                          ▼
Phase 5.1-5.5 fact-check cluster ─► Phase 6.0 assembly ─► Phase 6.5 deepening (if needed)
```

**Handoff to final audit occurs after Phase 6.5.** The assembled KB files + build manifests + fact-check artifacts are the artifacts passed to the Auditor.

---

## SECTION 2: PHASES 1.1 AND 1.3 — DUAL-BUILDER RESEARCH AND DRAFTS

### 1.1 Setup

Two builders work independently. Neither sees the other's output.

| Role | Recommended Model | Why |
|------|------------------|-----|
| Builder A | GPT-5.4 | Precise, well-sourced, current. Zero fabrication rate across 19 production KBs. |
| Builder B | Claude Sonnet 4.6 | Canonical default Builder B; Goldeneye is an explicit Phase 0.0 custom-preset opt-in when available. |

### 1.2 Builder Prompt Requirements

Each builder receives:
- The scoping report (from Info Gather or human)
- Shared Axioms (for voice, principles, error patterns)
- Instructions to web-search every factual claim
- Instructions to mark unverifiable claims with [UNVERIFIED]
- Target size (from scoping report)
- Output file path: `sources/kb_[builder_model].md`

### 1.3 Builder Draft Format

A single continuous markdown document with:
- `##` section headers matching the topic structure from the scoping report
- Inline source citations where available
- [UNVERIFIED] tags on claims not confirmed via web search
- A source key at the end listing all references

### 1.4 Builder Rules

1. **Web search every factual claim.** Do not rely on training data for facts.
2. **Mark what you can't verify.** [UNVERIFIED] is honest. Fabrication is not.
3. **Be comprehensive.** Target the size specified in the scoping report. Thin drafts produce thin KBs.
4. **Preserve specifics.** Dates, dollar amounts, case numbers, statute sections, entity names — these are the value. Never round, generalize, or omit.
5. **Analytical tone.** Per Shared Axioms Section 2. Write for the audience specified in the scoping report.
6. **Stay in scope.** Cover the topics in the scoping report. Don't drift into adjacent areas.
7. **Tag volatile fields.** Claims that change frequently must be tagged with `[VOLATILE:type]` inline. This enables the Refresh Orchestrator to prioritize staleness scans and warns downstream consumers to verify before using. See table below.

### 1.5 Volatile-Field Tagging (Mandatory)

Builders must tag claims that are known to change frequently with a `[VOLATILE:type]` marker:

| Tag | Applies to | Refresh expectation | Example |
|-----|-----------|---------------------|---------|
| `[VOLATILE:docket-count]` | Litigation case counts in active dockets | Months | "1,600+ federal cases in MDL 3047" |
| `[VOLATILE:penalty-rate]` | FTC/agency inflation-adjusted penalty rates | Annual | "$53,088 per violation under ROSCA" |
| `[VOLATILE:exchange-rate]` | Foreign currency conversions | At time of use | "KRW 11.6 billion (~$8.5M)" |
| `[VOLATILE:event-date]` | Forward-looking event dates not yet confirmed | Until confirmed | "Olympic Esports Games (first edition 2025)" |
| `[VOLATILE:bill-status]` | Legislative status (proposed/enacted/vetoed) | Session-by-session | "KOSA passed the Senate" |
| `[VOLATILE:market-data]` | Revenue, market cap, headcount, market share | Quarterly | "over $200 billion in annual revenue" |
| `[VOLATILE:rule-status]` | Administrative rule status (proposed/final/vacated/stayed) | Event-triggered | "Negative Option Rule enforceable July 14, 2025" |

**Why this matters:** Four of ten errors found in the Gaming Law KB book verification (April 2026) were staleness — claims that were accurate when written but became stale within months. Tagging at build time is cheaper than catching staleness downstream.

### 1.6 Volatile-Tag Preservation Discipline

Builders MUST tag volatile fields at draft time using the `[VOLATILE:type]` vocabulary. The downstream Phase 6.0 (Lead Assembly) MUST preserve these tags across paraphrasing — never drop a volatile tag when restating the surrounding sentence. The Refresh Orchestrator scans for these tags regardless of file age.

---

## SECTION 3: PHASE 2.0 — LEAD REVIEW

### 2.1 Setup

The Lead reads both builder drafts and produces three artifacts:
- Comparison report
- Revision instructions for Builder A
- Revision instructions for Builder B

| Role | Recommended Model | Why |
|------|------------------|-----|
| Lead | Claude Opus 4.6 | Best judgment, synthesis, and comparison capabilities. |

### 2.2 Comparison Report

`sources/comparison_report.md` — contains:

- **Section-by-section quality ratings** (1-5 scale) for both builders
- **Factual disputes** between builders — the Lead RESOLVES each dispute using web search, citing the source. Do not just flag disputes — settle them.
- **Coverage gaps** — topics one builder covered that the other missed
- **Fabrication flags** — claims that appear in only one builder and seem implausible. Apply the exclusion rule from Shared Axioms (Pattern 5): search before excluding.
- **Single-source claim inventory** — ALL claims that appear in only one builder's output, regardless of plausibility. These must be explicitly listed and tagged for Priority 1 verification by the Fact-Checker. Single-source claims have the highest fabrication risk because they weren't independently corroborated. (See Shared Axioms, Lesson 30.)
- **[UNVERIFIED] inventory** — all unverified claims from both builders
- **Assembly recommendation** — which builder is backbone for each section

### 2.3 Revision Instructions

`sources/review_[builder_model].md` — specific, actionable instructions for each builder:

- Claims to verify, correct, or remove (with specific text references)
- Sections needing expansion or reduction
- Content from the other builder to incorporate
- [UNVERIFIED] tags that need resolution
- Structural changes (file splits, rebalancing)

**Priority-ordered.** Most critical fixes first.

---

## SECTION 4: PHASE 3.0 — BUILDER REVISION

Each builder receives its revision instructions and the other builder's draft (for content to incorporate). Builders revise in parallel.

**Output:** `sources/kb_[builder_model]_v2.md`

**Rules:**
- Address ALL issues raised by the Lead
- Web search to verify any new claims added during revision
- Incorporate content from the other builder as directed
- Preserve sourcing discipline — new claims need citations
- Remove or resolve [UNVERIFIED] tags where possible

---

## SECTION 5: PHASE 6.0 — ASSEMBLY

### 5.1 Assembly Approach

The Lead (or a designated assembly agent) produces the final KB files from the revised drafts.

**Assembly rules:**
1. **Use the stronger builder as backbone** (per comparison report recommendation)
2. **Enrich with verified content from the other builder**
3. **Preserve ALL specifics** — dates, amounts, citations, entity names
4. **Do NOT summarize.** The Lead's output must be AT LEAST as detailed as the most detailed builder on each topic. If a builder wrote 20KB on a topic, the assembled version must be at least 20KB.
5. **Apply the comparison report's dispute resolutions** — the Lead already settled these

### 5.2 Output Files

For each topic in the scoping report, create:
- `[NN]-[topic-slug].md` — topic file with YAML metadata header and Key Takeaways section
- `index.md` — KB snapshot, routing table, key dates
- `table-of-authorities.md` — all cited sources organized by type
- `AGENTS.md` — v3-compliant entry point (5-7KB)

### 5.3 File Standards

Every topic file must include:

```yaml
---
title: [Topic Name]
kb: [KB Name]
last_updated: [date]
tags: [relevant tags]
---
```

- **Key Takeaways** section at the top (3-5 bullet points)
- **Cross-references** to related files in this KB
- **Source citations** inline where available
- **No [UNVERIFIED] tags** in final assembly — resolve or remove during assembly

---

## SECTION 6: PHASE 6.5 — QUALITY-TIER DEEPENING

### When Required

Run the pre-ship size gate (per Shared Axioms Section 6):
- Hard floor: No topic file below 12KB
- Soft floor: Average topic file ≥ 15KB
- Parity: Thinnest ≥ 50% of thickest

If any gate fails, deepen before final audit and regenerate any downstream artifacts affected by the changed `full/` files.

### Deepening Protocol

| Setting | Value |
|---------|-------|
| Model | GPT-5.4 (zero fabrication risk) |
| Concurrency | 4-6 files in parallel |
| Method | Read file + builder drafts → web search for additional content → expand thin sections |
| Target | Each file to 18-25KB |
| Cost | ~$0.70/file |

### Deepening Rules

1. **Preserve existing content.** Deepening ADDS — it doesn't rewrite.
2. **Web search for new content.** Don't pad with filler. Add substantive material from primary sources.
3. **Maintain voice and structure.** New content must match the existing analytical tone.
4. **Update index and table of authorities** after deepening.
5. **Re-run affected Phase 6 gates.** If deepening changes `full/`, re-run Phase 6.3 extraction and Phase 6.4 post-assembly fact-check before Phase 7.0 final audit.

---

## SECTION 7: HANDOFF TO FINAL AUDIT

After assembly, post-assembly fact-check, and any required deepening, produce the handoff artifact:

### Build Manifest

`sources/build_manifest.md`:

```markdown
# Build Manifest — [KB Name]
# Date: [date]
# Pipeline: [multi-model / single-model]

## Models Used
- Builder A: [model]
- Builder B: [model]
- Lead: [model]
- Deepening: [model] (if applicable)

## Files Produced
| File | Size | Sections | Notes |
|------|------|----------|-------|
| [filename] | [KB] | [section numbers] | [any flags] |

## Size Gate Results
- Hard floor: [PASS/FAIL]
- Soft floor: [PASS/FAIL]
- Parity: [PASS/FAIL — ratio]

## Known Issues
[Any unresolved items, thin sections, or areas the builders flagged as uncertain]

## Builder Drafts Preserved
- sources/kb_[model_a].md
- sources/kb_[model_a]_v2.md
- sources/kb_[model_b].md
- sources/kb_[model_b]_v2.md
- sources/comparison_report.md
- sources/review_[model_a].md
- sources/review_[model_b].md
```

The Fact-Checker receives the assembled KB files and the build manifest. It does NOT receive builder drafts, comparison reports, or revision instructions — those are Builder internals.

---

## SECTION 8: SINGLE-MODEL PATHWAY

When a multi-model pipeline is not feasible (cost, time, scope), a single-model pathway is acceptable with these constraints:

1. **Only for company KBs or non-legal topics.** Legal topic KBs require multi-model.
2. **Use GPT-5.4** as the single model (zero fabrication rate).
3. **Quality floors are stricter:** Weighted average ≥ 4.5 (vs. 4.3 for multi-model).
4. **Post-ship audit is still mandatory.**
5. **Document the justification** in the build manifest.

---

## SECTION 9: ANTI-PATTERNS

### Don't skip the Lead review
Running two builders and then assembling without comparison misses the dispute-resolution step where most errors are caught. The Lead review is where Builder A's fabrication meets Builder B's precision.

### Don't let the Lead summarize
The #1 assembly failure: the Lead reads two 100KB drafts and produces 10KB files. The Lead is a SYNTHESIZER, not a summarizer. If the builders wrote 20KB on a topic, the assembled version must be at least 20KB.

### Don't deepen without the pipeline
Deepening outside the full pipeline introduces errors (validated across 3 topic KBs this session). Deepening should feed INTO the pipeline — add content, then fact-check the additions. Deepening as a standalone fix is a v1.0 anti-pattern.

### Don't reuse stale builder drafts
If rebuilding a KB, generate fresh builder drafts. Using the original drafts from a prior build propagates the same errors that triggered the rebuild.

### Don't build without a scoping report
Even a brief one. The Info Gather module exists because building blind produces KBs that miss their audience, over-scope, or under-cover critical topics.

---

## SECTION 10: BUILDER DRAFT PRESERVATION

All intermediate artifacts are preserved in `sources/`:
- Original builder drafts (v1)
- Revised builder drafts (v2)
- Comparison report
- Revision instructions
- Build manifest
- Build prompts (exact prompts used at each phase)

These are non-negotiable provenance. A future user must be able to understand exactly how the KB was constructed.

---

*This module builds knowledge bases. It does not verify them. Handoff to the Fact-Checker is mandatory before shipping.*
