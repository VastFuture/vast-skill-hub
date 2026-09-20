---
name: tmux-qoder-cli-workflow
description: >
  Use when running Qoder CLI coding tasks in persistent tmux sessions, especially for unattended long-running work, parallel Qoder agents, progress inspection, interrupted terminal recovery, conversation resume, or stuck process cleanup. Triggers include start qoder, background qoder, tmux qoder, resume qoder, continue qoder, check qoder progress, parallel qoder, stop qoder; Chinese triggers include 启动qoder、后台qoder、恢复qoder、继续qoder、检查qoder进度、并行qoder、停止qoder、qodercli、杀qoder僵尸。
---

# TMUX + Qoder CLI Workflow

> **规范级别**：项目级操作技能
> **核心目标**：通过 tmux 持久化 Qoder CLI，让长时间 AI 编码任务在终端断连后继续运行并可恢复管理。

**命令名**：CLI 二进制是 `qodercli`。若本机同时装了 Qoder IDE，`qoder` 这个名字常被 IDE 占用，因此本技能统一用 `qodercli` 指代 CLI 入口；没有 IDE 冲突、`qoder` 指向 CLI 的环境，把变量改成 `qoder` 即可。qoder **没有 `chat` 子命令**，交互入口就是 CLI 本身。先用 `command -v qodercli` 或 `qodercli --version` 确认入口可用。

**IRON LAW：不要混淆三类"会话"——tmux 进程会话（保活终端）、qoder 本地对话会话（`--continue`/`--resume`/`--session-id` 恢复上下文）、qoder 云端远程会话（`--remote`/`--teleport`/`--remote-control`）。tmux 只负责让进程活着，恢复上下文必须用 qoder 的会话参数。**

## 一、执行检查单

```text
TMUX + Qoder CLI Progress:

- [ ] 确认项目目录、任务边界和 tmux 会话名
- [ ] 检查同名 tmux 会话，避免误连或覆盖
- [ ] 确认 CLI 入口可用（`command -v qodercli`）且 qoder 已登录（`qodercli login`），后台任务不能停在登录/授权提示
- [ ] 确认运行环境不含生产凭据，必要时用 qoder 自带 `--worktree` 隔离
- [ ] 使用自主执行模式启动 qoder
- [ ] 确认 qoder 已进入交互 TUI
- [ ] 发送完整任务与验收条件
- [ ] 定期捕获输出并判断运行状态
- [ ] 任务结束后核对改动与验证结果
- [ ] 经用户确认后停止或删除会话
```

## 二、核心命令速查

```bash
# 设置示例变量
QODER_CLI=qodercli          # 有 Qoder IDE 占用 qoder 时用 qodercli；无冲突可设 qoder
SESSION=qoder-<topic>
PROJECT_DIR=<project-dir>

# 确认 CLI 入口可用
command -v "$QODER_CLI" && "$QODER_CLI" --version

# 创建持久会话；同名会话已存在时命令会失败，不会覆盖
tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR" -x 200 -y 50

# 自主执行模式：--yolo 等价于 --permission-mode bypass_permissions，跳过所有权限确认，避免后台任务停在人工确认
tmux send-keys -t "$SESSION" "$QODER_CLI --yolo" Enter

# 发送任务前先确认 qoder 已进入交互 TUI 且没有登录/启动错误
tmux capture-pane -t "$SESSION" -p -S -40

# 发送任务。复杂、多行或含特殊字符的提示词优先从文件读取，见下文
tmux send-keys -t "$SESSION" '<任务描述与验收条件>' Enter

# 查看最近输出
tmux capture-pane -t "$SESSION" -p -S -80

# 进入会话；退出但保持运行按 Ctrl-b d
tmux attach-session -t "$SESSION"

# 请求当前前台 qoder 进程退出
tmux send-keys -t "$SESSION" C-c

# 删除 tmux 会话。执行前必须确认任务已结束且输出已检查
tmux kill-session -t "$SESSION"
```

`--yolo` 会跳过所有权限确认（等同 `--permission-mode bypass_permissions`，危险）。本技能以无人值守完成任务为目标，因此默认启用；如果用户要求审查或逐次授权，改用 `--permission-mode default`，或折中用 `--permission-mode auto`（自动批准）／`--permission-mode accept_edits`（仅自动批准文件编辑）。自主模式必须运行在最小权限环境：不注入生产凭据，不连接生产资源；并行或高风险改动优先用 qoder 自带 `--worktree` 隔离。

