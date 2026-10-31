---
name: ssh-manager
description: 管理免密登录的 SSH 服务器（add / list / show / exec / ssh / remove）。触发场景：用户说"添加服务器 ssh xxx"、"列出服务器"、"在 xx 上跑 xxx"、"登录到 xx 服务器"、"删除服务器"。触发词：ssh、服务器、远程、添加、列出、执行、登录、删除、ssh-keygen、免密。不要触发：通用 shell 命令、git 操作、本地文件编辑。
---

# SSH Manager

管理一组免密登录的 SSH 服务器。**所有状态都存在 `data/servers.json`**——这是唯一真相源。

## 数据源

`~/.claude/skills/ssh-manager/data/servers.json`

```json
[
  { "name": "prod_web", "host": "1.2.3.4", "port": 22, "user": "root",
    "key_path": "C:\\Users\\fhlin\\.ssh\\prod_web_key" }
]
```

## 主脚本

`scripts/ssh-manager.sh`（依赖 `python3`，Windows / macOS / Linux 都自带）

## 子命令

| 命令 | 用途 |
|------|------|
| `add <user@host> [port] [name]` | 生成密钥 + 推送公钥 + 验证免密 + 写 config + 写 json |
| `list` | 列出所有服务器（表格） |
| `show <name>` | 显示某台详情（JSON） |
| `exec <name> "<command>"` | 在服务器上执行命令 |
| `ssh <name>` | 交互登录（透传到 ssh） |
| `remove <name>` | 从列表移除（不删密钥） |

调用格式：
```bash
bash ~/.claude/skills/ssh-manager/scripts/ssh-manager.sh <command> [args]
```

## 关键规则（必须遵守）

1. **不重复生成密钥**：脚本内部已幂等处理。`add` 检测到密钥文件存在会复用，不要绕开脚本自己再跑 ssh-keygen。
2. **添加前先查重**：用 Read 读 `data/servers.json` 检查是否已存在。已存在时用 AskUserQuestion 让用户决定（改名 / 取消 / 复用）。
3. **exec / ssh 前先读 context**：见下一节"上下文系统"。不读就开干 = 必踩坑（不知道 sudo 方式、关键路径、已知坑、IP 是否被封）。
4. **危险命令必须用 AskUserQuestion 二次确认**：
   - `rm -rf`、`mkfs`、`dd`、`shutdown`、`reboot`、`halt`、`init 0/6`
   - `kill -9` / `pkill` 涉及关键进程
   - `chmod 777` / `chown` 大范围
   - 修改 `/etc/passwd`、`/etc/sudoers`、`/etc/ssh/sshd_config`
5. **模糊匹配要确认**：用户说"在那台 web 服务器上..."，不要猜——列出可能的匹配让用户选。
6. **执行输出要可见**：不要把 exec 的输出藏起来。
7. **失败要诚实**：`BatchMode=yes` 验证失败时，说明真实原因，不要伪装成功。

## 上下文系统（exec / ssh 前必读）

`scripts/ssh-manager.sh` 只管连接（host/port/user/key），**不存这台机器是干嘛的、有什么坑**。这部分由**外部 markdown 文档**承载：

```
~/.ssh-manager-skill/ssh-context/
├── README.md                # 格式说明
├── <server-name>.md         # 每台 server 一个，机器特定
└── lessons/                 # 跨机器通用经验
    ├── README.md
    └── <topic>.md
```

### 何时读什么

| 场景 | 必读 |
|------|------|
| 任何 `exec` / `ssh` 之前 | `ssh-context/<server-name>.md` 全文（机器特定） |
| 当前任务涉及某个 lesson 主题 | `ssh-context/lessons/<topic>.md`（按需，跨机器通用） |

### 不读就开干的常见后果

- 不知道这台机器要不要 `sudo -i`，写文件 Permission denied
- 不知道 clash / docker / 服务路径在哪，写错位置
- 不知道服务商封了 IP，调半天配置毫无进展
- 不知道 fake-ip 模式让 DNS 失真，dig 出来假 IP 还以为网络挂了

### 标准工作流

```
1. 用户: "在 xx 服务器上做 yyy"
2. AI: Read  ~/.ssh-manager-skill/ssh-context/<name>.md     → 机器特定
3. AI: 按当前任务挑 lesson(s)，Read lessons/<topic>.md      → 通用经验
4. AI: 综合判断 → 设计命令（参考 context 里的路径、权限、坑）
5. AI: 用 ssh-manager exec 执行
```

### 用户说"加台服务器 / 记一下" 时的处理

