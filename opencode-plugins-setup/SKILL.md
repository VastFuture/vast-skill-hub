---
name: vast-opencode-plugins-setup
description: >
  一键安装与配置 OpenCode 核心生态插件套件（模型容灾降级、企微群通知推送、Claude Code 生态桥接、Ralph 任务自循环）。
  当用户提到"安装opencode插件"、"配置opencode常用插件"、"opencode插件一键安装"、"设置opencode fallback/ralph/wecom"时使用此技能。
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
---

# OpenCode 核心插件套件一键安装技能

> **规范级别**：工具配置与运维技能  
> **适用目标**：在全局配置目录 `~/.config/opencode/` 下一键安装并注册 VastFuture 推荐的 OpenCode 核心插件生态。

---

## 一、集成插件列表

| 插件 | 仓库 / 包名 | 核心作用 |
|---|---|---|
| **Model Fallback** | `VastFuture/opencode-model-fallback`<br>(npm: `opencode-runtime-fallback`) | 模型自动容灾降级（429限流/超额/超时自动切换备选链路） |
| **WeCom Ping** | `VastFuture/opencode-wecom-ping`<br>(npm: `opencode-wecom-ping`) | 企微机器人消息推送（任务完成/报错/请求权限时通知） |
| **CC Adapter v2** | `VastFuture/opencode-cc-adapter`<br>(npm: `cc-adapter-v2`) | Claude Code 生态桥接（命令/技能/MCP/Agent 无缝兼容） |
| **Ralph Loop** | `VastFuture/opencode-ralph-loop`<br>(github: `VastFuture/opencode-ralph-loop`) | 自动化开发自循环（直到 Agent 满足 `<promise>DONE</promise>` 才终止） |

---

## 二、一键安装命令

### 1. Windows (PowerShell)
```powershell
& "scripts/setup.ps1"
```

或手动执行：
```powershell
Set-Location -LiteralPath "$HOME\.config\opencode"
npm install opencode-runtime-fallback opencode-wecom-ping cc-adapter-v2 VastFuture/opencode-ralph-loop --save
```

### 2. Linux / macOS / Git Bash
```bash
bash scripts/setup.sh
```

---

## 三、配置注册说明 (`~/.config/opencode/opencode.json`)

在 `opencode.json` 中配置 `"plugin"` 数组即可全局激活：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": [
    "cc-adapter-v2",
    "opencode-runtime-fallback",
    "opencode-wecom-ping",
    "ralph-loop"
  ]
}
```

---

## 四、环境变量与可选配置

1. **企业微信机器人**：
   在 `~/.config/opencode/.env` 中填入群机器人密钥：
   ```env
   WECOM_BOT_KEY=your-bot-webhook-key
   ```
2. **模型降级策略**：
   通过 `~/.config/opencode/opencode-fallback.jsonc` 自定义兜底链路模型列表。

---

## 五、验证与生效

安装与配置完成后，必须**完全退出并重启 OpenCode**。
通过以下命令可验证插件模块是否可以被正确加载：
```bash
node --input-type=module -e "await import('cc-adapter-v2'); await import('opencode-runtime-fallback'); await import('opencode-wecom-ping'); await import('ralph-loop'); console.log('All plugins loaded successfully');"
```
