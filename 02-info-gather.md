# Info Gather Module — KB Creation Framework
# Version: 1.0 | Created: 2026-04-09
# Scope: Standalone scoping and requirements elicitation for any KB project.
# Dependencies: Reads 01-shared-axioms.md for voice and principles.
# Independence: Can operate alone to scope a project without triggering a build.

---

## PURPOSE

This module produces a **scoping report** that defines what a knowledge base should cover, who it serves, and what quality standards apply. It can be used:

- **Standalone** — to scope a project for future execution
- **As Phase 0.1** — after Phase 0.0 model selection, feeding into the Builder module via artifact handoff

The output is a `scoping_report.md` file that any Builder (human or AI) can execute against.

---

## SECTION 0.0: MODEL SELECTION (Phase 0.0 — runs before scoping)

Before any scoping question is asked, the Lead Orchestrator dispatches `prompts/00a-model-selection.md` to prompt the operator for which models to use for each role. The output is a `model_assignment` YAML block written to the top of the scoping report (see Section 3 schema below).

The `model_assignment` block looks like this:

```yaml
model_assignment:
  preset: standard-multi-family | budget-multi-family | single-family-anthropic | single-family-openai | custom
  lead: <model-id>
  builder_a: <model-id>
  builder_b: <model-id>
  critic_pool: [<model-id>, ...]
  factcheck_pool_5a_5b_5c: [<model-id>, ...]
  factcheck_pool_5d_5e: [<model-id>, ...]
  factcheck_6b: [<model-id>, ...]
  auditor_7: [<model-id>, ...]
  memo_factcheck_8: [<model-id>, ...]
  rule_19_exceptions: []   # populated only if family separation was acknowledged-opt-out
```

If `rule_19_exceptions` is non-empty, the Phase 0.0 prompt requires the operator to provide a `opt_out_rationale` (free text). The rationale is captured in `sources/pipeline_state.md` and surfaced in the Quality Scorecard.

Downstream phases read this block and dispatch agents per the assignment.

---

## SECTION 1: REQUIRED QUESTIONS

Before building any KB, these questions must be answered. Do not proceed to building until every required question has a clear answer.

### 1.1 Identity & Type

| Question | Why It Matters |
|----------|---------------|
| **What is this KB about?** (company, legal topic, litigation, person, technology) | Determines structure, voice, error thresholds, and size targets |
| **What type of KB is this?** | Company KB, Legal Topic KB, Litigation Analysis KB, Person KB, Technology KB |
| **Does a KB on this topic already exist?** | If yes: audit first, decide rebuild vs. patch. Don't duplicate. |

### 1.2 Audience & Purpose

| Question | Why It Matters |
|----------|---------------|
| **Who will use this KB?** (role, seniority, organization) | Drives depth, tone, and assumed knowledge level |
| **What decisions will this KB inform?** | Determines which topics are essential vs. nice-to-have |
| **What's the primary use case?** (reference, analysis, briefing prep, client advice) | Shapes structure — reference KBs need routing tables; analysis KBs need conclusions |
| **Will this KB be used to produce downstream work product?** (memos, briefs, analyses, books) | Informs register-tagging discipline during drafting. Authority-view extraction runs by default at Phase 6.3 regardless — see Section 9 of shared-axioms.md. |

### 1.3 Scope & Boundaries

| Question | Why It Matters |
|----------|---------------|
| **What topics MUST be covered?** | Non-negotiable coverage areas |
| **What topics are explicitly OUT of scope?** | Prevents scope creep — "oxygen expands to the size of the room" |
| **What time period?** (historical through current, current only, specific date range) | Determines depth of historical coverage |
| **What jurisdictions?** (US only, EU, global, specific countries) | Legal KBs especially — jurisdiction determines which statutes matter |
| **What level of detail?** (survey, practitioner-depth, expert-depth) | Drives file size targets |

### 1.4 Known Anchors

| Question | Why It Matters |
|----------|---------------|
| **What facts are already verified?** | Anchor points that builders must preserve — prevents regression |
| **What are the key sources?** (SEC filings, court dockets, SDO websites, specific reports) | Directs builders to primary sources |
| **Are there existing materials to incorporate?** (prior KBs, memos, research) | Avoids duplicate work |
| **What are known controversies or disputed facts?** | Flags areas requiring extra verification |

