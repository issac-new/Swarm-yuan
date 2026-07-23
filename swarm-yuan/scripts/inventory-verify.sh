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
BASE=$(cd "$(dirname "${0}")/.." && pwd)

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
PROJ=$(cd "$PROJ" && pwd)

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
_dims=$(set | LC_ALL=C sed -n 's/^DIM_\([A-Z0-9_]*\)_TITLE=.*/\1/p' | sort -u)

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

# 跑枚举命令，计数（输出每行一匹配 → 数非空行）。
# 注意：CMD 模板含字面 ${PROJECT_DIR} 占位，必须先替换为真实路径再 eval。
# 不做 sort -u 去重——文件类 CMD（grep -rl / find）每文件只出一行，而出现次数类 CMD（grep -rhoE）
# 同一方法名可能多次出现，去重会压扁真实计数。计数与顺序无关，确定性由 grep -c 保证。
_enum_count() { # $1=CMD模板
  local cmd="$1"
  [[ -n "$cmd" ]] || { echo 0; return; }
  local _cmd
  _cmd=$(printf '%s' "$cmd" | LC_ALL=C sed "s|\${PROJECT_DIR}|$PROJ|g")
  local _n
  _n=$(eval "$_cmd" 2>/dev/null | LC_ALL=C grep -c .)
  [[ -n "$_n" ]] || _n=0
  echo "$_n"
}

# 数 reference-manual.md 对应表行数：定位 §<n> 标题到下一个同级/更高级 ## 之间，数表格数据行（| 开头非分隔/表头）
_list_count() { # $1=RM文件 $2=锚 §<n> 或 §<n>.<sub>
  local rm="$1" anchor="$2"
  [[ -f "$rm" ]] || { echo 0; return; }
  local sec=${anchor%%.*}
  # awk：进入 §<n> 段，到下一个 ## 退出；数 | 开头且非纯分隔/表头行
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

# fail-open 提示：给了 --skill-dir 但缺 reference-manual.md（只提示一次，stderr，不影响 exit 0）
_rm_missing_noticed=0
_notice_rm_missing() {
  if [[ "$_rm_missing_noticed" -eq 0 ]]; then
    echo "提示: $SKILL_DIR/references/reference-manual.md 不存在 → 清单计数全为 0（fail-open，仅枚举不核验）" >&2
    _rm_missing_noticed=1
  fi
}

rows=""; mismatches=""
for d in $_dims; do
  eval "title=\${DIM_${d}_TITLE:-}"
  eval "dfs=\${DIM_${d}_FORMS:-all}"
  eval "cmd=\${DIM_${d}_CMD:-}"
  eval "ref=\${DIM_${d}_RM_REF:-}"
  [[ -n "$cmd" ]] || continue
  _form_applicable "$dfs" || continue
  enum=$(_enum_count "$cmd")
  list=0
  if [[ -n "$SKILL_DIR" ]]; then
    rm="$SKILL_DIR/references/reference-manual.md"
    if [[ -f "$rm" ]]; then
      list=$(_list_count "$rm" "$ref")
    else
      _notice_rm_missing
    fi
  fi
  if [[ "$list" -gt 0 ]]; then
    # 比率定义：清单覆盖枚举的比例 = min(1, list/enum)；spec 原意「清单计数 ≥ 枚举×0.95」
    ratio=$(awk -v e="$enum" -v l="$list" 'BEGIN{ if(e==0) print "1.00"; else { r=l/e; if(r>1) r=1; printf "%.2f", r } }')
    if awk -v r="$ratio" 'BEGIN{ exit !(r+0 >= 0.95) }'; then st="PASS"; else st="FAIL"; fi
  else
    ratio="-"; st="NO_LIST"
  fi
  rows="${rows}${title}	${enum}	${list}	${ratio}	${st}
"
done

# 维度错配 lint：声明 backend 但检出前端 UI 组件 / 声明 frontend 但检出后端 controller → DIM_MISMATCH
# 注意：错配 lint 必须枚举「对面形态」的维度，与上面适用性过滤无关（FRONTEND_UI 对 backend 不适用，但仍需检测错配）。
if [[ "$FORM" == "backend" ]]; then
  eval "fcmd=\${DIM_FRONTEND_UI_CMD:-}"
  if [[ -n "$fcmd" ]]; then
    fenum=$(_enum_count "$fcmd")
    if [[ "${fenum:-0}" -gt 0 ]]; then
      mismatches="${mismatches}DIM_MISMATCH	声明形态=backend 但检出前端 UI 组件 ${fenum} 个（回 §C+.0 重判形态）
"
    fi
  fi
elif [[ "$FORM" == "frontend" ]]; then
  eval "bcmd=\${DIM_BACKEND_CONTROLLER_CMD:-}"
  if [[ -n "$bcmd" ]]; then
    benum=$(_enum_count "$bcmd")
    if [[ "${benum:-0}" -gt 0 ]]; then
      mismatches="${mismatches}DIM_MISMATCH	声明形态=frontend 但检出后端 controller ${benum} 个（回 §C+.0 重判形态）
"
    fi
  fi
fi

if [[ "$TSV" -eq 1 ]]; then
  printf '%s' "$rows" | LC_ALL=C sort
else
  echo "## 维度计数核验（inventory-verify.sh，形态=${FORM}）"
  echo "维度	枚举计数	清单计数	比率	状态"
  printf '%s' "$rows" | LC_ALL=C sort
fi
if [[ -n "$mismatches" ]]; then
  printf '%s' "$mismatches" | LC_ALL=C sort
fi
exit 0
