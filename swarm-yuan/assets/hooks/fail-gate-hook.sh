#!/usr/bin/env bash
# fail-gate-hook.sh — PreToolUse 门禁失败捕获门（WP-Enforce1：precheck fail 从"红字"升级为"真拦截"）
#
# 设计动机：此前的 PreToolUse hook 只 echo "✗ FAIL" 文字，AI 不重跑就等于绕过（诊断轮发现
# 的第一大洞）。本 hook 在门禁 fail 后捕获"未修复就继续改文件"的行为，返回 deny JSON 真拦截。
#
# 机制（捕获模型，非前置模型——不预跑门禁防慢，只抓"已 fail 未修复"）：
#   1. 配置 GATE_ENFORCE_DENY（precheck.conf，逗号分隔门禁名白名单）非空才生效；
#      空（默认）= 完全关闭，与既有行为逐字节一致（向后兼容）。
#   2. draft 期（SKILL.md status: draft）自动关闭——骨架期门禁红是常态，拦截会死锁。
#   3. PostToolUse Bash precheck.sh 时：若退出码非 0，把白名单门禁名记到
#      .swarm-yuan/.gate-fail-flag（捕获）；退出码 0 时清除（修复后解锁）。
#   4. PreToolUse Write/Edit/MultiEdit 时：flag 存在且非空 → deny JSON。
#   5. 文件目标豁免：改 .swarm-yuan/ 下的 conf 与 precheck.sh 本身不拦（修门禁配置的通道）。
#
# 用法（由 hooks.json 的 PreToolUse matcher 自动调用；PostToolUse 记 flag）：
#   stdin = Claude Code hook payload（JSON）
#   stdout = deny 时 hookSpecificOutput JSON；其余静默 exit 0
#   bash 3.2 兼容；解析失败一律放行（fail-open，不误伤正常流）
#
# WP-Enforce3：--report 子命令（deny 事件审计报告，独立于 hook stdin 流程）
#   用法：bash fail-gate-hook.sh --report [N] [--project <项目根>]
#     N = 输出最近 N 条 deny 事件（默认 20）
#     --project = 项目根（缺省 = 当前目录）
#   输出：① 最近 N 条 deny 事件 TSV（ts/tool/target/gates）② 按门禁聚合 ③ 按工具聚合
#   退出码：0 正常（含空文件）；1 arg 错误。

set -uo pipefail

if [[ "${1:-}" == "--report" ]]; then
  _rp_n=20
  _rp_proj="$(pwd)"
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) _rp_proj="${2:?--project 需要路径}"; shift 2 ;;
      -h|--help) sed -n '22,29p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
      *) [[ "$1" =~ ^[0-9]+$ ]] && _rp_n="$1" || { echo "未知参数: $1" >&2; exit 1; }; shift ;;
    esac
  done
  _rp_file="${_rp_proj}/.swarm-yuan/gate-deny.jsonl"
  if [[ ! -f "$_rp_file" ]]; then
    echo "## fail-gate deny 报告（project=${_rp_proj}）"
    echo "无 deny 事件（.swarm-yuan/gate-deny.jsonl 不存在）"
    exit 0
  fi
  echo "## fail-gate deny 报告（project=${_rp_proj}，最近 ${_rp_n} 条）"
  echo
  echo "### ① 最近 deny 事件（按时间倒序）"
  printf '%s\t%s\t%s\t%s\n' "时间" "工具" "目标" "门禁"
  # sed 抽 4 个字段（ts/tool/target/gates），逐行输出 TSV
  tail -"$_rp_n" "$_rp_file" | LC_ALL=C sed -n 's/.*"ts":"\([^"]*\)".*"tool":"\([^"]*\)".*"target":"\([^"]*\)".*"gates":"\([^"]*\)".*/\1\t\2\t\3\t\4/p' | LC_ALL=C sort -r
  echo
  echo "### ② 按门禁聚合（哪些门禁 deny 最多）"
  LC_ALL=C sed -n 's/.*"gates":"\([^"]*\)".*/\1/p' "$_rp_file" | LC_ALL=C sort | LC_ALL=C uniq -c | LC_ALL=C sort -rn | LC_ALL=C awk '{printf "%d\t%s\n", $1, $2}'
  echo
  echo "### ③ 按工具聚合"
  LC_ALL=C sed -n 's/.*"tool":"\([^"]*\)".*/\1/p' "$_rp_file" | LC_ALL=C sort | LC_ALL=C uniq -c | LC_ALL=C sort -rn | LC_ALL=C awk '{printf "%d\t%s\n", $1, $2}'
  exit 0
fi

HOOK_INPUT=$(cat 2>/dev/null || printf '')
[[ -z "$HOOK_INPUT" ]] && exit 0

