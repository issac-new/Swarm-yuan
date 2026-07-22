# G1：AI 决策治理与审计轨迹 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 swarm-yuan 的"AI 主导 + 用户决策"从散文原则升级为可机器审计的制度——决策有三级分类（Mechanical/Taste/UserChallenge）、User Challenge 有五要素物化、每条决策有审计轨迹落盘（decisions.jsonl），对齐 ISO/IEC 42001:2023 人工监督留痕。

**Architecture:** 新增 `references/decision-governance.md` 作为立法层文档，定义决策分类规则与 User Challenge 五要素。在 `trace-log.sh` 新增 `--decision` 模式落盘 `decisions.jsonl`（复用其永不 fail 设计）。`state-machine.sh` 的 transition 在阶段流转后记一条决策；guard_phase design 准入 warn 检查 decisions.jsonl 存在性。`precheck.sh` 的 `_fix_suggest` 在 fail 诊断末尾追加决策留痕提示。`spec-template.md` §2 决策记录表扩列。`generate-skill.sh` 的 `verify_completeness` 新增 decisions.jsonl 合法性校验（strict 路径 exit 1）。`SKILL.md` 重写 AI 主导段，7 条各标注分类。`facts.conf` + `self-check.sh` 扩展新口径。

**Tech Stack:** Bash 3.2 兼容（无 `declare -A`、`sed -i.bak+rm`、`grep -E`、`date -u`）；Markdown 模板；JSONL 落盘。

**Spec:** `docs/superpowers/specs/2026-07-22-g1-decision-governance-design.md`

## Global Constraints

- **bash 3.2 兼容**：不用 `declare -A`（用平行数组/字符串）；`sed -i.bak` 然后 `rm`；`grep -E`；`date -u '+%Y-%m-%dT%H:%M:%SZ'`；`$(cd ... && pwd)` 替代 `readlink -f`；`${var}` 引号防 C-locale；空数组用 `${arr[@]+"${arr[@]}"}` 防空崩。
- **永不 fail 阻塞主流程**：trace-log.sh `--decision` 模式落盘失败仅 warn 到 stderr，永远 exit 0（继承现有 `set -uo pipefail` 无 `-e` 设计）。
- **不改 fail() 语义**：`precheck.sh` 的 `fail()` 与 `_fix_suggest` 只追加输出提示，不改 fail 计数/exit 行为。
- **decisions.jsonl 路径**：`<project>/.swarm-yuan/decisions.jsonl`（与 `trace.jsonl`、`state.yaml` 同 `STATE_DIR`，`state-machine.sh:18`）。
- **口径权威源**：`swarm-yuan/assets/facts.conf`（catchphrase 数字单一事实源，self-check 机器执法）。
- **commit 风格**：Conventional Commits，中英文 header 跟随仓库历史（`feat(g1):` / `docs(g1):` scope）。

## File Structure

| 文件 | 责任 | 动作 |
|------|------|------|
| `swarm-yuan/references/decision-governance.md` | 决策分类注册表 + User Challenge 五要素 + 豁免条款 + ISO/IEC 42001 对齐声明 | **新增** |
| `swarm-yuan/assets/trace-log.sh` | 新增 `--decision` 模式：解析决策参数，追加 JSON 行到 decisions.jsonl | 改（L17-33 参数段 + L48-59 落盘段） |
| `swarm-yuan/assets/state-machine.sh` | transition 记录决策；guard_phase design 准入 warn 检查 decisions.jsonl | 改（L186-205, L109-126） |
| `swarm-yuan/assets/precheck.sh` | `_fix_suggest` 每条建议末尾追加决策留痕提示 | 改（L1239-1271） |
| `swarm-yuan/assets/spec-template.md` | §2 决策记录扩为 7 列表格 + 引导文 | 改（L25-31） |
| `swarm-yuan/scripts/generate-skill.sh` | `verify_completeness` 新增 decisions_miss 校验段 | 改（L433 后） |
| `swarm-yuan/SKILL.md` | 重写「AI 主导 + 用户决策原则」段，7 条各标注分类 | 改（L54-62） |
| `swarm-yuan/assets/facts.conf` | 新增决策治理口径 3 条 | 改（末尾） |
| `swarm-yuan/scripts/self-check.sh` | `check_doc_consistency` 扩展决策治理口径扫描 | 改（L531+ 段） |

---

### Task 1: 新增 references/decision-governance.md + facts.conf 口径

**Files:**
- Create: `swarm-yuan/references/decision-governance.md`
- Modify: `swarm-yuan/assets/facts.conf`（末尾追加）
- Test: 手动 `source facts.conf` + `grep` 验证口径存在

**Interfaces:**
- Produces: `references/decision-governance.md`（被 SKILL.md L54-62 引用，被 spec-template.md §2 引导文引用）
- Produces: `FACT_DECISION_TYPES=3` / `FACT_DECISION_LOG=decisions.jsonl` / `FACT_USER_CHALLENGE_ELEMENTS=5`（被 self-check.sh Task 6 消费）

- [ ] **Step 1: 写 references/decision-governance.md**

```markdown
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
| 用户原话/当前方向 | `ai_suggestion` | AI 观察到的用户当前既定方向 |
| 模型建议 | （ai_suggestion 本身即是建议） | — |
| 理由 | `rationale` | 为什么建议改变方向 |
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

落盘路径：`<project>/.swarm-yuan/decisions.jsonl`（与 trace.jsonl 同目录）。每行一个 JSON 对象：

```json
{"ts":"2026-07-22T10:30:00Z","phase":"design","type":"UserChallenge","ai_suggestion":"升级 vue 3.4→3.5","user_action":"approved","rationale":"3.5 修复 overlay 注入 bug","actor":"swarm-yuan/ai","alternatives":"保持 3.4,升 3.5-rc","missing_context":"可能影响 overlay 注入","cost_if_wrong":"overlay 失效需回退"}
```

- `type`：`Mechanical` / `Taste` / `UserChallenge`
- `user_action`：`approved` / `rejected` / `revised`
- UserChallenge 类必填 `alternatives`/`missing_context`/`cost_if_wrong`；Mechanical/Taste 可缺省
- 落盘永不阻塞主流程（trace-log.sh `--decision` 模式继承其永不 fail 设计）

## 6. 对齐 ISO/IEC 42001:2023

| 条款 | 要求 | 本文件落地 |
|------|------|----------|
| §6.1.2 AI 风险评估 | 识别决策风险 | 决策分类（低/中/高风险） |
| §6.1.3 AI 风险处置 | 处置留痕 | decisions.jsonl |
| §7.3 意识与培训 | 监督者可获取决策信息 | decisions.jsonl + spec §2 关联 |
| §8.3 系统监督 | 人工监督留痕 | UserChallenge 五要素 + user_action |
| §9.1 监视测量 | 决策绩效数据 | decisions.jsonl 结构化字段 |
| Annex A.2 人工监督 | 人可干预 | UserChallenge 永不自动 |

**对齐边界**：本文件落地的是"人工监督留痕"这一个点，不覆盖 ISO/IEC 42001 全部（管理体系范围评估/AI 系统影响评估/外部供应商管理属标准补全范畴）。
```

