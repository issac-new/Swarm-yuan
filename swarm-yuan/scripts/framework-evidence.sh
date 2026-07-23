#!/usr/bin/env bash
# framework-evidence.sh — 框架规律证据台账（WP-P3b/M2，最大 token 池脚本化）
# 输入: 目标仓库 + ACTIVE_FRAMEWORKS → 逐框架提取 references/frameworks/<fw>.md §3 verify 块
#       → 批量执行 cmd（${PROJECT_DIR} 替换为实参）→ 输出证据台账 TSV
# 输出: stdout TSV「framework | rule_id | rule_title | hits | evidence(top-N file:line) | SUGGEST」
#   SUGGEST 启发式（非判决）: hits>0 → applicable; hits=0 且 expect≠always → likely-na; expect=always → manual
# 红线（template-spec.md:346）: 本脚本只产证据台账 + 启发式 SUGGEST，不替模型做适用/不适用判断。
# 用法:
#   bash framework-evidence.sh <PROJECT_DIR> [--frameworks <fw1,fw2>] [--frameworks-dir <dir>] [--top <N>]
#     --frameworks       逗号分隔框架 id 列表（不给则调 detect-frameworks.sh 自动探测）
#     --frameworks-dir   框架文件目录（默认 references/frameworks，测试用）
#     --top              evidence 截断条数（默认 3）
# 退出码: 0 正常（fail-open，框架文件缺失跳过）；1 arg 错误。
set -uo pipefail
BASE="$(cd "$(dirname "${0}")/.." && pwd)"

PROJ=""; FWS=""; FWDIR="$BASE/references/frameworks"; TOP=3
while [[ $# -gt 0 ]]; do
  case "$1" in
    --frameworks) FWS="${2:?--frameworks 需要列表}"; shift 2 ;;
    --frameworks-dir) FWDIR="${2:?--frameworks-dir 需要路径}"; shift 2 ;;
    --top) TOP="${2:?--top 需要 N}"; shift 2 ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) [[ -z "$PROJ" ]] && PROJ="$1" || { echo "未知参数: $1" >&2; exit 1; }; shift ;;
  esac
done
[[ -n "$PROJ" && -d "$PROJ" ]] || { echo "✗ PROJECT_DIR 缺失或不存在: ${PROJ:-（空）}" >&2; exit 1; }
PROJ="$(cd "$PROJ" && pwd)"

# 框架列表：--frameworks > detect-frameworks.sh
if [[ -z "$FWS" ]]; then
  if [[ -x "$BASE/scripts/detect-frameworks.sh" ]]; then
    FWS=$("$BASE/scripts/detect-frameworks.sh" "$PROJ" 2>/dev/null | sed -n 's/.*"\([^"]*\)".*/\1/p' | tr '\n' ',' | sed 's/,$//')
  fi
  [[ -z "$FWS" ]] && { echo "（无 ACTIVE_FRAMEWORKS，台账为空）"; exit 0; }
fi

printf 'framework\trule_id\trule_title\thits\tevidence\tSUGGEST\n'

# bash 3.2 兼容的多框架迭代：用 set -- 切分逗号列表（处理单/多框架）
oifs=$IFS; IFS=','; set -- $FWS; IFS=$oifs
for fw in "$@"; do
  [[ -n "$fw" ]] || continue
  rule="$FWDIR/$fw.md"
  [[ -f "$rule" ]] || { printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$fw" "-" "-" "-" "-" "NO_RULE_FILE"; continue; }
  # 状态机式扫 verify 块：进入 ```verify 段，收 id/cmd/expect；退出时输出 VBLK 行
  # 红线：awk 只解析块字段，不执行 cmd（执行在 shell 层 fail-open）。
  # 用 US(\x1f, 非空白) 作分隔符：read 对 IFS 空白会合并空字段（空 cmd 会塌陷），
  # 非空白分隔符保留空字段，保证 id/cmd/expect/title 对齐（bash 3.2 兼容）。
  US="$(printf '\x1f')"
  awk -v fw="$fw" -v us="$US" '
    /^```verify/ { inblk=1; id=""; cmd=""; expect="always"; next }
    inblk && /^```/ { inblk=0; printf "%s%s%s%s%s%s%s%s%s\n", id, us, cmd, us, expect, us, title, us, fw; next }
    inblk && /^id:/ { id=$2 }
    inblk && /^cmd:/ { sub(/^cmd:[[:space:]]*/,""); cmd=$0 }
    inblk && /^expect:/ { expect=$2 }
    /^### 规律/ { title=$0; sub(/^### 规律[：:]?[[:space:]]*/,"",title) }
  ' "$rule" | while IFS="$US" read -r vid vcmd vexp vtitle vfw; do
    [[ -n "$vid" ]] || continue
    if [[ "$vexp" == "always" || -z "$vcmd" ]]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$fw" "$vid" "$vtitle" "-" "-" "manual"
      continue
    fi
    # 替换 ${PROJECT_DIR} 并执行（eval 处理引号；fail-open 失败计 0/空）
    _cmd=$(printf '%s' "$vcmd" | sed "s|\${PROJECT_DIR}|$PROJ|g")
    # 单次 eval 捕获输出，再派生 hits + evidence（避免双重执行/词法分裂）
    _out=$(eval "$_cmd" 2>/dev/null || true)
    if [[ -z "$_out" ]]; then
      _hits=0
      _evid=""
    else
      _hits=$(printf '%s\n' "$_out" | grep -c . || true)
      _evid=$(printf '%s\n' "$_out" | LC_ALL=C sed -E 's|^'"$PROJ"'/||' | LC_ALL=C sort | head -"$TOP" | tr '\n' ';' | sed 's/;$//')
    fi
    if [[ "$_hits" -gt 0 ]]; then _sug="applicable"; else _sug="likely-na"; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$fw" "$vid" "$vtitle" "$_hits" "$_evid" "$_sug"
  done
done
exit 0
