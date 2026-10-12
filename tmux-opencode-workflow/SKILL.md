---
name: tmux-opencode-workflow
description: >
  Use when running OpenCode TUI/CLI coding tasks in persistent tmux sessions, especially for unattended long-running work, parallel opencode agents, progress inspection, interrupted terminal recovery, conversation resume, or stuck process cleanup. Triggers include start opencode, background opencode, tmux opencode, resume opencode, continue opencode session, check opencode progress, parallel opencode, stop opencode; Chinese triggers include 启动opencode、后台opencode、恢复opencode、继续opencode、检查opencode进度、并行opencode、停止opencode、杀opencode僵尸。
---

# TMUX + OpenCode Workflow

> **规范级别**：项目级操作技能
> **核心目标**：通过 tmux 持久化 OpenCode，让长时间 AI 编码任务在终端断连后继续运行并可恢复管理。

**命令名**：CLI 二进制是 `opencode`。默认命令是 `opencode [project]`（直接启动 TUI，没有 `chat` 子命令；交互入口就是 TUI 本身）。一次性非交互用 `opencode run [message..]`。先 `command -v opencode` 与 `opencode --version` 确认入口与版本（已知可用 1.18.x）；本机若版本较旧、能力不同，按你机器实际行为为准，不要强行套用本文档示例。

**IRON LAW：不要混淆 tmux 进程会话与 opencode 本地对话会话。tmux 只负责让进程活着，恢复上下文必须用 `opencode` 自己的会话参数（`--continue` / `--session <id>` / `-s <id>` / `--fork`）。opencode 没有云端远程会话概念——不要用 qoder/kiro 的 `--remote`/`--teleport` 类比猜测。**

## 一、执行检查单

```text
TMUX + OpenCode Progress:

- [ ] 确认项目目录、任务边界和 tmux 会话名
- [ ] 检查同名 tmux 会话，避免误连或覆盖
- [ ] 确认 CLI 入口可用（`command -v opencode` 与 `opencode --version`）且对应 provider 已配置（`opencode providers`）
- [ ] 确认运行环境不含生产凭据；高风险改动优先走 git worktree 或独立项目目录
- [ ] 选择执行模式：完整 TUI（`opencode [project]`）或最小交互界面（`opencode --mini`）
- [ ] 使用自主执行模式启动（`--auto`）；自主模式任务不能在登录/授权提示停留
- [ ] 确认 opencode 已进入 TUI 主界面
- [ ] 发送完整任务与验收条件
- [ ] 定期捕获输出并判断运行状态
- [ ] 任务结束后核对改动与验证结果
- [ ] 经用户确认后停止或删除 tmux 会话
```

## 二、核心命令速查

```bash
# 设置示例变量
SESSION=opencode-<topic>
PROJECT_DIR=<project-dir>

# 确认 CLI 入口与版本
command -v opencode && opencode --version

# 创建持久会话；同名会话已存在时命令会失败，不会覆盖
tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR" -x 200 -y 50

# 默认完整 TUI 启动（自主模式）
tmux send-keys -t "$SESSION" 'opencode --auto' Enter

# 或最小交互界面（更轻、终端重连更稳）
tmux send-keys -t "$SESSION" 'opencode --auto --mini' Enter

# 发送任务前先确认已进入 TUI 主界面且没有登录/启动错误
tmux capture-pane -t "$SESSION" -p -S -40

# 发送任务。复杂、多行或含特殊字符的提示词优先从文件读取，见下文
tmux send-keys -t "$SESSION" '<任务描述与验收条件>' Enter

# 查看最近输出
tmux capture-pane -t "$SESSION" -p -S -80

# 进入会话；退出但保持运行按 Ctrl-b d
tmux attach-session -t "$SESSION"

# 请求当前前台 opencode 进程退出
tmux send-keys -t "$SESSION" C-c

# 删除 tmux 会话。执行前必须确认任务已结束且输出已检查
tmux kill-session -t "$SESSION"
```

`--auto` 等价于"自动批准未被显式拒绝的权限请求"（文档直标 "dangerous!"），作用对齐 qoder 的 `--yolo` / kiro 的 `--trust-all-tools`。本技能以无人值守完成任务为目标，因此默认启用；如果用户要求审查或逐次授权，去掉 `--auto`，让 opencode 在每次需要权限时停下询问。自主模式必须运行在最小权限环境：不注入生产凭据，不连接生产资源；并行或高风险改动优先用 git worktree 隔离。

任务简单时优先用 `opencode --mini --auto`：最小交互界面在 tmux 重连、断线恢复时更稳定，外加更小的日志体积，便于 `capture-pane` 翻看。

