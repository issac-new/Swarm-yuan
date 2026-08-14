# Codex 执行纪律方法论（OpenAI Codex CLI 吸收——省 token / 高效 / 质量三线）

> 来源：[openai/codex](https://github.com/openai/codex)（Rust 实现的本地编码 agent，Apache-2.0，2026-08 调研，基于官方文档 + `codex-rs` 源码实证：`compact.rs`/`compact_token_budget.rs`/`truncation.rs`/`prompts/templates/compact/*`/`review/rubric.md`/`protocol/src/prompts/base_instructions`）。
> 纪律：**非运行时接线**——Codex 虽是 swarm-yuan 的 7 个安装目标之一（install.sh 检测），本文不调用 codex CLI，只吸收其「为什么省 token、效率高、质量高」的执行纪律，供生成目标技能的 AI 遵守 + 编织进目标技能的 workflow/执行 prompt。对齐决策 27 吸收模式（cordis/context-engineering-layering 先例），不新增门禁（守决策 26）。

## 一、省 token 三件套（截断—压缩—缓存，全部是硬机制非玄学）

Codex 官方 `--json` 实测：`input_tokens: 24763, cached_input_tokens: 24448`——**98.7% 缓存命中**。三条机制叠加达成：

### 1.1 工具输出 head+tail 双端截断（只截一次）

- 每条 shell/工具输出设 **token 预算**（等价 Codex `tool_output_token_limit`），超限**保留首尾、截中间**，插入 `…N tokens truncated…` 标记（形如 `1..19 [截断标记] 129..150`——头部尾部都留，因为开头通常是错误信息、结尾通常是汇总）。
- **只截断一次**：对已截断内容不二次截断（防截断叠加膨胀）。
- 每条 shell 输出带结构化头：`Exit code / Wall time / Total output lines`——让 AI 用最少 token 判断成败，不必重读输出正文。
- **禁止绕过**：不用 python 脚本输出大段文件内容（防借道绕过截断）。

> **目标技能落地**：workflow 的执行 prompt 写明「跑测试/lint 输出超 ~500 行时只留头尾各 30 行 + 截断标记 + Exit code 行」；swarm-yuan 的 `trace-log.sh` 已带结构化字段（ts/gate/status/ids/duration），生成技能沿用此纪律。

### 1.2 CONTEXT CHECKPOINT 压缩（四段交接模板）

Codex 的 compaction prompt 原文结构（`prompts/templates/compact/prompt.md`）——为「另一个将接手的 LLM」写交接摘要：

1. **Current progress and key decisions made**（进度 + 已做决策）
2. **Important context, constraints, or user preferences**（约束 + 用户偏好）
3. **What remains to be done (clear next steps)**（剩余步骤）
4. **Any critical data, examples, or references needed to continue**（续跑必需的数据）

压缩后重注入前缀的关键句："Use this to **avoid duplicating work**"（防重复劳动）。多次压缩的摘要**按序重注入**（不丢早期摘要）。两条压缩路径：模型摘要式（零 token 换不来时用）与 **token-budget 式**（跳过摘要直接换新上下文窗口，零摘要成本）。

> **目标技能落地**：swarm-yuan 已有 builder-journal compaction 续传（WP-loop）；生成技能的长任务中断恢复按四段模板写 journal，恢复时先读 journal 防重做。

### 1.3 稳定前缀换缓存命中（AGENTS.md 固定注入）

- 项目规范文件（AGENTS.md，从 CWD 到根聚合）**固定注入 developer message**——不重复读取、位置稳定 → prompt 缓存前缀稳定（实测 98%+ 命中）。
- **字节预算**：`project_doc_max_bytes` 默认 **32KiB**，超限截断。
- 反例（要避免）：每轮动态拼装规则文本 → 缓存全失效。规则应**静态分层**（常驻的固定、按需的按需）。

> **目标技能落地**：生成技能时，特征卡/铁律等常驻内容放 SKILL.md 头部（稳定前缀），方法论文档放 references/ 按需读——这正是 swarm-yuan 决策 32（上下文压缩折叠）的设计，Codex 的数据（98.7% 命中）印证其有效性。

### 1.4 渐进披露（frontmatter-only 常驻）

Codex Skills 只常载 frontmatter（name/description），正文按触发注入（`skills.frontmatter_max_bytes`）。

> **目标技能落地**：同决策 32——SKILL.md 只常驻「做什么 + 何时用」，Step 详解折叠到 generation-flow.md 按需读。门禁清单一行一 flag（`--list-gates`），不常驻 54 条正文。

## 二、Review rubric 工程化（什么算 bug 的 8 条判定 + 结构化输出）

引自 `review/rubric.md`（95 行）。swarm-yuan 的门禁输出（fail id + 修复建议）可吸收其判定纪律：

### 2.1 什么算 bug（8 条判定，直接可抄）

1. **bug 必须是本次变更引入的**——已存在的旧 bug 不报（`The bug was introduced in the commit`）。
2. **必须可定位**——"可能影响其他部分"不算，必须指出**可证明受影响**的其他部分（`provably affected`）。
3. **修复代价与本仓 rigor 水平相称**——不要求全仓没有的严谨度（`not demand a level of rigor not present in the rest of the codebase`）。
4. 修复它须是**可行的**（不是"重写整个模块"级）。
5. 有**具体触发路径**（输入/状态），不是理论存在。
6. 违反的是**明确的规则**（须引用项目规则文件，见 2.2）。
7. 不是 speculation/猜测性发现。
8. 不报与本次变更无关的问题（`unrelated bugs`）。

### 2.2 结构化 finding + 规则溯源

- 每条 finding：**title ≤80 字符 + P0-P3 优先级 + confidence_score + 引用规则文件**（`verify the applicable project instruction file (AGENTS.md) that supplies the rule`——防幻觉引用，Codex 原文 "Do not fabricate citations"）。
- 末尾**强制二值结论**：`overall_correctness: "patch is correct" | "patch is incorrect"`——不许和稀泥。

> **目标技能落地**：生成技能的 review 节点（workflow 节点⑥/审查）输出格式带 P0-P3 + 规则引用（指向目标技能自己的 spec/铁律文件）+ 二值结论。swarm-yuan 门禁的 fail 输出已带 id + 建议，增量是优先级分级 + 规则溯源指针。

### 2.3 Auto-review 二级审批

越权/沙箱外请求 → 独立 reviewer 按 **POLICY.md**（Markdown 策略文件）判定 → 拿不准才升级问人。审批也自动化，但策略是显式文件可审计。

> **目标技能落地**：目标技能的防作弊门（integrity-guard）已是确定性 deny/advisory 两档；增量思路是「advisory 档的裁决依据写成显式 POLICY 段落，让 AI 复核时引用」。

## 三、测试哲学（写进执行 prompt 的纪律）

引自 Codex base instructions 原文：

1. **narrow → broad 顺序**：先跑「与本次改动最相关的窄测试」快速捕获问题，建立信心后逐步扩大范围（`start as specific as possible... then make your way to broader tests`）。
2. **格式化最多迭代 3 次**：格式化工具反复改不干净就停下查根因，不无限循环。
3. **不往无测试的仓库塞测试**（`do not add tests to codebases with no tests`）——尊重项目现状。
4. **按审批模式调激进度**：无人值守模式（`never`）主动跑测试/lint；交互模式（`untrusted`）等用户就绪再跑。
5. **修根因不打补丁**（`Fix the problem at the root cause rather than applying surface-level patches`）。
6. **改完不回读**：`apply_patch` 成功的文件不重读验证（补丁式编辑失败即报错，成功即成功）——省一轮读文件。

> **目标技能落地**：这些直接进生成技能 workflow 节点⑤（编码实现）的执行 prompt；第 6 条依赖 AI 运行时的补丁式 Edit 语义（Claude Code Edit/Codex apply_patch 均满足）。

## 四、吸收边界（诚实排除——不适合 skill 层的机制）

以下机制是 **agent harness 的职责**（Claude Code/Codex CLI 这类运行时自己实现），swarm-yuan 作为 skill 层不重复造：

- **OS 级沙箱**（Seatbelt/bwrap）：运行时职责；swarm-yuan 的 precheck 门禁跑在用户自己的 shell。
- **模型路由**（mini 干杂活/旗舰主审）：运行时控制模型调用。
- **Hooks 确定性裁决**：swarm-yuan 已有等价物（54 门禁本来就是确定性 bash 检查 + integrity-guard/failure-detector hooks）。
- **并行子代理调度**（spawn_agent/max_threads=6）：运行时的编排原语；swarm-yuan 的 subagent-orchestration.md 已引用方法论。

## 五、与其他 references 的关系

- **印证决策 32**（上下文压缩折叠）：§1.3/§1.4 的缓存数据（98.7% 命中）是决策 32 设计的外部证据。
- **补强 `review-methodology.md`**：§2 的 rubric 判定与五维度审查互补——五维度定「查什么」，rubric 定「什么算 finding」。
- **补强 `memory-persistence.md`**：§1.2 的 checkpoint 模板与 builder-journal 互补——journal 记「状态」，checkpoint 模板定「交接摘要的结构」。
- **补强 `subagent-orchestration.md`**：§3 的测试哲学进节点⑤执行纪律。
