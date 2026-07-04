# 六段式模板填充规范 (Six-Section Template Spec)

目标技能必须包含六段，覆盖材料模板的全部要素。每段的内容要求与填充规则如下。**生成后用本文件逐项核对，确保无遗漏。**

---

## 1. meta 段（SKILL.md）

**文件：** `<target-skill>/SKILL.md`

**结构：**
```markdown
---
name: <target-skill-name>
description: <项目名> 的需求交付全流程技能。当用户...都应使用本技能。涵盖...全流程。
---

# <skill-name> — <项目名> 需求交付全流程技能

## 核心理念
（项目最核心的铁律，来自 AGENTS.md/CONTRIBUTING/记忆，不超过 7 条）

## 改造分类（决定你怎么写代码）
（项目特有的改动分类表，如 A类/B类、core/plugin、src/lib）

## 全流程总览（N 节点）
（节点流程图 + 一句话说明每节点；标注流程入口顺序与并行关系）

## 六段式结构导航
（段 → 文件 → 用途 的映射表）

## 快速入口（按任务类型）
（任务类型 → 起始节点 → 关键参考 的表）

## 常用命令速查
（真实命令 + 端口约定）

## 质量门禁
（核心门禁清单，对应 check 段）

## 状态保存与恢复
（流程状态载体说明）

## 完成检查表
（任务完成前的 checkbox 清单）
```

**填充规则：**
- `description` 必须包含项目特有关键词（模块名、命令名、技术栈），写得"pushy"以提高触发率
- 核心理念只放最高优先级的铁律，不超过 7 条
- 改造分类必须反映项目实际（探查得出），不要套用通用模板
- 全流程总览的流程图要标注**入口顺序**（谁先做、谁后做、谁并行）——对应材料 workflow 要素 1
- 常用命令必须真实可执行
- **引用规则而非写死**：来自项目规则文件的约束，写"见 AGENTS.md / 项目记忆"，不重复具体值

---

## 2. workflow 段（references/workflow.md）— 9 要素/节点

**文件：** `<target-skill>/references/workflow.md`

**结构：** 节点化流程。**顶部**先画流程图（标注入口顺序与并行关系），然后每个节点含 **9 要素**：

```markdown
## 流程总览

（流程图，标注：①→②→③ 串行节点；并行节点用 └──┘ 标注）

---

## 节点①：需求理解

**① 流程入口（顺序/并行）：** （本节点在流程中的位置：前序节点、后续节点、可并行项）

**② 参与方：** （谁参与，谁是决策方，谁执行）

**③ 前序依赖检查（准入）：**
- （进入本节点前必须满足的条件）
- 信息不足时的处理（提问澄清，不臆测）

**④ 质量门禁：**
- （离开本节点前必须满足的条件，可被 precheck.sh 验证）

**⑤ 分支处理：**
- 成功：（对分支的处理）
- 失败/错误：（如何回退、重试）
- 信息不足：（暂停澄清还是降级处理）

**⑥ 产出物归档：**
- 持久化：（落盘到哪个路径）
- 临时上下文：（仅对话/草稿的产物）

**⑦ 流程控制：** （可否暂停/恢复/重启；恢复方式）

**⑧ 状态控制：** （状态保存在哪，如何恢复）

（其他节点同结构）

---

## ⑨ 流程完成检查表
（全流程完成前的 checkbox 清单，汇总所有节点的门禁）
```

**标准节点（可按项目裁剪）：**
1. 需求理解
2. 设计 spec（采用 OpenSpec proposal 模式：proposal.md + delta spec + design.md + tasks.md）
3. 实施 plan（采用 OpenSpec tasks checkbox 格式 + superpowers writing-plans bite-sized 步骤）
4. 分支准备
5. 编码实现（采用 superpowers subagent-driven：orchestrator + 每任务新 subagent + 两阶段审查；**复杂变更（>3 文件/跨模块）用 Dynamic Workflows 并行扇出 + 交叉验证**）
6. 测试验证（含 gstack/OCR 5 审查维度 + AUTO-FIX/ASK + 可选 `claude ultrareview` 云端多 agent 审查）
7. 合入 main
8. 构建发布

> 项目可能有额外节点（如"代码审查"、"部署验证"），或无发布环节。按项目实际裁剪。
> **方法论整合：** 节点②③用 OpenSpec 的 proposal→spec(delta)→design→tasks 模式（specs as source of truth）；节点⑤用 superpowers 的 subagent 编排（见 subagent-orchestration.md）；节点间状态用 comet 风格脚本背书（state-machine.sh，非 prompt-only）；节点⑥含 gstack/OCR 审查维度（见 review-methodology.md）。

**填充规则（9 要素逐项）：**
1. **流程入口** — 每节点标注其在流程中的位置（前序/后续/并行），顶部流程图体现全局入口顺序
2. **参与方** — 明确每个节点的参与者与角色（执行/决策/确认）
3. **准入检查** — 具体可验证（如"git rev-parse HEAD == git rev-parse main"）
4. **质量门禁** — 可被 precheck.sh 验证的检查项
5. **分支处理** — 必须覆盖成功/失败/信息不足三种情况
6. **产出物归档** — 区分持久化（落盘）vs 临时上下文（对话/草稿）
7. **流程控制** — 标注可否暂停/恢复/重启及恢复方式
8. **状态控制** — 状态载体（git 分支/文件/对话上下文）与恢复方式
9. **完成检查表** — workflow.md 末尾，汇总所有节点门禁