- [ ] **Step 2: 追加 facts.conf 口径**

在 `swarm-yuan/assets/facts.conf` 末尾（L79 后）追加：

```bash

# ===== 决策治理（G1，对齐 ISO/IEC 42001）=====
FACT_DECISION_TYPES=3                # Mechanical / Taste / UserChallenge
FACT_DECISION_LOG=decisions.jsonl   # 决策审计轨迹落盘文件名
FACT_USER_CHALLENGE_ELEMENTS=5      # ai_suggestion/rationale/alternatives/missing_context/cost_if_wrong
```

- [ ] **Step 3: 验证 facts.conf 可 source**

Run: `cd swarm-yuan && bash -c 'source assets/facts.conf && echo "DECISION_TYPES=$FACT_DECISION_TYPES LOG=$FACT_DECISION_LOG ELEMENTS=$FACT_USER_CHALLENGE_ELEMENTS"'`
Expected: `DECISION_TYPES=3 LOG=decisions.jsonl ELEMENTS=5`

- [ ] **Step 4: 验证 decision-governance.md 内容完整**

Run: `grep -cE '^## ' swarm-yuan/references/decision-governance.md`
Expected: `6`（§1 问题 / §2 三级分类 / §3 五要素 / §4 映射 / §5 格式 / §6 对齐）

Run: `grep -c 'ISO/IEC 42001' swarm-yuan/references/decision-governance.md`
Expected: ≥2（标题 + §6 表头）

- [ ] **Step 5: Commit**

```bash
git add swarm-yuan/references/decision-governance.md swarm-yuan/assets/facts.conf
git commit -m "feat(g1): 新增 decision-governance.md 决策分类注册表 + facts.conf 口径

- 决策三级分类（Mechanical/Taste/UserChallenge）+ 升级规则
- User Challenge 五要素（autoplan 吸收，R5 §七.4）
- 豁免条款裁决 logic-razor vs abstain 冲突（R3 §2.2-e）
- facts.conf 新增 3 口径（FACT_DECISION_TYPES/LOG/ELEMENTS）
- 对齐 ISO/IEC 42001:2023 人工监督留痕"
```

---

### Task 2: trace-log.sh 新增 --decision 模式

**Files:**
- Modify: `swarm-yuan/assets/trace-log.sh`（L17-33 参数段 + L48-59 落盘段）

**Interfaces:**
- Consumes: `references/decision-governance.md` 的 type/user_action 字段定义
- Produces: `bash trace-log.sh --decision --type <T> --suggestion <S> --user-action <A> --rationale <R> [--alternatives <A>] [--missing-context <M>] [--cost-if-wrong <C>] [--phase <P>]` → 追加 JSON 行到 `.swarm-yuan/decisions.jsonl`，exit 0（永不 fail）

- [ ] **Step 1: 读取当前 trace-log.sh 全文确认结构**

Run: `cat -n swarm-yuan/assets/trace-log.sh`
确认：L17 参数初始化、L18-29 参数解析 case、L36 `_json_esc`、L48-59 落盘段、L60 `exit 0`。

- [ ] **Step 2: 修改参数初始化与解析段**

在 L17 `NODE=""; ACTOR=""; TOOL=""; STATUS="started"; NOTE=""` 后新增决策变量初始化，并在参数解析 case 中新增 `--decision` 相关分支。

将 L17 替换为：

```bash
NODE=""; ACTOR=""; TOOL=""; STATUS="started"; NOTE=""
# --decision 模式变量
DECISION_MODE=0; D_TYPE=""; D_SUGGESTION=""; D_USER_ACTION=""; D_RATIONALE=""
D_ALTERNATIVES=""; D_MISSING_CONTEXT=""; D_COST_IF_WRONG=""; D_PHASE=""
```

在 L24 `--note)` 分支后、`*)` 分支前，新增：

```bash
    --decision)  DECISION_MODE=1; shift ;;
    --type)      D_TYPE="${2:-}"; shift 2 ;;
    --suggestion) D_SUGGESTION="${2:-}"; shift 2 ;;
    --user-action) D_USER_ACTION="${2:-}"; shift 2 ;;
    --rationale) D_RATIONALE="${2:-}"; shift 2 ;;
    --alternatives) D_ALTERNATIVES="${2:-}"; shift 2 ;;
    --missing-context) D_MISSING_CONTEXT="${2:-}"; shift 2 ;;
    --cost-if-wrong) D_COST_IF_WRONG="${2:-}"; shift 2 ;;
    --phase)     D_PHASE="${2:-}"; shift 2 ;;
```

- [ ] **Step 3: 修改 --tool 必填校验段**

将 L30-33 的 `--tool` 必填校验改为：`--tool` 在非 decision 模式下必填。

将：
```bash
if [[ -z "$TOOL" ]]; then
  echo "Usage: bash trace-log.sh --node <节点> --actor <技能/子代理> --tool <工具/命令> [--status started|done|fail] [--note <说明>]" >&2
  exit 1
fi
```

替换为：

