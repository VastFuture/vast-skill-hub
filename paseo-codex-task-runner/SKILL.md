---
name: paseo-codex-task-runner
description: Use when creating, supervising, waiting for, or reviewing a Codex coding task through Paseo, especially for background work, explicit project directories, dirty worktrees, provider readiness checks, and safety-constrained delegation. Triggers include Paseo task, Paseo Codex, background Codex agent, create agent with Paseo, 通过 Paseo 创建任务, Paseo 后台任务, Paseo 调用 Codex.
---

# Paseo Codex Task Runner

## 核心原则

先发现本机真实入口并验证 daemon、Provider、cwd，再创建任务。Paseo 负责任务托管，不替代发起者的独立代码审查和验证。

## 执行流程

1. **确认入口**

   ```bash
   command -v paseo
   paseo --version
   paseo run --help
   paseo status --json
   paseo provider ls --json
   ```

   不猜 MCP/SDK 方法。`codex` 必须显示 available；失败先查 `~/.paseo/daemon.log`。

2. **确认边界**

   - 校验绝对 `cwd`，区分聚合目录与 Git 仓库。
   - 读取目标项目规则；检查相关仓库 `git status --short`。
   - 决定是否复用 `--workspace`。仅在必要且符合项目规则时创建 worktree。
   - 明确是否允许 commit、push、启动/停止服务、外部写入。

3. **组装 Prompt**

   必须写清：目标与验收、目录职责、已知证据（要求独立复核）、保护范围、实现约束、验证命令、交付格式和副作用权限。不得包含 `.env`、Token、私有 fixture 或用户数据。

4. **创建后台任务**

   ```bash
   prompt=$(cat <<'PROMPT'
   目标：<用户可见结果>
   目录：<绝对路径与仓库职责>
   证据：<最小复现；请独立复核>
   保护：保留现有未提交改动和既有协议。
   验证：<测试、构建、真实交互>。
   权限：不要 commit、push、部署或操作生产资源。
   交付：根因、文件与行号、命令结果、未验证项。
   PROMPT
   )

   paseo run --background \
     --provider codex \
     --mode auto-review \
     --cwd <absolute-path> \
     --title "<short title>" \
     --label project=<project> \
     --json "$prompt"
   ```

   立即保存 `agentId`、`workspaceId`、`cwd`、provider 和 status。

5. **监督与等待**

   ```bash
   paseo inspect <agent-id> --json
   paseo logs <agent-id> --tail 100
   paseo wait <agent-id> --json --timeout 5400
   ```

   启动一次阻塞式 `wait`，不要 sleep/inspect 循环轮询。只有用户明确要求取消时才执行 `paseo stop <agent-id> --json`；禁止用 `--all` 或 `--cwd` 误伤其他任务。

6. **独立复核**

   Agent 空闲后检查实际 diff、脏工作树保留情况和副作用，再当场重跑风险匹配的测试。Codex 自报通过不是完成证据。

## 快速判断

| 现象 | 动作 |
|---|---|
| 找不到 Paseo 工具 | 先查 `command -v paseo` 和 `paseo --help` |
| daemon 有 PID 但请求失败 | 查有界 daemon 日志；不要把进程存在当健康 |
| Provider unavailable | 修复 Provider 认证/入口后再创建任务 |
| 自动创建了 workspace | 保存返回 ID；不要假定它是隔离 worktree |
| 工作树已有改动 | Prompt 明确禁止 reset、clean、覆盖和删除 |
| 任务长时间无输出 | 用一次 `inspect`/有界 `logs` 判断；不要高频轮询或擅自停止 |

## 红线

- 不泄露凭据、身份、订单或私有载荷。
- 不默认授权提交、推送、部署、生产写入或停止共享服务。
- 不覆盖用户改动，不删除任务现场。
- 不把“任务已创建”或“Agent 已完成”写成“修复已验证”。
