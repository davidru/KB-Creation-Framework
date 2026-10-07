# HOST-NOTES — OpenCode

Version: 3.1.0  
Host: OpenCode  
Last primary-source verification: 2026-06-07  
Repo verified: `github.com/sst/opencode` resolves through the GitHub API to `anomalyco/opencode`, default branch `dev`, commit `2006259a02a87edf9e37f253cbddf3188309026b`.

---

## 1. Declared capability level

**Declared level: L3 — not production-validated, conservative.**

OpenCode has the ingredients for L1a: configured agents can carry different `provider/model` assignments, subagents are invoked by the Task tool, and OpenCode's own Task tool instructions say to launch multiple agents concurrently when possible. The HOST-CONTRACT §3 L1a threshold, however, requires **at least four concurrent cross-family sub-agent dispatches** and HOST-CONTRACT §2.2 requires atomic per-file writes. Primary sources verified concurrency instructions in principle, but did not verify a four-agent cap/floor or built-in atomic write semantics. HOST-CONTRACT §2.2 says a host that cannot guarantee atomic per-file writes must not be declared above L3. Until `Validate-Host.ps1` proves the atomic-write wrapper and concurrency behavior, this host is L3 for production gating even though multi-model dispatch is source-supported.

**Promotion target:** L1a after `Validate-Host.ps1` demonstrates (1) four concurrent Task-tool subagents, (2) at least two model families in the same parent session, (3) framework atomic-write wrapper behavior, and (4) structured Markdown/JSON capture.

**Validate-Host status:** not run in this L2c build. No `Validate-Host.ps1` file was found in the local v3.1 tree during source review; observed level therefore remains unvalidated.

---

## 2. Capability map against HOST-CONTRACT §2

| HOST-CONTRACT capability | OpenCode mechanism | Verified status | Primary-source citation |
|---|---|---|---|
| §2.1 File-read with absolute paths | Built-in `read` tool takes `filePath` described as "The absolute path to the file or directory to read"; implementation also normalizes Windows paths and enforces external-directory permission. | Verified for absolute-path reads. | `packages/opencode/src/tool/read.ts`, blob `7aa12659792a43bc0c057d4a845beb2304b3d814`, commit `2006259...`; docs `https://opencode.ai/docs/tools` (accessed 2026-06-07). |
| §2.2 File-write with absolute paths, atomic per-file | Built-in `write` tool requires an absolute `filePath` and writes content with `fs.writeWithDirs`. Primary source does **not** say this write is atomic. | Absolute write verified; atomicity **adapter-required** and `[NEEDS-VERIFICATION]` by smoke test. | `packages/opencode/src/tool/write.ts`, blob `37be6d8c47bcec6ecc6c768b2c990e3597333500`, commit `2006259...`; docs `https://opencode.ai/docs/tools` (accessed 2026-06-07). |
| §2.3 Shell command execution — PowerShell 7+ floor | Config has `shell`; docs say compatible shells are used for agent tool calls. Shell prompt code recognizes `pwsh` as "PowerShell (7+)". Core bash tool output schema includes command, cwd, exitCode, output, truncation, and timeout fields. | Verified if project `opencode.json` sets `"shell": "pwsh"`. | `packages/core/src/v1/config/config.ts`, blob `f85175...`; `packages/opencode/src/tool/shell/prompt.ts`, blob `bec50d...`; `packages/core/src/tool/bash.ts`, blob `2365bb...`; docs `https://opencode.ai/docs/config` (accessed 2026-06-07). |
| §2.4 Sub-agent dispatch | OpenCode subagents are invoked manually by `@agent-name` or by the Task tool with `subagent_type`. Task tool creates a child session, selects the configured agent, and uses the subagent's configured model if present. | Verified for Task-tool dispatch by configured agent name. Direct dispatch "from prompt file path" is a framework wrapper duty: read the phase prompt file and pass its content to Task. | `https://opencode.ai/docs/agents`; `packages/opencode/src/tool/task.txt`, blob `c5e412...`; `packages/opencode/src/tool/task.ts`, blob `5ca166...`; commit `2006259...`. |
| §2.4 Structured output | Task tool says the agent returns one final message to the parent and the caller should specify exactly what the agent must return. `task.ts` wraps the final text in a `<task><task_result>...</task_result></task>` output. | Markdown text verified. JSON is possible as text or by file artifact, but separate machine-readable companion capture is `[NEEDS-VERIFICATION]`. | `packages/opencode/src/tool/task.txt`, blob `c5e412...`; `packages/opencode/src/tool/task.ts`, blob `5ca166...`; commit `2006259...`. |
| §2.5 Parallel sub-agent dispatch | Task tool instructions say to "Launch multiple agents concurrently whenever possible" using one message with multiple tool uses. OpenCode's own docs-locale workflow instructs an OpenCode run to launch translator subagent Task calls in parallel, but that workflow is disabled (`if: false`) and is evidence of intended usage rather than a runtime proof. | Runtime parallel dispatch and four-way concurrency cap/floor are `[NEEDS-VERIFICATION]`. | `packages/opencode/src/tool/task.txt`, blob `c5e412...`; `.github/workflows/docs-locale-sync.yml`, blob `5f921e...`; commit `2006259...`. |
| §2.5 Cross-family per-sub-agent dispatch | Agent config supports per-agent `model` in `provider/model` format. `Agent.Service` parses each configured agent model; Task tool uses `next.model` for the child session, otherwise inherits parent model. | Verified for static per-agent dispatch across providers/families, assuming provider credentials are available. | `https://opencode.ai/docs/agents`; `https://opencode.ai/docs/models`; `packages/core/src/v1/config/agent.ts`, blob `b220bd...`; `packages/opencode/src/agent/agent.ts`, blob `a04f53...`; `packages/opencode/src/tool/task.ts`, blob `5ca166...`; commit `2006259...`. |
| §2.6 Streaming / steering | Docs describe child sessions and navigation between parent/child sessions. Task tool has experimental background mode gated by `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true`. | Optional only. Not required for L1a; `[NEEDS-VERIFICATION]` for framework use. | `https://opencode.ai/docs/agents`; `packages/opencode/src/tool/task.ts`, blob `5ca166...`; commit `2006259...`. |