## 三、可靠发送任务

短提示可直接 `tmux send-keys`。任务含引号、换行、Shell 片段或 Markdown 时，不要手工套多层引号；先把任务写入项目内已确认且不会被提交的临时提示文件，复核不含凭据，再让 opencode 读取。opencode 支持以 `@<path>` 形式在提示词里引用文件，常用方式：

```bash
tmux send-keys -t "$SESSION" '请先读取 @<project>/.tmp/prompt.md，严格按其中任务和验收条件执行。完成后运行相关测试并汇报结果。' Enter
```

任务完成后删除临时提示文件；若文件需要成为项目事实源，按项目文档规范保留，而不是当作临时文件清理。

任务指令至少说明：

- 要解决的实际问题和允许修改的范围；
- 不得破坏的既有行为；
- 必须运行的测试或检查命令；
- 是否允许提交、推送或执行其他外部写操作。

无人值守长任务可用 `opencode --agent <name>` 切换专用 agent（`plan`/`build`/`general`），把范围约束编进 agent 配置而不是塞在每条任务里。除非用户明确授权，不要让 opencode 提交、推送、创建 PR、部署或修改生产资源——`--auto` 下它能执行被允许的副作用操作，范围约束只能靠任务边界和隔离环境保证。

> 一次性、非交互的 CI/脚本场景可改用 `opencode run [message..]`（单次响应后退出），并可加 `--print-logs` 把日志打到 stderr 便于解析。这条路径不进入 tmux、不落会话历史；后台长任务不要用它。

## 四、状态与进度诊断

```bash
# 会话是否存在
tmux has-session -t "$SESSION"

# 列出所有 opencode tmux 会话（会话名以 opencode- 开头）
tmux list-sessions -F '#{session_name} #{session_attached} #{session_activity}' | grep '^opencode-'

# 查看 pane 中的进程和最近输出
tmux list-panes -t "$SESSION" -F '#{pane_pid} #{pane_current_command} #{pane_dead}'
tmux capture-pane -t "$SESSION" -p -S -120

# 查看 opencode 自己的会话历史（在自己的 shell 里运行，不在 opencode TUI 内）
opencode session list
```

判断状态时同时回答三个问题：tmux 会话是否存在、pane 中的前台命令是否仍是 opencode、最近输出是否在推进。仅凭运行时长或一段时间没有输出，不能判定为僵尸。

如果界面等待权限确认：先读输出确认请求内容。任务本应自主执行但启动时漏了 `--auto`，停止当前 opencode 进程，再用带该参数的恢复命令启动；不要盲目发送 `y` 或 Enter。

排查启动问题时，`opencode --log-level DEBUG --print-logs` 可把诊断日志写到 stderr，复现一次后看完整错误链；长期后台任务不要一直开 DEBUG，会把磁盘/IO 占满。

## 五、恢复 opencode 对话

opencode 对话与项目目录绑定（会话元数据落在本地 DB）。恢复前必须进入原项目目录（启动时若不在项目根，靠 cwd 或显式传入 `[project]` 路径），否则可能找不到目标会话。

```bash
# 列出本机所有历史会话，查找目标 session id
opencode session list

# 继续最近一次会话
opencode --auto --continue

# 精确恢复指定会话（长任务优先）
opencode --auto --session <session-id>     # 或 --auto -s <session-id>

# 从被恢复的会话派生新会话，不污染原会话历史
opencode --auto --session <session-id> --fork
```

在 tmux 里恢复（先确保有可用会话）：

```bash
tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR" -x 200 -y 50
tmux send-keys -t "$SESSION" 'opencode --auto --session <session-id>' Enter
```

进阶：当前会话需要继续但不希望污染主线，从被恢复的会话派生一次：`--session <id> --fork`。

两种场景必须区分：

| 场景 | 操作 |
|---|---|
| tmux 会话仍在，opencode 仍在运行 | `tmux attach-session` 或 `capture-pane`，不要再启动 opencode |
| tmux 或 opencode 已退出，需要恢复上下文 | 在原项目目录创建/复用 tmux 会话，再执行 `--continue` 或 `--session <session-id>`；需要新分支走 `--fork` |

会话恢复参数互斥：`--continue` 与 `--session`/`-s` 不能同时使用；`--fork` 必须搭配 `--continue` 或 `--session`。不要猜测或手工修改 opencode 的会话 DB、日志或锁文件——路径会随版本变化；一律用 `opencode session list` / `opencode --session <id>` 命令。

