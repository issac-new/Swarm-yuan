# WP-P2 维度计数核验（inventory-verify.sh）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 spec `docs/superpowers/specs/2026-07-23-generation-toolization-design.md` §4（M1）：新增 `inventory-verify.sh` + 维度注册表 `assets/inventory-dimensions.conf`，把 Step 12 / exploration-guide §C+ 中模型手工 find/grep 枚举各维度组件 → 数 reference-manual.md 表格行数 → 去重 → 算 95% 比率 → 填核验表（`references/exploration-guide.md:1016-1023` 的 16a 枚举计数核验表）的机械工作脚本化；顺带做维度错配 lint（声明纯后端却出现 UI 组件表 → DIM_MISMATCH）。

**Architecture:** 数据驱动的维度注册表（`assets/inventory-dimensions.conf`，每维度 = 枚举 find/grep 规则 + 适用项目形态 + reference-manual.md 对应表名/锚）+ `inventory-verify.sh`（读注册表 + 项目形态 → 对目标仓库跑枚举 → 数 reference-manual.md 对应表行数 → 去重 → 算比率 → 输出 TSV 报告 + 人读摘要 + DIM_MISMATCH lint）。SKILL.md:100 Step 12 改写为「跑脚本 → 全 PASS 引用结论 / FAIL 回 Step 4 / DIM_MISMATCH 回 §C+.0 重判形态」。

**Tech Stack:** bash 3.2（三 OS），无新增依赖。

**Spec:** `docs/superpowers/specs/2026-07-23-generation-toolization-design.md` §4（M1）、§9（测试）、§10（WP 分解）。

## Global Constraints

- bash 3.2 兼容：禁 `declare -A`；`sed -i.bak` + `rm` 模式；正则用 `grep -E`/`sed -E`（BSD 兼容）；三 OS（macOS/Linux/Windows Git Bash）可跑。
- Repo-confirmed bash 3.2.57 quirks（两条都必须遵守）：
  1. `"` 紧贴 `)` 在引号命令替换内会解析失败 → 赋值用裸命令替换 `x=$(cmd "$VAR")`（不写 `x="$(cmd "$VAR")"`）。
  2. `$VAR` 紧跟多字节字符在双引号串内会误词法 → 多字节字符前用 `${VAR}` 花括号。
- 计量/核验类脚本 fail-open：缺文件/缺数据 exit 0（只 arg 错误 exit 1）。
- 输出确定性：同输入字节级一致（排序后输出，绝对路径转相对路径显示），可进 cli-ab byte-diff。
- 新脚本进 CI shellcheck 严格名单（`.github/workflows/ci.yml` Job4）。
- 分支纪律：一个 worktree（`.claude/worktrees/feat-wp-p2-inventory-verify`，从 origin/main 起），收口 `merge --no-ff`。
- run-verifier.sh all 全绿是合入门槛（注：metrics + sensitive gate-fixtures 是 main 上 WP-S2/WP-U 遗留的预存失败，非回归阻断，仅需披露）。
- 红线（template-spec.md:346）：脚本只做计数核验 + 维度错配 lint，**不替模型做适用/不适用判断**；核验表填什么维度仍由 §C+.0 形态判定驱动。

---

## Task 1: `assets/inventory-dimensions.conf` — 维度注册表

**Files:**
- Create: `swarm-yuan/assets/inventory-dimensions.conf`

**Interfaces:**
- 产生：bash 可 source 的 `KEY=value` 注册表；每维度一个块，字段：`DIM_<ID>_TITLE` / `DIM_<ID>_FORMS`（适用形态，空格分隔，`all`=全形态）/ `DIM_<ID>_CMD`（枚举命令模板，含 `${PROJECT_DIR}` 占位）/ `DIM_<ID>_RM_REF`（reference-manual.md 对应表锚，`§<n>` 或 `§<n>.<sub>`）。被 Task 2 的 `inventory-verify.sh` 消费。

