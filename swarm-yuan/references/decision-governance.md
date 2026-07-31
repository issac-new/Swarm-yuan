# 决策治理：AI 主导 + 用户决策的可审计制度

> 对齐标准：ISO/IEC 42001:2023（AI 管理体系）§6.1.2 风险评估 / §6.1.3 风险处置 / §7.3 意识与培训 / §8.3 系统监督 / §9.1 监视测量 / Annex A.2 人工监督
> 口径权威源：`assets/facts.conf`（FACT_DECISION_TYPES=3 / FACT_DECISION_LOG=decisions.jsonl / FACT_USER_CHALLENGE_ELEMENTS=5）
> 调研依据：`docs/research/R1-self-design.md` §五 G1（内在矛盾）；`docs/research/R5-upstream-local.md` §三.3.1 + §七.4（gstack autoplan 决策三级分类+五要素+审计轨迹）

## 1. 问题：AI 主导的决策黑箱

swarm-yuan 的「AI 主导 + 用户决策」原则（SKILL.md）列了 7 条"AI 主动…用户评估"，但全靠 AI 自觉：什么能自动做、什么必须停下问、问过之后怎么留痕，没有机器约束。这与 ISO/IEC 42001:2023 对"人工监督留痕"的要求直接冲突。

本文件把该原则形式化为**可机器审计的制度**：决策有分类、User Challenge 有五要素、每条决策有审计轨迹落盘（decisions.jsonl）。

## 2. 决策三级分类

| 分类 | 语义 | AI 行为 | 留痕要求 |
|------|------|---------|---------|
| **Mechanical** | 有唯一正确答案，从特征卡/代码可机械推导，无多方案 | 直接做，不停下问 | type=Mechanical, user_action=approved |
| **Taste** | 有判断空间但无方向性冲突 | 给方案+推荐，用户评估 | type=Taste, user_action=approved/revised |
| **UserChallenge** | 涉及方向性改变（依赖升级/安全冲突/删稳定单元/多方案/改只读/架构变更/不确定意图） | **必须停下输出五要素，永不自动决定** | type=UserChallenge + 五要素必填 |

### 2.1 分类规则

- **Mechanical**：探查事实无歧义（如特征卡第 4 项技术栈=探查结果）、配置机械推导（如 WRITABLE_DIRS 从特征卡第 2 项推导）。
- **Taste**：填充有判断空间（如 spec §5.5 复用约束选哪些单元）、诊断有判断空间（如门禁 fail 修复路径）。
- **UserChallenge**：天然需用户决策（如多方案选择）、或触发条件命中（依赖升级/安全冲突/删稳定单元/改只读/架构变更/不确定意图）。

### 2.2 升级规则（质量优先）

- Mechanical 遇触发条件 → 升 Taste
- Taste 遇触发条件 → 升 UserChallenge
- UserChallenge **永不降级**（最严）

#### 2.2.1 组件标记驱动升级（决策 29，Palantir AIP 动作授权映射）

> 理念来源：R11 调研（`docs/research/R11-palantir-mapping.md` §4.3）发现 Palantir AIP 的动作授权是"对象标记驱动"——改一个 `load-bearing` 对象的授权，继承自该对象的标记；swarm-yuan 的动作授权是"资产路径驱动"（改 precheck.conf/facts.conf 要 policy-guardian，改普通源码不要），**不取决于组件的稳定性标注或上游依赖**——存在治理盲区。

**规则**：AI 记录决策时，若拟改文件在某个"禁止改"稳定单元的**下游影响域**（决策 28 的 1 跳邻域，即特征卡第 11 项 §11g 记录的直接调用者），自动评 `costly` 可逆性（§2.4 已有 costly 评级，此处补"何时判 costly"的规则）：
- `cost_if_wrong` 字段须反映"可能破坏上游稳定单元契约"（如"改 UserService 可能破坏 UserRepo 的调用契约，需迁移 UserService 的所有调用方"）
- `reversibility` 字段标 `costly`（不阻断，仅作为 `cost_if_wrong` 的输入提示，对齐 §2.4 规则 3）
- 这**不改变三级分类**（Mechanical/Taste/UserChallenge）——只在 `reversibility` 横切属性上体现；若该下游改动还命中 §2.2 其他触发条件（如架构变更/删稳定单元），则按原升级规则升 UserChallenge

**与 §2.4 的关系**：§2.4 定义了 `reversible`/`costly`/`one-way` 三级可逆性；本规则补"何时判 costly"的判定准则——"拟改文件在禁止改稳定单元的下游影响域"是判 costly 的充分条件之一。`one-way` 的判定（§2.4 规则 2）仍由"删稳定单元/破坏性 DDL/公开发布/格式锁定"等触发，不冲突。

**与决策 28 的关系**：决策 28 补"标记沿调用链传播"的**门禁层**缺口（`--stable-diff` 传播 warn）；本规则补"动作授权锚定组件标记"的**决策层**缺口（`costly` 评级）。双通道：门禁 warn 提示风险 + 决策 `costly` 反映撤销成本。两者共用同一个"下游影响域"数据源（特征卡第 11 项 §11g）。

