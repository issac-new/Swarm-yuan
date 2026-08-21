#!/usr/bin/env bash
# gate-rules.sh — R13 批次2：rules.d 三值规则求值器（Codex Decision 架构的 bash 最小切片）
#
# 设计（docs/research/R13-final-plan.md §4.3）：
#   规则是数据不是代码：rules.d/*.rules 行格式
#     # 注释行
#     <pattern> → <allow|prompt|forbid> # <justification（forbid 须含替代方案）>
#   pattern 为 shell glob（fnmatch 语义，* 通配）；求值时多规则命中取最严：
#     forbid > prompt > allow（Codex execpolicy policy.rs .max() 同构）
#   求值器只是求值器：零内置规则（项目规则由探查期生成 / 审批沉淀写入）
#
# FORBID 消息 = 给模型的 API（Codex 拒绝消息带替代方案语义）：
#   FORBID <rule-id>: <原因>；替代：<justification 中"替代："后的内容>
#
# 用法:
#   bash gate-rules.sh <rules.d 目录> <待判定命令串>          # 输出三值之一 + FORBID 行
#   bash gate-rules.sh <rules.d 目录> <命令> --quiet           # 只输出三值（脚本内嵌用）
# 退出码: 0=allow / 3=prompt / 2=forbid / 1=参数错（fail-closed：rules.d 缺失时 deny-ish →
#   返回 prompt——无规则数据时命令须过宿主审批通道，不静默放行；§2.2 教义）
# 红线: 本脚本不改任何文件；FORBID 文案透传 stderr（宿主 hook deny 的 stderr 会回给模型）。
set -uo pipefail

RULES_DIR="${1:-}"
CMD="${2:-}"
QUIET=0
[[ "${3:-}" == "--quiet" ]] && QUIET=1

[[ -n "$CMD" ]] || {
  echo "Usage: bash gate-rules.sh <rules.d> <command> [--quiet]" >&2
  exit 1
}

# 无规则数据 → prompt（fail 方向：不静默 allow，走审批；§2.2——有下层门禁兜底处才可 fail-open）
_shopt_nullglob=$(shopt -p nullglob 2>/dev/null || true)
shopt -s nullglob
_rule_files=("$RULES_DIR"/*.rules)
eval "$_shopt_nullglob" 2>/dev/null || true
[[ ${#_rule_files[@]} -eq 0 ]] && { [[ $QUIET -eq 0 ]] && echo "PROMPT（无规则数据——命令走宿主审批通道）"; echo "prompt"; exit 3; }

# 取命令首 token 做前缀匹配用（git push origin main → "git push"）
_first_two=$(printf '%s' "$CMD" | awk '{print $1" "$2}')
_first_one=$(printf '%s' "$CMD" | awk '{print $1}')

_decision=""     # 最严决策
_hit_line=""     # 命中的规则原文（最严者）
_rank() { case "$1" in forbid) echo 3;; prompt) echo 2;; allow) echo 1;; *) echo 0;; esac }

for _rf in "${_rule_files[@]}"; do
  while IFS= read -r _line || [[ -n "$_line" ]]; do
    _line="${_line%"${_line##*[![:space:]]}"}"   # 去尾空白
    [[ -z "$_line" || "$_line" == \#* ]] && continue
    # 解析: <pattern> → <decision> [# justification]
    # BSD awk -F 不支持多字节分隔符（→ 是 UTF-8 三字节）——用 sed 切
    _pat=$(printf '%s' "$_line" | sed 's/→.*$//' | sed 's/[[:space:]]*$//')
    _rest=$(printf '%s' "$_line" | sed -n 's/^[^→]*→//p')
    _dec=$(printf '%s' "$_rest" | awk '{print $1}')
    _just=$(printf '%s' "$_rest" | sed -n 's/^[[:space:]]*[a-z]*[[:space:]]*#[[:space:]]*//p')
    [[ -z "$_pat" || -z "$_dec" ]] && continue
    case "$_dec" in allow|prompt|forbid) ;; *) continue ;; esac
    # glob 匹配（对首 token 或首两 token；pattern 含空格则对首两 token 匹配）
    _matched=0
    # pattern 尾部 " *" 视为"可有可无的尾参"（npm publish * 也命中裸 "npm publish"）
    _pat_base="${_pat% \*}"
    case "$_first_two" in $_pat) _matched=1 ;; esac
    [[ "$_matched" -eq 0 ]] && case "$_first_one" in $_pat_base) _matched=1 ;; esac
    [[ "$_matched" -eq 0 ]] && case "$_first_two" in $_pat_base) _matched=1 ;; esac
    [[ "$_matched" -eq 0 ]] && case "$CMD" in $_pat) _matched=1 ;; esac
    [[ "$_matched" -eq 0 ]] && continue
    # 取最严
    if [[ $( _rank "$_dec") -ge $( _rank "${_decision:-allow}") || -z "$_decision" ]]; then
      if [[ -z "$_decision" ]] || [[ $( _rank "$_dec") -gt $( _rank "$_decision") ]]; then
        _decision="$_dec"; _hit_line="$_line"; _hit_pat="$_pat"; _hit_just="$_just"; _hit_file="$_rf"
      fi
    fi
  done < "$_rf"
done

_decision="${_decision:-prompt}"   # 规则文件存在但无一命中 → prompt（兜底矩阵语义）

if [[ "$_decision" == "forbid" ]]; then
  _alt=$(printf '%s' "${_hit_just:-}" | sed -n 's/.*替代[：:][[:space:]]*//p')
  _rid=$(basename "${_hit_file:-${_rule_files[0]}}" .rules)
  [[ $QUIET -eq 0 ]] && printf 'FORBID %s: 命中规则「%s」——%s' "$_rid" "${_hit_pat}" "${_hit_just:-无理由}" >&2
  [[ $QUIET -eq 0 ]] && printf '\n' >&2
elif [[ "$_decision" == "prompt" && $QUIET -eq 0 && -n "${_hit_just:-}" ]]; then
  printf 'PROMPT: %s\n' "$_hit_just" >&2
fi

[[ $QUIET -eq 0 ]] && printf '%s\n' "$_decision" | tr '[:lower:]' '[:upper:]'
printf '%s\n' "$_decision"
case "$_decision" in
  forbid) exit 2 ;;
  prompt) exit 3 ;;
  allow)  exit 0 ;;
esac