用户要求为某台 server 加 context，AI 直接 Read / Write `~/.ssh-manager-skill/ssh-context/<server-name>.md`，不需要任何脚本命令。

用户要求记一条经验，AI 写到 `~/.ssh-manager-skill/ssh-context/lessons/<topic>.md`。

**结构规范**见 `ssh-context/README.md` 和 `ssh-context/lessons/README.md`。

## 详细文档（按需加载）

| 文档 | 何时读 |
|------|--------|
| `references/scenarios.md` | 处理具体场景时（添加 / 执行 / 列出 / 删除 / 登录的详细流程） |
| `references/sudo-workflow.md` | 用户说"用 root"、"sudo"、"切到管理员"时 |
| `references/troubleshooting.md` | add/exec 失败需要排查时 |
| `references/examples.md` | 需要对话模板时 |

**默认不要预读这些 references**——只在对应场景触发时再 Read。

## 典型流程速查

```bash
# 添加
bash ~/.claude/skills/ssh-manager/scripts/ssh-manager.sh add installer@115.190.211.205

# 列出
bash ~/.claude/skills/ssh-manager/scripts/ssh-manager.sh list

# 执行
bash ~/.claude/skills/ssh-manager/scripts/ssh-manager.sh exec installer_115_190_211_205 "df -h"

# 登录
bash ~/.claude/skills/ssh-manager/scripts/ssh-manager.sh ssh installer_115_190_211_205
```

## 常用模式

### sudo 写 `/etc/` 下的文件（避开 redirect 权限陷阱）

```bash
# 错的写法：shell `>` 用 installer 权限检查父目录，sudo 只对子命令有效
sudo base64 -d > /etc/clash/x        # → Permission denied

# 对的写法 A：先写 /tmp，再 sudo mv
echo "$DATA" | base64 -d > /tmp/x && sudo mv /tmp/x /etc/clash/x

# 对的写法 B：sudo -i bash -s，redirect 在 root shell 里
bash ssh-manager.sh exec server 'sudo -i bash -s' <<'REMOTE_EOF'
echo "$DATA" | base64 -d > /etc/clash/x
chown root:root /etc/clash/x
REMOTE_EOF
```
完整教训见 `ssh-context/lessons/sudo-redirect-trap.md`。

### heredoc 传本地变量到远端

```bash
# 错的写法：<<EOF（不带引号）让本地 bash 先展开变量
LOCAL_VAR=hello
bash ssh-manager.sh exec server 'bash -s' <<EOF
echo "remote got: $LOCAL_VAR"   # 远端看到的是已展开的 "hello"，不是变量名
EOF

# 对的写法：<<'EOF'（带引号）+ 命令字符串传变量
bash ssh-manager.sh exec server "VAR=$LOCAL_VAR bash -s" <<'EOF'
echo "remote got: $VAR"          # 远端展开，VAR 是位置参数注入的
EOF
```
完整教训见 `ssh-context/lessons/heredoc-var-expansion.md`。

### 多 server 批量操作

```bash
# 从 list 输出解析名字（注意 list 是表格格式，用 awk 跳分隔线）
for s in $(bash ssh-manager.sh list | awk 'NR>2 && $1 !~ /^---/ {print $1}'); do
    bash ssh-manager.sh exec "$s" "uptime"
done

# 或更精确：从 JSON 拿
for s in $(python3 -c "import json; print('\n'.join(s['name'] for s in json.load(open('/c/Users/fhlin/.claude/skills/ssh-manager/data/servers.json'))))"); do
    bash ssh-manager.sh exec "$s" "uptime"
done
```

### exec 失败排查流程

```
1. ssh-context/<name>.md 里"已知坑"先看一遍
2. 看 ssh-context/lessons/ 下相关 lesson
3. 直接 ssh 测试连通性：ssh -i ~/.ssh/<name>_key -o BatchMode=yes <user>@<host> 'whoami'
4. 测端口：bash -c "</dev/tcp/<host>/22"
5. 看 references/troubleshooting.md 的标准排查步骤
```

### 加新 server

```bash
# 1. 先查重
python3 -c "import json; print([s['name'] for s in json.load(open('/c/Users/fhlin/.claude/skills/ssh-manager/data/servers.json'))])"

# 2. add（脚本内部处理密钥推送 + 验证免密）
bash ssh-manager.sh add user@1.2.3.4 22 my_server

# 3. AI 自动给新 server 写 context（user 提醒或 AI 自观察）
# → ~/.ssh-manager-skill/ssh-context/my_server.md
```