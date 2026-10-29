# Agents & Workspaces Reference

> Load this file when the task involves creating agents, workspaces, worktrees, terminals, or structured-output agents.

## Table of Contents

1. [Workspace Creation Patterns](#1-workspace-creation-patterns)
2. [Agent Creation & Lifecycle](#2-agent-creation--lifecycle)
3. [Structured Output](#3-structured-output)
4. [Terminal Handling](#4-terminal-handling)
5. [Background Workspaces](#5-background-workspaces)
6. [Common Mistakes](#6-common-mistakes)

---

## 1. Workspace Creation Patterns

### Open Existing Directory

```typescript
const workspace = await client.workspaces.open("/Users/me/dev/storefront");
console.log(workspace.id, workspace.directory);
```

`open()` reuses the active workspace for the exact directory. Use when the directory itself is the task identity.

### Fresh Directory-Backed Workspace

```typescript
const workspace = await client.workspaces.create({
  source: { kind: "directory", path: "/Users/me/dev/storefront" },
  title: "Checkout issue 42",
});
```

Creates a new workspace panel even if another workspace already uses the same directory. The daemon still finds or creates the project automatically.

### Paseo-Managed Worktree

```typescript
const workspace = await client.workspaces.create({
  source: {
    kind: "worktree",
    cwd: "/Users/me/dev/storefront",
    action: "branch-off",
    refName: "main",
    branchName: "fix/checkout-42",
  },
  title: "Checkout issue 42",
});
```

The workspace owns the worktree at `~/.cursor/worktrees/<reponame>/<branchName>`. It is removed when the workspace is archived and no other active workspace references it.

**Project rule compliance**: If the project mandates specific worktree paths, branch naming, or base refs, create the worktree via `git worktree add` first, then pass the resulting directory to `workspaces.create({ source: { kind: "directory", path } })`.

### Combined Workspace + Agent Creation

```typescript
const cwd = "/Users/me/dev/storefront";
const workspace = await client.workspaces.create({
  source: { kind: "directory", path: cwd },
  title: "Review branch",
  agent: {
    cwd,
    config: { provider: "codex/gpt-5.5" },
    prompt: "Review the current diff and name the riskiest change.",
  },
});
```

Set `background` on the **workspace** options, not on the agent options. Passing `background` on the agent will reject.

## 2. Agent Creation & Lifecycle

### Basic Creation

```typescript
const agent = await client.agents.create({
  config: { provider: "claude/claude-sonnet-5" },
  cwd: "/Users/me/dev/storefront",
  prompt: "Review the checkout flow and propose one focused fix.",
  labels: { source: "checkout-review", "issue-id": "42" },
});
```

`create()` resolves as soon as the session exists — the prompt is still running.

### Run with Wait vs Send Fire-and-Forget

```typescript
// Wait for the turn result
const result = await agent.run("Now write the fix.");
if (result.status === "idle") {
  console.log(result.lastMessage);
}

// Fire-and-forget — no result to inspect
await agent.send("Continue in background.");
```

`run()` defaults to a 10-minute timeout. Pass milliseconds to change it. `send()` has no wait and returns `Promise<void>`.

### Continue Existing Agent by ID

```typescript
const agent = client.agents.ref("agent_01H8X...");
// ref() does NOT contact the daemon — properties are null until refresh/run/waitForFinish
await agent.refresh(); // fetches current snapshot; returns null if deleted
const result = await agent.run("Pick up where you left off.");
```

### Handle Four Turn Statuses

```typescript
const result = await agent.waitForFinish(600_000); // 10-minute default
switch (result.status) {
  case "idle":
    console.log("Completed:", result.lastMessage);
    break;
  case "permission":
    // Requires human decision — do not auto-resolve without authorization
    console.warn("Waiting on permissions:", agent.pendingPermissions?.length);
    break;
  case "error":
    throw new Error(`Agent error: ${result.error ?? "unknown"}`);
  case "timeout":
    // Agent is STILL RUNNING. Do not archive.
    console.warn("Timeout reached; agent still active. ID:", agent.id);
    break;
}
```

`timeout` is **not** cancellation. The agent continues on the daemon.

### Parent-Child Agents

```typescript
const child = await workspace.agents.create({
  config: { provider: "codex/gpt-5.5" },
  parent, // passes AgentAddress to establish parentage
  title: "Implement checkout fix",
  prompt: "Implement the accepted plan and run focused tests.",
});

// Archive parent cascades to children
await parent.archive();

// Or keep child alive after parent is gone
await child.detach();
```

`parent` accepts an `AgentAddress` (`{ serverId, agentId }`) or an agent handle. A handle's `address` preserves host identity after disconnect.

### Agent Handle Properties (Snapshot Semantics)

| Property | Type | Notes |
|---|---|---|
| `id` | `string` | Stable daemon agent ID |
| `workspaceId` | `string \| null` | Last observed; null until first snapshot |
| `status` | `AgentStatus \| null` | Last observed |
| `pendingPermissions` | `PermissionRequest[] \| null` | Last observed |
| `activeTurn` | `ActiveTurn \| null` | `{ turnId, startedAt }` |
| `lastUsage` | `Usage \| null` | Token counts, cost, context-window use |
| `lastError` | `string \| null` | Last recorded error |
| `archivedAt` | `string \| null` | null while active |
| `runtimeInfo` | `RuntimeInfo \| null` | Live provider, model, session ID |

A handle from `ref()` reads `null` for all optional properties until `refresh()`, `run()`, `waitForFinish()`, or `subscribe()` delivers a snapshot. Use `agent.current()` to get the whole last-observed snapshot.

## 3. Structured Output

```typescript
const schema = {
  type: "object",
  properties: {
    summary: { type: "string" },
    risk: { type: "string", enum: ["low", "medium", "high"] },
  },
  required: ["summary", "risk"],
  additionalProperties: false,
};

const agent = await client.agents.create({
  config: { provider: "codex/gpt-5.5" },
  cwd: process.cwd(),
  outputSchema: schema,
  prompt: "Assess the release risk of the current diff.",
});

const result = await agent.waitForFinish();
if (result.status !== "idle" || !result.lastMessage) {
  throw new Error(result.error ?? "Agent returned no structured output");
}

// Validate before using as trusted input
const assessment = JSON.parse(result.lastMessage) as { summary: string; risk: "low" | "medium" | "high" };
```

**Always validate parsed JSON in your application** before using it as trusted input. The provider may produce structurally valid but semantically incorrect output.

## 4. Terminal Handling

Terminals require a host that supports workspace terminals. Older hosts throw an update-host error.

```typescript
const terminal = await workspace.terminals.create({ name: "Development" });
terminal.write("echo ready");
terminal.sendKeys(["Enter"]);

const { lines } = await terminal.capture({ stripAnsi: true });
const { entries } = await workspace.terminals.list();
await terminal.kill();
```

`sendKeys()` recognizes: `Enter`, `Tab`, `Escape`, `Space`, `BSpace`, `C-c`, `C-d`, `C-z`, `C-l`, `C-a`, `C-e`. Other strings pass through literally. Input methods send without waiting for execution acknowledgment.

**Critical**: sending input is not execution completion. Always `capture()` or check `pane_current_command` to confirm the command finished before proceeding.

## 5. Background Workspaces

```typescript
const workspace = await client.workspaces.create({
  source: { kind: "directory", path: cwd },
  background: true,
  agent: {
    cwd,
    config: { provider: "codex/gpt-5.5" },
    prompt: "Run nightly migration check.",
  },
});

// Background workspaces are hidden from default discovery
const page = await client.agents.list({
  filter: { includeBackground: true },
});
```

`background` is a workspace creation-only option. Omission defaults to `false`. When a parent agent creates a new workspace, omission inherits the parent's workspace `background` value.

## 6. Common Mistakes

- ❌ Putting `background: true` on the agent object — it belongs on the workspace creation options.
- ❌ Assuming `workspace.agents.create()` copies the parent workspace's `background` flag — it does not unless inheritance applies.
- ❌ Using `ref()` and immediately reading `status` or `workspaceId` without calling `refresh()` first — they will be `null`.
- ❌ Archiving an agent found through `list()` without checking whether your orchestrator created it — use an owned-resource ledger.
- ❌ Treating `agent_update.status === "idle"` as turn completion when using subscriptions — use `turn_completed` events or `run()` results instead.
- ❌ Setting `outputSchema` on agents that do not support structured output — the daemon will reject the creation.
- ❌ Not validating JSON from `outputSchema` responses before treating them as trusted input.
