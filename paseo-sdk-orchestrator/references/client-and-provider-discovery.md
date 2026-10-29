# Client & Provider Discovery Reference

> Load this file when the task involves connecting to a Paseo daemon, selecting a provider, configuring provider-native options, or dispatching to a remote host.

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Client Lifecycle](#2-client-lifecycle)
3. [Authentication & Security](#3-authentication--security)
4. [Provider Discovery](#4-provider-discovery)
5. [Provider Options](#5-provider-options)
6. [Cross-Host Dispatch](#6-cross-host-dispatch)
7. [Common Mistakes](#7-common-mistakes)

---

## 1. Prerequisites

- **Node.js 22+** is required. Older versions will fail at import time.
- Install via the project's existing package manager:

```bash
npm install @getpaseo/client
# or
pnpm add @getpaseo/client
# or
yarn add @getpaseo/client
```

- Never pin a specific SDK version in a skill reference; the daemon determines compatibility at connection time.

## 2. Client Lifecycle

```typescript
import { createPaseoClient } from "@getpaseo/client";

const client = createPaseoClient({
  url: process.env.PASEO_DAEMON_URL ?? "ws://127.0.0.1:6767/ws",
});

try {
  await client.connect(); // resolves after daemon sends server info
  // ... use client ...
} finally {
  await client.close(); // removes listeners & connection; does NOT stop agents
}
```

| Method | Behavior |
|---|---|
| `connect()` | Promise<void>; resolves after daemon identifies itself |
| `close()` | Promise<void>; removes local listeners, closes WebSocket |
| `ensureConnected()` | Throws if not in `connected` state |
| `getConnectionState()` | Returns `idle \| connecting \| connected \| disconnected \| disposed` |

**Important**: `close()` does **not** archive agents or workspaces. Explicitly archive what you created in your `finally` block.

Reconnect after unexpected disconnect is controlled by `config.reconnect.enabled`. Do not silently assume the client will reconnect forever — set `maxDelayMs` appropriately.

## 3. Authentication & Security

| Config field | Purpose |
|---|---|
| `password` | Direct daemon password |
| `authHeader` | Complete Authorization header value for a proxy |
| `clientId` | Stable identifier for logs and subscriptions (auto-generated if omitted) |

**Never hard-code credentials.** Read from the project's existing configuration layer or injected environment variables. When logging client errors, strip or omit `password` and `authHeader` values.

For E2EE relay clients, pass `e2ee.enabled` and `e2ee.daemonPublicKeyB64`. Ordinary integrations can omit these fields.

## 4. Provider Discovery

### Wait for Ready Catalog

```typescript
const snapshot = await client.providers.waitForReady({
  cwd: process.cwd(),
  timeoutMs: 60_000,
});

for (const entry of snapshot.entries) {
  if (entry.status !== "ready") continue;
  for (const model of entry.models ?? []) {
    console.log(`${entry.provider}/${model.id}`);
  }
}
```

`waitForReady()` rejects after the timeout if any provider is still loading. `snapshot()` returns immediately and may include `loading` entries.

### Discover Modes, Features, and Diagnostics

```typescript
const models = await client.providers.listModels("codex", { cwd });
const modes = await client.providers.listModes("codex", { cwd });
const features = await client.providers.listFeatures({
  provider: `codex/${selectedModel}`,
  cwd,
  modeId: selectedMode,
});

const diagnostic = await client.providers.diagnostic("codex");
```

**Always use IDs returned by the daemon.** Never assume a mode named "full-access" exists on every provider — it may be `full_access`, `agent`, or absent entirely.

### Subscription for Live Updates

```typescript
const unsubscribe = client.providers.subscribe((update) => {
  const ready = update.entries.filter((e) => e.status === "ready");
  console.log("Ready providers:", ready.map((e) => e.provider));
});

// Later:
unsubscribe();
```

## 5. Provider Options

Provider-native `options` are validated strictly by each provider. An unknown key causes `client.agents.create()` to reject with a message naming the bad key.

### Codex Options

```typescript
config: {
  provider: "codex/gpt-5.5",
  options: {
    approval_policy: "never",
    sandbox_mode: "workspace-write",
    sandbox_workspace_write: {
      writable_roots: ["/absolute/path/to/project"],
      network_access: false,
      exclude_slash_tmp: true,
    },
    web_search: "disabled",
    features: { multi_agent_v2: true },
  },
}
```

| Option | Values |
|---|---|
| `approval_policy` | `untrusted` \| `on-request` \| `never` \| `{ granular: {...} }` |
| `sandbox_mode` | `read-only` \| `workspace-write` \| `danger-full-access` |
| `sandbox_workspace_write` | `writable_roots`, `network_access`, `exclude_slash_tmp`, `exclude_tmpdir_env_var` |
| `web_search` | `disabled` \| `cached` \| `indexed` \| `live` |
| `features` | Provider-feature boolean or policy object |

**Warning**: `approval_policy: "never"` only removes prompts. Without a restrictive `sandbox_mode`, the agent retains full filesystem and network access.

### Claude Options

```typescript
config: {
  provider: "claude/claude-sonnet-5",
  options: {
    disallowedTools: ["WebFetch"],
    sandbox: {
      enabled: true,
      failIfUnavailable: true,
      allowUnsandboxedCommands: false,
      filesystem: {
        allowWrite: ["/absolute/path/to/project"],
        denyRead: ["/Users/me/.ssh", "/Users/me/.aws"],
      },
      network: {
        allowedDomains: ["registry.npmjs.org", "github.com"],
        strictAllowlist: true,
      },
    },
  },
}
```

| Option | Values |
|---|---|
| `allowedTools` | Tool names permitted without asking |
| `disallowedTools` | Tool names permanently denied |
| `additionalDirectories` | Extra directories accessible |
| `sandbox` | Full sandbox config object |
| `settings.permissions` | `allow`/`ask`/`deny` rule lists |

`failIfUnavailable: true` makes agent creation fail when the sandbox cannot be established. Without it, the agent runs unsandboxed — a silent security regression.

### OpenCode Options

```typescript
config: {
  provider: "opencode/opencode/gpt-5.5",
  options: {
    permission: {
      read: "allow",
      edit: "allow",
      webfetch: "deny",
      external_directory: "deny",
      bash: {
        "git status": "allow",
        "git diff*": "allow",
        "git push*": "deny",
        "*": "ask",
      },
    },
  },
}
```

Every permission takes `ask` \| `allow` \| `deny`. Tools with a target accept a pattern map; later keys act as fallback. Tools without a target take a bare action.

### `modeId` vs `options`

`modeId` selects a Paseo-level operating mode from the provider's published list. `options` is provider-native and applied at session launch. When they overlap, `options` wins:

```typescript
config: {
  provider: "codex/gpt-5.5",
  modeId: "full-access",
  options: { sandbox_mode: "read-only" }, // effective: read-only
}
```

## 6. Cross-Host Dispatch

```typescript
// List registered hosts
const directory = await client.hosts.list();
// → { self: { serverId, label }, hosts: [...] }

// Add a host
const registration = await client.hosts.add({
  connection: "ssh://deploy@build-box",
  label: "Build box",
  metadata: { team: "infra" },
  sourceKey: "build-box",
});

// Acquire a remote scope (caller-owned, must dispose)
const remote = await client.hosts.client("srv_build_box");
try {
  const providers = await remote.providers.listAvailable();
  const agents = await remote.agents.list();
  // ... use remote APIs ...
} finally {
  await remote.dispose();
}

// Update / disable / remove
await client.hosts.update(registration.registrationId, { enabled: false });
await client.hosts.remove(registration.registrationId);
```

### Stable Error Codes

| Code | Meaning |
|---|---|
| `host_unknown` | Registration ID not found |
| `host_disabled` | Host is disabled; re-enable first |
| `host_offline` | Connection unreachable; retry or use another host |
| `permission_denied` | Auth failure for this host |
| `unsupported_capability` | Remote does not support the requested operation |
| `authentication_failed` | Credentials rejected |
| `server_id_mismatch` | Remote identity does not match registration |
| `self_host` | Cannot connect to self through host routing |
| `duplicate_host` | Connection already registered |

**Routing is one hop only.** Do not chain remote-to-remote calls.

When a request fails with `DaemonConnectionError` (`code: "DAEMON_CONNECTION_LOST"`) with optional `outcome: "unknown"` and known `serverId`, inspect the target resource before retrying — do not blindly re-issue the mutation.

## 7. Common Mistakes

- ❌ Passing `provider` as just `"codex"` without a model — the SDK requires `"provider/model"`.
- ❌ Assuming `client.close()` stops running agents — it does not.
- ❌ Calling `list()` without `subscribe: {}` when you need live updates — the plain list returns a snapshot only.
- ❌ Using a stale `serverId` after the host was removed — `hosts.client()` will throw `host_unknown`.
- ❌ Not disposing a remote scope — leaked observations persist until the origin client closes.
- ❌ Logging `password` or `authHeader` in error messages — they appear in stack traces.
