# 典型对话模板

## 模板 1：添加服务器

```
User: 添加服务器 ssh root@192.168.1.100

Assistant: 我会检查是否已存在，然后生成密钥并配置免密登录。
[读 data/servers.json 检查 → 未存在]
[运行 add root@192.168.1.100]
[脚本会提示输入 SSH 密码]
[输出]
已添加 192_168_1_100 → root@192.168.1.100:22
私钥: C:\Users\fhlin\.ssh\192_168_1_100_key
快捷登录: ssh 192.168.1.100
```

## 模板 2：sudo 工作流

```
User: 用 root 身份看下 /etc/shadow

Assistant: 先试 NOPASSWD sudo，不行再让你手动 sudo -i。
[运行 exec installer_115_190_211_205 "sudo head -3 /etc/shadow"]
→ 成功：返回 root 文件内容
→ 失败（sudo: a password is required）：建议 ssh + sudo -i
```

## 模板 3：模糊匹配多台服务器

```
User: 在生产服务器上查看磁盘

Assistant: "生产" 匹配到 2 台，请选择：
1. prod_web (1.2.3.4)
2. prod_db (1.2.3.5)
[用 AskUserQuestion 让用户选]
[用户选 prod_web]
[运行 exec prod_web "df -h"]
[输出结果]
```

## 模板 4：列出所有服务器

```
User: 我有哪些服务器

Assistant: [读 data/servers.json]
共 3 台:
- installer_115_190_211_205  installer@115.190.211.205:22
- prod_web                   root@1.2.3.4:22
- api_dev                    deploy@10.0.0.5:2222
```

## 模板 5：删除服务器

```
User: 删除 prod-web

Assistant: 确认要移除 prod-web 吗？(私钥不会被删除，仍在 ~/.ssh/)
[运行 ssh-manager remove prod-web]
[脚本询问 y/N]
[用户输入 y]
已移除: prod-web
提示: 如不再需要，可手动 rm ~/.ssh/prod_web_key*
```

## 模板 6：危险命令二次确认

```
User: 在生产上清理 /var/log

Assistant: 这是危险操作（涉及 rm + 系统目录），确认要继续吗？
1. 在 prod_web 上执行 `sudo find /var/log -type f -delete`
2. 仅查看不删：`sudo du -sh /var/log/*`
[用 AskUserQuestion 让用户选择]
```

## 模板 7：登录后多步操作

```
User: 登录到 api-dev 服务器，我要改 nginx 配置

Assistant: 已为你登录。
[运行 ssh-manager ssh api-dev]

你现在在 deploy@api-dev 上。常见操作:
- 切 root: sudo -i
- 改 nginx: sudo vim /etc/nginx/nginx.conf
- 测试配置: sudo nginx -t
- 重启: sudo systemctl restart nginx

完成后告诉我，我会帮你做其他事。
```
