---
name: tmux-kiro-cli-workflow
description: >
  Use when running Kiro CLI coding tasks in persistent tmux sessions, especially for unattended long-running work, parallel Kiro agents, progress inspection, interrupted terminal recovery, conversation resume, or stuck process cleanup. Triggers include start Kiro in background, tmux Kiro, resume Kiro, continue Kiro session, check Kiro progress, parallel Kiro, stop Kiro, and kill Kiro zombie; Chinese triggers include 启动kiro、后台kiro、恢复kiro、继续kiro、检查kiro进度、并行kiro、停止kiro、杀kiro僵尸。
---

# TMUX + Kiro CLI Workflow

> **规范级别**：项目级操作技能
> **核心目标**：通过 tmux 持久化 Kiro CLI，让长时间 AI 编码任务在终端断连后继续运行并可恢复管理。

**IRON LAW：不要混淆 tmux 进程会话与 Kiro 对话会话；前者保持进程存活，后者通过 `--resume` 或 `--resume-id` 恢复上下文。**

## 一、执行检查单

```text
TMUX + Kiro CLI Progress:

- [ ] 确认项目目录、任务边界和 tmux 会话名
- [ ] 检查同名 tmux 会话，避免误连或覆盖
- [ ] 确认运行环境不含生产凭据，必要时使用隔离的 Git worktree
- [ ] 使用自主执行模式启动 Kiro CLI
- [ ] 确认 Kiro 已进入聊天界面
- [ ] 发送完整任务与验收条件
- [ ] 定期捕获输出并判断运行状态
- [ ] 任务结束后核对改动与验证结果
- [ ] 经用户确认后停止或删除会话
```

## 二、核心命令速查

```bash
# 设置示例变量
SESSION=kiro-<topic>
PROJECT_DIR=<project-dir>

# 创建持久会话；同名会话已存在时命令会失败，不会覆盖
tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR" -x 200 -y 50

# 默认自主执行模式：允许 Kiro 调用全部工具，避免后台任务停在 HITL
tmux send-keys -t "$SESSION" 'kiro-cli chat --trust-all-tools' Enter

# 发送任务前先确认 Kiro 已进入聊天界面且没有启动错误
tmux capture-pane -t "$SESSION" -p -S -40

# 发送任务。复杂、多行或含特殊字符的提示词优先从文件读取，见下文
tmux send-keys -t "$SESSION" '<任务描述与验收条件>' Enter

# 查看最近输出
tmux capture-pane -t "$SESSION" -p -S -80

# 进入会话；退出但保持运行按 Ctrl-b d
tmux attach-session -t "$SESSION"

# 请求当前前台 Kiro 进程退出
tmux send-keys -t "$SESSION" C-c

# 删除 tmux 会话。执行前必须确认任务已结束且输出已检查
tmux kill-session -t "$SESSION"
```

`--trust-all-tools` 会放开 Kiro 的全部工具权限。本技能以无人值守完成任务为目标，因此默认启用；如果用户明确要求审查模式或逐次授权，则改用 `kiro-cli chat`。自主模式必须运行在最小权限环境：不注入生产凭据，不连接生产资源；并行或高风险改动优先使用隔离的 Git worktree。

## 三、可靠发送任务

短提示可直接用 `tmux send-keys`。任务包含引号、换行、Shell 片段或 Markdown 时，不要手工套多层引号；先把任务写入项目内已确认且不会被提交的临时提示文件，复核内容不含凭据，再让 Kiro 读取：

```bash
tmux send-keys -t "$SESSION" '请读取 <prompt-file>，严格按其中任务和验收条件执行。完成后运行相关测试并汇报结果。' Enter
```

任务完成后删除临时提示文件；如果文件需要成为项目事实源，则按项目文档规范保留，而不是当作临时文件清理。

任务指令至少说明：

- 要解决的实际问题和允许修改的范围；
- 不得破坏的既有行为；
- 必须运行的测试或检查命令；
- 是否允许提交、推送或执行其他外部写操作。

默认只允许修改与验证。除非用户明确授权，不要让 Kiro 提交、推送、创建 PR、部署或修改生产资源。

## 四、状态与进度诊断

```bash
# 会话是否存在
tmux has-session -t "$SESSION"

# 列出所有 Kiro tmux 会话
tmux list-sessions -F '#{session_name}\t#{session_attached}\t#{session_activity}' | grep '^kiro-'

# 查看 pane 中的进程和最近输出
tmux list-panes -t "$SESSION" -F '#{pane_pid}\t#{pane_current_command}\t#{pane_dead}'
tmux capture-pane -t "$SESSION" -p -S -120
```