## 六、并行任务

每个独立任务用不同的 tmux 会话名，例如 `opencode-api`、`opencode-ui`。并行前确认任务的文件边界不重叠；会改相同文件或依赖前序结果的任务必须串行，或放入隔离的 git worktree。

```bash
# 方案 A：git worktree 隔离执行，结果合并回主分支
git worktree add ../<topic>-worktree -b <branch>
tmux new-session -d -s opencode-api -c ../<topic>-worktree -x 200 -y 50
tmux send-keys -t opencode-api 'opencode --auto' Enter

# 方案 B：纯 tmux 多会话并行（仅当文件边界不重叠）
tmux new-session -d -s opencode-api -c <api-project-dir> -x 200 -y 50
tmux new-session -d -s opencode-ui  -c <ui-project-dir>  -x 200 -y 50
tmux send-keys -t opencode-api 'opencode --auto' Enter
tmux send-keys -t opencode-ui  'opencode --auto' Enter
```

需要切换模型或专用 agent，加 `-m provider/model` 与 `--agent <name>`：

```bash
tmux send-keys -t opencode-api 'opencode --auto -m cliproxy/claude-sonnet-4-6 --agent build' Enter
```

模型可用性会随 provider/账号变化，`opencode models [provider]` 是当下唯一可信清单——别信配置文件的默认值，启动前先 `opencode run -m <id> --agent build` 探一次。

## 七、停止与清理

1. 用 `capture-pane` 与 `opencode session list` 检查任务是否完成、失败或等待输入。
2. 需要停止 opencode 时先发 `C-c`，稍等再查 `pane_current_command` 和最新输出。
3. opencode 未退出再发一次 `C-c`；仍无效才在用户确认后终止 pane 进程或删除 tmux 会话。
4. 只有在不再需要该终端现场时才 `tmux kill-session`。
5. 结束后检查工作区 diff 和测试证据，不把"opencode 已退出"等同于"任务已完成"。
6. 历史会话导出 / 备份用 `opencode export <sessionID>` 与 `opencode import <file>`；不要再额外手工归档 DB 文件。

强制终止会丢失未保存的交互输出。杀 tmux 会话、杀 pane 进程、删 opencode 本地对话 是三种不同操作，不要把它们当成同一个"清理"动作。

## 八、反模式

- 不要用 `--session <id>` 代替 `tmux attach-session`；opencode 仍在运行时启动第二个进程，会双写会话、浪费配额。
- 不要把命令写成 `opencode-cli`、`opencode chat` 或 `opencode-cli run`；CLI 入口就是 `opencode`。
- 不要创建同名 tmux 会话后假定旧会话被覆盖；`tmux new-session` 会直接失败。
- 不要在复杂提示词外套多层 Shell 引号，避免内容被转义或截断。
- 不要在确认 opencode 就绪（已进 TUI、provider 已认证）前发送任务；任务文本可能落到 Shell 提示符被当命令执行。
- 不要并发使用互斥的会话参数（`--continue` 与 `--session`/`-s` 只能选一个）。
- 不要臆造 opencode 的会话存储/日志/锁文件路径并直接删除；用 `opencode session list` / `opencode export` / `opencode import`。
- 不要在含生产凭据或可访问生产资源的环境中使用 `--auto`。
- 不要因暂时无输出就杀进程；先查 pane、进程和最后输出。
- 不要默认授权提交、推送、部署或生产写操作。
- 不要相信配置文件的默认模型 id；启动前先跑一次 `opencode run -m <id> --agent build` 验证仍可解析。

## 九、交付前检查

- [ ] 项目目录和 tmux 会话名准确且互不冲突。
- [ ] CLI 入口可用（`command -v opencode`），provider 已配置（`opencode providers`），未停在登录/授权提示。
- [ ] 无人值守任务使用了 `--auto`（或显式选择不带 `--auto` 的审查路径）。
- [ ] 启动前已用 `opencode models` 或轻量探活确认模型 id 仍可解析。
- [ ] 已确认 opencode 进入 TUI 主界面后才发送任务。
- [ ] 自主执行环境不含生产凭据，且不能访问生产资源。
- [ ] 并行/高风险改动已用 git worktree 隔离或确认文件边界不重叠。
- [ ] 恢复操作使用原项目目录和正确的 session id，且未用互斥参数组合。
- [ ] 已捕获并检查 opencode 最终输出、工作区 diff 和真实测试结果。
- [ ] 未执行未经授权的提交、推送、部署或生产写操作。
- [ ] 不再需要的 tmux 会话已在确认后清理。
