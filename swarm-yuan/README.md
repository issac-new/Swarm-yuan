# swarm-yuan — 让 AI 懂你的项目，再写代码

> 从「AI 辅助写代码」到「AI 懂项目再写代码」的认知基础设施。
>
> **特征卡是立法，门禁是执法，验证器是司法**——特征卡让 AI 认识你的项目，门禁守护代码合规，独立验证器做司法。
> **两体系统**（R13）：生成器厚（探查全量，一次性消费）、生成物薄（每会话固定税 ≤8KB、概念体系 ≤5）；范式作为条件而非内容。
> **三层 Harness 拼图**（R13-R15）：过程强制门禁层（rules.d 三值 + hooks 双宿主）+ 工作流审计层（goal_id+closure 目标闭环 + 证据态分级）+ 评测层（digest 链式锚定 + 选择即证据 + 审计即完成条件）。
> 计数真值见 `assets/facts.conf`（不手抄；`scripts/self-check.sh` 机器执法）。

[![Release](https://img.shields.io/badge/release-v2.5-blue)](https://github.com/issac-new/Swarm-yuan/releases/tag/v2.5)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)]()

---

## 为什么需要它

AI 的代码生成能力已经很强，但「项目认知」仍是被多数工具忽视的环节——改了不该改的文件、升级了不该升级的依赖、重复造了已有组件的轮子、检查靠人工逐行 review。

swarm-yuan 是**元技能生成器**：为任意代码仓库生成项目专属开发技能（"目标技能"），核心闭环 = **探查**（全量组件库清单 + 调用链分析）→ **门禁**（三值规则 + hooks 强制）→ **自成长**（项目变了技能跟着变）。

---

## 关键设计理念

| 理念 | 含义 |
|------|------|
| **先认识，再行动** | AI 写代码前必须先认识项目。特征卡完成认知，门禁守护行动 |
| **拼装式开发** | 新功能 = 既有稳定单元拼装 + 最小新增胶水代码。禁止重复造轮子/侵入式重构/破坏性改造（奠基期用户原话，是探查的应用层目的） |
| **呈现递进的关系** | 门禁不是"数 import 数"——每个计数背后指向一条关系规律 |
| **特征卡是立法，门禁是执法，验证器是司法** | 特征卡定义「项目应该是什么样的」，门禁验证「代码是否符合」，`verifier/v1` 用 fixture 双态 + cli A/B 字节级等价做独立司法 |
| **分层整合，诚实降级** | 运行时按深度/CLI/方法论三层整合，每层有自带降级载体，未装不阻塞，不假装全深度接线 |
| **生成器厚、生成物薄**（R13 两体系统） | 生成时刻允许厚（探查知识全量，一次性消费），生成物必须薄（每会话固定税 ≤8KB、概念体系 ≤5，税制有机器预算） |
| **范式作为条件而非内容**（R13） | 机器执法只保留"防 AI 说谎"的条件类（path-check/计数核验/last-good/状态门/三值规则/FORBID 带替代）；概念/门禁/profile/references 一概不删，病根是"没有正确落地"，全部转为真实消费路径（落地优先于删除） |
| **审计是闭环不是事件**（R14-R15） | 审计单元是"一个用户目标+一个验收边界"（goal_id+closure）；证据态分级（配置≠使用≠有效）；三本账从并列升级为链式（ref_trace_hash 锚定，上游篡改全链 stale 可检出）；选择即证据；审计即完成条件 |
| **AI 全自动、零手动配置** | 生成 skill 是 AI 一键完成；使用时研发人员对 AI 说话而非手动跑命令；SKILL.md 是 AI 读的（写"零手动"铁律），USAGE 层保留 bash 双轨制 |
| **失败方向教义** | 权限边界一律 fail-closed；fail-open 只允许在有下层强制兜底处 |

---

## 特征卡：项目的「认知 DNA」

AI 探查项目后提取特征项（P0 强制 + P1 可增量，真值见 facts.conf），每项落到真实路径和版本号，不用占位符。特征卡不是独立文件，而是**分散承接进目标技能的各个文件中**（SKILL.md 定位/安全铁律/构建命令/分支规范/测试体系/编排约束等），驱动门禁配置和文件填充。

**拼装式开发是它的存在理由**：特征卡中的"可复用稳定单元清单"（API 接口/组件/类/函数/方法/store/类型定义，每个含签名/路径/用途/稳定性标注）是 AI 拼装时的零件目录——认知不是为了看懂项目，是为了让 AI 能基于稳定可靠的组件拼装新功能，规避破坏性改造与重复造轮子。

---

## 五层认知基底（理念内核，R13 后落地为 AI 判断引导）

| 层 | 解决什么 | 落点 |
|----|---------|------|
| 认知递进 | 如何认识项目（概念→结构→空间→映射→规律→处理 + 六维动力学） | 探查 + `--cognition`（AI 判断引导，机械计分已退役） |
| 思维语言 | 如何思考（三元演化/七推理） | spec 思考段（按需展开） |
| 认知辩证 | 如何推演+自证伪（逻辑剃刀） | `--cognition` 验证工具 |
| 偏差防范 | 如何纠偏（五维偏差 + 思维模型） | spec 偏差自检段（按需） |
| 辩证认知 | 如何统一前四层（辩证范畴） | `--domain` 违规检测 |

> 详见 `references/cognition-framework.md`。⚠️ "五层认知基底"是**工程启发式框架**（非心理测量学构念——未经信度/效度检验；R13 后机械计分退役，转为 AI 按框架逐维自查并留痕 `.swarm-yuan/notes/cognition.md`，六个月后回看 = 认知基线的纵向对比）。

---

## 终态设计（与 `../docs/DESIGN.md` 一致）

### 两体系统

```
厚生成器（一次性消费，可厚）          薄生成物（每会话重复消费，必须薄）
  探查知识库（框架规则/references）      SKILL.md（≤8KB：何时用/约束摘要/入口/路由/元规则/自成长）
  行业 profile（conf-render 真实加载）   地图（≤32KiB：两列表 |路径|说明与约束|）
  决策史/调研史（docs/）               rules.d/*.rules + precheck + hooks（双宿主）
                                      scripts（按需调用的工具，不算税）
```

### 三层 Harness 拼图

| 层 | 机制 | 落地版本 |
|----|------|---------|
| **过程强制门禁层** | 门禁四族（真值见 facts.conf）全部有真实触发路径；rules.d 三值规则（allow/prompt/forbid 取最严）；FORBID 消息带替代方案；hooks 双宿主真实拦截（Claude Code deny JSON + Codex exit 2）；沙箱通配符 deny（**/.env 防重命名绕过） | v2.0（R13 去抽象化重构） |
| **工作流审计层** | 审计单元目标闭环化（`goal_id`+`closure`：一个用户目标+一个验收边界，change↔validation 链接才 closed）；证据态分级（配置≠使用≠有效）；双账本（当窗验证 repair_verified_rate + guardrail 配对）；修复复核位（repair_review） | v2.2（R14 better-harness 吸收） |
| **评测层** | digest 链式锚定（`ref_trace_hash`：三本账从并列升级为链式，上游篡改全链 stale 可检出）；missing_evidence 态（"该测没测"显式态）；gate-plan 选择即证据（启用/跳过理由负空间可审计）；audit-closure 审计即完成条件（goal 闭环完备性重走） | v2.3（R15 HarnessEval 吸收） |

### 生成物规格

生成的目标技能 = **一张地图 + 一组条件 + 一条演化链**：

- **地图**：组件/接口/约束清单——生成时刻由探查产出，会话中按需 grep（不全量预读）；两列表 `| 路径 | 说明与约束 |`（路径供 path-check 执法，说明列写理解+稳定性标注词）
- **条件**：precheck 门禁（真实 fail 型）+ hooks（fail-gate/integrity-guard，双宿主）+ draft/active 状态门——全部不占认知，做错就被拦
- **演化链**：fingerprint 感知 → scope 局部重探查 → inventory-update 单条更新 → last-good 红线 → 落新基线

每会话固定税（SKILL.md + hooks + settings + conf）≤8KB；概念体系 ≤5（探查/约束/演化/留痕/生成）；冷启动到读项目代码 ≤3 步。

---

## 快速开始

```bash
# ① 安装（自动检测 Claude Code/Codex/Cursor/Windsurf/OpenCode/Gemini/Kimi）
git clone https://github.com/issac-new/Swarm-yuan.git && cd Swarm-yuan
bash install.sh

# ② 为项目生成技能（AI 一键完成：探查→填充→配置→验证全自动）
# 对 AI 说："为 /path/to/project 生成开发技能"
# 或命令行：
bash scripts/generate-skill.sh <skill-name> <project-dir> [target-dir]

# ③ 状态门翻 active（零占位符核验 + 路径存在性 + 闭环完备性）
bash scripts/generate-skill.sh --mark-active <skill-dir>

# ④ 日常使用（对 AI 说话，而非手动跑命令——零手动配置原则）
# "开始新需求：xxx" / "跑门禁" / "升级 skill" / "报了误报"

# ⑤ 任务级门禁计划（负空间可审计，R15）
bash scripts/gate-plan.sh <项目根> --plan "enable:check_branch,check_test|skip:check_compliance(非合规项目)"
bash scripts/gate-plan.sh <项目根> --diff   # 收口 diff 计划 vs 实际触发

# ⑥ 闭环完备性（审计即完成条件，R15）
bash scripts/audit-closure.sh <项目根> --strict   # 有 open goal → exit 2
```

---

## 运行时三层接线 + 领域知识

**运行时**（只引用调用不重新实现，按接线深度分三层；`../docs/upstream-baseline.md` 登记运行时的仓库/许可证/基线版本/drift 状态）：

| 层 | 运行时 | 接线方式 |
|----|--------|---------|
| 深度接线 | GitNexus / graphify / claude-mem / ocr | precheck.sh 门禁内真实子进程调用 + 多级降级链 |
| CLI 接线 | OpenSpec / comet / gsd-core / codex-security | 门禁/状态机按需调用 CLI（`openspec validate`/`comet guard`/`gsd-tools validate health`）+ 降级到自带载体 |
| 方法论引用 | superpowers / gstack / Ruflo / ECC / impeccable | AI 按 workflow 节点引用其模式，swarm-yuan 自带等价降级载体 |

每层有自带降级载体，未装运行时时不阻塞（fail-open + 降级），不假装全深度接线。`--upstream-baseline` 门禁（advisory）自动检测 upstream drift，CI 可见但不阻断构建。

**领域知识**：数据库 ACID / 网络 CORS / 安全密码哈希 / IM 消息保序 / 电商库存原子扣减 / 金融金额 Decimal……多领域客观规律（详见 `references/domain-knowledge.md`，计数真值见 facts.conf）。AI 探查时识别技术+业务领域，推导客观规律驱动 `--domain` 违规检测——防达克效应（对不熟悉的领域自信地写出错误代码）。

---

## 零占位符 + 自举

**零占位符**：AI 执行完整生成流程后由脚本机器执法（`--verify-completeness`）——零残留才算完成，命中"待填充"/"填充指引"/占位符即列 file:line 并 exit 1。

**自举**：swarm-yuan 能用自身的门禁检查自身（CI `generator-self-gate` job 三档 RC=0）。**自举证明的边界**：自举只证明"门禁规则与自身代码一致"（内部自洽），**不证明**"门禁能拦截真实缺陷"（外部有效）——后者由 `verifier/v1` 的行为等价与 `../docs/research/R9-paradigm-realworld-test.md` 的真实项目测试覆盖；R9 已诚实披露 5 个真实项目中 fixture 套件漏掉 3 个 P0/P1 bug（fixture 用构造的最小样例，与真实项目有差距）。外部有效性的进一步证据见 `verifier/v2/external-validity.md`（立项稿）。

---

## 质量基线（facts.conf 真值，不手抄）

- 门禁：四族全部有真实触发路径（可达率 54/54，`FACT_GATES_TOTAL` 机器对账）
- 配置：物理变量保留（兼容既有生成物）；user 面必配 ≈ 20 项（开关/路径/预算，`FACT_CONF_VARS_USERFACE`）
- references：全部带"何时读我"路由头（孤儿资产 = 0，self-check G18 断言）
- 生成物税：SKILL.md ≤8KB / 认知面 references 拷贝 ≤256KB（断言过）
- 测试：17 测试脚本 + gen-e2e + self-check 全 PASS（CI：ubuntu/macos/windows 三平台）

详细设计见 `../docs/DESIGN.md`（单一设计事实源，§0–§11）；演化史与决策记录见 `../docs/paradigm-decisions.md`（决策 1-35 索引）；落地案例见 `references/case-studies/articulation-orchestration.md`。

## License

MIT — see [LICENSE](../LICENSE)
