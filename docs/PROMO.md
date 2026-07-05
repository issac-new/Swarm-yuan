# 一个人 + AI = 一个研发团队？swarm-yuan 让 AI 全自动生成项目专属开发技能

> 接手一个新项目，花了一周才搞清楚代码结构、分支规范、哪些文件能改、哪些组件能复用……
>
> 如果 AI 能在 5 分钟内自动探查完这一切，生成一套专属开发技能——25 个质量门禁、18 段 spec 模板、14 项特征卡、hooks + slash 命令——零占位符，直接用？

这就是 **swarm-yuan**。

---

## 它是什么

swarm-yuan 是一个 **AI 驱动的 skill 生成器**。给它一个代码仓库路径，AI 全自动：

1. 🔍 读取项目知识（AGENTS.md / CLAUDE.md / 记忆 / hermes-agent）
2. 📊 三路并行探查代码库（结构 / 规范 / 代码组织）
3. 📋 提取 14 项特征卡（每项落到真实路径，不用占位符）
4. 🏗️ 生成六段式技能（SKILL.md + 13 个 reference + 25 个门禁 + hooks + commands）
5. ⚙️ 自动配置 45 个门禁变量
6. ✅ 运行 25 个门禁验证
7. 🧠 写回项目记忆（闭环）
8. 🔍 最终检查——**零占位符残留才算完成**

**一句话：对 AI 说"为这个项目生成 skill"，拿到一套零占位符的项目专属开发技能。**

---

## 一键安装，兼容 7 个 AI 工具

```bash
git clone https://github.com/issac-new/Swarm-yuan.git
cd Swarm-yuan/swarm-yuan
bash install.sh
```

| AI 工具 | 安装目录 |
|---------|---------|
| Claude Code | `~/.claude/skills/` |
| Codex | `~/.codex/skills/` |
| Cursor | `~/.cursor/skills/` |
| Windsurf | `~/.codeium/windsurf/skills/` |
| OpenCode | `~/.config/opencode/skills/` |
| Gemini CLI | `~/.gemini/skills/` |
| Kimi | `~/.kimi/skills/` |

---

## 25 个质量门禁

**核心 10 个**（`--all`，~5 秒）：分支 / 范围 / 构建 / 敏感信息 / 审查 / 复用 / 依赖 / 安全 / 测试 / 勾稽

**架构 15 个**（`--all-full`，~30 秒）：DDD 分层 / 稳定单元 / 调用链 / 架构决策 / 接口契约 / 变更影响 / 微服务 / 前端状态 / 组件架构 / 认知体检 / 领域知识 / 知识复用 / Mermaid

每个门禁优先用运行时工具（gitnexus/graphify/ocr/claude-mem），无则降级到 grep。

---

## 五层认知基底

| 层 | 解决什么 |
|----|---------|
| 认知递进 | 如何认识项目（概念→结构→空间→映射→规律→处理） |
| 思维语言 | 如何思考（三元演化 + 四导向 + 七推理） |
| 认知辩证 | 如何推演+自证伪（4-Phase SOP + 逻辑剃刀） |
| 偏差防范 | 如何纠偏（五维偏差 + 思维模型 8 类） |
| 辩证认知 | 如何统一前四层（7 对辩证范畴） |

> 核心理念：**呈现递进的关系，而非仅关注计算。**

---

## 10 个运行时工具

| 工具 | 能力 | 版本 |
|------|------|------|
| OpenSpec | spec-driven | v1.5.0 |
| superpowers | subagent 编排 | v6.1.1 |
| comet | 状态机 | v0.3.9 |
| GitNexus | 代码图谱 | v1.6.9 |
| graphify | 知识图 | v0.9.6 |
| gsd-core | phase-loop | v1.6.1 |
| claude-mem | 记忆持久化 | v13.10.1 |
| open-code-review | 代码审查 | v1.3.13 |
| gstack | 8 审查维度 | v1.58.5 |
| Ruflo | agent swarm | v3.21.1 |

---

## 32 个领域知识速查

技术 11 + 业务 7 + 专业 14（银行卡清算 / 等保 2.0 / ATT&CK / DDD / TOGAF / C4 / 大规模敏捷 / SRE / Kubernetes / 容灾 / 逻辑剃刀）

---

## 数字一览

| 维度 | 数值 |
|------|------|
| 质量门禁 | 25（核心 10 + 架构 15） |
| 运行时工具 | 10 |
| 特征卡 | 14 项 |
| spec 模板 | 22 段 |
| reference 文档 | 13 个 |
| 领域知识 | 32 个领域 |
| 认知基底 | 5 层 |
| 兼容 AI 工具 | 7 个 |
| 三平台 | macOS / Linux / Windows |
| 零占位符 | ✅ 生成完成时 grep 确认 |

---

**项目地址**：https://github.com/issac-new/Swarm-yuan

**详细说明**：`docs/USAGE.md`