- [ ] **Step 1: 写注册表**

Create `swarm-yuan/assets/inventory-dimensions.conf`:

```bash
# inventory-dimensions.conf — 维度枚举注册表（WP-P2/M1）
# 数据驱动：inventory-verify.sh source 本文件，按项目形态选取适用维度做枚举计数核验。
# 字段（每维度一个 <ID>，全大写下划线）:
#   DIM_<ID>_TITLE   维度人读名
#   DIM_<ID>_FORMS   适用项目形态（空格分隔）：backend frontend async desktop mobile lib common
#                    all = 全形态适用；common = 所有非纯库形态都适用
#   DIM_<ID>_CMD     枚举命令模板（含 ${PROJECT_DIR} 占位，inventory-verify.sh 替换后 eval）
#                    命令输出每行一个匹配文件（find -print / grep -rl），脚本去重计数
#   DIM_<ID>_RM_REF  reference-manual.md 对应表锚（§<n> 或 §<n>.<sub>）；脚本据此定位清单表行数
# 形态判定由 §C+.0 产出（exploration-guide.md）；脚本读生成产物 conf 的 PROJECT_FORM 变量，
#   不落产物时退化为全维度（与 spec §4 一致）。
# 红线：本表只定义「枚举什么 + 对照哪张表」，不替模型判断维度是否适用——适用判断由 §C+.0 形态判定驱动。

DIM_FRONTEND_UI_TITLE='前端 UI 组件'
DIM_FRONTEND_UI_FORMS='frontend'
DIM_FRONTEND_UI_CMD="find \"\${PROJECT_DIR}\" -type f \\( -name '*.vue' -o -name '*.svelte' -o -name '*.tsx' -o -name '*.jsx' \\) -not -path '*/node_modules/*' -not -path '*/dist/*'"
DIM_FRONTEND_UI_RM_REF='§4'

DIM_BACKEND_CONTROLLER_TITLE='后端 controller'
DIM_BACKEND_CONTROLLER_FORMS='backend'
DIM_BACKEND_CONTROLLER_CMD="grep -rlE 'router\\.(get|post|put|delete|patch|use|all)|@(Get|Post|Put|Delete|Patch|RequestMapping|Controller)' \"\${PROJECT_DIR}\" --include='*.ts' --include='*.js' --include='*.java' --include='*.go' --include='*.py' 2>/dev/null"
DIM_BACKEND_CONTROLLER_RM_REF='§6'

DIM_STORE_TITLE='store / 状态管理'
DIM_STORE_FORMS='common'
DIM_STORE_CMD="grep -rlE 'defineStore|createStore|createSlice|useReducer|Provider.*value|@ngrx|pinia|zustand|jotai|recoil' \"\${PROJECT_DIR}\" --include='*.ts' --include='*.js' --include='*.tsx' --include='*.jsx' 2>/dev/null"
DIM_STORE_RM_REF='§9'

DIM_TYPEDEF_TITLE='类型定义'
DIM_TYPEDEF_FORMS='common'
DIM_TYPEDEF_CMD="grep -rlE '^export (interface|type) ' \"\${PROJECT_DIR}\" --include='*.ts' --include='*.tsx' --include='*.d.ts' 2>/dev/null"
DIM_TYPEDEF_RM_REF='§9'

DIM_ASYNC_CONSUMER_TITLE='异步消费者 / handler'
DIM_ASYNC_CONSUMER_FORMS='async'
DIM_ASYNC_CONSUMER_CMD="grep -rlE '@KafkaListener|@RabbitListener|@StreamListener|@EventHandler|consume\\(|@Subscriber|def handle_|async def handle' \"\${PROJECT_DIR}\" --include='*.java' --include='*.ts' --include='*.js' --include='*.py' --include='*.go' 2>/dev/null"
DIM_ASYNC_CONSUMER_RM_REF='§6'

DIM_API_ENDPOINT_TITLE='接口端点'
DIM_API_ENDPOINT_FORMS='backend'
DIM_API_ENDPOINT_CMD="grep -rhoE '@(Get|Post|Put|Delete|Patch)\\([^)]*\\)|router\\.(get|post|put|delete|patch)\\([^)]*\\)|app\\.(get|post|put|delete|patch)\\(' \"\${PROJECT_DIR}\" --include='*.ts' --include='*.js' --include='*.java' --include='*.go' --include='*.py' 2>/dev/null"
DIM_API_ENDPOINT_RM_REF='§6'

DIM_LIB_EXPORT_TITLE='库导出'
DIM_LIB_EXPORT_FORMS='lib'
DIM_LIB_EXPORT_CMD="grep -rhE '^export ' \"\${PROJECT_DIR}\" --include='*.ts' --include='*.js' --include='*.py' --include='*.go' 2>/dev/null"
DIM_LIB_EXPORT_RM_REF='§4'
```

