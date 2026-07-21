# swarm-yuan — 让 AI 懂你的项目，再写代码

> 从「AI 辅助写代码」到「AI 懂项目再写代码」的认知基础设施。
>
> 16 项特征卡让 AI 认识你的项目，36 个质量门禁守护代码合规——特征卡是立法，门禁是执法。

[![Release](https://img.shields.io/badge/release-v2026.07.19-blue)](https://github.com/issac-new/Swarm-yuan/releases/tag/v2026.07.19)
[![Feature Card](https://img.shields.io/badge/feature%20card-16-green)]()
[![Quality Gates](https://img.shields.io/badge/quality%20gates-36-orange)]()
[![Runtimes](https://img.shields.io/badge/runtimes-11-yellow)]()
[![License](https://img.shields.io/badge/license-MIT-lightgrey)]()

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
| 先认识，再行动 | AI 写代码前必须先认识项目。16 项特征卡完成认知，36 个门禁守护行动 |
| 拼装式开发 | 新功能 = 既有稳定单元拼装 + 最小新增胶水代码。禁止重复造轮子/侵入式重构/破坏性改造 |
| 呈现递进的关系 | 门禁不是"数 import 数"——每个计数背后指向一条关系规律 |
| 特征卡是立法，门禁是执法 | 16 项特征卡定义「项目应该是什么样的」，36 个门禁验证「代码是否符合」 |
| 分层整合，诚实降级 | 11 运行时按深度/CLI/方法论三层整合，每层有自带降级载体，未装不阻塞，不假装全深接 |

---

## 16 项特征卡：项目的「认知 DNA」

AI 探查项目后提取 16 项特征，每项落到真实路径和版本号，不用占位符。特征卡不是独立文件，而是**分散承接进目标 skill 的各个文件中**，驱动门禁配置和文件填充。

| # | 特征项 | AI 提取什么 | 驱动什么 |
|---|--------|-----------|---------|
| 1 | 项目类型 | 单体/monorepo/overlay-fork/微服务 | SKILL.md 定位 + `--cognition` |
| 2 | **可改范围** | 可改目录 + 只读目录 + 只读区修改机制 | 安全铁律 + `--scope` |
| 3 | **改造分类** | A类(纯新增)/B类(骨架修改) | dev-guide + `--layer` |
| 4 | 技术栈 | 语言+框架+构建+测试（含版本基线） | codebase.md + `--deps` |
| 5 | **构建命令** | dev/build/test/release 真实命令 | `--build` `--test` |
| 6 | 分支规范 | 命名/合入/保护分支/推送 | `--branch` |
| 7 | 安全规则 | 脱敏/密钥/白名单 | `--sensitive` `--security` |
| 8 | 文档约定 | spec/plan 位置和命名 | workflow + spec-template |
| 9 | 测试体系 | 框架/目录/命令 | `--test` |
| 10 | 环境资源 | 运行时/DB/缓存/MQ/MCP | `--service` |
| 11 | **可复用稳定单元** | 全部稳定 API/组件/类/函数/store/类型（签名+路径+用途+复用方式+稳定性标注） | **`--reuse` + `--stable-diff` + `--state` + `--frontend`** |
| 12 | 数据规范 | schema/样例/业务规则/勾稽 | `--consistency` |
| 13 | 认知基底 | 认知映射表 + 六维动力学基线 | `--cognition` |
| 14 | **领域知识** | 技术+业务领域 → 推导客观规律 | `--domain` |
| 15 | **编排调用关系及约束** | 导入方向/注册顺序/路由挂载/状态所有权/测试边界 | `--layer` `--frontend` |
| 16 | **详尽构件库清单（全量）** | 全量构件表 + 接口端点表 + store/类型表（清单计数核验） | reference-manual §4/§6/§9 |

**第 11 项是核心中的核心**——AI 用 graphify `query` / gitnexus `context` 系统性盘点全部稳定单元（GitNexus（PolyForm Noncommercial 禁商用）降级为非默认，graphify（MIT）提为默认代码图谱工具），每个记录签名、路径、用途、复用方式、稳定性标注。

**特征卡驱动一切：** → 文件填充（SKILL.md 铁律 ← 第 2/6 项、codebase.md ← 第 4 项、reference-manual.md 组件库 ← 第 11 项）→ 门禁配置（precheck.conf 179 个变量从特征卡推导）→ 开发流程（开始新需求时从第 11 项检索可复用单元）。

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

## 36 个质量门禁：特征卡的守卫者

**特征卡是立法，门禁是执法。** 特征卡定义规则，门禁验证合规。

| 特征卡项（立法） | 门禁（执法） |
|----------------|-------------|
| 第 2 项：可改范围 | `--scope` 检查 git diff 是否触碰只读目录 |
| 第 5 项：构建命令 | `--build` 运行此命令，非零 = fail |
| 第 6 项：分支规范 | `--branch` 校验分支名 |
| 第 7 项：安全规则 | `--sensitive` `--security` 扫描密钥 |
| 第 11 项：可复用单元 | `--reuse` 检测新增单元与既有重名 |
| 第 11 项：稳定层 | `--stable-diff` 检测稳定层被改未声明 |
| 第 14 项：领域知识 | `--domain` 检测密码明文存储等违规 |

### 核心门禁（`--all`，10 个，~5 秒）

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

### 架构门禁（`--all-full` 在核心 10 个之上新增 17 个，~30 秒，未配置则静默跳过）

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
| `--shift-left` | 左移检查（测试设计/变更影响/可观测性，防缺陷流入后段） | — |
| `--framework` | 框架适配门禁（按 ACTIVE_FRAMEWORKS 逐框架执行规则集） | 第 4 项 |

### 合规门禁（9 个，随 `--all-full` 执行，未配置则静默跳过）

| 门禁 | 检查什么 | 依据 |
|------|---------|------|
| `--compliance` | 标准合规矩阵核验（六锚点完整 + 零占位符 + spec §22 标准合规段） | `references/standards-compliance.md`（GB/T 25000.51/8566 映射矩阵） |
| `--docs-pack` | 文档包清单（rusp/gbt9386/gbt8567 profile 必备文档存在性 + TBD 扫描） | GB/T 8567/9386 文档包 |
| `--sbom` | SBOM 生成 + 许可证块名单扫描（syft→cdxgen→lockfile 降级链，启用后 fail-closed） | 供应链 SBOM/SLSA |
| `--privacy` | 个人信息扫描（身份证/手机号/银行卡内置模式 + 豁免留痕，启用后 fail-closed） | 个保法/GB/T 35273 |
| `--authz` | 授权类弱点扫描（缺鉴权注解/IDOR/CORS 放行带凭据，CWE-862/863/639/284） | OWASP ASVS / CWE-862 |
| `--requirements` | 需求质量检查（spec 无 TBD/待定 + REQ- 唯一编号，严格模式启用后 fail-closed） | ISO/IEC/IEEE 29148 |
| `--crypto` | 密码算法合规（profile=gm 密评：弱算法 MD5/SHA1/DES → fail，国密白名单 SM2/SM3/SM4） | GB/T 39786-2021 |
| `--rtm` | 需求追溯矩阵（spec REQ- 编号须在测试目录或追溯矩阵可追溯；RTM_MATRIX_REQUIRED=1 时矩阵缺失 fail-closed） | ISO/IEC/IEEE 29148 RTM |
| `--release-sign` | 发布签名与 provenance（产物须带 .sig/.asc/.att/.bundle 伴随签名；cosign verify-blob 验签 + SLSA provenance fail-closed） | SLSA Build L2 / SSDF PS.2 |

### 降级策略

每个门禁优先用运行时工具，无则降级：

```
graphify path/explain → gitnexus trace（仅非商用场景）→ madge → 纯转发统计
ocr review → ocr scan → AI 5 维度审查
claude-mem search → 文件检测
```

---

## 快速开始

### 安装

```bash
git clone https://github.com/issac-new/Swarm-yuan.git
cd Swarm-yuan/swarm-yuan
bash install.sh
```

自动检测 7 个 AI 工具：Claude Code / Codex / Cursor / Windsurf / OpenCode / Gemini CLI / Kimi

### 生成项目技能

对 AI 说："为 /path/to/my-project 生成 skill"

或用 slash 命令：`/swarm-yuan /path/to/my-project`

AI 自动执行 11 步流程（**不允许中途停在骨架阶段**）：

```
自检 → 读取项目知识 → 探查仓库 → 提取 16 项特征卡 → 创建骨架 → 填充全部文件（消除占位符）→ 配置 precheck.conf → 生成 hooks/commands → 运行 36 个门禁 → 写回记忆 → 脚本确认零占位符（`generate-skill.sh --verify-completeness`）
```

### 日常使用

```bash
# 提交前自检
bash .claude/skills/my-project-dev/scripts/precheck.sh --all         # 核心 10 门禁
bash .claude/skills/my-project-dev/scripts/precheck.sh --all-full    # 全部 36 门禁

# 单独跑某个门禁
bash .claude/skills/my-project-dev/scripts/precheck.sh --security
bash .claude/skills/my-project-dev/scripts/precheck.sh --reuse
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
| 认知递进 | 如何认识项目 | 特征卡 16 项 = 认知递进的产物 |
| 思维语言 | 如何思考 | spec §14-§18 = 思维语言落地 |
| 认知辩证 | 如何推演+自证伪 | `--cognition` = 验证工具 |
| 偏差防范 | 如何纠偏 | spec §16 偏差自检 |
| 辩证认知 | 如何统一前四层 | `--domain` = 违规检测 |

---

## 11 个运行时 + 32 个领域

**运行时**（只引用调用不重新实现，按接线深度分三层）：

| 层 | 运行时 | 接线方式 |
|----|--------|---------|
| 深度接线（4） | GitNexus / graphify / claude-mem / ocr | precheck.sh 门禁内真实子进程调用 + 多级降级链 |
| CLI 接线（3） | OpenSpec / comet / gsd-core | 门禁/状态机按需调用 CLI（`openspec validate`/`comet guard`/`gsd-tools validate health`）+ 降级到自带载体 |
| 方法论引用（4） | superpowers / gstack / Ruflo / ECC | AI 按 workflow 节点引用其模式，swarm-yuan 自带等价降级载体 |

每层有自带降级载体，未装运行时时不阻塞（fail-open + 降级），不假装全深接。

**领域知识**：数据库 ACID / 网络 CORS / 安全密码哈希 / IM 消息保序 / 电商库存原子扣减 / 金融金额 Decimal……32 个领域客观规律。

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

**零占位符：** AI 执行完整 11 步后由脚本机器执法（`bash scripts/generate-skill.sh --verify-completeness <skill_dir>`）——零残留才算完成。

**自举：** swarm-yuan 能用自身的 36 个门禁检查自身。一个连自己都检查不了的工具，凭什么检查你的项目？

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
├── README.md                     ← 本文件
├── .gitignore                    ← 含 offline-cache 治理说明（whl/tgz 为离线安装所需，故意跟踪勿删）
├── docs/                         ← 设计文档 + 计划（USAGE/PROMO/FIVE_DIMENSIONS 唯一来源在 swarm-yuan/docs/）
│   ├── 2026-07-17-framework-rules-engine-design.md
│   └── plans/
├── swarm-yuan/                   ← 生成器 skill
│   ├── SKILL.md                  ← AI 入口（136 行）
│   ├── install.sh                ← 一键安装（7 环境检测）
│   ├── assets/                   ← 模板 + 门禁 + 状态机
│   │   ├── precheck.sh           ← 36 个门禁（3600+ 行，随门禁扩展演进）
│   │   ├── precheck.conf         ← 179 个配置变量模板
│   │   └── spec-template.md      ← 22 主段 spec 模板（§22=标准合规）
│   ├── docs/                     ← USAGE/PROMO/FIVE_DIMENSIONS 唯一来源
│   ├── references/               ← 18 个参考文档
│   ├── scripts/                  ← 生成器 + 自检
│   └── tests/                    ← fixture 测试（conf 中 __REPO_ROOT__ 占位符运行时替换为仓库根，任意机器可跑）
```

---

## 数字一览

| 维度 | 数值 |
|------|------|
| **特征卡** | **16 项（驱动全部文件 + 179 个门禁变量 + 开发流程）** |
| **质量门禁** | **36 个（核心 10 + 架构 17 + 合规 9，特征卡立法 + 门禁执法）** |
| 运行时工具 | 11 |
| spec 模板 | 22 主段（§22=标准合规） |
| 领域知识 | 32 个领域 |
| 认知基底 | 5 层 |
| 兼容 AI 工具 | 7 个 |
| 三平台 | macOS / Linux / Windows（CI 全覆盖：ubuntu-latest + macos-latest + windows-latest） |
| 零占位符 | ✅ |
| 自举 | ✅ |

---

## License

MIT

---

> AI 的代码生成能力已经很强，但「项目认知」还停留在零。swarm-yuan 用 16 项特征卡让 AI 先懂你的项目，用 36 个质量门禁守护代码合规——特征卡是立法，门禁是执法。
