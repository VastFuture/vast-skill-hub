---
name: paseo-sdk-orchestrator
description: >
  Use when building or reviewing a TypeScript scheduler/orchestrator that uses the Paseo TypeScript SDK (@getpaseo/client). Triggers on: Paseo SDK orchestration, SDK-based agent dispatch, parallel Paseo agents, Paseo event-driven workflows, Paseo cross-host dispatch, Paseo timeline subscription, Paseo workspace/worktree orchestration, Paseo structured output, Paseo permission handling, Paseo cleanup and lifecycle. Chinese triggers include: Paseo SDK 调度、用 SDK 编排多个 Agent、跨 Host Paseo 任务、Paseo 事件驱动监督、Paseo 工作流清理与恢复。
---

# Paseo SDK Orchestrator

> **规范级别**：项目级操作技能
> **核心目标**：指导编码 Agent 在现有 TypeScript 项目中编写基于 `@getpaseo/client` 的可恢复、可监督、可跨 Host 的 SDK 调度程序。

**IRON LAW：NEVER GUESS PROVIDER CAPABILITIES OR MUTATION OUTCOMES. DISCOVER FROM THE TARGET DAEMON; AFTER CONNECTION LOSS, INSPECT BEFORE RETRYING.**

## Workflow Checklist

```
Paseo SDK Orchestrator Progress:

- [ ] Step 1: Define orchestration graph & ownership ⚠️ REQUIRED
- [ ] Step 2: Check project & SDK prerequisites ⛔ BLOCKING
- [ ] Step 3: Design client & host scope
- [ ] Step 4: Discover provider capabilities ⚠️ REQUIRED
- [ ] Step 5: Choose workspace & resource creation pattern
- [ ] Step 6: Implement supervision & state machine
- [ ] Step 7: Implement events, recovery & cleanup
- [ ] Step 8: Assemble selected orchestration recipes
- [ ] Step 9: Validate & deliver ⚠️ REQUIRED
```

## Step 1: Define Orchestration Graph & Ownership ⚠️ REQUIRED

Before writing any code, answer explicitly:

- Which nodes are serial, parallel, parent-child, or cross-host?
- What is each node's input, completion condition, and failure propagation rule?
- Which agents, workspaces, and terminals does this program own and must clean up?
- Which resources are only referenced (never archived)?
- What ID, label, or business key survives process restarts?

Write a short graph description in your working notes. Do not skip this step for "simple" tasks — ownership confusion is the most common source of data loss.

## Step 2: Check Project & SDK Prerequisites ⛔ BLOCKING

- Read the target project's rules, TypeScript configuration, package manager, and test framework.
- Confirm Node.js 22+ (SDK requirement).
- Verify `@getpaseo/client` is installed or will be added via the project's existing package manager. Do not introduce a new framework or DI container for a single scheduling logic.
- Identify where the project stores daemon URLs and credentials; never hard-code them.

## Step 3: Design Client & Host Scope

- Create the client with `createPaseoClient(config)` — URL and auth come from the project's existing config layer.
- Define one client lifetime per orchestrator instance; call `client.connect()` and `client.close()` in `finally`.
- Closing the client **does not stop** agents or archive workspaces — state this clearly in your error-handling section.
- For cross-host work: acquire a remote scope via `client.hosts.client(serverId)`; dispose it explicitly; never confuse IDs between hosts.

If this step involves provider selection, provider options, or remote hosts, load `references/client-and-provider-discovery.md`.

## Step 4: Discover Provider Capabilities ⚠️ REQUIRED

Never hard-code a provider/model/mode/feature ID. Instead:

1. Call `client.providers.waitForReady({ cwd })` to get the ready catalog.
2. Use `client.providers.listModels(provider)` / `listModes(provider)` / `listFeatures(draftConfig)` to discover IDs at runtime.
3. Build `config.provider` as `"${provider}/${modelId}"` from discovered values.
4. Pass `modeId`, `thinkingOptionId`, and `featureValues` only from the daemon's response.
5. If the user's requested provider is unavailable, report the fact and ask for a replacement — do not silently swap to a different model family.

Provider-native `options` follow strict schemas per provider (Codex, Claude, OpenCode). Unknown keys cause creation to fail with the bad key name; do not add them silently.

## Step 5: Choose Workspace & Resource Creation Pattern

- `workspaces.open(cwd)` — reuse the active workspace for a directory; use when the directory *is* the task identity.
- `workspaces.create({ source: { kind: "directory", path } })` — create a fresh workspace panel without file isolation.
- `workspaces.create({ source: { kind: "worktree", cwd, action, refName, branchName } })` — isolate parallel writers in a Paseo-managed worktree. Must comply with the project's own worktree rules.
- `background` is a **workspace creation intent**, never an agent property. Setting it on the agent object will reject.
- Persist `hostId` / `workspaceId` / `agentId` / `labels` / business idempotency key immediately after creation.