**标注需要用户确认的节点**（通常是合入 main、发布）。

---

## 3. reference 段（references/*.md）— 8 项 + 特征卡 12 项完整承接

> **铁律：特征卡 12 项必须全部承接进目标技能的文件中，不得遗漏。** 下表是 12 项特征卡 → 目标技能文件的完整映射：

| 特征卡项 | 承接的目标技能文件 | 承接章节 |
|---------|-------------------|---------|
| 1. 项目类型 | SKILL.md + codebase.md | 概述 + 工作区布局 |
| 2. 可改范围 | SKILL.md（铁律）+ dev-guide.md（改造分类）+ precheck.sh --scope | 铁律 + 决策树 + 门禁 |
| 3. 改造分类 | SKILL.md（改造分类表）+ dev-guide.md（详解） | 改造分类 + 开发指南 |
| 4. 技术栈摘要 | codebase.md（技术栈版本表） | 技术栈 |
| 5. 构建发布命令 | SKILL.md（命令速查）+ release.md（编译规则）+ codebase.md（端口） | 命令速查 + 编译规则 + 端口 |
| 6. 分支规范 | SKILL.md（铁律）+ branch-setup.sh + precheck.sh --branch | 铁律 + 脚本 + 门禁 |
| 7. 安全规则 | reference-manual.md §2 + precheck.sh --sensitive | 安全检查清单 + 门禁 |
| 8. 文档约定 | workflow.md 节点②③ + spec-template.md + plan-template.md | spec/plan 命名格式 |
| 9. 测试体系 | reference-manual.md check §1 + precheck.sh --test | 测试案例 + 门禁 |
| 10. 环境与外部资源 | env-setup.sh + codebase.md（DB/资源）+ mcp-tools.md | 环境检测 + 资源 + MCP |
| 11. 可复用稳定单元 | reference-manual.md §4/5/6 + dev-guide.md §7（拼装式开发）+ spec-template.md（复用约束段）+ precheck.sh --reuse | 组件库 + 依赖链路 + 接口 + 拼装原则 + 复用标注 + 门禁 |
| 12. 数据规范 | reference-manual.md §8 + data-sample-template.md + precheck.sh --consistency | 数据字典 + 库表样例 + 勾稽门禁 |
| 13. 五层认知基底 | reference-manual.md（认知映射表+六维动力学基线+逻辑谬误图谱+辩证映射表）+ spec-template.md（§14交付衰减/§15蓝图/§16偏差自检/§17辩证映射）+ precheck.sh --cognition | 认知映射 + 动力学基线 + 辩证映射 + 五层体检门禁 |
| 14. 领域知识 | reference-manual.md（领域知识段：技术+业务领域规则）+ spec-template.md（§18领域知识约束）+ precheck.sh --domain | 领域识别 + 客观规律约束 + 违规检测门禁 |

**文件：** 多个，按主题拆分。

| 文件 | 覆盖材料项 | 内容 |
|------|-----------|------|
| `codebase.md` | §1 代码目录结构及配置信息 | 目录树、技术栈版本表、端口、配置、构建机制 |
| `dev-guide.md` | §7 组件库代码填充说明（部分） | 改造分类详解 + 开发指南 + **拼装式开发原则（优先复用既有稳定单元）** + 领域/实体对象域填充 + 接口参数填充 + 任务流程填充 |
| `release.md` | §3 项目编译规则清单 | 编译规则表 + 构建命令 + 产物位置 + 失败排查 |
| `reference-manual.md` | §2/4/5/6/7/8 + check §1/2/3/4 | 见下方 |

**reference-manual.md 必须包含的章节：**

| 章节 | 材料项 | 内容 |
|------|--------|------|
| §安全检查规则清单 | §2 | 脱敏、密钥、网络白名单、框架安全基线 |
| §项目组件库清单 | §4 | 主要组件模块 + 关键组件名 + store 位置 + 计数 |
| §组件依赖链路说明 | §5 | 组件挂载树/依赖关系图（从入口到子组件） |
| §应用接口清单 | §6 | API 入口、路由文件、OpenAPI 生成方式、认证机制 |
| §UI/UX设计资源清单 | §7 | 设计文档、主题、样式、品牌资源、i18n |
| §数据字典及数据规范 | §8 | schema 位置、数据流、业务规则、勾稽关系 |
| §测试案例（check §1） | check §1 | 单测/接口/集成/回归/安全测试案例及数据 |
| §业务规则案例（check §2） | check §2 | 业务规则 + 案例数据 |
| §数据勾稽核对（check §3） | check §3 | 无多漏错重核对项 |
| §UI展示核对（check §4） | check §4 | UI正确/脱敏/日志 |

