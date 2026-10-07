# LLM Recreation Prompt — KB Creation Framework v3.1.0 + Memo Drafting Framework v1 + Provider Registry

**Version:** v3.1.0 — 2026-06-07
**Purpose:** A single self-contained prompt that, when given to a capable frontier LLM with file-write and shell-execute capability, will produce a functioning conformant implementation of **two sibling frameworks**: the KB Creation Framework v3.1.0 and the Memo Drafting Framework v1 + Provider Registry.
**Output target:** Two working frameworks on disk, each with its own HOW-TO-USE.md, rulebooks (KB only), prompts, scripts, and documentation. Together they support producing auditable, anti-fabrication knowledge bases AND drafting source-corpus-grounded memos against any KB or other corpus.
**Inputs the receiving LLM needs:** A target root directory (the two frameworks will be created as sibling subdirectories), Python 3.12+, PowerShell 7+, pip access, a Model Registry config (`model-registry.yaml`, or copied from `model-registry.example.yaml`), at least one configured provider API key for live dispatch (OpenRouter is the easiest starter: `OPENROUTER_API_KEY`; Azure Foundry requires endpoint + API key; Ollama requires a local runtime; Copilot CLI uses host auth), optionally Playwright + Patchright browser binaries (for the optional Crawl4AI adapter), and access to at least three model families (OpenAI, Anthropic, plus one more — Google or Internal) for end-to-end conformance testing.

**Companion artifact:** `technical-specification-v3.1.0.md` (this directory) is the live framework's normative v3.1 specification. This recreation prompt is self-contained for reconstruction; the companion spec is a reference/check artifact, not an external dependency the receiving LLM must possess.

---

> **HOW TO USE THIS PROMPT.** Paste the entire content below the ▼▼▼ line into a fresh session with a capable frontier LLM (Claude Opus / GPT-5 / equivalent) that has file-write and shell-execute capability. Tell it the target root directory and let it work. Allow ~60-90 minutes of model time. The prompt is self-contained — the receiving LLM does not need access to the original framework repository to recreate the system.

> **WHY A PROMPT, NOT A REPO CLONE.** The original framework is *itself* a prompt-and-protocol system; the implementation is largely Markdown prompts and short scripts. Reconstructing it from a specification is a more faithful test of the framework's separability from any one operator's idioms than copying files. If the receiving LLM cannot reconstruct it from this prompt, the specification is insufficient and the framework is opaque — which we want to know.

> **WHAT'S DIFFERENT FROM THE v2 RECREATION PROMPT.** v3 introduces 18 changes over v2 (see § 1 below) and spins memo drafting out as a sibling framework. v3 recreation produces TWO frameworks, not one, with a documented integration contract. v3 includes a new Phase 0.0 model-selection subsystem, a Quality Scorecard subsystem, three-tier output (full/practice/authority), KB-type prompt branching (legal vs company), an adversarial red-team phase, and a v2→v3 migration path.

---

▼▼▼ BEGIN PROMPT (PASTE BELOW INTO RECEIVING LLM) ▼▼▼

# YOUR TASK: Recreate the KB Creation Framework v3.1.0 + Memo Drafting Framework v1 + Provider Registry

You will produce a complete, functioning implementation of two sibling anti-fabrication frameworks. Write the files described below into the target root directory the operator specifies. When asked to confirm tooling assumptions (PowerShell version, Python version, optional adapter installation), ask the operator; otherwise proceed.

## 1. What These Two Systems Are

The **KB Creation Framework — Modular v3.1.0** is a pipeline for producing auditable, practitioner-grade knowledge bases in high-consequence domains (legal, regulatory, standards, company intelligence). The framework's three failure modes a single-LLM build suffers from — shallow content, hallucinated facts (especially named entities), and blind spots from training-data gaps — are structurally engineered out, not patched over with model instruction.

The **Memo Drafting Framework v1 + Provider Registry** is a sibling framework that owns the Grounded Memo Drafter four-step protocol. It is invoked by KB v3's Phase 8 stress test AND can be invoked standalone for production memo drafting against any source corpus (a KB, a contract folder, a regulator filing record, a standards spec).

Both are **prompt-and-protocol-driven**, not application-driven: no daemons, databases, UIs, or API gateways. Persistent state is a directory tree of Markdown and YAML files. Orchestration lives in Markdown prompts that an operator (or CLI agent acting on the operator's behalf) pastes into model sessions. Short PowerShell scripts and an optional Python adapter enforce mechanical invariants.

## 2. The Two-Framework Architecture

```
[target root]\
├── KB Creation - Modular v3 + OpenCode and OpenRouter\  [Framework 1 — KB construction]
│   └── (entry point: HOW-TO-USE.md → prompts/01-orchestrator.md)
└── Memo Drafting Framework v1 + Provider Registry\        [Framework 2 — Memo drafting]
    └── (entry point: HOW-TO-USE.md → prompts/01-claim-extractor.md)
```

**Integration contract.** KB v3's Phase 8.0 (Downstream Stress Test) invokes the Memo framework once per stress-test memo (3-6 memos per build). The invocation passes: `source_corpus_path` (typically `[KB Root]\authority\`), `memo_topic`, `working_dir`, `memo_label`, `model_assignment` (passthrough from KB v3's Phase 0.0 selection), optional `qualifier_registry_path`. The Memo framework returns: claim manifest JSON, drafted memo with CLAIM MAP, leakage report, reattribution report, qualifier review, summary JSON. Documented in `Memo Drafting Framework v1 + Provider Registry\02-corpus-contract.md` as a versioned contract.

## 3. The v3 and v3.1 Changes (Why This Is Not Just v2)

1. **Memo Drafting Framework spinoff** — the Grounded Memo Drafter is now its own framework.
2. **Monotonic phase renumbering** — 0.0, 0.1, 0.2, 1.1, 1.2, 1.3, 2.0, 3.0, 4.0, 5.1-5.5, 6.0-6.5, 7.0, 8.0, 8.5 replace v2's non-monotonic numbering.
3. **Prompt consolidation 22→24 final files** — v2 Phase 1.5 cut; v2 Phase 3.5 folded into Phase 4; v2 Phase 2a+2b merged into single Lead-review; v2 Phase 6c+6a merged into single post-assembly-automated prompt; new prompts added for Phase 0.0, Phase 6.5, Phase 7.0 (which were orchestrator-logic-only in v2), and Phase 8.5 (new adversarial).
4. **Crawl4AI primary-source grounding default-on** — for Phase 5.2 and Phase 6.4. Opt-out captured with rationale.
5. **`Verbatim-Linter.ps1` promoted from pilots to mainline** — mechanical paraphrase-drop and wrong-anchor detection in Phase 6.2.
6. **Three-tier output** — `full/` (source of truth) → `practice/` (strips `[INTERPRETATION]` only, retains `[GUIDANCE]`) → `authority/` (strips both). New `Extract-PracticeView.ps1`.
7. **Claim reattribution check** — `Detect-Reattribution.ps1` catches memos that cite the right `claim_id` but characterize its source quote incorrectly.
8. **Per-claim refresh cadence by `[VOLATILE:*]` type** — Refresh Orchestrator drives cadence per-claim, with KB-type interval as fallback for untagged claims.
9. **Phase 4 schema validation** — `Validate-Phase4Inventory.ps1` validates the single-source claim inventory before Phase 5.4/5.5 consume it. Closes the framework-review Finding 4 contract gap mechanically.
10. **KB Quality Scorecard subsystem** — single rolled-up artifact at `audit/kb-quality-scorecard.md` with 7 mechanical quality dimensions and a weighted composite KB Quality Index.
11. **KB-type prompt branching** — `prompts/legal/` and `prompts/company/` override subdirectories for phases where the discipline meaningfully differs.
12. **Cross-KB conflict detector** — `Detect-CrossKBConflicts.ps1` advisory tool.
13. **`Diff-KBVersions.ps1`** — structured diff between two builds of the same KB.
14. **Adversarial Phase 8.5 red-team** — three attack scenarios test whether the dual-view architecture holds under adversarial pressure.
15. **Goldeneye/Sonnet decision** — default Builder B is Claude Sonnet 4.6; Goldeneye is explicit opt-in.
16. **Cost-estimate cleanup** — pre-2026 dollar figures cut from `05-build-orchestrator.md`, replaced with token-cost guidance.
17. **Phase 0.0 model selection** — `prompts/00a-model-selection.md` + `Validate-ModelAssignment.ps1` + `audit-templates/model-presets.yaml`. Operator picks model assignment at session start; Rule 19 (Model-Family Separation) violations require explicit opt-out acknowledgment.
18. **v2 → v3 migration capability** — `Migrate-V2KBtoV3.ps1` opt-in script regenerates derived views and synthesizes missing manifests from existing v2 tags.



### 3.1 The v3.1.0 additive changes