---

## 3. Repository, license, and host identity

OpenCode is an **AI coding agent**, not a library-only package: the README describes it as "The open source AI coding agent," gives CLI installation commands, and documents built-in primary agents and a general subagent. License is MIT. These points were verified in the repository primary source at commit `2006259a02a87edf9e37f253cbddf3188309026b`:

- `README.md`, blob `b5a4c8ddd9794e8c20bd287603bfa0c336522796`.
- `LICENSE`, blob `6439474beed8e0271df9862eff97ffd70ec2464c`.

---

## 4. OpenCode configuration model: static agents, not dynamic per-call model injection

OpenCode's project/runtime config uses the singular top-level key **`agent`**, not `agents`. This was verified in `https://opencode.ai/config.json` (accessed 2026-06-07) and in `packages/core/src/v1/config/config.ts`, where `agent` is the active field and `mode` is deprecated.

Each entry in `agent` may define:

| Field | Meaning for framework use | Source |
|---|---|---|
| `model` | Per-agent model in `provider/model` format. This is the static equivalent of Copilot CLI's dynamic per-call model argument. | `https://opencode.ai/docs/agents`; `https://opencode.ai/docs/models`; `packages/core/src/v1/config/agent.ts`. |
| `description` | Required by docs for agent selection and Task-tool descriptions. | `https://opencode.ai/docs/agents`. |
| `prompt` | System prompt string or `{file:./path}` reference, relative to the config file. | `https://opencode.ai/docs/agents`; `packages/core/src/v1/config/agent.ts`. |
| `mode` | `primary`, `subagent`, or `all`; omitted defaults to `all` in docs. | `https://opencode.ai/docs/agents`; `https://opencode.ai/config.json`. |
| `permission` | Per-agent permission map. Use this instead of deprecated `tools`. | `https://opencode.ai/docs/agents`; `https://opencode.ai/docs/tools`; `packages/core/src/v1/config/agent.ts`. |
| `steps` | Maximum agentic iterations before text-only response. | `https://opencode.ai/docs/agents`; `https://opencode.ai/config.json`. |
| `temperature`, `top_p`, `variant`, `hidden`, `disable`, `color` | Optional routing/UI/model controls. | `https://opencode.ai/config.json`; `packages/core/src/v1/config/agent.ts`. |
| `tools` | Deprecated compatibility field; normalizes to permissions. | `https://opencode.ai/docs/agents`; `packages/core/src/v1/config/agent.ts`. |
| Additional provider options | Unknown keys normalize into `options`; provider-specific options can be passed through. | `packages/core/src/v1/config/agent.ts`; `https://opencode.ai/docs/agents#additional`. |