```bash
if [[ "$DECISION_MODE" -eq 0 && -z "$TOOL" ]]; then
  echo "Usage: bash trace-log.sh --node <节点> --actor <技能/子代理> --tool <工具/命令> [--status started|done|fail] [--note <说明>]" >&2
  echo "       bash trace-log.sh --decision --type <Mechanical|Taste|UserChallenge> --suggestion <建议> --user-action <approved|rejected|revised> [--rationale <理由>] [--phase <阶段>] [--alternatives <备选>] [--missing-context <缺失上下文>] [--cost-if-wrong <代价>]" >&2
  exit 1
fi
# --decision 模式必填：type/suggestion/user-action
if [[ "$DECISION_MODE" -eq 1 ]]; then
  if [[ -z "$D_TYPE" || -z "$D_SUGGESTION" || -z "$D_USER_ACTION" ]]; then
    echo "⚠ --decision 模式必填 --type/--suggestion/--user-action，降级记录（exit 0 不阻塞）" >&2
    # 降级：填占位值继续落盘（永不 fail 阻塞主流程）
    [[ -z "$D_TYPE" ]] && D_TYPE="Unknown"
    [[ -z "$D_SUGGESTION" ]] && D_SUGGESTION="(missing)"
    [[ -z "$D_USER_ACTION" ]] && D_USER_ACTION="unknown"
  fi
  # UserChallenge 五要素校验（缺则 type 追加 :incomplete）
  if [[ "$D_TYPE" == "UserChallenge" ]]; then
    if [[ -z "$D_ALTERNATIVES" || -z "$D_MISSING_CONTEXT" || -z "$D_COST_IF_WRONG" ]]; then
      echo "⚠ UserChallenge 缺五要素（alternatives/missing_context/cost_if_wrong），降级记录为 UserChallenge:incomplete" >&2
      D_TYPE="UserChallenge:incomplete"
    fi
  fi
fi
```

- [ ] **Step 4: 修改 stdout + 落盘段**

在 L46 `echo "$_line"` 后、L48 `# 2) 落盘` 前，新增 decision 模式的分支跳转。

将 L46-60 替换为：

```bash
echo "$_line"

# --decision 模式：落盘 decisions.jsonl（与 trace.jsonl 同目录，永不 fail）
if [[ "$DECISION_MODE" -eq 1 ]]; then
  STATE_DIR="${PROJECT_DIR:-$(pwd)}/.swarm-yuan"
  if mkdir -p "$STATE_DIR" 2>/dev/null; then
    ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    local _dec_line
    _dec_line=$(printf '{"ts":"%s","phase":"%s","type":"%s","ai_suggestion":"%s","user_action":"%s","rationale":"%s","actor":"%s","alternatives":"%s","missing_context":"%s","cost_if_wrong":"%s"}\n' \
      "$ts" "$(_json_esc "$D_PHASE")" "$(_json_esc "$D_TYPE")" "$(_json_esc "$D_SUGGESTION")" \
      "$(_json_esc "$D_USER_ACTION")" "$(_json_esc "$D_RATIONALE")" "$(_json_esc "${ACTOR:-swarm-yuan/ai}")" \
      "$(_json_esc "$D_ALTERNATIVES")" "$(_json_esc "$D_MISSING_CONTEXT")" "$(_json_esc "$D_COST_IF_WRONG")")
    if ! printf '%s\n' "$_dec_line" >> "$STATE_DIR/decisions.jsonl" 2>/dev/null; then
      echo "⚠ trace-log: decisions.jsonl 落盘失败（$STATE_DIR/decisions.jsonl 不可写），决策未留痕（不阻塞）" >&2
    else
      echo "→ [决策留痕] type=$D_TYPE action=$D_USER_ACTION → $STATE_DIR/decisions.jsonl"
    fi
  else
    echo "⚠ trace-log: 无法创建 ${STATE_DIR}，决策未留痕（不阻塞）" >&2
  fi
  exit 0
fi

# 2) 落盘 trace.jsonl（失败仅 warn，不阻塞主流程）
STATE_DIR="${PROJECT_DIR:-$(pwd)}/.swarm-yuan"
if mkdir -p "$STATE_DIR" 2>/dev/null; then
  ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  if ! printf '{"ts":"%s","node":"%s","actor":"%s","tool":"%s","status":"%s","note":"%s"}\n' \
    "$ts" "$(_json_esc "$NODE")" "$(_json_esc "$ACTOR")" "$(_json_esc "$TOOL")" \
    "$(_json_esc "$STATUS")" "$(_json_esc "$NOTE")" >> "$STATE_DIR/trace.jsonl" 2>/dev/null; then
    echo "⚠ trace-log: 落盘失败（$STATE_DIR/trace.jsonl 不可写），仅保留 stdout 提示" >&2
  fi
else
  echo "⚠ trace-log: 无法创建 ${STATE_DIR}，仅保留 stdout 提示" >&2
fi
exit 0
```

**注意**：bash 3.2 不支持函数内 `local` 在主脚本顶层使用。trace-log.sh 是脚本非函数，`_dec_line` 改为普通变量（去掉 `local`）：

```bash
    _dec_line=$(printf '...')
```

- [ ] **Step 5: 语法检查**

Run: `bash -n swarm-yuan/assets/trace-log.sh`
Expected: 无输出（语法正确）

- [ ] **Step 6: 手动测试 — Mechanical 决策落盘**

Run:
```bash
cd /tmp && rm -rf g1-test && mkdir g1-test && cd g1-test
export PROJECT_DIR=/tmp/g1-test
bash /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/assets/trace-log.sh \
  --decision --type Mechanical --suggestion 'WRITABLE_DIRS=["src/"]' \
  --user-action approved --rationale '从特征卡第2项机械推导'
cat .swarm-yuan/decisions.jsonl
```
Expected stdout: `→ [决策留痕] type=Mechanical action=approved → /tmp/g1-test/.swarm-yuan/decisions.jsonl`
Expected file content: 一行 JSON，含 `"type":"Mechanical"` 和 `"user_action":"approved"`

- [ ] **Step 7: 手动测试 — UserChallenge 缺五要素降级**

