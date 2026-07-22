#!/usr/bin/env bash
# trace-log.sh — 全链路调用追踪（swarm-yuan 设计理念 2：每一步具体调用都有信息提示）
# 用法:
#   bash trace-log.sh --node <节点> --actor <技能/子代理> --tool <工具/命令> [--status started|done|fail] [--note <说明>]
#   --node/--actor 可缺省；--tool 必填。
#   bash trace-log.sh --decision --type <Mechanical|Taste|UserChallenge> --suggestion <建议> --user-action <approved|rejected|revised> [--rationale <理由>] [--phase <阶段>] [--alternatives <备选>] [--missing-context <缺失上下文>] [--cost-if-wrong <代价>]
#   --decision 模式（G1 决策治理）：落盘 .swarm-yuan/decisions.jsonl，对齐 ISO/IEC 42001 人工监督留痕。
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
# --decision 模式变量（G1 决策治理）
DECISION_MODE=0; D_TYPE=""; D_SUGGESTION=""; D_USER_ACTION=""; D_RATIONALE=""
D_ALTERNATIVES=""; D_MISSING_CONTEXT=""; D_COST_IF_WRONG=""; D_PHASE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --node)   NODE="${2:-}";   shift 2 ;;
    --actor)  ACTOR="${2:-}";  shift 2 ;;
    --tool)   TOOL="${2:-}";   shift 2 ;;
    --status) STATUS="${2:-}"; shift 2 ;;
    --note)   NOTE="${2:-}";   shift 2 ;;
    --decision)  DECISION_MODE=1; shift ;;
    --type)      D_TYPE="${2:-}"; shift 2 ;;
    --suggestion) D_SUGGESTION="${2:-}"; shift 2 ;;
    --user-action) D_USER_ACTION="${2:-}"; shift 2 ;;
    --rationale) D_RATIONALE="${2:-}"; shift 2 ;;
    --alternatives) D_ALTERNATIVES="${2:-}"; shift 2 ;;
    --missing-context) D_MISSING_CONTEXT="${2:-}"; shift 2 ;;
    --cost-if-wrong) D_COST_IF_WRONG="${2:-}"; shift 2 ;;
    --phase)     D_PHASE="${2:-}"; shift 2 ;;
    *) echo "未知参数: $1" >&2
       echo "Usage: bash trace-log.sh --node <节点> --actor <技能/子代理> --tool <工具/命令> [--status started|done|fail] [--note <说明>]" >&2
       echo "       bash trace-log.sh --decision --type <Mechanical|Taste|UserChallenge> --suggestion <建议> --user-action <approved|rejected|revised> [--rationale <理由>] [--phase <阶段>] [--alternatives <备选>] [--missing-context <缺失上下文>] [--cost-if-wrong <代价>]" >&2
       exit 1 ;;
  esac
done
if [[ "$DECISION_MODE" -eq 0 && -z "$TOOL" ]]; then
  echo "Usage: bash trace-log.sh --node <节点> --actor <技能/子代理> --tool <工具/命令> [--status started|done|fail] [--note <说明>]" >&2
  echo "       bash trace-log.sh --decision --type <Mechanical|Taste|UserChallenge> --suggestion <建议> --user-action <approved|rejected|revised> [...]" >&2
  exit 1
fi
# --decision 模式必填校验（缺则降级记录，永不 fail 阻塞主流程）
if [[ "$DECISION_MODE" -eq 1 ]]; then
  if [[ -z "$D_TYPE" || -z "$D_SUGGESTION" || -z "$D_USER_ACTION" ]]; then
    echo "⚠ --decision 模式缺 --type/--suggestion/--user-action，降级记录（exit 0 不阻塞）" >&2
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
# decision 模式跳过空"调用"行（落盘段自带决策提示）
[[ "$DECISION_MODE" -eq 0 ]] && echo "$_line"

# --decision 模式：落盘 decisions.jsonl（G1 决策治理，永不 fail 阻塞主流程）
if [[ "$DECISION_MODE" -eq 1 ]]; then
  STATE_DIR="${PROJECT_DIR:-$(pwd)}/.swarm-yuan"
  if mkdir -p "$STATE_DIR" 2>/dev/null; then
    ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    _dec_line=$(printf '{"ts":"%s","phase":"%s","type":"%s","ai_suggestion":"%s","user_action":"%s","rationale":"%s","actor":"%s","alternatives":"%s","missing_context":"%s","cost_if_wrong":"%s"}' \
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
