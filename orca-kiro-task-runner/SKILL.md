---
name: orca-kiro-task-runner
description: Use when creating, supervising, waiting for, or reviewing a Kiro CLI coding task inside an Orca-managed terminal, especially when Orca has no native kiro agent ID, the TUI must be inspected before prompt delivery, permission confirmations may appear, and dirty worktrees require protection. Triggers include Orca Kiro, Kiro in Orca terminal, 通过 Orca 创建 Kiro 任务, Orca Terminal 托管 Kiro, Orca 调用 kiro-cli.
---

# Orca Kiro Task Runner

## 核心原则

Orca 当前未声明原生 `kiro` Agent ID。本 Skill 只使用 Orca Terminal 托管 `kiro-cli`。完整交接在 Prompt 投递后结束；需要等待、监控或审查结果时，先由 `worker-start --terminal` 将现有 Terminal 纳入 `orchestration` 生命周期。

## 执行流程

1. **解析入口并加载当前指南**

   按顺序选择一次入口：`ORCA_CLI_COMMAND` 的完整值；开发会话中的 `orca-dev`；Linux 外部环境的 `orca-ide`；其他环境的 `orca`。Linux 下裸 `orca` 可能是同名屏幕阅读器。

   下文 `ORCA` 是占位符。直接替换为选中的真实入口，不创建 shell 变量，也不在失败后切换 Orca build。

   ```text
   ORCA skills get orca-cli
   ORCA status --json
   ```

2. **确认任务类型、边界和 CLI**

   - 未要求监督的所有权转移是完整交接。
   - 等待、监控、追踪完成、审查结果、消息或 DAG 是监督任务，先加载 `ORCA skills get orchestration`。
   - 在目标执行 Host 上确认 `kiro-cli` 可用；不要用 `/usr/bin/kiro` 代替而不核实其身份。
   - 读取项目规则，检查绝对 worktree 路径和 `git status --short`。
   - 明确 Kiro 的权限策略；无人值守权限只可用于无生产凭据、不能访问生产资源的环境。
   - 未经授权禁止 commit、push、部署、生产写入和停止共享服务。

3. **组装 Prompt**

   写明目标与验收、目录职责、证据（要求独立复核）、保护范围、验证命令、失败处理、交付格式和副作用权限。不得包含 `.env`、Token、私有 fixture 或用户数据。

4. **创建 Terminal 并检查 TUI**

   ```text
   ORCA terminal create \
     --worktree "path:<absolute-worktree-path>" \
     --title "Kiro Worker" \
     --command "kiro-cli" \
     --json

   ORCA terminal read \
     --terminal <handle> \
     --screen \
     --json
   ```

   若屏幕显示登录、权限选择、更新提示、报错或仍在初始化，不发送 Prompt。需要人工确认的权限界面必须报告给用户，不能盲目发送数字、Enter 或确认字符。

5. **投递完整交接**

   ```text
   ORCA terminal send \
     --terminal <handle> \
     --text "$prompt" \
     --enter \
     --wait-submit 10 \
     --json
   ```

   既有 Terminal handoff 在 receipt 返回 `accepted: true` 时成立；随后报告 Terminal handle 并停止监督。`turn_started` 只是更强的提交证据，不是 handoff 必需条件。`--wait-submit` 超时不代表输入未被接受，禁止自动重发；模糊传输错误只用原 request ID 和完全相同的 payload 执行 `--retry-request <id>`。

6. **执行监督任务**

   创建 Terminal 并确认 TUI 可输入后，不先发送普通 Prompt，直接将该 Terminal 交给 orchestration：

   ```text
   ORCA orchestration run-create --objective "<objective>" --json
   ORCA orchestration worker-start \
     --spec "$prompt" \
     --worktree "path:<absolute-worktree-path>" \
     --terminal <handle> \
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

   按当前 `orchestration` 指南处理消息、ack、settlement 和 release。不得先用 `terminal send` 投递同一任务再 `worker-start --terminal`，以免重复执行。

7. **独立复核**

   接受 `worker_done` 后检查真实 diff、权限副作用和测试结果。Orca 托管 Terminal 不等于验证 Kiro 结果；必须以输出和仓库证据共同判断。

## Kiro 特有风险

- 禁止写 `agent launch --agent kiro`；当前没有原生 Agent 证据。
- 不同时用 tmux 或另一个 Kiro CLI 恢复同一会话。
- Planner、Guide、resume 或 trust 参数以当前 `kiro-cli --help` 为准，不在 Skill 中硬编码。
- 监督任务必须使用 `worker-start --terminal` 接管现有 Terminal；不能用 Terminal idle 模拟 Dispatch settlement。

## 红线

- 不盲目接受权限提示，不泄露凭据或用户数据。
- 未经明确授权，不关闭 Terminal、不删除 worktree、不停止其他 Worker。
- 不把“输入已接受”“turn 已开始”或“Worker settled”写成“任务已验证”。