If this step involves agents, workspaces, worktrees, structured output, or terminals, load `references/agents-and-workspaces.md`.

## Step 6: Implement Supervision & State Machine

For every agent created, handle the full return type of `run()` / `waitForFinish()`:

| `status` | Meaning | Required action |
|---|---|---|
| `idle` | Turn completed; agent ready | Proceed with validation logic |
| `permission` | Waiting for a human decision | Report to user; do not auto-resolve without explicit authorization |
| `error` | Provider ended turn with error | Log `result.error`; decide retry or abort |
| `timeout` | Deadline elapsed; agent still running | Keep the agent alive; report status; never archive on timeout alone |

Use `send()` only when the caller truly does not need the result of this turn. `send()` returns `Promise<void>` — no result to inspect.

## Step 7: Implement Events, Recovery & Cleanup

Load `references/events-recovery-and-cleanup.md` when any of the following apply: live timeline, timeout handling, reconnect logic, permission responses, or resource archival.

Key rules:
- Wait for `unsubscribe.ready` before starting work that depends on timeline events.
- Reconnect emits `subscription_restored` — history is **not** replayed automatically; refetch by cursor if needed.
- If a mutation fails with `DAEMON_CONNECTION_LOST` and `outcome: "unknown"`, query by saved ID/label first; do not blindly replay the creation.
- Maintain an owned-resource ledger; archive only entries in it. Shared or referenced resources are untouched.
- Use `Promise.allSettled()` when cleaning multiple temporary agents.

## Step 8: Assemble Selected Recipes

Load `references/orchestration-recipes.md` and copy only the patterns relevant to the current task. Do not implement all eight recipes at once.

The eight supported patterns:
1. Parallel development & result aggregation
2. Plan → Build → Review sequential pipeline
3. Cross-host dispatch
4. Event-driven supervision
5. Resident role with label-based recovery
6. Terminal + agent mixed orchestration
7. Structured multi-model batch review
8. Temporary task with safety cleanup

## Step 9: Validate & Deliver ⚠️ REQUIRED

- Run the target project's TypeScript type checker and focused tests.
- Unit tests must cover: orchestration graph branches, four turn-result statuses, owned-resource cleanup, and "unknown outcome does not re-create" logic.
- If an authorized test daemon is available, run a credential-free smoke test; otherwise state explicitly that integration was not verified.
- Agent returning `idle` is not sufficient evidence — validate structured output, actual diffs, or downstream business proof.
- Scan generated code for: hardcoded passwords/auth headers/tokens, absolute personal paths, and hardcoded provider/model/mode/feature IDs.

## Confirmation Gates

The following operations require **explicit user authorization** before execution. Writing code alone does not trigger these gates:

- Connecting to a daemon or remote host other than the one the user specified.
- Creating agents or workspaces that incur cost or write files.
- Auto-approving or denying permission requests on behalf of the user.
- Modifying the daemon's global config.
- Registering, updating, disabling, or deleting a host.
- Archiving an existing agent/workspace or killing an existing terminal.
- Running integration tests that commit, push, deploy, or access production resources.

## Anti-Patterns

- ❌ Hard-coding "always available" provider/model/mode/feature IDs.
- ❌ Putting `background: true` on the agent object instead of the workspace creation options.
- ❌ Treating a `ref()` handle with all-null properties as a deleted resource — call `refresh()` first.
- ❌ Inferring turn completion from `agent_update → idle` alone; use `run()` result or `turn_completed` event.
- ❌ Assuming timeline history is complete after reconnect without explicit refetch.
- ❌ Retrying a creation mutation immediately after an `outcome: "unknown"` connection-loss error.
- ❌ Treating `approval_policy: "never"` as a sandbox — it only silences prompts, it does not restrict file/network access.
- ❌ Archiving an agent found through `list()` without confirming the orchestrator created it.
- ❌ Logging `password`, `authHeader`, API tokens, or raw prompt payloads.
- ❌ Treating Agent self-report of success as proof of code correctness or test pass.

## Pre-Delivery Checklist

- [ ] `SKILL.md` under 500 lines with frontmatter containing only `name` and `description`.
- [ ] Four references exist under `references/`; no unused sub-directories left from initialization.
- [ ] Iron Law present at the top of `SKILL.md`.
- [ ] Workflow checklist uses `⚠️ REQUIRED` and `⛔ BLOCKING` markers appropriately.
- [ ] Confirmation gates clearly enumerated before any destructive or costly operation.
- [ ] No hardcoded credentials, absolute personal paths, or permanent provider/model IDs.
- [ ] All TypeScript code examples compile against `@getpaseo/client` types (or are marked illustrative).
- [ ] Eight recipe patterns are each a complete, self-contained TypeScript example.
- [ ] No README, CHANGELOG, INSTALL_GUIDE, or placeholder files remain.
- [ ] Three-copy byte-identity verified: AgentMatrix source, `~/.agents/skills/`, and Skill Hub clone.
