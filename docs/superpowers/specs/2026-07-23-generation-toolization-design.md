# 生成管线工具化性能优化 — 设计文档

- 日期：2026-07-23
- 状态：已获用户分节确认（架构 / M1–M3 / M4–M5+测试+WP 分解）
- 前置文档：`docs/plans/2026-07-21-paradigm-slimming-plan.md`（范式减重 P0–P3，本轮是其思路向生成侧的自然延续）
- 红线约束：`references/template-spec.md:346` —— framework-knowledge.md 规律骨架「故意不由脚本生成」，AI 逐条验证的语义必须保留

## 1. 目标与验收

**目标**：优化 swarm-yuan 生成期及其生成的目标 skill 使用期的性能，把机械工作从模型转移到确定性脚本，降低 skill 使用过程中对模型处理速度与 token 吞吐的依赖。

**验收指标**（用户确认：三条都测量与报告，但**不设硬性 pass/fail 阈值**，纯信息性）：

1. 生成期 token 降幅 —— 代理指标（见 §3 计量的诚实限制）
2. 目标 skill 上下文缩减 —— 字节级静态上下文表面
3. 脚本运行耗时 —— wall-clock 基线对比

## 2. 总体架构

不动 Step 0–12 管线骨架，在其下新增「生成辅助脚本层」（`swarm-yuan/scripts/` 扁平命名，遵循现有惯例）。每个脚本承接一类机械工作，SKILL.md / exploration-guide.md 中对应步骤改写为固定两段式：

> **跑脚本 → 模型只读报告做判断**（判断语义全部保留，符合 template-spec.md:346 红线）

硬约束（所有新脚本）：bash 3.2 兼容（无 `declare -A`、`sed -i.bak` 模式）、macOS/Linux/Windows(Git Bash) 三 OS 可跑、配 `.bat` 包装、fixture 双态测试。

**六个工具化模块**：

| # | 模块 | 性质 |
|---|---|---|
| M1 | `inventory-verify.sh` — 维度计数核验 | 新增脚本 |
| M2 | `framework-evidence.sh` — 框架规律证据台账 | 新增脚本 + 62 个框架文件格式规范化 |
| M3 | `conf-render.sh` — precheck.conf 初稿渲染 | 新增脚本 |
| M4 | 信号索引数据化拆分 | 改造 detect-frameworks + exploration-guide 瘦身 ~300 行 |
| M5 | 目标 skill 上下文裁剪 | profile 化引用清单 + spec-template 节门控 |
| M6 | 计量设施 + 基线 | 扩 trace-log/cost-report/verifier |

## 3. M6 — 计量与基线（最先实施）

**诚实限制**：脚本无法直接观测模型 token 消耗，采用两个代理指标——

1. **wall-clock**：trace-log.sh 在每个 Step 记录耗时（模型处理时间的代理，有噪声但方向可信）；
2. **静态上下文表面**：字节级统计「管线要求模型必读的文件总量」（生成期）和「目标 skill 强制加载文件总量」（使用期）——确定性、可 byte-diff 的硬指标，进 verifier baseline。

**基线先行**：在 fixture 上对当前 main 跑一次完整生成，落 `verifier/baselines/pre-opt/`；之后每个模块合入时出 before/after 对比报告（信息性，不设阈值）。

## 4. M1 — `inventory-verify.sh`：维度计数核验

**接管工作**：Step 12 / exploration-guide §C+ 中模型手工 find/grep 枚举各维度组件 → 数 reference-manual.md 表格行数 → 去重 → 算 95% 比率 → 填核验表（`references/exploration-guide.md:729-738,949,971,1111,1310-1315`）。

**设计**：