### 1.5 Quality Requirements

| Question | Default | Override? |
|----------|---------|-----------|
| **Error-rate threshold?** | 12% legal, 20% company | Only stricter |
| **Size targets?** | Per Shared Axioms Section 6 | Can increase, not decrease |
| **Multi-model pipeline?** | Required for legal KBs | Single-model only with justification |
| **Post-ship audit?** | Mandatory | Never waived |

### 1.6 Tier A / Tier B Claim Classification (per-topic, required)

For every topic identified in Section 2, the scoping report must classify the topic's expected claim density per `../tier-a-b-classification.md` (Tier A = build-gating; Tier B = flag-and-defer; `[RESOLVED-ABSENT]` available for confirmed-absent claims). The classification cascades into the Phase 6.5 quality-tier audit / deepening gate (see `05-build-orchestrator.md`).

| Question | Why It Matters |
|----------|---------------|
| **Per topic: high / medium / low Tier-A density?** | Regulatory-regime KBs are high Tier-A across most topics; company KBs are typically medium-low. Drives Phase 6.5 gate strictness per topic. |
| **Per topic: any explicit Tier-B carve-outs?** | E.g., parcel-level zoning data may be Tier-B even in a high-Tier-A regulatory KB. Naming the carve-outs in scoping prevents the assembly gate from blocking on them later. |
| **Are there known non-public sources** the topic touches (TSRC, internal licence conditions, confidential filings) that should default to `[RESOLVED-ABSENT-NON-PUBLIC]`? | Prevents endless re-chasing of confirmed-non-public material. |

**Default per KB type** (override per topic in the scoping report):

| KB type | Default Tier-A density |
|---|---|
| Legal Topic KB (regulatory-regime: CRA, NIS2, AI Act, DORA, sector standards, jurisdiction-specific procedural KBs) | High |
| Legal Topic KB (comparative-jurisdiction survey) | Medium |
| Company KB | Medium-low |
| Person KB | Medium-low |
| Litigation Analysis KB | High (per-case operative claims) |
| Voice / style / judgment KB | N/A (Tier A/B does not apply) |

---

## SECTION 2: TOPIC STRUCTURE DEVELOPMENT

After answering the required questions, develop the topic structure.

### 2.1 For Company KBs

Standard 14-topic structure (customize as needed):

1. Company Overview & Business Model
2. Patent Portfolio & Technology
3. IP Monetization & Licensing
4. Standards Participation
5. FRAND/SEP Positions
6. Litigation History
7. ITC Proceedings
8. Antitrust & Regulatory
9. Financial Analysis
10. AI Technology & IP Strategy
11. Competitive Positioning
12. Corporate History & Key Figures
13. Public Policy Positions
14. [Company]-Microsoft Relationship

**Customization rules:**
- Add topics for company-specific areas (e.g., Adobe → Content Authenticity)
- Remove topics that don't apply (e.g., ITC if company has no ITC history)
- Never remove: Overview, IP/Patents, Litigation, Financial, Competitive

### 2.2 For Legal Topic KBs

No standard structure — topics emerge from the subject matter. But every legal topic KB should include:

- **Operating map / regulatory landscape** (which agencies, which statutes, which jurisdictions)
- **Key statutes and regulations** (full text analysis, not just citations)
- **Leading cases** (holdings, not just names)
- **Compliance frameworks** (what practitioners need to do)
- **Emerging issues** (what's changing, what's pending)
- **Cross-references** to related topic KBs

### 2.3 For Litigation Analysis KBs

Structure follows the cases:
- **Per-case files** (procedural history, legal theories, holdings, implications)
- **Cross-case analysis** (common themes, doctrinal shifts, strategic implications)
- **Implications file** (what this means for the organization)

### 2.4 Topic Sizing

| KB Type | Files | KB/file target | Total target |
|---------|-------|---------------|-------------|
| Company (14 topics) | 14-16 | 18-30KB | 250-400KB |
| Legal Topic (10-18 topics) | 12-20 | 15-30KB | 200-500KB |
| Litigation Analysis (2-5 cases) | 4-8 | 30-50KB | 150-300KB |
| Person | 5-8 | 15-25KB | 75-200KB |

