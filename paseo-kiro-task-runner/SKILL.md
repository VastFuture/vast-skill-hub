---
name: paseo-kiro-task-runner
description: Use when creating, supervising, waiting for, or reviewing a Kiro CLI coding task through Paseo, especially for background execution, Kiro planner or guide modes, permission-confirmation handling, explicit project directories, dirty worktrees, and safety-constrained delegation. Triggers include Paseo Kiro, background Kiro agent, 通过 Paseo 创建 Kiro 任务, Paseo 后台 Kiro, Paseo 调用 Kiro.
---

# Paseo Kiro Task Runner

## 核心原则

Paseo 中的 Provider ID 是 `kiro`，指向 Kiro CLI，不是 Kiro IDE。先核实 Provider 可用和权限模式，再创建后台任务。

## 执行流程

1. **检查入口与 Provider**

   ```bash
   command -v paseo
   paseo run --help
   paseo status --json
   paseo provider ls --json
   ```

   `kiro` 必须为 available。当前可见模式以 Provider 清单为准，例如 `kiro_default`、`kiro_planner`、`kiro_guide`；默认运行可省略 `--mode`。

2. **确认边界与权限**

   - 使用绝对 cwd，读取项目规则并检查脏工作树。
   - 确认 Kiro Provider 是否已配置可信工具策略；若仍弹权限请求，不盲目点击或注入确认字符。
   - 无人值守权限只能用于不含生产凭据、不能访问生产资源的环境。
   - 未经授权禁止 commit、push、部署和停止共享服务。

3. **组装 Prompt**

   写明目标与验收、目录职责、证据、保护范围、测试要求、失败处理和副作用权限。不得包含 `.env`、Token、私有 fixture 或用户数据。

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
     --provider kiro \
     --cwd <absolute-path> \
     --title "<short title>" \
     --label project=<project> \
     --json "$prompt"
   ```

   规划任务可在当场核实模式 ID 后追加 `--mode kiro_planner`；指南型任务可用 `kiro_guide`。不要把自然语言标签当 ID。

5. **保存、等待和复核**

   ```bash
   paseo inspect <agent-id> --json
   paseo logs <agent-id> --tail 100
   paseo wait <agent-id> --json --timeout 5400
   ```

   保存 Agent/Workspace ID；只启动一次阻塞式 wait。取消必须精确指定 Agent ID。完成后独立检查 diff、权限副作用和真实测试结果。

## Provider 特有风险

- `kiro` 是自定义 ACP Provider；Paseo 的通用 auto-accept 与 Kiro permission option 可能版本不兼容。
- 权限弹窗持续出现时，先检查 Provider 启动参数与 `--trust-all-tools` 配置，不重复创建任务。
- `--trust-all-tools` 等同放开任意工具；安全边界必须靠最小权限环境和 Prompt 约束守住。
- 不把 Paseo Agent、Kiro 对话和 tmux 会话混为一谈，也不要同时恢复同一任务。

完整权限排障：`/home/fenghaolin/workspace/prj/develop/openai/ai-dev-log/ops/paseo/kiro-cli-disable-confirmation.md`。
