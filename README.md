# VastFuture Skill Hub

> 分类整理 VastFuture 组织下所有 Agent Skills、工具与框架仓库，方便发现、检索与复用。
> 每个仓库标注 **Self-made**（fenghaolin 原创/主导）或 **External**（社区/他人贡献）。

---

## 🧑‍💻 Self-made — fenghaolin 原创或主导的仓库

> 以下仓库由 **fenghaolin** 初始化、主要开发或持续维护（以 commit 贡献为判断依据）。

### 🎨 原创图像生成 Skill

| 仓库 | 描述 |
|------|------|
| [agnes-image-gen](https://github.com/VastFuture/agnes-image-gen) | Agnes Image 2.1 Flash 图像生成 Skill（文生图/图生图/多图合成）⭐1 |
| [sensenova-image-gen](https://github.com/VastFuture/sensenova-image-gen) | SenseNova U1 Fast AI 信息图生成 Skill |

### 🔧 原创工程 & DevOps Skill

| 仓库 | 描述 |
|------|------|
| [clash-debug](https://github.com/VastFuture/clash-debug) | Clash Debug & Recovery Skill for opencode |
| [vibe-viewer](https://github.com/VastFuture/vibe-viewer) | 本地 Markdown 浏览器，beautiful-mermaid 渲染 + 实时重载 ⭐1 |
| [agy-cli-skill](https://github.com/VastFuture/agy-cli-skill) | Orchestrate Google Antigravity CLI (agy) — 并行执行、多模型路由、上下文注入 ⭐NEW |
| [opencode-model-fallback](https://github.com/VastFuture/opencode-model-fallback) | Automatic model fallback for OpenCode — 自动切换备用模型，零停机时间 ⭐NEW |
| [opencode-plugins-setup](#) (本仓目录) | OpenCode 核心生态插件一键安装 Skill — 模型降级/企微通知/CC桥接/Ralph自循环一键配置 ⭐NEW |
| [remote-server-management](#) (本仓目录) | SSH 远程服务器管理 Skill — 引导式 SSH 密钥配置 + 8 种诊断操作 + 9 个生产坑 + 11 个管理命令，全程占位符可安全提交 |
| [tmux-agy-workflow](#) (本仓目录) | 使用 tmux 持久化 agy 会话 — 断连恢复、僵尸清理、多任务并行管理 ⭐NEW |

### 🧩 Skill Collections（官方分类·自创）

| 仓库 | 类别 | 创建时间 | 描述 |
|------|------|---------|------|
| [all-skills](https://github.com/VastFuture/all-skills) | 全量备份 | 2026-04-20 | 全量 skills 私备同步仓库（跨设备备份），90+ skills |
| [vast-dev-skill](https://github.com/VastFuture/vast-dev-skill) | 开发 | 2026-04-22 | VastFuture 开发技能集，含 vast-harness-recommender 等 |
| [pm-skills](https://github.com/VastFuture/pm-skills) | 产品 | 2026-04-20 | 产品经理技能集（PMF、定价、用户访谈、PRD 等 86 条） |
| [dev-skills](https://github.com/VastFuture/dev-skills) | 开发 | 2026-04-20 | 开发与工程技能集（gstack、frontend-design、vercel-等） |
| [write-skills](https://github.com/VastFuture/write-skills) | 写作 | 2026-04-20 | 写作与内容生产技能集（ljg-writes、ljg-card 等 16+ 个） |
| [image-skills](https://github.com/VastFuture/image-skills) | 图像 | 2026-04-20 | 画图与设计视觉技能集（baoyu-image-cards、baoyu-comic 等 13 个） |
| [info-skills](https://github.com/VastFuture/info-skills) | 信息 | 2026-04-20 | 信息获取与处理技能集（baoyu-youtube-transcript、baoyu-translate 等） |
| [format-skills](https://github.com/VastFuture/format-skills) | 格式 | 2026-07-28 | 格式转换技能集（markdown → HTML/PDF/PPT 等） |
| [post-skills](https://github.com/VastFuture/post-skills) | 发布 | 2026-07-28 | 内容发布技能集（微信公众号、微博、X/Twitter 等） |
| [design-skills](https://github.com/VastFuture/design-skills) | 设计 | 2026-07-28 | 设计与原型技能集 |
| [planning-skills](https://github.com/VastFuture/planning-skills) | 规划 | 2026-07-28 | 规划与架构技能集 |
| [analysis-skills](https://github.com/VastFuture/analysis-skills) | 分析 | 2026-07-28 | 分析与诊断技能集 |
| [workflow-skills](https://github.com/VastFuture/workflow-skills) | 工作流 | 2026-07-28 | 工作流与自动化技能集 |
| [learning-skills](https://github.com/VastFuture/learning-skills) | 学习 | 2026-07-28 | 学习与教学技能集 |
| [nuwa-skills](https://github.com/VastFuture/nuwa-skills) | 思维框架 | 2026-07-28 | 女娲造人 — 思维框架技能集（Karpathy、Musk、Jobs 等视角） |
| [prompt-skills](https://github.com/VastFuture/prompt-skills) | Prompt | 2026-04-17 | Prompt engineering 技能集（prompt-principles、prompt-score 等） |
| [skills-4](https://github.com/VastFuture/skills-4) | 公开合集 | 2026-07-17 | Agent Skills 公开仓库 |

---

## 🌐 External — 社区与其他贡献者

> 以下仓库由外部贡献者创建、维护，或由 GitHub 用户提交 PR 共同维护。

### 🤖 Agent Harness & Framework

| 仓库 | 描述 | 主要作者 |
|------|------|---------|
| [deer-flow](https://github.com/VastFuture/deer-flow) | 开源 SuperAgent harness，支持沙盒、记忆、工具、skills 和 subagents | OctoBored 等 |
| [deer-workflow](https://github.com/VastFuture/deer-workflow) | 图工程运行时，TypeScript 编排 + 可替换 Agent 运行时 | — |
| [paseo](https://github.com/VastFuture/paseo) | 从桌面/移动端编排多 Agent 协作 | — |
| [paseo-relay](https://github.com/VastFuture/paseo-relay) | Paseo 轻量自托管中继服务器 | — |
| [paseo-self-hosted-relay](https://github.com/VastFuture/paseo-self-hosted-relay) | Elixir 部署管理自托管 Relay | — |
| [gbrain](https://github.com/VastFuture/gbrain) | Garry Tan 的 OpenClaw/Hermes Agent Brain | Garry Tan |
| [ECC](https://github.com/VastFuture/ECC) | Agent harness 性能优化系统 | Affaan Mustafa 等 |
| [LoopForge](https://github.com/VastFuture/LoopForge) | 可恢复的多 Agent 开发工作流 | — |
| [antigravity-cli](https://github.com/VastFuture/antigravity-cli) | Antigravity CLI — reasoning、execution、orchestration | — |
| [lobehub](https://github.com/VastFuture/lobehub) | LobeHub — Chief Agent Operator，7×24 运营你的 AI 团队 | — |
| [agentscope](https://github.com/VastFuture/agentscope) | Build and run agents you can see, understand and trust | — |
| [lumina](https://github.com/VastFuture/lumina) | Lumina 企业级 AI Agent 开发框架（AgentScope Java + Spring Cloud） | — |
| [mastra](https://github.com/VastFuture/mastra) | Mastra — 现代 TypeScript AI 应用与 Agent 框架 | — |
| [app](https://github.com/VastFuture/app) | One Works 应用 monorepo | — |
| [OpenCLI](https://github.com/VastFuture/OpenCLI) | 把任意网站变成 CLI，用已登录的浏览器状态驱动 AI Agent | — |
| [ego-lite](https://github.com/VastFuture/ego-lite) | 最快的 AI Agent 浏览器，共享已登录浏览器状态 | Alan / Tachikoma |

---

### 🧩 Skill Collections（外部贡献）

| 仓库 | 描述 | 主要作者 |
|------|------|---------|
| [Claude-Skills](https://github.com/VastFuture/Claude-Skills) | 245 个 Claude Code skills & agent plugins，653 个 Python 工具 | Brian Borghei 等 |
| [best-skills](https://github.com/VastFuture/best-skills) | 通用高质量 Skills 合集 🔥 | xstongxue / kriptoburak |
| [yan-skills](https://github.com/VastFuture/yan-skills) | Yan 的 Agent Skills — Google Trends SEO、autopilot、backlink | YAN |
| [min-skill](https://github.com/VastFuture/min-skill) | minli-skill 合集（explain-video、wechat 等） | amin |
| [SpaceZephyr-pm-skills](https://github.com/VastFuture/SpaceZephyr-pm-skills) | PM Skills 变体 | zephyrwang6 / 空格的键盘 |
| [phuryn-pm-skills](https://github.com/VastFuture/phuryn-pm-skills) | PM Skills Marketplace — 100+ agentic skills | — |
| [database-skills](https://github.com/VastFuture/database-skills) | Skills for AI agents working with databases | Lance Martin / PlanetScale |
| [prompt-skills](https://github.com/VastFuture/prompt-skills) | (external sync) | — |

---

### 🎨 Image & Design Skills（外部）

| 仓库 | 描述 | 主要作者 |
|------|------|---------|
| [Kami](https://github.com/VastFuture/Kami) | 👩‍🚒 Good content deserves good paper | Tw93 |

---

### ✍️ Content & Writing Skills（外部）

| 仓库 | 描述 | 主要作者 |
|------|------|---------|
| [creator-buddy](https://github.com/VastFuture/creator-buddy) | Creator Buddy — 跨平台内容搜索、创作者分析、爆款趋势研究 | zephyrwang6 / SpaceZephyr |
| [backlink_skills](https://github.com/VastFuture/backlink_skills) | Awesome skills for submitting URLs to free websites — 获取 backlinks | topduke963 |

---

### 🌐 Browser & Web Automation（外部）

| 仓库 | 描述 | 主要作者 |
|------|------|---------|
| [WebRPA](https://github.com/VastFuture/WebRPA) | 无代码自动化工具，拖拽构建网页数据采集/表单填写/自动化测试 | — |
| [boss-cli](https://github.com/VastFuture/boss-cli) | Boss 直聘自动化 CLI | joo |
| [boss-agent-cli](https://github.com/VastFuture/boss-agent-cli) | Local-assist BOSS Zhipin CLI for AI agents | joo |
| [ohmyboss](https://github.com/VastFuture/ohmyboss) | Boss 直聘 Skill | Jijeng |
| [boss-agent](https://github.com/VastFuture/boss-agent) | Boss Agent | — |
| [boss-skill](https://github.com/VastFuture/boss-skill) | Boss Skill — BMAD 全自动研发流水线 | — |

---

### 🧠 Knowledge & Learning（外部）

| 仓库 | 描述 | 主要作者 |
|------|------|---------|
| [llm-wiki-skills](https://github.com/VastFuture/llm-wiki-skills) | 🧠 LLM Wiki Skills — AI 帮你维护永远不过时的个人知识库 | Fountain |
| [llm-wiki-agent](https://github.com/VastFuture/llm-wiki-agent) | 自我构建的个人知识库 — Claude/Codex/Gemini 读取源文件 | Kiro / Yuhan Lei |
| [llm-wiki-skill](https://github.com/VastFuture/llm-wiki-skill) | 基于 Karpathy llm-wiki 方法论的个人知识库构建 Skill | — |
| [karpathy-llm-wiki](https://github.com/VastFuture/karpathy-llm-wiki) | Agent Skills-compatible LLM wiki for Claude Code, Cursor, Codex | Yuhan Lei |
| [llm_wiki](https://github.com/VastFuture/llm_wiki) | LLM Wiki 跨平台桌面应用 — 文档转互联知识库 | — |

---

### 🔧 Harness Engineering & DevOps（外部）

| 仓库 | 描述 | 主要作者 |
|------|------|---------|
| [age-harness-init](https://github.com/VastFuture/age-harness-init) | AGE harness init skill | age-harness-init (bot) |
| [harness-engineering](https://github.com/VastFuture/harness-engineering) | Harness engineering（AGENTS.md、docs/、lint rules） | 10xChengTu / ChengTu |
| [opencode-cc-adapter](https://github.com/VastFuture/opencode-cc-adapter) | Bridge Claude Code ↔ OpenCode | Fountain |
| [opencode-wecom-ping](https://github.com/VastFuture/opencode-wecom-ping) | OpenCode 插件：对话状态推送企业微信群机器人 | — |

---

### 💼 Business & Enterprise

| 仓库 | 描述 | 主要作者 |
|------|------|---------|
| [ragent](https://github.com/VastFuture/ragent) | 企业级 Agentic RAG 智能体 | — |
| [enterprise-ai-support-agent](https://github.com/VastFuture/enterprise-ai-support-agent) | 生产级 AI 客服平台 | — |
| [ticket-agent](https://github.com/VastFuture/ticket-agent) | 基于 DeepSeek Harness 的智能客服工单处理 Agent | — |
| [resume-screen-agent](https://github.com/VastFuture/resume-screen-agent) | 面向 HR 的简历初筛 Agent | — |
| [dsh-quant](https://github.com/VastFuture/dsh-quant) | Dsh-Quant: The Everything-Plugin AI native Quant OS | — |
| [dsh-web-ui](https://github.com/VastFuture/dsh-web-ui) | DeepSeek Harness Web UI 插件与皮肤集 | — |
| [dsh-plugin-agent-workflow](https://github.com/VastFuture/dsh-plugin-agent-workflow) | DeepSeek Harness Agent Workflow | — |
| [dsh-agent-teams](https://github.com/VastFuture/dsh-agent-teams) | AgentTeams plugin for DeepSeek Harness | — |
| [industrial-agent-long](https://github.com/VastFuture/industrial-agent-long) | industrial-agent | — |

---

### 🔌 API & Proxy

| 仓库 | 描述 | 主要作者 |
|------|------|---------|
| [CLIProxyAPI](https://github.com/VastFuture/CLIProxyAPI) | 多 CLI 包装为 OpenAI/Gemini/Claude 兼容 API 服务 | — |
| [sub2api](https://github.com/VastFuture/sub2api) | Sub2API-CRS2 一站式开源中转服务 | — |
| [OmniRoute](https://github.com/VastFuture/OmniRoute) | Free MIT AI gateway — 290+ provider，500+ 模型 | — |
| [awesome-freellm-apis](https://github.com/VastFuture/awesome-freellm-apis) | 134+ 免费 LLM APIs & AI API keys | watsonctl 等 |

---

### 📝 Content Tools

| 仓库 | 描述 | 主要作者 |
|------|------|---------|
| [koinote](https://github.com/VastFuture/koinote) | 所见即所得在线 Markdown 编辑器 | — |
| [Peekdown](https://github.com/VastFuture/Peekdown) | 轻量 Native Windows Markdown 查看器/编辑器 | — |
| [hexo-seo-starter](https://github.com/VastFuture/hexo-seo-starter) | Hexo 博客模板，内联修改版 AnZhiYu 主题 | — |
| [ziku-hexo-deploy](https://github.com/VastFuture/ziku-hexo-deploy) | ziku hexo 版本静态站 Cloudflare Pages 部署源 | — |

---

### 🛠️ Infrastructure & Tools

| 仓库 | 描述 |
|------|------|
| [edgetunnel](https://github.com/VastFuture/edgetunnel) | edgetunnel2 VLESS/Trojan/SS 多功能面板 |
| [list](https://github.com/VastFuture/list) | The Public Suffix List |
| [chuhai-tools](https://github.com/VastFuture/chuhai-tools) | 出海工具集 |
| [cloudflare-chuhai-tools](https://github.com/VastFuture/cloudflare-chuhai-tools) | Cloudflare 出海工具集 |
| [seo-chuhai-tools](https://github.com/VastFuture/seo-chuhai-tools) | SEO 出海工具集 |
| [mkdirs](https://github.com/VastFuture/mkdirs) | AI-powered directory website template（Next.js） |
| [mkdirs-1](https://github.com/VastFuture/mkdirs-1) | AI-powered directory website template（Next.js） |
| [agentflowing](https://github.com/VastFuture/agentflowing) | Cloudflare-native starter，构建订阅+积分制 AI Agent SaaS |
| [sfa-crm](https://github.com/VastFuture/sfa-crm) | VibeCoding 实现 Native AI SFA CRM |
| [goodhr](https://github.com/VastFuture/goodhr) | goodhr |
| [workany-ai](https://github.com/VastFuture/workany-ai) | — |
| [ba-xian](https://github.com/VastFuture/ba-xian) | — |
| [learning-site-astro](https://github.com/VastFuture/learning-site-astro) | — |
| [ziku](https://github.com/VastFuture/ziku) | — |
| [hanhai-nas](https://github.com/VastFuture/hanhai-nas) | 瀚海未来 · 飞牛 NAS 控制台落地页 |
| [hanhai-future-landing](https://github.com/VastFuture/hanhai-future-landing) | — |
| [vast-panel](https://github.com/VastFuture/vast-panel) | — |
| [vast-panel-full](https://github.com/VastFuture/vast-panel-full) | — |
| [mp-daily](https://github.com/VastFuture/mp-daily) | — ⭐1 |
| [vastfuture.xyz_backup](https://github.com/VastFuture/vastfuture.xyz_backup) | — |
| [seo-knowledge-base](https://github.com/VastFuture/seo-knowledge-base) | SEO 知识库 |

---

## 📊 统计概览

| 分类 | 仓库数 | 自创 | 外部 |
|------|--------|------|------|
| Self-made — 图像生成 Skill | 2 | 2 | 0 |
| Self-made — 工程 & DevOps Skill | 3 | 3 | 0 |
| Self-made — Skill Collections（官方分类） | 17 | 17 | 0 |
| **Self-made 小计** | **22** | **22** | **0** |
| Agent Harness & Framework | 16 | 0 | 16 |
| Skill Collections（外部） | 8 | 0 | 8 |
| Image & Design Skills（外部） | 1 | 0 | 1 |
| Content & Writing Skills | 2 | 0 | 2 |
| Browser & Web Automation | 8 | 0 | 8 |
| Knowledge & Learning | 5 | 0 | 5 |
| Harness Engineering & DevOps | 3 | 0 | 3 |
| Business & Enterprise | 9 | 0 | 9 |
| API & Proxy | 4 | 0 | 4 |
| Content Tools | 4 | 0 | 4 |
| Infrastructure & Tools | 21 | 0 | 21 |
| **External 小计** | **85** | **0** | **85** |
| **总计** | **107** | **22** | **85** |

---

## 🔗 快速跳转

- **自创 Skill 入口** → [all-skills](https://github.com/VastFuture/all-skills) / [vast-dev-skill](https://github.com/VastFuture/vast-dev-skill)
- **自创图像生成** → [agnes-image-gen](https://github.com/VastFuture/agnes-image-gen) / [sensenova-image-gen](https://github.com/VastFuture/sensenova-image-gen)
- **自创 Skill 集** → [pm-skills](https://github.com/VastFuture/pm-skills) / [dev-skills](https://github.com/VastFuture/dev-skills) / [write-skills](https://github.com/VastFuture/write-skills) / [image-skills](https://github.com/VastFuture/image-skills)
- **外部核心框架** → [deer-flow](https://github.com/VastFuture/deer-flow) / [ECC](https://github.com/VastFuture/ECC) / [gbrain](https://github.com/VastFuture/gbrain)
- **外部知识库** → [llm-wiki-skills](https://github.com/VastFuture/llm-wiki-skills) / [llm-wiki-agent](https://github.com/VastFuture/llm-wiki-agent)
- **外部企业级 Agent** → [ragent](https://github.com/VastFuture/ragent) / [enterprise-ai-support-agent](https://github.com/VastFuture/enterprise-ai-support-agent)
- **外部 API 聚合** → [CLIProxyAPI](https://github.com/VastFuture/CLIProxyAPI) / [OmniRoute](https://github.com/VastFuture/OmniRoute)

---

> 📅 最后更新：2026-09-04
> 🏷️ Organization: [github.com/VastFuture](https://github.com/VastFuture)
> 👤 Self-made 统计基于 GitHub commit author 历史分析