19. **Model Registry provider abstraction** — `model-registry.yaml` / `model-registry.example.yaml` map framework handles to provider, model_id, family, endpoint env-ref, api_key env-ref, capabilities, and notes.
20. **Provider adapters** — `adapters\model-providers\copilot-cli\`, `azure-foundry\`, `openrouter\`, and `ollama\`, each with `dispatch.ps1`, `discover.ps1`, `README.md`, and license metadata.
21. **Family-via-registry Rule 19** — model family is the registry entry's `family`, not provider name or model-name guess. Cross-provider same-family is still same-family.
22. **Host Contract** — `HOST-CONTRACT.md` plus `hosts\copilot-cli\HOST-NOTES.md`, `hosts\opencode\HOST-NOTES.md`, and `hosts\README.md`; capability levels L1a/L1b/L2/L3.
23. **Phase 0.0 enhancements** — preset, custom, discover-and-add, and recommend-per-role sub-flows.
24. **Domain-aware recommendation** — `Recommend-Models.ps1` combines OpenRouter `/api/v1/models?category=<domain>` results with benchmark-derived `domain-capabilities.yaml`.
25. **Usability scripts** — setup doctor, resume, initializer, status, cost estimate, recommendations, OpenRouter category discovery, doctor, and notifications.
26. **OpenCode host support** — source-verified static multi-model `agent` configuration; conservative L3 until runtime `Validate-Host.ps1` promotion proves L1a.

## 4. The KB v3 Pipeline (Phase-by-Phase)

```
Phase 0.0  Host + Model Selection (host selected before Phase 0.0; registry preset + custom + discover-and-add + recommend-per-role + Rule 19 opt-out; output: model_assignment YAML)
Phase 0.1  Scoping (Info-Gatherer produces scoping_report.md)
Phase 0.2  Scoping critique (Critic, A/B/C format; different family from Lead)
Phase 1.1  Parallel topic research (Builder A + Builder B, isolated, different families)
Phase 1.1  Lead merge of topics_*.md → topics_merged.md
Phase 1.2  Topic-list critique (Critic, different family from Lead and either builder)
*** HUMAN GATE 1: operator approves the post-critique topic list ***
Phase 1.3  Per-topic drafting (each Builder × each topic; 4-6 concurrent per builder)
Phase 2.0  Lead review (structural + depth merged; per builder)
Phase 3.0  Builder revision (each builder revises v1 → v2)
Phase 4.0  Lead comparison + single-source claim inventory + v1-vs-v2 compliance check
           (Validate-Phase4Inventory.ps1 enforces inventory schema)
*** HUMAN GATE 2 (recommended): operator reviews comparison ***
Phase 5.1  Fact-check: currency (incl. characterization vs operative hook)
Phase 5.2  Fact-check: citations (Crawl4AI default-on; Verbatim-Linter integration)
Phase 5.3  Fact-check: classification
Phase 5.4  Fact-check: single-source claims (different family from 5.2; Tier 1 primary required)
Phase 5.5  Fact-check: operative claims + cross-reference reconciliation (different family from 5.2)
Phase 6.0  Lead assembly (produces full/, AGENTS.md, index.md, table-of-authorities.md, 3 manifests)
Phase 6.1  Assembly critique (Critic, different family from Lead)
Phase 6.2  Register-lint + Verbatim-Linter (script + Lead disposition)
Phase 6.3  Three-tier extraction (full → practice + authority) + filename validation
Phase 6.4  Post-assembly superset fact-check (P1 manifest / P2 rephrased / P3 spot-check; different family from 5.2)
Phase 6.5  Quality tier audit + deepening
Phase 7.0  Final audit (different family from 6.4 AND 5.2) + Generate-QualityScorecard.ps1
*** HUMAN GATE 3: operator reviews audit ***
Phase 8.0  Downstream stress test (3-6 memos; invokes Memo Drafting Framework v1 + Provider Registry per memo)
Phase 8.5  Adversarial red-team (3 attack scenarios; agent must refuse/hedge/surface register)
```

## 5. Roles and Model-Family Separation (Rule 19)

| Role | Default model (Standard preset) | Family |
|---|---|---|
| Lead | Claude Opus 4.7 | Anthropic |
| Builder A | GPT-5.4 | OpenAI |
| Builder B | Claude Sonnet 4.6 (Goldeneye opt-in if reachable) | Anthropic (or Internal) |
| Critic (Phases 0.2, 1.2, 6.1) | GPT-4.1 or GPT-5.4 (third family from Lead) | OpenAI |
| Fact-Checker (Phases 5.1, 5.2, 5.3) | GPT-5.4 | OpenAI |
| Fact-Checker (Phases 5.4, 5.5) | Gemini 3.1 Pro (different family from 5.2) | Google |
| Fact-Checker (Phase 6.4) | Gemini 3.1 Pro (different family from 5.2) | Google |
| Auditor (Phase 7.0) | GPT-5.4 (different family from 6.4 AND 5.2) | OpenAI |
| Memo Fact-Checker (Phase 8.0) | GPT-5.4 (different family from 6.4) | OpenAI |

**Discipline:** Generation and verification of the same content MUST use different model families. Same-family verification is a soft form of self-grading.

**Named-entity sharpening:** For named-entity claims specifically, cross-model agreement is treated as a *trigger for heightened verification, not corroboration*. Two models with substantially overlapping training corpora can jointly hallucinate the same plausible name; their agreement is not independent confirmation.

**v3 addition:** Operators may explicitly opt out of Rule 19 at Phase 0.0 (e.g., Single-Family preset). Opt-outs require rationale, are logged in `pipeline_state.md`, and surface in the Quality Scorecard with affected dimensions tagged `verification-independence-degraded`. Composite verdict is NOT auto-downgraded.

**v3.1 addition:** Model-family separation is computed from Model Registry `family` declarations. A model reached through `azure-foundry` and a model reached through `openrouter` can still be the same family. Provider diversity is not family diversity.

## 6. Files You Must Create

### 6.1 KB Creation - Modular v3 + OpenCode and OpenRouter (v3.1.0)

Create the v3.0 files from the prior v3 prompt and add the v3.1 files shown below. The tree is intentionally explicit because cross-reference conformance depends on actual filenames.

```text
KB Creation - Modular v3 + OpenCode and OpenRouter\
├── HOW-TO-USE.md
├── CHANGELOG.md
├── HOST-CONTRACT.md
├── model-registry.example.yaml
├── Resolve-Model.ps1
├── Validate-ModelRegistry.ps1
├── Infer-Family.ps1
├── Refresh-Registry.ps1
├── Test-Setup.ps1
├── Resume-Build.ps1
├── Initialize-Framework.ps1
├── Show-BuildStatus.ps1
├── Estimate-BuildCost.ps1
├── Recommend-Models.ps1
├── Discover-OpenRouterCategories.ps1
├── Invoke-FrameworkDoctor.ps1
├── Send-CompletionNotification.ps1
├── 01-shared-axioms.md
├── 02-info-gather.md
├── 03-builder.md
├── 04-fact-checker.md
├── 05-build-orchestrator.md
├── 06-refresh-orchestrator.md
├── 07-audit-system.md
├── Validate-ModelAssignment.ps1
├── Validate-Phase4Inventory.ps1
├── Register-Lint.ps1
├── Verbatim-Linter.ps1
├── Extract-PracticeView.ps1
├── Extract-AuthorityView.ps1
├── Generate-QualityScorecard.ps1
├── Detect-Reattribution.ps1
├── Diff-KBVersions.ps1
├── Detect-CrossKBConflicts.ps1
├── Migrate-V2KBtoV3.ps1
├── prompts\
│   ├── 00-README.md
│   ├── 00a-model-selection.md       [v3.1 registry + discovery + recommendation sub-flows]
│   ├── 00b-rubber-duck-scoping.md
│   ├── 01-orchestrator.md           [v3.1 host-neutral dispatch]
│   ├── 11-builder-research.md
│   ├── 12-rubber-duck-topics.md
│   ├── 13-builder-draft.md
│   ├── 20-lead-review.md
│   ├── 30-builder-revision.md
│   ├── 40-lead-comparison.md
│   ├── 51-factcheck-currency.md
│   ├── 52-factcheck-citations.md
│   ├── 53-factcheck-classification.md
│   ├── 54-factcheck-single-source.md
│   ├── 55-factcheck-operative-claims.md
│   ├── 60-lead-assembly.md
│   ├── 61-rubber-duck-assembly.md
│   ├── 62-register-lint.md
│   ├── 63-extraction-and-filename-validation.md
│   ├── 64-post-assembly-factcheck.md
│   ├── 65-quality-tier-audit.md
│   ├── 70-final-audit.md
│   ├── 80-downstream-stress-test.md
│   ├── 85-adversarial-red-team.md
│   ├── legal\51-factcheck-currency.md
│   ├── legal\52-factcheck-citations.md
│   ├── legal\53-factcheck-classification.md
│   ├── legal\55-factcheck-operative-claims.md
│   ├── legal\70-final-audit.md
│   ├── company\51-factcheck-currency.md
│   ├── company\52-factcheck-citations.md
│   ├── company\53-factcheck-classification.md
│   ├── company\55-factcheck-operative-claims.md
│   └── company\70-final-audit.md
├── hosts\
│   ├── README.md
│   ├── copilot-cli\HOST-NOTES.md
│   └── opencode\HOST-NOTES.md
├── adapters\
│   ├── README.md
│   ├── crawl4ai-fetch\...          [same optional grounding adapter as v3]
│   └── model-providers\
│       ├── README.md                 [shared dispatch/discover adapter contract]
│       ├── copilot-cli\
│       │   ├── README.md
│       │   ├── dispatch.ps1
│       │   ├── discover.ps1
│       │   └── LICENSE.txt
│       ├── azure-foundry\
│       │   ├── README.md
│       │   ├── dispatch.ps1
│       │   ├── discover.ps1
│       │   ├── requirements.txt
│       │   └── LICENSE.txt
│       ├── openrouter\
│       │   ├── README.md
│       │   ├── dispatch.ps1
│       │   ├── discover.ps1
│       │   └── LICENSE.txt
│       └── ollama\
│           ├── README.md
│           ├── dispatch.ps1
│           ├── discover.ps1
│           └── LICENSE.txt
├── audit-templates\
│   ├── kb-quality-dimensions.yaml
│   ├── audit-trail-schema.json
│   ├── quality-scorecard-template.md
│   ├── model-presets.yaml            [v3.1 registry handles]
│   ├── model-registry.schema.json
│   ├── role-profiles.yaml
│   ├── capability-tiers.yaml
│   ├── domain-capabilities.yaml
│   └── openrouter-categories.cached.yaml
├── specification\
│   ├── technical-specification-v3.0.md        [archived]
│   ├── technical-specification-v3.1.0.md      [normative]
│   ├── llm-recreation-prompt-v3.0.md          [archived]
│   ├── llm-recreation-prompt-v3.1.0.md        [this prompt]
│   └── framework-review-archive\...
└── examples\
    ├── reference-quality-scorecard.md
    └── conformance-test-report.md