---

## SECTION 3: SCOPING REPORT FORMAT

The output of this module is a single markdown file that serves as the handoff artifact to the Builder.

````markdown
# Scoping Report — [KB Name]
# Date: [date]
# Scoped by: [human/model]

```yaml
model_assignment:
  preset: standard-multi-family | budget-multi-family | single-family-anthropic | single-family-openai | custom
  lead: <model-id>
  builder_a: <model-id>
  builder_b: <model-id>
  critic_pool: [<model-id>, ...]
  factcheck_pool_5a_5b_5c: [<model-id>, ...]
  factcheck_pool_5d_5e: [<model-id>, ...]
  factcheck_6b: [<model-id>, ...]
  auditor_7: [<model-id>, ...]
  memo_factcheck_8: [<model-id>, ...]
  rule_19_exceptions: []
```

## KB Identity
- **Name:** [name]
- **Type:** [company / legal topic / litigation / person]
- **Location:** [file path]

## Audience & Purpose
- **Primary audience:** [role, seniority, organization]
- **Primary use case:** [reference / analysis / briefing prep]
- **Decisions informed:** [list]

```yaml
audience_fit:
  frontline_practitioner: {ok: true|false, notes: "[what they get from this KB]"}
  senior_counsel: {ok: true|false, notes: "[depth/citation expectations]"}
  executive: {ok: true|false, notes: "[summary expectations]"}
```

## Downstream Use
- **Downstream work product expected:** [yes / no]
- **Types:** [memos, briefs, analyses, books, etc. — or "none"]
- **Authority-view extraction:** [default — run unless explicitly opted out below]
- **Tier A/B claim classification:** [see Section 1.6 — per-topic A-density (high/medium/low) and any topic-level Tier-B carve-outs]
- **Non-public sources noted for `[RESOLVED-ABSENT-NON-PUBLIC]` default:** [list, or "none"]
- **Opt out of authority view?:** [no (default) / yes — with reason]
  (Opt-out is valid only for pure reference KBs that use zero register tagging. If any `<!-- [GUIDANCE] -->` or `<!-- [INTERPRETATION] -->` tag exists in `full/` at assembly time, authority-view extraction runs automatically regardless of this field.)

## Scope
- **Topics in scope:** [numbered list with brief descriptions]
- **Topics out of scope:** [explicit exclusions]
- **Time period:** [range]
- **Jurisdictions:** [list]
- **Detail level:** [survey / practitioner / expert]

## Known Anchors
- **Verified facts:** [list with sources]
- **Key sources:** [list]
- **Existing materials:** [file paths]
- **Known controversies:** [list]

## Quality Requirements
- **Error-rate threshold:** [X%]
- **Size targets:** [per-file and total]
- **Pipeline:** [multi-model / single-model with justification]
- **Post-ship audit:** [mandatory]

## Topic Structure
[Numbered list of proposed topics with 1-2 sentence descriptions]

## Builder Notes
[Any additional context, warnings, or priorities for the builders]
````

---

## SECTION 4: ANTI-PATTERNS

### Don't scope blind
Read existing materials before scoping. The user caught us about to rebuild three KBs without understanding their scope, audience, or purpose. Always read index.md, AGENTS.md, and sample content files before defining the rebuild plan.

### Don't assume standard structure
Not every KB fits the 14-topic company template. Litigation KBs have 3-5 deep case files. Topic KBs have domain-specific structures. Let the subject matter drive the structure.

### Don't scope too broadly
"Cover all gaming law" is 18 topics. "Cover the two Meta verdicts" is 3 files. Scope determines resource allocation. Over-scoping produces thin coverage across too many topics. Under-scoping produces deep coverage but misses important areas. Match scope to purpose.

### Don't skip the "out of scope" question
If you don't explicitly exclude topics, they'll creep in. "Oxygen expands to the size of the room." The Builder will find adjacent topics interesting and start covering them unless told not to.

---

*This module operates independently. Its only output is a scoping_report.md file. It does not build, verify, or assemble anything.*
