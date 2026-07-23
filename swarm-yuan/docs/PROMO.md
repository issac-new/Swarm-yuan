# 17 项特征卡 + 49 个质量门禁：swarm-yuan 如何让 AI 懂你的项目

**从「AI 辅助写代码」到「AI 懂项目再写代码」的认知基础设施**

一句话摘要：swarm-yuan 用 17 项特征卡让 AI 认识你的项目，用 49 个质量门禁守护代码合规——特征卡是立法，门禁是执法，两者构成从认知到交付的完整闭环。

> **口径权威源**：`assets/facts.conf`（catchphrase 数字单一事实源，self-check 机器执法）。

---

## 一、为什么「AI 写代码」已经不够了？

大模型普及两年，几乎每个开发者都在用 AI 写代码。但当我们审视真实的生产现场，会发现一个尴尬的事实：

**AI 的代码生成能力已被充分释放，但项目认知几乎为零。**

### 三个结构性瓶颈

**瓶颈 1：AI 不知道你的项目规则。** AI 不知道哪些目录不能改、依赖版本不能升级、哪些组件可以复用。产出的代码经常违反项目规则。

**瓶颈 2：AI 不懂你的领域。** 密码必须哈希、SQL 必须参数化、消息有时序性——这些是客观规律，违反就是硬伤。AI 不知道。

**瓶颈 3：检查靠人工，过程不可见。** 没有自动化检查就没有信任，没有信任就只能逐行人工 review。

**核心论断：AI 的代码生成能力已经很强，但「项目认知」——对项目规则、结构、领域知识、可复用单元的理解——还停留在零。**

---

## 二、swarm-yuan 的关键设计理念

### 理念一：先认识，再行动

AI 写代码前必须先认识项目。swarm-yuan 用 **17 项特征卡** 完成认知，用 **49 个质量门禁** 守护行动。不认识就写 = 盲动。

### 理念二：拼装式开发

新功能 = 既有稳定单元的拼装 + 最小新增胶水代码。三条禁止：禁止重复造轮子、禁止侵入式重构、禁止破坏性改造。特征卡第 11 项盘点全部可复用单元，门禁 `--reuse` 验证复用合规。

### 理念三：呈现递进的关系，而非仅关注计算

门禁不是"数 import 数"——每个计数背后指向一条关系规律。`--layer` 数 import 是为了验证"结构是否遵循依赖单向"；`--reuse` 数新增导出是为了验证"概念是否复用了既存稳定单元"。

### 理念四：特征卡是立法，门禁是执法

17 项特征卡定义「项目应该是什么样的」，49 个门禁验证「代码是否符合」。两者构成闭环——特征卡驱动门禁配置，门禁验证特征卡定义的规则。**门禁还按执法强度分三档（决策 19）**：strict 17（真 fail 阻断）/ warn 21（混合）/ advisory 11（永不 fail，观测类）——让"门禁是执法"不再是一句宣称，而是机器可核验的分层。

---

## 三、17 项特征卡：项目的「认知 DNA」

### 什么是特征卡

特征卡是 AI 探查项目后提取的 **17 项项目特征**，每项落到真实路径和版本号，不用占位符。它不是独立文件，而是**分散承接进目标 skill 的各个文件中**，是门禁配置和文件填充的「数据源」。

**没有特征卡，门禁就是无源之水——不知道项目边界在哪、哪些单元稳定、什么领域规律不能违反。**

### 17 项特征卡