判断状态时同时回答三个问题：tmux 会话是否存在、pane 中的前台命令是否仍是 Kiro、最近输出是否在推进。仅凭运行时长或一段时间没有输出，不能判定为僵尸。

如果界面等待确认：先读取输出确认请求内容。任务已经授权自主执行但启动时漏了 `--trust-all-tools`，停止当前 Kiro 进程，再用带该参数的恢复命令启动；不要盲目发送 `y` 或 Enter。

## 五、恢复 Kiro 对话

Kiro 对话按工作目录保存。恢复前必须进入原项目目录，否则可能找不到目标会话。

```bash
# 查看当前项目的已保存会话及 sessionId
kiro-cli chat --list-sessions --format json

# 恢复当前项目最近一次对话
tmux send-keys -t "$SESSION" 'kiro-cli chat --trust-all-tools --resume' Enter

# 精确恢复指定对话，长任务优先使用此方式
tmux send-keys -t "$SESSION" 'kiro-cli chat --trust-all-tools --resume-id <session-id>' Enter
```

两种恢复场景必须区分：

| 场景 | 操作 |
|---|---|
| tmux 会话仍存在，Kiro 仍在运行 | `tmux attach-session` 或 `capture-pane`，不要再启动 Kiro |
| tmux 或 Kiro 已退出，需要恢复上下文 | 在原项目目录创建/复用空闲 tmux 会话，再执行 `--resume-id` |

不要猜测或手工修改 Kiro 的内部会话存储、日志文件或锁文件。使用 CLI 提供的会话命令。

## 六、并行任务

每个独立任务使用不同的 tmux 会话名，例如 `kiro-api`、`kiro-ui`。并行前确认任务的文件边界不重叠；会修改相同文件或依赖前序结果的任务必须串行，或放入隔离的 Git worktree。

```bash
tmux new-session -d -s kiro-api -c <api-project-dir> -x 200 -y 50
tmux new-session -d -s kiro-ui -c <ui-project-dir> -x 200 -y 50
tmux send-keys -t kiro-api 'kiro-cli chat --trust-all-tools' Enter
tmux send-keys -t kiro-ui 'kiro-cli chat --trust-all-tools' Enter
```

## 七、停止与清理

1. 用 `capture-pane` 检查任务是否完成、失败或等待输入。
2. 需要停止 Kiro 时先发送 `C-c`，等待片刻后检查 `pane_current_command` 和最新输出。
3. Kiro 未退出时再发送一次 `C-c`；仍无效才在用户确认后终止 pane 进程或删除 tmux 会话。
4. 只有在不再需要该终端现场时才执行 `tmux kill-session`。
5. 结束后检查工作区 diff 和测试证据，不把“Kiro 已退出”等同于“任务已完成”。

强制终止会丢失未保存的交互输出。杀会话、杀进程、删除 Kiro 对话都属于不同操作，不要把它们当成同一个“清理”动作。

## 八、反模式

- 不要用 `--resume` 代替 `tmux attach-session`；Kiro 仍在运行时会启动第二个进程。
- 不要创建同名会话后假定旧会话被覆盖；`tmux new-session` 会直接失败。
- 不要在复杂提示词外套多层 Shell 引号，避免内容被转义或截断。
- 不要在确认 Kiro 就绪前发送任务；任务文本可能落到 Shell 提示符并被当作命令执行。
- 不要因暂时无输出就杀进程；先检查 pane、进程和最后输出。
- 不要臆造 Kiro 的日志、数据库或锁文件路径并直接删除。
- 不要默认授权提交、推送、部署或生产写操作。
- 不要在含生产凭据或可访问生产资源的环境中使用自主执行模式。

## 九、交付前检查

- [ ] 项目目录和 tmux 会话名准确且互不冲突。
- [ ] 无人值守任务使用了 `--trust-all-tools`，审查模式除外。
- [ ] 已确认 Kiro 进入聊天界面后才发送任务。
- [ ] 自主执行环境不含生产凭据，且不能访问生产资源。
- [ ] 恢复操作使用原项目目录和正确的 Kiro `sessionId`。
- [ ] 已捕获并检查 Kiro 最终输出、工作区 diff 和真实测试结果。
- [ ] 未执行未经授权的提交、推送、部署或生产写操作。
- [ ] 不再需要的 tmux 会话已在确认后清理。