Run:
```bash
cd /tmp/g1-test
bash /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/assets/trace-log.sh \
  --decision --type UserChallenge --suggestion '升级 vue' --user-action approved
cat .swarm-yuan/decisions.jsonl | tail -1
```
Expected stderr: `⚠ UserChallenge 缺五要素...降级记录为 UserChallenge:incomplete`
Expected file: 最后一行含 `"type":"UserChallenge:incomplete"`

- [ ] **Step 8: 手动测试 — 原有 --node 模式不破坏**

Run:
```bash
cd /tmp/g1-test
bash /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/assets/trace-log.sh \
  --node "测试" --actor "AI" --tool "grep" --status done --note "不破坏"
cat .swarm-yuan/trace.jsonl | tail -1
```
Expected: trace.jsonl 正常追加一行，decisions.jsonl 不变

- [ ] **Step 9: 手动测试 — 缺 --tool 且非 decision 模式仍 exit 1**

Run:
```bash
bash /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/assets/trace-log.sh --node test 2>&1; echo "rc=$?"
```
Expected: 输出 Usage，`rc=1`

- [ ] **Step 10: Commit**

```bash
cd /Volumes/nvme2230/lab/Swarm-yuan
git add swarm-yuan/assets/trace-log.sh
git commit -m "feat(g1): trace-log.sh 新增 --decision 模式落盘 decisions.jsonl

- 新增 --decision/--type/--suggestion/--user-action/--rationale 等参数
- UserChallenge 缺五要素降级为 :incomplete（永不 fail 阻塞主流程）
- 复用 _json_esc + 永不 fail 设计（set -uo pipefail 无 -e）
- 原 --node 模式行为不变"
```

---

### Task 3: state-machine.sh transition 记录决策 + guard warn 检查

**Files:**
- Modify: `swarm-yuan/assets/state-machine.sh`（L186-205 transition_phase + L109-126 guard_phase design）

**Interfaces:**
- Consumes: trace-log.sh `--decision` 模式（Task 2）
- Produces: transition 成功后自动追加一条 Taste 类决策到 decisions.jsonl；guard_phase design 准入 warn 检查 decisions.jsonl 存在性

- [ ] **Step 1: 修改 transition_phase 记录决策**

在 `state-machine.sh` 的 `transition_phase()` 函数（L186-205）中，`set_field phase "$target"` (L203) 后、`echo "✓ 已转换到: $target"` (L204) 前，新增决策留痕调用。

将 L203-204:
```bash
  set_field phase "$target"
  echo "✓ 已转换到: $target"
```

替换为:
```bash
  set_field phase "$target"
  # G1：阶段流转决策留痕（Taste 类，guard 通过即 approved）
  local _tl_sh
  _tl_sh="${STATE_DIR:-${PROJECT_DIR:-$(pwd)}/.swarm-yuan}/../scripts/trace-log.sh"
  [[ -f "$_tl_sh" ]] || _tl_sh="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/trace-log.sh"
  if [[ -f "$_tl_sh" ]]; then
    bash "$_tl_sh" --decision --type Taste \
      --suggestion "$target" --user-action approved \
      --rationale "guard 通过，阶段从 $current 流转到 $target" \
      --phase "$target" >&2 2>/dev/null || true
  fi
  echo "✓ 已转换到: $target"
```

- [ ] **Step 2: 修改 auto_phase 记录决策**

`auto_phase()` (L225-248) 内 `set_field phase "$target"` (L241) 后同样加决策留痕。

将 L241-242:
```bash
    set_field phase "$target"
    echo "✓ auto 流转成功: $current → $target"
```

替换为:
```bash
    set_field phase "$target"
    # G1：auto 流转决策留痕
    local _tl_sh
    _tl_sh="${STATE_DIR:-${PROJECT_DIR:-$(pwd)}/.swarm-yuan}/../scripts/trace-log.sh"
    [[ -f "$_tl_sh" ]] || _tl_sh="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/trace-log.sh"
    if [[ -f "$_tl_sh" ]]; then
      bash "$_tl_sh" --decision --type Taste \
        --suggestion "$target" --user-action approved \
        --rationale "auto: guard 通过，$current → $target" \
        --phase "$target" >&2 2>/dev/null || true
    fi
    echo "✓ auto 流转成功: $current → $target"
```

- [ ] **Step 3: 修改 guard_phase design 准入 warn 检查 decisions.jsonl**

在 `guard_phase()` 的 `design)` 分支（L109-126）末尾、`;;` (L126) 前，新增 decisions.jsonl 存在性 warn 检查。

在 L125 `fi` 后、L126 `;;` 前，新增:

```bash
      # G1：design 准入 warn 检查 decisions.jsonl（warn 不 fail，不阻塞流转）
      local _dec_file="${STATE_DIR}/decisions.jsonl"
      if [[ ! -f "$_dec_file" ]]; then
        echo "  ⚠ decisions.jsonl 未创建（决策未留痕，G1 决策治理）"
      elif [[ ! -s "$_dec_file" ]]; then
        echo "  ℹ decisions.jsonl 存在但为空（draft 期允许）"
      else
        pass "decisions.jsonl 已有决策记录"
      fi
```

- [ ] **Step 4: 语法检查**

Run: `bash -n swarm-yuan/assets/state-machine.sh`
Expected: 无输出

- [ ] **Step 5: 手动测试 — transition 记录决策**

Run:
```bash
cd /tmp && rm -rf g1-sm-test && mkdir g1-sm-test && cd g1-sm-test
export PROJECT_DIR=/tmp/g1-sm-test
# 准备 trace-log.sh（复制到 scripts/ 位置）
mkdir -p .swarm-yuan/../scripts
cp /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/assets/trace-log.sh scripts/trace-log.sh
cp /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/assets/state-machine.sh scripts/state-machine.sh
# init + 造 proposal.md 满足 design 准入
bash scripts/state-machine.sh init test-change
touch .swarm-yuan/proposal.md
# transition open → design
bash scripts/state-machine.sh transition design 2>&1
echo "---decisions.jsonl---"
cat .swarm-yuan/decisions.jsonl
```
Expected: transition 输出 `✓ 已转换到: design`，decisions.jsonl 含一行 `"type":"Taste"` 且 `"suggestion":"design"`

- [ ] **Step 6: 手动测试 — guard design warn 检查**

