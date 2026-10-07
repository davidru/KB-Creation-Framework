# Refresh Orchestrator — KB Creation Framework
# Version: 1.0 | Created: 2026-04-09
# Scope: Manages ongoing maintenance, staleness detection, and breaking development surfacing.
# Dependencies: Reads 01-shared-axioms.md. Invokes 04-fact-checker for verification of updates.
# Independence: Operates continuously on a schedule. Does not require a human trigger per cycle.
# Key output: Development log with significance tiers for downstream memo/alert generation.

---

## PURPOSE

This module keeps the KB portfolio current after initial build. It handles:

- Scheduled and event-triggered refresh cycles
- Staleness detection by field volatility
- Content updates (corrections, additions, structural changes)
- A **development log** that classifies changes by significance
- **Breaking news surfacing** — pushing high-significance developments to a queue for human action
- Coordination with the Fact-Checker for post-update verification

It does NOT build KBs from scratch (that's the Builder). It does NOT draft memos or alerts (that's the user's downstream workflow — Virtual David, email drafting, etc.). It surfaces the raw material that makes those outputs possible.

---

## SECTION 1: REFRESH CADENCE

### Default Schedule (Fallback for Untagged Claims)

The KB-type interval remains the fallback cadence for untagged claims and for v2-built KBs that do not yet have a volatile-tag manifest.

| KB Type | Refresh Interval | Rationale |
|---------|-----------------|-----------|
| Legal topic KBs | 30 days | Regulatory landscape shifts monthly; court filings weekly |
| Company KBs | 60 days | Quarterly earnings cycle; litigation updates less frequent |
| Litigation KBs | 14 days | Active cases have frequent docket activity |
| Person KBs | 90 days | Positions evolve slowly unless triggered by events |

### Per-Claim Cadence by `[VOLATILE:*]` Type

v3 INTRODUCES per-claim cadence by `[VOLATILE:*]` type. The KB-type interval (Legal 30d, Company 60d, etc.) becomes the FALLBACK for untagged claims. Tagged claims get their cadence from the volatile-type:

```yaml
volatile_type_cadences:
  docket-count: 7d            # litigation case counts change weekly
  penalty-rate: 365d           # CPI-indexed annually
  exchange-rate: 30d           # accept staleness within a month
  event-date: 30d              # forward-looking event dates
  bill-status: 14d             # legislative status changes biweekly
  market-data: 14d             # market data
  rule-status: 30d             # administrative rule status
  case-status: 14d             # case status
  legislative-status: 14d
  leadership: 90d              # executive transitions
  patent-count: 90d
  membership: 180d             # SDO membership rarely changes
```

These are tunable per KB type via the KB's `kb-manifest.yaml`. The Refresh Orchestrator reads `sources/volatile_tag_manifest.md` when present; if a tagged claim is past its type-specific cadence, it is due even when the containing file is otherwise fresh.

### v2 KB Compatibility

The Refresh Orchestrator runs against any v2-built KB without modification. v2 KBs use the KB-type-interval fallback because they lack the `volatile_tag_manifest.md` that v3 builds produce. To get per-claim cadence on a v2 KB, run `Migrate-V2KBtoV3.ps1` first to synthesize the manifest from existing `[VOLATILE:*]` tags in `full/`.

### Event Triggers (Override Schedule)

Any of these events triggers an immediate refresh cycle for the affected KB(s):

| Trigger | Example | Affected KBs |
|---------|---------|---------------|
| Major court ruling | Supreme Court SEP decision | SEPs KB, all company KBs with SEP exposure |
| Regulatory action | EU DMA fine issued | Company KB (target), Competition KB, relevant topic KBs |
| M&A announcement | Company acquisition | Both company KBs, relevant topic KBs |
| Legislation enacted | New AI safety law signed | AI Governance KB, affected company KBs |
| Standards body decision | New patent policy adopted | IP/Patents KB, affected company KBs |
| Company earnings release | Quarterly report | That company's KB |
| User request | "Update the Qualcomm KB" | Specified KB |

### Trigger Detection

The Refresh Orchestrator does NOT passively monitor news feeds. It is invoked either:
1. On schedule (by the user or an automation)
2. On demand (user flags an event)
3. By the Audit System (when cross-KB analysis reveals staleness patterns)

---

## SECTION 2: REFRESH CYCLE PROTOCOL

### Step 1: Staleness Scan

For each file in the KB:
1. Read the file's `last_updated` metadata
2. Load `sources/volatile_tag_manifest.md` if present; otherwise scan the file for inline `[VOLATILE:*]` tags (v2 compatibility path).
3. For each tagged claim, compute due status from the volatile-type cadence in Section 1. Tagged claims are verified when their per-claim cadence is due regardless of the file's age.
4. For untagged claims, apply the KB-type fallback interval and High-Volatility Fields Checklist:
   - Financial data older than 1 quarter → STALE
   - Litigation status not matching current docket → STALE
   - Regulatory filing status not current → STALE
   - Leadership/executive roles not current → STALE
   - Market share/rankings older than 6 months → STALE
5. **Scan for `[VOLATILE:*]` tags** — these are claims the Builder flagged as high-refresh-priority at build time. Verify every due tagged claim via web search and log the volatile type, as-of date, cadence, and disposition.
6. Web search for developments since `last_updated` in each topic area
7. Produce a **staleness report** listing:
   - Files needing updates (with specific stale claims)
   - New developments not yet covered
   - Structural changes needed (new sections, file splits)
   - Volatile-field verification results

### Step 2: Content Update

For each stale file:
1. Web search for current, verified information
2. Replace stale content with updated content
3. Add new developments not previously covered
4. Preserve all existing content that remains accurate — don't rewrite what isn't broken
5. Update `last_updated` metadata
6. Update index.md and table-of-authorities.md if sources changed

### Step 3: Verification

Invoke the Fact-Checker in **Refresh Verification mode** (Mode 3 from 04-fact-checker.md):
- Verify only the CHANGED content (not the entire KB)
- Apply corrections
- Log results in verification_log.md

### Step 3.5: Correction Application Verification (Mandatory Gate)

Before closing any refresh cycle, verify that ALL corrections logged in `learned/` have been applied to the source KB files:

1. Parse `learned/open-questions.md` and `learned/corrections.md` for entries containing "KB impact:", "should be updated", "should be corrected", or equivalent action language
2. For each entry, verify the corresponding source file has been modified to reflect the correction
3. If any logged correction has NOT been applied to the source file:
   - **Apply it now** — make the edit to the source file
   - Log the application in `sources/verification_log.md`
   - Flag the gap in the audit trail with: `[CORRECTION-DECAY] Correction logged [date] but not applied until [date]`
4. This step is a **blocking gate** — the refresh cycle cannot be marked complete if unapplied corrections exist

**Why this gate exists:** Correction Decay (Shared Axioms, Pattern 12) is a demonstrated failure mode. In the Gaming Law KB (April 2026), *Alexander v. Take-Two* was correctly identified as misattributed ("not a Seventh Circuit decision") in `learned/open-questions.md`, but the correction was never applied to `01-intellectual-property.md`. The error then propagated into a downstream book manuscript. Logging a correction is not the same as applying it.

### Step 4: Development Log Entry

Log every change with a significance tier (see Section 3).

### Step 5: Update Summary

Produce `sources/refresh_[date].md`:

```markdown
# Refresh Summary — [KB Name]
# Date: [date]
# Trigger: [scheduled / event: description]

## Files Updated
| File | Changes | Significance |
|------|---------|-------------|
| [filename] | [brief description] | [Routine/Notable/Breaking] |

## New Developments Added
| Development | File | Significance |
|-------------|------|-------------|
| [description] | [where added] | [tier] |

## Stale Content Corrected
| Claim | Was | Now | Source |
|-------|-----|-----|--------|
| [old claim] | [old value] | [new value] | [source URL] |

## Verification Results
- Claims verified: [N]
- Confirmed: [N]
- Corrected: [N]
- Verification rate: [%]

## Breaking Developments (if any)
[Detailed description of any Breaking-tier items — these feed the development queue]
```

---

## SECTION 3: DEVELOPMENT LOG

### Purpose

The development log is the Refresh Orchestrator's primary value-add beyond simple maintenance. It transforms raw content updates into structured, classified intelligence that can drive downstream legal work.

### Log Location

`sources/development_log.md` — append-only, per KB.

### Entry Format

```markdown
## [Date] — [Significance Tier]

**Development:** [One-line summary]
**Details:** [2-5 sentences explaining what happened and why it matters]
**Source:** [URL or citation]
**KB Impact:** [Which files were updated]
**Downstream potential:** [What kind of memo/alert this could feed]

---
```

### Significance Tiers

| Tier | Criteria | Action | Examples |
|------|----------|--------|----------|
| **Routine** | Expected updates, minor corrections, data refreshes | Log only. No escalation. | Q4 revenue updated, executive title change, new patent filed |
| **Notable** | Meaningful developments that shift the landscape but don't require immediate action | Log + flag in refresh summary for user review at next session | New litigation filed, regulatory investigation opened, major policy shift announced |
| **Breaking** | Developments requiring potential immediate client communication, legal strategy adjustment, or executive briefing | Log + push to **development queue** + notify user | Major court ruling, regulatory enforcement action, M&A announcement affecting client interests, legislative passage |

### Tier Classification Rules

1. **Default to Routine.** Most updates are routine. Over-classification dilutes the signal.
2. **Notable requires strategic relevance.** Ask: "Would a practitioner want to know about this at their next update?" If yes → Notable.
3. **Breaking requires urgency.** Ask: "Would a practitioner want to know about this TODAY?" If yes → Breaking.
4. **When uncertain between tiers, choose the lower tier.** False positives (over-classifying) are worse than false negatives — they train the user to ignore the queue.
5. **Context matters.** The same event might be Routine for one KB and Breaking for another. A patent filing is Routine for the filer's company KB but potentially Notable for a competitor's KB.

---

## SECTION 4: DEVELOPMENT QUEUE

### Purpose

The development queue aggregates Breaking-tier items across all KBs into a single, actionable list. This is the Refresh Orchestrator's interface to downstream workflows (memo drafting, client alerts, executive briefings).

### Queue Location

`<framework-root>\development_queue.md`

This is a framework-level file, not per-KB. It aggregates across the entire portfolio.

### Queue Format

```markdown
# Development Queue
# Last updated: [timestamp]
# Items pending action: [N]

---

## [Priority 1] [Date] — [KB Name]
**Development:** [One-line summary]
**Details:** [From development log entry]
**Source:** [URL]
**Suggested action:** [memo / client alert / briefing note / strategy update]
**Status:** [NEW / acknowledged / actioned / dismissed]

---

## [Priority 2] [Date] — [KB Name]
...
```

### Queue Management Rules

1. **New items enter at status NEW.** The Refresh Orchestrator never auto-actions them.
2. **Human reviews and sets status:**
   - `acknowledged` — seen, will act on it
   - `actioned` — memo/alert drafted, sent, or filed
   - `dismissed` — reviewed, decided not to act
3. **Items older than 30 days at status NEW get flagged** as potentially stale themselves.
4. **The queue is NOT a to-do list.** It's a decision surface. The human decides what to do.

### Relationship to Downstream Workflows

```
Development Queue (this framework)
       │
       ▼
Human Decision: "This needs a memo"
       │
       ▼
Virtual David / Email Drafter (separate system)
  reads KB as reference → drafts memo
       │
       ▼
Fact-Checker Mode 4 (this framework)
  verifies memo independently
       │
       ▼
Human sends memo
```

The Refresh Orchestrator surfaces the item. The Builder never touches the memo. The Fact-Checker verifies the memo. Clean separation.

---

## SECTION 5: CROSS-KB REFRESH PATTERNS

### Cascade Updates

Some developments affect multiple KBs. The Refresh Orchestrator handles this:

1. **Identify cascade scope.** A Supreme Court SEP ruling affects: IP/Patents KB, SEPs KB, every company KB with a SEP portfolio.
2. **Refresh the topic KB first.** It sets the authoritative analysis.
3. **Then refresh affected company KBs** with cross-references to the topic KB.
4. **Single development log entry per KB** — even if the same event triggers multiple updates.

### Portfolio-Wide Staleness Report

Periodically (quarterly recommended), produce a portfolio-wide report:

```markdown
# Portfolio Staleness Report — [Date]

## KBs by Freshness
| KB | Last Refresh | Days Since | Status |
|----|-------------|------------|--------|
| [name] | [date] | [N] | [Fresh/Due/Overdue] |

## Overdue KBs
[List of KBs past their refresh interval]

## Top Development Log Entries (Last Quarter)
[Top 10 Notable + all Breaking items from the quarter]

## Recommended Actions
[Which KBs to prioritize, which can wait]
```

---

## SECTION 6: CONFIGURATION

### Defaults (Override Per KB)

```yaml
refresh_interval_days:
  legal_topic: 30
  company: 60
  litigation: 14
  person: 90

volatile_type_cadences:
  docket-count: 7d
  penalty-rate: 365d
  exchange-rate: 30d
  event-date: 30d
  bill-status: 14d
  market-data: 14d
  rule-status: 30d
  case-status: 14d
  legislative-status: 14d
  leadership: 90d
  patent-count: 90d
  membership: 180d

staleness_thresholds:
  financial_data_quarters: 1
  litigation_status_days: 14
  regulatory_status_days: 30
  leadership_days: 90

development_log:
  default_tier: routine
  breaking_notification: true
  queue_stale_days: 30

verification:
  mode: refresh  # Fact-Checker Mode 3
  verify_changed_only: true
```

### Per-KB Overrides

Store in `sources/refresh_config.md` within each KB:

```markdown
# Refresh Configuration — [KB Name]
refresh_interval_days: 14    # Active litigation, check biweekly
event_triggers:
  - docket_activity
  - judicial_opinion
  - settlement_announcement
priority: high                # Check this KB first in batch refreshes
```

---

## SECTION 7: ANTI-PATTERNS

### Don't refresh and ship without verification
Every refresh cycle must include Fact-Checker verification of changed content. Refreshing introduces errors at the same rate as deepening (~12-16% without verification).

### Don't classify everything as Breaking
If more than 10% of development log entries in a quarter are Breaking, the threshold is too low. Recalibrate. The queue becomes noise.

### Don't rewrite stable content
The Refresh Orchestrator updates stale content and adds new developments. It does not rewrite sections that are accurate and current. Unnecessary rewrites introduce errors and destroy provenance.

### Don't cascade blindly
Not every development in a topic KB requires updates to all related company KBs. Cascade updates only when the development materially changes the company-specific analysis.

### Don't skip the staleness scan
Jumping straight to web search without first identifying what's stale wastes resources on content that's already current. The staleness scan focuses effort.

---

*This module maintains KBs after build. It detects staleness, applies updates, verifies changes, and — critically — surfaces breaking developments for human action. It does not draft memos. It does not build KBs from scratch. It keeps the portfolio current and actionable.*
