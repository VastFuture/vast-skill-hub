# Orchestration Recipes Reference

> Load this file when implementing any of the eight target orchestration patterns. Each recipe is a complete, self-contained TypeScript snippet. Adapt it to your project's structure, testing framework, and configuration conventions.

## Table of Contents

1. [Parallel Development & Aggregation](#1-parallel-development--aggregation)
2. [Plan→Build→Review Pipeline](#2-planbuildreview-pipeline)
3. [Cross-Host Dispatch](#3-cross-host-dispatch)
4. [Event-Driven Supervision](#4-event-driven-supervision)
5. [Resident Role with Label Recovery](#5-resident-role-with-label-recovery)
6. [Terminal + Agent Mixed Orchestration](#6-terminal--agent-mixed-orchestration)
7. [Structured Multi-Model Batch Review](#7-structured-multi-model-batch-review)
8. [Temporary Task with Safety Cleanup](#8-temporary-task-with-safety-cleanup)

---

## 1. Parallel Development & Aggregation

Isolate each writer in its own worktree, run in parallel, aggregate results after all complete.

```typescript
import { createPaseoClient } from "@getpaseo/client";

async function parallelReformat(client: ReturnType<typeof createPaseoClient>, projectRoot: string) {
  const branches = ["auth-module", "payment-service", "user-profile"];
  const results = new Map<string, { status: string; message?: string; error?: string }>();

  const agents = await Promise.all(
    branches.map(async (branch) => {
      const workspace = await client.workspaces.create({
        source: {
          kind: "worktree",
          cwd: projectRoot,
          action: "branch-off",
          refName: "main",
          branchName: `feat/${branch}`,
        },
        title: `Reformat ${branch}`,
        agent: {
          cwd: projectRoot,
          config: { provider: "codex/gpt-5.5" },
          prompt: `Reformat all files under packages/${branch} to project style guidelines. Run lint and tests. Report any failures.`,
          labels: { "batch-id": Date.now().toString(), module: branch },
        },
      });
      return { workspace, branch };
    })
  );

  // Wait for all agents to finish
  const outcomes = await Promise.allSettled(
    agents.map(async ({ workspace, branch }) => {
      const agent = workspace.agents;
      // The first agent was created with the workspace; get its ID
      const list = await client.agents.list({
        filter: { labels: { "batch-id": agents[0].workspace.agents ? "placeholder" : "x" } },
      });
      // Fallback: poll until exactly one active agent in this workspace
      const active = list.entries.find((e) => e.agent.workspaceId === workspace.id && !e.agent.archivedAt);
      if (!active) return { branch, status: "error", error: "no agent found" };
      const handle = client.agents.ref(active.agent);
      const result = await handle.waitForFinish();
      return { branch, status: result.status, message: result.lastMessage, error: result.error };
    })
  );

  outcomes.forEach((outcome, i) => {
    const branch = branches[i];
    if (outcome.status === "fulfilled") results.set(branch, outcome.value);
    else results.set(branch, { status: "rejected", error: (outcome.reason as Error).message });
  });

  return Object.fromEntries(results);
}
```

**Verification contract**: every branch's result includes status and message; partial failures are reported individually; no worktree is left dangling.

---

## 2. Plan→Build→Review Pipeline

Sequential stages. Builder does not start if planner fails. Reviewer independently validates.

```typescript
import { createPaseoClient } from "@getpaseo/client";

type PipelineResult = {
  plan: { status: string; output?: string };
  build: { status: string; output?: string; errors?: string[] };
  review: { status: string; findings?: string[] };
};

async function runPipeline(client: ReturnType<typeof createPaseoClient>, projectRoot: string, featureDesc: string): Promise<PipelineResult> {
  const result: PipelineResult = { plan: { status: "pending" }, build: { status: "pending" }, review: { status: "pending" } };

  // Phase 1: Plan
  const planner = await client.agents.create({
    config: { provider: "claude/claude-sonnet-5" },
    cwd: projectRoot,
    title: "Feature planner",
    prompt: `Design a minimal implementation plan for: ${featureDesc}. Output a numbered list of changes with file paths. Do not write any code.`,
    labels: { stage: "plan", feature: featureDesc.slice(0, 20) },
  });
  const planOut = await planner.waitForFinish();
  result.plan = { status: planOut.status, output: planOut.lastMessage ?? undefined };
  if (planOut.status === "error") return result; // short-circuit

  // Phase 2: Build (only if plan succeeded)
  if (planOut.status === "idle") {
    const builder = await client.agents.create({
      config: { provider: "codex/gpt-5.5" },
      cwd: projectRoot,
      title: "Feature builder",
      prompt: `Implement the plan below. Run all relevant tests after each change.\n\n${planOut.lastMessage}`,
      labels: { stage: "build", feature: featureDesc.slice(0, 20) },
    });
    const buildOut = await builder.waitForFinish();
    result.build = { status: buildOut.status, output: buildOut.lastMessage ?? undefined };
    if (buildOut.status === "error" || buildOut.status === "timeout") return result;
  }

  // Phase 3: Review (independent of builder's self-assessment)
  const reviewer = await client.agents.create({
    config: { provider: "claude/claude-sonnet-5" },
    cwd: projectRoot,
    title: "Feature reviewer",
    prompt: `Review the current diff against the original plan. Report: (1) missing requirements, (2) unintended regressions, (3) test coverage gaps. Output a JSON array of findings.`,
    labels: { stage: "review", feature: featureDesc.slice(0, 20) },
  });
  const reviewOut = await reviewer.waitForFinish();
  result.review = { status: reviewOut.status, findings: reviewOut.lastMessage ? [reviewOut.lastMessage] : undefined };

  return result;
}
```

**Verification contract**: builder does not start when plan fails; reviewer's output is independent of builder's claim; each stage's result is persisted before the next starts.

---

## 3. Cross-Host Dispatch

Discover remote hosts, select target, dispatch agent there, dispose remote scope cleanly.

```typescript
import { createPaseoClient } from "@getpaseo/client";

async function dispatchToHost(client: ReturnType<typeof createPaseoClient>, targetHost: string, prompt: string) {
  // 1. Discover hosts
  const { hosts } = await client.hosts.list();
  const target = hosts.find((h) => h.serverId === targetHost || h.label === targetHost);
  if (!target) throw new Error(`Host not found: ${targetHost}`);
  if (!target.connected) throw new Error(`Host ${targetHost} is offline`);
  if (!target.enabled) throw new Error(`Host ${targetHost} is disabled`);

  // 2. Acquire remote scope
  const remote = await client.hosts.client(targetHost);
  try {
    // 3. Check provider availability on remote
    const providers = await remote.providers.listAvailable();
    const ready = providers.available.find((p) => p.provider === "codex");
    if (!ready) throw new Error(`No codex provider on host ${targetHost}`);

    // 4. Create agent on remote
    const agent = await remote.agents.create({
      config: { provider: "codex/gpt-5.5" },
      cwd: "/home/deploy/project",
      prompt,
      labels: { "dispatch-host": targetHost },
    });

    // 5. Wait for result
    const result = await agent.waitForFinish();
    return { host: targetHost, agentId: agent.id, status: result.status, message: result.lastMessage, error: result.error };
  } finally {
    // 6. Dispose remote scope — does NOT close origin client or stop agent
    await remote.dispose();
  }
}
```

**Verification contract**: remote scope is always disposed; host capability is checked before dispatch; agent ID is returned for later tracking.

---

## 4. Event-Driven Supervision

Subscribe to agent timeline, react to turn completion and permission events.

```typescript
import { createPaseoClient } from "@getpaseo/client";

async function superviseAgent(client: ReturnType<typeof createPaseoClient>, agentId: string) {
  const agent = client.agents.ref(agentId);
  await agent.refresh();
  if (!agent.current()) throw new Error(`Agent ${agentId} not found`);

  let turnCount = 0;
  let hasPermission = false;

  const unsubscribe = agent.timeline.subscribe((update) => {
    const { event } = update;
    if (event.type === "subscription_restored") {
      console.log("[supervise] Reconnected, events may be missed");
      return;
    }
    if (event.type === "error") {
      console.error("[supervise] Timeline error:", event.error);
      return;
    }
    if (event.type === "replacement") {
      void agent.timeline.refetch().catch(console.error);
      return;
    }
    if (event.type === "turn_completed") {
      turnCount++;
      console.log(`[supervise] Turn ${turnCount} completed`);
    }
    if (event.type === "turn_failed" || event.type === "turn_canceled") {
      console.warn(`[supervise] Turn ${turnCount} failed or canceled`);
    }
  });

  // Wait for initial live subscription
  await unsubscribe.ready;

  // Monitor for permission requests via periodic refresh
  const monitor = setInterval(async () => {
    await agent.refresh();
    if (agent.pendingPermissions?.length) {
      hasPermission = true;
      console.warn(`[supervise] ${agent.pendingPermissions.length} pending permission(s) on agent ${agentId}`);
    }
  }, 30_000);

  try {
    // Wait until agent is no longer active
    while (agent.status !== null && agent.status !== "idle" && agent.status !== "error") {
      await new Promise((r) => setTimeout(r, 5000));
      await agent.refresh();
    }
  } finally {
    clearInterval(monitor);
    unsubscribe();
  }

  return { agentId, finalStatus: agent.status, turnCount, hasPermission };
}
```

**Verification contract**: `unsubscribe.ready` awaited before monitoring starts; periodic refresh releases on cleanup; turn completion uses events, not `agent_update → idle`.

---

## 5. Resident Role with Label Recovery

Find an existing agent by label; create one only if missing. Survives process restarts.

```typescript
import { createPaseoClient } from "@getpaseo/client";

const ROLE_LABEL = "my-app-role";
const ROLE_VALUE = "planner";

async function getPlanner(client: ReturnType<typeof createPaseoClient>, projectRoot: string) {
  const listed = await client.agents.list({
    filter: { includeArchived: false, labels: { [ROLE_LABEL]: ROLE_VALUE } },
    page: { limit: 10 },
  });

  const existing = listed.entries.find(({ agent }) => agent.labels?.[ROLE_LABEL] === ROLE_VALUE);
  if (existing) {
    const handle = client.agents.ref(existing.agent);
    await handle.refresh();
    console.log(`Recovered existing planner: ${handle.id}, status: ${handle.status}`);
    return handle;
  }

  const agent = await client.agents.create({
    config: { provider: "claude/claude-sonnet-5" },
    cwd: projectRoot,
    title: " resident Planner",
    labels: { [ROLE_LABEL]: ROLE_VALUE, "created-by": "orchestrator" },
  });
  console.log(`Created new planner: ${agent.id}`);
  return agent;
}

// Usage
const planner = await getPlanner(client, process.cwd());
const plan = await planner.run("Plan the next small, shippable improvement.");
```

**Verification contract**: label namespace is namespaced (`my-app-role` not just `role`); `ref()` is followed by `refresh()` before using handle properties; new agents get an audit label (`created-by`).

---

## 6. Terminal + Agent Mixed Orchestration

Run a command in a workspace terminal while an agent works in parallel.

```typescript
import { createPaseoClient } from "@getpaseo/client";

async function buildAndMonitor(client: ReturnType<typeof createPaseoClient>, projectRoot: string) {
  // Agent reviews code
  const agent = await client.agents.create({
    config: { provider: "codex/gpt-5.5" },
    cwd: projectRoot,
    prompt: "Run the test suite and report failures.",
  });

  // Terminal watches build output
  const terminal = await agent.workspaceId
    ? client.workspaces.ref(agent.workspaceId).terminals.create({ name: "Build Watch" })
    : null;

  try {
    if (terminal) {
      terminal.write("npm test -- --watch\n");
      terminal.sendKeys(["Enter"]);
    }

    const result = await agent.waitForFinish();
    console.log(`Agent done: ${result.status}`);

    if (terminal) {
      const { lines } = await terminal.capture({ start: -50 });
      console.log("Terminal tail:", lines.join("\n"));
      await terminal.kill();
    }

    return result;
  } catch (err) {
    if (terminal) await terminal.kill().catch(() => undefined);
    throw err;
  }
}
```

**Verification contract**: terminal is killed in `finally`; workspace ID is confirmed before creating terminal; input send is followed by capture, not assumed completion.

---

## 7. Structured Multi-Model Batch Review

Multiple models review the same diff; parse and merge structured outputs.

```typescript
import { createPaseoClient } from "@getpaseo/client";

const RISK_SCHEMA = {
  type: "object",
  properties: {
    severity: { type: "string", enum: ["low", "medium", "high", "critical"] },
    file: { type: "string" },
    line: { type: "number" },
    description: { type: "string" },
  },
  required: ["severity", "file", "description"],
  additionalProperties: false,
};

async function batchReview(client: ReturnType<typeof createPaseoClient>, projectRoot: string) {
  const reviewers = await Promise.all([
    client.agents.create({
      config: { provider: "claude/claude-sonnet-5" },
      cwd: projectRoot,
      outputSchema: RISK_SCHEMA,
      prompt: "Review the current git diff for correctness and missed edge cases. Output JSON.",
      labels: { review-type: "correctness" },
    }),
    client.agents.create({
      config: { provider: "claude/claude-opus-4" },
      cwd: projectRoot,
      outputSchema: RISK_SCHEMA,
      prompt: "Review the current git diff for security vulnerabilities. Output JSON.",
      labels: { review-type: "security" },
    }),
    client.agents.create({
      config: { provider: "codex/gpt-5.5" },
      cwd: projectRoot,
      outputSchema: RISK_SCHEMA,
      prompt: "Review the current git diff for complexity and readability. Output JSON.",
      labels: { review-type: "complexity" },
    }),
  ]);

  const results = await Promise.allSettled(reviewers.map((a) => a.waitForFinish()));

  const findings: Array<{ reviewer: string; severity: string; file: string; description: string }> = [];
  for (let i = 0; i < reviewers.length; i++) {
    const r = results[i];
    const type = ["correctness", "security", "complexity"][i];
    if (r.status === "fulfilled" && r.value.status === "idle" && r.value.lastMessage) {
      try {
        const parsed = JSON.parse(r.value.lastMessage);
        findings.push({ reviewer: type, ...parsed });
      } catch {
        console.warn(`Failed to parse ${type} review output`);
      }
    } else if (r.status === "rejected") {
      console.error(`${type} review failed:`, (r.reason as Error).message);
    }
  }

  return findings.sort((a, b) => {
    const order = { critical: 0, high: 1, medium: 2, low: 3 };
    return (order[a.severity as keyof typeof order] ?? 4) - (order[b.severity as keyof typeof order] ?? 4);
  });
}
```

**Verification contract**: each reviewer's output is individually parsed and validated; failures are logged but do not abort the batch; results are prioritized by severity.

---

## 8. Temporary Task with Safety Cleanup

Create a short-lived agent, enforce a tight timeout, guarantee cleanup in `finally`.

```typescript
import { createPaseoClient } from "@getpaseo/client";

async function runSmokeTest(client: ReturnType<typeof createPaseoClient>, projectRoot: string) {
  const owned: Array<{ agent: Awaited<ReturnType<typeof client.agents.create>>; purpose: string }> = [];

  try {
    const agent = await client.agents.create({
      config: { provider: "codex/gpt-5.5" },
      cwd: projectRoot,
      title: "Smoke test",
      labels: { "temp-task": "smoke", "temp-created-at": new Date().toISOString() },
    });
    owned.push({ agent, purpose: "smoke-test" });

    const result = await agent.run(
      "Run the project's smoke test suite and report pass/fail count. Do not modify any source files.",
      { timeoutMs: 2 * 60_000 }
    );

    if (result.status !== "idle") {
      throw new Error(`Smoke test agent ended with status: ${result.status}${result.error ? ` — ${result.error}` : ""}`);
    }

    return { passed: true, output: result.lastMessage };
  } finally {
    // Clean up all owned temporary agents; ignore failures so one bad archive doesn't block others
    await Promise.allSettled(
      owned.map(({ agent, purpose }) =>
        agent.archive().catch((err) => console.warn(`Could not archive ${purpose}:`, err))
      )
    );
  }
}
```

**Verification contract**: all owned agents are archived in `finally`; `Promise.allSettled()` ensures one failure doesn't skip others; timeout does not trigger archive — only the `finally` block does; temporary agents are labeled with creation timestamp for audit.