Run:
```bash
cd /tmp && rm -rf g1-guard-test && mkdir g1-guard-test && cd g1-guard-test
export PROJECT_DIR=/tmp/g1-guard-test
mkdir -p scripts
cp /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/assets/trace-log.sh scripts/trace-log.sh
cp /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/assets/state-machine.sh scripts/state-machine.sh
bash scripts/state-machine.sh init guard-test
touch .swarm-yuan/proposal.md
# guard design（decisions.jsonl 不存在）
bash scripts/state-machine.sh guard design 2>&1 | grep -c 'decisions.jsonl 未创建'
```
Expected: `1`（warn 行出现一次）

- [ ] **Step 7: Commit**

```bash
cd /Volumes/nvme2230/lab/Swarm-yuan
git add swarm-yuan/assets/state-machine.sh
git commit -m "feat(g1): state-machine transition 记录决策 + guard warn 检查 decisions.jsonl

- transition/auto 流转成功后追加 Taste 类决策到 decisions.jsonl
- guard_phase design 准入 warn 检查 decisions.jsonl 存在性（不阻塞流转）
- 复用 trace_tool 的 trace-log.sh 定位逻辑"
```

---

### Task 4: precheck.sh _fix_suggest 增强决策留痕提示 + spec-template §2 扩列

**Files:**
- Modify: `swarm-yuan/assets/precheck.sh`（`_fix_suggest` 函数 L1239-1271）
- Modify: `swarm-yuan/assets/spec-template.md`（§2 L25-31）

**Interfaces:**
- Consumes: `references/decision-governance.md`（引用其 §User Challenge）
- Produces: `_fix_suggest` 每条建议末尾追加决策留痕提示；spec §2 扩为 7 列表格

- [ ] **Step 1: 读取 _fix_suggest 当前实现**

Run: `grep -n '_fix_suggest' swarm-yuan/assets/precheck.sh | head -5`
确认函数位置（预期 L1239 附近）。

Run: `sed -n '1239,1271p' swarm-yuan/assets/precheck.sh`
读取完整函数体，确认 `echo "  • ${id}: ${suggest}"` 的输出行位置。

- [ ] **Step 2: 修改 _fix_suggest 追加决策留痕提示**

在 `_fix_suggest` 函数的输出行（`echo "  • ${id}: ${suggest}"`）后，新增一行决策留痕提示。找到该输出行（预期在 case 块末尾 `esac` 前），在其后追加：

```bash
  # G1：决策留痕提示（不改变 fail 语义，只增强诊断输出）
  echo "    （决策留痕：若涉及多方案/依赖升级/安全冲突，须按 references/decision-governance.md §User Challenge 记录）"
```

**注意**：此提示对每条 fail 建议都输出（不区分 fail 类型），因为 AI 诊断阶段才知道是否涉及 User Challenge。提示是 advisory，不 exit。

- [ ] **Step 3: 修改 spec-template.md §2 决策记录扩列**

将 `swarm-yuan/assets/spec-template.md` L25-31:

```markdown
## 2. 决策记录

| 决策 | 选择 | 备选 | 理由 |
|------|------|------|------|
| 改造类型 | <按项目分类> | — | （理由） |
| （其他决策） | | | |
```

替换为:

```markdown
## 2. 决策记录

> 凡 User Challenge 类决策（依赖升级/安全冲突/删稳定单元/多方案/改只读）须在此登记并关联 `.swarm-yuan/decisions.jsonl` 行号。详见 `references/decision-governance.md`。

| 决策 | 选择 | 备选 | 理由 | 类型 | 用户裁定 | decisions.jsonl 行号 |
|------|------|------|------|------|---------|---------------------|
| 改造类型 | <按项目分类> | — | （理由） | Mechanical | approved | — |
| （其他决策） | | | | | | |

<!-- 类型：Mechanical（机械推导）/ Taste（判断空间）/ UserChallenge（方向性决策须五要素） -->
<!-- 用户裁定：approved / rejected / revised -->
```

- [ ] **Step 4: 语法检查 precheck.sh**

Run: `bash -n swarm-yuan/assets/precheck.sh`
Expected: 无输出

- [ ] **Step 5: 手动测试 — _fix_suggest 输出含决策留痕提示**

Run:
```bash
cd /tmp && rm -rf g1-fix-test && mkdir g1-fix-test && cd g1-fix-test
export PROJECT_DIR=/tmp/g1-fix-test
mkdir -p scripts
cp /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/assets/precheck.sh scripts/precheck.sh
# 造一个最小 precheck.conf 触发某个 fail
cat > scripts/precheck.conf <<'EOF'
PROJECT_DIR=/tmp/g1-fix-test
BRANCH_REGEX=^feat/
PROTECTED_BRANCHES=(main)
WRITABLE_DIRS=(src/)
READONLY_DIRS=()
TEST_CMD=true
BUILD_CMD=true
SCAN_DIRS=(src/)
CONSISTENCY_DIRS=()
EOF
# 跑 --fix-suggest（收集 fail 后输出建议）
bash scripts/precheck.sh --fix-suggest 2>&1 | grep -c '决策留痕'
```
Expected: ≥1（至少一条建议含决策留痕提示）

**注意**：如果 `--fix-suggest` 因 conf 不全无法跑通，降级为直接 grep 验证函数体：
```bash
grep -c '决策留痕' /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/assets/precheck.sh
```
Expected: `1`

- [ ] **Step 6: 验证 spec-template §2 扩列**

Run: `grep -c 'decisions.jsonl 行号' swarm-yuan/assets/spec-template.md`
Expected: `1`（表头含新列）

Run: `grep -c 'decision-governance.md' swarm-yuan/assets/spec-template.md`
Expected: `1`（引导文引用）

- [ ] **Step 7: Commit**

```bash
cd /Volumes/nvme2230/lab/Swarm-yuan
git add swarm-yuan/assets/precheck.sh swarm-yuan/assets/spec-template.md
git commit -m "feat(g1): _fix_suggest 追加决策留痕提示 + spec §2 决策记录扩为 7 列

- _fix_suggest 每条建议末尾追加 User Challenge 留痕提示（不改 fail 语义）
- spec-template §2 决策记录表扩为 7 列（+类型/用户裁定/decisions.jsonl 行号）
- 引导文引用 decision-governance.md"
```