### 2.3 豁免条款（裁决 logic-razor vs abstain 冲突）

R3 调研（`docs/research/R3-methodology.md` §2.2-e）发现 logic-razor 的"至少 10% 瑕疵"铁律与 gsd honest verifier 的"证据不足弃权（abstain: insufficient_spec）"直接冲突。裁决如下：

- 证据不足时按 gsd honest verifier 原则输出 `insufficient_spec` 弃权，**不强制 User Challenge 产出五要素**——五要素须基于充分证据，证据不足先补探查。
- logic-razor 的"至少 10% 瑕疵"铁律限定为 **Taste 类审查发现**，不适用于 UserChallenge 决策（UserChallenge 是方向性决策，不是审查找茬）。

### 2.4 决策可逆性评级（横切属性）

> 理念来源：gsd-core v1.8.0 `feat(#1951): reversibility tagging - gate one-way-door decisions`（commit c5e03717）。gsd-core 在 plan 的 `<task>` 上记录 `<reversibility rating="reversible|costly|one-way">`，`one-way` 自动插 `checkpoint:decision`。本节把该理念吸收为 swarm-yuan 决策治理的**横切属性**（对 §2 三级分类的修饰，不是新分类）。

**三级可逆性**（作为每条决策的属性，非独立分类维度）：

| 评级 | 语义 | 对 §2 分类的修饰 |
|------|------|----------------|
| `reversible` | 可低成本撤销（改回即可，无持久副作用） | 不改变原分类 |
| `costly` | 可撤销但代价高（需迁移/回滚数据/影响下游） | 标记但不阻断；UserChallenge 类的 `cost_if_wrong` 字段须反映该代价 |
| `one-way` | 不可逆或极难逆（删稳定单元/破坏性 DDL/公开发布/格式锁定） | **自动升级到 UserChallenge**（横切 §2.2 升级规则），即便原分类是 Mechanical/Taste |

**规则**：
1. **不确定时按 `reversible`**（避免 checkpoint 疲劳，对齐 gsd-core 默认值）。
2. `one-way` 决策**横切升级**：原 Mechanical/Taste 若评 `one-way`，自动按 UserChallenge 处理（必须停下输出五要素）。这与 §2.2 的"遇触发条件升 UserChallenge"同源--可逆性是触发条件之一。
3. `costly` **不阻断**：仅作为 `cost_if_wrong` 字段的输入提示，不强制升级。
4. 评级由 AI 在记录决策时给出（基于特征卡/探查/领域知识），用户可在 `user_action=revised` 时修正评级。

**与 §2.2 升级规则的关系**：§2.2 列出的触发条件（依赖升级/安全冲突/删稳定单元/改只读/架构变更/不确定意图）大多天然是 `one-way` 或 `costly`；本节给这些触发条件一个统一的"撤销成本"语义框架，使升级判定可机器辅助（如 `删稳定单元` -> `one-way` -> 自动 UserChallenge）。

**落盘**：`decisions.jsonl` 每行可带 `reversibility` 字段（缺省 `reversible`，对齐规则 1）；见 §5 schema。

## 3. User Challenge 五要素

autoplan 的 User Challenge 五要素（`docs/research/R5-upstream-local.md` §三.3.1 引述 autoplan/SKILL.md:933-966）：

| 要素 | decisions.jsonl 字段 | 含义 |
|------|---------------------|------|
| 用户原话/当前方向 | `ai_suggestion` | AI 观察到的用户当前既定方向（即建议要改变的对象） |
| 理由 | `rationale` | 为什么建议改变方向 |
| 备选方案 | `alternatives` | 除建议外的其他可行方案 |
| 可能缺失的上下文 | `missing_context` | AI 可能不知道的、影响决策的信息 |
| 若错了的代价 | `cost_if_wrong` | 如果按 AI 建议走但 AI 错了，代价是什么 |

**永不自动**：即使两个模型一致认为该改变用户既定方向，也**永不自动决定**——必须输出五要素，等用户裁定（approved/rejected/revised）后才继续。

## 4. SKILL.md 7 条 → 三类映射

| # | SKILL.md 现有条目 | 默认分类 | User Challenge 触发条件 |
|---|------------------|---------|----------------------|
| 1 | 特征卡 17 项：AI 主动生成建议值 | Mechanical | 第 2 项可改范围争议 |
| 2 | 门禁 conf 142 变量：AI 主动推导 | Mechanical | 涉及安全规则（SENSITIVE_WHITELIST/CRYPTO_PROFILE） |
| 3 | spec 模板填充：AI 主动预填 | Taste | §5.6 版本约束声明/§5.7 安全约束 |
| 4 | 门禁 fail：AI 主动诊断+修复建议 | Taste | 修复涉及依赖升级/安全冲突/删稳定单元 |
| 5 | 编码实现：AI 主动给代码方案 | Taste | 多方案选择/改只读/删稳定单元 |
| 6 | 多方案选择：AI 主动 2+ 方案权衡 | UserChallenge | 永远（永不自动） |
| 7 | 问题排查：AI 主动分析+解决方案 | Taste | 涉及架构变更/安全冲突 |

