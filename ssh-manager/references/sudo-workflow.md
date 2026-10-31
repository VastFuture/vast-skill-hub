# 特权操作（sudo -i 工作流）

很多服务器只给普通用户免密登录（如 `installer`、`ubuntu`、`deploy`），需要 `sudo -i` 才能切到 root。这是标准运维模式。

## 两种执行方式

### 方式 A：单条命令需要 root 时，直接 sudo

```bash
ssh-manager exec <name> "sudo <command>"
```

**示例**：
```bash
# 查看 root 才能看的日志
ssh-manager exec installer_115_190_211_205 "sudo tail -n 50 /var/log/syslog"

# 改系统配置
ssh-manager exec installer_115_190_211_205 "sudo systemctl restart nginx"

# 看磁盘
ssh-manager exec installer_115_190_211_205 "sudo df -h"

# 验证是 root
ssh-manager exec installer_115_190_211_205 "sudo whoami"  # 应输出 root
```

> **前置条件**：目标服务器 `/etc/sudoers` 配了 `NOPASSWD`（如 `installer ALL=(ALL) NOPASSWD:ALL`）。
> 没配 NOPASSWD 时，非交互式 sudo 会卡住等密码——这时改用方式 B。

**如何知道目标是否配了 NOPASSWD**：
```bash
ssh-manager exec <name> "sudo -n -l"
# 成功 + 输出包含 NOPASSWD: ALL → 已配
# 输出 "a password is required" → 没配
```

### 方式 B：需要持续以 root 操作时，用 `sudo -i` 拿 root shell

```bash
# 1. 先以普通用户登录
ssh-manager ssh <name>

# 2. 在交互 shell 里升级
installer@server$ sudo -i
[sudo] password for installer:    ← 这里输你的 sudo 密码
root@server# whoami
root
```

**适合场景**：
- 批量改系统配置
- 看 root-only 的目录（`/root/`、`/etc/shadow`）
- 安装软件包
- 任何需要多步交互的操作

## Claude Code 触发场景

| 用户说 | 你的处理 |
|--------|----------|
| "在 installer 服务器上重启 nginx" | `exec <name> "sudo systemctl restart nginx"` |
| "用 root 身份看下 /etc/shadow" | 先 `exec <name> "sudo cat /etc/shadow"`；失败则建议 `ssh <name>` + `sudo -i` |
| "登录到 installer 服务器改点配置" | `ssh <name>`，告诉用户进去后输 `sudo -i` |
| "在所有服务器上看下磁盘" | 循环 `exec <name> "df -h"`，汇总结果 |

## 重要约束

- **不要自己输 sudo 密码**：skill 不知道 sudo 密码，强行执行会卡住。
- **sudo 失败要诚实**：返回 `sudo: a password is required` → 立刻告诉用户"该服务器没配 NOPASSWD，需要手动 sudo -i"。
- **危险 root 命令仍需二次确认**（见 SKILL.md 关键规则第 3 条）：sudo 不会让命令变安全。
