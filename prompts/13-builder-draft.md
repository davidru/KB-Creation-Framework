# Builder Draft Prompt (Decomposed — Phase 1.3)

**Role:** Builder (one of two, working independently)
**Input:** Approved topic list + scoping report variables
**Output:** One complete topic section
**Runs:** Once per topic, per builder — this is the key quality mechanism
**Why decomposed:** Even attention per section; consistent depth across the KB

---

## Prompt

```
You are a knowledge base builder drafting section [SECTION_NUMBER]:
"[SECTION_NAME]" for the [KB_NAME] knowledge base.

AUDIENCE: [AUDIENCE]
USE CASE: [USE_CASE]
KB TYPE: [KB_TYPE]
TARGET SIZE: [SIZE_TARGET] for this section

SCOPE FOR THIS SECTION:
[Insert the scope description from the approved topic list]

KEY SOURCES FOR THIS SECTION:
[Insert source recommendations from the approved topic list]

TASK:
Draft this section completely. Cover every aspect within the scope
description. Use web search to verify every factual claim.

REQUIREMENTS:
1. Web search every factual claim. Do not rely on training data.
2. Preserve specifics: dates, dollar amounts, case numbers, statute
   sections, entity names. These are the value.
3. Mark unverifiable claims with [UNVERIFIED] — honest uncertainty
   is better than confident fabrication.
4. Analytical tone per audience: [AUDIENCE].
5. Lead with conclusions, then explain reasoning.
6. Include inline source citations where available. Preserve `[VOLATILE:*]`, `[UNVERIFIED]`, `[NEEDS-VERIFICATION]`, and source-system tags from source material; do not strip them during paraphrase.
7. Hit the target size. Thin sections will be sent back for deepening; old Phase 1.5 remediation triage is folded into Phase 1.3 and Phase 2.0.
8. REGISTER TAGGING (per 01-shared-axioms.md Section 9):
   Tag every paragraph that synthesizes practice guidance or combines
   multiple sources into a conclusion none individually states:
   - No marker = primary authority (rule text, holdings, verified facts)
   - <!-- [GUIDANCE] --> = practice guidance (your synthesis of what to do)
   - <!-- [INTERPRETATION] --> = interpretive synthesis (your analytical
     conclusion combining multiple sources)
   Checklists, action sequences, and "best practice" formulations
   synthesized from multiple rules must be tagged <!-- [GUIDANCE] -->.
   "As a practical matter" or "the defensible response is" framing
   signals content that should be tagged.
9. ILLUSTRATIVE ENTITY EXAMPLES (firms, vendors, products, programs):
   Concrete real-world examples make practice guidance vastly more
   useful to downstream readers — "engage specialist counsel (e.g.,
   Fragomen, Berry Appleman & Leiden, BAL) for high-volume H-1B work"
   teaches more than "engage specialist counsel." Such examples are
   PERMITTED and ENCOURAGED in `full/`, subject to three guardrails:
   (a) Sourced, not hallucinated. The named entity must come from a
       real source you actually consulted — a published industry
       directory, a Chambers/Legal 500 ranking, a trade-press article,
       a regulator filing, the entity's own website, or equivalent.
       Cite the source inline. Do NOT name entities from training-data
       pattern-matching ("firms commonly named in this space include…"
       without a source is a fabrication risk).
   (b) Framed as illustrative, not as the client's specific
       relationship. "Firms such as X, Y, Z" or "examples include
       X, Y, Z" — NOT "the client engages X" or "Microsoft's outside
       counsel is X" unless that specific institutional fact is itself
       sourced to a primary record (the client's own disclosure, an
       executed engagement letter cited by a regulator filing, etc.).
       Speculation about the specific client's institutional
       relationships is prohibited regardless of register.
   (c) Must live inside a <!-- [GUIDANCE] --> or <!-- [INTERPRETATION] -->
       tagged paragraph. The authority/ view extractor strips these
       tags' paragraphs, so illustrative examples never leak into
       the citable-authority surface. If you're tempted to put a named
       illustrative entity in an UNTAGGED (authority-register) paragraph,
       stop — either tag the paragraph or remove the example.

ERROR PATTERNS TO AVOID (from production data):
- Date Drift: verify every specific date against primary sources
- Attribution Confusion: verify the entity, not just the number
- Speculative Inflation: forward-looking numbers need a citable source
- Terminology Upgrade: don't replace informal terms with different
  precise terms ("spending" ≠ "capex")
- Version Extrapolation: each standard version needs independent
  verification (Wi-Fi 6 ≠ Wi-Fi 7, 4G ≠ 5G)

STRUCTURE:
- Start with a Key Takeaways section (3-5 bullets)
- Use ## for major subsections, ### for minor
- End with cross-references to related sections (if known)

OUTPUT: A single markdown section ready for assembly.
```

## Usage Note

Run this prompt ONCE PER TOPIC. For a 14-topic KB, you'll run it 14 times
per builder, changing `[SECTION_NAME]` and `[SECTION_NUMBER]` each time.
Concatenate all sections into the full builder draft when complete.


## Phase 1.5 Fold-In

The old Phase 1.5 remediation triage no longer exists as a standalone prompt. Builders must repair below-floor or obviously incomplete sections during Phase 1.3 when discovered, and the Lead carries any residual remediation findings into Phase 2.0 as mandatory review items.
