# Events, Recovery & Cleanup Reference

> Load this file when the task requires live timeline streaming, permission handling, reconnect logic, timeout management, or resource archival.

## Table of Contents

1. [Three-Layer Error Model](#1-three-layer-error-model)
2. [Owned Directory Subscriptions](#2-owned-directory-subscriptions)
3. [Timeline Events](#3-timeline-events)
4. [Timeout Semantics](#4-timeout-semantics)
5. [Reconnect & History Recovery](#5-reconnect--history-recovery)
6. [Permission Handling](#6-permission-handling)
7. [Resource Cleanup](#7-resource-cleanup)
8. [Common Mistakes](#8-common-mistakes)

---

## 1. Three-Layer Error Model

SDK errors fall into three distinct categories. Conflating them causes silent bugs.

### Layer 1: Promise Rejection

Connection failures, validation errors, RPC rejections, and SDK wait timeouts reject their promise:

```typescript
try {
  await client.connect();
} catch (err) {
  // Connection refused, auth failure, timeout
  console.error("Client error:", (err as Error).message);
  throw; // usually fatal — cannot proceed without a connection
}
```

### Layer 2: Agent Turn Status

`run()` / `waitForFinish()` returns `PaseoAgentRunResult` which contains `status`, `final`, `error`, and `lastMessage`. These are **expected states**, not exceptions:

```typescript
const result = await agent.waitForFinish();
// result.status is 'idle' | 'permission' | 'error' | 'timeout'
// Do NOT wrap this in try/catch — handle each status explicitly
```

### Layer 3: Unknown Mutation Outcome

When a mutation fails with `DAEMON_CONNECTION_LOST` and optional `outcome: "unknown"`, the server may have accepted the request before the connection dropped:

```typescript
try {
  await client.agents.create({ /* ... */ });
} catch (err) {
  const code = (err as { code?: string }).code;
  if (code === "DAEMON_CONNECTION_LOST") {
    const outcome = (err as { outcome?: string }).outcome;
    if (outcome === "unknown") {
      // Agent may or may not have been created — inspect before retrying
      const page = await client.agents.list({
        filter: { labels: { "intent-id": intentId } },
      });
      if (page.entries.some((e) => e.agent.workspaceId === expectedWorkspaceId)) {
        console.log("Agent already exists, using existing handle");
        return client.agents.ref(page.entries[0].agent.id);
      }
      // Safe to retry
      return client.agents.create({ /* ... */ });
    }
  }
  throw err;
}
```

## 2. Owned Directory Subscriptions

Plain `list()` returns a snapshot without starting observation. To receive live updates, pass `subscribe: {}`:

```typescript
const directory = await client.agents.list({
  filter: { includeArchived: false },
  subscribe: {},
});

directory.subscription.subscribe({
  snapshot({ entries }) {
    // Initial state — process all entries
  },
  update(message) {
    if (message.type !== "agent_update") return;
    const { kind, agent } = message.payload;
    if (kind === "upsert") {
      console.log(`${agent.id}: ${agent.status}`);
    } else if (kind === "remove") {
      console.log(`${message.payload.agentId} removed from directory`);
    }
  },
});

// When done:
await directory.subscription.release();
```

`client.agents.subscribe()` and handle-level `subscribe()` add **local listeners** to the observation — they do not request data from the server. Use the subscription's callbacks when multiple filtered views need separate handlers.

## 3. Timeline Events

```typescript
const unsubscribe = agent.timeline.subscribe((update) => {
  const { event } = update;
  if (event.type === "subscription_restored") {
    console.log("Reconnected; events may have been missed");
    return; // choose whether to refetch missed history
  }
  if (event.type === "error") {
    console.error("Timeline observation stopped:", event.error);
    return;
  }
  if (event.type === "replacement") {
    // Previous epoch invalid — refetch the page your UI needs
    void agent.timeline.refetch().then((page) => console.log(page.entries));
    return;
  }
  if (event.type === "timeline" && event.item.type === "assistant_message") {
    process.stdout.write(event.item.text);
  }
  if (event.type === "turn_completed") {
    console.log("\nTurn completed — safe to inspect result");
  }
});

// Wait for initial live subscription before starting work that depends on events
await unsubscribe.ready;
```

**Live-only delivery**: reconnect does not replay missed events. After `subscription_restored`, explicitly refetch history with cursor-based pagination if needed:

```typescript
const page = await agent.timeline.refetch({
  direction: "before",
  limit: 100,
  projection: "projected",
});
// Use page.startCursor, page.endCursor, page.hasOlder, page.hasNewer for paging
```

Do not infer turn completion from `agent_update.status === "idle"` — use `turn_completed`, `turn_failed`, or `turn_canceled` events, or the `run()` / `waitForFinish()` result.

## 4. Timeout Semantics

`waitForFinish(timeoutMs)` defaults to 10 minutes. When the deadline elapses:

- The agent **continues running** on the daemon.
- The result `status` is `"timeout"`.
- The agent remains visible in `list()` and can be resumed with `run()` or `send()`.

```typescript
const result = await agent.waitForFinish(300_000); // 5 minutes
if (result.status === "timeout") {
  // Agent still running — do NOT archive
  console.log(`Timeout after 5 min; agent ${agent.id} still active`);
  // Options: wait longer, send a follow-up, or let it run independently
}
```

Timeout is a **caller-side deadline**, not an agent cancellation. There is no SDK method to cancel a running turn — only `archive()` to stop the agent entirely.

## 5. Reconnect & History Recovery

After an unexpected disconnect, the SDK attempts automatic reconnect if `config.reconnect.enabled` is true. When the connection is restored:

1. The client emits `subscription_restored` on existing subscriptions.
2. No history is fetched automatically — missed events are lost.
3. A new `subscriptionId` is assigned; the old one is invalidated.

```typescript
// Pattern: reconnect + optional history refetch
agent.timeline.subscribe((update) => {
  if (update.event.type === "subscription_restored") {
    // Fetch missed history if the consumer needs it
    agent.timeline.refetch({ direction: "before", limit: 50 }).catch(console.error);
  }
});
```

When a live `replacement` event arrives, the previous epoch is invalidated. Fetch the page your consumer needs with the current cursor.

## 6. Permission Handling

By default, permission requests surface in the Paseo UI for human review. `waitForFinish()` returns `status: "permission"` when a request is pending.

To handle permissions programmatically, you **must** have explicit user authorization:

```typescript
// Only do this if the user has authorized programmatic permission handling
if (agent.pendingPermissions?.length) {
  const req = agent.pendingPermissions[0];
  await agent.respondToPermission({
    requestId: req.requestId,
    response: "allow", // or "deny"
  });
}
```

**Anti-pattern**: auto-approving all permissions. This defeats the purpose of the permission system and can cause unintended file writes or data access.

## 7. Resource Cleanup

Maintain an owned-resource ledger throughout the orchestrator's lifetime:

```typescript
const ownedAgents: Array<{ agent: PaseoAgentHandle; purpose: string }> = [];
const ownedWorkspaces: Array<{ workspace: PaseoWorkspaceHandle; purpose: string }> = [];

try {
  const agent = await client.agents.create({
    config: { provider: "codex/gpt-5.5" },
    cwd: process.cwd(),
    title: "Temporary smoke test",
  });
  ownedAgents.push({ agent, purpose: "smoke-test" });

  const result = await agent.run("Reply with READY and nothing else.", { timeoutMs: 2 * 60_000 });
  if (result.status !== "idle") throw new Error(result.error ?? result.status);
} finally {
  // Archive only what we created — never archive shared agents
  await Promise.allSettled(
    ownedAgents.map(({ agent, purpose }) =>
      agent.archive().catch((err) => console.warn(`Failed to archive ${purpose}:`, err))
    )
  );
}
```

Key rules:
- `client.close()` does **not** archive agents or workspaces.
- Archiving a parent **cascade-archives** its children.
- Call `detach()` on a child before archiving the parent if the child should survive independently.
- Use `Promise.allSettled()` so one failure does not prevent cleanup of others.
- Do not archive agents found via `list()` unless they are in your owned-resource ledger.

## 8. Common Mistakes

- ❌ Assuming `waitForFinish()` rejecting means the agent stopped — it may have timed out and is still running.
- ❌ Calling `archive()` inside a `finally` without checking the owned-resource ledger — may delete shared agents.
- ❌ Using `agent_update → idle` to detect turn completion in a timeline subscription — use `turn_completed` events instead.
- ❌ Not awaiting `unsubscribe.ready` before relying on live timeline events — initial attachment may not have completed.
- ❌ Assuming `subscription_restored` replays missed events — it does not; history must be refetched explicitly.
- ❌ Creating a new client after `close()` instead of reusing the same instance — the old instance's observations are lost.
- ❌ Forgetting to call `release()` on an owned directory subscription — leaks server-side observation slots.