| # | 特征项 | AI 提取什么 | 为什么重要 |
|---|--------|-----------|-----------|
| 1 | 项目类型 | 单体/monorepo/overlay-fork/微服务 | 决定探查策略和门禁方向 |
| 2 | **可改范围** | 可改目录 + 只读目录 + 只读区修改机制 | **安全铁律依据**——改了只读区 = 违规 |
| 3 | **改造分类** | A类(纯新增)/B类(骨架修改) | **决定代码怎么写** |
| 4 | 技术栈 | 语言+框架+构建+测试（含版本基线） | 版本锁定依据，`--deps` 对比基线 |
| 5 | **构建命令** | dev/build/test/release 真实命令 | **门禁执行基础**——`--build` `--test` 跑这些 |
| 6 | 分支规范 | 命名/合入/保护分支/推送 | `--branch` 校验规则 |
| 7 | 安全规则 | 脱敏/密钥/白名单 | `--sensitive` `--security` 扫描范围 |
| 8 | 文档约定 | spec/plan 位置和命名 | spec 文件路径 |
| 9 | 测试体系 | 框架/目录/命令 | `--test` 执行命令 |
| 10 | 环境资源 | 运行时/DB/缓存/MQ/MCP | `--service` 配置 |
| 11 | **可复用稳定单元** | 全部稳定 API/组件/类/函数/store/类型（签名+路径+用途+复用方式+稳定性标注） | **拼装式开发核心依据**——`--reuse` 重名检测源 |
| 12 | 数据规范 | schema/样例/业务规则/勾稽 | `--consistency` 核对项 |
| 13 | 认知基底 | 认知映射表 + 六维动力学基线 | `--cognition` 对比基线 |
| 14 | **领域知识** | 技术+业务领域 → 推导客观规律 | **防达克效应**——`--domain` 违规检测 |

**第 11 项是核心中的核心。** AI 用 graphify `query` / gitnexus `context` 系统性盘点全部稳定单元（GitNexus 因 PolyForm Noncommercial 禁商用降级为非默认，graphify（MIT）提为默认代码图谱工具）——不是随机 grep，而是基于代码图谱的 360 度上下文查询。每个单元记录签名、路径、用途、复用方式、稳定性标注。

### 特征卡如何驱动一切

**→ 文件填充：** SKILL.md 铁律 ← 第 2/6 项 → codebase.md 技术栈 ← 第 4 项 → dev-guide.md 改造分类 ← 第 3 项 → reference-manual.md 组件库 ← 第 11 项 → release.md 命令 ← 第 5 项……

**→ 门禁配置：** precheck.conf 162 个变量从特征卡推导——WRITABLE_DIRS ← 第 2 项、TEST_CMD ← 第 5 项、LAYER_DEFS ← 第 3 项、STABLE_GLOBS ← 第 11 项、SERVICE_DIRS ← 第 10 项……

**→ 开发流程：** 开始新需求时 AI 从第 11 项检索可复用单元 → 预填 spec §5.5 → 编码时查第 11 项组件库拼装优先 → 提交前 49 个门禁按特征卡规则检查。

### 落地示例（SwarmStudio overlay）

| # | 真实值 |
|---|--------|
| 1 | overlay 注入式二次开发（Vue 3 + Electron） |
| 2 | 可改: overlay/；只读: upstream/（严格禁止） |
| 3 | A类（custom/ 纯新增）+ B类（patches/ 骨架修改） |
| 5 | `npm run dev`(:8649) / `npm test` / `npm run inject` |
| 11 | CockpitWorkspace / CockpitKanban / GatewayNoticeBanner 等 15+ 组件 |
| 14 | IM 通讯（Matrix 协议）+ DevOps 监控 |

---

## 四、49 个质量门禁：特征卡的守卫者

### 门禁与特征卡的关系

**特征卡是立法，门禁是执法。**

| 特征卡项（立法） | 门禁（执法） |
|----------------|-------------|
| 第 2 项：overlay/ 可改，upstream/ 只读 | `--scope` 检查 git diff 是否触碰只读目录 |
| 第 5 项：`npm run build` | `--build` 运行此命令，非零 = fail |
| 第 6 项：feat/fix/refactor | `--branch` 校验分支名是否匹配正则 |
| 第 7 项：密钥不入代码库 | `--sensitive` `--security` grep 扫描密钥模式 |
| 第 11 项：CockpitWorkspace 等稳定单元 | `--reuse` 检测新增单元是否与既有重名 |
| 第 11 项：STABLE_GLOBS 指定的稳定层 | `--stable-diff` 检测稳定层被改而未声明 |
| 第 14 项：密码必须哈希 | `--domain` grep 检测密码明文存储 |

### 核心门禁（`--all`，10 个，~5 秒）

