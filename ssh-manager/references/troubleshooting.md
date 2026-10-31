# 故障排查

## add 命令失败

### 推送公钥失败（ssh-copy-id 报错）

**症状**：`Permission denied (publickey,password)` 或 `Permission denied (password)`

**检查清单**：
1. 目标账号密码是否正确（首次推送必须输一次密码）
2. 目标服务器 sshd 配置：`/etc/ssh/sshd_config` 中 `PubkeyAuthentication yes`
3. 账号是否被禁用 / shell 是否是 `/usr/sbin/nologin`

### BatchMode 验证失败

**症状**：脚本最后报错 `免密验证失败`

**检查清单**：
1. 目标服务器 `~/.ssh/authorized_keys` 权限：必须是 `600`
2. 目标服务器 `~/.ssh` 目录权限：必须是 `700`
3. sshd 配置：`AuthorizedKeysFile` 路径正确
4. SELinux / AppArmor 是否阻挡（少见）

### 连接超时

**症状**：`Connection timed out` / `Could not resolve hostname`

**检查清单**：
1. 网络是否通：`ping <host>` / `telnet <host> 22`
2. 端口是否正确：默认 22，其他端口要明确指定
3. 防火墙是否放行：本地防火墙、目标服务器防火墙、云服务商安全组
4. DNS 解析：`nslookup <host>`

### JSON 写入失败（Windows 特有，已修复）

**症状**：list 显示空，但 `data/servers.json` 文件其实有数据

**原因**：Python 在 Windows 上不识别 MSYS 的 `/c/Users/...` 虚拟路径

**已修复**：脚本用 `cygpath -w` 转 Windows 路径

**手动验证**：
```bash
python3 -c "import json; print(len(json.load(open(r'C:\Users\fhlin\.claude\skills\ssh-manager\data\servers.json'))))"
```

## exec 命令失败

### 私钥不存在

**症状**：`Load key ... : No such file or directory`

**处理**：
```bash
ssh-manager show <name>   # 看 key_path 是什么
ls -la <key_path>         # 看文件是否真存在
# 如果被删了 → 重跑 add 重新配置
```

### 服务器拒绝连接

**症状**：`Connection refused` / `Permission denied`

**可能原因**：
- 服务器重置了 `~/.ssh/authorized_keys` → 重跑 `add`
- 服务器改了 sshd 配置（如禁用了该用户的 key）
- 服务器换了 IP / 域名

### 命令不存在

**症状**：`bash: xxx: command not found`

**检查**：
- 命令名是否拼错
- 目标服务器是否装了对应软件
- PATH 是否对（sudo 时 PATH 可能被重置）

## 半完成状态恢复

如果 `add` 中途被打断（如 ssh-copy-id 超时、网络中断），状态可能不一致：

| 已完成步骤 | 检查方法 | 修复 |
|-----------|---------|------|
| 密钥生成 | `ls ~/.ssh/<name>_key*` | 已有 → add 会复用 |
| 公钥推送 | 登录服务器 `cat ~/.ssh/authorized_keys` | 没公钥 → 重跑 add |
| 写入 servers.json | `ssh-manager show <name>` | 缺失 → 手动补 json |
| 写入 ssh config | `grep "Host <host>" ~/.ssh/config` | 缺失 → 重跑 add |

**最安全的恢复方式**：直接重跑 `add`，脚本内部已幂等。
