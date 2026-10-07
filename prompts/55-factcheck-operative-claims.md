# Fact-Check: Operative-Claim & Cross-Reference Fidelity (Decomposed — Phase 5.5)

**Role:** Dedicated fact-check agent — DIFFERENT model family from Phase 5.2
**Input:** v2 drafts; the operative-claim inventory; the multi-occurrence claim map
**Output:** Operative-mechanism verification + cross-reference reconciliation results
**Runs:** Once per build; can run in parallel with Phases 5.1/5.2/5.3/5.4
**Required for:** Legal, regulatory, and standards KBs that carry operative provisions (reporting clocks, penalty schedules, indexation rules, conformity routes, trigger/threshold logic). Skippable only for KBs with no operative provisions (e.g., pure company-profile KBs) — document the skip.
**Reference:** 04-fact-checker.md Sections 1.2 (Priority 2a/2b), 1.3; 01-shared-axioms.md Patterns 14–16, Lessons 33–35

**Why decomposed:** Currency (Phase 5.1), citation (Phase 5.2), classification (Phase 5.3), and single-source (Phase 5.4) checks verify that a cite is current, real, correctly classified, and corroborated. None of them verify that the *operative mechanism* the cite supports is stated correctly, or that the same claim restated in another topic still says the same thing. Those two gaps produced the Medical Device Regulation KB failures of June 2026 (penalty-unit indexation cadence wrong; advertising pre-approval keyed to the wrong criterion; Canada hospital duty-holder imprecise; Australia reporting clocks incomplete in two different topics). This phase closes them.

---

## Prompt

