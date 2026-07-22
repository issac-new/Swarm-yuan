# G1：AI 决策治理与审计轨迹设计

> 日期：2026-07-22 ｜ 分支：`feat/g1-decision-governance`
> 范围：自身理念重构先行（C 方向第一批）—— G1 决策治理 + 审计轨迹
> 对齐标准：ISO/IEC 42001:2023（AI 管理体系）人工监督留痕
> 口径权威源：`swarm-yuan/assets/facts.conf`（catchphrase 数字单一事实源，self-check 机器执法）

---

## 1. 问题、目标与方案选型

### 1.1 问题定位（调研已确认的三条断点）

**断点 1 —「AI 主导 + 用户决策」是散文原则，无机制边界。** `SKILL.md:54-62` 列了 7 条"AI 主动…用户评估"，但全靠 AI 自觉：什么能自动做、什么必须停下来问、问过之后怎么留痕，没有任何机器约束。R1 调研（`docs/research/R1-self-design.md` §五 G1）称之为内在矛盾——AI 主导的连贯动作铁律（不可中途停止）与 ECC Must-Never（绝不替用户做决定）在"多方案选择/依赖升级"场景直接冲突，唯一的调和条款是 `SKILL.md:52` 的"疑虑必确认"，但无机制保证长跑流程中 AI 真的停。

**断点 2 — 决策零留痕，无法审计。** 36 门禁对"代码合规"执法严格（strict 12 真 fail），但对"AI 替用户做了哪些决定"零执法——决策是 AI 与用户之间的黑箱。这与 ISO/IEC 42001:2023（AI 管理体系）对"人工监督留痕"的要求直接冲突，也是后续 B 方向（标准/安全补全）合规叙事的根基缺口。

**断点 3 — 已有可用参照但未吸收。** R5 调研（`docs/research/R5-upstream-local.md` §七.4）确认 gstack autoplan 给出了完整答案：决策三级分类（Mechanical 静默自动 / Taste 自动但终审浮现 / **User Challenge 两模型一致认为该改用户既定方向——永不自动**）+ Decision Audit Trail 落盘每条决策 + Phase 0 restore point。R5 评级"❌ 未吸收"。autoplan 的 User Challenge 五要素（用户原话/模型建议/理由/可能缺失的上下文/若错了的代价）与 swarm-yuan 的"疑虑必确认"天然兼容——User Challenge 永不自动 ≈ 疑虑必确认的形式化。

### 1.2 目标

把"AI 主导 + 用户决策"从散文原则升级为**可机器审计的制度**：决策有分类、User Challenge 有五要素物化、每条决策有审计轨迹落盘、门禁 fail 诊断走决策日志，对齐 ISO/IEC 42001 人工监督留痕。

### 1.3 方案选型（三档，选 B）

| 档 | 内容 | 对齐标准 | 工作量 | 选择 |
|---|---|---|---|---|
| A 最小 | 决策分类注册表 + User Challenge 物化，无审计轨迹/门禁 | 无 | 2-3 文件 | ✗ 对齐不了 42001 |
| **B 中等（选）** | A + 决策审计轨迹 decisions.jsonl + state-machine/fail 诊断集成 + spec §2 增强 | ISO/IEC 42001 人工监督留痕 | 4-5 文件 | ✓ |
| C 完整 | B + checkpoint/restore 子命令 + `--decision-audit` 门禁 + CI fixture | 42001 + 阶段级可回滚 | 6-8 文件 + 门禁 + fixture | 留 G1 稳定后增量补 |

**选 B 的理由**：B 把"决策可审计"这条 ISO/IEC 42001 的硬要求落地（decisions.jsonl + 贯穿 fail 诊断/状态机/spec），又不引入 restore point 与决策 13（断点续传状态门）的语义冲突——restore point 属"阶段级可回滚"，是 G4（自举闭环+阶段机制）的范畴，G1 聚焦"决策治理"单一切片，scope 干净。C 档的 `--decision-audit` 门禁 + fixture 留到 G1 验证稳定后作为增量补。

