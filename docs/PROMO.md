# 一个人 + AI = 一个研发团队？swarm-yuan 让 Claude Code 自动为你生成项目专属开发技能

> 你有没有遇到过这种情况：接手一个新项目，花了一周才搞清楚代码结构、分支规范、哪些文件能改哪些不能碰、哪些组件能复用、测试怎么跑……
>
> 如果 AI 能在 5 分钟内自动探查完这一切，生成一套专属的开发技能——含 25 个质量门禁、18 段 spec 模板、14 项项目特征卡——你直接拿来用，零手动配置，会怎样？

这就是 **swarm-yuan**。

---

## 它是什么

swarm-yuan 是一个 **AI 驱动的 skill 生成器**。

你给它一个代码仓库的路径，它自动：

1. 🔍 **读取项目知识** — AGENTS.md、CLAUDE.md、项目记忆、hermes-agent 配置，提取团队积累的规则和教训
2. 📊 **探查代码库** — 三路并行子代理扫描（结构/规范/代码组织），优先用代码图谱工具索引
3. 📋 **提取 14 项特征卡** — 项目类型、可改范围、技术栈、构建命令、可复用稳定单元、领域知识……每项落到真实路径
4. 🏗️ **生成六段式技能** — SKILL.md + 13 个 reference + 7 个 asset 模板 + 25 个门禁脚本 + hooks + slash 命令
5. ⚙️ **自动配置** — 45 个门禁变量从探查结果推导，你不需要手动编辑任何配置文件
6. ✅ **自检验证** — 运行 25 个门禁，有误报自动修复后重跑
7. 🧠 **写回记忆** — 探查结果写回 claude-mem / .zcode/memories，形成闭环

**一句话：对 AI 说"为这个项目生成 skill"，5 分钟后你拿到一套可直接用的项目专属开发技能。**

---

## 为什么你需要它

### 痛点 1：每个项目都要重新摸索

接手新项目时，你花了大量时间理解：哪些目录能改？哪些只读？分支怎么命名？构建命令是什么？哪些组件可以复用？安全规则是什么？

**swarm-yuan 自动探查这一切**，生成 14 项特征卡，每项落到真实路径和命令名。

### 痛点 2：代码审查靠人工，漏检率高

**25 个门禁自动检查**，从分支命名到安全规范到复用合规到领域知识客观规律，全覆盖。

### 痛点 3：AI 编码不知道项目规则

**生成的目标技能内置项目规则**，AI 在编码时自动遵守。

---

## 25 个质量门禁

### 核心门禁（日常 `--all` 跑这 10 个，~5 秒）

| 门禁 | 检查什么 |
|------|---------|
| `--branch` | 分支命名 + 保护分支 |
| `--scope` | 改动范围（可改 vs 只读） |
| `--build` | 构建通过 |
| `--sensitive` | 密码/密钥明文扫描 |
| `--review` | 代码审查（调用 ocr，5 维度） |
| `--reuse` | 复用合规（禁止重复造轮子） |
| `--deps` | 依赖版本锁定 |
| `--security` | OWASP Top 10 |
| `--test` | 测试通过 |
| `--consistency` | 业务规则 + 数据勾稽 |

### 架构门禁（`--all-full` 跑全部 25 个）

DDD 分层 / 稳定单元篡改 / 调用链深度 / 架构决策记录 / 接口契约 / 变更影响 / 微服务 / 前端状态 / 组件架构 / 认知体检 / 领域知识 / 项目知识复用 / Mermaid 可视化。

每个门禁优先用已安装的运行时工具（gitnexus/graphify/ocr/claude-mem），无则降级到内置 grep。

---

## 五层认知基底

| 层 | 解决什么 |
|----|---------|
| 第一层 **认知递进** | 如何认识项目（概念→结构→空间→映射→规律→处理） |
| 第二层 **思维语言** | 如何思考（三元演化 + 四导向 + 七推理） |
| 第三层 **认知辩证** | 如何推演+自证伪（4-Phase SOP + 逻辑剃刀） |
| 第四层 **偏差防范** | 如何纠偏（五维偏差 + 思维模型 8 类） |
| 第五层 **辩证认知** | 如何统一前四层（7 对辩证范畴） |

> 核心理念：**呈现递进的关系，而非仅关注计算。**

---

## 10 个运行时工具

| 工具 | 能力 | 版本 |
|------|------|------|
| OpenSpec | spec-driven 开发 | v1.5.0 |
| superpowers | subagent-driven 编排 | v6.1.1 |
| comet | 脚本背书状态机 | v0.3.9 |
| GitNexus | 代码知识图谱（17 MCP 工具） | v1.6.9 |
| graphify | 广谱知识图（36 语法） | v0.9.6 |
| gsd-core | phase-loop + goal-backward | v1.6.1 |
| claude-mem | 跨会话记忆持久化 | v13.10.1 |
| open-code-review | 确定性代码审查 | v1.3.13 |
| gstack | 8 审查维度 | v1.58.5 |
| Ruflo | agent swarm + federation | v3.21.1 |

只引用调用，不重新实现。

---

## 32 个领域知识速查

**技术领域**（11 个）：数据库、缓存、网络、安全、并发、前端、分布式、构建/DevOps

**业务领域**（7 个）：IM 通讯、电商、CRM、监控、DevOps、教育、金融

**专业领域**（14 个）：银行卡转接清算、网络支付、等保 2.0、ATT&CK、DDD、TOGAF、C4、架构模式、大规模敏捷、敏捷工程、SRE、Kubernetes、容灾高可用、逻辑剃刀

> **铁律：领域规则不得违反通用常识和客观规律。**

---

## Claude Code 深度集成

| 能力 | 用法 |
|------|------|
| Hooks | SessionStart 注入状态 + PreToolUse 范围检查 |
| Slash Commands | `/my-skill:spec` / `/my-skill:precheck` / `/my-skill:explore` |
| MCP | 自动注册 gitnexus / claude-mem / graphify |
| Dynamic Workflows | 复杂变更并行扇出 + 交叉验证 |
| LSP | go-to-definition / find-references |
| Subagent | 每任务新 subagent + 两阶段审查 |
| ultrareview | 云端多 agent 审查（可选） |

联网/云端功能不可用时自动降级为本地工具。

---

## 数字一览

| 维度 | 数值 |
|------|------|
| 质量门禁 | 25 个（核心 10 + 架构 15） |
| 运行时工具 | 10 个 |
| 项目特征卡 | 14 项 |
| spec 模板 | 22 段（分级填写） |
| reference 文档 | 13 个 |
| 领域知识速查 | 32 个领域 |
| 认知基底 | 5 层 |
| 三平台兼容 | macOS / Linux / Windows |
| 自举能力 | ✅ 用自身门禁检查自身 |

---

## 安装

```bash
git clone https://github.com/issac-new/Swarm-yuan.git
cp -r Swarm-yuan/swarm-yuan ~/.agents/skills/
cp -r ~/.claude/skills/swarm-yuan/.claude/commands/ ~/.claude/commands/

# 使用
/swarm-yuan /path/to/your/project
```

---

**项目地址**：https://github.com/issac-new/Swarm-yuan

**详细使用说明**：`docs/USAGE.md`