**填充规则：**
- 全部用探查到的**真实路径、版本号、命令名、连接串格式**
- 组件依赖链路用树/图表示（从 App 入口到叶子组件）
- 接口清单列出 API 入口（控制器、路由文件、OpenAPI 生成方式、认证）
- 数据字典含 schema 定义位置、数据流、**勾稽核对项**（无多漏错重：无遗漏、无多余、记录正确、勾稽正确、一致性、幂等性）
- 业务规则案例：列出关键业务规则 + 对应的测试案例数据
- **★拼装式开发原则（dev-guide.md §7 必须含）**：
  - 优先复用特征卡第 11 项盘点的**既有稳定单元**（接口/组件/类/函数/方法/store/类型）
  - 新功能 = 既有稳定单元的拼装 + 最小新增胶水代码
  - **禁止重复造轮子**：新增函数/组件前，先查特征卡第 11 项是否已有同等功能的稳定单元
  - **禁止侵入式重构**：不修改既有稳定单元的签名/行为，只通过组合/扩展复用
  - **禁止破坏性改造**：不改 upstream 骨架/第三方依赖/框架核心，只通过项目允许的机制（patch/overlay/插件）接入
  - 每个新增文件须标注：复用了哪些既有单元（引用特征卡第 11 项的路径/签名）
- **★版本锁定原则（dev-guide.md 必须含 + codebase.md 版本表必须记录基线）**：
  - 功能性开发过程中，**不允许随意升级或更换核心技术及基础组件及依赖的版本**
  - 例外条件（须满足之一）：(1) 用户主动要求；(2) 严重安全漏洞；(3) 严重性能隐患；(4) 功能缺失（当前版本无法实现需求且无替代方案）
  - 探查时记录当前版本基线（特征卡第 4 项 → codebase.md 技术栈版本表）
  - 任何版本变更须在 spec-template.md 版本约束声明段中显式声明理由 + 经用户确认
  - precheck.sh `--deps` 检测 package.json/pyproject.toml/go.mod 等依赖版本是否被变更
- **★可复用稳定单元清单（reference-manual.md §4/5/6 必须含）**：从特征卡第 11 项整理，列出全部稳定单元的签名/路径/用途/复用方式/稳定性标注
- **★安全规范（reference-manual.md §2 必须含 + dev-guide.md 必须含安全编码规范）**：引用 `references/security-spec.md`，覆盖 OWASP Top 10（注入/XSS/CSRF/访问控制/身份认证/敏感数据/依赖安全）、代码安全（路径穿越/反序列化/SSRF/安全配置/日志安全）、网络安全（接口安全/传输安全/端口安全）、LLM 信任边界。precheck.sh `--security` 检测常见安全模式
- **★三平台兼容（swarm-yuan 自身的 .sh 脚本必须遵守，非目标技能强制）**：不用 declare -A / sed -i.bak+rm / grep -E / date -u / cd+pwd 替代 readlink -f / wc|xargs / ${var} 防 C-locale。详见 `references/security-spec.md` §六

---

## 4. assets 段（assets/*）— 7 项

**文件：** 模板、环境脚本、数据模版。

| 文件 | 材料项 | 内容 |
|------|--------|------|
| `spec-template.md` | §4 任务配置模版 + §5 静态资源 + **★复用约束段** | 设计文档模板（含静态资源/页面元素段 + 复用约束：标注复用了哪些既有稳定单元） |
| `plan-template.md` | §4 实施计划模版 | Task 拆分 + 起点核验 + 检查表 |
| `branch-setup.sh` | §3 拉取代码仓库分支 | 核验起点 + 建分支 + 记录基线 |
| `env-setup.sh` | §1 加载环境 + §2 检测资源连接/工具权限 | 环境加载 + 资源连通性 + 工具权限检测 |
| `data-sample-template.md` | §6 库表及数据结构、样例数据 | 库表 schema 模版 + 样例数据格式 |
| `state-machine.sh` | ★comet 风格阶段状态机 | 阶段状态持久化（init/get/set/transition/guard），survive compaction |

**填充规则：**
- `env-setup.sh` 必须检测：开发环境（node/python/go 版本）、外部资源连通性（DB/缓存/MQ，按项目实际）、工具权限（git/gh/docker）。检测项按项目探查结果定制，无对应资源的项跳过
- spec/plan 模板采用 OpenSpec 格式：spec-template = proposal.md（Why/What/Capabilities/Impact）+ delta spec（ADDED/MODIFIED/REMOVED/RENAMED + SHALL/MUST + Scenario WHEN/THEN）；plan-template = tasks.md（`- [ ] X.Y` checkbox，apply 阶段解析进度）
- branch-setup.sh 包含起点核验 + 保护分支检查
- data-sample-template.md 提供库表 schema + 样例数据的填写框架
- state-machine.sh 实现 comet 风格阶段状态机：`init <change>` / `get <field>` / `set <field> <val>` / `transition <phase>` / `guard <phase>` / `next`。状态存 `.swarm-yuan/state.yaml`（survive context compaction）。阶段转换有硬门禁（guard 验证产出物存在）

---

## 5. check 段（scripts/precheck.sh + reference-manual.md 检查段）— 4 项

**文件：** `scripts/precheck.sh` + `references/reference-manual.md` 的检查章节。

