---
name: tmux-cursor-workflow
description: >
  Use when running Cursor CLI coding tasks in persistent tmux sessions, especially for unattended long-running work, parallel Cursor agents, progress inspection, interrupted terminal recovery, chat resume, or stuck process cleanup. Triggers include start Cursor in background, tmux Cursor, resume Cursor chat, continue Cursor session, check Cursor progress, parallel Cursor tasks, stop Cursor; Chinese triggers include 启动Cursor、后台Cursor、tmux Cursor、恢复Cursor、继续Cursor、检查Cursor进度、并行Cursor、停止Cursor、杀Cursor僵尸。
---

# TMUX + Cursor CLI Workflow

> **规范级别**：项目级操作技能
> **核心目标**：通过 tmux 持久化 Cursor CLI，让长时间 AI 编码任务在终端断连后继续运行并可恢复管理。

**命令名**：官方主入口是 `agent`。先运行 `command -v agent` 与 `agent --version` 核实当前安装；部分机器同时提供 `cursor-agent`，只有在确认两者指向同一二进制时才把它当作别名，文档和自动化统一使用 `agent`。

**IRON LAW：不要混淆 tmux 终端会话与 Cursor chat。tmux 只负责让进程存活；对话上下文必须通过 `agent ls`、`agent resume`、`agent --continue` 或 `agent --resume=<chat-id>` 恢复。**

**默认权限契约**：按本技能约定，长任务默认用 `agent --yolo` 启动。`--yolo` 是 `--force` 的别名，会强制允许未被显式拒绝的命令；它不是“仅跳过确认”，也不授予提交、推送、部署或生产写入权限。只在已信任、无生产凭据、任务边界明确的工作区使用。

## 一、执行检查单

```text
TMUX + Cursor CLI Progress:

- [ ] 确认项目目录、仓库规则、任务边界和 tmux 会话名
- [ ] 检查同名 tmux 会话，避免误连或覆盖
- [ ] 确认 `agent` 入口、版本、登录状态和可用模型
- [ ] 确认工作区不含生产凭据，且 `--yolo` 风险已被接受
- [ ] 并行或高风险改动使用符合项目规则的独立 worktree
- [ ] 使用 `agent --yolo` 启动并确认已进入 Cursor TUI
- [ ] 发送完整任务、保护范围、验证要求和外部副作用边界
- [ ] 定期捕获输出并结合 pane 进程判断状态
- [ ] 任务结束后独立检查 diff 与真实验证结果
- [ ] 经用户确认后停止进程或删除 tmux 会话
```

## 二、核心命令速查

```bash
# 示例变量
SESSION=cursor-<topic>
PROJECT_DIR=<absolute-project-dir>

# 核实入口、版本、认证和模型；不要打印 API Key
command -v agent
agent --version
agent status
agent models

# 创建持久会话；同名会话已存在时会失败，不会覆盖
tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR" -x 200 -y 50

# 默认启动：高权限无人值守模式
tmux send-keys -t "$SESSION" 'agent --yolo' Enter

# 发送任务前先确认已进入 Cursor TUI，未停在登录或启动错误
tmux capture-pane -t "$SESSION" -p -S -60

# 发送短任务
tmux send-keys -t "$SESSION" '<任务描述与验收条件>' Enter

# 查看最近输出
tmux capture-pane -t "$SESSION" -p -S -120

# 进入会话；退出但保持运行按 Ctrl-b d
tmux attach-session -t "$SESSION"
```

如果当前版本的 `agent --help` 明确提供 `--auto-review`，需要降低权限时可改为：

```bash
tmux send-keys -t "$SESSION" 'agent --auto-review --sandbox enabled' Enter
```

`--auto-review` 会自动执行被分类为安全的工具调用，其余操作请求确认；该选项可能随版本变化，使用前必须以当前 `agent --help` 为准。若版本不支持，直接运行不带 `--yolo` 的 `agent`，逐次审批。

只读探索使用 `agent --mode ask`；先规划不实施使用 `agent --plan` 或 `agent --mode plan`。不要为了“方便”给只读任务叠加 `--yolo`。

## 三、可靠投递任务

只有在 `capture-pane` 显示 Cursor TUI 已就绪后才能投递任务。过早发送可能让任务文本落到 Shell 提示符并被当作命令执行。

任务至少说明：