- 内置维度注册表（数据驱动，独立 conf：`assets/inventory-dimensions.conf`），每维度 = 枚举模式（find/grep 规则）+ 适用项目形态（纯后端/纯前端/全栈/库）+ reference-manual.md 对应表名。
- 项目形态读生成产物中 §C+.0 判定结果；不落产物时退化为全维度。
- 输出 TSV 报告 + 人读摘要：`维度 | 枚举计数 | 清单计数 | 比率 | PASS/FAIL(<0.95)`。
- 顺带机械化维度错配检测：声明纯后端却出现 UI 组件表 → `DIM_MISMATCH`（纯前端 vs controller 表同理），把 SKILL.md:100 的模型判断变成结构 lint。
- **模型新动作**（Step 12 改写）：跑一次脚本；全 PASS → 直接引用报告结论；FAIL → 只针对失败维度回 Step 4 补漏；DIM_MISMATCH → 回 §C+.0 重判形态。

## 5. M2 — `framework-evidence.sh`：框架规律证据台账（最大 token 池）

**接管工作**：Step 4.5 中模型对 62 个框架文件逐个读 §1–§6、手工执行每条规律的 grep 验证、逐个抄证据 file:line（62 文件共 12,027 行，生成期最大 token 消耗点）。

**前提改造——框架文件格式规范化**：当前 62 个 `references/frameworks/<fw>.md` 的「验证方法」是写给模型看的散文，脚本无法可靠提取。定义机器可读 verify 块（放在每个规律条目下）：

````
### 规律 N：<标题>
...散文不变...
```verify
id: <fw>-rNN
cmd: grep -rn "pattern" --include="*.ts" src/
expect: hits>0
```
````

迁移用脚本辅助完成（解析现有 grep 语句 → 生成块 → 校对一次；62 文件 × ~5 规律，一次性成本）。

**脚本行为**：输入 = 目标仓库 + ACTIVE_FRAMEWORKS 列表（直接吃 `detect-frameworks.sh` 输出）→ 逐框架提取 verify 块并批量执行 → 输出证据台账 TSV：

```
framework | rule_id | rule_title | hits | evidence(top-N file:line) | SUGGEST(applicable/unclear/likely-na)
```

`SUGGEST` 只是启发式（hits=0 → likely-na），**不是判决**。

**模型新动作**（Step 4.5 改写）：读台账而非跑 grep；对每条规律做适用/不适用判断并记录理由（判断语义完整保留）；证据 file:line 从台账直接引用。规律计数 ≥ 深度门槛的校验由 `verify-framework-ruleset.sh` 继续兜底（已存在）。

## 6. M3 — `conf-render.sh`：precheck.conf 初稿渲染

**接管工作**：Step 8 中模型把特征卡散文翻译成 151 个 conf 变量。

**设计**：

- 汇总已有探测能力（detect-frameworks.sh + 语言/目录/包管理器嗅探，新增轻量嗅探逻辑）+ 特征卡骨架结构化字段 → 渲染三份 conf（`precheck.conf` / `precheck.arch.conf` / `precheck.compliance.conf`）初稿。
- 每个变量带溯源注释：`# AUTO:detected`（探测所得）/ `# AUTO:default`（默认值未动）/ `# TODO:model`（语义型变量如 LAYER_DEFS，显式标记）。
- **模型新动作**：只处理 `# TODO:model` 清单 + 审 diff 是否符合特征卡意图——从「写 151 行」变成「审 + 补少数」。
- 与现有 `merge_precheck_conf`（generate-skill.sh 内）关系：后者目前只追加占位符，改造为以 conf-render 输出为基底，占位符逻辑保留兜底。

## 7. M4 — 信号索引数据化拆分

**现状**：`references/exploration-guide.md`（1,334 行 / 101KB，生成期必读）中嵌 ~300 行 `# >>> framework-signal-index >>>` 机器生成块（`scripts/gen-framework-index.sh` 产出）——脚本数据住在模型文档里。

**设计**：

- 索引块整体迁出为独立数据文件 `assets/framework-signals.conf`（仍由 gen-framework-index.sh 生成，改输出路径与纯数据格式）。
- `detect-frameworks.sh` 直接消费该数据文件做信号匹配，输出增强：框架列表 + 命中信号明细 + 置信度。
- exploration-guide.md 原地留一行指针（「框架识别以 detect-frameworks.sh 输出为准」），模型必读物减重 ~30%（101KB → ~70KB）。
- CI 保鲜检查沿用 f0fc80a 模板 freshness check 模式扩展：索引与框架文件漂移即红。