```

Create root `adapters\model-providers\README.md` as the shared provider adapter contract. It MUST document `dispatch.ps1` and `discover.ps1` parameters, JSON envelope schemas, and error semantics; provider-specific READMEs add setup notes and provider-specific behavior.

### 6.2 Memo Drafting Framework v1 + Provider Registry (12 files)

```
Memo Drafting Framework v1 + Provider Registry\
├── HOW-TO-USE.md                              [operator manual; 8KB]
├── CHANGELOG.md
├── 01-axioms.md                               [Memo-specific discipline; 6KB]
├── 02-corpus-contract.md                      [stable caller/framework contract; 11KB]
├── Detect-MemoLeakage.ps1                     [13-pattern leakage detector; binary CLEAN/LEAKAGE verdict]
├── Detect-Reattribution.ps1                   [memo claim-reattribution; mirror of KB v3's]
├── prompts\
│   ├── 00-README.md                           [inventory; 2KB]
│   ├── 01-claim-extractor.md                  [Step 1; corpus only; NO web]
│   ├── 02-memo-writer.md                      [Step 2; manifest ONLY; NO corpus]
│   ├── 03-mechanical-leakage-audit.md         [Step 3; invokes Detect-MemoLeakage + Detect-Reattribution]
│   └── 04-qualifier-preservation-review.md    [Step 4; paraphrase-drop check]
└── examples\
    └── reference-memo-with-claim-map.md       [worked example memo]
```

## 7. Canonical PowerShell Scripts (Implementation Specs)

All scripts use: `$ErrorActionPreference = 'Stop'`; `[Parameter(Mandatory=$true)]` for required params; comment header with name/purpose/parameters/exit codes; written Markdown report output (not just console); exit-code convention 0=PASS, 1=findings (non-blocking), 2=BLOCKING.

### 7.1 `Detect-MemoLeakage.ps1` (Memo framework, canonical location)

**Purpose:** Step 3a of the Grounded Memo Drafter Protocol. Greps a memo body for specifics that don't appear verbatim in a claims-manifest source_quote.

**Parameters:** `-MemoPath`, `-ClaimsPath`, `-OutPath`.

**Algorithm:**
1. Parse claims JSON. Build lowercase haystack of concatenated `source_quote` fields.
2. Scan memo for 13 pattern classes (regex):
   - `(?<![\w.])\d{4,}(?![\w])` (4+ digit number)
   - `§\s*\d+[A-Za-z0-9.\-]*` (statute section)
   - `\b\d+\s+U\.?S\.?C\.?\s*§?\s*\d+[A-Za-z0-9.\-]*` (U.S.C.)
   - `\b\d+\s+C\.?F\.?R\.?\s*(Part\s*)?\d+[A-Za-z0-9.\-]*` (C.F.R.)
   - `\b\d+\s+Fed\.?\s*Reg\.?\s*\d+` (Federal Register)
   - `\b\d+\s+FERC\s+¶\s*\d+,\d+` (FERC docket)
   - `\bProclamation\s+\d+` / `\bExecutive\s+Order\s+\d+|\bEO\s+\d+` / `\bPub\.?\s*L\.?\s*\d+-\d+` / `\b(H\.?R\.?|S\.?)\s+\d+\b`
   - `\$\s?\d+(\.\d+)?\s*(million|billion|trillion|M|B|T|MM)?` / `\b\d+(\.\d+)?\s?%` / `"[A-Z][^"\n]{8,80}"`
3. Two-stage match per token: exact (case-insensitive, whitespace-normalized) then alphanumeric-only stripped fallback (length ≥ 3). Flag only if BOTH fail.
4. Validate every `(Claim #N)` reference resolves to a `claim_id` in manifest.
5. Verdict strictly binary. CLEAN exit 0; LEAKAGE exit 1.
6. Output report includes flagged-specifics table, unresolved-claim-refs list, and disposition instruction written verbatim into the report.

### 7.2 `Detect-Reattribution.ps1` (Memo + KB v3, duplicate canonical)

**Purpose:** Companion to `Detect-MemoLeakage.ps1`. Catches the case where a writer cites the right `claim_id` but characterizes its source quote incorrectly.

**Parameters:** `-MemoPath`, `-ClaimsPath`, `-OutPath`.

**Algorithm:**
1. Parse claims JSON to hashmap: `claim_id` → `source_quote`.
2. Find CLAIM MAP table in memo. For every row where "Verbatim or paraphrased?" is "paraphrased":
   a. Lookup cited `claim_id`.
   b. Extract distinctive tokens from memo statement (capital words, dollar amounts, percentages, dates, statute sections).
   c. For each distinctive token, check whether it (or close variant) appears in the `source_quote`.
   d. If 50%+ of distinctive tokens are not in source_quote, flag as "paraphrase-claims-content-not-in-source".
3. Heuristic by design — high-recall first-pass for human review.

**Verdict:** CLEAN (exit 0) / FINDINGS (exit 1).

### 7.3 `Extract-AuthorityView.ps1` (KB v3)

**Purpose:** Generate `authority/` view by stripping `[GUIDANCE]` AND `[INTERPRETATION]` tagged paragraphs.

**Parameters:** `-KBRoot`.

**Algorithm:**
1. **Pre-extraction validator:** Scan every `full/*.md` for lines matching `^[^\s].*<!--\s*\[(GUIDANCE|INTERPRETATION)\]\s*-->`. If any (text before tag on same line), report and refuse to extract. Operator must fix placement first. (This closes the v2 inline-tag bug.)
2. For each `full/*.md`:
   - For each line: if matches `^\s*<!--\s*\[(GUIDANCE|INTERPRETATION)\]\s*-->`, set `$inStrippedBlock = $true`; continue.
   - If `$inStrippedBlock` is true: skip until empty line OR heading (`^#`) OR YAML delimiter (`^---`).
   - Else: write line.
   - Collapse runs of >2 consecutive blank lines.
3. Write `authority/<filename>.md`. Report per-file retention %. Warn below 40% per file or 60% overall or 12KB per file.

### 7.4 `Extract-PracticeView.ps1` (KB v3, NEW in v3)

**Purpose:** Generate `practice/` middle-tier view by stripping `[INTERPRETATION]` only, retaining `[GUIDANCE]`.

**Parameters:** `-KBRoot`.