## 三、可靠发送任务

短提示可直接 `tmux send-keys`。任务含引号、换行、Shell 片段或 Markdown 时，不要手工套多层引号；先把任务写入项目内已确认且不会被提交的临时提示文件，复核不含凭据，再让 qoder 读取：

```bash
tmux send-keys -t "$SESSION" '请读取 <prompt-file>，严格按其中任务和验收条件执行。完成后运行相关测试并汇报结果。' Enter
```

启动时若要附带上下文文件，可用 `qodercli --attachment <file>`（可重复）。任务完成后删除临时提示文件；若文件需成为项目事实源，按项目文档规范保留，而不是当作临时文件清理。

任务指令至少说明：

- 要解决的实际问题和允许修改的范围；
- 不得破坏的既有行为；
- 必须运行的测试或检查命令；
- 是否允许提交、推送或执行其他外部写操作。

无人值守长任务建议加 `--max-turns <n>` 限制单轮查询的最大回合数，防止自动化失控循环。除非用户明确授权，不要让 qoder 提交、推送、创建 PR、部署或修改生产资源——`--yolo` 下它能执行一切副作用操作，范围约束只能靠任务边界和隔离环境保证。

> 一次性、非交互的 CI/脚本场景可改用 `qodercli -p "<prompt>"`（`--print`，单次响应后退出），并用 `-o json`/`-o stream-json` 取结构化输出；这类场景不需要 tmux，加 `--no-session-persistence` 可不落盘（仅与 `-p` 连用有效）。

## 四、状态与进度诊断

```bash
# 会话是否存在
tmux has-session -t "$SESSION"

# 列出所有 qoder tmux 会话（会话名以 qoder- 开头）
tmux list-sessions -F '#{session_name} #{session_attached} #{session_activity}' | grep '^qoder-'

# 查看 pane 中的进程和最近输出
tmux list-panes -t "$SESSION" -F '#{pane_pid} #{pane_current_command} #{pane_dead}'
tmux capture-pane -t "$SESSION" -p -S -120

# qoder 会话状态（在自己的 shell 里运行，不在 qoder TUI 内）
qodercli status
```

判断状态时同时回答三个问题：tmux 会话是否存在、pane 中的前台命令是否仍是 qoder、最近输出是否在推进。仅凭运行时长或一段时间没有输出，不能判定为僵尸。

如果界面等待授权确认：先读输出确认请求内容。任务本应自主执行但启动时漏了 `--yolo`，停止当前 qoder 进程，再用带该参数的恢复命令启动；不要盲目发送 `y` 或 Enter。

## 五、恢复 qoder 对话

qoder 对话与工作目录/项目绑定。恢复前必须进入原项目目录（或启动时用 `--cwd`/`-w <dir>` 指向它），否则可能找不到目标会话。

```bash
# 列出所有历史会话，查找目标 session id
qodercli --list-sessions

# 继续最近一次会话
qodercli --continue            # 或 qodercli -c

# 精确恢复指定会话（长任务优先）
qodercli --resume <session-id>  # 或 qodercli -r <session-id> / qodercli --session-id <session-id>

# 不带 id 的 --resume 会进入交互式列表让你选
qodercli --resume
```

在 tmux 里恢复（先确保有可用会话）：

```bash
tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR" -x 200 -y 50
tmux send-keys -t "$SESSION" "$QODER_CLI --yolo --session-id <session-id>" Enter
```

从被恢复的会话分叉出新会话而不污染原会话：加 `--fork-session`。

三种场景必须区分：

| 场景 | 操作 |
|---|---|
| tmux 会话仍在，qoder 仍在运行 | `tmux attach-session` 或 `capture-pane`，不要再启动 qoder |
| tmux 或 qoder 已退出，需要恢复上下文 | 在原项目目录创建/复用 tmux 会话，再执行 `--continue` 或 `--session-id` |
| 需要在云端/别的机器接续 | 用 `--remote`/`--teleport`/`--remote-session`，这与 tmux 和本地会话是两回事 |

会话恢复参数互斥：`--continue`、`--resume`、`--remote`、`--remote-session`、`--teleport`、`--remote-control` 不能同时使用。不要猜测或手工修改 qoder 的会话存储、日志或锁文件——这些路径未在官方文档公开；一律用 CLI 提供的 `--list-sessions`/`--resume`/`--session-id` 命令。

## 六、并行任务