**precheck.sh 子命令：**
```bash
bash precheck.sh                  # 全部门禁
bash precheck.sh --branch         # 分支规范
bash precheck.sh --scope          # 改动范围（可改 vs 只读）
bash precheck.sh --build          # 构建状态
bash precheck.sh --test           # 测试（check §1）
bash precheck.sh --sensitive      # 敏感信息脱敏（check §4）
bash precheck.sh --consistency    # 业务规则 + 数据勾稽核对（check §2/§3）
bash precheck.sh --review         # ★代码审查（gstack/OCR 5 维度，调用 ocr review 若可用）
bash precheck.sh --reuse          # ★复用合规检查（拼装式开发：禁止重复造轮子）
bash precheck.sh --deps           # ★依赖版本锁定：对比基线检测依赖版本变更（未经确认=违规）
bash precheck.sh --security       # ★安全规范：OWASP Top 10 模式扫描（注入/XSS/eval/硬编码密钥/TLS）
bash precheck.sh --layer          # ★DDD 分层边界：层穿透/依赖倒置/循环依赖/领域层污染框架/聚合跨引用
bash precheck.sh --stable-diff    # ★稳定单元篡改：稳定层文件改动必须先立 spec（MODIFIED 声明）
bash precheck.sh --link-depth     # ★调用链深度：链路膨胀/纯转发函数堆叠检测（graphify/madge 优先，降级启发式）
bash precheck.sh --adr            # ★TOGAF 架构决策：ADR 目录 + 新依赖须有 ADR + 技术债登记
bash precheck.sh --contract       # ★TOGAF 接口契约：契约 version 字段 + 跨上下文 import 必须经 ACL 防腐层
bash precheck.sh --consistency-cross # ★TOGAF BDAT 一致性：业务术语表 vs 代码标识符 + 数据所有权 SoR
bash precheck.sh --impact         # ★TOGAF 变更影响：spec 须含"影响范围"段 + 变更文件消费方反查
bash precheck.sh --service        # ★微服务架构：共享DB/同步链/共享模型/网关/trace透传
bash precheck.sh --api            # ★API 契约与幂等：版本化/幂等键/跨服务事务/Outbox
bash precheck.sh --state          # ★前端状态管理：巨型store/prop drilling/派生状态useState
bash precheck.sh --frontend       # ★前端组件架构：层级深/容器展示分离/props多/循环依赖/CSS污染
bash precheck.sh --cognition      # ★认知递进体检：六阶认知链完整性 + 六维动力学（速度/聚散/趋势/强度/能耗/累积量）
bash precheck.sh --domain         # ★领域知识：技术+业务领域识别 + 客观规律违规检测（密码明文/SQL拼接/XSS/并发竞态）
bash precheck.sh --knowledge      # ★项目知识复用：AGENTS.md/CLAUDE.md/记忆 → 生成 skill 是否复用
bash precheck.sh --mermaid        # ★Mermaid 可视化：架构图/流程图/调用链是否用 Mermaid
```

**reference-manual.md 检查段包含（对应 check 4 项 + 审查 + 复用）：**

| check 项 | 内容 | precheck 子命令 |
|----------|------|----------------|
| 分支规范 | 分支命名（feat/fix/refactor）+ 保护分支禁止直接开发 | `--branch` |
| 改动范围 | 可改 vs 只读目录边界，只读区改动=违规 | `--scope` |
| 构建状态 | 构建命令执行成功，产物存在 | `--build` |
| §1 单测/接口/集成/回归/安全测试案例 | 测试框架、目录、案例数据、运行命令 | `--test` `--sensitive` |
| §2 业务规则案例及数据 | 关键业务规则 + 案例数据 + 预期结果 | `--consistency` |
| §3 数据勾稽核对（无多漏错重） | 无遗漏、无多余、记录正确、勾稽正确、一致性、幂等性 | `--consistency` |
| §4 UI展示核对 | 展示正确、敏感信息脱敏、请求响应日志已记录 | `--sensitive` |
| ★代码审查 | 5 维度（正确性/安全/性能/可维护/测试覆盖）+ 两遍清单 + AUTO-FIX/ASK + 严重度分级 | `--review` |
| ★复用合规 | 拼装式开发（**硬门禁**）：校验 spec §5.5 复用约束段 + 4 checkbox 全勾；新增单元名 vs reference-manual §4/5/6 稳定单元名重名检测（重复造轮子→fail）；导出单元数异常 warn | `--reuse` |
| ★版本锁定 | 检测 package.json/pyproject.toml/go.mod 等依赖版本是否被变更（对比基线），未经用户确认的版本升级 = 违规 | `--deps` |
| ★安全检查 | 检测 OWASP Top 10 常见安全模式：SQL 拼接/命令注入/eval/v-html/路径穿越/硬编码密钥/弱哈希/禁用 TLS/CORS */调试模式 | `--security` |
| ★DDD 分层边界 | **硬门禁**：层依赖方向断言（仅允许上层→下层，LAYER_ORDER）；领域层不得 import 框架/ORM/Web/IO（DOMAIN_FORBIDDEN_IMPORTS）；循环依赖（madge）；聚合跨边界对象引用（聚合间只引用 ID，不引用对象） | `--layer` |
| ★稳定单元篡改 | **硬门禁**：git diff 检测 STABLE_GLOBS 内文件改动，必须在 spec MODIFIED 段声明 + 理由 + 迁移，否则 fail | `--stable-diff` |
| ★调用链深度 | 硬门禁+warn：graphify 最长路径 / madge 依赖树深度 > MAX_LINK_DEPTH → warn；降级为纯转发函数统计（>5 提示） | `--link-depth` |
| ★TOGAF 架构决策 | **硬门禁**：ADR_DIR 必须存在；git diff 新增第三方依赖须在 ADR 中说明选型理由（warn）；TECH_DEBT_FILE 存在时校验代码 TODO/FIXME 是否登记（warn） | `--adr` |
| ★TOGAF 接口契约 | **硬门禁**：CONTRACT_DIR 内契约文件必须含 version 字段；ACL_DIR + CONTEXT_DIRS 配置时，跨上下文 import 必须经 ACL 防腐层中转（绕过=fail） | `--contract` |
| ★TOGAF BDAT 一致性 | warn：GLOSSARY_FILE 中代码标识符须在代码中可查（漂移→warn）；SOR_FILE 数据所有权表存在性校验 | `--consistency-cross` |
| ★TOGAF 变更影响 | **硬门禁**：spec 必须含"影响范围/impact/消费方/stakeholder"段；git diff 改动文件若消费方 >3 则 warn 提示回归 | `--impact` |
| ★微服务-共享DB | **硬门禁**：DB_CONFIG_FILES 中多服务指向同一 host+database = 共享数据库反模式 → fail | `--service` |
| ★微服务-架构 | warn：共享库被多服务依赖；无 API_GATEWAY；同步调用 >MAX_SYNC_CHAIN；无 traceId 透传；无 Outbox 模式 | `--service` |
| ★API 契约 | **硬门禁**：API_SPEC_DIR 内定义文件缺 version → fail；warn：写 handler 无幂等键；warn：检测到分布式事务/2PC | `--api` |
| ★前端状态 | warn：store 文件行数 >MAX_STORE_LINES；props 透传(...props)>5；useState 内派生计算(.map/.filter) | `--state` |
| ★前端组件 | warn：组件嵌套深度 >MAX_COMPONENT_DEPTH；容器+展示混合；props >MAX_PROPS_COUNT；非 scoped CSS；**硬门禁**：循环依赖(madge) | `--frontend` |
| ★认知递进体检 | **不判违规**（不 fail），呈现"认知体检报告"：六阶认知链（概念/结构/空间/映射/规律/处理）逐阶评分 + 六维动力学（速度/聚散/趋势/强度/能耗/累积量）状态观测。总分 ≥8 + ≥4 条规律 = 完整；5-7 = 部分建立；<5 = 不足 | `--cognition` |