## 5. decisions.jsonl 格式

落盘路径：`<project>/.swarm-yuan/decisions.jsonl`（与 trace.jsonl、state.yaml 同目录 `.swarm-yuan/`）。每行一个 JSON 对象：

```json
{"ts":"2026-07-22T10:30:00Z","phase":"design","type":"UserChallenge","ai_suggestion":"升级 vue 3.4→3.5","user_action":"approved","rationale":"3.5 修复 overlay 注入 bug","actor":"swarm-yuan/ai","alternatives":"保持 3.4,升 3.5-rc","missing_context":"可能影响 overlay 注入","cost_if_wrong":"overlay 失效需回退"}
```

- `type`：`Mechanical` / `Taste` / `UserChallenge`（缺五要素降级为 `UserChallenge:incomplete`）
- `user_action`：`approved` / `rejected` / `revised`
- `reversibility`：`reversible`（缺省）/ `costly` / `one-way`（§2.4 横切属性；`one-way` 自动升级到 UserChallenge）
- UserChallenge 类必填 `alternatives`/`missing_context`/`cost_if_wrong`；Mechanical/Taste 可缺省
- 落盘永不阻塞主流程（trace-log.sh `--decision` 模式继承其永不 fail 设计：落盘失败仅 warn 到 stderr，exit 0）

## 6. 记录方式（trace-log.sh --decision）

```bash
bash scripts/trace-log.sh --decision \
  --type <Mechanical|Taste|UserChallenge> \
  --suggestion '<AI 建议>' \
  --user-action <approved|rejected|revised> \
  [--rationale '<理由>'] [--phase '<阶段>'] \
  [--reversibility <reversible|costly|one-way>] \
  [--alternatives '<备选>'] [--missing-context '<缺失上下文>'] [--cost-if-wrong '<代价>']
```

> `--reversibility` 缺省 `reversible`（§2.4 规则 1）。传 `one-way` 时，trace-log.sh 不自动改写 `type`--升级判定由 AI 在调用前完成（AI 须把 `one-way` 决策的 `--type` 设为 `UserChallenge` 并填五要素）；脚本仅忠实落盘传入值。

阶段流转由 `state-machine.sh transition` 自动记录 Taste 类决策；门禁 fail 诊断（`_fix_suggest`）提示须按本文件 §User Challenge 记录；spec §2 决策记录表关联 decisions.jsonl 行号。

## 7. 对齐 ISO/IEC 42001:2023

| 条款 | 要求 | 本文件落地 |
|------|------|----------|
| §6.1.2 AI 风险评估 | 识别 AI 系统决策风险 | 决策分类（Mechanical 低/Taste 中/UserChallenge 高风险） |
| §6.1.3 AI 风险处置 | 处置措施留痕 | decisions.jsonl（type/user_action/rationale） |
| §7.3 AI 意识与培训 | 人工监督者可获取决策信息 | decisions.jsonl 落盘可审计 + spec §2 关联行号 |
| §8.3 AI 系统监督 | 人工监督留痕 | UserChallenge 五要素 + user_action 字段 |
| §9.1 监视测量分析 | AI 决策绩效数据 | decisions.jsonl 结构化字段（可后续聚合分析） |
| Annex A.2 人工监督 | 人可干预 AI 决策 | UserChallenge 永不自动 + 用户裁定后继续 |

**对齐边界**：本文件落地的是"人工监督留痕"这一个点，不覆盖 ISO/IEC 42001 全部（管理体系范围评估/AI 系统影响评估/外部供应商管理属标准补全范畴）。

## 8. 跨会话决策回溯（claude-mem 集成）

决策落盘 `decisions.jsonl` 是**当前变更**的审计轨迹；跨会话/跨压缩的历史决策回溯借助 claude-mem（见 `references/memory-persistence.md`）：

```bash
# 会话启动/压缩后，先 search 找相关历史决策
claude-mem search "UserChallenge 依赖升级"
# 再 timeline 看该决策的上下文
claude-mem timeline <observation-id>
```

**组合闭环**：`decisions.jsonl`（本次变更决策，机器可校验）+ `trace.jsonl`（调用轨迹）+ claude-mem（跨会话长期记忆）——三层覆盖"当前可审计 + 过程可追溯 + 长期可回溯"。AI 在新会话接手时，先 `claude-mem search` 相关决策历史，再读当前 `decisions.jsonl`，形成完整的决策上下文。

**聚合分析**：`scripts/cost-report.sh` 输出决策治理段（按类型/裁定/阶段分布 + UserChallenge 计数），对齐 ISO/IEC 42001 §9.1 监视测量——决策绩效数据可用于评估"AI 主导+用户决策"的运行质量（如 UserChallenge 的 approved/rejected/revised 分布反映人工监督有效性）。