- 要解决的问题、允许修改的目录和文件边界；
- 必须保持不变的 API、行为、数据和用户现场；
- 必须运行的测试、检查命令和验收条件；
- 是否允许联网、安装依赖、提交、推送、创建 PR 或部署；
- 完成后需要返回的 diff、测试和残余风险证据。

短提示可直接用 `tmux send-keys`。提示包含多行 Markdown、引号或 Shell 片段时，先写入一个已确认不会提交且不含凭据的文件，再发送一条简短指令让 Cursor 读取：

```bash
PROMPT_FILE=<absolute-path-to-prompt.md>
tmux send-keys -t "$SESSION" "请读取 $PROMPT_FILE，严格按其中任务边界和验收条件执行。" Enter
```

任务结束后按项目规则删除临时提示文件。若内容应成为长期事实源，就放到项目规定的文档目录，不要当临时文件处理。

`--yolo` 只改变 Cursor 的工具确认策略，不扩大用户授权范围。Prompt 没有明确允许时，Cursor 不得提交、推送、创建 PR、部署、改生产配置、写生产数据或执行破坏性 Git 操作。

## 四、状态与进度诊断

```bash
# tmux 会话是否存在
tmux has-session -t "$SESSION"

# 列出约定以 cursor- 开头的会话
tmux list-sessions -F '#{session_name} #{session_attached} #{session_activity}' | grep '^cursor-'

# 查看 pane 的 shell PID、前台命令和 dead 状态
tmux list-panes -t "$SESSION" -F '#{pane_pid} #{pane_current_command} #{pane_dead}'

# 查看最近输出
tmux capture-pane -t "$SESSION" -p -S -160

# 从 pane shell PID 查直接子进程
PANE_PID=$(tmux display-message -p -t "$SESSION" '#{pane_pid}')
pgrep -P "$PANE_PID" -a || true
```

判断状态时同时回答：tmux 会话是否存在、pane 中是否仍有 `agent`/`cursor-agent` 进程、最近输出是否在推进。暂时无输出可能是模型推理、工具运行或等待外部命令，不能单凭时间判定为僵尸。

常见情况：

| 现象 | 处理 |
|---|---|
| 停在登录或账号错误 | 在可信终端完成 `agent login`，再重新启动；不要把凭据粘进 tmux 日志 |
| 停在 workspace trust | 确认目录可信后重新以 `--yolo` 启动；`--trust` 只处理工作区信任，不等于工具权限放开 |
| 等待工具确认 | 先读清请求内容；如果本应默认无人值守，停止后用 `--yolo` 恢复 chat，不要盲发 `y` |
| pane 仍在但 Cursor 已退出 | 读取退出信息，再用 `--continue` 或精确 chat ID 恢复 |
| 长时间无输出 | 查 pane、子进程与最后一条工具调用；仍无法判断时保留现场并报告 |

## 五、恢复 Cursor chat

优先在原项目目录恢复；项目上下文、规则和文件状态可能影响恢复结果。

```bash
# 交互选择历史 chat
agent ls

# 恢复最近 chat
agent resume

# 继续上一 chat；适合重新启动 TUI
agent --yolo --continue

# 精确恢复指定 chat；长任务优先记录 chat ID
agent --yolo --resume=<chat-id>
```

在新的 tmux 会话中恢复：

```bash
tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR" -x 200 -y 50
tmux send-keys -t "$SESSION" 'agent --yolo --resume=<chat-id>' Enter
```

| 场景 | 正确操作 |
|---|---|
| tmux 仍在且 Cursor 仍运行 | `attach-session` 或 `capture-pane`，不要启动第二个 Cursor 进程 |
| tmux 存在但 Cursor 已退出 | 在原 pane 中按退出原因执行 `--continue` 或 `--resume=<chat-id>` |
| tmux 已消失 | 在原项目目录创建新 tmux 会话，再恢复 Cursor chat |
| 只需要最近一次上下文 | `agent --yolo --continue` |
| 多条 chat 容易混淆 | 先 `agent ls`，再用精确 chat ID 恢复 |

当前官方 CLI 没有 `persist` 子命令。不要把 `agent persist` 写入脚本，也不要猜测或直接修改 Cursor 的本地 chat 存储、锁文件和日志；存储位置会随版本变化。

## 六、并行任务与 worktree

每个独立任务使用不同的 tmux 会话名和文件边界。会修改相同文件、共享生成物或依赖前序结果的任务必须串行，或放入隔离 worktree 后再执行。

