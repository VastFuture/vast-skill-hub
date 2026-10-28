---
name: paseo-qoder-task-runner
description: Use when creating, supervising, waiting for, or reviewing a Qoder CLI coding task through Paseo, especially for background execution, Qoder permission or plan modes, explicit project directories, dirty worktrees, and safety-constrained delegation. Triggers include Paseo Qoder, background Qoder agent, 通过 Paseo 创建 Qoder 任务, Paseo 后台 Qoder, Paseo 调用 Qoder.
---

# Paseo Qoder Task Runner

## 核心原则

Paseo 中的 Provider ID 是 `qoder`。先读取 Provider 当前默认模式和权限选项；不要把本机 `qodercli` 命令参数直接复制成 Paseo `--mode`。

## 执行流程

1. **检查入口与 Provider**

   ```bash
   command -v paseo
   paseo run --help
   paseo status --json
   paseo provider ls --json
   ```

   `qoder` 必须为 available。Provider 可能显示 Default、Accept Edits、Bypass Permissions、Plan；默认任务省略 `--mode`，特殊模式使用当前配置实际 ID。

2. **确认边界**

   - 使用绝对 cwd，读取项目规则，检查相关 Git 工作树。
   - 脏工作树明确禁止 reset、clean、覆盖和删除。
   - Bypass Permissions 仅可在最小权限、无生产凭据环境中使用。
   - 未经授权禁止 commit、push、PR、部署和生产写入。

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
     --provider qoder \
     --cwd <absolute-path> \
     --title "<short title>" \
     --label project=<project> \
     --json "$prompt"
   ```

   只有在用户明确选择计划或权限策略且 ID 已核实时，才追加 `--mode <provider-mode-id>`。

4. **保存、等待和复核**

   ```bash
   paseo inspect <agent-id> --json
   paseo logs <agent-id> --tail 100
   paseo wait <agent-id> --json --timeout 5400
   ```

   保存 Agent/Workspace ID，只启动一次阻塞式 wait。取消时精确指定 Agent ID。任务结束后独立检查 diff、工作树保护和当场测试结果。

## Provider 特有风险

- Qoder CLI 入口在本机可能叫 `qodercli`，但 Paseo Provider ID 固定使用配置中的 `qoder`。
- Qoder 的本地/远程对话恢复参数不适用于 Paseo Agent 管理；不要同时恢复同一任务。
- Bypass Permissions 能执行高副作用操作，不能仅靠模型自律保证安全。
- 不使用 `paseo stop --all` 或 `--cwd` 代替明确 Agent ID。

相关 CLI 语义参考真源 Skill：`tmux-qoder-cli-workflow`；Paseo 创建流程参考 `/home/fenghaolin/workspace/prj/develop/openai/ai-dev-log/ops/paseo/creating-codex-tasks-with-paseo.md`。