---

## 2. 架构与组件

### 2.1 总体架构

```
       ┌── references/decision-governance.md ──────────────┐
       │  决策分类注册表（Mechanical/Taste/UserChallenge）  │  ← 新增，立法层
       │  User Challenge 五要素 + 豁免条款                   │
       │  对齐 ISO/IEC 42001 人工监督留痕                   │
       └──────────────────────┬──────────────────────────┘
                              │ 驱动
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
  SKILL.md 重写          trace-log.sh           state-machine.sh
  "AI 主导+用户决策"段   新增 --decision 模式      transition 记录决策
  (生成器入口)           (落盘 decisions.jsonl)   (guard 关联 decision log)
        │                     │                     │
        │                     ▼                     │
        │          <project>/.swarm-yuan/              │
        │          decisions.jsonl  ← 新产出物           │
        │          (ts/phase/type/ai_suggestion/        │
        │           user_action/rationale/actor)         │
        │                     │                     │
        ▼                     ▼                     ▼
  precheck.sh _fix_suggest  spec-template.md §2
  (fail 诊断走 decision log) (决策记录段增强)
```

### 2.2 组件清单

| # | 文件 | 动作 | 改动要点 | 行号锚点 |
|---|------|------|---------|---------|
| 1 | `references/decision-governance.md` | **新增** | 决策分类注册表（三类）+ User Challenge 五要素 + 豁免条款 + ISO/IEC 42001 对齐声明 | — |
| 2 | `SKILL.md` | 改 | 重写「AI 主导 + 用户决策原则」段（L54-62）：7 条各标注决策分类 + 引用 decision-governance.md | L54-62 |
| 3 | `assets/trace-log.sh` | 改 | 新增 `--decision` 模式：解析 `--type/--suggestion/--user-action/--rationale` 等参数，追加 JSON 行到 `decisions.jsonl` | L17-33, L48-59 |
| 4 | `assets/state-machine.sh` | 改 | transition 记录决策；guard_phase design 准入检查 decisions.jsonl 存在性（warn 不 fail） | L186-205, L109-126 |
| 5 | `assets/precheck.sh` | 改 | `_fix_suggest` 每条建议末尾追加"决策留痕"提示 | L1239-1271 |
| 6 | `assets/spec-template.md` | 改 | §2 决策记录扩为 7 列表格 + 引导文 | L25-31 |

### 2.3 产出物

**`.swarm-yuan/decisions.jsonl`**（与 `trace.jsonl`、`state.yaml` 同目录 `STATE_DIR`，`state-machine.sh:18`）

每行一个 JSON 对象：

```json
{
  "ts": "2026-07-22T10:30:00Z",
  "phase": "design",
  "type": "UserChallenge",
  "ai_suggestion": "升级 vue 3.4→3.5",
  "user_action": "approved",
  "rationale": "性能问题已确认，用户评估后批准",
  "actor": "swarm-yuan/ai",
  "alternatives": ["保持 3.4", "升 3.5-rc"],
  "missing_context": "可能影响 overlay 注入",
  "cost_if_wrong": "overlay 失效需回退"
}
```

- `type`：`Mechanical` / `Taste` / `UserChallenge`
- `user_action`：`approved` / `rejected` / `revised`
- UserChallenge 类必填后三字段（alternatives/missing_context/cost_if_wrong），对应 autoplan 五要素
- Mechanical/Taste 类后三字段可缺省

### 2.4 与已有机制的协同

