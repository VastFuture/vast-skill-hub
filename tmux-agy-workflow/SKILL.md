---
name: vast-tmux-agy-workflow
description: >
  使用 tmux 持久化 agy (Antigravity CLI) 会话来管理长时间运行的 AI 编码任务。
  当需要启动 agy 执行重构/开发任务、恢复被中断的 agy 会话、检查 agy 进程状态、
  或需要多 agy 并行管理时使用此技能。
  触发词：启动agy、后台agy、tmux agy、继续agy、恢复agy、agy进程、杀agy僵尸。
allowed-tools:
  - Bash
  - Read
---

# TMUX + AGY 协同工作流

> **规范级别**：项目级操作技能
> **核心目标**：通过 tmux 持久化会话保障 agy 长时间运行的 AI 编码任务不因终端断连而丢失。

---

## 一、核心命令速查

```bash
# 创建会话（推荐宽度200，高度50）
tmux new-session -d -s agy-<topic> -x 200 -y 50

# 启动 agy（可选恢复已有对话）
tmux send-keys -t agy-<topic> 'cd <project-dir> && agy --dangerously-skip-permissions [--conversation <conv-id>]' Enter
tmux send-keys -t agy-<topic> '' Enter  # 触发进入交互状态

# 发送任务指令
tmux send-keys -t agy-<topic> '<任务描述>' Enter

# 检查进度（等待后查看）
sleep 60 && tmux capture-pane -t agy-<topic> -p -S -40 | tail -30

# 让 agy 提交推送
tmux send-keys -t agy-<topic> '提交并推送' Enter

# 清理会话
tmux kill-session -t agy-<topic>
```

---

## 二、agy 进程诊断

### 判断是否存活
```bash
# 看进程状态和CPU
ps -p <pid> -o %cpu,etime,stat

# 看网络活动（有ESTAB连接=仍在干活）
ss -tnp | grep <pid>

# 看最新日志
tail -10 ~/.gemini/antigravity-cli/log/cli-*.log
```

### 僵尸进程识别
- 运行 > 24h 且累计 CPU > 50h
- 日志只有心跳请求，无 streamGenerateContent
- 最后日志停留在 `connection timed out`

### 清理僵尸
```bash
kill <pid>
rm -f ~/.gemini/antigravity-cli/presence/<conv-id>.lock
```

---

## 三、会话恢复

agy 状态存在 `~/.gemini/antigravity-cli/conversations/<conv-id>.db`，重启时用相同 `--conversation` 参数即可恢复上下文。
