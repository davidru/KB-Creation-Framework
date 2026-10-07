# Shared Axioms — KB Creation Framework
# Version: 1.0 | Created: 2026-04-09
# Scope: Read by ALL modules. Contains principles, lessons, voice, error patterns.
# Independence: This document has no dependencies on other modules.

---

## SECTION 1: GOVERNING PRINCIPLES

These principles apply to every module in the framework. They are non-negotiable.

### The Rules

1. **Judgment Beats Formalism** — Default to informed judgment over rigid rules.
2. **Don't Solve Tomorrow's Problems Today** — Avoid over-engineering for hypothetical scenarios.
3. **Lead With the Bottom Line** — Start with the practical answer.
4. **Legally Permissible ≠ Operationally Wise** — Account for optics, scalability, durability.
5. **Consistency Over Purity** — Imperfect but consistent > elegant but uneven.
6. **Avoid Bright Lines You Can't Defend Later** — Hard caps invite edge-case pressure.
7. **Optics Matter** — Apply the reasonable outsider test.
8. **Governance Must Scale With the Organization**
9. **Use Structure to Enable Participation, Not Police It**
10. **Explain Tradeoffs—Let Others Decide** — Provide the framework, not just the answer.
11. **Choose—Then Own It** — Apply consistently going forward.

### Quality Axioms

12. **No compromise on quality. Ever.** A KB with a 12% error rate in legal citations is not "acceptable with caveats" — it's wrong law that propagates into legal advice.
13. **Currency is the highest priority for legal KBs.** A repealed statute cited as current law is a critical error. A stale market cap is an annoyance. Different KB types have different error tolerances.
14. **Verify the noun, not just the number.** A correct number attributed to the wrong entity is more dangerous than a fabricated number, because it survives casual verification.
15. **Process is substance.** An auditable process surfaces non-compliance. A silent process hides it.
16. **Every claim must earn its place.** If you can't verify it, say so explicitly or omit it. There is no middle ground.
17. **Do not skip steps — ever — without explicit user permission.** Every phase in the v3 pipeline (0.0, 0.1, 0.2, 1.1, 1.2, 1.3, 2.0, 3.0, 4.0, 5.1, 5.2, 5.3, 5.4, 5.5, 6.0, 6.1, 6.2, 6.3, 6.4, 6.5, 7.0, 8.0, 8.5) runs by default. "Skip" decision rules elsewhere in this framework are NOT self-executing — they are flags that require the Lead to STOP, surface the proposed skip to the user with the rationale, and wait for explicit approval before proceeding. The user's stated priority is quality and zero errors, not cost or time. When in doubt, run the step. Silent skipping is a process failure equivalent to a fact-check miss.

18. **Downstream documents must trace to KB sources.** When a KB is used to generate a memo, book, email, or other downstream document, every factual claim in the downstream document must trace to a specific KB section — or be independently verified via web search. Agents drafting downstream documents must NOT generate unsourced factual claims for narrative framing. If a market-size figure, industry statistic, or "scene-setting" fact is needed and the KB doesn't provide it, the agent must search for and cite the figure rather than estimating.
19. **Model-Family Separation.** Generation and verification of the same content must use different model families. The Lead, Builder A, and Builder B are assigned through Phase 0.0 model selection using the canonical presets in `audit-templates/model-presets.yaml`; the standard preset is validated mechanically and any family-separation exceptions must use the Phase 0.0 opt-out path rather than proceeding silently. Critique passes (Phase 0.2, 1.2, 6.1), fact-check phases (5.1-5.5, 6.4), the audit (Phase 7.0), and the stress-test fact-checker / reviewer (Phase 8.0) all use a different family from whoever generated the content being checked. Specifically: Phase 5.4 uses a different family from Phase 5.2; Phase 6.4 uses a different family from Phase 5.2; Phase 7.0 uses a different family from Phase 6.4 and Phase 5.2; Phase 8.0 memo fact-check uses a different family from Phase 6.4. Same-family verification is a soft form of self-grading — the model's blind spots and training-data biases are shared with the content it is supposed to check. Family is determined by the Model Registry per entry, not inferred from the model name. Cross-provider same-family usage (e.g., Azure Foundry GPT-4o + OpenAI direct GPT-4o) is NOT cross-family corroboration — both declare `family: openai` in the registry, and Rule 19 enforcement applies as such. Document the model used at every phase in `sources/pipeline_state.md`. If family separation cannot be achieved, STOP and invoke the Phase 0.0 opt-out path rather than proceeding silently. Operators may invoke the explicit opt-out path documented in `prompts/00a-model-selection.md` for builds where family separation cannot be achieved. Opt-outs MUST be acknowledged interactively, logged in `sources/pipeline_state.md`, and surfaced in the Quality Scorecard methodology appendix. Opt-outs do NOT auto-downgrade the Quality Scorecard's composite verdict but DO tag the affected dimension scores; see `audit-templates/kb-quality-dimensions.yaml` § family_separation_exception_handling.