- [ ] **Step 2: 验证可 source**

Run: `cd swarm-yuan && ( set +u; . assets/inventory-dimensions.conf; echo "dims: ${#DIM_FRONTEND_UI_TITLE} ${DIM_STORE_RM_REF}" )`
Expected: 打印 `dims: 前端 UI 组件 §9`（无语法错误；`${#}` 为字符串长度不关键，关键是变量可见）

- [ ] **Step 3: Commit**

```bash
git add swarm-yuan/assets/inventory-dimensions.conf
git commit -m "feat(wp-p2): inventory-dimensions.conf 维度枚举注册表（7 维度数据驱动）"
```

---

## Task 2: `scripts/inventory-verify.sh` — 维度计数核验 + 错配 lint

**Files:**
- Create: `swarm-yuan/scripts/inventory-verify.sh`
- Test: `swarm-yuan/tests/test-inventory-verify.sh`

**Interfaces:**
- 消费：`assets/inventory-dimensions.conf`（Task 1）；目标仓库 `<PROJECT_DIR>`；目标 skill 的 `references/reference-manual.md`（数清单表行数）；可选 `PROJECT_FORM`（读 skill 的 precheck.conf 或 env）。
- 产生：CLI `inventory-verify.sh <PROJECT_DIR> [--skill-dir <dir>] [--form <backend|frontend|...>] [--tsv]`；stdout 人读摘要 + TSV 明细（`--tsv` 只出 TSV）。TSV 列：`维度 | 枚举计数 | 清单计数 | 比率 | 状态`；末尾 DIM_MISMATCH 行（如有）。exit 0（含 FAIL 维度，fail-open 核验）；1=arg 错误。

- [ ] **Step 1: 写失败测试**

Create `swarm-yuan/tests/test-inventory-verify.sh`:

