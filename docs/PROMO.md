# 让 AI 懂你的项目，再写代码

**swarm-yuan：从「AI 辅助」到「AI 懂项目」的认知基础设施**

一句话摘要：给 AI 一个代码仓库，5 分钟后它比你更懂这个项目的规则、结构、可复用单元和领域知识——并自动生成 25 个质量门禁守着你的代码库。

---

## 一、为什么「AI 写代码」已经不够了？

大模型普及两年，几乎每个开发者都在用 AI 写代码。但当我们审视真实的生产现场，会发现一个尴尬的事实：

**AI 的代码生成能力已被充分释放，但项目认知几乎为零。**

### 三个结构性瓶颈

**瓶颈 1：AI 不知道你的项目规则**

今天的 AI 使用模式是「人手一个 Copilot」——每个人独立地与 AI 对话，AI 不知道你的 AGENTS.md 写了什么、哪些目录不能改、依赖版本不能随意升级、哪些组件可以复用。

个人效率提升了，但 AI 产出的代码经常违反项目规则：改了不该改的文件、升级了不该升级的依赖、重复造了已有组件的轮子。

**瓶颈 2：AI 不懂你的领域**

AI 能写代码，但它不知道你的项目属于什么领域、有什么客观规律不能违反。密码必须哈希、SQL 必须参数化、消息有时序性须保序——这些不是「建议」，是客观规律。违反就是硬伤。

**瓶颈 3：检查靠人工，过程不可见**

AI 跑完一个任务，你只看到结果。代码安全吗？有没有注入？有没有 XSS？有没有改到只读目录？——没有自动化检查就没有信任，没有信任就只能逐行人工 review。

**核心论断：AI 的代码生成能力已经很强，但「项目认知」——对项目规则、结构、领域知识、可复用单元的理解——还停留在零。滞后的认知正在反噬 AI 产出的代码质量。**

---

## 二、swarm-yuan 的回答：14 项特征卡——项目的「认知 DNA」

swarm-yuan 不是给 AI 一个更好的聊天框，而是给 AI 一套项目专属的认知基础设施。

核心产物是**14 项特征卡**——AI 探查项目后提取的项目「认知 DNA」，每项落到真实路径和版本号，不用占位符。特征卡不是独立文件，而是**分散承接进目标 skill 的各个文件中**，驱动后续的门禁配置和开发流程。

### 14 项特征卡：AI 比你更懂你的项目

| # | 特征项 | AI 提取什么 | 驱动什么 |
|---|--------|-----------|---------|
| 1 | 项目类型 | 单体/monorepo/overlay-fork/微服务 | SKILL.md 定位 + `--cognition` ①概念 |
| 2 | 可改范围 | 哪些目录能改、哪些只读 | 铁律 + `--scope` 门禁 |
| 3 | 改造分类 | A类/B类、core/plugin | dev-guide + `--layer` 门禁 |
| 4 | 技术栈 | 语言+框架+构建+测试（含版本基线） | codebase.md + `--deps` 门禁 |
| 5 | 构建命令 | dev/build/test/release 真实命令 | 命令速查 + `--build` `--test` 门禁 |
| 6 | 分支规范 | 命名/合入策略/保护分支 | 铁律 + `--branch` 门禁 |
| 7 | 安全规则 | 脱敏/密钥/白名单 | reference-manual + `--security` 门禁 |
| 8 | 文档约定 | spec/plan 位置和命名 | workflow + spec-template |
| 9 | 测试体系 | 框架/目录/命令 | reference-manual + `--test` 门禁 |
| 10 | 环境资源 | 运行时版本/DB/缓存/MQ/MCP | env-setup + `--service` 门禁 |
| 11 | **可复用稳定单元** | 全部稳定 API/组件/类/函数/store/类型（签名+路径+用途+复用方式+稳定性标注） | reference-manual §4/5/6 + `--reuse` 门禁 |
| 12 | 数据规范 | schema/样例数据/业务规则/勾稽关系 | reference-manual §8 + `--consistency` 门禁 |
| 13 | 认知基底 | 认知映射表 + 六维动力学基线 | reference-manual + `--cognition` 门禁 |
| 14 | 领域知识 | 技术+业务领域识别 → 推导客观规律 | reference-manual + `--domain` 门禁 |

**第 11 项是核心中的核心。** AI 用 gitnexus `context` / graphify `query` 系统性盘点全部稳定单元——不是随机 grep，而是基于代码图谱的 360 度上下文查询。盘点的每个单元记录签名、路径、用途、复用方式、稳定性标注，供后续拼装式开发引用。

### 特征卡如何驱动一切

**特征卡 → 文件填充：** SKILL.md 的铁律来自第 2/6 项、codebase.md 的技术栈来自第 4 项、dev-guide.md 的改造分类来自第 3 项、reference-manual.md 的组件库来自第 11 项……14 项特征卡是目标 skill 所有文件的「数据源」。

**特征卡 → 门禁配置：** precheck.conf 的 45 个配置变量从特征卡推导——WRITABLE_DIRS 来自第 2 项、TEST_CMD 来自第 5 项、LAYER_DEFS 来自第 3 项、SERVICE_DIRS 来自第 10 项、STABLE_GLOBS 来自第 11 项……特征卡是 25 个门禁的「大脑」。

**特征卡 → 开发流程：** 开始新需求时，AI 从特征卡第 11 项检索可复用单元，预填 spec §5.5 复用约束。编码时 AI 查特征卡第 11 项的组件库清单，拼装优先。提交前 25 个门禁按特征卡配置的规则检查。

### 落地示例：SwarmStudio overlay 项目

