# swarm-yuan — 让 AI 懂你的项目，再写代码

> 从「AI 辅助写代码」到「AI 懂项目再写代码」的认知基础设施。
>
> **两体系统**：生成器厚（探查全量，一次性消费）、生成物薄（每会话固定税 ≤8KB、概念体系 ≤5）；范式作为条件而非内容。
> **三层 Harness 拼图**：过程强制门禁层（rules.d 三值 + hooks 双宿主）+ 工作流审计层（goal_id+closure 目标闭环 + 证据态分级）+ 评测层（digest 链式锚定 + 选择即证据 + 审计即完成条件）。
> 计数真值见 `assets/facts.conf`（不手抄；`scripts/self-check.sh` 机器执法）。

[![Release](https://img.shields.io/badge/release-v2.4-blue)](https://github.com/issac-new/Swarm-yuan/releases/tag/v2.4)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)]()

---

## 为什么需要它

AI 的代码生成能力已经很强，但「项目认知」仍是被多数工具忽视的环节——改了不该改的文件、升级了不该升级的依赖、重复造了已有组件的轮子、检查靠人工逐行 review。

swarm-yuan 是**元技能生成器**：为任意代码仓库生成项目专属开发技能（"目标技能"），核心闭环 = **探查**（全量组件库清单 + 调用链分析）→ **门禁**（三值规则 + hooks 强制）→ **自成长**（项目变了技能跟着变）。

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
| **工作流审计层** | 审计单元目标闭环化（`goal_id`+`closure`：一个用户目标+一个验收边界，change↔validation 链接才 closed）；证据态分级（配置≠使用≠有效：Present/Wired/Exercised/Outcome-supported）；双账本（当窗验证 repair_verified_rate + guardrail 配对）；修复复核位（repair_review） | v2.2（R14 better-harness 吸收） |
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
bash swarm-yuan/install.sh

# ② 为项目生成技能（AI 一键完成：探查→填充→配置→验证全自动）
# 对 AI 说："为 /path/to/project 生成开发技能"
# 或命令行：
bash swarm-yuan/scripts/generate-skill.sh <skill-name> <project-dir> [target-dir]

# ③ 状态门翻 active（零占位符核验 + 路径存在性 + 闭环完备性）
bash swarm-yuan/scripts/generate-skill.sh --mark-active <skill-dir>

# ④ 日常使用（对 AI 说话，而非手动跑命令——零手动配置原则）
# "开始新需求：xxx" / "跑门禁" / "升级 skill" / "报了误报"

# ⑤ 任务级门禁计划（负空间可审计，R15）
bash scripts/gate-plan.sh <项目根> --plan "enable:check_branch,check_test|skip:check_compliance(非合规项目)"
bash scripts/gate-plan.sh <项目根> --diff   # 收口 diff 计划 vs 实际触发

# ⑥ 闭环完备性（审计即完成条件，R15）
bash scripts/audit-closure.sh <项目根> --strict   # 有 open goal → exit 2
```

---

## 设计原则（终态）

| 原则 | 含义 |
|------|------|
| 落地优先于删除 | 概念/门禁/profile/references 一概不删——病根是"没有正确落地"（机械打分/僵尸孤立/无路由），全部转为真实消费路径 |
| 范式作为条件而非内容 | 机器执法只保留"防 AI 说谎"的条件类（path-check/计数核验/last-good/状态门/三值规则/FORBID 带替代）；AI 的理解深度由行为证据兜底，不由表格验证 |
| 拼装式开发 | 新功能 = 既有稳定单元拼装 + 最小新增胶水代码；禁止重复造轮子/侵入式重构/破坏性改造（奠基期用户原话，是探查的应用层目的） |
| AI 全自动、零手动配置 | 生成 skill 是 AI 一键完成；使用时研发人员对 AI 说话而非手动跑命令；SKILL.md 是 AI 读的（写"零手动"铁律），USAGE 层保留 bash 双轨制 |
| 审计是闭环不是事件 | 审计单元是"一个用户目标+一个验收边界"；证据态分级（配置≠使用≠有效）；审计即完成条件 |
| 失败方向教义 | 权限边界一律 fail-closed；fail-open 只允许在有下层强制兜底处 |
| 落地案例诚实化 | 门禁外部有效性目前在 Java/JS Web 品类上验证（R9），跨品类见 `verifier/v2/external-validity.md` 立项稿 |

详细设计见 `../docs/DESIGN.md`（单一设计事实源，11 章）；演化史与决策记录见 `../docs/paradigm-decisions.md`（决策 1-34 索引）。

---

## 质量基线（facts.conf 真值，不手抄）

- 门禁：四族全部有真实触发路径（可达率 54/54，`FACT_GATES_TOTAL` 机器对账）
- 配置：物理变量保留（兼容既有生成物）；user 面必配 ≈ 20 项（开关/路径/预算，`FACT_CONF_VARS_USERFACE`）
- references：全部带"何时读我"路由头（孤儿资产 = 0，self-check G18 断言）
- 生成物税：SKILL.md ≤8KB / 认知面 references 拷贝 ≤256KB（断言过）
- 测试：17 测试脚本 + gen-e2e + self-check 全 PASS（CI：ubuntu/macos/windows 三平台）

## License

MIT — see [LICENSE](../LICENSE)