| 已有机制 | G1 关系 | 协同方式 |
|---------|---------|---------|
| `trace-log.sh` 节点级追踪（决策 16） | 复用其双通道+永不 fail 设计 | `--decision` 是 `--node` 姊妹模式 |
| `state-machine.sh` draft/active 状态门（决策 13） | 不冲突 | draft 期 decisions.jsonl 可空，`--mark-active` 后须非空 |
| `precheck.sh` fail 诊断（决策 15） | 增强不改变 | `_fix_suggest` 只追加提示 |
| `spec-template.md §2` 决策记录 | 扩展 | 表格扩列 + 引导文 |
| `SKILL.md` AI 主导原则 | 细化 | 7 条各标注分类 |
| 决策 13 断点续传 | 不触碰 | restore point 属 G4 |

### 2.5 不做的事（scope 边界）

- ❌ 不做 `--decision-audit` 门禁（留 G1 验证稳定后增量补）
- ❌ 不做 checkpoint/restore 子命令（G4 范畴）
- ❌ 不做 CI fixture（C 档）
- ❌ 不改 `fail()` 语义
- ❌ 不触碰断点续传状态门语义

---

## 3. 数据流与决策分类映射表

### 3.1 端到端数据流

#### 场景 A：Mechanical 决策（静默自动）

```
AI Step 5 配置 precheck.conf
  → AI 推导 WRITABLE_DIRS=["src/"]（从特征卡第 2 项）
  → 判定：Mechanical 类（配置推导，无多方案/无依赖升级/无安全冲突）
  → AI 直接填值，不停下问
  → trace-log.sh --decision --type Mechanical \
      --suggestion 'WRITABLE_DIRS=["src/"]' \
      --user-action approved \
      --rationale '从特征卡第2项机械推导，无歧义'
  → 追加到 .swarm-yuan/decisions.jsonl
  → 流程继续，不中断
```

#### 场景 B：User Challenge 决策（必停，五要素）

```
AI Step 4.5 框架深化，发现 vue 3.4 项目可升 3.5
  → 判定：UserChallenge 类（依赖升级 = 决策 18 质量优先 + SKILL.md:52 疑虑必确认）
  → AI 必须停下，输出五要素：
     ai_suggestion: 升级 vue 3.4→3.5
     alternatives: ["保持 3.4", "升 3.5-rc"]
     rationale: 3.5 修复了 overlay 注入已知 bug
     missing_context: 可能影响 SwarmStudio overlay 注入链路
     cost_if_wrong: overlay 失效需回退
  → 用户裁定（approved/rejected/revised）
  → trace-log.sh --decision --type UserChallenge \
      --suggestion '升级 vue 3.4→3.5' \
      --user-action <用户裁定> \
      --rationale '3.5 修复 overlay 注入 bug' \
      --alternatives '保持 3.4,升 3.5-rc' \
      --missing-context '可能影响 overlay 注入' \
      --cost-if-wrong 'overlay 失效需回退'
  → 追加到 .swarm-yuan/decisions.jsonl
  → 按用户裁定继续
```

#### 场景 C：门禁 fail 触发决策留痕

```
precheck.sh --reuse fail（新增单元与既有重名）
  → fail() 收集 FAIL_IDS="gate_reuse_duplicate"
  → _fix_suggest 输出建议 + 追加提示：
     "• gate_reuse_duplicate: 检查 spec §5.5 复用约束...
      （决策留痕：此 fail 若涉及多方案/依赖升级/安全冲突，
       须按 decision-governance.md §User Challenge 记录）"
  → AI 诊断：是否是 User Challenge？
     - 若是（如重名因依赖升级引入）→ 走场景 B 五要素
     - 若否（纯 Mechanical 误报）→ AI 调 conf 后重跑，记录 Taste 类决策
  → 修复后重跑门禁
```

#### 场景 D：阶段流转记录

```
state-machine.sh transition open→design
  → guard_phase("design") 检查 proposal.md 存在 → 通过
  → set_field phase design
  → trace-log.sh --decision --type Taste \
      --suggestion 'design' \
      --user-action approved \
      --rationale 'guard 通过，proposal.md 已就绪'
  → 追加到 .swarm-yuan/decisions.jsonl
```

### 3.2 决策分类映射表（SKILL.md 7 条 → 三类）