```
You are verifying OPERATIVE-CLAIM FIDELITY and CROSS-REFERENCE
CONSISTENCY in the [KB_NAME] knowledge base. You are a different model
family from the citation fact-checker (Phase 5.2). Do NOT read how the
KB was built.

You are NOT checking whether cites are current (that is Phase 5.1) or real
(that is Phase 5.2). You are checking two things the other phases miss:
(A) whether the OPERATIVE MECHANISM each provision describes is stated
correctly, and (B) whether the same claim, restated in more than one
place, still says the same thing.

================================================================
PART A — OPERATIVE-MECHANISM FIDELITY
================================================================

An OPERATIVE claim tells the reader what an actor must DO, or sets a
numeric/temporal anchor the actor must meet. For these, the VALUE is
not the only load-bearing element — the MECHANISM around it is just as
load-bearing and goes wrong the same way.

For every operative claim, verify the MECHANISM against the verbatim
provision text (primary source — pull it; do not rely on recall):

1. INDEXATION / ADJUSTMENT CADENCE
   - "indexed annually" vs. "every 3 years" vs. "on a fixed schedule."
   - DO NOT ASSUME ANNUAL. Read the indexation subsection. The penalty
     value may be right while the cadence is wrong.

2. REPORTING / NOTIFICATION CLOCKS
   - A multi-tier clock is MULTIPLE claims, not one. A 48h / 10d / 30d
     structure = three claims. Verify EVERY tier.
   - For each tier verify: (a) the time window, (b) the trigger
     condition that selects that tier, (c) which actor the clock binds.
   - Flag any clock that is missing a tier the source provides.

3. TRIGGER / THRESHOLD LOGIC
   - Does the obligation key on entity CLASS, CLAIM type, RISK tier,
     or TRANSACTION type? These are routinely conflated.
   - Worked failure: "pre-approval required for Class IIb/III devices"
     when the provision keys pre-approval to making a restricted
     CLAIM, regardless of device class.

4. DUTY-HOLDER SCOPE
   - Verify the EXACT class the provision binds. When a regulation
     narrows a statute's broad term to a defined subset, cite the
     NARROWED term.
   - Worked failure: a statute says "health care institutions"; the
     implementing regulation says "hospitals are the prescribed health
     care institutions." The duty-holder is "hospitals," not all
     health care institutions.

5. PENALTY STRUCTURE
   - Individual vs. body-corporate; civil vs. criminal; strict-
     liability vs. ordinary; per-event vs. continuing. Each variant is
     a separate claim; verify each.

VERDICT RULE FOR PART A: a CONFIRMED verdict requires EITHER a verbatim
quote of the operative provision OR a preserved [NEEDS-VERIFICATION]
flag. A plausible-sounding mechanism stated WITHOUT the provision text
is a FINDING even when the associated number is correct. "The number
checks out" is not "the mechanism checks out."

================================================================
PART B — CROSS-REFERENCE / CROSS-TOPIC RECONCILIATION
================================================================

When the same operative or definitional claim appears in more than one
file or section, the restatements drift. Build a map of every claim
that appears in 2+ places, then for each:

1. CANONICAL DESIGNATION
   - Identify the canonical statement: the file/section that quotes the
     source or states it most fully. Diff EVERY other restatement
     against it.

2. PARAPHRASE-DROP DETECTION
   - A restatement that drops a qualifier, a tier, a threshold variant,
     an exception, or an enumerated limb the canonical preserves is a
     FINDING — treated identically to a paraphrase-drop in the
     canonical itself.

3. CONFLICTING RESTATEMENTS
   - Where two topics state the same obligation DIFFERENTLY (e.g.,
     Topic A: 10d + 30d; Topic B: 10d + 48h), neither is presumed
     correct. Verify BOTH against primary source and reconcile to the
     FULL structure (here: 48h + 10d + 30d). Report which topics were
     individually incomplete.

4. CIRCULAR-CORROBORATION GUARD
   - Self-corroboration is NOT corroboration. A value that appears in
     two KB files, in a prior memo, in a persona/instruction file, or
     in any AI-authored artifact has been COPIED, not independently
     confirmed. Operative values require a Tier 1 PRIMARY source.
   - When you record corroboration for a value, EXCLUDE the operator's
     own prior outputs and any AI-authored artifact from the
     corroboration set. If the only "corroboration" is an internal
     echo, the value is UNVERIFIED.

================================================================
VERIFICATION METHOD (per 04-fact-checker.md Section 1.3)
================================================================
- Pull the PRIMARY provision text. If a grounding adapter manifest
  exists (Section 1.3.1), read the fetched text; otherwise web-search
  for the official statute/regulation/guidance text.
- BLOCKED-SOURCE ESCALATION IS MANDATORY (04-fact-checker.md §1.3.0;
  Shared Axioms Pattern 17). You may NOT return an UNVERIFIABLE verdict
  for an ACCESS reason (403, JS-SPA shell, Cloudflare/Turnstile, PDF
  loaded async) until you have walked the Primary-Source Access Fallback
  Chain to exhaustion: Tier 0 API → 1 web_search/Wayback → 2 curl_cffi
  (try a /download or static-PDF endpoint directly) → 2.5 cloudscraper →
  3 Playwright → 4 Camoufox → 5 patchright → 6 Scrapling. Consult
  ../host-registry.md for the host's known min-tier first; log the tier
  that worked and append it to the registry. Reserve UNVERIFIABLE for
  genuine ABSENCE (source not published) or a permanent wall (Akamai/
  PerimeterX/auth/paywall) AFTER the chain is exhausted — and name the
  tiers attempted. A regulator SPA or 403 is presumptively recoverable.
- Tier 1 (primary) sources only count toward a CONFIRMED operative
  verdict. Tier 2/3 may support, but cannot alone confirm an operative
  mechanism or value.
- Do NOT rely on training data. Do NOT count internal/self-authored
  sources as corroboration.

EXECUTION CONSTRAINT:
Execute all verifications yourself, sequentially, in this session. Do
NOT decompose into sub-agents — consistent standards and provenance
tracking matter here.

================================================================
OUTPUT FORMAT
================================================================

PART A — Operative-Mechanism table:
| # | File:§ | Operative claim (as drafted) | Mechanism element (cadence/clock/trigger/duty-holder/penalty) | Provision text (verbatim) | Source (Tier 1 URL + provision) | Verdict (CONFIRMED / CORRECTED-MECHANISM / CORRECTED-VALUE / UNVERIFIABLE) | Correction |

PART B — Cross-Reference table:
| # | Claim | Occurrences (file:§ list) | Canonical | Divergence found (dropped tier/qualifier/limb, or conflicting values) | Reconciled statement | Source | Verdict (CONSISTENT / RECONCILED / UNVERIFIABLE) |

Summaries:
- Part A: [N] confirmed, [N] corrected-mechanism, [N] corrected-value, [N] unverifiable
- Part B: [N] consistent, [N] reconciled (drift corrected), [N] unverifiable
- CIRCULAR-CORROBORATION flags raised: [list any value whose only corroboration was an internal/self-authored echo]
- BLOCKING items (wrong mechanism stated as fact with no flag; conflicting cross-topic values both shipped; duty-holder scope error): [list]

PATTERN PROMOTION CANDIDATES (per 01-shared-axioms.md Patterns 14–16):
[Note any operative-mechanism drift, cross-reference divergence, or
circular-corroboration instance for the master audit log.]
```

