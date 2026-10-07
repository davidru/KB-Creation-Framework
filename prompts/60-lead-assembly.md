# Lead Assembly Prompt (Monolithic — Phase 6)

**Role:** Lead assembler
**Input:** Both v2 drafts, comparison report, all fact-check results
**Output:** Complete assembled KB
**Runs:** Once
**Why monolithic:** Cross-cutting synthesis requires full context
**Reference:** 03-builder.md Sections 5-6 for assembly rules and file standards

---

## Prompt

```
You are assembling the final [KB_NAME] knowledge base from two
independently-built and reviewed drafts.

BUILDER A v2 DRAFT: [paste or attach]
BUILDER B v2 DRAFT: [paste or attach]
COMPARISON REPORT: [paste or attach]
FACT-CHECK RESULTS:
- Currency (Phase 5.1): [paste or attach]
- Citations (Phase 5.2): [paste or attach]
- Classifications (Phase 5.3): [paste or attach]

KB TYPE: [KB_TYPE]
AUDIENCE: [AUDIENCE]
SIZE TARGET: [SIZE_TARGET] per file

ASSEMBLY RULES (per 03-builder.md Section 5):

1. Use the BACKBONE builder per comparison report recommendation.
2. Enrich with verified content from the other builder.
3. Apply ALL fact-check corrections — remove unverified citations,
   update stale data, fix misclassifications.
4. Preserve ALL specifics: dates, amounts, citations, entity names.
5. Do NOT summarize. If a builder wrote 20KB on a topic, the
   assembled version must be AT LEAST 20KB.
6. No silent [UNVERIFIED] stripping. Resolve or remove where possible. Any unresolved [UNVERIFIED] that survives assembly MUST be preserved in `full/`, marked `[UNVERIFIED-AT-ASSEMBLY]`, and listed in `sources/unresolved_unverified_manifest.md` with rationale and next action.

7. PROVENANCE TRACKING: For any citation, enforcement case, dollar
   amount, or factual claim you add that does NOT appear in either
   builder draft, mark it with <!-- [NEW] --> inline. These will be
   verified in Phase 6.4. Do NOT suppress new content — enrichment is
   expected — but make the new claims identifiable.

8. REGISTER TAGGING (per 01-shared-axioms.md Section 9):
   Preserve register tags and volatile tags from builder drafts. When assembling:
   - Unmarked content (primary authority) stays unmarked.
   - <!-- [GUIDANCE] --> tagged content keeps its tag.
   - <!-- [INTERPRETATION] --> tagged content keeps its tag.
   - If you synthesize new practice guidance during assembly,
     tag it <!-- [GUIDANCE] -->.
   - If builders disagree on whether content is authority vs.
     guidance, default to the more conservative tag (guidance).

MANDATORY MANIFESTS:
- `sources/new_claims_manifest.md` — every citation, case, dollar amount, or factual claim added during assembly that did not appear in either builder draft.
- `sources/unresolved_unverified_manifest.md` — every unresolved `[UNVERIFIED]` / `[NEEDS-VERIFICATION]` retained at assembly, with `[UNVERIFIED-AT-ASSEMBLY]` marker, source attempts, rationale, and owner.
- `sources/volatile_tag_manifest.md` — every `[VOLATILE:*]` tag preserved or introduced, with file, claim, volatile type, as-of date, and refresh implication.

VOLATILE TAG PRESERVATION:
`[VOLATILE:*]` tags are load-bearing refresh metadata. Preserve them across paraphrasing and relocation. If you split a paragraph, carry the tag adjacent to each claim it modifies. If you remove a volatile tag, explain why in `volatile_tag_manifest.md`.

CREATE THESE FILES:

1. AGENTS.md (create FIRST — 5-7KB)
   - Entry point with routing table
   - Topic-to-file mapping
   - Session protocol

2. index.md (10-20KB)
   - KB snapshot and key dates
   - Quick reference covering the most-asked questions
   - Routing table to deep-dive files

3. Per-topic files: [NN]-[topic-slug].md
   Each file must include:
   - YAML metadata header (title, kb, last_updated, tags)
   - Key Takeaways section (3-5 bullets)
   - Full analytical content
   - Cross-references to related files
   - Inline source citations

4. table-of-authorities.md (10-20KB)
   - Every verified citation organized by type
   - Only citations that passed fact-check Phase 5.2

FILE STANDARDS:
- Every file must have YAML front matter
- Analytical voice for [AUDIENCE]
- Lead with conclusions, then reasoning
- Size floor: no file below 12KB (01-shared-axioms.md Section 6)
- Parity: thinnest file ≥ 50% of thickest
- DEPTH TARGET: Each topic file should aim for 35-45KB. The assembled KB
  total should be at least 3x the larger builder draft. If the larger
  builder wrote 99KB and the smaller wrote 44KB, the assembled output
  should be at least 300KB (and ideally 500KB+). Thin assembly means
  you left material on the table — go back to the sources and extract more.
  A-tier KBs average 40KB+ per topic file.

DIRECTORY STRUCTURE:
- Save all assembled topic files to [STATE_ROOT]/full/
- Save AGENTS.md, index.md, table-of-authorities.md to [STATE_ROOT]/
- The full/ folder is the source of truth for all content.

After assembly, run the size gate. List every file with its size.
Flag any below 12KB for deepening.

ASSEMBLY COMPLETION CHECKLIST (MANDATORY — print before declaring assembly done):

You MUST print this checklist verbatim and confirm each line. Do NOT
declare assembly done if any line is ✗. Phase 6.3 will block if you do.

  ASSEMBLY COMPLETION CHECKLIST
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [ ] AGENTS.md created at KB root        (size: ___ KB)
  [ ] index.md created at KB root         (size: ___ KB)
  [ ] table-of-authorities.md created     (size: ___ KB)
  [ ] full/ contains all assembled topic files (count: ___)
  [ ] Register tags preserved in full/    (count of [GUIDANCE]/[INTERPRETATION]: ___)
  [ ] Illustrative entity examples (named firms/vendors/products/programs)
      are sourced and live inside [GUIDANCE]/[INTERPRETATION] paragraphs only
      (none in untagged authority-register paragraphs)        (Y/N: ___)
  [ ] sources/new_claims_manifest.md created
  [ ] sources/unresolved_unverified_manifest.md created
  [ ] sources/volatile_tag_manifest.md created and `[VOLATILE:*]` tags preserved
  [ ] sources/pipeline_state.md updated with Phase 6.0 entry

If any line is ✗, STOP and create the missing artifact before reporting
assembly complete. The infrastructure files (AGENTS.md, index.md,
table-of-authorities.md) are NOT optional — they are the entry points
that downstream consumers depend on. Shipping a KB with only full/
populated is a Phase 6.0 failure, not a Phase 6.0 success.

Common silent-skip pattern (do NOT do this): producing all 15 topic
files in full/, declaring assembly done, then proceeding to Phase 6.5
remediation and Phase 6.4 fact-check while the infrastructure files
were never created. The US Employment Immigration KB (April 2026)
shipped this way and required corrective work. Print the checklist.

Phase 6.3: AUTHORITY VIEW GENERATION — see prompts/63-extraction-and-filename-validation.md

This is now a DISTINCT, DEFAULT-ON phase. Do NOT run the extraction script as
part of this assembly prompt. After assembly completes, the orchestrator (or
manual operator) invokes prompts/63-extraction-and-filename-validation.md as its own
step. Authority-view extraction is mandatory unless the scoping report
explicitly opts out with justification (see 01-shared-axioms.md Section 9
Rule 7).

Your only obligation in this assembly prompt is to apply register tagging
correctly — preserve <!-- [GUIDANCE] --> and <!-- [INTERPRETATION] -->
tags from the builder drafts, and apply them to any practice guidance or
interpretive synthesis you introduce during assembly. If you ship an
assembled full/ folder with zero register tags and practice guidance is
present, Phase 6.3 will flag a BLOCKING error.

After the size gate, produce a NEW CLAIMS MANIFEST:
List every citation, case, dollar amount, or factual claim in the
assembled output that does not appear in either builder draft.
Format: | File | Claim | Type | Source (if known) |
Save as sources/new_claims_manifest.md.
This manifest feeds Phase 6.4 (post-assembly fact-check). The unresolved and volatile manifests feed Phase 6.4, Phase 6.5, and the Quality Scorecard.

OUTPUT: Complete KB directory structure with all files.
Save builder drafts and comparison report in sources/ for provenance.
```