| # | SKILL.md 现有条目 | 默认分类 | 判定依据 | User Challenge 触发条件 |
|---|------------------|---------|---------|----------------------|
| 1 | 特征卡 16 项：AI 主动生成建议值 | Mechanical | 探查事实，无歧义 | 第 2 项可改范围争议 |
| 2 | 门禁 conf 142 变量：AI 主动推导 | Mechanical | 从特征卡机械推导 | 涉及安全规则（SENSITIVE_WHITELIST/CRYPTO_PROFILE） |
| 3 | spec 模板填充：AI 主动预填 | Taste | 填充有判断空间 | §5.6 版本约束声明/§5.7 安全约束 |
| 4 | 门禁 fail：AI 主动诊断+修复建议 | Taste | 诊断有判断空间 | 修复涉及依赖升级/安全冲突/删稳定单元 |
| 5 | 编码实现：AI 主动给代码方案 | Taste | 方案有判断空间 | 多方案选择/改只读/删稳定单元 |
| 6 | 多方案选择：AI 主动 2+ 方案权衡 | UserChallenge | 天然需用户决策 | 永远（永不自动） |
| 7 | 问题排查：AI 主动分析+解决方案 | Taste | 方案有判断空间 | 涉及架构变更/安全冲突 |

**分类规则**：
- **Mechanical**：有唯一正确答案，从特征卡/代码可机械推导，无多方案。AI 直接做，记录留痕。
- **Taste**：有判断空间但无方向性冲突，AI 给方案+推荐，用户评估。默认 approved，可 revised。
- **UserChallenge**：涉及方向性改变（依赖升级/安全冲突/删稳定单元/多方案/改只读），**AI 必须停下输出五要素，永不自动决定**。

**升级规则**（质量优先）：
- Mechanical 遇触发条件 → 升 Taste
- Taste 遇触发条件 → 升 UserChallenge
- UserChallenge 永不降级（最严）

**豁免条款**（裁决 R3 §2.2-e 的 logic-razor vs abstain 冲突）：
- 证据不足时按 gsd honest verifier 原则输出 `insufficient_spec` 弃权，不强制 User Challenge 产出五要素——五要素须基于充分证据，证据不足先补探查。
- logic-razor 的"至少 10% 瑕疵"铁律限定为 Taste 类审查发现，不适用于 UserChallenge 决策。

### 3.3 decisions.jsonl 生命周期

| 阶段 | 状态 | 约束 |
|------|------|------|
| 生成流程 draft 期 | 可空 / 可有 Mechanical+Taste 条目 | 状态门允许 |
| `--mark-active` 时 | 须非空（至少 1 条） | `verify_completeness --strict` 校验 |
| 目标 skill 运行期 | 持续追加 | state-machine transition 自动记；AI 按 SKILL.md 引导记 |
| `--upgrade` 时 | 保留不覆盖 | 与 state.yaml/trace.jsonl 同保护 |

### 3.4 `--verify-completeness` 接入点

generate-skill.sh `verify_completeness()` 在 L433 后新增 `decisions_miss` 检查段（类比 `trace_miss` 模式）：

1. 扫 `$skill_dir/.swarm-yuan/decisions.jsonl` 是否存在
2. 若存在：逐行校验 JSON 合法性（bash 3.2 兼容：python3 -c 'json.loads' 或 grep 字段存在性降级）
3. 若含 UserChallenge 行：校验五要素非空
4. 缺失/非法/缺要素 → 追加到 decisions_miss
5. decisions_miss 并入 hits 统一裁决（draft 放行 / strict exit 1）

**降级**：无 python3 时降级为 grep 字段存在性检查，不阻塞主流程。

---

## 4. 错误处理、测试与对齐标准

### 4.1 错误处理（三道防线）

**防线 1：decisions.jsonl 落盘永不阻塞主流程**

继承 `trace-log.sh` 永不 fail 设计（L15 无 `-e` + L54 落盘失败仅 warn + L60 永远 exit 0）：