**Architectural consequence:** OpenCode does not match Copilot CLI's "spawn this subagent now with model X" shape. The framework must render a stable OpenCode `agent` block from Phase 0.0 `model_assignment`, restart or re-read config when assignments change, and then dispatch by `subagent_type`.

If a framework-facing config file uses a plural conceptual `agents:` block, Phase 0.0 must translate it to OpenCode's verified singular `agent` object before OpenCode starts.

---

## 5. Static-agent configuration mechanism for this framework

### 5.1 Required Phase 0.0 behavior

1. Resolve every `model_assignment` handle through the Model Registry (`Resolve-Model.ps1`) into `(provider, family, model_id, endpoint, adapter path)` per HOST-CONTRACT §2.4.
2. Convert each resolved assignment into an OpenCode `provider/model_id` string.
3. Write or refresh the project `opencode.json` `agent` object before the run starts by invoking `Render-OpenCodeAgents.ps1` (shipped at framework root in v3.1.5). The script reads the resolved `model_assignment` from `sources/pipeline_state.md`, calls `Resolve-Model.ps1` per handle, and emits a complete opencode.json with one agent per framework role mapped to its specific `provider/model_id`.
4. Set `shell` to `pwsh` for HOST-CONTRACT §2.3.
5. Set `permission.task` on the Lead agent so it may invoke only the framework subagents required for the run.
6. Restart OpenCode or start a fresh OpenCode run after config changes. OpenCode's own customize skill says config is loaded once at startup and is not hot-reloaded (`packages/core/src/plugin/skill/customize-opencode.md`, blob `99b112...`, commit `2006259...`).

### 5.2 Worked example rendered from representative `model_assignment`

Renderable via: `pwsh Render-OpenCodeAgents.ps1 -AssignmentPath sources\pipeline_state.md -OpenCodeJsonPath .\opencode.json`

Representative assignment:

```yaml
model_assignment:
  lead: anthropic_sonnet_framework_lead
  claim_extractor: openai_gpt_claim_extractor
  memo_writer: anthropic_sonnet_writer
  critic_rubber_duck: openai_gpt_critic
  factcheck_scout: google_gemini_scout
```

Representative OpenCode `opencode.json` after Phase 0.0 resolution:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "shell": "pwsh",
  "permission": {
    "read": "allow",
    "glob": "allow",
    "grep": "allow",
    "edit": "allow",
    "bash": "allow",
    "task": "allow",
    "external_directory": "ask"
  },
  "agent": {
    "kb-lead": {
      "mode": "primary",
      "description": "KB Creation Framework Lead orchestrator.",
      "model": "anthropic/claude-sonnet-4-5",
      "prompt": "{file:./prompts/00-lead.md}",
      "permission": {
        "task": {
          "*": "deny",
          "claim-extractor-openai": "allow",
          "memo-writer-anthropic": "allow",
          "critic-rubber-duck-openai": "allow",
          "factcheck-scout-google": "allow"
        }
      }
    },
    "claim-extractor-openai": {
      "mode": "subagent",
      "description": "Extracts claims with verbatim source quotes; returns Markdown and JSON text.",
      "model": "openai/gpt-5.1-codex",
      "prompt": "{file:./prompts/15-claim-extractor.md}",
      "permission": { "read": "allow", "grep": "allow", "glob": "allow", "edit": "deny", "bash": "deny", "task": "deny" },
      "steps": 24
    },
    "memo-writer-anthropic": {
      "mode": "subagent",
      "description": "Writes the grounded memo only from the claim manifest.",
      "model": "anthropic/claude-sonnet-4-5",
      "prompt": "{file:./prompts/15-memo-writer.md}",
      "permission": { "read": "allow", "edit": "allow", "bash": "deny", "task": "deny" },
      "steps": 20
    },
    "critic-rubber-duck-openai": {
      "mode": "subagent",
      "description": "Adversarial critic for cite, qualifier, omission, and leakage review.",
      "model": "openai/gpt-5.1-codex",
      "prompt": "{file:./prompts/16-rubber-duck.md}",
      "permission": { "read": "allow", "grep": "allow", "glob": "allow", "bash": "deny", "edit": "deny", "task": "deny" },
      "steps": 24
    },
    "factcheck-scout-google": {
      "mode": "subagent",
      "description": "External primary-source verification scout.",
      "model": "google/gemini-3-pro",
      "prompt": "{file:./prompts/17-factcheck-scout.md}",
      "permission": { "read": "allow", "webfetch": "allow", "websearch": "deny", "bash": "ask", "edit": "deny", "task": "deny" },
      "steps": 24
    }
  }
}
```

The model strings above are illustrative outputs of Model Registry resolution. The registry, not HOST-NOTES, decides the exact provider IDs and model IDs used in production. The `permission.task` catch-all deny appears **before** specific allows because OpenCode permission rules use last-match-wins ordering; placing `"*": "deny"` last disables the Task tool for the intended subagents. The example denies `websearch` for the Google scout because OpenCode docs state websearch is available only with the OpenCode provider or when `OPENCODE_ENABLE_EXA` is set.

---

## 6. Dispatch and output rules for framework operators

### 6.1 Exact invocation syntax

Use the Task tool for Lead-controlled subagent dispatch:

```json
{
  "description": "Review grounded memo",
  "subagent_type": "critic-rubber-duck-openai",
  "prompt": "Read the attached prompt content and return the required findings table."
}
```

Manual TUI syntax is `@agent-name`, e.g. `@general help me search for this function`. For framework runs, prefer the Task tool because it records `subagent_type`, creates a child session, and returns a task output to the parent. Sources: `https://opencode.ai/docs/agents`; `packages/opencode/src/tool/task.txt`; `packages/opencode/src/tool/task.ts`.