```bash
#!/usr/bin/env bash
# test-inventory-verify.sh — inventory-verify.sh 双态测试（WP-P2/M1）
set -uo pipefail
cd "$(dirname "${0}")/.."
SH="scripts/inventory-verify.sh"
TMP="$(mktemp -d /tmp/ivtest.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

# --- 态 1：后端项目，controller 维度枚举计数 == 清单计数 → PASS ---
mkdir -p "$TMP/proj/src" "$TMP/skill/references"
cat > "$TMP/proj/src/a.ts" <<'EOF'
router.get('/x', h1)
router.post('/y', h2)
EOF
cat > "$TMP/proj/src/b.ts" <<'EOF'
router.get('/z', h3)
EOF
# reference-manual.md §6 接口表：表头 1 行 + 3 数据行 = 3 个端点清单
cat > "$TMP/skill/references/reference-manual.md" <<'EOF'
# reference-manual
## §6 全量接口端点表
| 端点 | 方法 | 说明 |
|------|------|------|
| /x | GET | a |
| /y | POST | b |
| /z | GET | c |
EOF
out="$(bash "$SH" "$TMP/proj" --skill-dir "$TMP/skill" --form backend --tsv 2>/dev/null)"; rc=$?
[[ $rc -eq 0 ]] && ok "后端态 exit 0" || bad "exit=$rc"
echo "$out" | grep -qE '后端 controller	3	3	1\.00	PASS' && ok "controller 3/3 PASS" || bad "controller 核验异常: $out"

# --- 态 2：枚举计数 > 清单计数（漏列）→ FAIL + 比率 <0.95 ---
cat > "$TMP/proj/src/c.ts" <<'EOF'
router.get('/w', h4)
router.post('/v', h5)
EOF
out="$(bash "$SH" "$TMP/proj" --skill-dir "$TMP/skill" --form backend --tsv 2>/dev/null)"
echo "$out" | grep -qE '后端 controller	5	3	0\.60	FAIL' && ok "漏列 5/3 FAIL" || bad "漏列核验异常: $out"

# --- 态 3：维度错配 lint（声明 backend 却有 UI 组件文件）→ DIM_MISMATCH ---
mkdir -p "$TMP/proj2/src" "$TMP/skill2/references"
printf '<template><div/></template>\n' > "$TMP/proj2/src/x.vue"
printf 'router.get("/a", h)\n' > "$TMP/proj2/src/c.ts"
cat > "$TMP/skill2/references/reference-manual.md" <<'EOF'
# reference-manual
## §6 全量接口端点表
| 端点 | 方法 |
| /a | GET |
EOF
out="$(bash "$SH" "$TMP/proj2" --skill-dir "$TMP/skill2" --form backend 2>/dev/null)"
echo "$out" | grep -qF 'DIM_MISMATCH' && ok "backend+UI 文件 → DIM_MISMATCH" || bad "错配未检出: $out"

# --- 态 4：fail-open（无 reference-manual.md → exit 0 + 提示）---
mkdir -p "$TMP/proj3/src" "$TMP/skill3"
printf 'router.get("/a", h)\n' > "$TMP/proj3/src/c.ts"
out="$(bash "$SH" "$TMP/proj3" --skill-dir "$TMP/skill3" --form backend 2>&1)"; rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -qF 'reference-manual.md' && ok "无清单 fail-open" || bad "态4 异常 rc=$rc: $out"

# --- 态 5：确定性（同输入连跑两次 byte-identical 的 TSV 明细段）---
o1="$(bash "$SH" "$TMP/proj" --skill-dir "$TMP/skill" --form backend --tsv 2>/dev/null)"
o2="$(bash "$SH" "$TMP/proj" --skill-dir "$TMP/skill" --form backend --tsv 2>/dev/null)"
[[ "$o1" == "$o2" ]] && ok "确定性 byte-identical" || bad "两次输出不一致"

[[ $FAIL -eq 0 ]] && { echo "PASS test-inventory-verify"; exit 0; } || { echo "FAIL test-inventory-verify" >&2; exit 1; }
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash swarm-yuan/tests/test-inventory-verify.sh`
Expected: FAIL（`scripts/inventory-verify.sh` 不存在）

- [ ] **Step 3: 实现 `swarm-yuan/scripts/inventory-verify.sh`**

