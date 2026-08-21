# swarm-yuan — 让 AI 懂你的项目，再写代码

> 从「AI 辅助写代码」到「AI 懂项目再写代码」的认知基础设施。
>
> 17 项特征卡让 AI 认识你的项目，54 个质量门禁守护代码合规——特征卡是立法，门禁是执法。
> （边界声明：门禁外部有效性目前在 Java/JS Web 品类上验证（R9），跨品类见 `verifier/v2/external-validity.md` 立项稿。）
>
> **口径权威源**：`assets/facts.conf`（所有 catchphrase 数字的单一事实源，`scripts/self-check.sh` 机器执法做漂移检测）。

[![Release](https://img.shields.io/badge/release-v2.0-blue)](https://github.com/issac-new/Swarm-yuan/releases/tag/v2.0)
[![Feature Card](https://img.shields.io/badge/feature%20card-17-green)]()
[![Quality Gates](https://img.shields.io/badge/quality%20gates-54-orange)]()
[![Frameworks](https://img.shields.io/badge/frameworks-74-blueviolet)]()
[![Runtimes](https://img.shields.io/badge/runtimes-13-yellow)]()
[![License](https://img.shields.io/badge/license-MIT-lightgrey)]()

---

## 适用场景（WP-P10 范式定位）

> 详见 `docs/paradigm-positioning.md`。swarm-yuan 是重量级范式，重量是设计选择不是缺陷——通过 profile 自适应让重量显式可选。

**适用**：团队协作项目（≥2 人）、中大型项目（≥80 文件或 ≥3 形态）、强监管交付（合规要求）、长期维护项目（需沉淀记忆）、多技术栈混合项目（微服务/全栈）。

**不适用**：个人脚本/一次性原型、学习用 demo、极小改动（改 typo/调样式）、无 AI 辅助的纯人工开发。**替代方案**：直接用 AI 裸写，或单文件 `precheck.sh` 做门禁不套生成器，或传统 lint/test 工具链。

---

## 为什么需要它

**痛点 1：AI 不知道你的项目规则。** 改了不该改的文件、升级了不该升级的依赖、重复造了已有组件的轮子。

**痛点 2：AI 不懂你的领域。** 密码必须哈希、SQL 必须参数化、消息有时序性——违反就是硬伤。

**痛点 3：检查靠人工。** 没有自动化检查就没有信任，只能逐行 review。

**核心论断：AI 的代码生成能力已经很强，但「项目认知」还停留在零。**

---

## 关键设计理念

| 理念 | 含义 |
|------|------|
| 先认识，再行动 | AI 写代码前必须先认识项目。17 项特征卡完成认知，54 个门禁守护行动 |
| 拼装式开发 | 新功能 = 既有稳定单元拼装 + 最小新增胶水代码。禁止重复造轮子/侵入式重构/破坏性改造 |
| 呈现递进的关系 | 门禁不是"数 import 数"——每个计数背后指向一条关系规律 |
| 特征卡是立法，门禁是执法，验证器是司法 | 17 项特征卡定义「项目应该是什么样的」，54 个门禁验证「代码是否符合」，`verifier/v1`（golden-vector/金向量 = 74 框架 fixture 的预期门禁 exit-code 向量，回归基线）用 fixture 双态 + cli A/B 字节级等价做独立司法 |
| 分层整合，诚实降级 | 13 运行时按深度/CLI/方法论三层整合，每层有自带降级载体，未装不阻塞，不假装全深度接线 |
| 重量是设计选择，不是缺陷 | 重量级范式通过 `--profile auto\|lite\|standard\|compliance` 四档自适应让重量显式可选（决策 18/25，WP-P10 范式定位） |

---

## 17 项特征卡：项目的「认知 DNA」

AI 探查项目后提取 17 项特征（P0 六项 1/4/5/11/15/16 + P1 十一项），每项落到真实路径和版本号，不用占位符。特征卡不是独立文件，而是**分散承接进目标技能的各个文件中**，驱动门禁配置和文件填充。

| # | 特征项 | AI 提取什么 | 驱动什么 |
|---|--------|-----------|---------|
| 1 | 项目类型 | 单体/monorepo/overlay-fork/微服务 | SKILL.md 定位 + `--cognition` |
| 2 | **可改范围** | 可改目录 + 只读目录 + 只读区修改机制 | 安全铁律 + `--scope` |
| 3 | **改造分类** | A类(纯新增)/B类(骨架修改) | dev-guide + `--layer` |
| 4 | 技术栈 | 语言+框架+构建+测试（含版本基线） | codebase.md + `--deps` + `--framework` |
| 5 | **构建命令** | dev/build/test/release 真实命令 | `--build` `--test` |
| 6 | 分支规范 | 命名/合入/保护分支/推送 | `--branch` |
| 7 | 安全规则 | 脱敏/密钥/白名单 | `--sensitive` `--security` |
| 8 | 文档约定 | spec/plan 位置和命名 | workflow + spec-template |
| 9 | 测试体系 | 框架/目录/命令 | `--test` |
| 10 | 环境资源 | 运行时/DB/缓存/MQ/MCP | `--service` |
| 11 | **可复用稳定单元** | 全部稳定 API/组件/类/函数/store/类型（五维字段定义见 `references/exploration-guide.md` §11f） | **`--reuse` + `--stable-diff` + `--state` + `--frontend`** |
| 12 | 数据规范 | schema/样例/业务规则/勾稽 | `--consistency` |
| 13 | 认知框架 | 认知映射表 + 六维动力学基线 | `--cognition` |
| 14 | **领域知识** | 技术+业务领域 → 推导客观规律 | `--domain` |
| 15 | **编排调用关系及约束** | 导入方向/注册顺序/路由挂载/状态所有权/测试边界 | `--layer` `--frontend` |
| 16 | **详尽组件库清单（全量）** | 全量构件表 + 接口端点表 + store/类型表（清单计数核验） | reference-manual §4/§6/§9 |
| 17 | 合规与质量基线 | 强监管关键词/合规门禁开关/质量门禁开关 | `--compliance-suite` profile 升档 |

**第 11 项是核心中的核心**——AI 用 graphify `query` / gitnexus `context` 系统性盘点全部稳定单元（GitNexus（PolyForm Noncommercial 禁商用）降级为非默认，graphify（MIT）提为默认代码图谱工具），每个记录五维字段（定义见 `references/exploration-guide.md` §11f，详解见 `docs/FIVE_DIMENSIONS.md`）。

**特征卡驱动一切：** → 文件填充（SKILL.md 铁律 ← 第 2/6 项、codebase.md ← 第 4 项、reference-manual.md 组件库 ← 第 11 项）→ 门禁配置（precheck.conf 三件套 176 个变量从特征卡推导，懒生成机制按 ACTIVE_FRAMEWORKS 自动补占位）→ 开发流程（开始新需求时从第 11 项检索可复用单元）。

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

## 54 个质量门禁：特征卡的守卫者

**特征卡是立法，门禁是执法。** 特征卡定义规则，门禁验证合规。

> **门禁分层（决策 19）——执法强度横切维度：** 54 门禁按 `fail()` 能力分三档，与 core/standard/compliance 执行序列正交：
> - **strict（16 个）**：≥3 个 fail 调用，真正阻断交付的硬门禁（branch/layer/reuse/security/shift-left/compliance/sbom/dengbao/pia/test-evidence/review-record/release-sign/quality-model/sast-deep/oss-eval）
> - **warn（23 个）**：1-2 个 fail，混合 warn，能 fail 但触发条件窄（privacy/authz/requirements/rtm/crypto/contract/impact/service/api/review/frontend/domain/knowledge 等）
> - **advisory（15 个）**：0 个 fail，永不阻断，只 warn/pass（cognition/consistency/consistency-cross/link-depth/state/diagram/operate/decision-audit/learnings/state-phase/upstream-baseline/pr-quality/skill-supply-chain/cwe-audit/cert-audit）
>
> **advisory 三轴命名（T12 澄清）**：① advisory-file=15（gates-advisory.sh 物理位置，含 cognition 因历史）；② advisory-level=14（0-fail enforce，gate-enforce-level.conf）；③ advisory-only=10（不在 ALL_GATES_CORE/STANDARD/COMPLIANCE 执行序列：operate/decision-audit/cwe-audit/cert-audit/learnings/pr-quality/skill-supply-chain/state-phase/upstream-baseline）。三者正交，本文档统一用 enforce-level 口径（14）。
>
> 查看分层：`bash scripts/precheck.sh --list-gates`。分层由 `scripts/gen-enforce-level.sh` 自动按 fail() 数归类（幂等），手动覆盖见 precheck.sh `_ENFORCE_OVERRIDE`。

| 特征卡项（立法） | 门禁（执法） |
|----------------|-------------|
| 第 2 项：可改范围 | `--scope` 检查 git diff 是否触碰只读目录 |
| 第 5 项：构建命令 | `--build` 运行此命令，非零 = fail |
| 第 6 项：分支规范 | `--branch` 校验分支名 |
| 第 7 项：安全规则 | `--sensitive` `--security` 扫描密钥 |
| 第 11 项：可复用单元 | `--reuse` 检测新增单元与既有重名 |
| 第 11 项：稳定层 | `--stable-diff` 检测稳定层被改未声明 |
| 第 14 项：领域知识 | `--domain` 检测密码明文存储等违规 |

### 核心门禁（`--all`，10 个，通常 10-20 秒，取决于项目规模与 build/test 命令耗时）

| 门禁 | 检查什么 | fail 条件 |
|------|---------|----------|
| `--branch` | 分支命名 + 保护分支 | 在 main 上开发 / 分支名不合规 |
| `--scope` | 改动范围 | 只读目录有改动 |
| `--build` | 构建通过 | 构建失败 |
| `--sensitive` | 敏感信息 | 密码/密钥明文 |
| `--review` | 代码审查（5 维度） | ocr 检测到 High |
| `--reuse` | 复用合规 | spec 缺 §5.5 / 新增与既有重名 |
| `--deps` | 依赖锁定 | 版本变更但 spec 未声明 |
| `--security` | OWASP Top 10 | 注入/XSS/eval/硬编码密钥 |
| `--test` | 测试通过 | 测试失败 |
| `--consistency` | 业务规则 + 勾稽 | 人工核对项 |

### 架构门禁（`--all-full` 在核心 10 个之上新增 17 个，通常 15-40 秒，未配置则静默跳过）

| 门禁 | 检查什么 | 特征卡依据 |
|------|---------|-----------|
| `--layer` | DDD 分层边界（穿透/倒置/领域污染/聚合跨引用） | 第 3 项 |
| `--stable-diff` | 稳定单元篡改（改稳定层须 spec MODIFIED 声明） | 第 11 项 |
| `--link-depth` | 调用链深度（链路膨胀/纯转发堆叠） | 第 13 项 |
| `--adr` | 架构决策记录（ADR + 技术债登记） | 第 8 项 |
| `--contract` | 接口契约（version + ACL 防腐层） | 第 10 项 |
| `--consistency-cross` | BDAT 一致性（术语表 vs 代码 + 数据所有权） | 第 12 项 |
| `--impact` | 变更影响分析（消费方反查 + graphify God Nodes 检测） | — |
| `--service` | 微服务架构（共享 DB/同步链/网关/trace） | 第 10 项 |
| `--api` | API 契约与幂等（version/幂等键/分布式事务） | 第 10 项 |
| `--state` | 前端状态管理（巨型 store/prop drilling/派生 useState） | 第 11 项 |
| `--frontend` | 前端组件架构（层级/props/循环依赖/CSS 污染） | 第 11 项 |
| `--cognition` | 认知递进体检（六阶+六维+五层总分） | 第 13 项 |
| `--domain` | 领域知识违规检测（密码明文/SQL 拼接/XSS/并发竞态） | 第 14 项 |
| `--knowledge` | 项目知识复用（AGENTS.md/CLAUDE.md/记忆 → skill 引用） | — |
| `--diagram` | 可视化（mermaid 结构图：架构/流程/调用链 + echarts/antv 数据图：统计/分布/趋势；`--mermaid` 为别名） | — |
| `--shift-left` | 左移检查（测试设计/变更影响/可观测性，防缺陷流入后段） | — |
| `--framework` | 框架适配门禁（按 ACTIVE_FRAMEWORKS 逐框架执行规则集，74 框架 × 六段式） | 第 4 项 |

### 合规门禁（17 个，独立 `--compliance-suite` 按需执行，未配置则静默跳过）

| 门禁 | 检查什么 | 依据 |
|------|---------|------|
| `--compliance` | 标准合规矩阵核验（六锚点完整 + 零占位符 + spec §22 标准合规段） | GB/T 25000.51/8566 |
| `--docs-pack` | 文档包清单（rusp/gbt9386/gbt8567 profile 必备文档存在性 + TBD 扫描） | GB/T 8567/9386 |
| `--sbom` | SBOM 生成 + 许可证块名单扫描（syft→cdxgen→lockfile 降级链，启用后 fail-closed） | 供应链 SBOM/SLSA |
| `--privacy` | 个人信息扫描（身份证/手机号/银行卡内置模式 + 豁免留痕，启用后 fail-closed） | 个保法/GB/T 35273 |
| `--authz` | 授权类弱点扫描（缺鉴权注解/IDOR/CORS 放行带凭据，CWE-862/863/639/284） | OWASP ASVS / CWE-862 |
| `--requirements` | 需求质量检查（spec 无 TBD/待定 + REQ- 唯一编号，严格模式启用后 fail-closed） | ISO/IEC/IEEE 29148 |
| `--crypto` | 密码算法合规（profile=gm 密评：弱算法 MD5/SHA1/DES → fail，国密白名单 SM2/SM3/SM4） | GB/T 39786-2021 |
| `--rtm` | 需求追溯矩阵（spec REQ- 编号须在测试目录或追溯矩阵可追溯；RTM_MATRIX_REQUIRED=1 时矩阵缺失 fail-closed） | ISO/IEC/IEEE 29148 RTM |
| `--release-sign` | 发布签名与 provenance（产物须带 .sig/.asc/.att/.bundle 伴随签名；cosign verify-blob 验签 + SLSA provenance fail-closed） | SLSA Build L2 / SSDF PS.2 |
| `--dengbao` | 等保 2.0 控制点（DENGBAO_LEVEL 二/三级分级，启用后 fail-closed + 豁免留痕） | GB/T 22239-2019 |
| `--pia` | 隐私影响评估（PIA 文档缺失 → fail，启用后 fail-closed） | 个保法 55-56 条 / GB/T 35273 |
| `--sast-deep` | 深度 SAST（semgrep→opengrep→内置降级链，启用后 fail-closed） | GB/T 34943/34944/34946 |
| `--oss-eval` | 开源代码安全评价（复用 --sbom 产物，成分清单/许可证纳入评价，启用后 fail-closed） | GB/T 43848-2024 |
| `--quality-model` | 质量模型核验（GB/T 25000.51 八特性 + 质量门禁基线，WP-S2） | GB/T 25000.51 |
| `--test-evidence` | 测试证据链（TEST_EVIDENCE_REQUIRED 开关，未配置=SKIP 明示，WP-S2） | GB/T 9386 |
| `--review-record` | 评审记录（REVIEW_RECORD_REQUIRED 开关，WP-S2） | GB/T 8567 |
| `--metrics` | 质量度量趋势（gate-trends.sh 衰退检测，WP-S2） | GB/T 15532 |

### 降级策略

每个门禁优先用运行时工具，无则降级：

```
graphify path/explain → gitnexus trace（仅非商用场景）→ madge → 纯转发统计
ocr review → ocr scan → AI 5 维度审查
claude-mem search → 文件检测
semgrep → opengrep → 内置 CWE 模式（--sast-deep）
syft → cdxgen → lockfile 解析（--sbom）
```

### SARIF 2.1.0 输出

`bash scripts/precheck.sh --format json | bash scripts/to-sarif.sh > results.sarif` —— 符合 OASIS SARIF 2.1.0（2020-03-27），规则元数据（CWE 标签 / GB-T 条款）从 `assets/standards-map.conf`（75 条目：21 门禁级 + 50 框架级 + 4 advisory）注入，可被 GitHub Code Scanning / SonarQube / Azure DevOps 直接消费。

---

## 7 行业 profile：强监管交付的行业基线

7 个行业各一份 `.md`（`references/industry-profile-*.md`，法规依据）+ `.conf`（`assets/industry-profiles/<行业>.conf`，门禁映射）对，按需 `cat assets/industry-profiles/<行业>.conf >> <目标技能>/scripts/precheck.conf` 后 `precheck.sh --doctor` 自检为 0 fail 即接入：

| 行业 | 法规覆盖 | 基础标准 |
|------|---------|---------|
| 金融 | 网安法/数安法/个保法 + 人民银行/金监总局/证监会办法 + JR/T 系列 | JR/T 0171-2020 / 金规〔2024〕24号 |
| 医疗 | 个保法/数安法 + 卫健委办法/互联网诊疗细则 | GB/T 39725 / YY/T 0664-2020 |
| 政务 | 网安法 21 条/密评/个保法 55-56 | GB/T 22239 / 39786 / 43848 |
| 汽车 | 车载软件安全 + 软件升级 | ISO 26262 / UNECE R155 / R156 / ASIL A-D |
| 能源 | 等保 + 密评 + 工控安全 | IEC 62443 / GB/T 36572-2018 |
| 工业 | DCS/SCADA/PLC | IEC 62443 SL1-SL4 / GB/T 33009-2016 |
| 通信 | 5GC/EPC/BOSS | YD/T 1729-2008 / 3GPP TS 33.501 |

> 行业 profile 与 `--profile auto\|lite\|standard\|compliance` 四档（FACT_PROFILES=4）是不同维度：前者是行业法规基线，后者是重量自适应档位。

---

## 快速开始

### 安装

```bash
git clone https://github.com/issac-new/Swarm-yuan.git
cd Swarm-yuan/swarm-yuan
bash install.sh
```

自动检测 7 个 AI 工具：Claude Code / Codex / Cursor / Windsurf / OpenCode / Gemini CLI / Kimi（按兼容深度分三档，见「AI 工具兼容三档」）。Windows 用 `install.bat`。

### 生成项目技能

对 AI 说："为 /path/to/my-project 生成 skill"

或用 slash 命令：`/swarm-yuan /path/to/my-project`

AI 自动执行 13 节点流程（**不允许中途停在骨架阶段**）：

```
自检 → 读取项目知识 → 探查仓库 → 提取 17 项特征卡 → 创建骨架 → 填充全部文件（消除占位符）
→ 配置 precheck.conf → 生成 hooks/commands → 运行 54 个门禁 → 写回记忆
→ 脚本确认零占位符（`generate-skill.sh --verify-completeness`）→ 维度计数核验（`inventory-verify.sh`）
```

### 日常使用

```bash
# 提交前自检
bash .claude/skills/my-project-dev/scripts/precheck.sh --all         # 核心 10 门禁
bash .claude/skills/my-project-dev/scripts/precheck.sh --all-full    # 标准 27 门禁（核心 10 + 架构 17）
bash .claude/skills/my-project-dev/scripts/precheck.sh --compliance-suite  # 合规 17 门禁（强监管交付按需）

# 单独跑某个门禁
bash .claude/skills/my-project-dev/scripts/precheck.sh --security
bash .claude/skills/my-project-dev/scripts/precheck.sh --reuse

# SARIF 输出（接入 GitHub Code Scanning）
bash .claude/skills/my-project-dev/scripts/precheck.sh --all --format json | bash scripts/to-sarif.sh > results.sarif
```

或对 AI 说："跑门禁" / "开始新需求：xxx"

### 升级

```bash
bash ~/.claude/skills/swarm-yuan/scripts/generate-skill.sh --upgrade my-project-dev /path/to/project
```

覆盖通用模板 / 保留项目特定文件 / 自动备份 / AI 重新填充 precheck.conf。

---

## 五层认知框架

| 层 | 解决什么 | 与特征卡/门禁的关系 |
|----|---------|-------------------|
| 认知递进 | 如何认识项目（六阶：概念→结构→空间→映射→规律→处理 + 六维动力学） | 特征卡 17 项 = 认知递进的产物 |
| 思维语言 | 如何思考（三元+三导向+七推理+7×7 双循环） | spec §14/§15 = 思维语言落地（§16 第四层 / §17 第五层 / §18 领域知识贯穿） |
| 认知辩证 | 如何推演+自证伪（logic-razor 六步） | `--cognition` = 验证工具 |
| 偏差防范 | 如何纠偏（5 维偏差 + 8 心智模型） | spec §16 偏差自检 |
| 辩证认知 | 如何统一前四层（7 对辩证对 + ECC 四声部议事会） | `--domain` = 违规检测 |

> 详见 `references/cognition-framework.md`。
> ⚠️ "`--cognition` 门禁得分 ≥15/22 = 认知完整"是**工程启发式评分**，非心理测量学构念--未经信度/效度检验，分数仅用于自检"是否覆盖五层话题"，不构成对 AI 认知能力的测量。详见根 `README.md` 五层认知框架段与 `docs/research/R3-methodology.md` §2.1。

---

## 13 个运行时 + 32 个领域

**运行时**（只引用调用不重新实现，按接线深度分三层；`docs/upstream-baseline.md` 登记 13 个运行时的仓库/许可证/基线版本/drift 状态）：

| 层 | 运行时 | 接线方式 |
|----|--------|---------|
| 深度接线（4） | GitNexus / graphify / claude-mem / ocr | precheck.sh 门禁内真实子进程调用 + 多级降级链 |
| CLI 接线（4） | OpenSpec / comet / gsd-core / codex-security | 门禁/状态机按需调用 CLI（`openspec validate`/`comet guard`/`gsd-tools validate health`/`npx @openai/codex-security scan`）+ 降级到自带载体 |
| 方法论引用（5） | superpowers / gstack / Ruflo / ECC / impeccable | AI 按 workflow 节点引用其模式，swarm-yuan 自带等价降级载体 |

每层有自带降级载体，未装运行时时不阻塞（fail-open + 降级），不假装全深度接线。`--upstream-baseline` 门禁（advisory）自动检测 upstream drift，CI 可见但不阻断构建。

**领域知识**：数据库 ACID / 网络 CORS / 安全密码哈希 / IM 消息保序 / 电商库存原子扣减 / 金融金额 Decimal……32 个领域客观规律（详见 `references/domain-knowledge.md`）。

---

## AI 工具兼容三档（G7 分级声明）

swarm-yuan 宣称"兼容 7 个 AI 工具"，实际是**三层同心圆**（R1 §四 实证），按深度分三档：

| 档 | 工具 | 能力 | 实现方式 |
|----|------|------|---------|
| **可运行（runnable）** | Claude Code / Codex / Cursor / Windsurf / OpenCode / Gemini / Kimi（全 7） | skill 目录复制 + bash 脚本执行 | `install.sh`/`generate-skill.sh` 检测 home 目录首个命中，复制同一套 markdown+bash |
| **可集成（cli）** | Cursor / Windsurf / Codex / OpenCode / Gemini / Kimi（6） | 原生命令格式派生（GEMINI.md/AGENTS.md 标记区块段） | `generate-skill.sh --render-tools` 按工具派生规则文件 |
| **深度集成（deep）** | Claude Code（1） | Hooks + Slash Commands + MCP + Dynamic Workflows + LSP + Subagent | `hooks/hooks.json` + `commands/*.md` + `.mcp.json` + `settings.local.json` |

> **诚实声明**：对非 Claude Code 的 6 个工具，"兼容"= 可运行 + 可集成（目录复制 + 规则派生），hooks/commands/MCP 等深度能力**不随 skill 迁移**。README 的"Claude Code 深度集成"表不适用于其余 6 者。长期可为各工具生成对应原生命令格式。

---

## Claude Code 深度集成（仅 deep 档）

| 能力 | 用法 |
|------|------|
| Hooks | SessionStart 注入状态 + PreToolUse(Write) 检查范围 |
| Slash Commands | `/my-skill:spec` / `/my-skill:precheck` / `/my-skill:explore` |
| MCP | 自动注册 gitnexus / claude-mem / graphify |
| Dynamic Workflows | 复杂变更并行扇出 + 交叉验证 |
| LSP | go-to-definition / find-references |
| Subagent | 每任务新 subagent + 两阶段审查 |

---

## 零占位符 + 自举

**零占位符：** AI 执行完整 13 节点后由脚本机器执法（`bash scripts/generate-skill.sh --verify-completeness <skill_dir>`）——零残留才算完成。命中"待填充"/"填充指引"/"<占位符>"即列 file:line 并 exit 1。

**自举：** swarm-yuan 能用自身的 54 个门禁检查自身（CI `generator-self-gate` job 三档 `--all`/`--all-full`/`--compliance-suite` RC=0）。**自举只证明内部自洽（门禁规则与自身代码一致），不证明外部有效（门禁能拦截真实缺陷）**--后者由 verifier/v1 C1 行为等价与 R9 真实项目测试覆盖，R9 已披露 fixture 漏掉 3 个 P0/P1。

---

## FAQ

**Q: 门禁报误报？** → 对 AI 说"precheck 报了误报"，AI 自动分析+调整+重跑。也可直接编辑 `precheck.conf`。

**Q: `--reuse` 总是 fail？** → 每次变更前写 spec，填 §5.5 的 4 个 checkbox。先声明复用了特征卡第 11 项的哪些单元，再写代码。

**Q: 不需要微服务/前端/TOGAF？** → 特征卡第 10/11 项留空 = 对应门禁静默跳过。

**Q: 项目结构变了？** → 对 AI 说"重新探查并更新 skill"。AI 重新探查 → 更新特征卡 → 更新门禁配置。

---

## 仓库结构

```
Swarm-yuan/
├── README.md                     ← 仓库门面（本文件的父级）
├── .gitignore                    ← 忽略 swarm-yuan 本地状态
├── docs/                         ← 设计文档 + 计划 + 研究交付物（USAGE/PROMO/FIVE_DIMENSIONS 唯一来源在 swarm-yuan/docs/）
│   ├── paradigm-decisions.md     ← 决策 18-31（1-17 见 paradigm-decisions-archive.md，口径权威源 facts.conf）
│   ├── paradigm-positioning.md   ← WP-P10 范式定位
│   ├── upstream-baseline.md      ← 13 运行时登记 + drift 处置
│   ├── plans/                    ← 4 份 dated 计划
│   └── research/                 ← R1-R9 九份研究交付物
├── swarm-yuan/                   ← 生成器 skill
│   ├── SKILL.md                  ← AI 入口（13 运行时/54 门禁/五层认知/Step 0-8 共 13 节点）
│   ├── install.sh / install.bat  ← 一键安装（7 环境检测 + Windows）
│   ├── assets/                   ← 模板 + 门禁 + 状态机 + 调用追踪
│   │   ├── precheck.sh           ← 门禁调度器
│   │   ├── gates-strict.sh       ← strict 门禁（enforce 分档，行数见 facts.conf FACT_SCRIPT_LOC）
│   │   ├── gates-warn.sh         ← warn 门禁
│   │   ├── gates-advisory.sh     ← advisory 门禁
│   │   ├── precheck.conf         ← 核心配置变量（14 个）
│   │   ├── precheck.arch.conf    ← 架构配置变量（110 个，懒生成）
│   │   ├── precheck.compliance.conf ← 合规配置变量（48 个）
│   │   ├── facts.conf            ← 口径单一事实源（self-check 机器执法）
│   │   ├── gate-enforce-level.conf ← 自动生成的分层映射
│   │   ├── standards-map.conf    ← 75 条目（SARIF 元数据源）
│   │   ├── framework-signals.md  ← 74 框架信号索引
│   │   ├── framework-gates/      ← 74 个 .sh（与 frameworks/*.md 1:1）
│   │   ├── industry-profiles/    ← 7 行业 .conf
│   │   ├── spec-template.md      ← 23 主段 spec 模板（§23=发布后运营）
│   │   └── trace-log.sh          ← 全链路调用追踪（stdout 公告 + trace.jsonl 落盘）
│   ├── docs/                     ← USAGE/PROMO/FIVE_DIMENSIONS 唯一来源
│   ├── references/               ← 40 个参考文档 + frameworks/（74 框架 + _template）
│   ├── scripts/                  ← 28 个脚本（生成器+自检+SARIF+drift+baseline+cost）
│   ├── tests/                    ← fixture 测试（e2e + 74 framework fixture + 48 gate-fixture + sarif-fixture）
│   └── ci/                       ← 自举 self-precheck.conf
```

> **生成的目标技能含**：SKILL.md / references/*.md / assets/* / scripts/(precheck.sh+gates-strict/warn/advisory.sh+gate-enforce-level.conf+precheck.conf 三件套+state-machine.sh+trace-log.sh+memory-writeback.sh+self-check.sh+detect-frameworks.sh+detect-profile-drift.sh+detect-spec-scale.sh+task-scale.sh+cost-report.sh+snippets.md+mcp-tools.md) / hooks/hooks.json / commands/(spec+precheck+explore) / settings.local.json / .mcp.json / .swarm-yuan-version（以 generate-skill.sh UNIVERSAL_FILES 38 条为真值；generate-skill.sh 本身不拷入目标技能）

---

## 数字一览

| 维度 | 数值 | 口径源 |
|------|------|--------|
| **特征卡** | **17 项**（P0 六项 1/4/5/11/15/16 + P1 十一项） | FACT_FEATURE_CARDS=17 |
| **质量门禁** | **54 个** = strict 16 + warn 23 + advisory 15；执行序列 --all 核心 10 / --all-full 标准 27 / --compliance-suite 合规 17 / advisory-only 10 不在任何执行序列 | FACT_GATES_TOTAL=54 |
| **配置变量** | **176 个**（precheck.conf 16 + precheck.arch.conf 112 + precheck.compliance.conf 48，懒生成按 ACTIVE_FRAMEWORKS 补占位） | FACT_CONF_VARS=176 |
| **框架规则集** | **74 个**（references/frameworks/*.md 1:1 配 assets/framework-gates/*.sh） | FACT_FRAMEWORKS=74 |
| **参考文档** | 35 个（references/*.md 不含 frameworks/ 子目录） | FACT_REFERENCES=35 |
| **standards-map** | 75 条目（21 门禁级 + 50 框架级 + 4 advisory） | FACT_STANDARDS_MAP_ENTRIES=75 |
| 运行时工具 | 13（深度 4 + CLI 4 + 方法论 5） | FACT_RUNTIMES=13 |
| spec 模板 | 23 主段（§23=发布后运营） | FACT_SPEC_SECTIONS=23 |
| 领域知识 | 32 个领域 | FACT_DOMAINS=32 |
| 认知框架 | 5 层 | — |
| 行业 profile | 7（金融/医疗/政务/汽车/能源/工业/通信） | — |
| profile 档位 | 4（auto/lite/standard/compliance） | FACT_PROFILES=4 |
| 兼容 AI 工具 | 7（三档：runnable 7 / cli 6 / deep 1） | FACT_COMPAT_*=7/6/1 |
| CWE 条目 | 60 | FACT_CWE_ENTRIES=60 |
| 安全认证 profile | 6 | FACT_CERT_PROFILES=6 |
| 生成流程 | 13 节点 / 8 工作流节点 | FACT_FLOW_STEPS=13 |
| 决策治理类型 | 3（Mechanical / Taste / UserChallenge，对齐 ISO/IEC 42001） | FACT_DECISION_TYPES=3 |
| 三平台 | macOS / Linux / Windows（CI 11 job 全覆盖；**bash 硬前置**，Windows 需 Git Bash/WSL，原生 cmd/PowerShell 不支持） | — |
| 零占位符 | ✅（`generate-skill.sh --verify-completeness` 机器执法） | — |
| 自举 | ✅（CI generator-self-gate 三档 RC=0） | FACT_BOOTSTRAP_GATES=3 |
| 上下文表面瘦身（字节代理，非 token） | 193226B/2144L → 156992B/1856L（−18.8% / −13.4%，WP-P0~P6；模型 token 削减未测量） | FACT_CONTEXT_SURFACE_PRE_OPT=193226 |

---

## License

MIT

---

> AI 的代码生成能力已经很强，但「项目认知」还停留在零。swarm-yuan 用 17 项特征卡让 AI 先懂你的项目，用 54 个质量门禁守护代码合规——特征卡是立法，门禁是执法，验证器是司法。