### 6.2 Parallel dispatch

For independent phase reads or critic passes, the Lead should issue multiple Task tool calls in one assistant turn. This follows OpenCode's own Task instruction: "Launch multiple agents concurrently whenever possible; to do that, use a single message with multiple tool uses." The framework must still record model family, prompt path, output path, and success/failure metadata per HOST-CONTRACT §2.4.

### 6.3 Output capture

Task-tool output returns to the parent as one final text message wrapped by `task.ts` in a task-result structure. Therefore:

1. Prompts must require a final Markdown section with deterministic headings.
2. If JSON is needed, require either a fenced JSON block in the final message or a written JSON artifact path.
3. Treat JSON capture as `[NEEDS-VERIFICATION]` until `Validate-Host.ps1` confirms the exact parser path.

---

## 7. Known degradations and open questions

| Item | Disposition |
|---|---|
| Four-way concurrent subagents | `[NEEDS-VERIFICATION]` Primary sources verify OpenCode's intended concurrent Task-call usage, but not a runtime four-agent floor/cap. Required before L1a. |
| Atomic per-file writes | `[NEEDS-VERIFICATION]` OpenCode `write` is absolute-path capable but not documented as atomic. Use a framework PowerShell sibling-temp + replace wrapper and smoke-test it. |
| Prompt-file-backed Task dispatch | `[NEEDS-VERIFICATION]` Agent system prompts can use `{file:...}`. Task prompt input is text; framework should read phase prompt files before dispatch or verify an OpenCode-supported file expansion path. |
| Separate JSON companion capture | `[NEEDS-VERIFICATION]` Markdown final text is verified. JSON as a separately captured machine artifact needs framework parser/writer validation. |
| Config hot reload | OpenCode config is loaded once at startup; Phase 0.0 model-assignment refresh must restart OpenCode or begin a fresh `opencode run`. |
| Current HOST-NOTES level | L3 until `Validate-Host.ps1` records observed L1a; the L3 declaration is driven by unverified atomic-write and smoke-test gates, not by lack of source support for static multi-model agents. |

---

## 8. Provenance bibliography

All sources below are primary OpenCode sources or this framework's normative contract. Accessed 2026-06-07.

