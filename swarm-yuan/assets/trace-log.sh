#!/usr/bin/env bash
# trace-log.sh — 全链路调用追踪（swarm-yuan 设计理念 2：每一步具体调用都有信息提示）
# 用法:
#   bash trace-log.sh --node <节点> --actor <技能/子代理> --tool <工具/命令> [--status started|done|fail] [--note <说明>]
#   --node/--actor 可缺省；--tool 必填。
# 行为（双通道，均无需用户确认）:
#   1) stdout 打印一行结构化提示：→ [<节点>] 调用 <actor> · <tool>（<status>）— <note>
#   2) 追加 JSON 行到 ${PROJECT_DIR:-$(pwd)}/.swarm-yuan/trace.jsonl（与 gate-runs.jsonl 同目录同构）
# 约定:
#   - AI 在每次具体调用（子代理扇出 / 技能调用 / CLI 工具 / 门禁脚本）前调用本脚本一次；
#     长耗时调用结束后可用 --status done/fail 再记一次。
#   - 本脚本自身永不交互、永不 fail 阻塞主流程（落盘失败仅 warn 到 stderr，stdout 提示照常打印）。
# 三平台兼容：bash 3.2 / 无 declare -A / date -u / sed 无 -i。

set -uo pipefail

NODE=""; ACTOR=""; TOOL=""; STATUS="started"; NOTE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --node)   NODE="${2:-}";   shift 2 ;;
    --actor)  ACTOR="${2:-}";  shift 2 ;;
    --tool)   TOOL="${2:-}";   shift 2 ;;
    --status) STATUS="${2:-}"; shift 2 ;;
    --note)   NOTE="${2:-}";   shift 2 ;;
    *) echo "未知参数: $1" >&2
       echo "Usage: bash trace-log.sh --node <节点> --actor <技能/子代理> --tool <工具/命令> [--status started|done|fail] [--note <说明>]" >&2
       exit 1 ;;
  esac
done
if [[ -z "$TOOL" ]]; then
  echo "Usage: bash trace-log.sh --node <节点> --actor <技能/子代理> --tool <工具/命令> [--status started|done|fail] [--note <说明>]" >&2
  exit 1
fi

# JSON 最小转义：反斜杠 / 双引号；剔除换行与回车（单行 jsonl 铁律）
_json_esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\r\n'; }

# 1) stdout 结构化提示（主通道：用户可见"调用了何种工具及技能"）
_line="→ "
[[ -n "$NODE" ]] && _line="${_line}[${NODE}] "
_line="${_line}调用 "
[[ -n "$ACTOR" ]] && _line="${_line}${ACTOR} · "
_line="${_line}${TOOL}"
[[ "$STATUS" != "started" ]] && _line="${_line}（${STATUS}）"
[[ -n "$NOTE" ]] && _line="${_line} — ${NOTE}"
echo "$_line"

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
  echo "⚠ trace-log: 无法创建 $STATE_DIR，仅保留 stdout 提示" >&2
fi
exit 0