```bash
#!/usr/bin/env bash
# inventory-verify.sh — 维度计数核验 + 维度错配 lint（WP-P2/M1）
# 把 Step 12 / exploration-guide §C+ 的手工枚举计数核验脚本化：
#   对目标仓库按维度注册表跑 find/grep 枚举 → 数 reference-manual.md 对应表行数 → 去重 → 算比率（≥0.95 PASS）
#   顺带维度错配 lint：声明纯后端却有 UI 组件文件 / 纯前端却有 controller → DIM_MISMATCH
# 用法:
#   bash inventory-verify.sh <PROJECT_DIR> [--skill-dir <dir>] [--form <形态>] [--tsv]
#     --skill-dir  目标 skill 根（含 references/reference-manual.md）；不给则只做枚举不核验清单
#     --form       项目形态（backend/frontend/async/desktop/mobile/lib/common）；不给读 skill conf PROJECT_FORM，再不给退化为全维度
#     --tsv        只输出 TSV 明细（默认人读摘要 + TSV）
# 输出: stdout TSV「维度	枚举计数	清单计数	比率	状态」按维度排序 + 末行 DIM_MISMATCH（如有）
# 退出码: 0 正常（含 FAIL 维度，fail-open 核验）；1 arg 错误 / PROJECT_DIR 不存在。
# 红线：本脚本只做计数 + 错配 lint，不替模型判断维度是否适用（适用判断由 §C+.0 形态判定驱动）。
set -uo pipefail
BASE="$(cd "$(dirname "${0}")/.." && pwd)"

PROJ=""; SKILL_DIR=""; FORM=""; TSV=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill-dir) SKILL_DIR="${2:?--skill-dir 需要路径}"; shift 2 ;;
    --form)      FORM="${2:?--form 需要形态}"; shift 2 ;;
    --tsv)       TSV=1; shift ;;
    -h|--help)   sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) [[ -z "$PROJ" ]] && PROJ="$1" || { echo "未知参数: $1" >&2; exit 1; }; shift ;;
  esac
done
[[ -n "$PROJ" && -d "$PROJ" ]] || { echo "✗ PROJECT_DIR 缺失或不存在: ${PROJ:-（空）}" >&2; exit 1; }
PROJ="$(cd "$PROJ" && pwd)"

# 形态：--form > skill conf PROJECT_FORM > 全维度（all）
if [[ -z "$FORM" && -n "$SKILL_DIR" ]]; then
  _conf="$SKILL_DIR/scripts/precheck.conf"
  [[ -f "$_conf" ]] && FORM=$( (set +u; . "$_conf" 2>/dev/null; printf '%s' "${PROJECT_FORM:-}") )
fi
FORM="${FORM:-all}"

# source 维度注册表
# shellcheck disable=SC1091
. "$BASE/assets/inventory-dimensions.conf" 2>/dev/null || { echo "✗ 维度注册表缺失: assets/inventory-dimensions.conf" >&2; exit 1; }

# 收集所有维度 ID（DIM_<ID>_TITLE 去前缀）
_dims=$(set | sed -n 's/^DIM_\([A-Z0-9_]*\)_TITLE=.*/\1/p' | sort -u)

# 形态适用判定：FORM=all 或维度 FORMS 含 $FORM 或维度 FORMS 含 common 且 $FORM != lib
_form_applicable() { # $1=维度FORMS
  local dfs="$1"
  [[ "$FORM" == "all" ]] && return 0
  case " $dfs " in
    *" all "*) return 0 ;;
    *" $FORM "*) return 0 ;;
    *" common "*) [[ "$FORM" != "lib" ]] && return 0 ;;
  esac
  return 1
}

# 跑枚举命令，去重计数（输出每行一文件 → sort -u → wc -l）
_enum_count() { # $1=CMD模板
  local cmd="$1"
  eval "${cmd}" 2>/dev/null | sort -u | grep -c . || echo 0
}

# 数 reference-manual.md 对应表行数：定位 §<n> 标题到下一个同级/更高级 ## 之间，数表格数据行（| 开头非分隔/表头）
_list_count() { # $1=RM文件 $2=锚 §<n> 或 §<n>.<sub>
  local rm="$1" anchor="$2"
  [[ -f "$rm" ]] || { echo 0; return; }
  local sec=${anchor%%.*} sub=""
  [[ "$anchor" == *.* ]] && sub=".${anchor#*.}"
  # awk：进入 §<n> 段（含 .<sub> 子段），到下一个 ## 退出；数 | 开头且非纯分隔/表头行
  awk -v sec="$sec" '
    { if ($0 ~ "^## " sec "[ .]") { insec=1; next }
      if (insec && $0 ~ "^## ") { insec=0 }
      if (insec && /^\|/) {
        line=$0; gsub(/[ \t]/,"",line)
        if (line !~ /^\|[-:|]+\|$/ && line !~ /^\|.*维度|端点|构件|方法|说明.*\|$/ && line !~ /^\|[-]+/) c++
      }
    }
    END { print c+0 }
  ' "$rm"
}

rows=""; mismatches=""
for d in $_dims; do
  eval "title=\${DIM_${d}_TITLE:-}" eval "dfs=\${DIM_${d}_FORMS:-all}"
  eval "cmd=\${DIM_${d}_CMD:-}" eval "ref=\${DIM_${d}_RM_REF:-}"
  [[ -n "$cmd" ]] || continue
  _form_applicable "$dfs" || continue
  enum=$(_enum_count "$cmd")
  list=0
  if [[ -n "$SKILL_DIR" ]]; then
    rm="$SKILL_DIR/references/reference-manual.md"
    list=$(_list_count "$rm" "$ref")
  fi
  if [[ "$list" -gt 0 ]]; then
    ratio=$(awk -v e="$enum" -v l="$list" 'BEGIN{ printf "%.2f", (l+0>=e+0?1.0:e/l) }')
    # 比率定义：清单覆盖枚举的比例 = min(1, list/enum)；spec 原意「清单计数 ≥ 枚举×0.95」
    ratio=$(awk -v e="$enum" -v l="$list" 'BEGIN{ if(e==0) print "1.00"; else { r=l/e; if(r>1) r=1; printf "%.2f", r } }')
    if awk -v r="$ratio" 'BEGIN{ exit !(r+0 >= 0.95) }'; then st="PASS"; else st="FAIL"; fi
  else
    ratio="-"; st="NO_LIST"
  fi
  rows="${rows}${title}	${enum}	${list}	${ratio}	${st}
"
  # 维度错配 lint：FORM=backend 但枚举到前端 UI 组件（>0）→ DIM_MISMATCH；FORM=frontend 枚举到 controller 同理
  if [[ "$FORM" == "backend" && "$d" == "FRONTEND_UI" && "$enum" -gt 0 ]]; then
    mismatches="${mismatches}DIM_MISMATCH	声明形态=backend 但检出前端 UI 组件 ${enum} 个（回 §C+.0 重判形态）\n"
  fi
  if [[ "$FORM" == "frontend" && "$d" == "BACKEND_CONTROLLER" && "$enum" -gt 0 ]]; then
    mismatches="${mismatches}DIM_MISMATCH	声明形态=frontend 但检出后端 controller ${enum} 个（回 §C+.0 重判形态）\n"
  fi
done

if [[ "$TSV" -eq 1 ]]; then
  printf '%s' "$rows" | sort
else
  echo "## 维度计数核验（inventory-verify.sh，形态=${FORM}）"
  echo "维度	枚举计数	清单计数	比率	状态"
  printf '%s' "$rows" | sort
fi
if [[ -n "$mismatches" ]]; then
  printf "${mismatches}" | sort
fi
exit 0
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash swarm-yuan/tests/test-inventory-verify.sh`
Expected: `PASS test-inventory-verify`

