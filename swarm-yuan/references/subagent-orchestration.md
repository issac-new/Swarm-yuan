# Subagent 编排模式 (Subagent-Driven Development)

> 整合自 [superpowers](https://github.com/obra/superpowers) 的 `subagent-driven-development` 方法论。
> 本文件指导目标技能的 workflow 节点⑤（编码实现）如何采用 subagent 编排模式。
> **仅引用方法论模式，不复制 superpowers 源码。**

## 核心理念

**为什么用 subagent？** 上下文隔离。为每个任务派发一个全新的 subagent，精确构造其指令与上下文，使其专注并成功完成任务。subagent **不继承**主会话的上下文与历史——你构造它正好需要的内容。这也保留主会话的上下文用于协调工作。

**核心公式（引自 superpowers）：**
> Fresh subagent per task + task review (spec + quality) + broad final review = high quality, fast iteration

## Orchestrator / Spawn-Collect 循环

主会话（controller）的职责是**协调**，不是直接编码：

```
1. 读 plan 一次，记录上下文 + 全局约束，创建 todos
2. Pre-Flight Plan Review — 扫描一遍，找出相互矛盾或违反全局约束的任务；
   批量汇总成一个问题问人（不是一个发现一个中断）
3. 每任务循环：
   a. 派发全新 implementer subagent（带 task brief）
   b. 若 implementer 提问 → 回答、提供上下文、重新派发
   c. implementer 实现、测试、提交、自审，回报状态
   d. controller 派发 task reviewer subagent（审查 spec 合规 + 代码质量）
   e. 若有问题 → 派发 fix subagent → 重新审查
   f. 标记任务完成 + 追加 progress ledger；下一个任务
4. 全部任务完成后 → 派发 final whole-branch reviewer → 收尾
```

## 文件交接（Context Hygiene）

**铁律：粘贴进 dispatch prompt 的内容会常驻 controller 上下文整个会话。** 所以交接用**文件路径**，非粘贴文本：

- task brief → 写入唯一命名的文件，prompt 里只给路径（"read this first — it is your requirements"）
- implementer 报告 → 写入 report 文件（`task-N-report.md`），prompt 里给路径 + 报告契约
- 审查包 → diff 写入文件，reviewer prompt 给文件路径

dispatch prompt 应含：(1) 一句话说明任务位置；(2) brief 路径；(3) 前序任务的接口/决策；(4) controller 对歧义的裁决；(5) report 路径 + 报告契约。

> 反模式（引自 superpowers）：一个真实会话的 dispatch 达 42k 字符，其中 99% 是粘贴的历史。

## 状态回报契约

implementer 回报**仅**短状态 + 提交 + 一行测试摘要 + concerns + report 路径：

| 状态 | 含义 | controller 处理 |
|------|------|----------------|
| `DONE` | 完成且自审通过 | 派发 reviewer |
| `DONE_WITH_CONCERNS` | 完成但有顾虑 | reviewer 重点看 concerns |
| `NEEDS_CONTEXT` | 需要更多信息 | 回答后重新派发 |
| `BLOCKED` | 无法继续 | 见下方处理 |

**BLOCKED 处理（引自 superpowers，不可忽略）：**
1. 上下文问题 → 提供更多上下文，同模型
2. 需要推理 → 用更强模型
3. 任务太大 → 拆分
4. plan 错了 → 上报人类

> "绝不忽略 escalation，也绝不迫使同一模型无变化地重试。"

## 两阶段审查

每任务完成后，派发 **task reviewer**，产出**两个判决**：

1. **Spec 合规** — 实现是否符合 spec/proposal 的要求
2. **代码质量** — 可读性、测试覆盖、错误处理、风格

若有 Critical/Important 发现 → 派发 fix subagent → 重新审查。Minor 发现记入 ledger，留待 final review。

**final whole-branch review** — 全部任务完成后，对整个分支做一次广审。

## 持久化进度（Progress Ledger）

**铁律：对话记忆不抗 context compaction。** 用 ledger 文件持久化进度：

- 位置：`<repo-root>/.swarm-yuan/sdd/progress.md`（或项目约定路径）
- 启动时 `cat` ledger；标记完成的任务 = DONE，不重新派发，从第一个未完成任务恢复
- 干净审查后追加：`Task N: complete (commits <base7>..<head7>, review clean)`

> 引自 superpowers："controllers that lost their place have re-dispatched entire completed task sequences — the single most expensive failure observed."

## 连续执行

**不要在任务之间停下来 check-in。** 执行 plan 的所有任务不停顿。停止的唯一理由：
- 无法解决的 BLOCKED
- 真正阻碍进展的歧义
- 所有任务完成

> "'Should I continue?' prompts and progress summaries waste their time."

## 模型选择

每次派发**显式指定模型**（省略会静默继承会话最贵模型）：
- 转录级任务（plan 已含完整代码）→ 便宜模型
- 集成任务 → 中档
- 架构与 final review → 最强模型

> "Turn count beats token price" — 最便宜模型在多步任务上要 2-3 倍轮次，reviewer/prose 实现者至少用中档。

## 构造 reviewer prompt 的禁忌

- 不要加开放式"检查所有用法"
- 不要让 reviewer 重跑 implementer 已跑过的测试
- **绝不预判发现**（"do not flag"、"treat as Minor at most"）— 让 reviewer 提出，在循环中裁决
- 全局约束块是 reviewer 的"注意力镜头"——从 spec 逐字复制精确值/格式/关系

## 与目标技能的整合

目标技能的 workflow 节点⑤应：
1. 引用本文件作为 subagent 编排指南
2. 在 plan-template.md 的 header 标注执行方式（subagent-driven 推荐 / inline 备选）
3. 在 scripts/state-machine.sh 中实现阶段状态持久化（survive compaction）
4. 在 dev-guide.md 的"任务流程填充"段引用本编排模式
