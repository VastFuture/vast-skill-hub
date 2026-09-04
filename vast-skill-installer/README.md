# vast-skill-installer

> 📍 **技能溯源与项目信息**：
> - **所属组织**: [VastFuture](https://github.com/VastFuture)
> - **宿主仓库**: [VastFuture/vast-skill-hub](https://github.com/VastFuture/vast-skill-hub)
> - **来源背景**: 提炼自 `vast-site-studio` 项目自动化安装 `backlink_skills` 和 `yan-skills` 的标准化多源安装实践。

---

## 🎯 核心能力

跨仓库多源 Agent Skills 一键安装器：
- 自动化浅克隆（`--depth 1`）远程仓库；
- 剥离 `.git` 内部状态与多余元数据，消除子模块（Submodule）与脏索引污染；
- 规范化部署到当前项目 `.agents/skills` 或全局目录；
- 内置 `seo`、`dev`、`all` 预设，支持零参数一键安装核心站长技能套件。

详细使用说明与指令请参见同目录下的 [SKILL.md](./SKILL.md)。