每个独立任务用不同的 tmux 会话名，例如 `qoder-api`、`qoder-ui`。并行前确认任务的文件边界不重叠；会改相同文件或依赖前序结果的任务必须串行，或用 qoder 自带 `--worktree` 隔离。

```bash
# 方案 A：qoder 自带 worktree 隔离执行，结果合并回主分支；name 可省略（自动生成）
# 官方示例：qodercli --worktree "重构数据库层"
tmux new-session -d -s qoder-api -c <api-project-dir> -x 200 -y 50
tmux send-keys -t qoder-api "$QODER_CLI --yolo --worktree" Enter

# 方案 B：纯 tmux 多会话并行（仅当文件边界不重叠）
tmux new-session -d -s qoder-api -c <api-project-dir> -x 200 -y 50
tmux new-session -d -s qoder-ui  -c <ui-project-dir>  -x 200 -y 50
tmux send-keys -t qoder-api "$QODER_CLI --yolo" Enter
tmux send-keys -t qoder-ui  "$QODER_CLI --yolo" Enter
```

需要额外访问受信任目录时，用 `--add-dir <dir>`（可重复）。

## 七、停止与清理

1. 用 `capture-pane` 和 `qodercli status` 检查任务是否完成、失败或等待输入。
2. 需要停止 qoder 时先发 `C-c`，稍等再查 `pane_current_command` 和最新输出。
3. qoder 未退出再发一次 `C-c`；仍无效才在用户确认后终止 pane 进程或删除 tmux 会话。
4. 只有在不再需要该终端现场时才 `tmux kill-session`。
5. 删除某条历史会话用 `qodercli --delete-session <index>`（index 来自 `--list-sessions`）。
6. 结束后检查工作区 diff 和测试证据，不把"qoder 已退出"等同于"任务已完成"。

强制终止会丢失未保存的交互输出。杀 tmux 会话、杀 pane 进程、删 qoder 本地对话、删云端远程会话是四种不同操作，不要把它们当成同一个"清理"动作。

## 八、反模式

- 不要把三类会话混为一谈：tmux 进程会话、qoder 本地对话（`--resume`）、qoder 云端远程会话（`--remote`/`--teleport`/`--remote-control`）。
- 不要把命令写成 `qoder-cli`（带连字符）或 `qoder chat`；qoder 没有 `chat` 子命令，CLI 入口是 `qodercli`（无 IDE 冲突时才是 `qoder`）。
- 不要在 qoder 仍在运行时用 `--resume` 启动第二个进程；应 `tmux attach-session`。
- 不要创建同名 tmux 会话后假定旧会话被覆盖；`tmux new-session` 会直接失败。
- 不要在复杂提示词外套多层 Shell 引号，避免内容被转义或截断。
- 不要在确认 qoder 就绪（已进 TUI、已登录）前发送任务；任务文本可能落到 Shell 提示符被当命令执行。
- 不要并发使用互斥的会话参数（`--continue`/`--resume`/`--remote`/`--teleport`/`--remote-control` 等只能选一个）。
- 不要臆造 qoder 的会话存储/日志/锁文件路径并直接删除；用 `--list-sessions`/`--delete-session`。
- 不要在含生产凭据或可访问生产资源的环境中使用 `--yolo`/`bypass_permissions`。
- 不要因暂时无输出就杀进程；先查 pane、进程和最后输出。
- 不要默认授权提交、推送、部署或生产写操作。

## 九、交付前检查

- [ ] 项目目录和 tmux 会话名准确且互不冲突。
- [ ] CLI 入口可用（`command -v qodercli`）且 qoder 已登录（`qodercli login`），未停在登录/授权提示。
- [ ] 无人值守任务使用了 `--yolo`（或 `--permission-mode bypass_permissions`），审查模式除外。
- [ ] 长任务已评估是否加 `--max-turns` 防失控循环。
- [ ] 已确认 qoder 进入交互 TUI 后才发送任务。
- [ ] 自主执行环境不含生产凭据，且不能访问生产资源。
- [ ] 并行/高风险改动已用 `--worktree` 隔离或确认文件边界不重叠。
- [ ] 恢复操作使用原项目目录和正确的 session id，且未用互斥参数组合。
- [ ] 已捕获并检查 qoder 最终输出、工作区 diff 和真实测试结果。
- [ ] 未执行未经授权的提交、推送、部署或生产写操作。
- [ ] 不再需要的 tmux 会话已在确认后清理。