---

### Task 5: generate-skill.sh verify_completeness 新增 decisions_miss 校验

**Files:**
- Modify: `swarm-yuan/scripts/generate-skill.sh`（`verify_completeness()` L433 后）

**Interfaces:**
- Consumes: trace-log.sh `--decision` 模式产生的 decisions.jsonl（Task 2）
- Produces: `verify_completeness` 新增 decisions_miss 检查段，并入 hits 统一裁决（draft 放行 / strict exit 1）

- [ ] **Step 1: 读取 verify_completeness 当前 L433 附近**

Run: `sed -n '425,445p' swarm-yuan/scripts/generate-skill.sh`
确认 L433 `hits=$(printf '%s\n%s\n' "$hits" "$trace_miss" ...)` 的位置，在其后插入 decisions_miss 段。

- [ ] **Step 2: 在 L433 后新增 decisions_miss 校验段**

在 L433 `hits=$(printf '%s\n%s\n' "$hits" "$trace_miss" | grep -v '^$' || true)` 后、L434 `if [[ -n "$hits" ]]` 前，新增:

```bash
  # G1：decisions.jsonl 校验（decisions_miss 并入 hits 统一裁决）
  # 检查 ① 文件存在性 ② 每行 JSON 合法性 ③ UserChallenge 行五要素非空
  local dec_file="$skill_dir/.swarm-yuan/decisions.jsonl" decisions_miss=""
  if [[ -f "$dec_file" ]]; then
    # 逐行校验：有 python3 用 json.loads，无则降级 grep 字段存在性
    if command -v python3 >/dev/null 2>&1; then
      local py_out
      py_out=$(python3 -c '
import sys, json
for i, line in enumerate(sys.stdin, 1):
    line = line.strip()
    if not line: continue
    try:
        obj = json.loads(line)
    except Exception as e:
        print(f"{i}: 非法JSON ({e})")
        continue
    if obj.get("type") == "UserChallenge":
        for k in ("alternatives", "missing_context", "cost_if_wrong"):
            if not obj.get(k):
                print(f"{i}: UserChallenge 缺 {k}")
    ' "$dec_file" 2>/dev/null || true)
      [[ -n "$py_out" ]] && decisions_miss=$(echo "$py_out" | sed "s|^|$dec_file:|")
    else
      # 降级：grep 字段存在性（bash 3.2 兼容，不阻塞）
      local ln=0
      while IFS= read -r dline; do
        ln=$((ln + 1))
        # 非法 JSON 粗检：不含 "type" 字段
        echo "$dline" | grep -q '"type"' || { decisions_miss="${decisions_miss}${decisions_miss:+$'\n'}$dec_file:$ln: 非法JSON（缺 type 字段）"; continue; }
        # UserChallenge 五要素
        echo "$dline" | grep -q '"type":"UserChallenge"' || continue
        echo "$dline" | grep -q '"alternatives"' || decisions_miss="${decisions_miss}${decisions_miss:+$'\n'}$dec_file:$ln: UserChallenge 缺 alternatives"
        echo "$dline" | grep -q '"missing_context"' || decisions_miss="${decisions_miss}${decisions_miss:+$'\n'}$dec_file:$ln: UserChallenge 缺 missing_context"
        echo "$dline" | grep -q '"cost_if_wrong"' || decisions_miss="${decisions_miss}${decisions_miss:+$'\n'}$dec_file:$ln: UserChallenge 缺 cost_if_wrong"
      done < "$dec_file"
    fi
  fi
  hits=$(printf '%s\n%s\n' "$hits" "$decisions_miss" | grep -v '^$' || true)
```

- [ ] **Step 3: 语法检查**

Run: `bash -n swarm-yuan/scripts/generate-skill.sh`
Expected: 无输出

- [ ] **Step 4: 手动测试 — 空 decisions.jsonl + draft 放行**

Run:
```bash
cd /tmp && rm -rf g1-vc-test && mkdir -p g1-vc-test/.swarm-yuan && cd g1-vc-test
# 造一个最小 skill 结构
mkdir -p references scripts hooks
echo 'status: draft' > SKILL.md
echo '# workflow' > references/workflow.md
# decisions.jsonl 不存在
bash /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/scripts/generate-skill.sh --verify-completeness . 2>&1 | grep -c 'decisions'
echo "rc=$?"
```
Expected: grep 计数可能为 0（decisions_miss 为空时不打印）或含 warn；rc=0（draft 放行）

- [ ] **Step 5: 手动测试 — UserChallenge 缺五要素 + strict exit 1**

Run:
```bash
cd /tmp/g1-vc-test
echo 'status: active' > SKILL.md
# 造一个缺 cost_if_wrong 的 UserChallenge 行
echo '{"ts":"2026-07-22T10:00:00Z","phase":"design","type":"UserChallenge","ai_suggestion":"test","user_action":"approved","rationale":"r","actor":"a","alternatives":"x","missing_context":"y"}' > .swarm-yuan/decisions.jsonl
bash /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/scripts/generate-skill.sh --verify-completeness . --strict 2>&1 | grep -c 'cost_if_wrong'
echo "rc=$?"
```
Expected: grep 计数 ≥1（检测到缺 cost_if_wrong）；rc=1（strict exit 1）

- [ ] **Step 6: 手动测试 — 合法 Mechanical 行通过**

Run:
```bash
cd /tmp/g1-vc-test
echo '{"ts":"2026-07-22T10:00:00Z","phase":"design","type":"Mechanical","ai_suggestion":"test","user_action":"approved","rationale":"r","actor":"a"}' > .swarm-yuan/decisions.jsonl
# 确保 SKILL.md 无占位符
echo 'status: active' > SKILL.md
echo '# workflow' > references/workflow.md
bash /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/scripts/generate-skill.sh --verify-completeness . --strict 2>&1
echo "rc=$?"
```
Expected: rc=0（合法 Mechanical 行通过 strict）

- [ ] **Step 7: Commit**