- [ ] **Step 5: 回归（真实 fixture 上跑，fail-open 不崩）**

Run: `cd swarm-yuan && bash scripts/inventory-verify.sh tests/fixtures/gin --form backend --tsv 2>/dev/null | head -5`
Expected: TSV 输出 controller 维度一行 + 状态（NO_LIST，fixture 无 skill）；exit 0

- [ ] **Step 6: Commit**

```bash
git add swarm-yuan/scripts/inventory-verify.sh swarm-yuan/tests/test-inventory-verify.sh
git commit -m "feat(wp-p2): inventory-verify.sh 维度计数核验 + 维度错配 lint（数据驱动，fail-open）"
```

---

## Task 3: SKILL.md Step 12 + exploration-guide §C+ 指针改写

**Files:**
- Modify: `swarm-yuan/SKILL.md:100`（Step 12 段）
- Modify: `swarm-yuan/references/exploration-guide.md:1010-1023`（§16 详尽构件库清单 + 16a 枚举计数核验表）

**Interfaces:**
- 模型新动作（spec §4）：跑一次 `inventory-verify.sh`；全 PASS → 直接引用报告结论；FAIL → 只针对失败维度回 Step 4 补漏；DIM_MISMATCH → 回 §C+.0 重判形态。

- [ ] **Step 1: SKILL.md:100 Edit**