| 故障 | 行为 | 用户可见 |
|------|------|---------|
| `.swarm-yuan/` 目录不可写 | stderr warn，继续主流程 | `⚠ decisions.jsonl 落盘失败，决策未留痕（不阻塞）` |
| `--decision` 缺必填参数 | stderr warn，记录降级行（type 后追加 `:incomplete`） | `⚠ UserChallenge 缺 cost_if_wrong，降级记录` |
| JSON 转义失败 | 跳过该条，warn | `⚠ 决策 JSON 转义失败，跳过` |

**防线 2：verify_completeness 校验不改变 fail 语义**

与决策 13 状态门同构——decisions_miss 只在 `--strict` 路径才 exit 1，draft 模式放行：

| 模式 | decisions.jsonl 缺失/非法 | 行为 |
|------|--------------------------|------|
| draft（默认） | 放行 | warn 列出缺失项，return 0 |
| `--strict`（mark-active） | exit 1 | 列入 hits（与占位符同门槛） |

**防线 3：state-machine guard 不因 decisions.jsonl 缺失阻塞流转**

guard_phase design 准入的 decisions.jsonl 检查是 **warn 不 fail**：
- 文件不存在 → warn
- 文件存在但空 → 通过
- 文件存在且非空 → 通过

**不阻塞流转的理由**：decisions.jsonl 是"决策留痕"不是"阶段准入产出物"。留痕缺失不应阻塞开发——否则把"可审计"变成"必须先填表才能干活"，违反连贯动作铁律。

### 4.2 测试策略

G1 不新增 CI fixture（C 档才做）。验证靠三道现有机制：

| 验证手段 | 覆盖什么 | 怎么跑 |
|---------|---------|--------|
| `bash -n` 语法检查 | 改动后语法不崩 | CI shellcheck Job 已含 |
| `self-check.sh check_doc_consistency` | facts.conf 新增口径不漂移 | 改 facts.conf 后跑 |
| `verify_completeness` 手动验证 | decisions.jsonl 校验逻辑正确 | 造含/缺五要素的文件跑 --strict |

**手动验证清单**：

1. 造空 `.swarm-yuan/decisions.jsonl` → `--verify-completeness` draft 放行，`--strict` exit 1
2. 造合法 Mechanical 行 → 两种模式都通过
3. 造 UserChallenge 行缺 cost_if_wrong → draft warn，strict exit 1
4. 造非法 JSON 行 → draft warn，strict exit 1
5. trace-log.sh `--decision` 缺 `--type` → warn 降级记录，exit 0
6. state-machine transition → decisions.jsonl 新增 Taste 行
7. precheck.sh fail → `_fix_suggest` 输出含"决策留痕"提示

### 4.3 对齐标准（ISO/IEC 42001:2023 映射）

| ISO/IEC 42001 条款 | 要求 | G1 落地 |
|-------------------|------|---------|
| §6.1.2 AI 风险评估 | 识别 AI 系统决策风险 | 决策分类（Mechanical 低/Taste 中/UserChallenge 高） |
| §6.1.3 AI 风险处置 | 处置措施留痕 | decisions.jsonl |
| §7.3 AI 意识与培训 | 人工监督者可获取决策信息 | decisions.jsonl 落盘可审计 + spec §2 关联行号 |
| §8.3 AI 系统监督 | 人工监督留痕 | UserChallenge 五要素 + user_action |
| §9.1 监视测量分析 | AI 决策绩效数据 | decisions.jsonl 结构化字段 |
| Annex A.2 人工监督 | 人可干预 AI 决策 | UserChallenge 永不自动 + 用户裁定后继续 |

**对齐边界**：G1 落地的是"人工监督留痕"这一个点，不覆盖 ISO/IEC 42001 全部。decision-governance.md 会显式声明这个边界。

### 4.4 facts.conf 新增口径

