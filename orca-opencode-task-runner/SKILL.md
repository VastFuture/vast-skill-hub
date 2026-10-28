---
name: orca-opencode-task-runner
description: Use when handing off, launching, waiting for, or reviewing an OpenCode coding task through Orca's native opencode agent, especially for Orca-managed worktrees, OpenCode account or model readiness, dirty worktree protection, and safety-constrained delegation. Triggers include Orca OpenCode, Orca native OpenCode agent, 通过 Orca 创建 OpenCode 任务, Orca 后台 OpenCode, Orca 调用 OpenCode.
---

# Orca OpenCode Task Runner

## 核心原则

使用 Orca 原生 Agent ID `opencode`。完整交接在 Prompt 投递后结束；需要等待、监控或审查结果时使用 Orca `orchestration`。不要把 OpenCode CLI 参数直接复制成 Orca 参数。

## 执行流程

1. **解析入口并加载当前指南**

   按顺序选择一次入口：`ORCA_CLI_COMMAND` 的完整值；开发会话中的 `orca-dev`；Linux 外部环境的 `orca-ide`；其他环境的 `orca`。Linux 下裸 `orca` 可能不是 Agent 编排工具。

   下文 `ORCA` 是占位符。直接替换为选中的真实入口，不创建 shell 变量，也不在失败后切换 Orca build。

   ```text
   ORCA skills get orca-cli
   ORCA status --json
   ORCA account list --json
   ```

2. **确认任务类型、边界与 OpenCode 可用性**

   - 未要求监督的所有权转移是完整交接。
   - 等待、监控、追踪完成、审查结果、消息或 DAG 是监督任务，先加载 `ORCA skills get orchestration`。
   - 读取项目规则，检查绝对路径和 `git status --short`。
   - 确认执行 Host 上 OpenCode 可启动；账号或模型选择以当前 `account list` 和 CLI 帮助为准。
   - 未经授权禁止 commit、push、部署、生产写入和停止共享服务。
   - 脏工作树明确禁止 reset、clean、覆盖和删除。

3. **组装 Prompt**

   写明目标与验收、目录职责、证据（要求独立复核）、保护范围、验证命令、交付格式和副作用权限。不得包含 `.env`、Token、私有 fixture 或用户数据。

4. **执行完整交接**

   新隔离 worktree：

   ```text
   ORCA worktree create \
     --repo "path:<absolute-repo-root>" \
     --name <short-name> \
     --no-parent \
     --agent opencode \
     --prompt "$prompt" \
     --json
   ```

   既有 worktree：

   ```text
   ORCA agent launch \
     --agent opencode \
     --worktree "path:<absolute-worktree-path>" \
     --prompt "$prompt" \
     --json
   ```

   OpenCode 模型选择要求既有 worktree、已验证的执行 Host CLI 和可用模型，且不支持 `--effort`。默认不传模型；确有需要时先查看当前 `agent launch --help`。确认 Prompt 已投递后报告 handoff，不等待完成；模糊失败只用 `--retry-launch <operationId>` 幂等重试。

5. **执行监督任务**

   ```text
   ORCA orchestration run-create --objective "<objective>" --json
   ORCA orchestration worker-start \
     --spec "$prompt" \
     --worktree "path:<absolute-worktree-path>" \
     --agent opencode \
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

   新 worktree 的监督任务使用当前指南支持的 `--worktree new-top-level --repo "path:<absolute-repo-root>" --name <short-name>`。按当前 `orchestration` 指南处理消息、ack、settlement 和 release。接受 `worker_done` 后检查真实 diff、工作树保护和副作用，再当场运行风险匹配的测试。

## OpenCode 特有风险

- Orca 管理的 OpenCode 会话不要同时用 tmux 或 OpenCode CLI 恢复。
- `opencode2` 是另一个 Orca Agent ID，不是本 Skill 的默认替代；用户未指定时不要自动切换。
- 模型和账号可用性会变化，以当前 Host 返回为准，不硬编码配置。
- 监督任务叠加 Orca 当前版本的 `orchestration` 指南；不要自行用 Terminal idle 代替 Dispatch settlement。

## 红线

- 不泄露凭据、账号、用户数据或私有载荷。
- 不默认授权 commit、push、部署、生产写入或破坏性 Git 操作。
- 未经明确授权，不关闭 Terminal、不删除 worktree、不停止其他 Worker。
