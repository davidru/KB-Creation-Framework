# Hosts — KB Creation Framework v3.1
# Scope: Supported host index and capability-level matrix.
# Contract: See `..\HOST-CONTRACT.md`.

---

## SECTION 1: SUPPORTED HOST INDEX

Supported hosts are execution harnesses that satisfy `HOST-CONTRACT.md` at a verified capability level. Each host MUST have a `HOST-NOTES.md` file before it is promoted beyond this index.

| Host | Level | Status | Notes |
|---|---|---|---|
| Copilot CLI | L1a | Supported v3.1 default | [`hosts\copilot-cli\HOST-NOTES.md`](copilot-cli/HOST-NOTES.md) *(to be built in L2b)* |
| OpenCode | L1a | Supported v3.1 new host | [`hosts\opencode\HOST-NOTES.md`](opencode/HOST-NOTES.md) *(to be built in L2c)* |

Do not infer support for Claude Code, Codex CLI, Hermes Agent, Goose, OpenHands, Plandex, or other hosts from this directory. Those hosts were considered and deferred for later releases.

---

## SECTION 2: CAPABILITY-LEVEL MATRIX

| Capability | L1a — Full Multi-Agent with Cross-Family | L1b — Parallel Single-Family | L2 — Sequential Multi-Model | L3 — Single-Model |
|---|---|---|---|---|
| Absolute-path file-read | Required | Required | Required | Required |
| Absolute-path file-write, atomic per-file | Required | Required | Required | Required |
| PowerShell 7+ shell execution | Required | Required | Required | Required |
| Prompt-file sub-agent dispatch | Required | Required | Required, sequential only | Optional or unavailable |
| Model Registry handle resolution | Required | Required | Required | Required if a registry is used; no family switching |
| Per-dispatch model-family selection | Required | Not available for concurrent sub-agents | Available sequentially | Not available |
| Parallel dispatch | At least 4 concurrent | At least 4 concurrent | Not required | Not required |
| Cross-family parallel dispatch | Required | Not available | Not available | Not available |
| Rule 19 status | Fully enforced as designed | Not satisfied by parallel same-family work; requires sequential workaround or exception | Enforceable sequentially | Not enforceable |
| Quality Scorecard effect | No degradation flag | Records L1b and affected phases | Records L2 runtime degradation | Verdict MUST be `CONDITIONAL` |

### 2.1 Supported host comparison

| Capability | Copilot CLI | OpenCode |
|---|---|---|
| Declared v3.1 level | L1a | L1a |
| Absolute-path file-read | Required by contract; HOST-NOTES pending | Required by contract; HOST-NOTES pending |
| Absolute-path file-write, atomic per-file | Required by contract; HOST-NOTES pending | Required by contract; HOST-NOTES pending |
| PowerShell 7+ shell execution | Required by contract; HOST-NOTES pending | Required by contract; HOST-NOTES pending |
| Prompt-file sub-agent dispatch | Required by contract; HOST-NOTES pending | Required by contract; HOST-NOTES pending |
| Cross-family per-sub-agent model selection | Verified by direct use of the `task` tool model parameter; details pending HOST-NOTES | Verified at planning stage from OpenCode agent model configuration; primary-source HOST-NOTES pending |
| Minimum parallel dispatch | At least 4 for L1a; HOST-NOTES pending | At least 4 for L1a; HOST-NOTES pending |
| Streaming / steerable mid-flight feedback | Optional; HOST-NOTES pending | Optional; HOST-NOTES pending |

---

## SECTION 3: PER-HOST STATUS TABLE

| Host name | Level | Verified-by source | Last verification date |
|---|---|---|---|
| Copilot CLI | L1a | Direct use in v3.0/v3.1 planning; `task` dispatch accepts per-call model handles across families. HOST-NOTES evidence file pending. | 2026-06-06 |
| OpenCode | L1a | Planning-stage review of OpenCode agent model configuration; L2c HOST-NOTES must primary-source-verify invocation syntax, agents-block schema, and parallel dispatch semantics before final promotion. | 2026-06-06 |

The status table is not a substitute for `Validate-Host.ps1`. If runtime validation observes a lower level than this table, the observed level controls the build and the Quality Scorecard records the degradation.

---

## SECTION 4: HOW TO ADD A NEW HOST

1. Read `..\HOST-CONTRACT.md` in full.
2. Verify the host against each required capability using primary host documentation, repository source, or direct execution.
3. Create `hosts\<host-name>\HOST-NOTES.md` with the evidence required by `HOST-CONTRACT.md` Section 4.
4. Run `Validate-Host.ps1` and record the observed level.
5. Add the host to this README only at the verified level.
6. If the host is L1b, L2, or L3, document the Rule 19 consequence explicitly. Do not describe degraded execution as full v3.1 multi-agent independence.
