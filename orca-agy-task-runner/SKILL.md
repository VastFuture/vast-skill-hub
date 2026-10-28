---
name: orca-agy-task-runner
description: Use when handing off, launching, waiting for, or reviewing an Antigravity or AGY coding task through Orca's native antigravity agent, especially for Orca-managed worktrees, high-permission safety boundaries, dirty worktree protection, and independent verification. Triggers include Orca AGY, Orca Antigravity, Orca native antigravity agent, 通过 Orca 创建 AGY 任务, Orca 后台 Antigravity, Orca 调用 agy.
---

# Orca AGY Task Runner

## 核心原则

技能名沿用常用称呼 AGY，但 Orca 原生 Agent ID 是 `antigravity`，不是 `agy`。完整交接与监督任务必须分流；Antigravity 的 Prompt 约束不能替代 OS、凭据和网络隔离。

## 执行流程

1. **解析入口并加载当前指南**

   按顺序选择一次入口：`ORCA_CLI_COMMAND` 的完整值；开发会话中的 `orca-dev`；Linux 外部环境的 `orca-ide`；其他环境的 `orca`。Linux 下不要默认调用裸 `orca`。

   下文 `ORCA` 是占位符。直接替换为选中的真实入口，不创建 shell 变量，也不在失败后切换 Orca build。

   ```text
   ORCA skills get orca-cli
   ORCA status --json
   ```

2. **确认任务类型与高权限边界**

   - 未要求监督的所有权转移是完整交接。
   - 等待、监控、追踪完成、审查结果、消息或 DAG 是监督任务，先加载 `ORCA skills get orchestration`。
   - 读取目标项目规则，检查绝对路径和 `git status --short`。
   - 只在无生产凭据、不能访问生产资源的最小权限环境中运行高权限任务。
   - 明确禁止 reset、clean、覆盖用户改动，以及未经授权的 commit、push、部署和外部写入。
   - 并行任务文件边界重叠时必须串行，或使用符合项目规则的隔离 worktree。

3. **组装 Prompt**

   写明目标与验收、目录职责、已知证据（要求独立复核）、保护范围、验证命令、失败处理、交付格式和副作用权限。不得包含 `.env`、Token、私有 fixture 或用户数据。

4. **执行完整交接**

   新隔离 worktree：

   ```text
   ORCA worktree create \
     --repo "path:<absolute-repo-root>" \
     --name <short-name> \
     --no-parent \
     --agent antigravity \
     --prompt "$prompt" \
     --json
   ```

   既有 worktree：

   ```text
   ORCA agent launch \
     --agent antigravity \
     --worktree "path:<absolute-worktree-path>" \
     --prompt "$prompt" \
     --json
   ```

   `--agent agy` 是错误写法。模型参数仅在当前帮助和可用模型已核实时添加。确认 Prompt 已投递后报告 handoff，不等待完成；模糊启动失败只用返回的 `--retry-launch <operationId>` 重试。

5. **执行监督任务并独立复核**

   ```text
   ORCA orchestration run-create --objective "<objective>" --json
   ORCA orchestration worker-start \
     --spec "$prompt" \
     --worktree "path:<absolute-worktree-path>" \
     --agent antigravity \
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

   新 worktree 的监督任务使用当前指南支持的 `--worktree new-top-level --repo "path:<absolute-repo-root>" --name <short-name>`。按当前 `orchestration` 指南处理消息、ack、settlement 和 release。禁止因为空等待或暂时无输出就杀进程。

## AGY 特有风险

- Orca Agent 与 `agy` CLI conversation 是不同会话层，不同时恢复或操作同一任务。
- 不清理 Antigravity presence lock，不猜测内部恢复方式。
- 监督任务叠加 Orca 当前版本的 `orchestration` 指南，不用 Terminal idle 代替 Dispatch settlement。
- 未经明确授权，不关闭 Terminal、不删除 worktree、不停止其他 Worker。

## 红线

- 不泄露凭据、账号、用户数据或私有载荷。
- 不默认授权 commit、push、部署、生产写入或破坏性 Git 操作。
- 不把“Agent 已启动”“TUI 已空闲”写成“任务已验证”。
