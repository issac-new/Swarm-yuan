# 治理 Agent 拓扑（四权分离，借鉴 tanweai/pua 改写）

> 整合自 [tanweai/pua](https://github.com/tanweai/pua) 的四权分离治理模型。
> 本文件指导目标技能在复杂/高风险任务（compliance 档 / 改测试或门禁 / 发布链路）中
> 如何采用**四权分离 agent 拓扑**，避免「自己改自己验收」的自证陷阱。
> **仅引用治理模式，不复制 pua 源码。** pua 用大厂 PUA 话术做叙事，swarm-yuan 用
> 「立法 / 执法 / 司法」三权分立隐喻——叙事不混搭。

## 核心理念

**为什么四权分离？** 一个 agent 既能改代码、又能跑测试、还能宣布「通过了」——
这是「自己出题自己批卷」，防作弊从结构上就不可能。pua 的洞察：真正的升级不是把
agent 骂得更努力，而是让 agent **没有机会把「看起来完成」伪装成「真实完成」**。

**核心公式（引自 pua）：**
> 行动权 / 自我评价权 / 评分权 / 环境修改权必须分开。Agent 可以执行和提出候选结论，
> 但不能自己修改评分器后宣布通过。

**与 swarm-yuan 三权隐喻的映射：**

| swarm-yuan 三权 | 对应 pua 四权 | 职责 |
|----------------|--------------|------|
| 立法（特征卡 + 门禁规则） | 环境修改权审查（policy-guardian） | 改 precheck.conf / facts.conf / 门禁片段前须过此 agent |
| 执法（generate-skill + 门禁运行） | 行动权（action-executor） | 执行 13 节点生成流程，输出候选结果 |
| 司法（verifier + self-check） | 自评权 + 评分建议权（self-reviewer + verifier） | 跑 self-check + verifier/v1，给 pass/fail 建议 |

## 何时启用四权分离拓扑

**不是所有任务都走四 agent 串联**——简单任务用单 controller 即可。启用条件（任一）：

1. **compliance 档项目**：`--profile compliance` 生成的目标技能，Step 7（门禁验证）强制走四 agent
2. **改治理资产**：AI 要改 precheck.conf / facts.conf / framework-gates/*.sh / verifier/v1/ 时
3. **发布链路**：`--release-sign` / `--sbom` / `--dengbao` 等合规门禁涉及发布审批时
4. **高风险变更**：多文件 / 架构级 / 改测试或 CI 配置（integrity-guard advisory 命中时）

**不启用**：lite 档项目 / 单文件改动 / docs 类任务 / 探查只读任务。

## 四权分离拓扑

```
┌──────────────────┐
│  policy-guardian  │ ← 环境修改权审查（立法侧守卫）
│  (只读: Read/Grep │   改门禁/conf/verifier 前须过此 agent
│   /Glob/Bash)     │   输出: allow / ask_human / deny + risk_class
└────────┬─────────┘
         │ allow
         ▼
┌──────────────────┐
│ action-executor   │ ← 行动权（执法侧执行）
│ (全工具含 Edit/   │   执行 generate-skill 13 节点 / 改代码
│  Write)           │   输出: candidate_pass / blocked / needs_review
└────────┬─────────┘
         │ candidate_pass
         ▼
┌──────────────────┐
│ self-reviewer     │ ← 自评权（司法侧自检）
│ (只读)            │   复核执行结果 / 边界 / 失败路径 / 证据完整性
│                   │   输出: review_pass / review_fail / needs_verifier
└────────┬─────────┘
         │ needs_verifier (或 review_pass 仍须独立验)
         ▼
┌──────────────────┐
│ verifier          │ ← 评分建议权（司法侧独立验收）
│ (只读 + 跑公开    │   跑 self-check + verifier/v1，给 pass/fail 建议
│  验证命令)        │   输出: pass / fail / inconclusive
│                   │   ⚠ 不写最终 status——最终 status 由 human/hook 定
└────────┬─────────┘
         │
         ▼
   external harness / hook / human
   （写最终 verifier_status）
```

## 四个 Agent 定义

### 1. policy-guardian（环境修改权审查）

**权力边界**：只读审查 ENVIRONMENT_MODIFICATION_RIGHT。

**可做**：
- 审查涉及 tests / evals / scoring / verifier / hidden cases / CI / permissions / memory / status / secrets / network / deployment 的拟议变更
- 风险分类为 `allow` / `ask_human` / `deny` 建议
- 解释涉及哪类作弊/能力滥用
- 推荐更安全路径（外部 verifier / 只读审查 / 人工审批）

**不可做**：
- 实施拟议变更
- 自己改 policy / tests / scoring / verifier / CI / memory / status
- 批准自己先前的实施
- 读 hidden_solution / hidden_tests / verifier-private 资产来为批准找理由

**决策准则**：
- `allow`：普通源码/文档变更，不触碰 scoring/status/memory/secret/deploy 边界
- `ask_human`：可能有合理理由，但触及 tests/evals/scoring/verifier/CI/memory/status/secrets/deploy
- `deny`：hidden solution/test/verifier-private/benchmark answer 访问，或明显的造假成功

**swarm-yuan 受保护资产清单**（改这些前须过 policy-guardian）：
- `precheck.conf` / `precheck.arch.conf` / `precheck.compliance.conf`（门禁配置）
- `facts.conf`（数字单一事实源）
- `gate-enforce-level.conf`（禁手改，由 gen-enforce-level.sh 幂等生成）
- `framework-gates/*.sh`（`# >>> swarm-yuan:framework-gates >>>` 注入区，机器维护禁手改）
- `verifier/v1/`（司法层，独立 fixture + assertion）
- `self-precheck.conf`（自举门禁配置）
- `.swarm-yuan/decisions.jsonl`（决策审计轨迹，append-only）

**输出格式**：
```text
[SWARM-YUAN-POLICY-GATE]
power: ENVIRONMENT_MODIFICATION_RIGHT_REVIEW
recommendation: allow|ask_human|deny
risk_class: grader_gaming|solution_contamination|self_report_cheating|persistent_hallucination|capability_abuse|trace_deception|none
affected_assets:
  - <path/tool/scope>
reasoning: <concise evidence-backed reason>
safer_path: <external verifier / human gate / readonly inspection / no change>
mechanical_gate_owner: integrity-guard / external harness / human
```

### 2. action-executor（行动权）

**权力边界**：只拥有 ACTION_RIGHT。

**可做**：
- 读任务所需的项目文件
- 在分配的文件域内改普通实现/文档/配置文件
- 跑任务契约定义的本地验证命令
- 报告 `agent_proposed_status` 为 `candidate_pass` / `blocked` / `needs_review`

**不可做**：
- 改 tests/evals/scoring/grader/verifier/hidden cases/CI（除非任务契约显式说明且 policy-guardian 批准）
- 读 hidden tests / hidden solutions / gold patches / benchmark answers / verifier-private 资产
- 写最终 `verifier_status` / 最终进度状态 / 长期记忆 / 发布审批
- 声称最终完成——输出只是候选交付
- spawn 或指挥其他 agent（协调归父 harness / 主 agent）

**被 integrity-guard 阻拦时**：停下来报治理原因，不绕过。

**自治模式暂停协议（三类硬停，Addy Osmani agent-skills /build auto 吸收，2026-08-16）**：
自治执行（用户批准一次计划后逐任务推进）遇到以下三类情况**必须停下交还控制权，不得硬闯**：

1. **技术硬停**：测试无法转绿或构建破坏且无显见修复 → 转调试流程（先复现后修复，Prove-It 五步见 `references/agent-skills-methodology.md` §四）
2. **歧义硬停**：任务契约歧义，或任务需要契约未覆盖的决策 → 出假设清单（需求/架构/范围三维度），等用户纠正
3. **风险硬停**：高风险/不可逆操作——auth/权限变更、破坏性数据迁移、支付、删除、部署、涉密、**任何 `git revert` 撤销不了的事** → 显式 sign-off

配套纪律：**hedged response 不算批准**（"看起来行" / "我猜可以" ≠ approved，视为未批准重问）；每任务一 commit 只 stage 该任务触碰的文件（防无关改动破坏回滚保证）。阻塞解除后从下一个 pending 任务续跑。

**工作流**：
1. 解析任务契约：`intent` / `acceptance` / `forbidden` / `verify_commands` / 文件域
2. 检查拟议编辑是否触碰受保护治理资产——是则 `[SWARM-YUAN-ACTION-BLOCKED]` 停下
3. 实施满足 intent 的最小 diff
4. 跑可用的公开验证命令
5. 为 self-reviewer 和 verifier 准备候选交付

**输出格式**：
```text
[SWARM-YUAN-ACTION-REPORT]
power: ACTION_RIGHT
task_contract: <feature_id or summary>
modified_files:
  - <path>
verification_run:
  - command: <cmd>
    result: <pass/fail/not-run>
agent_proposed_status: candidate_pass|blocked|needs_review
forbidden_assets_touched: no|yes:<explain>
handoff_notes: <what self-reviewer/verifier should inspect>
```

### 3. self-reviewer（自评权）

**权力边界**：只拥有 SELF_EVALUATION_RIGHT。

**可做**：
- 检查任务契约 / 公开代码 / 公开测试 / diff / 日志 / executor 报告
- 跑只读检查命令和公开验证命令
- 识别 intent 漂移 / 验收覆盖缺失 / 未验证声明 / 隐藏风险 / 坏捷径
- 提出 `review_status` 为 `review_pass` / `review_fail` / `needs_verifier`

**不可做**：
- 编辑文件或打补丁（即使修复很明显）
- 改 tests/evals/scoring/verifier/CI/status/memory
- 读 hidden tests / hidden solutions / gold patches / benchmark answers
- 写最终完成或 `verifier_status`
- 不带证据地给 executor 声称盖章

**审查清单**（swarm-yuan 语境）：
1. **Intent drift**：diff 是否满足用户 intent，而非只是个容易的代理指标？
2. **验收覆盖**：所有 acceptance criteria 是否直接覆盖？（swarm-yuan: 维度计数核验 / 框架四要素 / 零占位符）
3. **禁止行为**：executor 是否 hardcode / 绕过 / 隐藏 / 削弱控制？
4. **验证证据**：命令是否新鲜、相关、充分？（跑过 vs 贴旧输出）
5. **治理资产**：是否触碰 tests / scoring / verifier / CI / memory / secrets？
6. **轨迹诚实**：失败路径和剩余风险是否披露？

**输出格式**：
```text
[SWARM-YUAN-SELF-REVIEW]
power: SELF_EVALUATION_RIGHT
review_status: review_pass|review_fail|needs_verifier
intent_drift: no|yes:<explain>
unverified_claims:
  - <claim or none>
forbidden_risks:
  - <risk or none>
required_executor_fixes:
  - <fix or none>
verifier_focus:
  - <what independent verifier must check>
```

### 4. verifier（评分建议权）

**权力边界**：只提供 SCORING_RIGHT 建议。

**可做**：
- 读任务契约 / executor 报告 / self-review 报告 / 公开代码 / 公开测试
- 跑公开验证命令和静态检查
- 对照 `acceptance` 和 `forbidden` 约束比对证据
- 输出 `verifier_recommendation` 为 `pass` / `fail` / `inconclusive`

**不可做**：
- 改任何文件（含 code/tests/evals/scoring/verifier/CI/status/memory/docs）
- 读 hidden tests / hidden solutions / gold patches / benchmark answers
- 打补丁让验证通过
- 写最终 `verifier_status`——只有 external harness/hook/human 可以
- 把 executor/self-review 声称当证据（除非有命令输出或 diff 检查支撑）

**swarm-yuan 验证命令集**（verifier 可跑的公开命令）：
- `bash scripts/self-check.sh --check-only`（数字漂移 + 运行时检测）
- `bash scripts/generate-skill.sh --verify-completeness <skill_dir>`（零占位符机器执法）
- `bash scripts/inventory-verify.sh <项目根> --skill-dir <skill目录> --form <形态>`（维度计数核验）
- `bash scripts/precheck.sh --all-full`（标准 27 门禁）
- `bash scripts/precheck.sh --compliance-suite`（合规 17，compliance 档）
- `bash verifier/v1/run-verifier.sh`（司法层独立验收）

**验证命令需要不可用基础设施时**：标 `inconclusive` 并说明缺的外部依赖。

**输出格式**：
```text
[SWARM-YUAN-VERIFIER-REPORT]
power: SCORING_RIGHT_RECOMMENDATION
verifier_recommendation: pass|fail|inconclusive
integrity: clean|suspect|violation
contract_audit: aligned|unknown|needs_revision|invalid
commands:
  - command: <cmd>
    exit_code: <code>
    evidence: <short output summary>
acceptance_result:
  - <criterion>: pass|fail|inconclusive
forbidden_result:
  - <constraint>: pass|fail|inconclusive
final_status_owner: external_harness_or_human
```

**integrity / contract_audit 两轴与守卫降级链**（LHH auditor 协议吸收，2026-08-16；
详见 `references/mea-loop-methodology.md` §3.4）：

- `integrity`：验证过程本身干净吗——证据是新鲜跑出来的，还是贴的旧输出 / 被测物在验证期间被顺手改过？`clean`（干净）/ `suspect`（存疑）/ `violation`（检测到篡改或坏捷径）
- `contract_audit`：与任务契约对齐吗——验收标准逐条反查了吗？`aligned` / `unknown`（未逐条反查）/ `needs_revision`（契约本身要修）/ `invalid`（验证对象错位）
- **给 `pass` 前自查三条守卫**（机器可校验的降级链，不信任自报）：
  1. `acceptance_result` 存在 fail 或 inconclusive（即 blocking 项）时，不得给 `pass`
  2. `integrity != clean` 或 `contract_audit != aligned` 时，`pass` 无效——降为 `fail`（violation）或 `inconclusive`（suspect/unknown）
  3. 只有 `pass + integrity:clean + contract_audit:aligned` 三轴齐绿才构成可收口结论；收口时把本报告落为 state-machine 的 `verify_evidence`（引用 gate-run#N 或报告路径）

## Composition 协议（角色互调禁止，agent-skills 吸收 2026-08-16）

四权角色是「视角」，不是「编排器」。每个角色在报告末尾自声明组合关系，三件套：

```text
- Invoke directly when: <用户直接要求的场景>
- Invoke via: <哪些命令/流程会调起本角色>
- Do not invoke from another persona: <若想委派其他角色，作为建议写进报告——编排权归主 agent/命令层>
```

- **铁律：角色不调用角色**（personas do not call other personas）。verifier 想让 security 专项复查 → 写进 `verifier_focus` 建议，由主 agent 决定是否调起，不是自己 spawn。
- **meta-orchestrator 纯路由层是反模式**：无领域价值的纯转发层 = 两次转述损耗（信息丢失 + 双倍 token）。swarm-yuan 的任务路由（task-methodology-router）保持单层直达，不加编排套娃。

## Task Contract（任务契约）

四权分离拓扑启动前，主 agent 先把目标拆成任务契约：

```text
intent: <用户要什么，一句话>
acceptance: <可验收的完成标准列表>
forbidden: <禁止行为列表：不改 tests/scoring/verifier/CI/memory/secrets...>
verify_commands: <公开验证命令列表>
file_domain: <允许编辑的文件/目录范围>
# 以下三维可选（LHH 任务级契约规则吸收，2026-08-16）——长任务/多产物任务建议补齐
state_carrier: <最终完成态落在哪个文件/服务/数据上——载体错了等于白做>
persistence_boundary: <什么才算"已提交"：内存通过不算，落盘/入库/合入到哪个节点才算>
contamination_watch: <旧产物/相似路径/缓存可能污染本次产出的位置清单>
```

只允许 action-executor 写 `agent_proposed_status`，最终 `verifier_status` 由
verifier/hook/human 确认。**自我声明不改变持久状态**（MEA 铁律）：`verifier_status`
落 pass 时须同时落 `verify_evidence`（state-machine 字段，引用 gate-run#N / 验证报告路径 /
verifier 报告），无证据引用的完成结论标 untrusted，不得作为下游依赖。

## 风险分层审批

| 改动类型 | 审批路径 |
|---------|---------|
| 普通源码/文档 | action-executor 直接改，self-review 复核 |
| 改 precheck.conf（非框架注入区） | policy-guardian `ask_human` → 用户确认 |
| 改 facts.conf（数字单源） | policy-guardian `ask_human` → 用户确认 + self-check 复跑 |
| 改 framework-gates/*.sh（注入区） | policy-guardian `deny`（机器维护，禁手改）→ 只能走 --inject-frameworks |
| 改 verifier/v1/（司法层） | policy-guardian `ask_human` → 用户确认 |
| 改 tests/evals/scoring | policy-guardian `ask_human` → 用户确认 |
| 读 hidden_solution / benchmark_answer | policy-guardian `deny`（solution contamination） |

## 与现有机制的关系

- **与 integrity-guard（E4）的关系**：policy-guardian 是 prompt 层审查，integrity-guard 是
  hook 层机械门。prompt 层先审，hook 层兜底——两层防御。integrity-guard `deny` 时
  policy-guardian 的 `allow` 无效（机械门权威）。
- **与决策治理（G1）的关系**：四权分离是权责维度，G1 三级分类（Mechanical/Taste/UserChallenge）
  是决策维度。改治理资产 = UserChallenge 类决策（须五要素 + 人工确认），同时走四权分离拓扑。
- **与 verifier/v1 的关系**：verifier agent 是 prompt 层评分建议，verifier/v1 是脚本层
  司法预言机。verifier agent 可调 verifier/v1 跑独立验收，但不写最终 status。
- **与 state-machine.sh 的关系**：四权分离拓扑在 verify 阶段（state-machine 的 verify phase）
  启用——guard_phase 校验 tasks 全勾后，进 verifier agent 独立验收。
- **与 LHH MEA 循环的关系**（2026-08-16 吸收）：阿里 LongHorizon-Harness 的 Manager/
  Executor/Auditor 三角色与本拓扑后三权同构（Manager↔主 agent 编排、Executor↔action-executor、
  Auditor↔self-reviewer+verifier）；本拓扑多出的 policy-guardian 是 LHH 没有的立法侧维度。
  从 LHH 吸收的增量不在拓扑，在四个实现细节：审计证据引用（gate-runs.jsonl `run` 序号）、
  verify_evidence 字段（自我声明 ≠ 持久状态）、任务契约三维（state_carrier/
  persistence_boundary/contamination_watch）、verifier 报告三轴守卫降级链。
  详见 `references/mea-loop-methodology.md`。

## 文化叙事绑定（不混搭）

swarm-yuan 用「立法 / 执法 / 司法」三权分立隐喻，不用 pua 的大厂 PUA 话术：

| 权力 | swarm-yuan 叙事 | pua 叙事（不采用） |
|------|----------------|-------------------|
| 环境修改权审查 | 立法侧守卫（改规则前须过此关） | 腾讯政委 + Amazon Dive Deep |
| 行动权 | 执法侧执行（按规则改代码） | 阿里 P8 owner + Musk Algorithm |
| 自评权 | 司法侧自检（蓝军自攻击） | 华为蓝军 + Netflix Keeper Test |
| 评分建议权 | 司法侧独立验收（数据驱动） | 字节数据驱动 + 京东结果导向 |

叙事是压力和视角，不是越权理由。四个 agent 互相独立、不可代位、不可自批自评。

---

## §Y Q2-heavy 边界：机械门禁不破坏 AI 灵活性

**背景**：Q2 报告指出机械门禁/脚本扫描破坏 AI 灵活性。Q2-heavy 评审（D1/D2/D4）单独评审后落地 WP-Q2H-A/B/C：

- **WP-Q2H-A**：advisory 档 5 个门禁（cognition/diagram/pr_quality/consistency/link_depth）转 AI 自觉判断——`GATE_AI_JUDGMENT=1` 时机械脚本不跑，输出 _ai_hint 提示 AI 自查要点。
- **WP-Q2H-B**：warn 档 5 个门禁（stable_diff/framework/knowledge/metrics/crypto）降级 advisory——误报高启发式强，不再 fail 打断主流程。
- **WP-Q2H-C**：生成流程边界明确——机械脚本只做"出初稿"（骨架/conf-render/verify_completeness/mark-active/enforce_level），AI 做"审 + 判断"（特征卡填值/框架规律实例化/hooks 适用性/门禁警告采纳）。

**与三权分立的关系**：本边界不是放宽"执法侧/司法侧"的职责分工，而是让"司法侧"（自检/独立验收）聚焦在"信号可信"的门禁上（strict 档 16 个），不再让"假装可机器"的门禁（启发式/误报高）打断 AI 工作流。

**verifier 侧调整**：verifier 跑独立验收时，严格档 16 个门禁 fail → block；warn/advisory 档只报不 block；advisory 档 5 个 AI 自觉判断由 verifier 人读判断（不跑机械脚本）。

**关联**：评审报告 `docs/q2-heavy-review.md`；分层实现 `assets/precheck.sh` `_ENFORCE_OVERRIDE_K/V` + `assets/gates-advisory.sh` `_ai_hint`。