| 门禁 | 检查什么 | fail 条件 |
|------|---------|----------|
| `--branch` | 分支命名 + 保护分支 | 在 main 上开发 / 分支名不合规 |
| `--scope` | 改动范围 | 只读目录有改动 |
| `--build` | 构建通过 | 构建失败 |
| `--sensitive` | 敏感信息 | 密码/密钥明文 |
| `--review` | 代码审查（5 维度） | ocr 检测到 High |
| `--reuse` | 复用合规 | spec 缺 §5.5 / 新增单元与既有重名 |
| `--deps` | 依赖锁定 | 版本变更但 spec 未声明 |
| `--security` | OWASP Top 10 | 注入/XSS/eval/硬编码密钥 |
| `--test` | 测试通过 | 测试失败 |
| `--consistency` | 业务规则 + 勾稽 | 人工核对项 |

### 架构门禁（`--all-full`，17 个，~30 秒，未配置则静默跳过）

| 门禁 | 检查什么 | 特征卡依据 |
|------|---------|-----------|
| `--layer` | DDD 分层边界（穿透/倒置/领域污染/聚合跨引用） | 第 3 项 |
| `--stable-diff` | 稳定单元篡改（改稳定层须 spec MODIFIED 声明） | 第 11 项 |
| `--link-depth` | 调用链深度（链路膨胀/纯转发堆叠） | 第 13 项 |
| `--adr` | 架构决策记录（ADR + 技术债登记） | 第 8 项 |
| `--contract` | 接口契约（version + ACL 防腐层） | 第 10 项 |
| `--consistency-cross` | BDAT 一致性（术语表 vs 代码 + 数据所有权） | 第 12 项 |
| `--impact` | 变更影响分析（消费方反查） | — |
| `--service` | 微服务架构（共享 DB/同步链/网关/trace） | 第 10 项 |
| `--api` | API 契约与幂等（version/幂等键/分布式事务） | 第 10 项 |
| `--state` | 前端状态管理（巨型 store/prop drilling/派生 useState） | 第 11 项 |
| `--frontend` | 前端组件架构（层级/props/循环依赖/CSS 污染） | 第 11 项 |
| `--cognition` | 认知递进体检（六阶+六维+五层总分） | 第 13 项 |
| `--domain` | 领域知识违规检测（密码明文/SQL 拼接/XSS/并发竞态） | 第 14 项 |
| `--knowledge` | 项目知识复用（AGENTS.md/CLAUDE.md/记忆 → skill 引用） | — |
| `--mermaid` | Mermaid 可视化（架构图/流程图/调用链） | — |

### 合规门禁（17 个，独立 `--compliance-suite` 按需执行，未配置则静默跳过）

| 门禁 | 检查什么 | 特征卡依据 |
|------|---------|-----------|
| `--compliance` | 标准合规矩阵核验（六锚点 + 零占位符 + spec §22 标准合规段） | 第 8 项 |
| `--docs-pack` | 文档包清单（rusp/gbt9386/gbt8567 profile 必备文档 + TBD 扫描） | 第 8 项 |
| `--sbom` | SBOM 生成 + 许可证块名单扫描（启用后 fail-closed） | 第 4 项 |
| `--privacy` | 个人信息扫描（身份证/手机号/银行卡内置模式 + 豁免留痕，启用后 fail-closed） | 第 7 项 |
| `--authz` | 授权类弱点扫描（缺鉴权注解/IDOR/CORS 放行带凭据，CWE-862/863/639/284） | 第 7 项 |
| `--requirements` | 需求质量检查（spec 无 TBD/待定 + REQ- 唯一编号，严格模式 fail-closed） | 第 8 项 |
| `--crypto` | 密码算法合规（profile=gm 密评：弱算法 → fail，国密白名单 SM2/SM3/SM4） | 第 7 项 |
| `--rtm` | 需求追溯矩阵（spec REQ- 编号须在测试目录或追溯矩阵可追溯；RTM_MATRIX_REQUIRED=1 时矩阵缺失 fail-closed） | 第 8 项 |
| `--release-sign` | 发布签名与 provenance（产物须带 .sig/.asc/.att/.bundle 伴随签名；cosign verify-blob 验签 + SLSA provenance fail-closed） | 第 5 项 |
| `--dengbao` | 等保 2.0 控制点（DENGBAO_LEVEL 二/三级分级：双因子/审计日志/审计字段/个人信息保护缺口，启用后 fail-closed + 豁免留痕） | 第 7 项 |
| `--pia` | 隐私影响评估（PIA 文档缺失 → fail，启用后 fail-closed） | 第 7 项 |
| `--sast-deep` | 深度 SAST（semgrep→opengrep→内置降级链，启用后 fail-closed） | 第 7 项 |
| `--oss-eval` | 开源代码安全评价（复用 --sbom 产物，成分清单/许可证纳入评价，启用后 fail-closed） | 第 4 项 |