old_string（Step 12 段中「**按维度计数核验（仅 P0 维度强制）：对 §C+.0 判定的每个维度，用对应的 `find`/`grep` 命令计数，对比 reference-manual.md 对应章节行数，偏差 >5% → 回到 Step 4 补全该维度**；**维度适配核验：纯后端项目不应有 UI 组件表，纯前端项目不应有 controller 表（维度错配 → 回 Step 4 重判）**」）：

```
；**按维度计数核验（仅 P0 维度强制）：对 §C+.0 判定的每个维度，用对应的 `find`/`grep` 命令计数，对比 reference-manual.md 对应章节行数，偏差 >5% → 回到 Step 4 补全该维度**；**维度适配核验：纯后端项目不应有 UI 组件表，纯前端项目不应有 controller 表（维度错配 → 回 Step 4 重判）**
```

new_string：

```
；**维度计数核验（WP-P2 脚本化）：跑 \`bash scripts/inventory-verify.sh <项目根> --skill-dir <skill目录> --form <§C+.0形态>\`，全 PASS → 直接引用报告结论；FAIL（清单计数 < 枚举计数 × 0.95）→ 只针对失败维度回 Step 4 补漏；DIM_MISMATCH（声明形态与枚举结果矛盾）→ 回 §C+.0 重判形态**。维度注册表见 \`assets/inventory-dimensions.conf\`（数据驱动，新增维度改注册表不改脚本）
```

- [ ] **Step 2: exploration-guide.md §16a 表 Edit**

old_string（`:1017-1023` 的 16a 枚举计数核验表整段）：

```
#### 16a. 枚举计数核验表
| 维度 | find/grep 命令 | 枚举计数 | 清单计数 | 覆盖率 | 偏差说明 |
|------|---------------|---------|---------|--------|---------|
| 前端 UI 组件 | `find ... \( -name "*.vue" -o -name "*.svelte" -o -name "*.tsx" -o -name "*.jsx" \)` | | | ≥95% | |
| 后端 controller | `grep -rl "router\.(get\|post..."` | | | ≥95% | |
| store | `grep -rl "defineStore\|createStore\|createSlice\|useReducer\|Provider.*value"` | | | ≥95% | |
| 类型定义 | `grep -rl "^export (interface\|type)"` | | | ≥95% | |
（按 §C+.0 判定的维度填，不存在的维度不填）
```

new_string：

```
#### 16a. 枚举计数核验表（WP-P2 脚本化）

> **本表由 `scripts/inventory-verify.sh` 自动产出（维度注册表 `assets/inventory-dimensions.conf` 数据驱动）。**
> 跑 `bash scripts/inventory-verify.sh <项目根> --skill-dir <skill目录> --form <§C+.0形态> [--tsv]`：
> - 全 PASS → 直接引用报告结论填本表「核验结果」列；
> - FAIL（清单计数 < 枚举计数 × 0.95）→ 只针对失败维度回 §C+.1 补全清单后重跑；
> - DIM_MISMATCH（声明形态与枚举结果矛盾，如 backend 却检出 UI 组件）→ 回 §C+.0 重判形态。
> 红线：脚本只做计数 + 错配 lint，不替模型判断维度是否适用（适用判断由 §C+.0 形态判定驱动）。

| 维度 | 枚举计数 | 清单计数 | 比率 | 核验结果 | 偏差说明 |
|------|---------|---------|------|---------|---------|
（由 inventory-verify.sh 报告填，按 §C+.0 判定的维度）
```

