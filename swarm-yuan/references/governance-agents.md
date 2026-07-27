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

## Task Contract（任务契约）

四权分离拓扑启动前，主 agent 先把目标拆成任务契约：

```text
intent: <用户要什么，一句话>
acceptance: <可验收的完成标准列表>
forbidden: <禁止行为列表：不改 tests/scoring/verifier/CI/memory/secrets...>
verify_commands: <公开验证命令列表>
file_domain: <允许编辑的文件/目录范围>
```

只允许 action-executor 写 `agent_proposed_status`，最终 `verifier_status` 由
verifier/hook/human 确认。

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

## 文化叙事绑定（不混搭）

swarm-yuan 用「立法 / 执法 / 司法」三权分立隐喻，不用 pua 的大厂 PUA 话术：

| 权力 | swarm-yuan 叙事 | pua 叙事（不采用） |
|------|----------------|-------------------|
| 环境修改权审查 | 立法侧守卫（改规则前须过此关） | 腾讯政委 + Amazon Dive Deep |
| 行动权 | 执法侧执行（按规则改代码） | 阿里 P8 owner + Musk Algorithm |
| 自评权 | 司法侧自检（蓝军自攻击） | 华为蓝军 + Netflix Keeper Test |
| 评分建议权 | 司法侧独立验收（数据驱动） | 字节数据驱动 + 京东结果导向 |

叙事是压力和视角，不是越权理由。四个 agent 互相独立、不可代位、不可自批自评。
