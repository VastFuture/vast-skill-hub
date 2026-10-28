---
name: paseo-opencode-task-runner
description: Use when creating, supervising, waiting for, or reviewing an OpenCode coding task through Paseo, especially for background execution, OpenCode agent-mode selection, explicit project directories, dirty worktrees, and safety-constrained delegation. Triggers include Paseo OpenCode, background OpenCode agent, 通过 Paseo 创建 OpenCode 任务, Paseo 后台 OpenCode, Paseo 调用 OpenCode.
---

# Paseo OpenCode Task Runner

## 核心原则

Paseo 中的 Provider ID 是 `opencode`。先验证 daemon、Provider 和绝对 cwd；Paseo 托管任务，发起者仍负责独立审查 diff 与测试。

## 执行流程

1. **检查入口与 Provider**

   ```bash
   command -v paseo
   paseo run --help
   paseo status --json
   paseo provider ls --json
   ```

   `opencode` 必须为 available。当前默认模式应从 `provider ls` 读取；不要把 OpenCode CLI 的 `--agent` 参数直接当成 Paseo `--mode`。

2. **确认边界**

   - 使用绝对 cwd，区分聚合目录和 Git 仓库。
   - 读取项目规则并检查相关仓库 `git status --short`。
   - 脏工作树必须明确禁止 reset、clean、覆盖和删除。
   - 未经授权禁止 commit、push、部署、生产写入和停止共享服务。

3. **组装完整 Prompt**

   写明目标、验收、目录职责、已知证据（要求独立复核）、保护范围、验证命令、交付格式和副作用权限。不得包含 `.env`、Token、私有 fixture 或用户数据。

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
     --provider opencode \
     --cwd <absolute-path> \
     --title "<short title>" \
     --label project=<project> \
     --json "$prompt"
   ```

   需要 Build、Plan、coder、explorer 或自定义 Agent 模式时，先以当前 `paseo provider ls --json` 为准，再追加 `--mode <provider-mode-id>`；不凭显示标签猜 ID。

5. **保存与监督**

   立即保存 `agentId`、`workspaceId`、cwd、provider 和 status。

   ```bash
   paseo inspect <agent-id> --json
   paseo logs <agent-id> --tail 100
   paseo wait <agent-id> --json --timeout 5400
   ```

   启动一次阻塞式 wait，禁止 sleep/inspect 循环轮询。只有用户明确要求取消时才精确执行 `paseo stop <agent-id> --json`。

6. **独立复核**

   Agent 空闲后检查实际 diff、工作树保护和副作用，再当场运行风险匹配的测试。OpenCode 自报通过不是完成证据。

## Provider 特有风险

- OpenCode Provider 的会话由 Paseo 管理；不要同时用 tmux/OpenCode CLI 恢复同一会话。
- 自定义模式会随 OpenCode 配置变化，始终以当前 Provider 清单为准。
- OpenCode helper 出现 `session.create timed out` 或 first-record watchdog 时，先按 Paseo OpenCode 排障文档诊断，不要反复创建新任务。
- 不用 `paseo stop --all` 或 `--cwd` 代替明确 Agent ID。

完整运维说明：`/home/fenghaolin/workspace/prj/develop/openai/ai-dev-log/ops/paseo/creating-codex-tasks-with-paseo.md`；OpenCode 排障：同目录 `opencode-troubleshooting.md` 与 `session-create-30s-timeout.md`。