Cursor 可用 `--worktree [name]` 在 `~/.cursor/worktrees/<reponame>/<name>` 创建隔离 worktree：

```bash
tmux new-session -d -s cursor-api -c "$PROJECT_DIR" -x 200 -y 50
tmux send-keys -t cursor-api 'agent --yolo --worktree api-task' Enter
```

但仓库规则可能强制 worktree 位置、分支名或基线。存在此类规则时，不得使用 Cursor 默认目录；应先按项目规范手工创建 worktree，再把 tmux 的 `-c` 指向该目录：

```bash
git worktree add <approved-worktree-path> -b <branch> <base-ref>
tmux new-session -d -s cursor-api -c <approved-worktree-path> -x 200 -y 50
tmux send-keys -t cursor-api 'agent --yolo' Enter
```

模型清单随账号和版本变化，使用 `agent models` 或 `agent --list-models` 获取当下真实 ID，再通过 `--model <model>` 启动；不要把示例模型名当作稳定契约。

## 七、Headless 附录

`agent -p` 用于脚本和一次性自动化，不是 tmux 交互长任务的默认入口。`--print` 仍可访问 write 和 shell 工具，不能把它当作只读安全模式；需要真实写入的无人值守脚本通常还会使用 `--yolo`：

```bash
agent -p --yolo --output-format stream-json \
  '按任务边界完成修改，运行指定验证并返回结构化结果。'
```

机器消费进度可用 `--output-format json|stream-json`；增量文本需再加 `--stream-partial-output`。脚本必须检查退出码、保存脱敏日志并限制工作区权限。需要持续交互、人工观察或 chat 恢复时，使用 tmux TUI，不要用 headless 替代。

## 八、停止与清理

```bash
# 先查看最终输出
tmux capture-pane -t "$SESSION" -p -S -200

# 请求前台 Cursor 退出
tmux send-keys -t "$SESSION" C-c

# 复查进程状态
tmux list-panes -t "$SESSION" -F '#{pane_pid} #{pane_current_command} #{pane_dead}'

# 只有确认不再需要现场后才删除 tmux 会话
tmux kill-session -t "$SESSION"
```

清理顺序：

1. 捕获最终输出，确认是完成、失败还是等待输入。
2. 独立检查工作区 diff、测试输出和未跟踪文件；Cursor 退出不等于任务完成。
3. 先发一次 `C-c`，稍等并复查；仍无响应时再决定是否第二次中断。
4. 强制杀进程或删除 tmux 会话前必须获得用户确认，避免丢失现场。
5. Cursor 内置 worktree 或手工 worktree 的删除按项目 Git 规则单独处理，不能随 tmux 会话一起清理。

## 九、反模式

- 不要把 CLI 主入口写成 `cursor chat`、`cursor-agent chat` 或未经核实的别名；统一使用 `agent`。
- 不要把 `--yolo` 解释为允许 commit、push、部署、生产写入或破坏性 Git 操作。
- 不要在含生产凭据、生产网络权限或个人敏感数据的环境中使用默认 `--yolo`。
- 不要把 `--trust` 当成 `--yolo`；前者只跳过 workspace trust 提示。
- 不要把 `--print` 当成只读；只读探索使用 `--mode ask`。
- 不要使用不存在的 `agent persist`，也不要猜测本地 chat 数据路径。
- 不要在 Cursor TUI 就绪前发送任务，也不要对未知确认界面盲发 Enter 或 `y`。
- 不要在 Cursor 仍运行时启动第二个进程恢复同一 chat。
- 不要因短时无输出就杀进程；先查 pane、子进程和最后输出。
- 不要绕过仓库对 worktree 位置、分支和验证的强制规则。

## 十、交付前检查

- [ ] `agent` 入口、版本、认证和模型已按当前环境核实。
- [ ] 默认启动使用 `agent --yolo`，工作区可信且不含生产凭据。
- [ ] 已确认 Cursor TUI 就绪后才投递完整任务。
- [ ] Prompt 明确了文件边界、保护范围、验证命令和外部副作用授权。
- [ ] tmux 会话与 Cursor chat 的恢复操作没有混淆。
- [ ] 并行任务文件边界不重叠，或已使用符合项目规则的 worktree。
- [ ] 已捕获最终输出并独立核对 diff、测试、未跟踪文件和残余风险。
- [ ] 未执行未经授权的提交、推送、部署、生产写入或破坏性操作。
- [ ] 停止和清理动作已保留必要现场，并经用户确认。