| Source | URL / path | Commit / blob | Tier used | Used for |
|---|---|---|---|---|
| OpenCode repo default branch | `https://github.com/sst/opencode` -> `https://github.com/anomalyco/opencode` | commit `2006259a02a87edf9e37f253cbddf3188309026b` | GitHub API / MCP | Canonical repository identity. |
| README | `README.md` | blob `b5a4c8ddd9794e8c20bd287603bfa0c336522796`, commit `2006259...` | GitHub MCP | CLI/coding-agent identity; built-in agents; `@general`. |
| License | `LICENSE` | blob `6439474beed8e0271df9862eff97ffd70ec2464c`, commit `2006259...` | GitHub MCP | MIT license. |
| Agents docs | `https://opencode.ai/docs/agents`; repo source `packages/web/src/content/docs/agents.mdx` | blob `53048b7927b9ea9d3bd5e49512675b00514d621b`, commit `2006259...` | `web_fetch` + GitHub MCP | Agent types, `@` mention, config fields, permissions, model override, task permissions. |
| Config docs | `https://opencode.ai/docs/config`; repo source `packages/web/src/content/docs/config.mdx` | blob `c1a69f5a866d03e46fc63f6ad892436853e641ec`, commit `2006259...` | `web_fetch` + GitHub MCP | Config precedence, `shell`, `agent`, model/provider options. |
| Config schema | `https://opencode.ai/config.json`; source `packages/core/src/v1/config/config.ts` | config.ts blob `f85175cb7909e17cd1773b26a5a9be1ac0950aae`, commit `2006259...` | `web_fetch`; auxiliary `curl.exe` schema inspection | Singular `agent`; no plural `agents`; shell/model fields. |
| Agent config schema | `packages/core/src/v1/config/agent.ts` | blob `b220bd7ef87d7e34598673fdb5ec8fa9c7a3146c`, commit `2006259...` | GitHub MCP | Agent fields; `tools` deprecation; additional keys normalize into `options`. |
| Agent runtime | `packages/opencode/src/agent/agent.ts` | blob `a04f5315b063c9ae1152a7a06472630653aebc23`, commit `2006259...` | GitHub MCP | Built-in agents; model parsing; per-agent model in runtime agent info. |
| Task tool instructions | `packages/opencode/src/tool/task.txt` | blob `c5e412f409d944fa3e5af5d41ebd7bc784e09b15`, commit `2006259...` | GitHub MCP | `subagent_type`; concurrency instruction; final output behavior. |
| Task tool implementation | `packages/opencode/src/tool/task.ts` | blob `5ca1666add7c61d4c8108721af977fc6936e1ad9`, commit `2006259...` | GitHub MCP | Child session creation; model selection; output wrapping; background gate. |
| Tools docs | `https://opencode.ai/docs/tools`; repo source `packages/web/src/content/docs/tools.mdx` | blob `e8d5e0963aeb6133d6f6093ae02fa6f656486f45`, commit `2006259...` | `web_fetch` + GitHub MCP | Built-in read/write/bash/edit/glob/grep/apply_patch tools and permissions. |
| Read tool | `packages/opencode/src/tool/read.ts` | blob `7aa12659792a43bc0c057d4a845beb2304b3d814`, commit `2006259...` | GitHub MCP | Absolute-path read behavior. |
| Write tool | `packages/opencode/src/tool/write.ts` | blob `37be6d8c47bcec6ecc6c768b2c990e3597333500`, commit `2006259...` | GitHub MCP | Absolute-path write behavior; no verified atomicity. |
| Bash/shell tool | `packages/core/src/tool/bash.ts`; `packages/opencode/src/tool/shell/prompt.ts` | blobs `2365bbc3b4f349d9dc3ba59b5478836debcfa4d7`, `bec50d98d9b3ea9babb8030b825c1e35ce2f9992`, commit `2006259...` | GitHub MCP | Shell command execution, output schema, timeout, `pwsh` profile. |
| Models docs | `https://opencode.ai/docs/models`; repo source `packages/web/src/content/docs/models.mdx` | blob `b135e7554d467ea70b386b006ae8cf10e9c225bb`, commit `2006259...` | `web_fetch` + GitHub MCP | Provider/model ID format and multi-provider support. |
| OpenCode docs-locale workflow | `.github/workflows/docs-locale-sync.yml` | blob `5f921e8bb71792b9cd4b36b8b9b357d5a03d70bc`, commit `2006259...` | GitHub MCP | OpenCode's own instruction to run subagent Task calls in parallel. |
| Permissions docs | `https://opencode.ai/docs/permissions`; repo source `packages/web/src/content/docs/permissions.mdx` | blob `19182e27491b8385468ff9bc753a198f23356116`, commit `2006259...` | `web_fetch` + GitHub MCP | Last-match-wins permission ordering; permission keys. |
| Task permission tests | `packages/opencode/test/permission-task.test.ts` | blob `e5d92c5815d97787e290a8f603b2ad95ff008947`, commit `2006259...` | GitHub MCP | `permission.task` wildcard and ordering behavior. |
| Config reload note | `packages/core/src/plugin/skill/customize-opencode.md` | blob `99b112d9a55153535f3404d1886ce999ada03689`, commit `2006259...` | GitHub code search + GitHub MCP | Config loaded once; restart required after config changes. |
| Framework host contract | `HOST-CONTRACT.md` | local v3.1.0 | Local file read | Capability levels and per-host HOST-NOTES requirements. |
