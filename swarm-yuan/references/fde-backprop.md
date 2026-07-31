# FDE 反向传播纪律（Forward Deployed Engineer = Human Backpropagation）

> 理念来源：Palantir Forward Deployed Engineering = "the human equivalent of backpropagation, in which teams of engineers get as close as possible to a problem while working in concert with core engineering teams" to "relentlessly synthesize feedback and ship new features"（`/docs/foundry/architecture-center/overview/`，R11 调研 §1.7 吸收）。
> 决策 29（2026-07-31，`docs/paradigm-decisions.md`）：把 swarm-yuan 的 forward deploy / backprop 不对称形式化——forward 强（每项目生成专属技能 + memory-writeback 三路写回），backprop 弱/手工（R1-R9 调研 + WP-* 批次都是人工捕获）。本文件定义反向传播纪律，0 新门禁，0 新变量。

## 1. 问题：forward 强、backprop 弱

swarm-yuan 的 **forward deploy** 已落地：
- `generate-skill.sh <name> <project-dir>` 对每个项目 forward-deploy 专属技能（`SKILL.md:85`）
- `memory-writeback.sh` 三路写回 `.swarm-yuan/project-knowledge.md` / `.zcode/memories/` / claude-mem（`SKILL.md:106`）
- 每项目的 `decisions.jsonl`（决策审计轨迹）+ `trace.jsonl`（调用轨迹）记录运营反馈

但 **backprop 到核心**（swarm-yuan 模板）是**手工**的：
- `docs/research/R1-R11` 调研文档靠人工撰写
- `docs/paradigm-decisions.md` 决策记录靠人工捕获
- WP-* 批次提交靠人工识别"哪些模式值得回传核心"

**偏倚风险**：R9 已暴露"5 项目清一色 Java/JS Web"样本偏倚（`docs/research/R9` R10 待测品类段）。反向传播弱 → 核心模板只反映 Java/JS Web 品类的教训，C/Rust/Go/嵌入式品类的模式不会被回传。

## 2. 反向传播纪律

**触发条件**：每 N 个 forward deploy 后（N 可配，建议 5），执行一次反向传播周期。

**执行流程**：

### 2.1 聚合（机器辅助）

跑 `scripts/cost-report.sh` 聚合 N 个项目的 `.swarm-yuan/decisions.jsonl` + `.swarm-yuan/trace.jsonl`：

```bash
# 对每个 forward-deploy 过的项目，聚合决策与轨迹
for proj in <N 个项目路径>; do
  bash scripts/cost-report.sh --project "$proj" --aggregate
done
```

### 2.2 模式提取（机器辅助，AI 主导）

从聚合数据提取两类高频模式：

| 模式类型 | 提取方法 | 回传目标 | 示例 |
|---------|---------|---------|------|
| **高频 UserChallenge** | 统计 decisions.jsonl 中 `type=UserChallenge` 的 `ai_suggestion` 关键词分布，占比 >30% 的主题 | 核心模板对应 reference 的纪律补强 | "依赖升级"占比 >30% → `references/security-spec.md` 补版本锁定纪律 |
| **高频门禁 fail** | 统计 trace.jsonl/gate-runs.jsonl 中 fail 集中的门禁 + 触发文件特征 | 特征卡填充指引 / 门禁检测规则补强 | `--reuse` fail 集中在某类组件 → `exploration-guide.md` §11 补该类组件的稳定单元识别规则 |

### 2.3 落地（人工审阅，非自动改核心模板）

提取的模式作为 **WP-* 批次的输入**，由人工（或 AI 主导 + 用户决策，对齐 G1）审阅后落地：
- 模式是否值得回传核心？→ 价值评估（守"新增须等额删除"决策 26 的精神）
- 回传到哪里？→ references 文档 / SKILL.md 叙事 / 门禁检测规则 / 特征卡填充指引
- 是否新增门禁？→ **默认不新增**（守决策 27：吸收优先）；仅当概念无法以方法论吸收且不机器执法会致范式失真才考虑

**关键**：反向传播**不自动改核心模板**——守"AI 主导+用户决策"原则。聚合与模式提取是机器辅助，落地决策是人工/AI 主导+用户批准。

## 3. 与 Palantir FDE 的映射

| Palantir FDE | swarm-yuan 对应 |
|--------------|----------------|
| FDE 嵌入客户运营现实 | 生成器 forward-deploy 到每项目（`generate-skill.sh`） |
| FDE 产生信号 | 每项目的 `decisions.jsonl`/`trace.jsonl` 记录运营反馈 |
| FDE = human backpropagation | 反向传播周期（§2）把项目信号回传核心模板 |
| core engineering 泛化模式 | WP-* 批次把模式沉淀进 swarm-yuan 核心 |
| 客户特定定制随时间沉淀为平台特性 | 项目特定教训随时间沉淀为核心模板更新 |

## 4. 与现有机制的关系

- **与 `memory-writeback.sh` 的关系**：memory-writeback 是**项目内**闭环（记忆→生成→开发→记忆，`SKILL.md:106`）；反向传播是**跨项目**闭环（N 个项目→核心模板）。两者正交：前者管单项目记忆持久化，后者管跨项目模式回传。
- **与 `cost-report.sh` 的关系**：`cost-report.sh` 已有聚合能力（`SKILL.md:78` 调用级细节聚合）；反向传播复用其聚合输出，不新写脚本。
- **与 R1-R11 调研的关系**：R1-R11 是**人工**捕获的"从项目学到什么"；反向传播纪律是**机器辅助**提取 + 人工落地，降低 R 调研的门槛（不必每次靠人主动写）。
- **与决策 27 的关系**：反向传播提取的模式若催生"新增门禁"冲动，按决策 27 纪律——吸收优先（references 文档/SKILL.md 叙事/G<N> 断言），新增门禁是最后手段。

## 5. 落地要求

本文件是方法论引用层（非门禁），AI 在生成流程 Step 8（AI 最终检查）后、或跨项目复盘时引用本纪律：
1. 询问用户"当前已有几个 forward-deploy 项目？是否到 N=5 触发反向传播周期？"
2. 若触发，跑聚合 + 模式提取，输出"反向传播报告"（高频 UserChallenge / 高频门禁 fail）
3. 用户审阅报告后决定是否启动 WP-* 批次落地

**不强制**：本纪律是 best-effort，不阻塞生成流程，不 fail self-check。目标是降低"从项目到核心"的反向传播门槛，而非新增机器执法。
