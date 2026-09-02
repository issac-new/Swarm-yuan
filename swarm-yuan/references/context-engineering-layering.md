> **何时读我**：任务命中本文档主题时按需读取（路由表见 SKILL.md）。首行：# 上下文工程分层方法论（Context Engineering Layering）

# 上下文工程分层方法论（Context Engineering Layering）

> 来源：[Vibe编码 公众号《Opus 4.8 删掉了73%的提示词，Opus 5 为何又新增了 82%》](https://mp.weixin.qq.com/s/GXEnP16WbpjWtWDxj5OE2A)（2026-07-27，作者 VibeCoder）+ Anthropic Context Engineering 文档。
> 纪律：只引用方法论模式与证据视角，不调任何上游 CLI / 引擎 / 截获工具；不复制文章原文（上游文章可按需存档到 `swarm-yuan/research/context-engineering/` 供 AI 阅读，本地 gitignored，不入 git）。
> 守决策 27：吸收优先于新增门禁，不新增 `check_*`，门禁数保持 55；守决策 26：复杂度预算不增。
> 适用场景：目标技能 在**生成自身骨架**（SKILL.md / hooks / commands / MCP / precheck.conf / CLAUDE.md）时，AI 引用本文方法论决定**规则应该放在哪一层**——是常驻 System、还是 CLAUDE.md、还是按需 Skill、还是 typed schema、还是运行时门禁。也用于 swarm-yuan 仓库自身的配置分层（本仓库是一套分层 Agent 运行时的元范例）。

---

## 一、定位：填补 swarm-yuan 的"规则该放哪一层"空白

swarm-yuan 当前 17 项特征卡 / 55 门禁 / 79 框架规则集回答了「项目应该是什么样的」与「代码是否合规」，但**没有显式回答「我新加的这条规则，应该放进哪一层上下文」**——是写进 SKILL.md 常驻、还是 precheck.conf 配置、还是 reference 按需读、还是门禁机器执法、还是 hooks 阻断。

文章给出的 U 型曲线证据把这个问题显式化了：

| 模型代 | System Prompt 字符 | System+Tools 字符 | 形态 |
|--------|-------------------|------------------|------|
| Opus 4.7 | 14,808 | 105,286 | 长规则书（Doing tasks 3,321 + Executing actions 3,585 + 沟通格式 2k+） |
| Opus 4.8 | 4,050 | 76,268 | 薄 Harness（1,702 字符接口语义 + 一句代码风格） |
| Opus 5 | 7,376 | 79,423 | 薄底座 + Delivering work 2,019 + Corrections 1,368 |

**关键证据解读**：4.8→5 的 System 增长 82.12%，但 System+Tools 只增长 4.14%——围绕提示词长短争论很容易忽略真正占上下文的大块接口层。

**对本系统的价值**：swarm-yuan 的 SKILL.md / references / precheck.conf 三件套 / 55 门禁 / hooks.json / .mcp.json 本身就是一套分层上下文，但分层原则此前是隐性的（散落在各 WP 决策里）。本文把"分层放置规则"的方法论显式化，给 swarm-yuan 一个可引用的元决策框架。

---

## 二、核心论断：minimal ≠ short，关键是高信号 + 合适抽象高度

Anthropic 对 Context Engineering 的定义：**minimal 并不必然 short，关键是保留高信号内容，并处在合适的抽象高度**。

文章的证据支撑：
- 4.8 删掉的是「微观工程规范」（如何写注释、何时更新进度、Bash 9,821 字符的教程式描述）——低频说明长期占据注意力，且模型能力变化后旧约束诱发过度检查。
- 5 加回的是「自主 Agent 治理协议」（Delivering work + Corrections）——处理范围漂移、澄清过载、过早宣布完成、授权边界、纠错传播阈值。
- 三版 input schema 总长度都保持 16,411 字符——**能力接口没有消失，用法被放回参数名、枚举、返回结构和按需 Skill**。

**对 swarm-yuan 的映射**：一条规则是否值得常驻，不取决于它多短，而取决于：
1. 是否跨任务复用（单任务规则不该常驻）
2. 是否会影响用户决策（会 → 适合 System / SKILL.md）
3. 是否能从局部环境推断（能 → 留给 CLAUDE.md / 仓库代码）
4. 是否能由测试/接口/Hook 更稳定地解决（能 → 不该常驻 System）

---

## 三、分层放置规则：六层上下文模型

文章把 Agent 运行时拆成六层，每层只装属于自己的真相。swarm-yuan 既有产物可一一对应：

| 层 | 职责 | swarm-yuan 对应载体 | 不该装什么 |
|----|------|-------------------|-----------|
| **模型** | 判断、工具调用、自验证 | （外部模型能力，swarm-yuan 不控制） | — |
| **System / SKILL.md** | 产品身份、授权边界、完成定义、全局信任协议 | 目标技能 的 `SKILL.md`（铁律段：可改范围 / 分支规范 / 安全铁律） | 仓库目标与代码中推得出的约定 |
| **Tools / typed schema** | 动作空间定义 | 目标技能 的 `hooks.json` / `.mcp.json` / commands/*.md + `precheck.sh` 的 flag 接口 | 自然语言教程（应压成参数名/枚举/返回结构） |
| **CLAUDE.md / 仓库事实** | 仓库目标与代码中推不出的约定 | 目标项目的 `CLAUDE.md` / `AGENTS.md`（第 2/6 项特征卡驱动） | 跨任务通用的产品身份（属 System 层） |
| **Skills / References（按需加载）** | 专项流程 | swarm-yuan 的 `references/*.md`（30+ 文档）+ 目标技能 的 snippets.md / mcp-tools.md | 常驻规则（按需才读） |
| **Memory** | 跨会话经验 | swarm-yuan 的 `memory-writeback.sh` / `.swarm-yuan/cognition-metrics.jsonl` + `references/memory-persistence.md` | 当前任务事实（属 CLAUDE.md） |
| **permissions / sandbox / hooks** | 真正阻断副作用 | 目标技能 的 `hooks.json`（PreToolUse Write 范围检查）+ `precheck.sh` 55 门禁 + `integrity-guard.sh` / `failure-detector.sh` | 软约束（阻断交给门禁，叙事交给 System） |

**关键铁律（文章原话转译）**：permissions、sandbox、hooks 才负责真正阻断副作用——System 不该假装是阻断层，它只是治理内核。

---

## 四、4.7 长规则书的代价（反面教材）

文章对 Opus 4.7 的批评，恰好是 swarm-yuan 在生成目标技能 时要避免的反模式：

| 4.7 的代价 | swarm-yuan 的对应警示 |
|-----------|---------------------|
| 规则与用户请求/仓库惯例/其他规则冲突 | SKILL.md 铁律段只放 P0 六项（1/4/5/11/15/16），不堆砌 |
| 低频说明长期占据注意力 | references 按需读，不进 SKILL.md 常驻 |
| 模型能力变化后旧约束诱发过度检查 | 门禁分层 strict/warn/advisory（决策 19），advisory 永不 fail |
| Bash 9,821 字符教程式描述 | precheck.sh flag 接口压成 `--branch`/`--scope`/`--reuse`，用法在 `--list-gates` |

**接线动作**：生成目标技能时，若 AI 发现自己在 SKILL.md 写超过 3 段的「如何做 X」教程式内容，应触发本层判断——大概率该挪进 reference 或压成 flag 接口。

---

## 五、4.8 薄 Harness 的迁移路径（正面范式）

文章归纳 Anthropic 的迁移方向，swarm-yuan 已部分践行：

| 迁移方向 | swarm-yuan 既有落地 |
|---------|-------------------|
| 让 Claude 运用判断，不写死微观规则 | 特征卡第 3 项「改造分类」由 AI 判断 A/B 类，不写死规则 |
| 设计接口，按需披露上下文 | `--profile auto` 按项目规模自适应披露门禁集 |
| 减少重复工具说明 | `framework-signals.md` 机器生成索引，模型读索引而非重复 grep |
| 用 Auto Memory 承接长期状态 | `memory-writeback.sh` + `references/memory-persistence.md` |
| 代码风格压成一句「观察周围代码」 | `references/template-spec.md` §六段式「跟随仓库惯用法」 |

**关键吸收**：文章说「固定规则让位给情境判断，仓库代码、测试和 CLAUDE.md 成为更高保真的参考」——这正是 swarm-yuan 特征卡第 11 项「可复用稳定单元」的设计哲学：AI 先盘点既有稳定单元再决定是否新增，而不是套固定规则。

---

## 六、Opus 5 的 Delivering work + Corrections（治理内核范式）

文章对 Opus 5 新增两章的解读，是 swarm-yuan 治理回路 WP 批次（v2026.07.28）的方法论锚点：

### 6.1 Delivering work（交付工作）

| Opus 5 治理点 | swarm-yuan 对应 |
|--------------|----------------|
| 范围漂移 | `--scope` 门禁（git diff 触碰只读目录 fail）+ 特征卡第 2 项可改范围 |
| 澄清过载 | `references/task-methodology-router.md` 任务类型×方法论路由，避免一上来全量澄清 |
| 过早宣布完成 | `generate-skill.sh --verify-completeness` 零占位符机器执法 |
| 单点阻塞 | `references/governance-agents.md` 四权分离——先完成不依赖答案的部分 |
| 授权边界 | `references/decision-governance.md` 三级分类（Mechanical/Taste/UserChallenge），UserChallenge 才交还用户 |

### 6.2 Corrections（纠错治理）

| Opus 5 治理点 | swarm-yuan 对应 |
|--------------|----------------|
| 会改变代码/结论/用户决策的错误须明确说明 | `references/decision-governance.md` decisions.jsonl 留痕 |
| 小偏差直接修正后继续 | advisory 门禁永不 fail，只 warn/pass |
| 不让长篇道歉挤占注意力 | `--format json` + `to-sarif.sh` 结构化输出，不堆叙事 |
| 先判断其他 Agent 的反馈，不自动升级子 Agent 输出为事实 | `references/subagent-orchestration.md` 两阶段审查 + `references/review-methodology.md` 5 维度交叉验证 |

**接线动作**：swarm-yuan 治理回路（governance-agents / failure-detector / integrity-guard / loop-oracle / compaction-state）的产品形态，可引用本文作为"为何要做这些 hook"的理论依据——它们都是把 System 层无法稳定承载的治理逻辑下沉到 hooks/门禁层。

---

## 七、Prompt 作为 model adapter 的视角

文章最核心的元判断：**同一客户端仅切换 model ID 就选不同 System，意味着 Prompt 正在承担模型适配层的角色**。

- 新模型能力增强时，适配层删掉已被模型和基础设施吸收的旧教程。
- 新的稳定失败模式出现后，加入少量跨任务治理。
- 追求最小充分集合，字符最少只是可能结果。

**对 swarm-yuan 的映射**：swarm-yuan 生成目标技能 时，SKILL.md 的铁律段本质上就是「model adapter」——它适配的是「AI 模型对项目的认知」这一能力缺口。当目标项目的 CLAUDE.md / 仓库代码已经能提供更高保真的约定时，SKILL.md 不该重复，只补缺口。

**与五层认知基底的关系**：`references/cognition-framework.md` 的五层（认知递进/思维语言/认知辩证/偏差防范/辩证认知）回答「AI 如何认识项目」；本文回答「认识项目的规则该装在哪一层」。两者正交，互补。

---

## 八、升级模型时的自检清单（AI 引用）

文章给的自检方式，转译为 swarm-yuan 生成目标技能 时的自检：

1. **重新跑自己的任务集**——生成 skill 后用 `precheck.sh --all` 三档自举验证（RC=0）。
2. **重点看**：范围扩张（`--scope` 是否触只读）、澄清次数（task-methodology-router 是否路由正确）、完成率（`--verify-completeness` 零占位）、过度验证（advisory 门禁是否误 warn）、子 Agent 成本（subagent 编排是否过度扇出）、纠错噪声（json/sarif 输出是否可消费）。
3. **若一个问题能由测试、接口或 Hook 更稳定地解决，就没有理由让它常驻 System**——下沉到门禁或 hooks。
4. **只有跨任务复用、会影响用户决策、又无法从局部环境推断的规则，才值得进入最高优先级上下文**（SKILL.md 铁律段 / P0 特征卡）。

---

## 九、与 swarm-yuan 既有触点的接线声明

| 文章概念 | swarm-yuan 既有触点 | 接线方式 |
|---------|---------------------|---------|
| 六层上下文模型 | SKILL.md / references / precheck.conf / hooks.json / .mcp.json / memory-writeback | 本文显式化分层原则，AI 生成目标技能 时引用本文做「规则放哪层」决策 |
| minimal ≠ short | `--profile auto`（按规模自适应披露）+ advisory 门禁分层 | 引用本文支撑「advisory 永不 fail」的合理性——最小充分不等于最短 |
| Prompt = model adapter | SKILL.md 铁律段（P0 六项特征卡驱动） | 引用本文解释「为何 SKILL.md 只放 P0 六项铁律」——它是项目认知的 adapter |
| Delivering work | governance-agents / decision-governance / generate-skill --verify-completeness | 治理回路 WP 批次的理论依据 |
| Corrections | advisory 门禁 / decisions.jsonl / subagent 两阶段审查 | 纠错治理的方法论锚点 |
| 升级时重新跑任务集 | self-check.sh + verifier/v1 all + generator self-gate 三档 | 引用本文作为「发版前回归全绿」的方法论依据 |

---

## 十、不引用的部分（守纪律声明）

以下文章内容**不引用**，守方法论引用层「只引用模式不调 CLI / 不复制原文」铁律：

- 文章的 Unix Socket 截获实验代码与具体字符数计量方法——只引用结论（U 型曲线 + 分层原则），不复制截获工具
- Anthropic 内部评测因果链——文章明确说「公开资料没有披露模板提交或内部评测因果链，所以这是强推断」，swarm-yuan 只引用强推断，不当作已证事实
- 文章对 Opus 4.7/4.8/5 的能力评测——文章明确说「这里观察的是 Harness 装配机制，不是模型能力评测」，swarm-yuan 不引用任何模型能力断言

---

## 十一、版本与来源

- 来源：[Vibe编码 公众号《Opus 4.8 删掉了73%的提示词，Opus 5 为何又新增了 82%》](https://mp.weixin.qq.com/s/GXEnP16WbpjWtWDxj5OE2A)（2026-07-27，作者 VibeCoder）+ Anthropic Context Engineering 文档
- 许可证：文章内容版权归原作者，swarm-yuan 只引用方法论模式与证据视角，不复制原文
- 上游文章：[Vibe编码 公众号原文](https://mp.weixin.qq.com/s/GXEnP16WbpjWtWDxj5OE2A)（可按需存档到 `swarm-yuan/research/context-engineering/` 供 AI 阅读，本地 gitignored，不入 git）
- 吸收决策：决策 27（运行时升级整合纪律——吸收优先于新增门禁）+ 决策 26（复杂度负向预算，门禁数保持 55）
- 自检断言：G14 `check_context_engineering_layering`（`self-check.sh`，warn-only，守本文档存在性 + SKILL.md 接线 + facts.conf 口径）
- 口径同步：`facts.conf` `FACT_REFERENCES=33`（本文档 +1）