### 降级策略

每个门禁优先用运行时工具，无则降级：

```
graphify explain（知识图，默认）→ gitnexus trace（代码图谱，仅非商用场景）→ madge（依赖树）→ 纯转发统计
ocr review（diff 审查）→ ocr scan（全文件）→ AI 5 维度审查
claude-mem search（记忆库）→ 文件检测
```

**有能力就用，无能力降级——不浪费工具，也不因缺失崩溃。**

---

## 五、五层认知基底：特征卡和门禁的哲学根基

| 层 | 解决什么 | 与特征卡/门禁的关系 |
|----|---------|-------------------|
| 认知递进 | 如何认识项目 | 特征卡 17 项 = 认知递进的产物 |
| 思维语言 | 如何思考 | spec §14-§18 = 思维语言在 spec 中的落地 |
| 认知辩证 | 如何推演+自证伪 | 门禁 `--cognition` = 认知辩证的验证工具 |
| 偏差防范 | 如何纠偏 | spec §16 偏差自检 = 偏差防范的工程落地 |
| 辩证认知 | 如何统一前四层 | 门禁 `--domain` = 辩证认知的违规检测 |

> 门禁不是"数 import 数"——`--layer` 数 import 是为了验证"结构是否遵循依赖单向规律"；`--reuse` 数新增导出是为了验证"概念是否复用了特征卡第 11 项的既存稳定单元"。每个计数背后指向一条关系规律。

---

## 六、11 个运行时 + 32 个领域

**运行时工具**（只引用调用不重新实现）：OpenSpec / superpowers / comet / GitNexus / graphify / gsd-core / claude-mem / open-code-review / gstack / Ruflo / ECC

**领域知识速查**：数据库 ACID / 网络 CORS / 安全密码哈希 / IM 消息保序 / 电商库存原子扣减 / 金融金额 Decimal……32 个领域的客观规律。

**铁律：领域规则不得违反通用常识和客观规律。违反就是硬伤。**

---

## 七、Claude Code 深度集成

| 能力 | 用法 |
|------|------|
| ⚡ Hooks | SessionStart 注入状态 + PreToolUse(Write) 检查范围 |
| / Slash Commands | `/my-skill:spec` / `/my-skill:precheck` / `/my-skill:explore` |
| 🔌 MCP | 自动注册 gitnexus / claude-mem / graphify |
| 🌊 Dynamic Workflows | 复杂变更并行扇出 + 交叉验证 |
| 🔍 LSP | go-to-definition / find-references |
| 🤖 Subagent | 每任务新 subagent + 两阶段审查 |

---

## 八、零占位符 + 自举

**零占位符：** AI 执行完整 13 步流程后由脚本机器执法（`bash scripts/generate-skill.sh --verify-completeness <skill_dir>`）——零残留才算完成。

**自举：** swarm-yuan 能用自身的 49 个门禁检查自身。一个连自己都检查不了的工具，凭什么检查你的项目？

---

## 九、一键安装，兼容 7 个 AI 工具

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
| **特征卡** | **17 项（驱动全部文件 + 162 个门禁变量 + 开发流程）** |
| **质量门禁** | **49 个（核心 10 + 架构 17 + 合规 17 + advisory-only 5，特征卡立法 + 门禁执法）** |
| 运行时工具 | 11 |
| 领域知识 | 32 个领域 |
| 认知基底 | 5 层 |
| 兼容 AI 工具 | 7 个 |
| 三平台 | macOS / Linux / Windows |
| 零占位符 | ✅ |
| 自举 | ✅ |

---

**项目地址**：https://github.com/issac-new/Swarm-yuan

**使用说明**：`docs/USAGE.md`

---

> AI 的代码生成能力已经很强，但「项目认知」还停留在零。swarm-yuan 用 17 项特征卡让 AI 先懂你的项目，用 49 个质量门禁守护代码合规——特征卡是立法，门禁是执法。