# ===== 提取 hook 上下文（python3 优先，降级 grep）=====
if command -v python3 >/dev/null 2>&1; then
  _PARSED=$(printf '%s' "$HOOK_INPUT" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get("hook_event_name", ""))
    print(d.get("tool_name", ""))
    ti = d.get("tool_input", {})
    if isinstance(ti, dict):
        print(ti.get("command", "") or "")
        print(ti.get("file_path", "") or ti.get("path", "") or "")
    else:
        print("")
        print("")
    print(d.get("cwd", ""))
    tr = d.get("tool_response", {})
    if isinstance(tr, dict):
        ec = tr.get("exit_code", tr.get("exitCode", ""))
        print("" if ec is None else str(ec))
    else:
        print("")
except Exception:
    for _ in range(6):
        print("")
' 2>/dev/null)
  _lines=()
  while IFS= read -r _ln; do _lines+=("$_ln"); done <<< "$_PARSED"
  EVENT="${_lines[0]:-}"
  TOOL="${_lines[1]:-}"
  CMD="${_lines[2]:-}"
  FILE_PATH="${_lines[3]:-}"
  CWD="${_lines[4]:-}"
  EXIT_CODE="${_lines[5]:-}"
else
  EVENT=$(printf '%s' "$HOOK_INPUT" | grep -o '"hook_event_name":"[^"]*"' 2>/dev/null | head -1 | sed 's/"hook_event_name":"//;s/"$//' || printf '')
  TOOL=$(printf '%s' "$HOOK_INPUT" | grep -o '"tool_name":"[^"]*"' 2>/dev/null | head -1 | sed 's/"tool_name":"//;s/"$//' || printf '')
  CMD=$(printf '%s' "$HOOK_INPUT" | grep -o '"command":"[^"]*"' 2>/dev/null | head -1 | sed 's/"command":"//;s/"$//' || printf '')
  FILE_PATH=""
  CWD=""
  EXIT_CODE=""
fi

[[ -z "$EVENT" ]] && exit 0

# ===== 定位 skill 根与配置 =====
# hooks.json 用 ${CLAUDE_PLUGIN_ROOT:-.} 调用，cwd 是项目根；skill 脚本在 scripts/ 下
ROOT="${CWD:-$(pwd)}"
CONF="$ROOT/scripts/precheck.conf"
FLAG_DIR="$ROOT/.swarm-yuan"
FLAG="$FLAG_DIR/.gate-fail-flag"

# 白名单读取（GATE_ENFORCE_DENY=check_security,check_sensitive 或 all）
DENY_LIST=""
[[ -f "$CONF" ]] && DENY_LIST=$(grep -m1 '^GATE_ENFORCE_DENY=' "$CONF" 2>/dev/null | sed 's/^GATE_ENFORCE_DENY=//;s/^"//;s/"$//' | tr -d '[:space:]' || printf '')
# 白名单空（默认）= 完全关闭，不读 flag、不输出任何东西
[[ -z "$DENY_LIST" ]] && exit 0

# draft 期自动关闭（骨架期门禁红是常态）
if [[ -f "$ROOT/SKILL.md" ]] && grep -q '^status: draft' "$ROOT/SKILL.md" 2>/dev/null; then
  exit 0
fi

# ===== PostToolUse Bash：precheck 退出码 → flag 记/清 =====
if [[ "$EVENT" == "PostToolUse" && "$TOOL" == "Bash" ]]; then
  # 只对 precheck.sh 调用感兴趣
  case "$CMD" in
    *precheck.sh*)
      mkdir -p "$FLAG_DIR" 2>/dev/null || true
      if [[ "${EXIT_CODE:-0}" != "0" && -n "$EXIT_CODE" ]]; then
        # 记录白名单门禁名（逗号分隔原样落盘，deny 时原样展示）
        printf '%s' "$DENY_LIST" > "$FLAG" 2>/dev/null || true
      else
        rm -f "$FLAG" 2>/dev/null || true
      fi
      ;;
  esac
  exit 0
fi