## 8. M5 — 目标 skill 上下文裁剪

**现状**：每个生成的目标 skill 拷入 ~23 个引用文档（UNIVERSAL_FILES，`scripts/generate-skill.sh:42-81`），已标「按需读取」；但 (a) spec-template 23 节是强制填充负担，其中 §14–§18 认知/辩证法/领域节的门禁 `check_cognition` 是纯关键词计分、0 个 fail()（`docs/2026-07-20-audit-optimization-decisions.md:33` 已定性「装饰性叙事」）；(b) 引用清单不区分 profile。

**设计**（保守：不删能力只分层）：

- **spec-template 节门控**：模板拆为核心 18 节 + 认知扩展包 §14–§18。lite/standard profile 默认只发核心节；compliance profile 保留全部。`check_cognition` 适配：节不存在 → SKIP 并如实披露（沿用 WP-F 的 SKIPPED 诚实原则）。
- **UNIVERSAL_FILES profile 分级**：core（三 profile 都拷）/ standard / compliance-only（如 standards-compliance.md 43KB、安全认证 profile 文档）。lite 进一步收窄（WP-E 已做部分，补齐分级）。
- 生成产物 SKILL.md 的「按需读取」索引表由 generate-skill.sh 依据分级清单自动生成，避免手写漂移。

## 9. 测试策略

| 层 | 内容 |
|---|---|
| 单元 | 每个新脚本 fixture 双态测试（沿用 62 框架 fixture + 40 门禁 fixture 组模式，新增 inventory/conf/evidence 三组 fixture） |
| 回归 | `verifier/v1/cli-ab-test.sh` 字节级 A/B：M1/M3 输出确定性；`metrics-baseline.txt` 增加新脚本行数/耗时条目 |
| 一致性 | `self-check.sh` 的 `check_doc_consistency` 扩展：SKILL.md/exploration-guide 引用的脚本名必须存在于 scripts/（防文档-脚本漂移） |
| 端到端 | 生成管线模型驱动部分无法真 e2e，改为指令-脚本一致性 lint + fixture 项目人工抽检一次 |
| 合入门槛 | 现有 45 门禁行为、fixture 双态、golden-vector 退出码全绿 |

## 10. WP 分解（≤3 并行，逐个收口）

| WP | 内容 | 依赖 |
|---|---|---|
| **WP-P0** | M6 基线采集：trace-log 加 Step 耗时 + 上下文表面统计脚本 + fixture 跑基线落 `verifier/baselines/pre-opt/` | 无，**最先做** |
| **WP-P1** | M4 信号索引拆分（独立、低风险，先落地验证模式） | 无 |
| **WP-P2** | M1 inventory-verify + 维度注册表 + Step 12 改写 | P0 |
| **WP-P3** | M2 框架 verify 块格式 + 62 文件迁移 + evidence 台账 + Step 4.5 改写（可再拆 P3a 格式迁移 / P3b 脚本） | P0 |
| **WP-P4** | M3 conf-render + Step 8 改写 | P0 |
| **WP-P5** | M5 上下文裁剪（spec-template 门控 + 引用分级） | 无 |
| **WP-P6** | M6 收尾：before/after 对比报告 + facts.conf 数字渲染扩展 | P1–P5 |

## 11. 明确不做（YAGNI / 红线）

- 不重写 Step 0–12 控制流（方案 B 引擎化留作远期演进）。
- 不由脚本直接落 framework-knowledge.md 规律产物（template-spec.md:346 红线；脚本只到证据台账 + 启发式 SUGGEST 为止）。
- 不给计量设硬性阈值（用户明确选择信息性报告）。
- 不删除 spec-template §14–§18 能力，只做 profile 分层。