**填充规则：**
- scope 检查反映项目的可改/只读边界
- sensitive 扫描涵盖项目用到的密钥格式
- `--consistency` 检查业务规则完整性 + 数据勾稽（无多漏错重）
- `--review` 调用 `ocr review`（若已安装），否则提示手动审查清单（5 维度 + 两遍清单）。引用 `references/review-methodology.md`
- `--reuse` 是**硬门禁**（违反则 `FAIL=1`，exit 1），做三件事：(1) 校验当前 spec 文档含 §5.5 复用约束段且 4 个拼装合规声明 checkbox 全部勾选；(2) 从 spec §5.5 "新增胶水代码" 表提取新增单元名，与 reference-manual.md §4/5/6 稳定单元名做重名检测，重名 = 重复造轮子 → fail；(3) 启发式 warn：可改目录新增导出单元数 >30 提示人工核对
- `--deps` 是**硬门禁**：对比探查时记录的版本基线（codebase.md 版本表），检测 package.json/pyproject.toml/go.mod 中依赖版本是否被变更。变更且 spec 中无版本约束声明段 = 违规。引用 `references/security-spec.md` §2.3
- `--security` 是**硬门禁**：扫描可改目录中的常见安全模式（见 `references/security-spec.md` §五安全检查清单），检测到 High 级 = fail
- `--layer` 是**硬门禁**：配置 LAYER_DEFS（层名=目录glob）+ LAYER_ORDER（依赖顺序，上层→下层）+ DOMAIN_LAYER + DOMAIN_FORBIDDEN_IMPORTS + AGGREGATE_DIR。做四件事：(1) 解析相对 import，断言仅允许上层依赖下层，倒置/穿透 fail；(2) 领域层不得 import 框架/ORM/IO（react/express/sequelize/prisma 等），违反 fail；(3) 循环依赖检测（madge，未装则 warn）；(4) 聚合间不得直接 import 其他聚合目录的对象（只引用 ID），违反 fail。防范 DDD 层穿透/领域污染/贫血模型被框架绑死/聚合边界破坏
- `--stable-diff` 是**硬门禁**：配置 STABLE_GLOBS（稳定层文件 glob，如 src/domain/** src/repositories/**）。git diff（vs main）检测稳定层文件改动，必须在 spec MODIFIED 段声明该文件 + 理由 + 迁移路径，否则 fail。防范"顺手改稳定单元签名/破坏聚合根/改 Repository 接口"
- `--link-depth` 配置 MAX_LINK_DEPTH（建议 6-8）。优先用 graphify 最长路径，降级 madge 依赖树深度，再降级为纯转发函数统计（>5 warn）。超阈值 warn（不 fail，因深度可能是合理的）。防范"适配层堆叠/调用链膨胀/Repository 查询泄漏"
- `--adr` 配置 ADR_DIR（架构决策记录目录）+ TECH_DEBT_FILE（技术债登记）。做三件事：(1) ADR_DIR 不存在 fail；(2) git diff 新增第三方依赖若未在 ADR 文件中出现则 warn（技术选型应有决策记录）；(3) 代码中 TODO/FIXME/HACK 数量提示在技术债文件登记。防范 TOGAF "架构决策无文档/技术债无登记"
- `--contract` 配置 CONTRACT_DIR（接口契约目录）+ ACL_DIR（防腐层目录）+ CONTEXT_DIRS（限界上下文目录列表）。做两件事：(1) 契约文件必须含 version 字段（缺则 fail）；(2) 跨上下文 import 解析到其他上下文目录 = 绕过 ACL → fail。防范 TOGAF "接口无版本/遗留系统无防腐层"
- `--consistency-cross` 配置 GLOSSARY_FILE（业务术语表）+ SOR_FILE（数据所有权表）。warn 级：(1) 术语表代码标识符在代码中 grep 不到 → 命名漂移 warn；(2) SoR 表存在性校验。防范 TOGAF "BDAT 命名不一致/数据所有权模糊"
- `--impact` 硬门禁：spec 必须含"影响范围/impact/消费方/stakeholder"任一关键字段（缺则 fail）；git diff 改动文件用 grep 反查消费方，>3 则 warn 提示回归范围。防范 TOGAF "变更无影响分析/评审后不遵从"
- `--service` 配置 SERVICE_DIRS/DB_CONFIG_FILES/SHARED_LIBS_DIR/API_GATEWAY/MAX_SYNC_CHAIN。**硬门禁**：多服务 DB_CONFIG_FILES 指向同一 host+database = 共享数据库 → fail。warn：共享库被多服务依赖；无网关；同步调用 >阈值；无 traceId/spanId 透传（建议 OpenTelemetry）；无 Outbox 模式。防范"分布式单体/共享DB/同步链雪崩/无追踪"
- `--api` 配置 API_SPEC_DIR/WRITE_HANDLER_DIRS。**硬门禁**：API 定义文件缺 version → fail。warn：写 handler（POST/PUT/DELETE）无 idempotency-key/request-id → 重复扣款风险；检测到分布式事务/2PC（seata/@GlobalTransactional/XAResource）→ 应改 Saga/Outbox；无 Outbox → 库消息不一致风险。防范"契约无版本/无幂等/跨服务事务"
- `--state` 配置 STORE_DIR/MAX_STORE_LINES/COMPONENT_DIR。warn：store 文件行数 >MAX_STORE_LINES（巨型 store）；...props 透传 >5 处（prop drilling）；useState 内 .map/.filter/.reduce（派生状态应 useMemo）。防范"状态散落/prop drilling/派生不同步"
- `--frontend` 配置 COMPONENT_DIR/MAX_COMPONENT_DEPTH/MAX_PROPS_COUNT/STYLE_DIR/BUNDLE_REPORT。**硬门禁**：循环依赖（madge）→ fail。warn：组件嵌套深度（python 扫描 JSX 标签峰值）>阈值；容器+展示混合（同时含数据获取+大量渲染）；props 数量 >阈值；非 .module.css 全局样式；bundle 重复依赖。防范"组件树失控/CSS污染/循环依赖"
- `--cognition` 配置 COGNITION_BASELINE/COG_SPEED_FILES/COG_CUMULATIVE_TODO/COG_STRENGTH_FANIN。**不判违规**，输出认知体检报告：(1) 六阶认知链逐阶评分——①概念（glossary+稳定单元清单）②结构（LAYER_DEFS+AGGREGATE_DIR+CONTEXT_DIRS）③空间（SERVICE_DIRS+COMPONENT_DIR+STORE_DIR）④映射（术语↔代码一致性+分层↔目录+SoR↔服务）⑤规律（每条门禁对应一条规律）⑥处理（spec/ADR/技术债）；(2) 六维动力学——速度（变更文件数）、聚散（服务/组件数）、趋势（依赖深度对比基线）、强度（高 fan-in 模块数）、能耗（巨型文件数）、累积量（TODO 累积）。总分 ≥8+≥4 规律=完整。**理念：呈现递进的关系而非仅计数**，每个计数背后指向一条关系规律
- 测试检查调用项目真实的测试命令
- **★swarm-yuan 自身的 .sh 脚本须兼容三平台**（macOS BSD bash 3.2 + Linux GNU bash 4+）：不用 declare -A / sed -i.bak+rm / grep -E（非 -P）/ date -u（非 -d）/ $(cd+pwd) 替代 readlink -f / wc|xargs / ${var} 防 C-locale。详见 `references/security-spec.md` §六

---

## 6. scripts 段（scripts/*）— 3 项

**文件：** 工具箱脚本与文档。

| 文件 | 材料项 | 内容 |
|------|--------|------|
| `precheck.sh` | §1 执行命令脚本 | 质量门禁检查（见 check 段，含 --review --reuse --deps --security --layer --stable-diff --link-depth --adr --contract --consistency-cross --impact --service --api --state --frontend --cognition） |
| `state-machine.sh` | ★comet 风格状态机 | 阶段状态持久化（init/get/set/transition/guard/next），survive compaction |
| `snippets.md` | §1 代码示例片段 + §3 组件详细参数配置说明 | 常用代码片段、命令示例、组件参数配置 |
| `code-graph-tools.md` | ★GitNexus+graphify 引用 | 代码图谱工具安装与命令（只引用，不复制源码） |
| `mcp-tools.md` | §2 MCP工具：DB/ELK/Redis/MQ/dubbo/union/CMDB | MCP 工具接入说明（按项目实际有的才填） |

**填充规则：**
- precheck.sh 是必选，含 `--review` + `--reuse` 子命令（引用 review-methodology.md + 拼装式开发原则）
- state-machine.sh 实现 comet 风格阶段状态机（init/get/set/transition/guard/next），状态存 `.swarm-yuan/state.yaml`
- snippets.md 收录：高频命令组合、代码模板、组件参数配置表
- **code-graph-tools.md 引用 GitNexus/graphify**（见 `references/code-graph-tools.md`）：按项目语言生态选择，只写安装+命令+集成模式，**不复制工具源码**
- **mcp-tools.md 按项目实际填充**：项目有 DB/ELK/Redis/MQ → 填访问方式；无 → 写"本项目无外部 MCP 资源"
- 脚本必须 `chmod +x` 且 `bash -n` 语法检查通过
- 路径用绝对路径或基于脚本位置的相对路径，确保可移植

---

## 生成后核对清单

生成目标技能后，用本清单逐项核对材料要素覆盖 + **特征卡 12 项全覆盖** + **拼装式开发** + 方法论整合：

**★特征卡 13 项全覆盖（逐项核对，任何一项遗漏 = 未完成）：**
- [ ] 1.项目类型 → SKILL.md + codebase.md
- [ ] 2.可改范围 → SKILL.md（铁律）+ dev-guide.md + precheck.sh --scope
- [ ] 3.改造分类 → SKILL.md + dev-guide.md
- [ ] 4.技术栈摘要 → codebase.md
- [ ] 5.构建发布命令 → SKILL.md（命令速查）+ release.md + codebase.md（端口）
- [ ] 6.分支规范 → SKILL.md（铁律）+ branch-setup.sh + precheck.sh --branch
- [ ] 7.安全规则 → reference-manual.md §2 + precheck.sh --sensitive
- [ ] 8.文档约定 → workflow.md 节点②③ + spec-template.md + plan-template.md
- [ ] 9.测试体系 → reference-manual.md check §1 + precheck.sh --test
- [ ] 10.环境与外部资源 → env-setup.sh + codebase.md + mcp-tools.md
- [ ] 11.**可复用稳定单元** → reference-manual.md §4/5/6（签名/路径/用途/复用方式/稳定性标注）+ dev-guide.md §7（拼装式开发原则）+ spec-template.md（复用约束段）+ precheck.sh --reuse
- [ ] 12.数据规范 → reference-manual.md §8 + data-sample-template.md + precheck.sh --consistency
- [ ] 13.**五层认知基底** → reference-manual.md（认知映射表+六维动力学基线+逻辑谬误图谱+辩证映射表）+ spec-template.md（§14交付衰减/§15蓝图/§16偏差自检/§17辩证映射）+ precheck.sh --cognition（五层总分≥15/19）
- [ ] 14.**领域知识** → reference-manual.md（领域知识段：技术领域+业务领域+客观规律）+ spec-template.md（§18领域知识约束：领域识别+客观规律表+声明）+ precheck.sh --domain（spec §18存在性+reference-manual领域知识段+客观规律违规检测）

**★拼装式开发核对：**
- [ ] dev-guide.md §7 含拼装式开发原则（优先复用既有稳定单元；禁止重复造轮子/侵入式重构/破坏性改造）
- [ ] reference-manual.md §4/5/6 含可复用稳定单元清单（API接口/组件/类/函数/方法/store/类型定义，每个含签名/路径/用途/复用方式/稳定性标注）
- [ ] spec-template.md 含复用约束段（复用的既有单元表 + 新增胶水代码表 + 拼装合规声明）
- [ ] precheck.sh 含 `--reuse` 子命令（检测重复造轮子 + 提示核对稳定单元清单）

**★版本锁定核对：**
- [ ] codebase.md 含技术栈版本基线表（探查时的当前版本）
- [ ] spec-template.md 含版本约束声明段（本次变更是否涉及版本升级 + 理由 + 用户确认）
- [ ] precheck.sh 含 `--deps` 子命令（对比基线检测依赖版本变更）

**★安全规范核对：**
- [ ] reference-manual.md §2 含安全检查清单（OWASP Top 10：注入/XSS/CSRF/访问控制/身份认证/敏感数据/路径穿越/SSRF/依赖安全/安全配置/日志安全）
- [ ] dev-guide.md 含安全编码规范（参数化查询/输入校验/输出编码/路径校验/SSRF 防御/不安全反序列化禁止）
- [ ] precheck.sh 含 `--security` 子命令（检测 SQL 拼接/命令注入/eval/v-html/路径穿越/硬编码密钥/弱哈希/禁用 TLS/CORS */调试模式）
- [ ] 引用 `references/security-spec.md`

