# 触发场景详解

详细的处理流程和边界处理。

## 场景 1：添加服务器

**用户说**：`添加服务器 ssh root@1.2.3.4`

### 处理流程

```bash
# 1. 查重：用 Read 工具读 data/servers.json
#    - 若 name 已存在：用 AskUserQuestion 问用户（改名 / 取消 / 复用现有）
#    - 若 host 已存在：warn 但允许继续（密钥会复用）

# 2. 执行 add
bash ~/.claude/skills/ssh-manager/scripts/ssh-manager.sh add root@1.2.3.4
```

### 向用户报告

- 服务器名（默认 = host 替换 `.` `-` 为 `_`）
- 用户 @ host:port
- 私钥位置
- 快捷登录命令

### 命名规则

| 输入 | 默认 name |
|------|-----------|
| `root@1.2.3.4` | `1_2_3_4` |
| `deploy@my-server.com:2222` | `my_server_com` |
| `admin@10.0.0.5` 自定义 | `prod_api` |

第三参数覆盖默认：`add root@1.2.3.4 22 my_server`。

## 场景 2：在服务器上执行命令

**用户说**：`在 prod-web 上跑 uptime` / `在生产服务器上跑 df -h`

### 模糊匹配规则

1. **精确匹配优先**：用户给出的字符串直接对比 `name`
2. **大小写不敏感子串匹配**：按优先级 `name > host > user`
3. **零匹配**：提示先 add
4. **多个匹配**：用 AskUserQuestion 列出所有候选让用户选
5. **单匹配**：直接执行，无需确认（除非命令本身危险）

### 处理流程

```bash
# 1. 解析用户意图中的服务器名/角色
# 2. 在 data/servers.json 中找匹配
# 3. 执行 exec
bash ~/.claude/skills/ssh-manager/scripts/ssh-manager.sh exec <name> "<cmd>"
# 4. 输出原始结果给用户
```

## 场景 3：列出所有服务器

**用户说**：`列出所有服务器` / `我有哪些服务器` / `服务器清单`

### 处理方式（任选其一）

**方式 A**：直接调脚本
```bash
bash ~/.claude/skills/ssh-manager/scripts/ssh-manager.sh list
```

**方式 B**：用 Read 工具读 `data/servers.json`，自己格式化为表格

**方式 B 的格式化模板**：
```
共 N 台服务器:
- {name:20} {user}@{host}:{port}
- {name:20} {user}@{host}:{port}
```

## 场景 4：删除服务器

**用户说**：`删除 prod-web` / `移除 xxx 服务器`

```bash
# 脚本会要求二次确认（输入 y）
bash ~/.claude/skills/ssh-manager/scripts/ssh-manager.sh remove <name>
```

**告知用户**：
- 私钥**不会**被删除（仍在 `~/.ssh/` 下）
- 必要时提示手动清理密钥文件：`rm ~/.ssh/<name>_key*`

## 场景 5：交互登录

**用户说**：`登录 prod-web` / `连到 xxx 服务器`

```bash
# 透明透传到 ssh
bash ~/.claude/skills/ssh-manager/scripts/ssh-manager.sh ssh <name>
```

**进交互 shell 后常见后续操作**：
- `sudo -i` 切 root（详见 `sudo-workflow.md`）
- 改配置前先 `cd` 到目标目录
- 用 `exit` 退出登录

## 并发安全

- **一次只处理一台**服务器的添加/删除，不要并发。
- add 中途失败（如 ssh-copy-id 超时）→ 用 `list` + `show` 检查状态：
  - 密钥已生成但未推送公钥 → 重跑 `add` 会复用密钥
  - 公钥已推送但未写入 json → 手动补 json
  - 半完成状态：用 `show <name>` 看 key_path 是否存在
