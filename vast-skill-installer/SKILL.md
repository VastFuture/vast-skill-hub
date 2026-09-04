---
name: vast-skill-installer
description: >
  从远程 Git 仓库（如 GitHub 技能集）一键拉取并安装技能到当前项目或全局环境（.agents/skills 或 .claude/skills）。
  自动处理浅克隆、剥离 .git 嵌套污染与残留元数据，保持干净平铺的文件结构。
  当用户提到"安装技能"、"从github安装skill"、"拉取外部技能库"、"安装backlink_skills/yan-skills"时使用此技能。
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
---

# 跨仓库多源 Agent Skill 一键安装技能 (vast-skill-installer)

> **设计哲学**：好品味（消除子模块嵌套与元数据污染）、实用主义（最直接的浅克隆 + 规范化同步）、零破坏性。  
> **适用目标**：将 GitHub 上的单技能仓库或多技能集合仓库，快速、干净地安装到当前工作区的 `.agents/skills/` 或用户全局 `.agents/skills/` / `.claude/skills/`。

---

## 🎯 核心问题与设计原则

### 1. 为什么不能直接 `git clone`？
- 如果在已有 git 项目的子目录下直接 `git clone`，会引入子 `.git` 目录，导致 Git 将其误判为嵌套 Submodule 或脏索引，从而无法直接提交代码。
- 直接复制时 Windows 与 POSIX 的隐藏目录处理容易遗留 `HEAD`, `config`, `objects` 等孤儿文件。

### 2. 标准安装流程（无特殊分支设计）
```text
远程仓库 URL 
  └──> 临时目录浅克隆 (--depth 1)
        └──> 剥离 .git 元数据
              └──> 规范同步至目标 .agents/skills/<skill-dir>
                    └──> 验证 SKILL.md 完整性
```

---

## 🚀 快速使用

### 1. 零参数一键安装（默认预设：内置自动安装 backlink_skills + yan-skills）
```powershell
# Windows
& "scripts/install-skills.ps1"

# Linux / macOS
bash scripts/install-skills.sh
```

### 2. 指定预设套件
- **SEO 站长套件 (默认)**：`backlink_skills` + `yan-skills`
- **开发工程套件**：`vast-dev-skill`
- **全量核心套件**：`backlink_skills` + `yan-skills` + `vast-dev-skill`

```powershell
# 安装开发套件
& "scripts/install-skills.ps1" -Preset dev

# 安装全量套件到指定目录
& "scripts/install-skills.ps1" -Preset all -TargetDir ".agents/skills"
```

### 3. 自定义仓库安装
```powershell
# PowerShell (Windows)
& "scripts/install-skills.ps1" -RepoUrls @(
    "https://github.com/VastFuture/backlink_skills",
    "https://github.com/VastFuture/yan-skills"
) -TargetDir ".agents/skills"

# Bash (Linux / macOS / Git Bash)
bash scripts/install-skills.sh \
  --target ".agents/skills" \
  "https://github.com/VastFuture/backlink_skills" \
  "https://github.com/VastFuture/yan-skills"
```

---

## 📋 典型支持技能源

| 技能集合 / 仓库 | 核心能力 |
|---|---|
| `VastFuture/backlink_skills` | 免费外链清单筛选、SEO 目录批量/高质量提交、LinkedIn/Medium/公众号 SEO 文章写作 |
| `VastFuture/yan-skills` | Google Trends 实时跟踪、Autopilot 自动化长流程、Backlink 采集与 Rankup 增长循环 |
| `VastFuture/vast-dev-skill` | 架构设计宪法、代码审查、品味检查、工作流自动化等工程套件 |

---

## 🛠️ 安装验证步骤

安装完成后，可通过以下步骤验证：
1. **检查目录结构**：确认目标目录下存在各技能目录且包含 `SKILL.md`。
2. **确认无 git 污染**：运行 `git status`，确保所有新添加的技能文件均作为未跟踪文件正常显示，而不是显示为 submodule（带 `+` 或 `Subproject commit`）。
3. **完成提交**：
   ```bash
   git add .agents/skills/
   git commit -m "feat: install agent skills from remote repositories"
   ```