**★三平台兼容核对（swarm-yuan 自身脚本，非目标技能强制）：**
- [ ] swarm-yuan 的 .sh 脚本兼容 macOS(BSD bash 3.2)+Linux(GNU bash 4+)（不用 declare -A / sed -i.bak / grep -E / date -u / cd+pwd / wc|xargs / ${var}防C-locale）
- [ ] 无硬编码平台特定路径（用配置/env/相对路径）
- [ ] 文件名小写无特殊字符（Windows 兼容）
- [ ] 代码模板中路径用 / + path.join()（Node）/ os.path.join()（Python）

**材料要素覆盖：**
- [ ] **meta**：铁律、改造分类、流程总览（含入口顺序）、命令速查、门禁、检查表
- [ ] **workflow 9 要素**：每节点都有 流程入口/参与方/准入/门禁/分支处理/产出物归档/流程控制/状态控制；末尾有完成检查表
- [ ] **reference 8 项**：目录结构/安全检查/编译规则/组件库/组件依赖链路/接口清单/UI-UX资源/数据字典
- [ ] **assets 7 项**：环境加载/资源检测/分支拉取/任务配置模版/静态资源/库表样例/组件填充说明
- [ ] **check 4 项**：单测接口集成回归安全/业务规则案例/数据勾稽(无多漏错重)/UI脱敏日志
- [ ] **scripts 3 项**：执行脚本/代码片段+组件参数/MCP工具