```
# 决策治理（G1，对齐 ISO/IEC 42001）
FACT_DECISION_TYPES=3                # Mechanical / Taste / UserChallenge
FACT_DECISION_LOG=decisions.jsonl   # 决策审计轨迹落盘文件名
FACT_USER_CHALLENGE_ELEMENTS=5      # ai_suggestion/rationale/alternatives/missing_context/cost_if_wrong
```

self-check `check_doc_consistency` 扩展：扫 SKILL.md/decision-governance.md 的"3 类决策"/"decisions.jsonl"/"五要素"口径与 facts.conf 一致。

### 4.5 遗留边界

| 项 | 留给谁 | 理由 |
|----|-------|------|
| `--decision-audit` 门禁 + fixture | G1 验证稳定后增量补（C 档） | 避免未经真实项目校准的硬门禁淹没误报 |
| checkpoint/restore 子命令 | G4（自举闭环+阶段机制） | restore point 属阶段级可回滚，与决策治理正交 |
| decisions.jsonl 聚合分析脚本 | 后续可选 | cost-report.sh 可扩展 |
| AI 决策质量度量（置信度/命中率） | 后续可选 | gstack adaptive gating 属 A 方向 |
| 跨会话决策回溯（claude-mem 集成） | 后续可选 | G1 只落盘不联网 |
| `--upgrade` 保留 decisions.jsonl | **需做**（实现时） | 归入 PROJECT_SPECIFIC_FILES 逻辑 |

### 4.6 实现顺序预估

| WP | 内容 | 依赖 | 预估文件改动 |
|----|------|------|------------|
| WP-G1-1 | 新增 `references/decision-governance.md` + facts.conf 口径 | 无 | 1 新增 + 1 改 |
| WP-G1-2 | trace-log.sh `--decision` 模式 | WP-G1-1 | 1 改 |
| WP-G1-3 | state-machine.sh transition+guard 集成 | WP-G1-2 | 1 改 |
| WP-G1-4 | precheck.sh `_fix_suggest` 增强 + spec-template §2 扩列 | WP-G1-1 | 2 改 |
| WP-G1-5 | generate-skill.sh verify_completeness decisions_miss 校验 | WP-G1-2 | 1 改 |
| WP-G1-6 | SKILL.md 重写 AI 主导段 + self-check 扩展 + 文档口径同步 | 全部 | 2 改 |

---

## 5. 关键证据索引

- R1 自身设计理念分析（G1 内在矛盾）：`docs/research/R1-self-design.md` §五 G1
- R5 gstack autoplan 调研（决策三级分类+五要素+审计轨迹）：`docs/research/R5-upstream-local.md` §三.3.1, §七.4
- R3 logic-razor vs abstain 冲突：`docs/research/R3-methodology.md` §2.2-e
- SKILL.md AI 主导原则现状：`swarm-yuan/SKILL.md:54-62`
- SKILL.md 疑虑必确认：`swarm-yuan/SKILL.md:52`
- trace-log.sh 永不 fail 设计：`swarm-yuan/assets/trace-log.sh:15,54,60`
- state-machine.sh transition：`swarm-yuan/assets/state-machine.sh:186-205`
- state-machine.sh guard_phase：`swarm-yuan/assets/state-machine.sh:102-184`
- precheck.sh fail() + _fix_suggest：`swarm-yuan/assets/precheck.sh:412-420,1239-1271`
- spec-template.md §2 现状：`swarm-yuan/assets/spec-template.md:25-31`
- generate-skill.sh verify_completeness：`swarm-yuan/scripts/generate-skill.sh:349-451`
- facts.conf 单一事实源：`swarm-yuan/assets/facts.conf`
- 决策 13 断点续传状态门：`docs/paradigm-decisions.md` 决策 13
- 决策 15 fail 诊断：`docs/paradigm-decisions.md` 决策 15
- 决策 16 全链路追踪：`docs/paradigm-decisions.md` 决策 16
