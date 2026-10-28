---
name: orca-codex-task-runner
description: Use when handing off, launching, waiting for, or reviewing a Codex coding task through Orca's native codex agent, especially for Orca-managed worktrees, existing worktree launches, dirty worktree protection, and safety-constrained delegation. Triggers include Orca Codex, Orca task, Orca worktree agent, 通过 Orca 创建 Codex 任务, Orca 后台 Codex, Orca 调用 Codex.
---

# Orca Codex Task Runner

## 核心原则

使用 Orca 原生 Agent ID `codex`。先区分完整交接与监督任务：交接在 Prompt 成功投递后结束；用户要求等待、监控、审查结果或协调时，必须使用 Orca `orchestration` 生命周期。

## 执行流程

1. **解析入口并加载当前指南**

   按顺序选择一次入口：`ORCA_CLI_COMMAND` 的完整值；开发会话中的 `orca-dev`；Linux 外部环境的 `orca-ide`；其他环境的 `orca`。Linux 下裸 `orca` 可能是同名屏幕阅读器。

   下文 `ORCA` 是占位符。每次执行时直接替换为选中的真实入口，不创建名为 `ORCA` 的 shell 变量，也不在失败后切换到另一个 Orca build。

   ```text
   ORCA skills get orca-cli
   ORCA status --json
   ```

2. **确认任务类型与边界**

   - “交给另一个 Agent/worktree”且未要求监督：完整交接。
   - 要求等待、监控、追踪完成、审查结果、消息或 DAG：监督任务，先执行 `ORCA skills get orchestration`。
   - 读取目标仓库规则，检查绝对仓库路径和 `git status --short`。
   - 决定创建隔离 worktree，还是在既有 Orca worktree 中启动。
   - 明确是否允许 commit、push、PR、部署、外部写入和服务启停。
   - 脏工作树必须禁止 reset、clean、覆盖和删除用户改动。

3. **组装 Prompt**

   Prompt 必须写清目标与验收、目录职责、已知证据（要求独立复核）、保护范围、验证命令、交付格式和副作用权限。不得包含 `.env`、Token、私有 fixture 或用户数据。

4. **执行完整交接**

   新隔离 worktree：

   ```text
   ORCA worktree create \
     --repo "path:<absolute-repo-root>" \
     --name <short-name> \
     --no-parent \
     --agent codex \
     --prompt "$prompt" \
     --json
   ```

   既有 worktree：

   ```text
   ORCA agent launch \
     --agent codex \
     --worktree "path:<absolute-worktree-path>" \
     --prompt "$prompt" \
     --json
   ```

   只有当前帮助明确支持且用户需要时才追加 `--model` / `--effort`。保存完整 JSON 和 `result.launch.outcome.handle`；旧 Host 可能返回 `result.agentTerminalHandle`。确认 `prompt.outcome` 为 `journaled` 或 `handed-to-terminal` 后报告 handoff，不等待接收者完成。丢失启动响应时只能使用错误返回的 `--retry-launch <operationId>` 重试，不能新建重复 Agent。

5. **执行监督任务**

   ```text
   ORCA orchestration run-create --objective "<objective>" --json
   ORCA orchestration worker-start \
     --spec "$prompt" \
     --worktree "path:<absolute-worktree-path>" \
     --agent codex \
     --json
   ORCA orchestration check \
     --wait \
     --types "worker_done,escalation,question" \
     --timeout-ms 900000 \
     --json
   ORCA orchestration worker-read \
     --dispatch <dispatch-id> \
     --source auto \
     --limit 1000 \
     --json
   ```

   新 worktree 的监督任务使用当前指南支持的 `--worktree new-top-level --repo "path:<absolute-repo-root>" --name <short-name>`，不要先手工创建后重复启动。按当前 `orchestration` 指南处理消息、ack、settlement 和 release。空等待是检查点，不是失败。

6. **独立复核**

   收到并接受 `worker_done` 后，检查真实 diff、工作树保护和外部副作用，并当场重跑风险匹配的验证。Codex 自报通过或 Worker settled 都不是完成证据。

## 路由边界

- 本 Skill 负责 Codex 路由；普通交接使用 `orca-cli`，监督任务叠加当前版本的 `orchestration` 指南。
- 不直接用 raw `git worktree` 或任意 PTY 替代 Orca 已管理的状态。
- 未经明确授权，不关闭 Terminal、不删除 worktree、不停止其他 Worker。

## 红线

- 不泄露凭据、账号、用户数据或私有载荷。
- 不默认授权 commit、push、部署、生产写入或破坏性 Git 操作。
- 不把“Agent 已启动”“TUI 已空闲”写成“任务已验证”。