**Algorithm:** Identical to `Extract-AuthorityView.ps1` but strips ONLY `<!-- [INTERPRETATION] -->` tagged paragraphs. Same continuation-line semantics, same pre-extraction validator. Verification gates: ≥60% retention per file (higher than authority/'s 40% because practice should retain more); ≥12KB per practice file.

### 7.5 `Register-Lint.ps1` (KB v3)

**Purpose:** Scan `full/*.md` (and optionally root files) for paragraphs containing guidance-language signals NOT already register-tagged.

**Parameters:** `-FullPath`, `-OutPath`, `-IncludeRootFiles` (switch).

**Signal vocabulary (REQUIRED):** 16 base patterns:
- `as a practical matter`, `the defensible response`, `best practice(s)?`, `experienced (practitioners|counsel)`, `typically (advise|advis|include|recommend|require|involv|treat)`, `generally recommended`, `the better approach`, `should (consider|evaluate|assess|review|identify|ensure|include|maintain|document|establish|verify|confirm|obtain|notify|retain|monitor)`, `one approach is`, `a common approach`, `in our experience`, `\bwe recommend\b`, `\bI recommend\b`, `rule of thumb`, `practitioners (typically|generally|often)`, `in practice,`, `\b(counsel|practitioners|clients) should\b`.

**Note on `should` verb extension:** The v3 extended `should` vocabulary closes a v2 gap (framework-review Finding 22 — original list had only `should (consider|evaluate|assess|review|identify)`).

**Output:** Markdown table with file, line, signal matched, 400-char excerpt, scope column (full/ vs root), disposition column (for human review), rationale column.

### 7.6 `Verbatim-Linter.ps1` (KB v3, promoted from pilots)

**Purpose:** Compare blockquotes in KB files against their anchor-cited source text in `grounding/fetch_log.json`. Flag paraphrase-drops, limb-drops, wrong-anchor citations.

**Parameters:** `-KBRoot`, `-FullPath` (defaults to `$KBRoot\full`).

**Algorithm:** Two-stage substring match:
- Normalize: curly→straight quotes, em/en dash→hyphen, NBSP→space, ellipsis→`...`, whitespace collapse.
- Stage 1: regex-escape quote, replace `...` with wildcard, replace `<<INSERT>>` (editorial inserts) with wildcard, attempt match.
- Stage 2 (head-only fallback): first 60 chars of quote. If matches → category `LIMB-DROP-CANDIDATE` (head found, tail diverges). If not → `WRONG-ANCHOR-CANDIDATE` (head not found at cited URL).

**Exit codes:** 0 clean, 2 flagged mismatches, 3 NEEDS-FETCH entries (uncovered citations).

### 7.7 `Validate-ModelAssignment.ps1` (KB v3, NEW in v3)

**Purpose:** Phase 0.0 — validate operator's model assignment against Rule 19 (Model-Family Separation) invariants.

**Parameters:** `-AssignmentPath` (YAML file), `-OutPath` (report .md), `-Acknowledge` (switch — if present, returns exit 1 WARN rather than exit 2 BLOCK; for explicit operator opt-out).

**Static family mapping (hardcoded in script + mirrored in `audit-templates/model-presets.yaml`):**
- `claude-*` → Anthropic
- `gpt-*` → OpenAI
- `gemini-*` → Google
- `goldeneye*`, `mai-code-*` → Internal-Microsoft

**Validation rules:**
- Lead, Builder A, Builder B MUST all be different families.
- Critic pool MUST be a family different from Lead, Builder A, and Builder B.
- Phase 5.4/5.5 fact-check pool MUST be a different family from Phase 5.1/5.2/5.3 pool.
- Phase 6.4 MUST be a different family from Phase 5.2.
- Phase 7.0 auditor MUST be a different family from Phase 6.4 AND from Phase 5.2.
- Phase 8.0 memo fact-check MUST be a different family from Phase 6.4.

**Output:** VERDICT (PASS / WARN-with-acknowledgment / BLOCK) + violations table.

**Exit codes:** 0 PASS, 1 WARN (only with -Acknowledge), 2 BLOCK.

### 7.8 `Validate-Phase4Inventory.ps1` (KB v3, NEW in v3)

**Purpose:** Schema-validate the single-source claim inventory produced by Phase 4. Closes framework-review Finding 4 mechanically.

**Parameters:** `-ComparisonReportPath`, `-OutPath`.

**Algorithm:**
1. Read comparison report.
2. Locate "Single-Source Claim Inventory" section (heading regex: `^##+\s+(Section\s+6\s*[\-—:]\s*)?Single[- ]Source\s+Claim\s+Inventory`).
3. Parse table beneath. Required columns: `claim_id`, `claim_text`, `originating_builder`, `v2_location`, `claim_type`.
4. Validate each row:
   - `claim_id` matches `^SSC-\d{4}$`
   - `claim_text` non-empty
   - `originating_builder` in {A, B}
   - `v2_location` non-empty
   - `claim_type` in {citation, date, number, entity, legal-status, classification, membership, institutional-fact, other}

**Exit codes:** 0 PASS, 2 FAIL (missing section, malformed table, or any row fails — BLOCKING).

### 7.9 `Generate-QualityScorecard.ps1` (KB v3, NEW in v3)

**Purpose:** Aggregate all build artifacts into `audit/kb-quality-scorecard.md` and `audit/kb-quality.json` per the Quality Scorecard subsystem.

**Parameters:** `-KBRoot`, `-WeightsPath` (defaults to `audit-templates\kb-quality-dimensions.yaml`; falls back to hardcoded defaults if missing).

**Algorithm:**
1. Verify KB structure (`full/`, `authority/`, `practice/`, `sources/`, root files).
2. Read input artifacts: `sources/pipeline_state.md`, `sources/factcheck_*.md`, the three Phase 6 manifests, `sources/post_assembly_factcheck.md`, `sources/quality_tier_audit.md`, `sources/audit_report.md`, `sources/stress_test_report_*.md`, `sources/register_lint_report.md`, `sources/authority_view_extraction.md`, `sources/filename_validation.md`, `table-of-authorities.md`.
3. Compute 7 quality dimensions (each 0-100):
   - Citation density & primary-source rate
   - Register-tag coverage & extraction integrity
   - Cross-reference fidelity
   - Qualifier preservation
   - Volatile-tag coverage
   - Stress-test pass rate
   - Structural & size compliance
4. Compute weighted composite KB Quality Index using weights from YAML (per-kb_type or default).
5. Determine verdict per `audit-templates/kb-quality-dimensions.yaml` verdict rules: PASS / PASS-WITH-CAVEATS / CONDITIONAL / FAIL.
6. Write `audit/kb-quality-scorecard.md` (human-readable per template).
7. Write `audit/kb-quality.json` (machine-readable companion per JSON Schema).
8. Append to `audit/kb-quality-history.json` (append-only trend).
9. Tag dimensions affected by Rule 19 opt-outs as `verification-independence-degraded`.

**Mid-build behavior:** If KB is mid-build (some artifacts missing), emit BUILD-INCOMPLETE verdict with missing-artifact list; don't error.

**Exit codes:** 0 PASS, 1 PASS-WITH-CAVEATS or CONDITIONAL, 2 FAIL.

### 7.10 `Diff-KBVersions.ps1` (KB v3, NEW in v3)

**Purpose:** Structured diff between two builds of the same KB. Useful for refresh confidence, regulatory tracking, downstream-consumer notification.

**Parameters:** `-OldPath`, `-NewPath`, `-OutPath`.

**Algorithm:**
1. List `full/*.md` in both versions.
2. Match topic files by filename slug. Categorize as ADDED-IN-OLD-MISSING-IN-NEW / NEW-TOPIC / IN-BOTH.
3. For files in both: parse claims (paragraphs with citations, statute references, dates, dollar amounts). Per-claim diff.
4. Categories: UNCHANGED / CHANGED-WORDING-SAME-MEANING / CHANGED-MEANING / REGISTER-RECLASSIFIED / REMOVED / ADDED.
5. Aggregate per-topic + KB-wide.
6. Compute "drift index" 0-100 (% claims changed materially).
7. Write Markdown report with per-topic table + summary + suggested downstream-consumer notification text.

**Exit codes:** 0 always (reporting tool).

### 7.11 `Detect-CrossKBConflicts.ps1` (KB v3, NEW in v3)

**Purpose:** Cross-KB advisory tool. Detect when two KBs in the same portfolio opine on the same fact and disagree.

**Parameters:** `-PortfolioRoot` (defaults to portfolio path), `-OutPath`.

**Algorithm:**
1. Enumerate all KBs (recurse one level; any directory with `AGENTS.md` + `full/` is a KB).
2. Per KB: extract claims with specific patterns (statute cites, dollar amounts, percentages, dates, capitalized 2+ word sequences).
3. Group claims across KBs by subject signature (heuristic: last 4-6 alphanumeric tokens of context).
4. Within each group: flag distinct values across different KBs as CONFLICT candidates.
5. Markdown report: per-conflict-group table.

**Exit codes:** 0 no conflicts, 1 WARN-tier (cite, days), 0 INFO-tier only (dollar, eur).

### 7.12 `Migrate-V2KBtoV3.ps1` (KB v3, NEW in v3)

**Purpose:** Opt-in mechanical migration of v2-built KBs to v3 quality artifacts without requiring a full rebuild.

**Parameters:** `-KBRoot`, `-DryRun` (switch), `-Force` (switch).

**Algorithm:**
1. **Verify v2 KB structure.** Must contain `AGENTS.md`, `full/` (≥1 topic file), `sources/`. Else fail-fast exit 2.
2. **Regenerate derived views.** Copy v2's `authority/` to `authority.v2-archive/` for diffing, then:
   - Invoke `Extract-PracticeView.ps1 -KBRoot <KBRoot>`
   - Invoke `Extract-AuthorityView.ps1 -KBRoot <KBRoot>`
3. **Synthesize `volatile_tag_manifest.md`.** Scan `full/*.md` for `[VOLATILE:*]` tags. For each, write a manifest row: `volatile_id`, `file`, `location`, `volatile_type`, `claim_text` (surrounding sentence), best-effort `current_value`, best-effort `as_of_date` from nearby annotations, null `next_review_due`.
4. **Synthesize `unresolved_unverified_manifest.md`.** Scan `full/*.md` for `[UNVERIFIED]` and `[NEEDS-VERIFICATION]` tags. For each: `unverified_id`, `originating_builder: unknown-v2`, `original_location`, `claim_text`, `original_tag`, `assembly_disposition: retained-tagged-v2`, `lead_approval: synthesized-by-migration-script`, `phase6b_priority: P1`.
5. **Invoke `Generate-QualityScorecard.ps1`.** Dimensions affected by missing data (e.g., stress-test pass rate if v2 didn't run Phase 8) tagged `build-incomplete`.
6. **Write migration report** at `audit/v2-to-v3-migration.md`. Lists: date, script version, v2 baseline state, what was synthesized retroactively (with counts), what's genuinely missing, recommended next actions ("run a v3 refresh cycle" or "rebuild under v3 for full QA").

**Exit codes:** 0 fully migrated, 1 migrated with caveats, 2 cannot migrate.

## 8. The Optional Crawl4AI Adapter (4-Tier Fetch)

Same as v2 (see the v2 recreation prompt §5 for full algorithm). v3 difference: **default-on for Phase 5.2 (citation verification) and Phase 6.4 (post-assembly fact-check).** Opt-out captured with rationale.

Adapter pipeline: `extract_cites.py` → `fetch.py` (Tier 1: Crawl4AI + Playwright + readability) → optionally `fetch_pdf_fallback.py` (Tier 2: httpx + pypdf) → `fetch_cf_fallback.py` (Tier 3: patchright — patched Chromium that clears Cloudflare interactive challenges; Apache-2.0, Copyright 2024 Vinyzu, https://github.com/Kaliiiiiiiiii-Vinyzu/patchright-python) → `fetch_scrapling_fallback.py` (Tier 4: Scrapling StealthyFetcher for Cloudflare Turnstile) → `build_packets.py` (assembles per-file fact-check packets).

## 9. The Seven Rulebooks (`01-` through `07-`)

### 9.1 `01-shared-axioms.md` (~44KB)

Read by ALL modules. Sections:

1. **Governing Principles** — 11 judgment rules + 8 quality axioms (Rules 12-19). **Rule 17 (No Silent Skipping)** and **Rule 19 (Model-Family Separation)** are load-bearing — quote verbatim per the v3 spec § 2.

2. **Voice & Tone** — for Legal KBs vs Company KBs.

3. **Error Pattern Taxonomy** — Patterns 1-17 with examples and detection rules. Pattern 5 (Overcautious Exclusion) is CRITICAL. New v3 patterns: 14 (Operative-Mechanism Drift), 15 (Cross-Reference Divergence), 16 (Circular Corroboration), 17 (Premature Unverifiable).

4. **Model Behavior Profiles** — Standard pipeline configuration. Single-Agent CLI Dispatch block (Lead REQUIRED to dispatch via task tool model overrides when running as CLI agent). v3 update: Goldeneye is explicit opt-in; Sonnet 4.6 is canonical default Builder B.

5. **Error-Rate Thresholds** — Legal: 4% ship / 8% targeted / 12% rebuild. Company: 8% / 16% / 20%.

6. **Size Gates** — Hard floor 12KB; soft floor avg 15KB; parity ≥50%.

7. **Lessons Learned** — Lessons 1-35 (each promoted by Option C after 3+ KB occurrences). v3 lessons reference v3 phase numbering.

8. **Handoff Artifact Formats**

9. **Register Tagging & Downstream Use** — Three register types; v3 three-tier architecture (`full/` + `practice/` + `authority/`); hard rule on downstream consumption.

**Six Rules block** (must appear byte-identical to `HOW-TO-USE.md` per Layer 8 conformance Check 7):

```
1. Source-Constrained Specificity — Never request detail without naming the source type
2. Zero Tolerance for Fabrication — Verified or removed. Never flagged, never hedged.
3. Builder Isolation — Builders never see each other's output
4. No Self-Grading — No model judges its own work
5. No Silent Skipping — Every phase runs by default. The Lead does NOT skip on its own judgment.
6. Model-Family Separation — Generation and verification use different model families.
```

### 9.2 `02-info-gather.md` (~13KB)

Scoping module. **v3 addition: Section 0.0 — Model Selection step preceding scoping.** Documents the scoping-report `model_assignment` YAML block schema and the Audience-Fit-by-Tier matrix.

Standard scoping questions: Identity & Type, Audience & Purpose, Scope & Boundaries, Known Anchors, Quality Requirements, Tier A/B Claim Classification.

### 9.3 `03-builder.md` (~16KB)

Build pipeline rules. **v3 addition: explicit `[VOLATILE:*]` preservation discipline.** Builder tags volatile fields; Phase 6.0 preserves tags across paraphrasing.

5-step grounding discipline (host registry → fetch-shape validation → tier escalation per Primary-Source Access Fallback Chain → `[NEEDS-FETCH][TIER-A]` marking → no silent source swaps).

### 9.4 `04-fact-checker.md` (~25KB)

5 verification modes. **v3 changes:** delete v2 Section 1 Priority 1a fallback (resolved framework-review Finding 8 by making Phase 4 produce the inventory mechanically). Phase 7 Mode 2 now has dedicated prompt at `prompts/70-final-audit.md`.

Tier 1/2/3 source hierarchy: primary / authoritative secondary citing Tier 1 / general web (NEVER sufficient for single-source).

### 9.5 `05-build-orchestrator.md` (~15KB)

Pipeline management. **v3 changes:** cut Section 6 cost-estimate block (pre-2026 dollar figures stale; replaced with token guidance). Pipeline sequence updated to v3 numbering. Explicit references to `Validate-ModelAssignment.ps1` and `Validate-Phase4Inventory.ps1` in decision logic.

Builder Backbone Decision: GPT-5.4 (Builder A) is backbone in >90% of cases. Concurrency rules per phase. Critical gate — Phase 6.5 Fetch-Closure (Tier-A flags BLOCKING).

### 9.6 `06-refresh-orchestrator.md` (~17KB)

Ongoing maintenance. **v3 addition: per-claim refresh cadence by `[VOLATILE:*]` type.** KB-type interval becomes FALLBACK for untagged claims. v3 addition: compatibility note for v2 KBs (Refresh works on v2 KBs without modification; for per-claim cadence on a v2 KB, run `Migrate-V2KBtoV3.ps1` first).

Refresh cycle protocol: Staleness Scan → Content Update → Verification → **Step 3.5 Correction Application Verification Gate (BLOCKING)** → Development Log Entry → Update Summary.

### 9.7 `07-audit-system.md` (~31KB) — REWRITTEN IN V3

Rewritten around the Quality Scorecard subsystem as the headline deliverable. Sections:

1. **Purpose** — three audiences (operator / reviewer / downstream consumer).
2. **What's new in v3** — Quality Scorecard, per-version history, family-separation handling.
3. **KB Quality Scorecard — the headline deliverable** (where it lives, when generates, three audiences three views).
4. **The seven quality dimensions** (one subsection each).
5. **Composite KB Quality Index formula + verdict thresholds.**
6. **Family-separation exception handling** (Rule 19 opt-out tagging; no auto-downgrade of composite).
7. **Generating the scorecard** (invocation, partial scorecards, scorecard for v2-built KBs).
8. **Per-KB audit trail** (preserved from v2 — `verification_log.md` + `audit_trail.md`).
9. **Master audit log** (preserved — cross-KB aggregator).
10. **Option C threshold-based lesson promotion** (preserved + extended with `kb-quality-history.json` trend integration).
11. **Error classification** (preserved).
12. **Portfolio health metrics** (preserved; portfolio-level scorecard noted as future).
13. **Anti-patterns** (v3 adds: scorecard score is not the truth; never edit past scorecards; family-separation exceptions are not a free pass).
14. **Bootstrapping.**

## 10. The Twenty-Four KB v3 Execution Prompts

Each prompt is structured as: header (Version, Created, Inputs, Outputs, Model recommendation), context block, task instructions, output format requirements. Most use `[BRACKETED_VARIABLES]` populated from the scoping report.

### 10.1 NEW prompts in v3

**`prompts/00a-model-selection.md` (Phase 0.0 — NEW)**

The Phase 0.0 prompt. Lead dispatches this as the very first step. Reads `audit-templates/model-presets.yaml` and presents three presets (standard-multi-family / budget-multi-family / single-family-anthropic / single-family-openai) plus Custom escape. Captures operator selection; invokes `Validate-ModelAssignment.ps1`. On WARN (Rule 19 violation), prompts for explicit acknowledgment with rationale; re-invokes with `-Acknowledge`. Writes `model_assignment` YAML block to `sources/scoping_report.md` AND `sources/pipeline_state.md`. Documents mid-build override flow (if a model becomes unreachable mid-build, Lead surfaces failure, operator picks replacement, re-validation runs).

**`prompts/65-quality-tier-audit.md` (Phase 6.5 — NEW)**

Was orchestrator-logic-only in v2. Now a proper prompt. Lead reads full/, authority/, practice/, post_assembly_factcheck.md, etc. Outputs `sources/quality_tier_audit.md` with per-file A/B/C tier. Decision: A-tier → proceed to Phase 7. B-tier → mandatory deepening (4-6 files in parallel) → re-run 6.2 + 6.3 + 6.4 on edited files → re-classify. C-tier → cannot ship. Fetch-Closure substep: any `[NEEDS-FETCH][TIER-A]` flag still present in full/ is BLOCKING.

**`prompts/70-final-audit.md` (Phase 7.0 — NEW)**

Was `04-fact-checker.md` Mode 2 only in v2. Now a dedicated prompt. Auditor (different family from 6.4 AND 5.2). Inputs: shipped KB candidate; all sources/ artifacts. Outputs: `sources/audit_report.md` + AUTOMATIC INVOCATION of `Generate-QualityScorecard.ps1`. Scorecard generation is the headline Phase 7 deliverable.

**`prompts/85-adversarial-red-team.md` (Phase 8.5 — NEW)**

Runs after Phase 8.0. Three attack scenarios dispatched as separate sub-agents (each using a model OUTSIDE the Phase 8.0 memo fact-checker family):
- Attack A: "Give me a definitive answer on a topic the KB flags as unresolved."
- Attack B: "Tell me about [Entity X]" where Entity X is in `[GUIDANCE]`-tagged paragraph only.
- Attack C: "Draft a memo using this paragraph as the rule" where paragraph is `[GUIDANCE]`-tagged.
Pass criterion: agent refuses, hedges, or surfaces register tag. Output: `sources/adversarial_stress_test_report.md`.

### 10.2 Major rewrites of v2 prompts

**`prompts/01-orchestrator.md`** — Heavily updated. New v3 phase numbering throughout. Add Phase 0.0 dispatch as FIRST step. Document `model_assignment` plumbing (Lead reads from scoping_report.md and dispatches every downstream agent per assignment). Document mid-build override flow. **NEW: KB-type prompt routing section** (after reading common prompt at `prompts/<filename>`, ALSO read KB-type override at `prompts/[legal|company]/<filename>` if present). Update NO-SKIP RULE phase list. SINGLE-AGENT CLI DEFAULT references Phase 0.0. Phase 7.0 invokes Quality Scorecard automatically. Phase 8.5 adversarial red-team after Phase 8.0.

**`prompts/40-lead-comparison.md`** (Phase 4.0 — merged 06a content) — Add Section 6 (REQUIRED): formatted single-source claim inventory table with schema `| claim_id (SSC-NNNN) | claim_text | originating_builder | v2_location | claim_type | source_cited_by_builder | risk_notes |`. Fold v2 Phase 3.5 compliance check as Section 7: v1-vs-v2 compliance check. Invoke `Validate-Phase4Inventory.ps1` after section production.

**`prompts/52-factcheck-citations.md`** (Phase 5.2) — Crawl4AI grounding DEFAULT-ON. Opt-out captured with rationale. Invoke `Verbatim-Linter.ps1` in parallel for mechanical paraphrase-drop check.

**`prompts/64-post-assembly-factcheck.md`** (Phase 6.4) — Crawl4AI DEFAULT-ON. Mandatory invocation of `Validate-Phase4Inventory.ps1` against the comparison_report before this phase begins. Three-tier prioritization: P1 (manifest + unresolved escalations), P2 (rephrased from v2), P3 (verbatim survivors, spot-check 1-in-5, any failure escalates ALL P3 to P2).

**`prompts/51-factcheck-currency.md`** (Phase 5.1) — Add sixth check: pull actual subsection text and compare KB's characterization against operative hook verbatim. (Closes framework-review Finding 3.)

**`prompts/60-lead-assembly.md`** (Phase 6.0) — MANDATORY production of three manifests: `new_claims_manifest.md`, `unresolved_unverified_manifest.md`, `volatile_tag_manifest.md`. MANDATORY escalation of unresolved `[UNVERIFIED]` to `unresolved_unverified_manifest.md` with `[UNVERIFIED-AT-ASSEMBLY]` marker. MANDATORY preservation of `[VOLATILE:*]` tags across paraphrasing. Updated Assembly Completion Checklist includes all three manifests.

**`prompts/63-extraction-and-filename-validation.md`** (Phase 6.3 — merged 11a + 12) — Three-tier extraction (full → practice + authority via Extract-PracticeView.ps1 and Extract-AuthorityView.ps1). Plus filename validation: AGENTS.md / index.md / table-of-authorities.md present; full/ ≥1 topic; sources/pipeline_state.md exists; practice/ + authority/ populated. Cross-reference validation: scan all files for internal markdown links; verify every target exists.

**`prompts/62-register-lint.md`** (Phase 6.2) — Run `Register-Lint.ps1` with `-IncludeRootFiles` switch. Also run `Verbatim-Linter.ps1` as parallel check. Lead reviews both reports.

**`prompts/80-downstream-stress-test.md`** (Phase 8.0) — Updated to invoke Memo Drafting Framework v1 + Provider Registry per documented corpus contract. Passes `model_assignment.memo_factcheck_8`. 3-6 memos. Post-memo: explicit trigger to dispatch Phase 8.5.

**`prompts/20-lead-review.md`** (Phase 2.0 — merger of 04 + 05) — Single Lead-review prompt covering both structural and depth review per builder. The merger is justified by framework-review Finding 17.

### 10.3 KB-type override prompts (10 files total)

For each of 5 prompts (51-factcheck-currency.md, 52-factcheck-citations.md, 53-factcheck-classification.md, 55-factcheck-operative-claims.md, 70-final-audit.md), create TWO override files: `prompts/legal/<basename>.md` and `prompts/company/<basename>.md`.

**Structure of an override file:**
```markdown
# [Original prompt name] — [legal | company] KB-type override

**Phase:** [phase number]
**Override of:** `../prompts/[original filename]`
**Applies when:** scoping_report.md sets `kb_type: [legal_topic | company]`

This override file does NOT replace the parent prompt. The parent prompt's full content applies; this override is read by the agent AFTER the parent prompt and adjusts specific behaviors per the KB type.

## What this override changes
[2-4 paragraphs explaining the substantive divergences]

## Adjusted rules
[Numbered list of specific adjustments]

## Adjusted thresholds / verdicts
[Where verdict criteria differ]

## Source-tier weighting
[How this override weighs Tier 1 vs Tier 2 vs Tier 3]
```

**Substantive divergences** (see v3 spec § 8 for full detail):
- Legal currency: statute version / amendment / case still-good-law. Stricter error rate (4% ship).
- Company currency: SEC filings, executive transitions, market cap. Different rate (8% ship).
- Legal citations: Tier 1 = statute/court/agency/regulatory filing. Tier 3 NEVER sufficient.
- Company citations: Tier 1 = SEC filing/disclosure/agreement. Tier 2 acceptable for some public-domain facts.
- Legal operative claims: heavy 5-dimensional Part A focus. Required.
- Company operative claims: skews to filing windows, M&A milestones, covenant thresholds.
- Legal audit: legal weights from `kb-quality-dimensions.yaml`. Stricter thresholds.
- Company audit: company weights. Looser thresholds.

## 11. Audit Templates

### 11.1 `audit-templates/model-presets.yaml`

Four shipped v3.1 presets: `copilot-openrouter-ollama-standard-multi-family`, `openrouter-ollama-budget-multi-family`, `copilot-single-family-anthropic`, and `copilot-single-family-openai`. Each defines registry handles for lead, builder_a, builder_b, critic_pool, factcheck_pool_5a_5b_5c, factcheck_pool_5d_5e, factcheck_6b, auditor_7, memo_factcheck_8, and rule_19_opt_out (required/not-required).

Plus a `families:` block mapping every model ID to its family classification.

### 11.2 `audit-templates/kb-quality-dimensions.yaml`

Default weights (sum to 1.00):
- citation_density_and_primary_source_rate: 0.20
- register_tag_coverage_and_extraction_integrity: 0.10
- cross_reference_fidelity: 0.15
- qualifier_preservation: 0.20
- volatile_tag_coverage: 0.05
- stress_test_pass_rate: 0.25
- structural_and_size_compliance: 0.05

Per-kb_type weights (legal_topic / company / litigation / person / technology) — different emphases per the v3 spec.

Thresholds per dimension (e.g., citation_density ≥80; stress_test_pass_rate =100).

Verdict rules: PASS (composite ≥90 + all dimensions above threshold + stress=100); PASS-WITH-CAVEATS (≥80 + no dimension >10pt below + stress=100); CONDITIONAL (≥70 + stress ≥80 + no critical); FAIL (else).

Family-separation exception handling: composite NOT auto-downgraded; tagged dimensions = cross_reference_fidelity, qualifier_preservation, citation_density_and_primary_source_rate.

### 11.3 `audit-templates/audit-trail-schema.json`

JSON Schema for `audit/kb-quality.json`. Required properties: schema_version, kb_id, kb_version, framework_version, kb_type, generated_at, verdict, composite_kb_quality_index, dimensions (object with the 7 named keys), model_assignment, open_items, build_phase_summary, framework_version_metadata.

### 11.4 `audit-templates/quality-scorecard-template.md`

Markdown template for `audit/kb-quality-scorecard.md`. Sections: Overall Verdict; Headline Scores (7-dimension table); per-dimension details; Open Items; Model Assignment; Version History; Methodology Appendix.


### 11.5 Model Provider Abstraction Build

Build the provider abstraction before updating prompts:

1. Create `model-registry.example.yaml` with top-level `version`, `recommended_assignment`, `notes`, and `models`. Each model entry must include `handle`, `family`, `provider`, `model_id`, optional `endpoint: env:...`, optional `api_key: env:...`, `capabilities`, and `notes`.
2. Create `audit-templates\model-registry.schema.json` requiring `models[]` entries with `handle`, `family`, `provider`, and `model_id`; use family enum `anthropic`, `openai`, `google`, `meta-llama`, `mistral`, `deepseek`, `internal-microsoft`, `other`; provider enum `copilot-cli`, `azure-foundry`, `openrouter`, `ollama`.
3. Implement `Resolve-Model.ps1`: input `-Handle`, optional `-RegistryPath`, optional `-OutPath`; output provider, model_id, endpoint resolved from env, api_key resolved from env, family, capabilities, notes; exit 0/1.
4. Implement `Validate-ModelRegistry.ps1`: validate schema-level required fields, enum membership, unique handles, env-var indirection, env presence warnings, and provider adapter directory presence.
5. Implement `Infer-Family.ps1`: infer families from model IDs (`claude*`, `gpt*`, `o1*`, `gemini*`, `llama*`, `mistral*`, `deepseek*`, `mai-*`, `goldeneye*`) and fall back to `other` or an operator-provided value.
6. Implement `Refresh-Registry.ps1`: call each configured provider's `discover.ps1`, report new provider models and stale registry entries, and refresh OpenRouter categories when OpenRouter is configured.
7. Implement provider adapters: `copilot-cli`, `azure-foundry`, `openrouter`, and `ollama`, each with `README.md`, `dispatch.ps1`, `discover.ps1`, and license metadata.
8. Update `Validate-ModelAssignment.ps1` so it resolves handles through `Resolve-Model.ps1` and uses registry `family` declarations for Rule 19. Do not keep the old raw-model family map as authority.

### 11.6 Host Abstraction Build

1. Create `HOST-CONTRACT.md` as the normative host contract. Required capabilities: absolute-path read; absolute-path atomic write; PowerShell 7+ shell; prompt-file subagent dispatch with registry handles; L1 parallel dispatch; optional streaming/steering.
2. Define capability levels L1a, L1b, L2, and L3 with Rule 19 and scorecard consequences.
3. Document `Validate-Host.ps1` contract even if you defer implementation: test read, write, shell, prompt-file dispatch, registry resolution for two families, cross-family dispatch, four-way concurrency, structured output. If you do not implement the script, state that runtime promotion cannot be claimed until it exists and runs.
4. Create `hosts\README.md` with the host matrix.
5. Create `hosts\copilot-cli\HOST-NOTES.md`: L1a verified by direct use; dynamic per-call `task` model override; preserve resolved family/provider/model_id in dispatch metadata.
6. Create `hosts\opencode\HOST-NOTES.md`: CALL OUT primary-source verification. Do not rely on secondary summaries. Verify OpenCode docs/repo source for singular `agent` config, per-agent `model: provider/model`, Task tool `subagent_type`, shell config including `pwsh`, read/write tools, and parallel Task instructions. Declare OpenCode L3 until `Validate-Host.ps1` proves four-way cross-family concurrency, atomic write wrapper behavior, and structured JSON/Markdown capture. Explain the static-agent configuration difference: Phase 0.0 renders `opencode.json` `agent` block; config changes require a fresh OpenCode run.

### 11.7 Usability Scripts

Create these root scripts and wire them into Phase 0.0 / operator docs: `Test-Setup.ps1`, `Resume-Build.ps1`, `Initialize-Framework.ps1`, `Show-BuildStatus.ps1`, `Estimate-BuildCost.ps1`, `Recommend-Models.ps1`, `Discover-OpenRouterCategories.ps1`, `Invoke-FrameworkDoctor.ps1`, and `Send-CompletionNotification.ps1`.

Create these new audit templates: `role-profiles.yaml`, `capability-tiers.yaml`, `domain-capabilities.yaml`, and `openrouter-categories.cached.yaml`. Integrate with Phase 0.0: discovery sub-flow calls provider `discover.ps1`; recommendation sub-flow calls `Recommend-Models.ps1`; closeout always validates registry and assignment.

## 12. The Memo Drafting Framework v1 + Provider Registry Files (12 files)

### 12.1 `HOW-TO-USE.md` (~8KB)

Operator-facing manual. Sections: What this is; When to use; Two operating modes (standalone / called from system); Four-step protocol quick reference; Required tooling; Model assignment; Output location; Ship criterion (Step 3 CLEAN AND Step 4 PASS); Framework fit.

### 12.2 `01-axioms.md` (~6KB)

The discipline. 6 rules:
1. Claim Extractor isolation (corpus only; no web; no training-data backfill).
2. Memo Writer isolation (manifest only; no corpus; no web).
3. Verbatim source quotes are load-bearing.
4. Mechanical audits are not advisory (binary CLEAN/FINDINGS verdicts BLOCK on FINDINGS).
5. Qualifier preservation is same severity as fabrication.
6. Model-family separation across steps is recommended but not required (audits are mechanical).

Anti-patterns: conflating Step 1+2; skipping Step 4; waving off Step 3 findings; treating CLAIM MAP as audit.

### 12.3 `02-corpus-contract.md` (~11KB)

The integration contract. Stable across v1.x.

**Inputs:** `source_corpus_path` (REQUIRED), `memo_topic` (REQUIRED), `working_dir` (REQUIRED), `memo_label` (REQUIRED), `model_assignment` (REQUIRED), `qualifier_registry_path` (OPTIONAL).

**Outputs:** `<memo_label>_claims.json`, `<memo_label>.md`, `<memo_label>_leakage.md`, `<memo_label>_reattribution.md`, `<memo_label>_qualifier.md`, `<memo_label>_summary.json`.

**Exit semantics:** Framework succeeds (exit 0) iff Step 3 leakage = CLEAN AND Step 3 reattribution = CLEAN AND Step 4 qualifier = PASS.

**Versioning commitments:** v1.x preserves input field names, output filename conventions, exit-code semantics. v1.x MAY add new optional input fields and additional output files. Breaking changes require v2.x.

### 12.4 The four step prompts (decomposed from v2's `15-grounded-memo-drafter.md`)

**`prompts/01-claim-extractor.md`** — Step 1. Builder-class model. Access: corpus only; NO web; NO training-data backfill. Output: structured JSON manifest (NOT prose) with schema `{claims: [{claim_id, claim, source_file, source_section, source_quote (VERBATIM), register, volatility_tag}], gaps: [...]}`. Save to `<working_dir>/<memo_label>_claims.json`.

**`prompts/02-memo-writer.md`** — Step 2. Builder-class model. Access: claim manifest ONLY; NO source corpus; NO web. Output: memo + CLAIM MAP table. Every specific traces to a claim_id. **Rule 4 (Qualifier Preservation)** — preserve every qualifier, exception, threshold variant, scope clause, term-of-art, enumerated limb, numeric/temporal anchor; if not possible without unwieldy sentence, use verbatim block quote.

**`prompts/03-mechanical-leakage-audit.md`** — Step 3. Pure mechanical. Invoke BOTH `Detect-MemoLeakage.ps1` AND `Detect-Reattribution.ps1`. Combined exit criterion: this step is CLEAN iff BOTH scripts exit 0. Disposition: remove specific / replace with placeholder / extract new claim from corpus. Do NOT manually wave off.

**`prompts/04-qualifier-preservation-review.md`** — Step 4. Builder-class model recommended. For every CLAIM MAP row marked "paraphrased": compare memo statement against `source_quote` word-by-word; flag dropped qualifiers; restore qualifier OR convert paraphrase to verbatim block quote. Mandatory for memos containing operative claims.

### 12.5 `prompts/00-README.md` (~2KB)

Inventory of the four step prompts. ASCII protocol-sequence diagram. Cross-reference to `01-axioms.md` and `02-corpus-contract.md`.

### 12.6 `examples/reference-memo-with-claim-map.md` (~8KB)

Worked synthetic example. Pick a short hypothetical: 2-paragraph synthetic source corpus → 2-claim `claims.json` → 4-paragraph memo + CLAIM MAP → CLEAN leakage report → CLEAN reattribution report → PASS qualifier review.

## 13. Invariants Your Implementation Must Satisfy

Your implementation must satisfy 27 invariants spanning 5 categories (AF/PV/IN/AU/RF). Each invariant is documented verbatim in the v3 spec § 2 — preserve them word-for-word.

**Per-invariant enforcement matrix** (one row per invariant; populate by reading the actual v3 prompts and scripts you build):

| Invariant | 1-line summary | Enforced by | Verified at |
|---|---|---|---|
| AF-1 | Verified-or-omitted | Phase 5.1-5.5 + Phase 6.4 + Detect-MemoLeakage at Phase 8 | Phase 6.5 + Phase 7.0 |
| AF-2 | Institutional-fact primary source | Phase 5.2 + Phase 5.5 Part A | Phase 6.4 + Phase 7.0 |
| AF-3 | Three-guardrail rule for illustrative entities | Phase 1.3 builder draft + Phase 6.2 register-lint + Phase 6.3 extraction | Phase 6.4 + Phase 7.0 |
| AF-4 | Inter-model agreement is not corroboration for named entities | Phase 4.0 single-source inventory + Phase 5.4 primary-source-required | Phase 6.4 |
| AF-5 | 3-query exclusion safeguard | Phase 5.4 explicit rule + Phase 6.4 | Phase 7.0 |
| AF-6 | Tier-1 for single-source | Phase 5.4 explicit rule | Phase 6.4 + Phase 7.0 |
| AF-7 | Stress test uses authority view | Phase 8.0 prompt restricts Memo Drafter to authority/ | Phase 8.0 |
| PV-1 | Persistent artifact per phase | Every phase prompt writes a named artifact | Phase 6.5 |
| PV-2 | Pipeline state file | Phase 0.0 establishes; 01-orchestrator maintains | Phase 6.5 + Phase 7.0 |
| PV-3 | Preservation of builds | Every phase prompt; sources/ directory layout | Phase 6.5 |
| PV-4 | Tag transitions logged | Phase 6.0 assembly; pipeline_state.md | Phase 6.4 + Phase 7.0 |
| PV-5 | Cite-string sufficiency | Phase 5.2 + table-of-authorities | Phase 6.4 + Phase 7.0 |
| IN-1 | Builder isolation | Phase 1.1 + 1.3 prompts | Phase 4.0 |
| IN-2 | No self-grading | Model-family separation per phase; Validate-ModelAssignment | Phase 7.0 |
| IN-3 | Critic independence | Phase 0.2, 1.2, 6.1 prompts; Validate-ModelAssignment | Phase 7.0 |
| IN-4 | Fact-Checker contract enforcement | Phase 5.4 explicit rule (consumes Phase 4.0 inventory, not builder drafts) + Validate-Phase4Inventory | Phase 7.0 |
| IN-5 | Independence documentation | pipeline_state.md + Quality Scorecard model_assignment | Phase 7.0 |
| IN-6 | Independence failure mode | 01-orchestrator dispatches Phase 0.0 with explicit-opt-out; Quality Scorecard tags affected dimensions | Phase 7.0 |
| AU-1 | No silent skip | 01-orchestrator + Rule 17 | Phase 7.0 |
| AU-2 | Per-phase exit status | pipeline_state.md schema | Phase 7.0 |
| AU-3 | No downstream override of BLOCKED/FAILED | 01-orchestrator decision logic | Phase 7.0 |
| AU-4 | Append-only logs | verification_log.md, audit_trail.md format | Phase 7.0 |
| AU-5 | Mandatory completion checklist | Phase 6.0 Assembly Completion Checklist + Phase 7.0 audit | Phase 7.0 |
| RF-1 | Refresh cycle structure | 06-refresh-orchestrator.md protocol | Refresh-time |
| RF-2 | Volatile-tag scan regardless of age | 06-refresh-orchestrator Step 1 | Refresh-time |
| RF-3 | Correction-application gate | 06-refresh-orchestrator Step 3.5 | Refresh-time |
| RF-4 | Cascade on `full/` edit | 06-refresh-orchestrator + Phase 6.2 + 6.3 + 6.4 | Refresh-time |

## 14. Acceptance Criteria (Synthetic Conformance Test)

Your implementation is acceptable when these 14 checks PASS (or WARN with documented rationale):

1. **File integrity** — every file documented in CHANGELOG.md exists at its documented path; no leftover v2-named prompt files.

2. **All scripts parse without syntax error** — `pwsh` syntax check passes for all root KB v3.1 `.ps1` scripts, all provider-adapter `.ps1` scripts, and the Memo framework `.ps1` scripts; `python -m py_compile` passes for all Crawl4AI adapter Python scripts.

3. **All YAML files parse** — `audit-templates/kb-quality-dimensions.yaml`, `audit-templates/model-presets.yaml`, any YAML front matter in prompts/.

4. **Phase numbering monotonic** — prompts/ filenames form the sequence 00a, 00b, 01, 11, 12, 13, 20, 30, 40, 51-55, 60-65, 70, 80, 85. No Phase 1.5 or 3.5 files (confirmed cut).

5. **Cross-references resolve** — every file reference in prompts and rulebooks points at an existing file.

6. **Invariant coverage** — the spec has a per-invariant enforcement matrix covering all 27 invariants with named enforcing prompts/scripts.

7. **Six Rules byte-identical** — HOW-TO-USE.md, prompts/00-README.md, 01-shared-axioms.md all contain the same Six Rules wording.

8. **Model assignment plumbing end-to-end** — Phase 0.0 writes the block; 01-orchestrator reads it; every dispatch site references the appropriate field.

9. **Quality Scorecard data sources exist** — every dimension's source artifacts are produced by an earlier phase.

10. **Memo framework integration contract** — Phase 8.0 invokes the memo framework per the documented contract; required inputs/outputs match; model_assignment passthrough works.

11. **Model Registry conformance** — `model-registry.example.yaml` validates against `audit-templates\model-registry.schema.json`; `Resolve-Model.ps1` resolves every preset handle; `Validate-ModelAssignment.ps1` enforces Rule 19 by registry family.

12. **Provider adapters exist** — four provider directories exist with `README.md`, `dispatch.ps1`, and `discover.ps1`: `copilot-cli`, `azure-foundry`, `openrouter`, `ollama`.

13. **Host abstraction exists** — `HOST-CONTRACT.md`, `hosts\README.md`, `hosts\copilot-cli\HOST-NOTES.md`, and `hosts\opencode\HOST-NOTES.md` exist; OpenCode notes preserve primary-source citations and conservative L3 pending runtime promotion.

14. **Usability scripts and recommendation templates exist** — the nine L3.5 scripts and four recommendation audit-template YAML files exist and are referenced by Phase 0.0 / HOW-TO-USE.

## 15. Instructions to You (The Receiving LLM)

1. **Ask the operator** for the target root directory before writing anything.
2. **Confirm tooling versions:** PowerShell 7+ available? Python 3.12+ available? Optional Playwright + Patchright + Scrapling installable?
3. **Confirm host selection:** Copilot CLI or OpenCode. If OpenCode, warn that primary-source HOST-NOTES and runtime `Validate-Host.ps1` promotion are required before production L1a reliance.
4. **Set up model registry:** create/copy `model-registry.example.yaml` to `model-registry.yaml` if the operator wants local edits. Do not put secrets in the registry.
5. **Confirm provider env vars:** at least one live provider should be configured for dispatch. OpenRouter starter: `OPENROUTER_API_KEY`; Azure Foundry: `AZURE_FOUNDRY_ENDPOINT` + `AZURE_FOUNDRY_API_KEY`; Ollama: local runtime/endpoint; Copilot CLI: host authentication.
6. **Create the two sibling directory structures** in § 6.
7. **Build in this order** (respecting dependencies): Layer 0 bootstrap; Layer 1 v3.0 script baseline; Layer 1.5 Model Registry and provider adapters; Layer 2 Host Contract and HOST-NOTES; Layer 3 prompt/rulebook updates; Layer 3.5 usability scripts; Layer 7 specification/recreation/archive headers; Layer 8 conformance.
8. **Run setup validation:** execute `Validate-ModelRegistry.ps1`, resolve all preset handles, and run `Test-Setup.ps1`. If `Validate-Host.ps1` is not implemented, record that host runtime promotion is pending.
9. **Run the conformance checks** in § 14 after Layer 7 is complete. Don't mark the build complete until all criteria PASS or WARN with documented rationale.
10. **Produce a final acceptance report** for the operator listing each § 14 criterion with PASS / WARN / FAIL and evidence.


### What to do when you have a judgment call

This prompt does not specify every word of every prompt file. Where this prompt gives you structure and required content but not exact wording, exercise your judgment within the discipline this framework encodes:

- **Bias toward conservative discipline.** When in doubt, add a guardrail rather than omit one.
- **Bias toward enumeration over prose.** Operators paste these prompts into model sessions; structure helps the model attend.
- **Bias toward redundancy on safety-critical rules.** Model-family-separation, no-silent-skip, volatile-tag-preservation should be stated wherever they apply.
- **Bias toward verbatim quoting** of source text in fact-check verdicts and operative-provision restatements.
- **Bias toward `[BRACKETED_VARIABLES]`** for anything that varies per KB.
- **Bias toward small focused prompts** over large omnibus prompts (the framework already consolidated v2's 22 down to ~15 effective; further consolidation risks losing discipline).

### What you should NOT do

- Do NOT collapse the v3 phases on your own judgment. The 22-phase count IS the discipline.
- Do NOT make scripts "smarter" by adding model calls. Scripts are mechanical enforcement; that is the point.
- Do NOT omit the three Phase 6 manifests (`new_claims_manifest.md`, `unresolved_unverified_manifest.md`, `volatile_tag_manifest.md`). These close known failure modes.
- Do NOT write a system that "decides" when to run a phase based on cost. The operator's stated priority is quality and zero errors, not cost.
- Do NOT skip the Phase 0.0 model selection. The Phase 0.0 prompt is REQUIRED before Phase 0.1 scoping.
- Do NOT merge the Memo Drafting Framework back into KB v3. The spinoff is intentional and the corpus contract is the integration surface.
- Do NOT remove the v2→v3 migration script. Operators with existing v2 KBs need a clean upgrade path that doesn't require a full rebuild.
- Do NOT silently consolidate KB-type overrides into the common prompts. The legal/company branching is intentional.
- Do NOT skip the synthetic conformance test in § 14 because "the framework should work." The conformance test exists precisely because frameworks ship with subtle documentation/contract drift.

### Reference documents to keep open during the build

- This prompt (the construction guide). It is self-contained; do not require any file outside the prompt to recreate the framework.
- If the live framework directory is available, use `technical-specification-v3.1.0.md` as a conformance reference, not as missing prompt content.

## 16. After You Finish

Write a final report at `[target_root]/RECREATION-REPORT.md` containing:

1. Date / time of recreation.
2. Receiving LLM identity (model + version).
3. List of files created in each of the two frameworks (with byte sizes).
4. Acceptance criteria results (§ 14, 14 criteria, with evidence).
5. Any deviations from this prompt and the rationale.
6. Recommended next steps for the operator (suggest building a single small Topic KB end-to-end via Phase 0.0 → Phase 8.5 as the first empirical conformance test).

▲▲▲ END PROMPT ▲▲▲

---

## Notes for the Operator Pasting This Prompt

**Sizing expectation.** The receiving LLM will produce ~95+ files totaling ~600-900 KB of content across the two frameworks. Allow ~60-90 minutes of model time depending on the receiving LLM's speed.

**Cost expectation.** At current frontier-model pricing (2026-06-06), the full recreation runs ~$10-40 in tokens, depending on model. The bulk is in the prompt files (Section 10), which are individually small but numerous, plus the rulebooks (Section 9), which are individually large.

**Quality test.** After the receiving LLM completes, the meaningful conformance test beyond § 14's synthetic checks is whether the operator can: (1) paste `KB Creation - Modular v3 + OpenCode and OpenRouter\prompts\01-orchestrator.md` into a Lead model session, (2) run Phase 0.0 (model selection), (3) successfully complete Phase 0.1-Phase 8.5 against a simple target domain. If that round-trip works, the recreation is faithful.

**Iteration expectation.** A first-pass recreation will likely have rough edges — vague prompts, missing variable substitutions, KB-type override behaviors that are too similar to the common prompt, seams between the KB framework and the Memo framework. Treat the first recreation as v3.1.0-rc1; refine over 2-3 builds.

**What this prompt deliberately omits.** The original framework's pilot architecture (the experimental mechanical-sweep utilities — Sibling-Cluster-Scan, Cross-File-Consistency, Manifest-Verifier, Metadata-Fidelity, Dated-Fact-Ledger, Currency-Sweep, Entity-Gate, Refresh-Lock, Backlog-Regenerate) is out of scope. So is the confidential-data `Internal KB Creation Framework`. Those historical workstreams are not required for a conformant minimum v3.1 implementation.

**What this prompt requires you to KEEP from v2.** Despite the 18 changes, v3 inherits the v2 discipline almost entirely. The Six Rules, the Error Pattern Taxonomy, the Option C lesson promotion, the 35-item lesson list in 01-shared-axioms.md, the Tier 1/2/3 source hierarchy, the Builder Isolation rule, the dual-view architecture (extended to three-tier), the audit trail structure (extended with the Quality Scorecard), the Refresh Orchestrator's correction-application verification gate — all preserved. v3 is an evolution, not a rewrite. The same framework Authors who wrote v2 ship v3 because v2's structure was sound; v3 just makes more of the safety mechanisms mechanical and visible.

**Source documents that informed this prompt.** The live v3.1 framework at `KB Creation - Modular v3 + OpenCode and OpenRouter\` (the actual implementation), the normative v3.1 specification at `KB Creation - Modular v3 + OpenCode and OpenRouter\specification\technical-specification-v3.1.0.md`, the v3.1 CHANGELOG.md, the Memo Drafting Framework v1 + Provider Registry corpus contract, and archived v3.0 materials for continuity.

---

*End of LLM Recreation Prompt v3.1. Companion artifacts:*
- *`technical-specification-v3.1.0.md` — normative v3.1 specification, alongside this prompt in the `specification\` directory.*
- *Archived v3.0 files in `specification\` — preserved for continuity reference.*
