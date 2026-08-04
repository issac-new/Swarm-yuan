# swarm-yuan — 让 AI 懂你的项目，再写代码

> 从「AI 辅助写代码」到「AI 懂项目再写代码」的认知基础设施。
>
> 17 项特征卡让 AI 认识你的项目，54 个质量门禁守护代码合规——特征卡是立法，门禁是执法。

[![Release](https://img.shields.io/badge/release-v2026.08.04-blue)](https://github.com/issac-new/Swarm-yuan/releases/tag/v2026.08.04)
[![Feature Card](https://img.shields.io/badge/feature%20card-17-green)]()
[![Quality Gates](https://img.shields.io/badge/quality%20gates-54-orange)]()
[![Frameworks](https://img.shields.io/badge/frameworks-74-blueviolet)]()
[![Runtimes](https://img.shields.io/badge/runtimes-13-yellow)]()
[![License](https://img.shields.io/badge/license-MIT-lightgrey)]()

> **口径权威源**：`swarm-yuan/assets/facts.conf`——所有 catchphrase 数字的单一事实源，`scripts/self-check.sh` 机器执法做漂移检测。本 README 每一个数字都可被 `facts.conf` + 机械计数复现。

---

## 为什么需要它

**痛点 1：AI 不知道你的项目规则。** 改了不该改的文件、升级了不该升级的依赖、重复造了已有组件的轮子。

**痛点 2：AI 不懂你的领域。** 密码必须哈希、SQL 必须参数化、消息有时序性——违反就是硬伤。

**痛点 3：检查靠人工。** 没有自动化检查就没有信任，只能逐行 review。

**核心论断：AI 的代码生成能力已经很强，但「项目认知」仍是被多数工具忽视的环节。** 同行产品（spec-kit 12 万星、BMAD-METHOD 5 万星、SuperClaude 2.3 万星）解决了 spec 生成或 prompt 工程，但「质量门禁的规模化强制」在我们调研的上述 4 个同行中未见脚本化门禁 + 独立验证器的强制闭环——swarm-yuan 用 54 门禁 + 状态机 + 验证器试图补上这一段。本判断受样本规模限制（4 个同行 + 1 份 gist 交叉分析，2026-07-20 实测），非全行业普查结论。

---

## 关键设计理念

| 理念 | 含义 |
|------|------|
| 先认识，再行动 | AI 写代码前必须先认识项目。17 项特征卡完成认知，54 个门禁守护行动 |
| 拼装式开发 | 新功能 = 既有稳定单元拼装 + 最小新增胶水代码。禁止重复造轮子/侵入式重构/破坏性改造 |
| 呈现递进的关系 | 门禁不是"数 import 数"——每个计数背后指向一条关系规律 |
| 特征卡是立法，门禁是执法，验证器是司法 | 17 项特征卡定义「项目应该是什么样的」，54 个门禁验证「代码是否符合」，`verifier/v1` 用 fixture 双态 + cli A/B 字节级等价做独立司法 |
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
| 11 | **可复用稳定单元** | 全部稳定 API/组件/类/函数/store/类型（五维字段定义见 `swarm-yuan/references/exploration-guide.md` §11f） | **`--reuse` + `--stable-diff` + `--state` + `--frontend`** |
| 12 | 数据规范 | schema/样例/业务规则/勾稽 | `--consistency` |
| 13 | 认知基底 | 认知映射表 + 六维动力学基线 | `--cognition` |
| 14 | **领域知识** | 技术+业务领域 → 推导客观规律 | `--domain` |
| 15 | **编排调用关系及约束** | 导入方向/注册顺序/路由挂载/状态所有权/测试边界 | `--layer` `--frontend` |
| 16 | **详尽构件库清单（全量）** | 全量构件表 + 接口端点表 + store/类型表（清单计数核验） | reference-manual §4/§6/§9 |
| 17 | 合规与质量基线 | 强监管关键词/合规门禁开关/质量门禁开关 | `--compliance-suite` profile 升档 |

**第 11 项是核心中的核心**——AI 用 graphify `query` / gitnexus `context` 系统性盘点全部稳定单元（GitNexus（PolyForm Noncommercial 禁商用）降级为非默认，graphify（MIT）提为默认代码图谱工具，决策见 `docs/upstream-baseline.md`），每个记录五维字段（定义见 `swarm-yuan/references/exploration-guide.md` §11f，详解见 `swarm-yuan/docs/FIVE_DIMENSIONS.md`）。

**特征卡驱动一切：** → 文件填充（SKILL.md 铁律 ← 第 2/6 项、codebase.md ← 第 4 项、reference-manual.md 组件库 ← 第 11 项）→ 门禁配置（precheck.conf 三件套 171 个变量从特征卡推导，懒生成机制按 ACTIVE_FRAMEWORKS 自动补占位）→ 开发流程（开始新需求时从第 11 项检索可复用单元）。

### 落地示例（SwarmStudio overlay）

| # | 真实值 |
|---|--------|
| 1 | overlay 注入式二次开发（Vue 3 + Electron） |
| 2 | 可改: overlay/；只读: upstream/（严格禁止） |
| 3 | A类（custom/ 纯新增）+ B类（patches/ 骨架修改） |
| 5 | `npm run dev`(:8649) / `npm test` / `npm run inject` |
| 11 | CockpitWorkspace / CockpitKanban / GatewayNoticeBanner 等 15+ 组件 |
| 14 | IM 通讯（Matrix 协议）+ DevOps 监控 |

### 落地示例（强监管交付 · 关节编排汇报）

> 真实汇报场景：《AI 赋能研发工作的系统方案》——以「关节编排（Articulated Orchestration）」为核心方法论，面向公司技术总裁，清算核心系统交付（资金 0 容错 · 强监管 · 变更可追溯）。swarm-yuan 的抽象能力在此场景中被映射为一套可对外讲述的工程叙事，每个论点都有机器执法机制兜底「凭什么可信」。

核心映射（完整版见 [`swarm-yuan/references/case-studies/articulation-orchestration.md`](swarm-yuan/references/case-studies/articulation-orchestration.md)）：

- **关节** ≈ 特征卡第 11 项「可复用稳定单元」五维字段 + `inventory-verify.sh` 计数核验
- **编排约束** ≈ 调用链路分析 §C+.2 形态自适应 + §C+.3 每条约束附代码证据
- **安检** ≈ 54 门禁三档 enforce（strict 16 / warn 23 / advisory 15）+ verifier 司法独立验证
- **左移** ≈ spec §19 测试设计 + §20 变更影响 + §21 可观测性 + `--shift-left` 门禁
- **审计可追溯** ≈ `trace-log.sh` → `trace.jsonl` + `decisions.jsonl`（ISO/IEC 42001 人工监督留痕）

> **关键纠偏**：汇报中的「10⁻¹⁰ 失效概率」是使用方基于分层防御的推演模型，**非 swarm-yuan 仓库直接输出**；「103 组件」是目标项目枚举产物非 skill 硬数字。详见案例文档的「关键纠偏」段。

---

## 54 个质量门禁：特征卡的守卫者

**特征卡是立法，门禁是执法。**[^separation] 特征卡定义规则，门禁验证合规。

[^separation]: **三权分立隐喻的教学性边界**：本隐喻为教学类比，非政治学严格对应。门禁不具备法律的普遍约束力（仅作用于本项目，非社会规范）；verifier/v1 与被验证者同处一个 git 仓库与 CI，不具备司法的独立裁量权与终局性（其"独立"指验收脚本是独立子目录、不与门禁共享逻辑，而非机构独立）。隐喻用于帮助理解"定义规则-执行检查-独立验收"三组件分工，不构成对组件性质的经验断言。

> **门禁分层（决策 19）——执法强度横切维度：** 54 门禁按 `fail()` 能力分三档，与 core/standard/compliance 执行序列正交：
> - **strict（16 个）**：≥3 个 fail 调用，真正阻断交付的硬门禁（branch/layer/reuse/security/shift-left/compliance/sbom/dengbao/pia/test-evidence/review-record/release-sign/quality-model/sast-deep/oss-eval）
> - **warn（23 个）**：1-2 个 fail，混合 warn，能 fail 但触发条件窄（privacy/authz/requirements/rtm/crypto/contract/impact/service/api/review/frontend/domain/knowledge 等）
> - **advisory（15 个）**：0 个 fail，永不阻断，只 warn/pass（cognition/consistency/consistency-cross/link-depth/state/mermaid/operate/decision-audit/learnings/state-phase/upstream-baseline/pr-quality/skill-supply-chain/cwe-audit/cert-audit）
>
> 查看分层：`bash scripts/precheck.sh --list-gates`。advisory 门禁在子 shell 内重定义 fail/warn 为纯 echo，永不进计数——"advisory 是观测类，不阻断交付"语义机器化。分层由 `scripts/gen-enforce-level.sh` 自动按 fail() 数归类（幂等），手动覆盖见 precheck.sh `_ENFORCE_OVERRIDE`。

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
| `--mermaid` | Mermaid 可视化（架构图/流程图/调用链） | — |
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

7 个行业各一份 `.md`（法规依据）+ `.conf`（门禁映射）对，按需 `cat assets/industry-profiles/<行业>.conf >> <目标技能>/scripts/precheck.conf` 后 `precheck.sh --doctor` 自检为 0 fail 即接入：

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

## 五层认知基底

| 层 | 解决什么 | 与特征卡/门禁的关系 |
|----|---------|-------------------|
| 认知递进 | 如何认识项目（六阶：概念→结构→空间→映射→规律→处理 + 六维动力学） | 特征卡 17 项 = 认知递进的产物 |
| 思维语言 | 如何思考（三元+三导向+七推理+7×7 双循环） | spec §14-§18 = 思维语言落地 |
| 认知辩证 | 如何推演+自证伪（logic-razor 六步） | `--cognition` = 验证工具 |
| 偏差防范 | 如何纠偏（5 维偏差 + 8 心智模型） | spec §16 偏差自检 |
| 辩证认知 | 如何统一前四层（7 对辩证对 + ECC 四声部议事会） | `--domain` = 违规检测 |

> 详见 `swarm-yuan/references/cognition-framework.md`。
> ⚠️ "五层认知基底"与"`--cognition` 门禁得分 ≥15/19 = 认知完整"是**工程启发式评分**，非心理测量学构念--未经信度/效度检验，分数仅用于自检"是否覆盖五层话题"，不构成对 AI 认知能力的测量。五层认知文档全文无学术引用（见 `docs/research/R3-methodology.md` §2.1 自承），R3:178 建议两条出路：补学术出处页（图尔敏 1958 / Minto 1987 / Kruger-Dunning 1999 / Tversky-Kahneman 1974 / 《实践论》《矛盾论》），或维持"工程启发式框架"显式降级声明。本仓库当前采用后者。

---

## 13 个运行时 + 32 个领域

**运行时**（只引用调用不重新实现，按接线深度分三层；`docs/upstream-baseline.md` 登记 13 个运行时的仓库/许可证/基线版本/drift 状态）：

| 层 | 运行时 | 接线方式 |
|----|--------|---------|
| 深度接线（4） | GitNexus / graphify / claude-mem / ocr | precheck.sh 门禁内真实子进程调用 + 多级降级链 |
| CLI 接线（3） | OpenSpec / comet / gsd-core | 门禁/状态机按需调用 CLI（`openspec validate`/`comet guard`/`gsd-tools validate health`）+ 降级到自带载体 |
| 方法论引用（5） | superpowers / gstack / Ruflo / ECC / impeccable | AI 按 workflow 节点引用其模式，swarm-yuan 自带等价降级载体 |

每层有自带降级载体，未装运行时时不阻塞（fail-open + 降级），不假装全深度接线。`--upstream-baseline` 门禁（advisory）自动检测 upstream drift，CI 可见但不阻断构建。

**领域知识**：数据库 ACID / 网络 CORS / 安全密码哈希 / IM 消息保序 / 电商库存原子扣减 / 金融金额 Decimal……32 个领域客观规律（详见 `swarm-yuan/references/domain-knowledge.md`）。

---

## AI 工具兼容三档（诚实分层，不假装全深度接线）

与 13 个运行时的三层接线范式平行——7 个 AI 工具的兼容深度同样分档声明：

| 档 | 名称 | 能力 | 工具 |
|---|------|------|------|
| runnable | 可运行 | 目录复制（该工具自身对 skills 目录的加载约定） | 全部 7 个 |
| cli | 集成 | runnable + `--render-tools` 派生原生规则文件（.mdc/.windsurf/AGENTS.md/GEMINI.md 标记区块） | Cursor/Windsurf/Codex/OpenCode/Gemini/Kimi（6 个） |
| deep | 深度集成 | cli + slash command 注册 + hooks/commands/MCP（hooks.json/.mcp.json/commands/*.md 随骨架生成） | Claude Code（1 个） |

> 非 Claude 工具安装的骨架中 hooks/commands 目录为 deep 档（Claude Code）专属，cli 档不消费（死重，不影响功能）。设 `SWARM_YUAN_SLIM=1` 可在安装时裁剪这些死重（opt-in，默认保留不影响既有用户）。
> 档位元数据机器可读：`assets/tool-adapters/common.sh` 的 `TA_TIER_<tool>` 声明，self-check 对账 facts.conf 口径。

---

## Claude Code 深度集成

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

**自举：** swarm-yuan 能用自身的 54 个门禁检查自身（CI `generator-self-gate` job 三档 `--all`/`--all-full`/`--compliance-suite` RC=0）。

**自举证明的边界**：自举只证明"门禁规则与自身代码一致"（内部自洽），**不证明**"门禁能拦截真实缺陷"（外部有效）。后者由 `verifier/v1` 的 C1 行为等价与 `docs/research/R9-paradigm-realworld-test.md` 的真实项目测试覆盖--R9 已诚实披露 5 个真实项目中 fixture 套件漏掉 3 个 P0/P1 bug（fixture 用构造的最小样例，与真实项目有差距）。外部有效性的进一步证据见 `verifier/v2/external-validity.md`（立项稿）。

---

## 设计与决策弧线（v2026.07.04 → v2026.08.04）

swarm-yuan 不是一次性写出来的，是 21 天、14 个 release tag、9 份研究交付物、20+ 个 WP 工作包迭代出来的。完整决策见 `docs/paradigm-decisions.md`（决策 18-31，1-17 见 paradigm-decisions-archive.md）+ `docs/` 下 dated 设计文档。

### 范式转折点

| 时间 | 转折 | 决策依据 |
|------|------|---------|
| 2026-07-17 | 框架规则引擎立项（六段式模板 + 四要素量化验收） | `docs/2026-07-17-framework-rules-engine-design.md` |
| 2026-07-20 | 不 vendor superpowers v6.1.1（44MB/10 子许可证/在线安装才是 canonical）→ 改用 upstream-baseline 登记+drift 检测 | `docs/2026-07-20-upstream-vendor-decision.md` |
| 2026-07-20 | GitNexus（PolyForm Noncommercial 禁商用）降级为非默认 → graphify（MIT）提为默认代码图谱工具 | `docs/upstream-baseline.md` |
| 2026-07-20 | 决策 13：废止"断点续传违背零占位符铁律"否决 → 以 draft/active 状态门替代（WP-H） | 决策 13 |
| 2026-07-21 | 决策 18/25：`--profile auto` 默认 + "重量是设计选择不是缺陷"（WP-P10 范式定位） | `docs/paradigm-positioning.md` |
| 2026-07-22 | R9 真实项目测试（5 个 GitHub 项目）暴露 fixture 测试不可替代的 3 个 P0/P1 bug → fixture + 真实项目双轨制 | `docs/research/R9-paradigm-realworld-test.md` |
| 2026-07-23 | WP-P0~P6 生成管线工具化：上下文表面字节 193226B → 156992B（−18.8%，字节级代理；模型 token 削减未测量） | `verifier/baselines/post-opt/comparison-report.md` |
| 2026-07-24 | WP-X/WP-Y 方法论门禁化完结：+graphify God Nodes / +state-phase / +upstream-baseline drift / +pr-quality / +skill-supply-chain / canary 可配阈值 → 54 门禁 | `verifier/runs/README.md` |
| 2026-07-27 | 全面审计修复三连：术语统一 + 结构逻辑补全 + CI 红修复 + 数字漂移 + 标准失实 + 自检盲区（wp-full-audit / wp-audit-residual / wp-conf-syntax-guard / wp-audit-2026-07-27） | `docs/` dated 修复记录 |
| 2026-07-28 | 治理与回路 WP 批次：+governance-agents 四权分离拓扑 / +failure-detector PostToolUse(Bash) 失败模式检测 / +integrity-guard PreToolUse 防作弊门 / +loop-oracle Oracle Gate 循环 hook / +compaction-state compaction 状态续传 / +task-router 任务类型×方法论路由表 / +z19-learnings check_learnings 置信度反哺 / +g55-loop-oracle 门禁化兜底（决策 26.1：check_canary → check_loop_oracle 等价替换）/ 吸收 impeccable v4.0.2 作为方法论引用层第 5 对象 | `verifier/runs/README.md` |
| 2026-07-29 | 吸收上下文工程分层方法论（Vibe编码《Opus 4.8 删掉了73%的提示词，Opus 5 为何又新增了 82%》）：六层上下文模型（模型/System/Tools/CLAUDE.md/Skills/Memory/Hooks）↔ swarm-yuan 既有载体接线 + minimal≠short + Prompt=model adapter + Delivering work/Corrections 治理内核；G14 warn-only 断言；非运行时纯方法论吸收（FACT_REFERENCES 32→33，不进 12/5） | `swarm-yuan/references/context-engineering-layering.md` |
| 2026-07-30 | 吸收 openai/codex-security CLI 接线层第 4 对象：**AI 约束推理扫描（非传统 SAST——OpenAI 官方明确「不包含 SAST 报告」，采用约束推理 + 攻击路径验证而非模式匹配 + 降级链）** + source→sink 数据流 + 静态评估七元组 + 威胁模型五要素 + SECURITY.md 策略合并 + scan contract 三件套 + 14 bundled skills + Docker 沙箱范式；`--sast-deep` 门禁 `SAST_DEEP_TOOL=codex-security` 时显式调用，**非降级链一环（非 SAST，auto 降级链不变，两者正交可并行）**；开源 Apache-2.0，Trusted Access 非付费门槛，API 按 token 计费；G15 warn-only 断言；CLI 接线层 3→4 / 运行时 12→13 / 参考文档 33→34（fde-backprop 删除后 35→34） | `swarm-yuan/references/codex-security-methodology.md` |
| 2026-07-31 | 反思修复批次（WP-reflection-fixup，对照 10 个上下文工程问题审计生成器自身）：WP-A 口径数字单源——self-check 扫描扩 SKILL.md+references 全量 + 补 runtimes/domains/cognition 三类 catchphrase 扫描 + 修 12→13 运行时漂移（facts.conf FACT_COGNITION_LAYERS=5）；WP-B 生成产物 e2e 回归——run-gen-e2e.sh 断言骨架/workflow/conf 嗅探 + 挂进 verifier，附带修 create 路径解析 + BUILD_CMD 未引号两个潜伏 bug；WP-C spec 节按任务类型机械校验——模板头部表层化矩阵 + --reuse --task-type 验证豁免落实；WP-D advisory 轴混淆修正——SKILL.md 删长注释辨析 + --list-gates 归并轴（explicit-flag-only） | `verifier/runs/README.md` |
| 2026-08-03 | 文档口径漂移修复 + LOC 守护（fix/doc-drift-and-loc-governance，12 项）：SKILL.md 结构塌陷修复（孤儿表格行+重复标题）/ README CLI 层（3）→（4）补 codex-security / USAGE enforce 表 strict 20→16·warn 19→23·canary→loop-oracle / PROMO 运行时名 ocr / CLAUDE.md 瘦身去重（删 11 runtimes·~4000 lines·28 docs·20k+22k，消除与同文件内部矛盾）/ self-check 运行时正则补 `(external )?runtimes` 容错（根因修复）/ facts.conf +FACT_SCRIPT_LOC + self-check LOC warn-only 守护 + README 删 4 处写死行数（根除漂移源）/ research 幽灵路径措辞修正 + 浅克隆建议 | `verifier/runs/README.md` |
| 2026-08-04 | **四轮复盘：从「内部一致性」到「外部可用性」**（v2026.08.04 发版含 5 批次）。① 可视化门禁双引擎（feat/diagram）：check_mermaid→check_diagram，结构关系图用 mermaid（GitHub 原生渲染）+ 数据统计图用 echarts/antv option JSON，按内容选恰当图表；`--mermaid` 保留别名。② verifier 名实修复（fix/verifier-honesty）：golden-vector **内容比对首次自动化**（此前只对账行数，CLAUDE.md 描述的比对行为并不存在）+ rebuild-golden 模式 / gen-e2e Step 8 假断言（`\|\| true` 吞退出码后无条件 ok）/ fixtures/e2e 进 all 投票 + gen_e2e 死票修复（函数末尾 echo 恒返回 0）/ generate-skill.sh 加 Windows 路径转换。③ self-check 既有项清理（fix/self-check）：strict/warn 正则加尾随约束 `([^0-9→]\|$)` 止误伤历史叙事 / 源码包 tag 降级（当天 -src 未打时 ls-remote 取最近可用，不再让终端用户吃 FAIL）。④ 脚本注释漂移守（fix/script-comment）：**catchphrase 执法边界从 .md 扩到 .sh 头部注释**（新增 check_gates_header_comment，反向验证通过）+ 删死配置 FACT_MEASURE_METADATA_COVERED + 三个 warn-only 开关注明推进条件防僵尸化。⑤ **lite 档生成失败 P0 bug**（fix/lite-profile）：`chmod +x assets/*.sh` 在 lite 档 glob 无匹配 → set -e 中断 → 小项目（auto→lite）按默认命令生成必残缺；改 find -exec 容错 + 补 lite/compliance 档 e2e 回归（反向验证能捕获原 bug）+ 7 处性能声称按实测修正（--all 声称 ~5s 实测 12-16s）| `verifier/runs/README.md` |

### 9 份研究交付物（R1-R9，2026-07-20~22）

| ID | 角色 | 关键结论 |
|----|------|---------|
| R1 | 自身设计理念 | 7 设计哲学 + 8 gap（G1-G8），立法-执法链断裂点定位 |
| R2 | 门禁引擎 | 27 门禁解剖，21/27 硬 fail，6/27 永不 fail；对照 GB/T 34943/34944/34946 + ISO/IEC 5055 的 8 个结构 gap |
| R3 | 方法论体系 | 14 参考文档分析；五层认知 0 学术引用；spec↔特征卡缺显式 RTM |
| R4 | 框架规则库 | 58 triplets / 676 子门禁（fail 一二四/warn 五五二，R4 研究时点快照）；fail-fixture 覆盖 71%；spring-boot 3 沉睡门禁实证 |
| R5 | 上游组件(本地) | gstack + superpowers marketplace 分析；offline-cache/superpowers 是 marketplace 目录非核心插件 |
| R6 | 上游组件(网络) | 9 运行时 + 同行产品（spec-kit/BMAD/SuperClaude/Kiro）；"质量门禁规模化强制在 4 个同行中未见强制闭环"（非全行业普查） |
| R7 | 质量标准 | 12 标准族 / Q-01~Q-22 映射；"文档集+测试证据链+可追溯矩阵三位一体" |
| R8 | 安全标准 | 6 层 / 12 族 / 35 行映射；推荐 6 新安全门禁族；fail-closed 强制（衡山医院 5 万元罚款执法案例） |
| R9 | 真实项目测试 | 5 项目暴露 3 个 fixture 测不出的 P0/P1 bug；druid 框架新增；74/74 fixture 回归绿 |

### WP 工作包谱系（摘）

- **WP-A~M**（2026-07-21 范式瘦身，时点快照）：合规九门禁拆分 `--compliance-suite` / check_cognition 诚实化 / 三档 profile / draft 状态门 / precheck.conf 三件套物理拆分 / Windows CI 降频 / 全局一致性收口
- **WP-P0~P6**（2026-07-23 生成管线工具化，SDD/TDD）：context-surface 计量基线 → 信号索引外化 → 库存核验 → 框架证据台账 → conf 渲染三件套 → context 瘦身 → 对比报告
- **WP-Q1~Q4**（2026-07-21 自适应瘦身）：门禁分层 strict/warn/advisory + precheck.sh 三文件拆分 / profile 偏向修正 / 项目级信号 / 任务级机器判断
- **WP-R**（2026-07-22 真实项目测试）：SIGPIPE 崩溃 + `[[ -f ]]&&source` set-e + detect-frameworks 4 缺陷修复 + druid 新增
- **WP-S1/S2**（2026-07-23 安全/质量门禁）：+4 安全（dengbao/pia/sast-deep/oss-eval）+4 质量（quality-model/test-evidence/review-record/metrics）+ SARIF 2.1.0 + 特征卡 17
- **WP-T**（2026-07-23 CWE 回填）：quartz CWE×4 + advisory 映射×4 + P0 批框架 CWE×46 → standards-map 21→75
- **WP-W**（2026-07-23 框架扩充）：+4 框架（android/ios-swiftui/dotnet/c-cpp）→ 74 框架
- **WP-X**（2026-07-24 方法论门禁化）：+graphify God Nodes in check_impact + check_state_phase + check_upstream_baseline → 52 门禁
- **WP-Y**（2026-07-24 终审）：+check_pr_quality + check_skill_supply_chain + canary 可配阈值 + upstream 自动化 drift → 54 门禁

---

## 验证器（司法独立）

`verifier/v1/` 用 8 条验收准则（C1-C8）做独立司法，不靠"看起来能跑"做完成判据：

| 准则 | 检查什么 | 机制 |
|------|---------|------|
| C1 | 行为等价（最高优先） | 74 framework fixture 的 violating→FAIL / compliant→PASS 逐一相同；exit-code + id-level assert 计数等 |
| C2 | E2E | `tests/e2e/run-e2e.sh` RC=0（Java 4 框架注入 + 4 fail id） |
| C3 | 重复消除 | precheck.sh 双副本 diff（vs Swarm-studio 兄弟仓库，ABSENT 则 informational） |
| C4 | Shellcheck 不恶化 | 核心脚本 error 级 ≤ baseline |
| C5 | CLI 兼容 | 54 flag × 2 corpus × A/B stdout 字节级相同 + exit-code 相同；`--all` core-10 header 序列 vs `core10-sequence.txt` |
| C6 | 可维护性 | LOC 增长 <40% vs baseline；framework-gates 注入双副本 diff <30；self-check 文档一致性段无 ✗/FAIL |
| C7 | 交付物 | 《全面分析与重构报告》 |
| C8 | 合规门禁 fixture | 全量 48 gate-fixture 组双态 + id-level assert；`GATE_FIXTURES_FAILS 0` |

验收记录见 `verifier/runs/`（逐轮时间戳日志）；当前口径：**fixtures 74/74 | gate-fixtures 48/48 | cli-ab DIFFS 0 | 54 门禁 / advisory 15**（wp-y-final 日志的 45 组/advisory=16（旧）为该轮时点真值，Z3 后 advisory=15）。

```bash
bash verifier/v1/run-verifier.sh all     # 全量验收（fixtures + gate-fixtures + e2e + shellcheck + metrics + cli-ab）
```

---

## 仓库结构

```
Swarm-yuan/
├── README.md                     ← 本文件
├── CLAUDE.md                     ← AI 协作指令（仓库工作约定）
├── LICENSE                       ← MIT
├── docs/                         ← 设计文档 + 计划 + 研究交付物
│   ├── paradigm-decisions.md     ← 决策 18-31（1-17 见 paradigm-decisions-archive.md，口径权威源 facts.conf）
│   ├── paradigm-positioning.md   ← WP-P10 范式定位
│   ├── upstream-baseline.md      ← 13 运行时登记 + drift 处置
│   ├── 2026-07-17-framework-rules-engine-design.md
│   ├── 2026-07-20-audit-optimization-decisions.md
│   ├── 2026-07-20-upstream-vendor-decision.md
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
│   │   ├── precheck.conf         ← 核心配置变量（12 个）
│   │   ├── precheck.arch.conf    ← 架构配置变量（110 个，懒生成）
│   │   ├── precheck.compliance.conf ← 合规配置变量（48 个）
│   │   ├── facts.conf            ← 口径单一事实源（self-check 机器执法）
│   │   ├── gate-enforce-level.conf ← 自动生成的分层映射（gen-enforce-level.sh）
│   │   ├── standards-map.conf    ← 75 条目（21 门禁+50 框架+4 advisory，SARIF 元数据源）
│   │   ├── framework-signals.md  ← 74 框架信号索引（gen-framework-index.sh 生成）
│   │   ├── framework-gates/      ← 74 个 .sh（与 frameworks/*.md 1:1）
│   │   ├── industry-profiles/    ← 7 行业 .conf
│   │   ├── spec-template.md      ← 23 主段 spec 模板（§23=发布后运营）
│   │   └── trace-log.sh          ← 全链路调用追踪（stdout 公告 + trace.jsonl 落盘）
│   ├── docs/                     ← USAGE/PROMO/FIVE_DIMENSIONS 唯一来源
│   ├── references/               ← 35 个参考文档 + frameworks/（74 框架 + _template）
│   ├── scripts/                  ← 23 个脚本（生成器+自检+SARIF+drift+baseline+cost）
│   ├── tests/                    ← fixture 测试（e2e + 74 framework fixture + 48 gate-fixture + sarif-fixture）
│   └── ci/                       ← 自举 self-precheck.conf
├── verifier/                     ← 独立验收（C1-C8）
│   ├── v1/                       ← run-verifier.sh + cli-ab-test.sh + golden-vector.txt + metrics-baseline.txt
│   ├── baselines/                ← pre-opt / post-opt 上下文表面基线 + comparison-report.md
│   └── runs/                     ← 20 个 timestamped 日志 + README 账本（WP 进度）
└── tests/                        ← 跨层级测试 fixtures
```

> **生成的目标技能含**：SKILL.md / references/*.md / assets/* / scripts/(precheck.sh+gates-strict/warn/advisory.sh+gate-enforce-level.conf+precheck.conf 三件套+state-machine.sh+trace-log.sh+memory-writeback.sh+self-check.sh+detect-frameworks.sh+detect-profile-drift.sh+detect-spec-scale.sh+task-scale.sh+cost-report.sh+snippets.md+mcp-tools.md) / hooks/hooks.json / commands/(spec+precheck+explore) / settings.local.json / .mcp.json / .swarm-yuan-version（以 generate-skill.sh UNIVERSAL_FILES 38 条为真值；generate-skill.sh 本身不拷入目标技能）

---

## 数字一览

| 维度 | 数值 | 口径源 |
|------|------|--------|
| **特征卡** | **17 项**（P0 六项 1/4/5/11/15/16 + P1 十一项） | FACT_FEATURE_CARDS=17 |
| **质量门禁** | **54 个** = strict 16 + warn 23 + advisory 15（执法强度横切）；执行序列 --all 核心 10 / --all-full 标准 27 / --compliance-suite 合规 17 / advisory-only 10 不在任何执行序列 | FACT_GATES_TOTAL=54 |
| **配置变量** | **171 个**（precheck.conf 12 + precheck.arch.conf 111 + precheck.compliance.conf 48，懒生成按 ACTIVE_FRAMEWORKS 补占位） | FACT_CONF_VARS=171 |
| **框架规则集** | **74 个**（references/frameworks/*.md 1:1 配 assets/framework-gates/*.sh，六段式 + 四要素量化验收） | FACT_FRAMEWORKS=74 |
| **参考文档** | 35 个（references/*.md 不含 frameworks/ 子目录） | FACT_REFERENCES=35 |
| **standards-map** | 75 条目（21 门禁级 + 50 框架级 + 4 advisory） | FACT_STANDARDS_MAP_ENTRIES=75 |
| 运行时工具 | 13（深度 4 + CLI 4 + 方法论 5） | FACT_RUNTIMES=13 |
| spec 模板 | 23 主段（§23=发布后运营） | FACT_SPEC_SECTIONS=23 |
| 领域知识 | 32 个领域 | FACT_DOMAINS=32 |
| 认知基底 | 5 层 | — |
| 行业 profile | 7（金融/医疗/政务/汽车/能源/工业/通信） | — |
| profile 档位 | 4（auto/lite/standard/compliance） | FACT_PROFILES=4 |
| 兼容 AI 工具 | 7（三档：runnable 7 / cli 6 / deep 1） | FACT_COMPAT_*=7/6/1 |
| CWE 条目 | 60 | FACT_CWE_ENTRIES=60 |
| 安全认证 profile | 6（等保4级/BCP5级/GB22240/PCI-DSS/ISO27001/…） | FACT_CERT_PROFILES=6 |
| 生成流程 | 13 节点 / 8 工作流节点 | FACT_FLOW_STEPS=13 / FACT_FLOW_NODES=8 |
| 决策治理类型 | 3（Mechanical / Taste / UserChallenge，对齐 ISO/IEC 42001） | FACT_DECISION_TYPES=3 |
| 三平台 | macOS / Linux / Windows（CI 11 job 全覆盖：ubuntu-latest + macos-latest + windows-latest） | — |
| 零占位符 | ✅（`generate-skill.sh --verify-completeness` 机器执法） | — |
| 自举 | ✅（CI generator-self-gate 三档 RC=0） | FACT_BOOTSTRAP_GATES=3 |
| 上下文表面瘦身（字节代理，非 token） | 193226B/2144L → 156992B/1856L（−18.8% / −13.4%，WP-P0~P6；模型 token 削减未测量） | FACT_CONTEXT_SURFACE_PRE_OPT=193226 |

---

## License

MIT

---

> AI 的代码生成能力已经很强，但「项目认知」还停留在零。swarm-yuan 用 17 项特征卡让 AI 先懂你的项目，用 54 个质量门禁守护代码合规——特征卡是立法，门禁是执法，验证器是司法。