```bash
cd /Volumes/nvme2230/lab/Swarm-yuan
git add swarm-yuan/scripts/generate-skill.sh
git commit -m "feat(g1): verify_completeness 新增 decisions.jsonl 合法性校验

- 检查文件存在性 + 每行 JSON 合法性 + UserChallenge 五要素非空
- 有 python3 用 json.loads，无则降级 grep 字段存在性
- decisions_miss 并入 hits 统一裁决（draft 放行 / strict exit 1）"
```

---

### Task 6: SKILL.md 重写 AI 主导段 + self-check 扩展 + 文档口径同步

**Files:**
- Modify: `swarm-yuan/SKILL.md`（L54-62 AI 主导段）
- Modify: `swarm-yuan/scripts/self-check.sh`（check_doc_consistency 扩展决策治理口径）
- Modify: `swarm-yuan/SKILL.md`（reference 文件清单表追加 decision-governance.md）

**Interfaces:**
- Consumes: Task 1-5 的全部产出物
- Produces: SKILL.md 7 条各标注分类 + self-check 新口径断言

- [ ] **Step 1: 重写 SKILL.md L54-62 AI 主导段**

将 SKILL.md L54-62:

```markdown
**AI 主导 + 用户决策原则**：在目标 skill 的完整生命周期中，特征卡提取、门禁配置、spec 填充、代码实现、问题排查等所有环节均**优先以 AI 为主导生成建议项**——AI 探查项目后主动提出特征卡建议、主动推导门禁配置、主动填充 spec 模板、主动给出代码方案、主动诊断门禁 fail 原因并给出修复建议。用户的角色是**评估决策或修订后批准执行**，而非手动编写。具体：
- 特征卡 16 项：AI 探查后**主动生成建议值**，用户评估修订后确认
- 门禁 precheck.conf 142 变量：AI 从特征卡**主动推导建议配置**，用户评估后确认
- spec 模板填充：AI **主动预填**（含 §5.5 复用约束从第 11 项检索预填），用户评估修订后确认
- 门禁 fail：AI **主动诊断原因 + 给出修复建议**，用户评估后批准执行
- 编码实现：AI **主动给出代码方案**（含复用了哪些稳定单元），用户评估后确认
- 多方案选择：AI **主动提出 2+ 方案权衡 + 推荐**，用户决策
- 问题排查：AI **主动分析 + 给出解决方案**，用户评估后批准
```

替换为:

```markdown
**AI 主导 + 用户决策原则**（G1 决策治理，对齐 ISO/IEC 42001 人工监督留痕）：在目标 skill 的完整生命周期中，特征卡提取、门禁配置、spec 填充、代码实现、问题排查等所有环节均**优先以 AI 为主导生成建议项**，但决策按**三级分类**治理——什么能自动做、什么必须停下问、每条决策有审计轨迹落盘。用户的角色是**评估决策或修订后批准执行**，而非手动编写。详见 `references/decision-governance.md`。具体：
- 特征卡 16 项：AI 探查后**主动生成建议值**（Mechanical 类，直接做），用户评估修订后确认
- 门禁 precheck.conf 142 变量：AI 从特征卡**主动推导建议配置**（Mechanical 类；涉及安全规则如 SENSITIVE_WHITELIST/CRYPTO_PROFILE 升 Taste），用户评估后确认
- spec 模板填充：AI **主动预填**（Taste 类；§5.6 版本约束/§5.7 安全约束升 UserChallenge），用户评估修订后确认
- 门禁 fail：AI **主动诊断原因 + 给出修复建议**（Taste 类；涉及依赖升级/安全冲突/删稳定单元升 UserChallenge），用户评估后批准执行
- 编码实现：AI **主动给出代码方案**（Taste 类；多方案/改只读/删稳定单元升 UserChallenge），用户评估后确认
- 多方案选择：AI **主动提出 2+ 方案权衡 + 推荐**（**UserChallenge 类，永不自动决定**，须输出五要素等用户裁定），用户决策
- 问题排查：AI **主动分析 + 给出解决方案**（Taste 类；涉及架构变更/安全冲突升 UserChallenge），用户评估后批准

> **决策留痕**：每条决策通过 `scripts/trace-log.sh --decision` 追加到 `.swarm-yuan/decisions.jsonl`（永不 fail 阻塞主流程）；UserChallenge 类须含五要素（alternatives/missing_context/cost_if_wrong）。阶段流转由 `scripts/state-machine.sh` transition 自动记录。`--mark-active` 前须有至少 1 条决策记录。
```

- [ ] **Step 2: 在 SKILL.md reference 文件清单表追加 decision-governance.md**

在 SKILL.md 的 reference 文件清单表中（L130-152 附近），找到 `| 安全规范（OWASP/STRIDE/CWE） | references/security-spec.md |` 行后，新增一行:

```markdown
| 决策治理（三级分类+五要素+decisions.jsonl，对齐 ISO/IEC 42001） | `references/decision-governance.md` |
```

- [ ] **Step 3: 修改 self-check.sh check_doc_consistency 扩展决策治理口径**

在 `self-check.sh` 的 `check_doc_consistency` 函数中（L531+ 的文档扫描段），新增决策治理口径扫描。

在 L548 `true_fw=$(ls ...)` 后、L550 `# WP-P1：facts.conf 自身一致性对账` 前，新增:

```bash
  # G1：决策治理口径扫描（decisions.jsonl / 三类决策 / 五要素）
  local true_dec_types=0
  [[ -n "${FACT_DECISION_TYPES:-}" ]] && true_dec_types="$FACT_DECISION_TYPES"
  if [[ "$true_dec_types" -gt 0 ]]; then
    for doc in README.md docs/USAGE.md docs/PROMO.md "$root_claude"; do
      case "$doc" in
        /*) docpath="$doc" ;;
        *)  docpath="$base/$doc" ;;
      esac
      [[ -f "$docpath" ]] || continue
      # 扫描"N 类决策"口径
      bad=$(grep -oE "[0-9]+ ?类决策" "$docpath" 2>/dev/null \
            | grep -oE "[0-9]+" | sort -u | grep -vx "$true_dec_types" || true)
      [[ -n "$bad" ]] && warn "$(basename "$docpath"): 决策分类数出现非${true_dec_types}值($(echo $bad | tr '\n' ' '))"
    done
  fi
```