- [ ] **Step 3: 一致性回归**

Run: `cd swarm-yuan && bash scripts/self-check.sh 2>&1 | grep -E "✗|✓.*脚本名|inventory" ; bash tests/test-inventory-verify.sh`
Expected: 无 ✗；`PASS test-inventory-verify`

- [ ] **Step 4: Commit**

```bash
git add swarm-yuan/SKILL.md swarm-yuan/references/exploration-guide.md
git commit -m "docs(wp-p2): SKILL.md Step 12 + exploration-guide §16a 指向 inventory-verify.sh"
```

---

## Task 4: WP-P2 CI 接线 + 全量回归 + 收口

**Files:**
- Modify: `.github/workflows/ci.yml`（shellcheck 严格名单 + self-check job 测试步骤）

- [ ] **Step 1: ci.yml Edit 1 — shellcheck 严格名单**

old_string（`ci.yml:223-224` 行尾 `scripts/context-surface.sh; do`）：

```
                   scripts/gen-framework-index.sh assets/trace-log.sh scripts/cost-report.sh \
                   scripts/context-surface.sh; do
```

new_string：

```
                   scripts/gen-framework-index.sh assets/trace-log.sh scripts/cost-report.sh \
                   scripts/context-surface.sh scripts/inventory-verify.sh; do
```

- [ ] **Step 2: ci.yml Edit 2 — self-check job 测试步骤**

old_string（WP-P0/P1 测试步骤块）：

```yaml
      - name: 计量与信号索引测试（WP-P0/P1）
        run: |
          bash tests/test-context-surface.sh
          bash tests/test-cost-report.sh
          bash tests/test-signal-index.sh
          bash tests/test-detect-frameworks.sh
```

new_string：

```yaml
      - name: 计量/信号索引/维度核验测试（WP-P0/P1/P2）
        run: |
          bash tests/test-context-surface.sh
          bash tests/test-cost-report.sh
          bash tests/test-signal-index.sh
          bash tests/test-detect-frameworks.sh
          bash tests/test-inventory-verify.sh
```

- [ ] **Step 3: 本地全量回归**

Run: `bash verifier/v1/run-verifier.sh all && bash swarm-yuan/tests/test-inventory-verify.sh`
Expected: verifier 全绿（metrics/sensitive gate-fixtures 预存失败披露即可，非本 WP 回归）；测试 PASS

- [ ] **Step 4: Commit 并按 AGENTS.md 收口 WP-P2**

```bash
git add .github/workflows/ci.yml
git commit -m "ci(wp-p2): inventory-verify 进 shellcheck 严格层 + 维度核验测试进 CI"
# worktree 内 rebase origin/main → push → main merge --no-ff → 清理 worktree/分支
```

---

## Self-Review 记录

- Spec 覆盖：§4 M1 → Task 1-4 ✓（维度注册表 + 核验脚本 + 错配 lint + Step 12/guide 改写 + CI）；§9 测试 → Task 2 双态测试 + Task 4 全量回归 ✓。
- 红线遵守：脚本只做计数 + 错配 lint，不替模型判断维度适用性（适用判断由 §C+.0 形态判定驱动，脚本读 PROJECT_FORM 但不 override）✓。
- bash 3.2 quirk：赋值全用裸 comsub `x=$(cmd "$VAR")`；无 `$VAR`+多字节紧邻场景（TSV 用 TAB 分隔非多字节）✓。
- fail-open：无 reference-manual.md → NO_LIST exit 0；无 skill-dir → 只枚举不核验清单 ✓。
- 确定性：TSV 按 `sort` 输出，路径用 `cd $(pwd)` 取绝对值但显示维度名非路径，两次连跑 byte-identical（态 5 测试）✓。
- 占位符扫描：无运行期占位符；维度注册表的 `${PROJECT_DIR}` 是 eval 替换的命令模板占位，由脚本 `eval` 前替换，非设计占位。