# ===== PreToolUse Write/Edit/MultiEdit/Bash：flag 存在 → deny =====
# WP-Enforce2 扩展：
#   ① 拦截范围加 Bash（仅拦"推进态"命令白名单：git push/commit/merge/release/deploy/install 等；
#      不拦只读命令 git status/log/diff/ls/cat/grep，也不拦测试命令 npm test/build/lint——fail 后
#      需要重跑这些诊断，拦了反而死锁）。
#   ② deny 事件落盘 .swarm-yuan/gate-deny.jsonl（时间/工具/目标/白名单门禁），供 verifier 审计
#      和用户复盘——这是 deny 动作的"留痕"（G1 决策治理对齐 ISO/IEC 42001）。
#   ③ Bash 拦截需独立开关 GATE_ENFORCE_DENY_BASH（默认空=不拦 Bash，避免误伤）。
_deny_log() { # $1=tool $2=target $3=gates
  local _dl_dir="$ROOT/.swarm-yuan"
  local _dl_file="${_dl_dir}/gate-deny.jsonl"
  mkdir -p "$_dl_dir" 2>/dev/null || return 0
  local _dl_ts
  _dl_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  # JSON 最小转义（bash 3.2 + UTF-8 中文安全：先剥离换行/回车/反斜杠/双引号）
  local _e1 _e2 _e3
  _e1=$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\r\n')
  _e2=$(printf '%s' "$2" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\r\n')
  _e3=$(printf '%s' "$3" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\r\n')
  printf '{"ts":"%s","tool":"%s","target":"%s","gates":"%s"}\n' "$_dl_ts" "$_e1" "$_e2" "$_e3" >> "$_dl_file" 2>/dev/null || true
}

if [[ "$EVENT" == "PreToolUse" ]]; then
  case "$TOOL" in
    Write|Edit|MultiEdit)
      # flag 不存在 → 放行
      [[ ! -f "$FLAG" ]] && exit 0
      # 文件目标豁免：修 .swarm-yuan/ conf 或 precheck.sh 本身不拦（修配置通道）
      _norm=$(printf '%s' "$FILE_PATH" | tr '\\' '/')
      case "$_norm" in
        *.swarm-yuan/*|*precheck.sh|*precheck.conf|*precheck.arch.conf|*precheck.compliance.conf|*precheck.patch.conf)
          exit 0
          ;;
      esac
      _gates=$(cat "$FLAG" 2>/dev/null || printf 'configured')
      [[ -z "$_gates" ]] && _gates="configured"
      _deny_log "$TOOL" "$FILE_PATH" "$_gates"
      cat << EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"swarm-yuan fail-gate: 门禁 ${_gates} 上次运行 fail 且未修复——GATE_ENFORCE_DENY 白名单生效，先跑 bash scripts/precheck.sh 修复后再改文件。","additionalContext":"swarm-yuan fail-gate: DENY — precheck 捕获的 fail 未修复（白名单：${_gates}）。解除方式：1) 跑 bash scripts/precheck.sh --all（或对应门禁）修复至通过（flag 自动清除）；2) 若需放宽白名单，改 scripts/precheck.conf 的 GATE_ENFORCE_DENY（UserChallenge 类决策，须决策落痕）；3) 本门默认关闭，是你在 conf 里显式开启的。deny 事件已落盘 .swarm-yuan/gate-deny.jsonl（审计留痕）。"}}
EOF
      ;;
    Bash)
      # WP-Enforce2：Bash 拦截需独立开关 GATE_ENFORCE_DENY_BASH（默认空=不拦，避免误伤）
      # 白名单：git push/commit/merge/release/deploy/install/publish；不拦只读（status/log/diff/ls/cat/grep）与测试命令（npm test/build/lint）——fail 后需要重跑诊断。
      _bash_deny=""
      [[ -f "$CONF" ]] && _bash_deny=$(grep -m1 '^GATE_ENFORCE_DENY_BASH=' "$CONF" 2>/dev/null | sed 's/^GATE_ENFORCE_DENY_BASH=//;s/^"//;s/"$//' | tr -d '[:space:]' || printf '')
      [[ -z "$_bash_deny" ]] && exit 0
      [[ ! -f "$FLAG" ]] && exit 0
      # 提取命令首个 token（git/npm/bash/sh 等）
      _cmd_first=$(printf '%s' "$CMD" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
      _cmd_second=$(printf '%s' "$CMD" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')
      # 拼成 cmd_first:cmd_second 形式做白名单匹配（git:push / npm:publish / bash:deploy.sh 等）
      _cmd_key="${_cmd_first}:${_cmd_second}"
      # 白名单匹配（逗号分隔，支持三种形式：cmd_first 兜底 / cmd_first:cmd_second 精确 / cmd_second 单独）
      # 例：白名单 "push" 命中 "git push ..."（cmd_second）；白名单 "git" 命中所有 git 子命令（cmd_first 兜底）；
      #     白名单 "git:push" 精确命中。
      _match=0
      IFS=',' read -ra _deny_arr <<< "$_bash_deny"
      for _d in "${_deny_arr[@]+"${_deny_arr[@]}"}"; do
        [[ -z "$_d" ]] && continue
        if [[ "$_cmd_key" == "$_d" || "$_cmd_first" == "$_d" || "$_cmd_second" == "$_d" ]]; then
          _match=1; break
        fi
      done
      [[ "$_match" -eq 0 ]] && exit 0
      _gates=$(cat "$FLAG" 2>/dev/null || printf 'configured')
      [[ -z "$_gates" ]] && _gates="configured"
      _deny_log "Bash" "$CMD" "$_gates"
      cat << EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"swarm-yuan fail-gate: 门禁 ${_gates} 上次运行 fail 且未修复——GATE_ENFORCE_DENY_BASH 拦截推进态命令（${_cmd_key}）。","additionalContext":"swarm-yuan fail-gate: DENY Bash — precheck 捕获的 fail 未修复（白名单：${_gates}），推进态命令 ${_cmd_key} 被 GATE_ENFORCE_DENY_BASH 拦截。解除方式：1) 跑 bash scripts/precheck.sh --all（或对应门禁）修复至通过；2) 若为误伤（如临时调研命令），改 scripts/precheck.conf 的 GATE_ENFORCE_DENY_BASH 白名单（UserChallenge 类决策）。deny 事件已落盘 .swarm-yuan/gate-deny.jsonl。"}}
EOF
      ;;
  esac
fi

exit 0