20. **Model Provenance Honesty (MANDATORY).** Every phase artifact and the `sources/pipeline_state.md` phase log MUST record the **actual model that produced the content**, not the intended assignment. Specifically:
    - `model_assignment:` in `sources/scoping_report.md` and the top of `pipeline_state.md` records the INTENDED Phase 0.0 selection — operator-approved, source-of-truth for what SHOULD be used.
    - Per-phase logs in `sources/pipeline_state.yaml` (v3.1.11+ canonical format) — or the legacy `sources/pipeline_state.md` for builds that pre-date v3.1.11 — record the ACTUAL dispatch result. The YAML format is schema-validated (`audit-templates/pipeline-state.schema.json`) and lintable by `Validate-PipelineState.ps1`; the markdown format is parsed by Generate-QualityScorecard.ps1's tolerant regex-based parser. Both formats require the same fields per dispatch: `intended_handle:` + `actual_model_id:` + `actual_provider:` + `actual_family:` + `dispatch_status:` (one of: `dispatched-as-intended` | `dispatched-with-substitution` | `dispatched-after-override` | `failed-then-acknowledged-opt-out`).
    - **`intended_handle` integrity (v3.1.10 tightening).** `intended_handle` MUST be one of the role-specific handles declared in the Phase 0.0 `model_assignment:` block at the top of `pipeline_state.md`. It is NOT a freeform field where the orchestrator can write whatever handle it just dispatched. If the actual dispatch routed to a different model than the role's Phase 0.0 handle, the log entry reads `intended_handle: <role's Phase 0.0 handle>` + `actual_model_id: <what actually ran>` + `dispatch_status: dispatched-with-substitution` (or appropriate enum value). Mid-build re-assignment is permitted ONLY via the Mid-Build Override Flow in `prompts/00a-model-selection.md`, which rewrites the Phase 0.0 `model_assignment:` block atomically with operator acknowledgment and an audit-trail entry; subsequent phases use the new assignment's `intended_handle`. Drift between Phase 0.0 assignment and per-phase `intended_handle` (without an override-flow entry) is itself a Rule 20 integrity violation, separate from the actual-vs-intended divergence.
    - **OpenCode `subagent_type` MUST be a role-based subagent name (v3.1.10 clarification).** On OpenCode hosts, the `subagent_type` parameter passed to the Task tool MUST be one of the role-based agent names rendered into `opencode.json`'s `agent:` block by `Render-OpenCodeAgents.ps1` (e.g., `builder-a`, `builder-b`, `critic-pool-handle-1`, `factcheck-pool-5a-5b-5c-handle-1`, `factcheck-6b`, `auditor-7`, `memo-factcheck-8`, `lead`). Registry handle names (e.g., `lead-xai-grok43`, `builder-deepseek-v4-flash`, `factcheck-deepseek`, `auditor-mistral`) are NOT valid `subagent_type` values — OpenCode does not match `subagent_type` against handle names and will silently fall back to the parent (Lead) model when an unknown `subagent_type` is supplied. The authoritative routing table lives in the Lead's prompt in `opencode.json` (injected by Render-OpenCodeAgents.ps1 v3.1.10+ as the "DISPATCH ROUTING TABLE" section) AND in the agent block names themselves (read `(Get-Content opencode.json -Raw | ConvertFrom-Json).agent.PSObject.Properties.Name` for the canonical list).
    - **Dispatch-time silent-fallback detection (v3.1.10).** Render-OpenCodeAgents.ps1 v3.1.10+ embeds a deterministic `DISPATCH-FINGERPRINT::<agent-name>::<hex>` token in every sub-agent's prompt AND surfaces it in the agent's `description` field. The orchestrator's dispatch protocol on OpenCode hosts (mandatory) is: (a) prepend the literal token `ECHO-FINGERPRINT` to the task prompt, (b) inspect the response — a correctly-routed sub-agent echoes its fingerprint on the first non-empty line (it has the fingerprint in its prompt; the parent model does not when fallback occurs), (c) verify the fingerprint against opencode.json's expected value (mechanically via `Test-DispatchFingerprint.ps1`), (d) on match: log `dispatch_status: dispatched-as-intended`, (e) on no-fingerprint or wrong-fingerprint: log `dispatch_status: dispatched-with-substitution` and invoke DISPATCH-FAILURE CONTRACT from `prompts/01-orchestrator.md`. This mechanism catches OpenCode's silent fallback at dispatch time, not at Phase 9 scorecard generation — the prior failure mode where 60%+ of dispatches in a real build silently substituted to the parent model and the orchestrator did not notice until scorecard.
    - When actual ≠ intended (e.g., Lead substituted for a failed sub-agent dispatch under acknowledged opt-out, or mid-build model override changed the assignment), the deviation MUST be explicit in the phase log. Recording the intended assignment when the actual model differed is an integrity violation of the Quality Scorecard's family-separation accounting.
    - Per-phase deliverable artifacts (e.g., `comparison_report.md`, `factcheck_*.md`, `kb-quality-scorecard.md`) MUST include a "Model provenance" section listing the actual model(s) that produced their content, sourced from `pipeline_state.md` actuals — NOT inferred from the Phase 0.0 assignment.
    - The Quality Scorecard's family-separation dimension MUST score against actuals. A build where Lead substituted for both builders scores as same-family (Rule 19 degraded), NOT as cross-family, regardless of what the intended assignment said.
    - Adapter `dispatch.ps1` returns `model_id`, `top_provider`, and (where available) actual underlying provider/model the upstream routed to. This data is the ground truth; orchestrator MUST capture it per dispatch and append to `pipeline_state.md`.
    - **All content-generation phases must log per-dispatch actuals (v3.1.10 clarification).** This includes per-topic build phases (e.g., when Builder A and Builder B both run on each of N topics, the orchestrator MUST log 2N entries — one per builder per topic — or a single phase header followed by a per-topic actuals table). A build with no per-topic actuals entries — as observed in the WA-Law-Firm-KB v2 build where Phase 5.2 had zero entries despite 15 topics being drafted — is a Rule 20 violation and the Quality Scorecard's Rule 19 cross-phase pair evaluation will return `INSUFFICIENT_DATA` for every pair anchored to that phase.
    - This rule was added 2026-06-07 after an operator empirically observed v3.1 phase logs claiming the designated model while the actual work was done by the Lead (DeepSeek) on OpenCode after Task-tool dispatch failed (v3.1.6 silent-fallback issue). Recording the intended-but-not-actual model is a worse failure than the dispatch failure itself, because it makes the framework's audit trail a lie. The v3.1.10 tightening (intended_handle integrity + subagent_type role-name requirement + dispatch fingerprint + per-topic logging) was added 2026-06-08 after a follow-up WA-Law-Firm-KB v2 build exhibited a 62.5% silent-fallback rate (10/16 dispatches) that the orchestrator did not detect because (a) it dispatched to invented handle names that didn't match opencode.json subagent names, and (b) it rewrote intended_handle per phase rather than honoring Phase 0.0, and (c) there was no dispatch-time verification mechanism.

### Operator-facing Six Rules summary

Operator-facing summary — see HOW-TO-USE.md for the canonical form.

1. **Source-Constrained Specificity** — Never request detail without naming the source type
2. **Zero Tolerance for Fabrication** — Verified or removed. Never flagged, never hedged.
3. **Builder Isolation** — Builders never see each other's output
4. **No Self-Grading** — No model judges its own work
5. **No Silent Skipping** — Every phase runs by default. The Lead does NOT skip, shortcut, or conditionally bypass any phase on its own judgment. Any "skip if…" heuristic in the orchestrator is a flag to pause, surface the proposal to the user, and wait for explicit approval. The user's priority is quality and zero errors — not speed or cost. See 01-shared-axioms.md Rule 17.
6. **Model-Family Separation** — Generation and verification of the same content must use different model families. The Lead and both builders are different families from each other. Critique, fact-check, audit, and stress-test phases use a different family from whoever produced the content being checked. Document the model used at every phase. See 01-shared-axioms.md Section 4 for separation requirements per phase.

---

## SECTION 2: VOICE & TONE

### For Legal Knowledge Bases

- **Analytical, not encyclopedic.** Write for a practicing lawyer who needs to act on the information, not a student who needs to learn the background.
- **Lead with the conclusion.** State the legal position, then explain the reasoning.
- **Plain English with precise legal nouns.** Use "governance," "FRAND commitment," "consent decree," "exclusionary conduct." Avoid legalese that obscures meaning.
- **Short paragraphs.** 1-3 sentences. One idea per paragraph.
- **Explain tradeoffs, not rules.** Use concrete examples.
- **Flag risk without alarmism.** Frame uncertainty as risk identification, not speculation.
- **Epistemic humility on facts.** "My understanding is…" / "[UNVERIFIED]" when uncertain about premises. Never hedge on the analytical conclusion.

### For Company Knowledge Bases

- Same analytical tone, focused on strategic implications for CELA practitioners.
- Frame each topic from the perspective of: "What does a Microsoft lawyer need to know about this company's IP/standards/regulatory posture?"
- Include peer comparisons and competitive context where relevant.

### Vocabulary

**Use:** "From a [X] perspective…", "My sense is…", "At a high level…", "That said,…", "The question we need to answer is…", "As a practical matter…", "Realistically…"

**Never use:** "It depends" (without then giving the answer), "pursuant to," "hereinafter," "synergies," "leverage" (as verb), "circle back," "touch base"

---

## SECTION 3: ERROR PATTERN TAXONOMY

These error patterns were identified across 19 company KB builds and 15 topic KB audits, plus subsequent downstream-use incidents. Every module that creates or verifies content should watch for these.

### Pattern 1: Date Drift (4.6% of errors)
**What:** Dates shift by days or months from the actual event.
**Example:** IPO date stated as "December 19, 1991" when actual was December 13, 1991.
**Root cause:** Models reconstruct dates from approximate memory rather than looking them up.
**Detection:** Verify every specific date against primary sources.

### Pattern 2: Attribution Confusion (3.4% of errors)
**What:** Correct number attached to wrong entity.
**Example:** $18.4B was Bloomberg's valuation estimate, not the Amazon deal's valuation.
**Root cause:** Models retrieve numbers and attach them to the most contextually prominent entity.
**Detection:** For every specific number, verify the exact entity, time period, and context.

### Pattern 3: Speculative Inflation (2.3% of errors)
**What:** Plausible-sounding forward numbers stated without sources.
**Example:** "FY2026 revenue projected at $6.40B" when no such projection was public.
**Root cause:** Models extrapolate from trends and present the extrapolation as fact.
**Detection:** Any forward-looking number requires a specific, citable source.

### Pattern 4: Terminology Upgrade (1.1% of errors)
**What:** Informal terms replaced with more precise-sounding but different terms.
**Example:** "spending" → "capex" (which has a specific accounting meaning).
**Root cause:** Models optimize for precision of language, inadvertently changing meaning.
**Detection:** Compare against source material for terminology shifts.

### Pattern 5: Overcautious Exclusion (CRITICAL)
**What:** Real events excluded as fabrications because they seem implausible.
**Example:** Anthropic Pentagon supply-chain risk designation excluded as "fabrication." Adobe $150M FTC settlement removed as "unverified." Both were real.
**Root cause:** Fact-checkers develop a heuristic that unusual claims from known-fabrication models are probably fake. Right ~70% of the time — but creates confirmation bias.
**Detection:** Mandatory web search before ANY exclusion decision. Log the search queries and results.

### Pattern 6: Stale Financial Ratios (CRITICAL)
**What:** Financial ratios use training-data-era numbers when the actual values have moved dramatically.
**Example:** Tesla P/E stated as 40-60× when actual was 294-335×.
**Root cause:** Models cannot know current-period valuations by definition.
**Detection:** All financial ratios, market cap, headcount, and market share require web verification. NEVER trust model knowledge for these fields.

### Pattern 7: Wrong Jurisdiction (1% of errors)
**What:** Legal actions attributed to wrong court, agency, or jurisdiction.
**Root cause:** Models conflate parallel proceedings across jurisdictions.
**Detection:** Verify court name, docket number, and jurisdiction for every case citation.

### Pattern 8: Standards Membership Unverifiability (systemic)
**What:** SDO membership claims that can't be confirmed because many SDOs don't publish rosters.
**Example:** Apple Bluetooth SIG membership — almost certainly true but not publicly confirmable.
**Root cause:** Models assert membership based on product implementation evidence.
**Detection:** Prefer implementation claims over membership claims. For membership, only assert where a public roster, press release, or company filing confirms.

### Pattern 9: Private/Nonprofit Opacity (systemic)
**What:** Revenue, headcount, or operational data for private/nonprofit entities that don't file public reports.
**Root cause:** Models fill gaps with plausible estimates.
**Detection:** Flag all private/nonprofit data claims for heightened scrutiny. Accept "not publicly reported" as an answer.

### Pattern 10: Version Extrapolation
**What:** Commitments for one standard version extrapolated to another.
**Example:** Adobe's RF patent pledge for ISO 32000-1 extrapolated to ISO 32000-2.
**Root cause:** Models treat related standard versions as fungible.
**Detection:** Each version requires independent verification. Wi-Fi 6 ≠ Wi-Fi 7. 4G ≠ 5G.

### Pattern 11: Entity Suffix Fabrication (2% of errors)
**What:** Corporate entity names fabricated or confused (parent vs. subsidiary, LLC vs. Inc.).
**Root cause:** Models guess at corporate structure.
**Detection:** Verify exact entity names from SEC filings or official registrations.

### Pattern 12: Correction Decay (demonstrated in Gaming Law KB, April 2026)
**What:** Errors are identified and logged in `learned/` files but never applied back to the source KB files.
**Example:** *Alexander v. Take-Two* flagged in `open-questions.md` as "not a Seventh Circuit decision — KB should be updated." The KB source file was never updated. The error then propagated into a downstream book manuscript.
**Root cause:** The correction pipeline treats logging as completion. No mandatory step connects `learned/` entries to source-file edits. The agent that identifies the problem is not the same agent that applies the fix, and the handoff is implicit rather than enforced.
**Detection:** Every refresh cycle must diff `learned/` entries against source files. Any correction flagged as "KB impact: [file] should be updated" that hasn't been applied is a blocking issue. See Refresh Orchestrator Section 2.5 (Correction Application Verification Gate).

### Pattern 13: Decorative Fabrication (demonstrated in Gaming Law book, April 2026)
**What:** Market-size figures, industry statistics, and framing claims generated by downstream agents (memo drafters, book generators) without KB sourcing.
**Example:** "$200 billion" industry revenue stated in a book introduction. The KB never made this claim — the drafting agent generated it for narrative impact. Actual figure was $184-188B.
**Root cause:** Agents writing "scene-setting" prose optimize for rhetorical impact over accuracy. Round numbers and superlatives ("the largest," "over $X billion") are particularly high-risk.
**Detection:** Any factual claim in a downstream document that does not trace to a specific KB section should be flagged for independent verification. Drafting prompts should instruct agents to use only KB-sourced figures for market data.

### Subpattern 2a: Exchange Rate Drift (under Pattern 2: Attribution Confusion)
**What:** Foreign-currency penalty or revenue amounts converted to USD at an unspecified or outdated exchange rate, producing a figure that doesn't match any authoritative source.
**Example:** KFTC fine stated as KRW 11.6 billion "~$8.5M" — the KRW figure is correct, but the USD conversion doesn't match the rate at time of announcement (~$8.9M).
**Root cause:** Models pick a round USD conversion without specifying the rate or date.
**Detection:** State the original-currency figure as primary. Note USD conversions as approximate and pin to a date or rate source. Example: "KRW 11.6 billion (~$8.9M at time of announcement)" rather than "~$8.5M."

### Pattern 14: Operative-Mechanism Drift (demonstrated in Medical Device Regulation KB, June 2026)
**What:** The *value* of an operative claim is correct but the *mechanism* around it — indexation cadence, reporting-clock structure, trigger logic, duty-holder scope, penalty structure — is asserted from plausibility and is wrong.
**Example:** Australia penalty-unit value stated correctly as AUD $330, but the indexation mechanism stated as "CPI-indexed annually on 1 July" when Crimes Act 1914 s. 4AA(3) indexes every THREE years (next 1 July 2026). Separately, TGA advertising pre-approval framed as keyed to device class ("Class IIb and Class III devices") when it is keyed to claim type (restricted representations, TG Act s. 42DE), regardless of class.
**Root cause:** Models state regulatory mechanisms from the most common pattern (most indexation is annual; obligations often scale with device class) rather than reading the provision. A `[VOLATILE]` flag on the *number* gives false comfort that the *mechanism* was checked too.
**Detection:** Verify the operative mechanism (cadence/clock/trigger/duty-holder/penalty), not just the value, against the verbatim provision. Flag the mechanism, not just the number. See Fact-Checker Priority 2a; Phase 5.5 (`prompts/55-factcheck-operative-claims.md`).

### Pattern 15: Cross-Reference Divergence (demonstrated in Medical Device Regulation KB, June 2026)
**What:** The same fact stated in two topics drifts; the non-canonical restatement drops a qualifier or a tier, and neither restatement is individually complete.
**Example:** Canada SOR/98-282 § 62 hospital reporting stated precisely in Topic 08 ("hospital") but imprecisely in Topic 19 ("healthcare institutions"). Australia adverse-event clocks: Topic 11 carried 10d + 30d (missing the 48h public-health-threat lane); Topic 19 carried 10d + 48h (missing the 30d lane) — neither held the full TGA three-tier (48h / 10d / 30d) structure.
**Root cause:** Topics are built and verified independently; no pass reconciles a claim that appears in multiple topics against a single canonical statement or against primary source. A drafter pulling from whichever topic maps to the question inherits that topic's specific drop.
**Detection:** For any claim appearing in ≥2 files, designate a canonical statement and diff every restatement against it and against primary source; reconcile to the full structure, not to one topic. See Fact-Checker Priority 2b; Phase 5.5 (`prompts/55-factcheck-operative-claims.md`).

### Pattern 16: Circular Corroboration (demonstrated in Medical Device Regulation KB verification, June 2026)
**What:** An operative value is treated as "confirmed" because it appears in multiple sources, but the corroborating sources are internal echoes — other KB files, a prior memo, a persona/instruction file, or another AI-authored artifact — not independent primary sources.
**Example:** A verification agent reported the AUD $330 penalty-unit value as corroborated, citing among its sources the operator's own `copilot-cli-setup` instructions file — a self-authored artifact, not a primary source.
**Root cause:** Search surfaces the operator's own prior outputs and treats them as third-party corroboration. Plausible-but-wrong values launder into "confirmed" through self-citation.
**Detection:** Operative values require a Tier 1 primary source. Exclude self-/AI-authored artifacts and prior internal work products from the corroboration set (cf. Institutional-Fact Discipline: treat your own outputs as suspect on re-read). See Fact-Checker Priority 2b; Phase 5.5 (`prompts/55-factcheck-operative-claims.md`).

### Pattern 17: Premature Unverifiable — Access-Failure Misclassified as Absence (demonstrated in Medical Device Regulation SaMD survey, June 2026)
**What:** A primary source that *exists* is marked `[NEEDS-VERIFICATION]` / "Unverifiable" / "STILL-UNVERIFIABLE" because the **default fetch was blocked** (403, JS-SPA shell, Cloudflare challenge, Turnstile), without escalating through the Primary-Source Access Fallback Chain (Tier 0 API → 1 web_search/Wayback → 2 curl_cffi → 2.5 cloudscraper → 3 Playwright → 4 Camoufox → 5 patchright → 6 Scrapling). "I couldn't reach it with the default tool" is silently converted into "it can't be verified."
**Example:** The SaMD six-jurisdiction survey shipped UAE and Saudi answers carrying a heavy `[NEEDS-VERIFICATION]` load on penalties, definitions, and reporting clocks because the SFDA portal (`sfda.gov.sa`) returned a Drupal JS-SPA shell and the UAE legislation portal (`uaelegislation.gov.ae`) was recorded as "403/blocked." On escalation: **Scrapling StealthyFetcher (Tier 6)** rendered the SFDA SPA and exposed the static PDFs (Implementing Regulation; MDS-REQ 11 V2 reporting clock); **curl_cffi (Tier 2)** retrieved the full 850 KB official PDF of UAE Federal Decree-Law No. 38/2024 on the *first try* from the portal's `/download` endpoint. Both jurisdictions' operative cores were primary-confirmable all along — the block was a tooling default, not a source absence.
**Root cause:** The fact-check / verification phases default to `web_search` only and treat anti-bot 403s, SPA shells, and paywalls as "permanent gaps" routed to manual or to an Unverifiable verdict. The build-time grounding pass (03-builder + Phase 6.5 fetch-closure) already mandates the chain; the verification side did not, so blocked sources leaked to NEEDS-VERIFICATION at fact-check time.
**Detection / rule:** "Source unreachable" is **never** a terminal disposition until the full fetch fallback chain (Tier 0–6) has been attempted and logged. Distinguish **access-failure** (source exists, default fetch blocked → MUST escalate the chain, consult `../host-registry.md` for the host's known min-tier) from **genuine absence** (source does not exist publicly, e.g., unpublished executive regulations → legitimately `[NEEDS-VERIFICATION]`, naming the specific tiers attempted and why each failed). Only Akamai Bot Manager / PerimeterX / authenticated-session / true paywall hosts are permanent gaps — and only after the chain is exhausted. See Fact-Checker §1.3 "Blocked-Source Escalation"; host-registry feedback loop; `~/.copilot/copilot-instructions.md` Primary-Source Access Fallback Chain.

---

## SECTION 4: MODEL BEHAVIOR PROFILES

### Standard Pipeline Configuration

The authoritative default presets live in `audit-templates/model-presets.yaml`; the table below summarizes the standard multi-family preset.

| Role | Model | Family |
|------|-------|--------|
| **Lead** | Claude Opus 4.7 | Anthropic |
| **Builder A** | GPT-5.4 | OpenAI |
| **Builder B** | Claude Sonnet 4.6 | Anthropic |

Lead and Builder B share the Anthropic family. To preserve independence, the Lead never reviews Builder B's draft in isolation — both builders' drafts are reviewed identically — and all critic / fact-check / audit phases use the Phase 0.0 `model_assignment` discipline rather than ad hoc substitutions.

Goldeneye is preferred when available, but the framework treats Claude Sonnet 4.6 as the canonical default Builder B. Operators who want Goldeneye select the 'custom' preset at Phase 0.0 model selection and substitute Goldeneye for Builder B explicitly. The substitution is recorded in `sources/pipeline_state.md`.

### Single-Agent (CLI) Operation — Default Dispatch Pattern

When the Lead is a single CLI agent (e.g., Copilot CLI, Claude Code, Cursor) rather than a human orchestrator switching browser tabs, the Lead is REQUIRED to dispatch Builder A, Builder B, critics, and fact-checkers as parallel sub-agents using model overrides (e.g., the `task` tool with `model: gpt-5.4` and `model: claude-sonnet-4.6`). This is the default — do NOT ask the user whether to use multi-model. Do NOT collapse the pipeline to a single model unless the user explicitly opts out.

Pre-flight check: at Phase 0.0 the Lead confirms the required model overrides are reachable (one OpenAI-family slot, one Anthropic-family Builder slot, one third-family critic slot). If any required family is unavailable, STOP and surface to the user before scoping continues.

### Claude Opus 4.7 (Lead)
- **Strengths:** Excellent at comparison, synthesis, and assembly. Best judgment for Lead Reviewer role. Strong at identifying disputes between builders.
- **Weaknesses:** Expensive. Can over-summarize if not explicitly instructed to preserve detail.
- **Role:** Lead Reviewer, final assembly, comparison reports. Never builds content it later judges.
- **Cost:** $5.00/M input, $25.00/M output. (Opus 4.6 acceptable as fallback at the same role.)

### GPT-5.4 (Builder A)
- **Strengths:** Zero fabrication rate across 19 KBs and 114+ operations. Best sourcing discipline. Current through training data. Excellent for fact-checking, deepening, and post-assembly work.
- **Weaknesses:** Slightly less creative/expansive in first-draft generation.
- **Role:** Builder A (primary builder). Also used for deepening, fact-check, and audit passes.
- **Cost:** $1.75/M input, $14.00/M output. ~$0.70/file for deepening.

### Claude Sonnet 4.6 (Builder B — default)
- **Strengths:** Creative, expansive first drafts. Strong at structural organization and richer prose. Pairs well with GPT-5.4 because the two models miss different things in first drafts.
- **Weaknesses:** Higher historical fabrication rate than GPT-5.4 (legacy 4.5 measured 6–30%; 4.6 reduced but not eliminated). Can reassert claims that prior passes removed. Shares the Anthropic family with the Lead — compensate via third-family critic/fact-check phases.
- **Role:** Builder B (independent second draft). Default in CLI single-agent operation; Goldeneye requires explicit custom selection.

### Goldeneye (Builder B — explicit opt-in)
- **Strengths:** Internal model with distinct training characteristics. Provides genuine third-family divergence from Lead (Anthropic) and Builder A (OpenAI).
- **Weaknesses:** Behavior profile still accumulating production data. Monitor for fabrication patterns.
- **Role:** Builder B (independent second draft) when selected through the `custom` Phase 0.0 preset.

### Multi-Model Pipeline Rationale
Using models in their strongest roles produces better results than any single model. GPT-5.4's accuracy + Sonnet's expansiveness (or an operator-selected Goldeneye divergence) + Opus's judgment = the errors each model makes are caught by the others. Single-model pipelines are acceptable only with domain justification, stricter quality floors, and explicit user opt-out. CLI single-agent Leads default to multi-model dispatch via sub-agents — they do not ask.

---

## SECTION 5: ERROR-RATE THRESHOLDS

### Post-Audit Disposition (Mandatory)

**Legal / Regulatory Topic KBs:**
| Error Rate | Action |
|-----------|--------|
| 0-4%      | Ship — corrections only |
| 8%        | Targeted corrections + re-audit the corrected claims |
| 12%+      | **Full multi-model rebuild** |

**Company / Entity KBs:**
| Error Rate | Action |
|-----------|--------|
| 0-8%      | Ship — corrections only |
| 12-16%    | Targeted corrections + re-audit |
| 20%+      | **Full multi-model rebuild** |

**Rationale:** Legal accuracy has a categorically different error tolerance than financial data staleness. A wrong statute citation propagates into legal advice. A stale market cap does not.

These thresholds apply to ALL audits: initial, post-ship, refresh, and periodic re-verification.

---

## SECTION 6: SIZE GATES

### Pre-Ship Size Gate (Mandatory)
- **Hard floor:** No topic file below 12KB. Blocking deficiency.
- **Soft floor:** Average topic file ≥ 15KB. Triggers mandatory deepening if below.
- **Parity check:** Thinnest file ≥ 50% of thickest file.

### Rebuild Target Sizes
- **Company KB topic files:** 18-30KB each
- **Legal topic KB files:** 15-30KB each
- **Litigation analysis files:** 30-50KB each (deeper procedural detail required)
- **Index files:** 10-20KB
- **Table of authorities:** 10-20KB
- **AGENTS.md:** 5-7KB

---

## SECTION 7: LESSONS LEARNED (PRESERVED FROM V2 — FULL 35-ITEM LIST)

Numbered lessons from production. This section preserves the full 35-item v2 lesson list. New lessons are added via the Option C promotion process: when the Fact-Checker identifies the same error pattern in 3+ KBs, it drafts a lesson here. Human confirms or edits.

1. Models fabricate with confident specificity — invented case names, fake docket numbers, plausible-sounding enforcement actions.
2. Date and citation errors are more common than invented cases.
3. Financial data is always stale from model knowledge alone.
4. Two-model comparison catches errors that single-model review misses.
5. Three model families ideal; two acceptable with domain justification.
6. Builder drafts should be preserved in `sources/` — they are raw material for future deepening.
7. Deepening is a pipeline stage, not remediation. Every build requires it.
8. Assembly compression is structural: two 70-100KB drafts compress to 6-10KB/file average. This is not failure — it's the mathematics of merging overlapping content.
9. Max 2-3 concurrent agents for high-context phases. Deepening can do 4-6. Never exceed 20.
10. Per-file quality floors matter more than averages. Four weak files in a 16-file KB will be found.
11. Overstated legal conclusions propagate through downstream work products.
12. Implausibility is not evidence of fabrication — it's a signal to search harder.
13. Mandatory web search before any exclusion decision.
14. High-volatility fields (P/E, market share, headcount, valuations, patent counts) are NEVER trustworthy from model knowledge.
15. Verify the noun, not just the number.
16. Standards membership ≠ standards implementation — and membership is often unverifiable.
17. Never extrapolate patent or FRAND commitments across standard versions.
18. Pipeline fatigue produces thinner later builds — size gate catches this.
19. Most "fabrications" are misattributions — correct facts with wrong context.
20. Legal topic KBs require stricter error-rate thresholds than company KBs.
21. Deepening without the full pipeline introduces errors. Deepening should feed INTO the pipeline, not bypass it.
22. Prior audits can introduce new errors — verification passes need their own verification.
23. Sonnet builds creative but stale; GPT-5.4 builds precise and current. Use each in its strength.
24. When paraphrasing statutory provisions, preserve the operative trigger. "Applies to X" is wrong if the text says "applies to Y with commentary extending to X." Quote the actual hook and note the extension separately. Conceptually-correct-but-textually-inaccurate paraphrases survive internal review and fail on first contact with a reader who pulls the article.
25. After a KB ships, stress-test it downstream: have an agent draft a short advisory memo using the KB, then fact-check the memo against both the KB and primary sources. This catches the gap between what the KB says and what a user actually produces from it. If the downstream output drifts from the KB's careful phrasing, the KB may need to be more explicit or more quotable.
26. Unverified citations propagate faster than verified ones. Once an unverified claim appears in a work product, it becomes the next person's "source." The KB's [UNVERIFIED] tagging discipline must extend to downstream outputs: if a claim enters a memo from outside the KB and cannot be pinned to a primary source, remove it — do not just flag it.
27. Practice guidance synthesized from multiple rules propagates downstream as black-letter authority unless the KB explicitly distinguishes register. Models compress principles into crisp action checklists that read like operative rules. Tag the register at build time; filter on it at consumption time. (Promoted from US Legal Ethics KB stress test, April 2026.)
28. Logging a correction is not the same as applying it. If `learned/open-questions.md` says "KB impact: [file] should be updated" and the file is not updated, the correction has not happened — it has been documented. The Refresh Orchestrator's Correction Application Verification gate (`06-refresh-orchestrator.md` Step 3.5) exists to enforce this. (Promoted from Gaming Law KB book verification, April 2026.)
29. Litigation docket counts, inflation-adjusted penalty rates, and forward-looking event dates are high-volatility fields that go stale within months. Tag them with `[VOLATILE:type]` at build time so downstream consumers and the Refresh Orchestrator know to verify before using. A specific number without a date anchor is a time bomb. (Promoted from Gaming Law KB book verification, April 2026.)
30. Single-source claims — facts that appear in only one builder's output — have the highest fabrication risk because they weren't independently corroborated. The CDPR "February 2025 second attack" fabrication survived the pipeline because it appeared only in Builder A and was plausible-sounding. All single-source claims must receive Phase 5.4 (`prompts/54-factcheck-single-source.md`) verification. (Promoted from Gaming Law KB book verification, April 2026.)
31. Single-agent CLI Leads silently drop Phase 6.0 infrastructure-file creation when they conflate "assembly" with "ship the topic files." The US Employment Immigration KB (April 2026) was assembled with all 15 topic files in `full/` but no AGENTS.md, no index.md, no table-of-authorities.md, and an empty `authority/` folder — yet the Lead ran downstream audit and stress-test phases on top of an incomplete deliverable. Two fixes: (a) Phase 6.0 lead-assembly prompt (`prompts/60-lead-assembly.md`) now requires the Lead to print an Assembly Completion Checklist verbatim before declaring assembly done; (b) Phase 6.3 is now a **structural** completeness gate as well as a filename-validation gate — it tests for the existence of AGENTS.md, index.md, table-of-authorities.md, and authority/ population (conditional on register tags in `full/`). Missing infrastructure is BLOCKING. (Promoted from US Employment Immigration KB build incident, April 2026.)
32. Illustrative entity examples (named firms, vendors, products, programs) make practice guidance materially more useful and are PERMITTED in `full/` provided they are (a) sourced to a real reference actually consulted, (b) framed as illustrative rather than as the specific client's institutional relationship, and (c) placed inside `<!-- [GUIDANCE] -->` or `<!-- [INTERPRETATION] -->` tagged paragraphs so the authority-view extractor strips them. Earlier in 2026 the US Employment Immigration KB had the names "Fragomen, BAL, Berry Appleman & Leiden" inserted as plausible-but-unsourced illustrative examples in `[GUIDANCE]`-tagged paragraphs. Those names then propagated into the persona file as Microsoft's standing outside counsel and surfaced in a memo as institutional fact. The contamination chain was diagnosed (see ~/.copilot/copilot-instructions.md "Institutional-Fact Discipline") and the structural protection — persona files contain conventions not facts; downstream consumers cite primary sources only; rubber-duck institutional-fact audit on every named-entity claim — now lives at the consumption layer where it belongs. The source-side response is therefore not to sterilize KB `full/` content of illustrative examples (which would impoverish the human-facing view), but to require the three guardrails above. Downstream protection is structural (authority/ extraction + persona discipline + consumer audit), not content-purification at the source. (Promoted from US Employment Immigration KB illustrative-examples policy revision, April 2026.)

33. Verify the operative *mechanism*, not just the value. Indexation cadence, multi-tier reporting clocks, trigger/threshold logic, duty-holder scope, and penalty structure go wrong the same way numbers do — and a `[VOLATILE]` flag on the number gives false comfort that the mechanism was checked. "CPI-indexed annually on 1 July" survived internal review because annual indexation is the common case; the provision (Crimes Act 1914 s. 4AA(3)) said every three years. "Pre-approval for Class IIb/III devices" survived because obligations often scale with device class; the provision keyed pre-approval to making a restricted claim, regardless of class. Quote the operative subsection or flag it; never state a regulatory mechanism from plausibility. (Promoted from Medical Device Regulation KB verification, June 2026. See Phase 5.5 `prompts/55-factcheck-operative-claims.md`.)
34. The same fact stated in two topics drifts, and the drafter pulls from whichever topic maps to the question. For any operative or definitional claim that appears in ≥2 files, designate a canonical statement and diff every restatement against it and against primary source. Two topics describing the same obligation differently does not make either correct — Canada hospital reporting was precise in Topic 08 and imprecise in Topic 19; the Australia adverse-event clocks were each missing a different tier in Topics 11 and 19. Reconcile to the full structure, not to one topic. (Promoted from Medical Device Regulation KB verification, June 2026.)
35. Self-corroboration is not corroboration. A value that appears in two KB files, a prior memo, a persona/instruction file, or any AI-authored artifact has been copied, not independently confirmed. Operative values require a Tier 1 primary source; exclude the operator's own prior outputs from the corroboration set. A verification agent once "confirmed" a penalty-unit value partly against the operator's own instructions file — an internal echo masquerading as third-party corroboration. (Promoted from Medical Device Regulation KB verification, June 2026. See Phase 5.5 `prompts/55-factcheck-operative-claims.md`.)

*Lessons are added when the same pattern is observed in 3+ KBs. The master audit log tracks pattern frequency.*

---

## SECTION 8: HANDOFF ARTIFACT FORMATS

Each module communicates with others through artifacts, not by reading each other's instructions. These are the standard formats.

### Info Gather → Builder
```
File: sources/scoping_report.md
Contains:
- KB name, type (company/legal topic/litigation/person)
- Audience and purpose
- Topic list with brief descriptions
- Coverage boundaries (what's in/out)
- Known verified anchor facts
- Key sources to consult
- Target size and file count
```

### Builder → Fact-Checker
```
File: The assembled KB files themselves
Plus: sources/build_manifest.md listing all files, sizes, and models used
```

### Fact-Checker → Builder/Shared Axioms
```
File: sources/factcheck_report.md
Contains:
- Numbered claim list with verdicts (Confirmed/Wrong/Stale/Unverifiable)
- Source citations for each verification
- Error rate calculation
- Error pattern tags (from taxonomy in Section 3)
- Suggested corrections
- Pattern frequency counts (for Option C promotion)
```

### Fact-Checker → Master Audit Log
```
Appends to: KB Creation Framework/master_audit_log.md
Format: Date | KB Name | Error Rate | Patterns Found | Disposition
```

### Orchestrator → All Modules
```
File: sources/pipeline_state.md
Contains:
- Current phase, what's complete, what's pending
- Decision log (why rebuild vs. patch, which builder is backbone)
- Agent IDs and status
- Handoff checklist
```

---

## SECTION 9: REGISTER TAGGING & DOWNSTREAM USE

### The Problem

KB content written in a single undifferentiated register causes downstream agents to cite practice guidance as if it were black-letter authority. In the US Legal Ethics KB stress test (April 2026), 3 of 41 downstream claims were flagged as overstatements — all traced back to KB passages that presented practitioner synthesis in the same declarative voice as rule text. The underlying guidance was defensible; the problem was that nothing in the file distinguished "the rule says X" from "experienced counsel would do Y."

### Register Tagging (Build-Side)

Every substantive paragraph in a KB file must be written in one of three registers. Use inline HTML comments as markers:

- **No marker** = **Primary authority** — rule text, holdings, verified facts directly traceable to a single primary source. This is the only content downstream agents should cite as authority.
- `<!-- [GUIDANCE] -->` = **Practice guidance** — the author's synthesis of what to do. Defensible, operationally useful, but not sourced to a single authority. Often synthesizes multiple rules into an action checklist. **This register is also the correct home for sourced illustrative entity examples** (e.g., "firms such as Fragomen, BAL, Berry Appleman & Leiden") — the authority-view extractor strips these paragraphs, so illustrative examples enrich the human-facing `full/` view without ever entering the citable-authority surface.
- `<!-- [INTERPRETATION] -->` = **Interpretive synthesis** — combining multiple sources into a conclusion none individually states. Analytical value, but the conclusion is the KB author's, not the source's. Sourced illustrative entity examples may also live here.

**Tagging rules:**
1. Human readers ignore the HTML comments — the text reads naturally.
2. Downstream agents filter on them — they can distinguish citeable authority from guidance.
3. Key Takeaways sections are typically `<!-- [GUIDANCE] -->` unless they quote rule text.
4. "As a practical matter…" or "The defensible response is…" framing is a strong signal that content should be tagged `<!-- [GUIDANCE] -->`.
5. Checklists, action sequences, and "best practice" formulations synthesized from multiple rules are almost always `<!-- [GUIDANCE] -->`.
6. **Illustrative entity examples** (named firms, vendors, products, programs cited as examples of a category) belong in `<!-- [GUIDANCE] -->` or `<!-- [INTERPRETATION] -->` paragraphs, never in untagged authority-register paragraphs. Three guardrails apply: (a) sourced — the named entity must come from a real source actually consulted (industry directory, ranking, trade press, regulator filing, the entity's own materials); cite inline. (b) Framed as illustrative ("firms such as X, Y, Z"), never as the specific client's institutional relationship unless that relationship is independently sourced to a primary record. (c) Will be stripped from `authority/` automatically via the register-tag-based extractor — that is the structural protection against downstream consumers absorbing illustrative examples as institutional facts.

### Dual-View KB Architecture

When a KB has downstream use cases (producing work product from the KB), the assembly phase generates two views in separate folders:

```
[KB Root]/
├── AGENTS.md                    ← routing + consumption protocol (shared)
├── index.md                     ← human entry point (shared)
├── table-of-authorities.md      ← verified citations (shared)
├── sources/                     ← build artifacts (not shipped)
│
├── full/                        ← FULL VIEW
│   ├── 01-[topic].md            Register-tagged. All content.
│   └── ...                      For human readers and standalone reference.
│
└── authority/                   ← AUTHORITY VIEW
    ├── 01-[topic].md            Guidance/interpretation stripped.
    └── ...                      For downstream agents producing work product.
```

**Rules:**
1. The `full/` folder is the source of truth. Register tags are retained — they are invisible in rendered markdown and enable authority-view regeneration.
2. The `authority/` folder is a derived artifact. It is generated by a deterministic script that strips all `<!-- [GUIDANCE] -->` and `<!-- [INTERPRETATION] -->` tagged paragraphs from the full-view files.
3. When the full view is updated, the authority view must be regenerated.
4. Downstream agents producing work product MUST use the `authority/` folder. This is a hard rule — the exposure problem cannot be solved by instructions alone. Models absorb everything in their context window regardless of tagging.
5. Infrastructure files (AGENTS.md, index.md, table-of-authorities.md) stay at the KB root and serve both use cases.
6. Same filenames in both folders — AGENTS.md routing directs agents to the correct folder based on use case.
7. **Default is ON.** Authority-view extraction runs by default for every build. Skip it only if the scoping report explicitly opts out with a documented reason (e.g., pure reference KB with no register tagging anywhere). If any `<!-- [GUIDANCE] -->` or `<!-- [INTERPRETATION] -->` tag exists in `full/`, extraction is mandatory regardless of scoping-report settings. See Phase 6.3 `prompts/63-extraction-and-filename-validation.md` for the procedure and gates.

### Downstream Consumption Protocol (Use-Side)

When an agent uses a KB to produce work product (memos, briefs, advice):

1. **Cite only unmarked content as authority.** Unmarked paragraphs state rules, holdings, or verified facts — these can be cited as "Rule X requires…" or "In *Case Y*, the court held…"
2. **Do not cite tagged content as authority.** Content marked `<!-- [GUIDANCE] -->` or `<!-- [INTERPRETATION] -->` may inform analysis structure and recommendations, but must be framed as guidance: "One defensible approach is…", "Experienced practitioners typically…", "Practice guidance suggests…"
3. **If the KB is your only source and the relevant content is tagged as guidance, say so.** "Practice guidance suggests X, but the governing rule is [cite unmarked rule text]."
4. **The claim map must include the register.** Add a column: `Register (Authority/Guidance/Interpretation)`. This makes overstatement traceable.

### Lesson (added to Section 7)

27. Practice guidance synthesized from multiple rules propagates downstream as black-letter authority unless the KB explicitly distinguishes register. Models compress principles into crisp action checklists that read like operative rules. Tag the register at build time; filter on it at consumption time.

---

*This document is the foundation of the KB Creation Framework. All other modules reference it. It is updated only through the Option C promotion process or direct human edit.*