| # | 特征项 | 真实值 |
|---|--------|--------|
| 1 | 项目类型 | overlay 注入式二次开发（Vue 3 + Electron） |
| 2 | 可改范围 | 可改: overlay/；只读: upstream/（严格禁止） |
| 3 | 改造分类 | A类（custom/ 纯新增）+ B类（patches/ 骨架修改） |
| 4 | 技术栈 | Vue 3 + TypeScript + Vite + NaiveUI + Vitest + SQLite + Koa + Electron |
| 5 | 构建命令 | `npm run dev`(:8649) / `npm run build` / `npm test` / `npm run inject` |
| 11 | 可复用单元 | CockpitWorkspace / CockpitKanban / CockpitChatPane / GatewayNoticeBanner / KanbanMarkdown 等 15+ 组件 |
| 14 | 领域知识 | IM 通讯（Matrix 协议）+ DevOps 监控（cockpit 看板） |

---

## 三、25 个门禁：特征卡的守卫者

特征卡定义了「项目应该是什么样的」，25 个门禁则验证「代码是否符合特征卡定义的规则」。

**核心 10 个**（`--all`，~5 秒）：分支 / 范围 / 构建 / 敏感信息 / 审查 / 复用 / 依赖 / 安全 / 测试 / 勾稽

**架构 15 个**（`--all-full`，~30 秒）：DDD 分层 / 稳定单元 / 调用链 / 架构决策 / 接口契约 / 变更影响 / 微服务 / 前端 / 认知体检 / 领域知识 / 知识复用 / Mermaid

每个门禁优先用运行时工具（gitnexus/graphify/ocr/claude-mem），无则降级到内置 grep。**有能力就用，无能力降级——不浪费工具，也不因缺失崩溃。**

> 门禁不是「数 import 数」——`--layer` 数 import 是为了验证「结构是否遵循依赖单向规律」；`--reuse` 数新增导出是为了验证「概念是否复用了特征卡第 11 项的既存稳定单元」。每个计数背后指向一条关系规律。

---

## 四、五层认知基底：特征卡的哲学根基

| 层 | 解决什么 |
|----|---------|
| 认知递进 | 如何认识项目（概念→结构→空间→映射→规律→处理） |
| 思维语言 | 如何思考（三元演化 + 四导向 + 七推理） |
| 认知辩证 | 如何推演+自证伪（4-Phase SOP + 逻辑剃刀） |
| 偏差防范 | 如何纠偏（五维偏差 + 思维模型 8 类） |
| 辩证认知 | 如何统一前四层（7 对辩证范畴） |

特征卡第 13 项记录六维动力学基线（速度/聚散/趋势/强度/能耗/累积量），`--cognition` 门禁对比基线检测认知趋势变化。特征卡第 14 项识别领域知识，`--domain` 门禁检测客观规律违规。

---

## 五、10 个运行时 + 32 个领域

swarm-yuan 整合 10 个开源运行时工具（只引用调用不重新实现）：OpenSpec / superpowers / comet / GitNexus / graphify / gsd-core / claude-mem / open-code-review / gstack / Ruflo

内置 32 个领域客观规律速查：数据库 ACID / 网络 CORS / 安全密码哈希 / IM 消息保序 / 电商库存原子扣减 / 金融金额 Decimal……

**铁律：领域规则不得违反通用常识和客观规律。**

---

## 六、Claude Code 深度集成

| 能力 | 用法 |
|------|------|
| ⚡ Hooks | SessionStart 注入状态 + PreToolUse(Write) 检查范围 |
| / Slash Commands | `/my-skill:spec` / `/my-skill:precheck` / `/my-skill:explore` |
| 🔌 MCP | 自动注册 gitnexus / claude-mem / graphify |
| 🌊 Dynamic Workflows | 复杂变更并行扇出 + 交叉验证 |
| 🔍 LSP | go-to-definition / find-references |
| 🤖 Subagent | 每任务新 subagent + 两阶段审查 |

---

## 七、零占位符 + 自举：生成完成的自证

**零占位符：** AI 执行完整 11 步流程后 grep 检查——确认零「待填充」/零「填充指引」/零占位符残留。有则回填，循环直到零残留。

**自举：** swarm-yuan 能用自身的 25 个门禁检查自身。一个连自己都检查不了的工具，凭什么检查你的项目？

---

## 八、一键安装，兼容 7 个 AI 工具

```bash
git clone https://github.com/issac-new/Swarm-yuan.git
cd Swarm-yuan/swarm-yuan
bash install.sh
```

Claude Code / Codex / Cursor / Windsurf / OpenCode / Gemini CLI / Kimi——自动检测，安装到对应目录。

---

## 数字一览

| 维度 | 数值 |
|------|------|
| **特征卡** | **14 项（驱动全部文件+门禁配置）** |
| 质量门禁 | 25（核心 10 + 架构 15） |
| 运行时工具 | 10 |
| spec 模板 | 22 段 |
| 领域知识 | 32 个领域 |
| 认知基底 | 5 层 |
| 配置变量 | 45 个（从特征卡推导） |
| 兼容 AI 工具 | 7 个 |
| 三平台 | macOS / Linux / Windows |
| 零占位符 | ✅ |
| 自举 | ✅ |

---

**项目地址**：https://github.com/issac-new/Swarm-yuan

**使用说明**：`docs/USAGE.md`

**示例项目**：`Swarm-studio/`（SwarmStudio overlay 零占位符生成物）

---

> AI 的代码生成能力已经很强，但「项目认知」还停留在零。swarm-yuan 做的事很简单：用 14 项特征卡让 AI 先懂你的项目，再写代码。