**注意**：`warn` 和 `bad` 变量在该函数已有定义，直接复用。

- [ ] **Step 4: 语法检查**

Run: `bash -n swarm-yuan/scripts/self-check.sh`
Expected: 无输出

- [ ] **Step 5: 手动测试 — self-check 能跑通**

Run:
```bash
cd /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan
bash scripts/self-check.sh --check-only 2>&1 | tail -20
```
Expected: self-check 正常完成（可能有 warn 但不崩）

- [ ] **Step 6: 验证 facts.conf 对账通过**

Run:
```bash
cd /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan
bash scripts/self-check.sh --check-only 2>&1 | grep -c 'facts.conf 与代码真值一致'
```
Expected: `1`（facts.conf 对账通过）

- [ ] **Step 7: 验证 SKILL.md 决策分类标注完整**

Run: `grep -cE 'Mechanical|Taste|UserChallenge' swarm-yuan/SKILL.md`
Expected: ≥7（7 条各标注了分类）

Run: `grep -c 'decision-governance.md' swarm-yuan/SKILL.md`
Expected: ≥2（AI 主导段引用 + reference 清单表引用）

- [ ] **Step 8: 跑 shellcheck 确保不恶化**

Run: `shellcheck -x -e SC2086,SC1090,SC1091,SC2155,SC2034,SC2230,SC2004,SC2312 swarm-yuan/assets/trace-log.sh swarm-yuan/assets/state-machine.sh`
Expected: 无 error 级新增（warn 级可接受）

- [ ] **Step 9: 跑现有测试不回归**

Run: `bash swarm-yuan/tests/run-gate-fixture.sh branch 2>&1 | tail -5`
Expected: branch 门禁 fixture 双态绿（violating FAIL / compliant PASS）

Run: `bash verifier/v1/run-verifier.sh all 2>&1 | tail -10`
Expected: C1-C8 全绿（可能耗时较长，如超时跑 `bash verifier/v1/run-verifier.sh fixtures`）

- [ ] **Step 10: Commit**

```bash
cd /Volumes/nvme2230/lab/Swarm-yuan
git add swarm-yuan/SKILL.md swarm-yuan/scripts/self-check.sh
git commit -m "feat(g1): SKILL.md 重写 AI 主导段标注三级分类 + self-check 扩展决策口径

- SKILL.md 7 条 AI 主导行为各标注 Mechanical/Taste/UserChallenge 分类
- 新增决策留痕引导（decisions.jsonl + 五要素 + --mark-active 前须有记录）
- reference 清单表追加 decision-governance.md
- self-check check_doc_consistency 扩展决策治理口径扫描（N 类决策）"
```

---

## Self-Review

**1. Spec coverage:**

| Spec 章节 | 覆盖 Task |
|-----------|----------|
| §1 问题/目标/方案选型 | 全部 Task 的前提（无需单独 Task） |
| §2.1 架构 | Task 1-6 各组件 |
| §2.2 组件清单 #1 decision-governance.md | Task 1 |
| §2.2 #2 SKILL.md 重写 | Task 6 |
| §2.2 #3 trace-log.sh --decision | Task 2 |
| §2.2 #4 state-machine.sh transition+guard | Task 3 |
| §2.2 #5 precheck.sh _fix_suggest | Task 4 |
| §2.2 #6 spec-template §2 扩列 | Task 4 |
| §2.3 产出物 decisions.jsonl | Task 2（落盘）+ Task 5（校验） |
| §2.4 协同（不改 fail 语义/不触碰断点续传） | Task 4（不改 fail）+ Task 3（guard warn 不 fail） |
| §3.1 数据流场景 A-D | Task 2+3（落盘）+ Task 4（fail 诊断提示） |
| §3.2 决策分类映射表 | Task 1（文档）+ Task 6（SKILL.md 7 条标注） |
| §3.3 decisions.jsonl 生命周期 | Task 5（mark-active 校验）+ Task 2（落盘） |
| §3.4 verify_completeness 接入点 | Task 5 |
| §4.1 错误处理三道防线 | Task 2（防线 1）+ Task 5（防线 2）+ Task 3（防线 3） |
| §4.2 测试策略 | 每个 Task 的手动测试步骤 |
| §4.3 ISO/IEC 42001 对齐 | Task 1（文档声明） |
| §4.4 facts.conf 口径 | Task 1 |
| §4.5 遗留边界 | scope 外（不做 --decision-audit / checkpoint） |
| §4.6 实现顺序 | Task 1-6 顺序与 spec WP-G1-1~6 一致 |

**无 gap。** 所有 spec 章节都有对应 Task。

**2. Placeholder scan:**

扫描计划全文：
- 无 "TBD" / "TODO" / "implement later" / "fill in details"
- 无 "Add appropriate error handling"（每个步骤都有具体代码）
- 无 "Similar to Task N"（每个 Task 自包含）
- 无未定义的类型/函数引用（trace-log.sh `--decision` 在 Task 2 定义，Task 3/5 消费）

**无 placeholder。**

**3. Type consistency:**

- `DECISION_MODE` / `D_TYPE` / `D_SUGGESTION` / `D_USER_ACTION` / `D_RATIONALE` / `D_ALTERNATIVES` / `D_MISSING_CONTEXT` / `D_COST_IF_WRONG` / `D_PHASE` — Task 2 定义，Task 3 消费（通过 `--decision` CLI 参数，不直接引用变量名） ✓
- `decisions_miss` — Task 5 定义并消费 ✓
- `FACT_DECISION_TYPES` / `FACT_DECISION_LOG` / `FACT_USER_CHALLENGE_ELEMENTS` — Task 1 定义，Task 6 消费 ✓
- `decisions.jsonl` — 全 Task 一致路径 `<project>/.swarm-yuan/decisions.jsonl` ✓
- `UserChallenge:incomplete` — Task 2 定义（降级标记），Task 5 校验时该 type 不含纯 `UserChallenge` 字面匹配，不影响五要素检查逻辑 ✓

**类型一致。**

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-22-g1-decision-governance.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