**方法论整合（7 项）：**
- [ ] **Spec-driven（OpenSpec）**：workflow 节点②③用 proposal→spec(delta)→design→tasks 模式；spec/plan 模板用 OpenSpec 格式（delta ADDED/MODIFIED + SHALL/MUST + Scenario WHEN/THEN；tasks `- [ ]` checkbox）
- [ ] **Subagent-driven（superpowers）**：workflow 节点⑤引用 subagent-orchestration.md（orchestrator + 每任务新 subagent + 两阶段审查 + progress ledger + 文件交接）；**复杂变更用 Dynamic Workflows 并行扇出 + 交叉验证（降级：Task(subagent) 手动并行）**
- [ ] **State machine（comet）**：scripts/state-machine.sh 实现阶段状态持久化 + 阶段转换硬门禁；workflow 状态控制段引用它
- [ ] **Review（gstack/OCR）**：check 段含 5 审查维度 + 两遍清单 + AUTO-FIX/ASK + 严重度分级；precheck.sh --review；引用 review-methodology.md
- [ ] **Code-graph（GitNexus/graphify）**：scripts/code-graph-tools.md 引用工具命令（只引用不复制）；探查阶段先用图谱索引；组件依赖链路从图谱读
- [ ] **Phase-loop + capability（gsd-core）**：引用 gsd-patterns.md；check 用 goal-backward 对抗验证（任务完成≠目标达成，FORCE 立场，BLOCKER/WARNING 分类）；门禁分 4 类（pre-flight/revision/escalation/abort）；workflow 可选 wave 并行；**若装了 gsd-core 则调用 `/gsd-execute-phase`/`/gsd-verify`/`gsd-tools` 运行时引擎，若未装则降级为 state-machine.sh + subagent 手动编排**
- [ ] **Memory persistence（claude-mem）**：引用 memory-persistence.md；状态控制段说明跨会话记忆方案（state-machine.sh 管阶段 + progress ledger 管任务 + claude-mem 若装则管跨会话知识）；3 层渐进式检索

