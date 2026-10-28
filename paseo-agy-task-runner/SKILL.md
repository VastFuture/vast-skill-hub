---
name: paseo-agy-task-runner
description: Use when creating, supervising, waiting for, or reviewing an Antigravity or AGY coding task through Paseo, especially for background execution, full-access mode, explicit project directories, dirty worktrees, and safety-constrained delegation. Triggers include Paseo AGY, Paseo Antigravity, background AGY agent, 通过 Paseo 创建 AGY 任务, Paseo 后台 Antigravity, Paseo 调用 agy.
---

# Paseo AGY Task Runner

## 核心原则

技能名使用常用称呼 AGY，但 Paseo 中的真实 Provider ID 是 `antigravity`，不是 `agy`。每次创建前必须从 Provider 清单核实此映射和权限模式。

## 执行流程

1. **检查入口与映射**

   ```bash
   command -v paseo
   paseo run --help
   paseo status --json
   paseo provider ls --json
   ```

   `antigravity` 必须为 available；当前默认模式应显示为 `full-access`。若实际清单变化，以当场结果为准，不猜 Provider ID。

2. **确认高权限边界**

   - Full access 只能运行在无生产凭据、不能访问生产资源的最小权限环境。
   - 使用绝对 cwd，读取项目规则并检查脏工作树。
   - 明确禁止 reset、clean、覆盖用户改动，以及未经授权的 commit、push、部署和外部写入。
   - 并行任务文件边界重叠时必须串行或使用符合项目规则的隔离 worktree。

3. **组装 Prompt 并创建任务**

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
     --provider antigravity \
     --mode full-access \
     --cwd <absolute-path> \
     --title "<short title>" \
     --label project=<project> \
     --json "$prompt"
   ```

4. **保存、等待和复核**

   ```bash
   paseo inspect <agent-id> --json
   paseo logs <agent-id> --tail 100
   paseo wait <agent-id> --json --timeout 5400
   ```

   保存 Agent/Workspace ID；只启动一次阻塞式 wait。停止必须精确指定 Agent ID。完成后独立检查 diff、副作用和测试证据。

## Provider 特有风险

- `--provider agy` 是错误写法；Paseo 当前映射为 `antigravity`。
- `full-access` 权限很高，Prompt 约束不能替代 OS、凭据和网络隔离。
- Paseo Agent 与 AGY CLI conversation 是不同会话层，不同时恢复或操作同一任务。
- 不因任务无输出就清理 AGY presence lock 或杀进程；先用 Paseo 的 inspect 和有界 logs 判断。

相关 CLI 语义参考真源 Skill：`tmux-agy-workflow`；Paseo 创建流程参考 `/home/fenghaolin/workspace/prj/develop/openai/ai-dev-log/ops/paseo/creating-codex-tasks-with-paseo.md`。
