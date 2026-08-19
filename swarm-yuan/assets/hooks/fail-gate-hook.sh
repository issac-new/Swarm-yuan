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

set -uo pipefail

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

# ===== PreToolUse Write/Edit/MultiEdit：flag 存在 → deny =====
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
      cat << EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"swarm-yuan fail-gate: 门禁 ${_gates} 上次运行 fail 且未修复——GATE_ENFORCE_DENY 白名单生效，先跑 bash scripts/precheck.sh 修复后再改文件。","additionalContext":"swarm-yuan fail-gate: DENY — precheck 捕获的 fail 未修复（白名单：${_gates}）。解除方式：1) 跑 bash scripts/precheck.sh --all（或对应门禁）修复至通过（flag 自动清除）；2) 若需放宽白名单，改 scripts/precheck.conf 的 GATE_ENFORCE_DENY（UserChallenge 类决策，须决策落痕）；3) 本门默认关闭，是你在 conf 里显式开启的。"}}
EOF
      ;;
  esac
fi

exit 0