**★五层认知基底核对（第三+四+五层，见 SKILL.md 五层框架段 + references/cognition-framework.md）：**
- [ ] **第一层 认知递进**：reference-manual.md 含"认知映射表"段（六阶落点）+ "六维动力学基线"段；特征卡第 13 项已填；`--cognition` ①-⑥ 体检可运行
- [ ] **第二层 思维语言**：spec-template.md 含 §14 交付衰减分析 + §15 蓝图任务段；workflow 节点含七推理落点；spec §2 决策记录含思维模型对照列
- [ ] **第三层 认知辩证**：workflow 含 4-Phase 多轮交互 SOP（概念澄清→破局重构→七步推演→行动落地，每 Phase 暂停）；check 段含逻辑剃刀 6 步对抗审查（观点镜像/核心定调/病理诊断/降维反驳/建设性重构/灵魂拷问）；reference-manual.md 含"逻辑谬误图谱"段（四类谬误）；引用 references/logic-razor.md
- [ ] **第四层 偏差防范**：spec-template.md 含 §16 认知偏差自检段（五维偏差扫描表 + 思维模型对照表 + 自检声明 3 checkbox）；workflow 6 节点含偏差检查锚点；引用 references/cognitive-bias.md
- [ ] **第五层 辩证认知**：SKILL.md 含辩证认知框架段（本质与现象+7对辩证关系+矛盾分析法落点）；spec-template.md 含 §17 辩证映射分析段（主要矛盾+7对≥2对+辩证声明）；reference-manual.md 含"辩证映射表"段（7对辩证关系落点）；workflow 节点含矛盾识别（主要矛盾+矛盾主要方面）；引用 references/cognition-framework.md 第五层
- [ ] **`--cognition` 五层总分**：`bash precheck.sh --cognition` 输出五层认知基底总分 ≥15/19（第一层 11 + 第二层 3 + 第三层 2 + 第四层 2 + 第五层 1）
- [ ] **最小意识三条件**：M(门禁可运行) + H(state-machine+记忆) + A(认知体检+对抗验证) 三条件标注在 dev-guide.md

**质量：**
- [ ] 无占位符残留（`<待填充>`/`<项目根>` 等）
- [ ] 所有 .sh 通过 `bash -n`
- [ ] frontmatter description 含项目关键词
- [ ] **工具引用合规**：只引用 GitNexus/graphify/ocr/claude-mem/gsd-core 命令，无重新实现
