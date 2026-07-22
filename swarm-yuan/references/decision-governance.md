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
| **UserChallenge** | 涉及方向性改变（依赖升级/安全冲突/删稳定单元/多方案/改只读） | **必须停下输出五要素，永不自动决定** | type=UserChallenge + 五要素必填 |

### 2.1 分类规则

- **Mechanical**：探查事实无歧义（如特征卡第 4 项技术栈=探查结果）、配置机械推导（如 WRITABLE_DIRS 从特征卡第 2 项推导）。
- **Taste**：填充有判断空间（如 spec §5.5 复用约束选哪些单元）、诊断有判断空间（如门禁 fail 修复路径）。
- **UserChallenge**：天然需用户决策（如多方案选择）、或触发条件命中（依赖升级/安全冲突/删稳定单元/改只读）。

### 2.2 升级规则（质量优先）

- Mechanical 遇触发条件 → 升 Taste
- Taste 遇触发条件 → 升 UserChallenge
- UserChallenge **永不降级**（最严）

### 2.3 豁免条款（裁决 logic-razor vs abstain 冲突）

R3 调研（`docs/research/R3-methodology.md` §2.2-e）发现 logic-razor 的"至少 10% 瑕疵"铁律与 gsd honest verifier 的"证据不足弃权（abstain: insufficient_spec）"直接冲突。裁决如下：

- 证据不足时按 gsd honest verifier 原则输出 `insufficient_spec` 弃权，**不强制 User Challenge 产出五要素**——五要素须基于充分证据，证据不足先补探查。
- logic-razor 的"至少 10% 瑕疵"铁律限定为 **Taste 类审查发现**，不适用于 UserChallenge 决策（UserChallenge 是方向性决策，不是审查找茬）。

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
| 1 | 特征卡 16 项：AI 主动生成建议值 | Mechanical | 第 2 项可改范围争议 |
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
- UserChallenge 类必填 `alternatives`/`missing_context`/`cost_if_wrong`；Mechanical/Taste 可缺省
- 落盘永不阻塞主流程（trace-log.sh `--decision` 模式继承其永不 fail 设计：落盘失败仅 warn 到 stderr，exit 0）

## 6. 记录方式（trace-log.sh --decision）

```bash
bash scripts/trace-log.sh --decision \
  --type <Mechanical|Taste|UserChallenge> \
  --suggestion '<AI 建议>' \
  --user-action <approved|rejected|revised> \
  [--rationale '<理由>'] [--phase '<阶段>'] \
  [--alternatives '<备选>'] [--missing-context '<缺失上下文>'] [--cost-if-wrong '<代价>']
```

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
