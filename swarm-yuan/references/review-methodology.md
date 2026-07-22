# 代码审查方法论 (Code Review Methodology)

> 整合自 [gstack](https://github.com/garrytan/gstack) 的审查清单/specialist 模式与 [open-code-review](https://github.com/alibaba/open-code-review) 的 5 维度/规则链/严重度分级。
> 本文件指导目标技能的 check 段如何集成代码审查。
> **仅引用方法与 `ocr` 命令，不复制源码。**

## 五个审查维度（open-code-review 基线）

每个变更审查时覆盖这 5 维度（引自 open-code-review `default.md`）：

| 维度 | 审查问题 |
|------|---------|
| **正确性 Correctness** | 逻辑是否正确？边界条件是否完整？异常处理是否得当？并发场景是否线程安全？ |
| **安全 Security** | 是否有 SQL 注入/XSS 等漏洞？敏感信息处理是否正确？权限校验是否完整？ |
| **性能 Performance** | 是否有明显性能问题（N+1 查询、不必要循环）？资源是否正确释放？ |
| **可维护性 Maintainability** | 代码是否清晰易懂？命名是否准确表达意图？是否遵循项目既有风格与架构？ |
| **测试覆盖 Test Coverage** | 关键逻辑路径是否有测试？测试是否覆盖边界条件？ |

> 目标技能生成时，可按项目语言追加 open-code-review 的语言专项规则（java/ts/rust/c 等），通过 `ocr review --rule <file>` 引用。

## 两遍清单结构（gstack 模式）

审查分两遍，每遍聚焦不同严重度：

### 第一遍：CRITICAL（阻塞性）
- SQL 安全（注入、参数化）
- 竞态条件（check-then-act、非原子复合操作）
- LLM 信任边界（AI 生成代码的注入点）
- Shell 注入 / 命令注入
- 枚举完备性（switch/default 覆盖）
- 认证/授权绕过
- 路径穿越

### 第二遍：INFORMATIONAL（非阻塞）
- 命名一致性
- 注释完整性
- 风格规范
- 小幅性能优化建议

## AUTO-FIX vs ASK 启发式（gstack Fix-First Heuristic）

每个审查发现的处置决策：

> **若修复是机械的、资深工程师会不加讨论地应用 → AUTO-FIX（自动修复）**
> **若合理的工程师可能意见不一 → ASK（询问用户）**

| 发现类型 | 处置 |
|---------|------|
| 明显 bug（空指针、越界、逻辑错误） | AUTO-FIX |
| 安全漏洞（注入、越权） | AUTO-FIX |
| 清晰的拼写错误/死代码 | AUTO-FIX |
| 合理但依赖上下文的风格/性能 | ASK |
| 架构层面的重构 | ASK |
| 可能是误报 | 丢弃（silent discard） |

## 严重度分级（open-code-review 模式）

| 级别 | 含义 | 处置 |
|------|------|------|
| **High** | 明显 bug/安全/清晰错误 | 必须修复 |
| **Medium** | 合理但依赖上下文的风格/性能 | 评估后修复 |
| **Low** | 可能误报 | 静默丢弃 |

## 严格聚焦规则（open-code-review Strict Focus）

> "Context tools are for understanding purposes only. Findings from other files must NOT become the subject of your comments. If you discover a potential issue in another file while gathering context, ignore it — your task is limited to the current diffs."

审查只针对**变更文件**（diff 中 `+` 行）。用上下文工具理解周边代码，但不在其他文件提评论。

## Specialist 并行审查（gstack 模式）

复杂变更可派发并行 specialist subagent，各带专项清单：

| Specialist | 清单 |
|-----------|------|
| Testing | 测试覆盖、边界、mock 正确性 |
| Maintainability | 可读性、命名、DRY、复杂度 |
| Security | OWASP Top 10、STRIDE、注入、越权 |
| Performance | N+1、热路径、资源泄漏 |
| Data Migration | schema 变更、数据迁移、回滚 |
| API Contract | 接口签名、兼容性、版本 |

每个 finding 标 AUTO-FIX 或 ASK。

## 自动化审查工具引用（ocr）

目标技能可引用 [open-code-review](https://github.com/alibaba/open-code-review) CLI 自动审查：

```bash
# 安装（Go 二进制，或 npm 包装）
# 见 https://github.com/alibaba/open-code-review 安装说明

# 审查当前 diff
ocr review --from <base> --to <head> --audience agent

# 审查时附带需求上下文（审查是否正确实现了需求）
ocr review --background "需求描述"

# 全文件扫描（非 diff）
ocr scan --path <dir>

# 指定规则文件
ocr review --rule <project>/.opencodereview/rule.json

# 检查哪个规则会应用
ocr rules check <file>
```

**规则解析链（4 层，first-match-wins）：**
1. `--rule` CLI flag
2. 项目 `<repo>/.opencodereview/rule.json`
3. 全局 `~/.opencodereview/rule.json`
4. 内置 `system_rules.json`

目标技能生成时，可在项目根放 `.opencodereview/rule.json` 定制规则（path glob + rule 内容/文件 + merge_system_rule）。

## 审查与 spec 的关联（gstack plan-completion audit）

审查不只是看代码质量，还要核对**是否完成了 spec/tasks.md 的要求**：

| 验证类型 | 含义 | 判定 |
|---------|------|------|
| DIFF-VERIFIABLE | 可从 diff 直接验证 | DONE / NOT DONE |
| CROSS-REPO | 跨仓库影响 | DONE / PARTIAL / UNVERIFIABLE |
| EXTERNAL-STATE | 外部状态（DB/缓存） | DONE / CHANGED / UNVERIFIABLE |
| CONTENT-SHAPE | 内容形态（输出格式/字段） | DONE / PARTIAL / NOT DONE |

对照 tasks.md 的每个 checkbox，按类型验证完成度。

## Plan 原地修订（openspec `/opsx:update`，v1.6.0+）

> 引自 openspec v1.6.0。swarm-yuan 生成的目标技能可引用此能力，在 design→build 边界处修订计划而不回退到 open 阶段。

**命令：**
```bash
# 原地修订已有 change 的 plan，并 reconcile 关联 artifacts（不越界到实现工作）
openspec update <change-id>
# 或通过 slash command（Claude Code 集成）
/opsx:update <change-id>
```

**行为：**
- 读取已有 change 的 `plan.md` + `tasks.md`，允许原地修改 plan 与关联 spec delta
- 自动 reconcile：若 plan 引用了已变更的 spec 节，更新 tasks 中的受影响 checkbox（DIFF-VERIFIABLE 类自动重判）
- **不触发实现工作**：只生成/更新 plan+tasks，不写实现代码、不改实现文件

**在目标技能中的落地：**
- workflow 的 design→build 边界处，若需基于新信息调整 plan（而非回退到 open 重做），引用 `openspec update` 而非重新 `openspec change`
- precheck.sh 的 `design` 门禁可增加检查：若 `tasks.md` 存在，其 checkbox 列表与当前 `plan.md` 的任务定义一致（reconcile 无遗漏）

## 预批准 OpenSpec CLI（openspec 生成技能权限，v1.6.0+）

> 引自 openspec v1.6.0。生成的技能与 Claude commands 可预批准 OpenSpec CLI，避免每次 opsx 调用都触发权限确认。

**在目标技能中的落地：**
- 生成目标技能时，在 `hooks/hooks.json` 或 commands 的 frontmatter 中，为 `openspec`/`opsx` 命令预置 `"permission": "allow"` verdict
- 仅预批准 OpenSpec CLI 这一个工具，其他工具（grep/Read/Bash）仍受正常权限控制
- 示例 hooks 片段：
```json
{
  "PreToolUse": [
    { "matcher": "Bash", "hooks": [{"type": "command", "command": "echo '{\"permission\":\"allow\"}'"}], "condition": "tool_input.command matches /^openspec|^opsx/" }
  ]
}
```
- 这减少高频 opsx 调用（validate/update/change/archive）的重复确认，同时不弱化其他工具的权限门

## 与目标技能的整合

目标技能的 check 段应：
1. 在 `reference-manual.md` 加"代码审查"章节，列 5 维度 + 两遍清单 + AUTO-FIX/ASK
2. 在 `precheck.sh` 加 `--review` 子命令（调用 `ocr review` 若可用，否则提示手动审查清单）
3. 在 workflow 节点⑥（测试验证）引用本审查方法论
4. 在 `dev-guide.md` 引用 subagent 编排时的两阶段审查（spec合规 + 质量）

## gstack v1.58 + open-code-review v1.3 全量能力

> 来自 gstack v1.58.5 + open-code-review v1.3.13 源码调研。

### gstack 审查维度（超出 5 维度的扩展）

| 维度 | gstack 命令 | 描述 | swarm-yuan 落点 |
|------|------------|------|----------------|
| 战略/范围 | `/plan-ceo-review` | 4 范围模式（扩张/选择性扩张/维持/缩减）| spec §1.3 非目标可引用 |
| 架构/数据流 | `/plan-eng-review` | ASCII 图 + 状态机 + 错误路径 + 测试矩阵 + 失败模式 | spec §5 详细设计可引用 |
| 视觉设计 | `/plan-design-review` | 每维度 0-10 评分 + "10 分长什么样" + AI Slop 检测 | 前端项目可引用 |
| 开发体验 | `/plan-devex-review` | DX 审查 + TTHW 基准 + 摩擦追踪 | dev-guide 可引用 |
| 跨模型审查 | `/codex` | OpenAI Codex 独立第二意见 + 3 模式（审查门/对抗挑战/开放咨询）| `--review` 可引用 |
| 安全 | `/cso` | OWASP Top 10 + STRIDE + 17 FP 排除 + 8/10+ 置信门 + 利用场景 | `--security` 可引用 |
| 性能 | `/benchmark` | Core Web Vitals + 页面加载 + 资源大小 + before/after | 前端项目可引用 |
| 根因调试 | `/investigate` | Iron Law：无调查不修复 + 3 次失败后停止 | check 段可引用 |

### open-code-review 关键能力

| 能力 | 描述 | swarm-yuan 落点 |
|------|------|----------------|
| **确定性文件捆绑** | 相关文件分组成审查单元（如 `message_en.properties` + `message_zh.properties`），每个 bundle 独立 sub-agent | `--review` 大变更集可引用 |
| **外部定位模块** | 独立模块提高 AI 评论的行号定位准确度（解决定位漂移） | `--review` 质量提升 |
| **外部反思模块** | 独立模块提高评论内容准确度 | `--review` 质量提升 |
| **模板引擎规则匹配** | 按路径的规则匹配（比自然语言更稳定） | `--review` 规则可引用 |
| **`ocr scan` 全文件审计** | 无 git diff 也能审查（非 git 目录/迁移前扫描） | 探查阶段可引用 |
| **`--audience agent`** | 输出摘要模式供 agent 消费（非人类进度显示） | subagent 审查可引用 |
| **MCP server 支持** | 可挂载 CodeGraph 等工具做代码结构分析 | `--review` + `--layer` 协同 |
| **4 层规则优先级链** | CLI > 项目(`.opencodereview/rule.json`) > 全局 > 内置 | 项目自定义审查规则 |
| **`--background` 需求上下文** | 从 commit message 自动填充需求上下文 | 更精准的审查 |
| **`ocr viewer` WebUI** | 查看完整 LLM 请求/响应会话（DNS-rebinding 防护） | 审查调试 |
| **精度优先设计** | 50 仓库/200 PR/10 语言/1505 标注基准验证，精度 + F1 显著高于通用 agent，~1/9 token | 资源效率 |
| **Anti-overfitting eval 纪律**（ruflo v3.25.0 方法论） | 审查策略改进须在**冻结的 human-labeled eval set**（hash-pinned, tamper-evident）上验证；每代改进暴露 humanRelevance delta（"自检索升但 human relevance 平→过拟合"须可见）；**clean-room replay** 验收（离线重放 promoted generation，哈希一致 + 重新跑 accept/v1+sig） | `--review` 规则演进可引用 |
| **Shadow/canary 部署模式**（ruflo v3.24.0 方法论） | promoted 审查策略 champion 经一代 shadow 延迟后才 serve；canary 在 evolving store 上每 tick 重打分；**auto-rollback** 回归——可迁移到"precheck 规则升级"场景 | `--review` 规则升级可引用 |

### ECC v2.0 审查方法论扩展

> 来自 ECC v2.0.0。将审查系统从"静态规则"升级为"动态评估 + 对抗收敛 + 部署验证"。

#### Santa Method（对抗收敛审查）

ECC 的 `santa-method` 是两阶段审查的**对抗收敛**变体：

| 阶段 | 说明 | 与 swarm-yuan 两阶段审查的关系 |
|------|------|------------------------------|
| Agent A 审查 | 独立审查 agent，输出 findings | 同 swarm-yuan Stage 1（spec 合规） |
| Agent B 审查 | **另一个独立**审查 agent，输出 findings | 同 swarm-yuan Stage 2（代码质量） |
| **收敛判决** | A 和 B 的 findings 取交集——只有双方都报告的 finding 才视为真 | **新增**：降低误报率 |

**N-of-M 收敛**：可扩展为 N 个审查 agent，至少 M 个（如 3/5）报告同一 finding 才采纳。

**在目标技能中的落地：**
- 高复杂度变更（large 级）可用 santa-method 替代单 agent 审查
- 收敛判决规则：A ∩ B 的 findings → High；A ∪ B 的 findings → 全部列出但标注来源

#### Skill-Run Telemetry（技能运行遥测）

ECC 的 `skill-runs.jsonl` 记录每次 skill 执行的**3×3 结果矩阵**：

| outcome | 含义 |
|---------|------|
| `success` | 完全成功 |
| `failure` | 完全失败 |
| `partial` | 部分成功 |

| feedback | 含义 |
|----------|------|
| `accepted` | 用户采纳结果 |
| `corrected` | 用户修正后采纳 |
| `rejected` | 用户拒绝结果 |

**9 种组合**（success+accepted 是最佳，failure+rejected 是最差）。

**Verifier-gated promotion**：skill 改进提案须经 verifier 验证（不扩大 blast radius）才能 promote。

**在目标技能中的落地：**
- swarm-yuan 的目标技能可在 check 段加 `--telemetry` 子命令：记录 skill 执行的 outcome/feedback
- 遥测数据存于 `.swarm-yuan/skill-runs.jsonl`（JSONL 格式，一行一次运行）

#### Skill-Comply（行为合规测试）

ECC 的 `skill-comply` 自动测试 agent 是否**真的遵循 skill**：

- 自动生成 **3 种严格度**的 prompt：宽松（隐式暗示）/ 标准（明确指令）/ 严格（强制要求）
- 运行 agent，记录行为序列
- 分类行为：compliant / partial / non-compliant
- 报告合规率

**在目标技能中的落地：**
- 生成的目标技能可在 check 段加 `--comply` 子命令：测试 skill 的合规率
- 若合规率 < 阈值（如 80%），修订 skill 的指令（更明确/更严格）

#### Head-to-Head Agent Eval（head-to-head 对比）

ECC 的 `agent-eval` 对比两个 agent 在同一任务上的表现：

| 指标 | 说明 |
|------|------|
| pass-rate | 通过测试的比例 |
| cost | token 消耗 |
| time | 耗时 |
| consistency | 多次运行的结果一致性 |

**在目标技能中的落地：**
- 生成目标技能时，可对比两个候选 skill（如两个不同 prompt 策略）的 head-to-head 表现
- 选择 pass-rate 高 + cost 低 + consistency 高的版本

#### Deploy Canary-Watch（部署验证）

ECC 的 `canary-watch` 是**发布后**的验证（不同于 swarm-yuan 的 eval-rollout canary）：

- 验证 HTTP 端点可访问
- 验证 SSE 流正常
- 验证静态资产加载
- 验证无 console 错误
- 验证性能无回归

**在目标技能中的落地：**
- 若项目有部署环节，check 段可加 `--canary-watch` 子命令：发布后验证部署 URL
- 与 swarm-yuan 的 shadow/canary（eval 阶段）互补：shadow/canary 验证策略，canary-watch 验证部署

#### Closed-Stale Salvage Ledger（陈旧 PR 抢救）

ECC 的 stale PR 抢救流程（治理模式）：

1. **关闭陈旧 PR**：用礼貌评论关闭（"此 PR 已陈旧，如有价值请重新提交"）
2. **记录 salvage ledger**：记录 PR 号、作者、原因、有用文件、风险、建议行动
3. **手动 diff 审查**：审查 salvage 候选的 diff
4. **cherry-pick 或重写**：若 diff 干净则 cherry-pick，否则用 attribution 重写
5. **标记状态**：landed / superseded / no-action

**在目标技能中的落地：**
- 若项目有大量陈旧 PR，可在 check 段加 `--salvage` 子命令：扫描陈旧 PR 并生成 salvage ledger
- 规则：**绝不盲 cherry-pick 生成的 churn**（机械生成的变更须人工审查）

### ocr v1.7.8–v1.7.12 + gsd-core v1.7.0 审查能力扩展

> 来自 open-code-review v1.7.8→v1.7.12 + gsd-core v1.7.0 release notes。

#### Delegate 模式（ocr v1.7.11+）

ocr 新增 **delegation mode**——host-agent 驱动的代码审查：

- host-agent（如 Claude Code）将审查任务**委托**给 ocr
- ocr 作为 delegated reviewer，而非独立运行
- 适用于：host-agent 已有完整上下文，只需 ocr 做规则匹配 + finding 生成

**在目标技能中的落地：**
- review-methodology 的 specialist 并行审查可引用 delegate 模式：host-agent 委托 ocr 做特定维度审查
- `ocr review --delegate` 选项

#### W3C Traceparent 传播（ocr v1.7.9+）

ocr 审查过程传播 **W3C traceparent** header：

- 从父进程继承 traceparent
- 审查的每一步（LLM 调用、规则匹配、finding 生成）都携带 trace
- 支持分布式追踪（审查过程可追踪到具体 LLM 调用）

**在目标技能中的落地：**
- 若项目用分布式追踪，precheck.sh 的 `--review` 子命令可传播 traceparent
- 审查结果可关联到 trace（便于审计"为什么这个 finding 被报告"）

#### Honest Verifier Abstain（gsd-core v1.7.0+）

gsd-core 的 verifier 新增 **abstain（弃权）** 判决：

- 当 spec 信息不足以推断 backstop truth 时，verifier **弃权**（`insufficient_spec`）而非猜测
- 弃权 ≠ 通过：弃权时须补充 spec 信息后重新验证
- 防止 verifier 在信息不足时"编造"验证结果

**在目标技能中的落地：**
- review-methodology 的 spec-compliance audit 可引用 abstain：若 spec 不够详细无法验证，报 "abstain: insufficient_spec" 而非 "pass"
- precheck.sh 的 `--review` 子命令：abstain 计为 "需人工确认"（非 pass 非 fail）

#### Assumption-Delta Advisory Checkpoint（gsd-core v1.7.0+）

gsd-core 在实现过程中检查**假设偏移**：

- 实现开始时记录假设清单（"我假设 X 为真"）
- 实现过程中若发现假设不成立，记录 **assumption-delta**（"假设 X 不成立，实际 Y"）
- 在 advisory checkpoint 暂停，提示人工确认假设偏移的影响

**在目标技能中的落地：**
- workflow 节点⑤（编码实现）可引用 assumption-delta：实现过程中假设变化时记录
- check 段审查 assumption-delta：评估假设偏移是否影响 spec 合规

#### OpenAI Responses API + LiteLLM 网关（ocr v1.7.10/v1.7.12+）

ocr 新增 LLM provider 支持：

| Provider | 版本 | 说明 |
|----------|------|------|
| **OpenAI Responses API** | v1.7.10 | OpenAI 新 Responses API 协议 |
| **Ollama Cloud** | v1.7.11 | 内置 Ollama Cloud 预置 |
| **LiteLLM AI Gateway** | v1.7.12 | LiteLLM 网关预置（统一多 LLM 路由） |

**在目标技能中的落地：**
- 若项目用 ocr 审查，dev-guide.md 可列出支持的 LLM provider（含 OpenAI Responses/Ollama Cloud/LiteLLM）
| **Astro 专用审查规则**（v1.3.13+） | `.astro` 文件的专用审查规则 | Astro 项目可引用 |
| **per-chapter 文档路由**（v1.3.13+） | 文档站点按章节路由，便于导航 | 文档审查可引用 |
| **可恢复 review session**（v1.7.6+） | `ocr review` 支持 resumable sessions + session inspection，中断后可恢复审查 | 长变更集审查可引用 |
| **`code_search` 路径遍历拒绝**（v1.7.6+） | `ocr` 工具层拒绝 traversal pathspecs，作为 path-traversal 防御的工具级补充 | `--security` 可引用 |
| **Monorepo git top-level 路径解析**（v1.7.4+） | `file_read` 路径在 monorepo 中按 git top-level 解析，避免子包相对路径错位 | monorepo 审查可引用 |
| **结构化 category + severity**（v1.7.3+） | findings 现带结构化 category 字段（不止 severity），便于按类别过滤 | `--review` 规则可引用 |
| **Python 内置审查规则**（v1.7.6+） | Python 代码审查规则已内置（与 Java/TS/Rust 平级） | Python 项目可引用 |
| **可复用 composite PR-review GitHub Action**（v1.7.6+） | 抽取为可复用 composite action，CI 中一行引用即可做 PR 自动审查 | CI 集成可引用 |
| **`--background-file` 业务上下文**（v1.7.6+） | 读取本地业务上下文文件作为审查背景（比 `--background` 字符串更结构化） | 大型项目审查可引用 |
| **Eden AI provider 预置**（v1.7.7+） | 内置 Eden AI 作为 LLM provider 预设 | 按项目环境选择 |
| **Dark mode + 系统等宽字体**（v1.7.5+） | viewer 支持 dark mode + 系统等宽字体 | 审查调试体验 |

### superpowers 审查模式（两阶段 subagent review）

| 阶段 | 检查什么 | swarm-yuan 落点 |
|------|---------|----------------|
| Stage 1: Spec 合规 | 实现是否符合 spec delta（ADDED/MODIFIED/REMOVED） | check 段引用 |
| Stage 2: 代码质量 | 5 维度（正确性/安全/性能/可维护/测试覆盖）+ 两遍清单 | check 段引用 |
| TDD 强制 | RED→GREEN→REFACTOR，先写测试后写代码（删违规代码） | `--test` 可引用 |
| 系统调试 | 4 阶段根因定位（root-cause-tracing / defense-in-depth / condition-based-waiting） | `--review` 可引用 |
| 验证前完成 | 确保"真的修了"而非"以为修了" | goal-backward 可引用 |

## pre-emit 引用门与置信度标定（gstack #1539 吸收，治 fail-open/误报）

> 来源：gstack review/SKILL.md:1241-1276（pre-emit 验证门）+ cso/SKILL.md:1012-1046（置信度标定 + 并行独立验证）。

**pre-emit 引用门**：凡审查产出的 finding **必须逐字引用动机代码行（file:line）**，否则强制降级压出主报告——"If you cannot quote the motivating line(s), the finding is unverified"。

**置信度标定**：finding 应带置信度标注（high/medium/low），3-4 分压入附录、1-2 分仅 P0 才报。一个 VERIFIED finding 即全库搜同模式变体（变体分析）；每个候选 finding 可派独立验证 subagent（只给 file:line 防锚定），低于阈值即弃。

**FP 硬排除**：对已知误报类（如"文档文件不是可执行代码"、"SKILL.md 是可执行提示代码不适用文档豁免"）建立排除清单，审查时先过滤。

**门禁承载**：`precheck.sh check_review`——ocr review 输出对含 finding 关键词但缺 `file:line` 引用的行降级 warn（pre-emit 引用门）；AI 5 维度审查降级路径输出 pre-emit 指引。姿态为 **warn 级 advisory**（不新增 fail），与现有降级策略一致。
