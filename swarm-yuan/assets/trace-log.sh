#!/usr/bin/env bash
# trace-log.sh — 全链路调用追踪（swarm-yuan 设计理念 2：每一步具体调用都有信息提示）
# 用法:
#   bash trace-log.sh --node <节点> --actor <技能/子代理> --tool <工具/命令> [--status started|done|fail] [--note <说明>]
#   --node/--actor 可缺省；--tool 必填。
#   bash trace-log.sh --decision --type <Mechanical|Taste|UserChallenge> --suggestion <建议> --user-action <approved|rejected|revised> [--rationale <理由>] [--phase <阶段>] [--reversibility <reversible|costly|one-way>] [--confidence <extracted|inferred|ambiguous>] [--alternatives <备选>] [--missing-context <缺失上下文>] [--cost-if-wrong <代价>]
#   --decision 模式（G1 决策治理）：落盘 .swarm-yuan/decisions.jsonl，对齐 ISO/IEC 42001 人工监督留痕。
#   --reversibility（§2.4，gsd-core v1.8.0 吸收）：决策可逆性评级，缺省 reversible；one-way 应由 AI 在调用前升级 type=UserChallenge。
#   --confidence（知识溯源三标，graphify v0.9.27 吸收）：决策依据的溯源置信度，缺省 inferred。
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
DECISION_MODE=0; D_TYPE=""; D_SUGGESTION=""; D_USER_ACTION=""; D_RATIONALE=""; D_GOAL=""; D_CLOSURE=""; D_REPAIR_REVIEW=""
D_ALTERNATIVES=""; D_MISSING_CONTEXT=""; D_COST_IF_WRONG=""; D_PHASE=""
D_REVERSIBILITY=""; D_CONFIDENCE=""; D_OUTCOME=""
# --key-node 模式变量（WP-Q2-lite 关键节点化）
KEY_NODE_MODE=0; KEY_NODE_NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --node)   NODE="${2:-}";   shift 2 ;;
    --actor)  ACTOR="${2:-}";  shift 2 ;;
    --tool)   TOOL="${2:-}";   shift 2 ;;
    --status) STATUS="${2:-}"; shift 2 ;;
    --note)   NOTE="${2:-}";   shift 2 ;;
    --key-node) KEY_NODE_MODE=1; KEY_NODE_NAME="${2:-}"; shift 2 ;;
    --decision)  DECISION_MODE=1; shift ;;
    --goal)      D_GOAL="${2:-}"; shift 2 ;;
    --closure)   D_CLOSURE="${2:-}"; shift 2 ;;
    --repair-review) D_REPAIR_REVIEW="${2:-}"; shift 2 ;;
    --type)      D_TYPE="${2:-}"; shift 2 ;;
    --suggestion) D_SUGGESTION="${2:-}"; shift 2 ;;
    --user-action) D_USER_ACTION="${2:-}"; shift 2 ;;
    --rationale) D_RATIONALE="${2:-}"; shift 2 ;;
    --alternatives) D_ALTERNATIVES="${2:-}"; shift 2 ;;
    --missing-context) D_MISSING_CONTEXT="${2:-}"; shift 2 ;;
    --cost-if-wrong) D_COST_IF_WRONG="${2:-}"; shift 2 ;;
    --phase)     D_PHASE="${2:-}"; shift 2 ;;
    --reversibility) D_REVERSIBILITY="${2:-}"; shift 2 ;;
    --confidence)    D_CONFIDENCE="${2:-}";    shift 2 ;;
    --outcome)       D_OUTCOME="${2:-}";       shift 2 ;;
    *) echo "未知参数: $1" >&2
       echo "Usage: bash trace-log.sh --node <节点> --actor <技能/子代理> --tool <工具/命令> [--status started|done|fail] [--note <说明>]" >&2
       echo "       bash trace-log.sh --decision --type <Mechanical|Taste|UserChallenge> --suggestion <建议> --user-action <approved|rejected|revised> [--rationale <理由>] [--phase <阶段>] [--reversibility <reversible|costly|one-way>] [--confidence <extracted|inferred|ambiguous>] [--outcome <implemented|rejected|superseded|proposed>] [--alternatives <备选>] [--missing-context <缺失上下文>] [--cost-if-wrong <代价>]" >&2
       echo "       bash trace-log.sh --key-node <节点名> [--actor <谁>] [--status started|done|fail] [--note <说明>]  # WP-Q2-lite 关键节点化（八节点关键调用看板）" >&2
       exit 1 ;;
  esac
done
if [[ "$DECISION_MODE" -eq 0 && -z "$TOOL" && "$KEY_NODE_MODE" -eq 0 ]]; then
  echo "Usage: bash trace-log.sh --node <节点> --actor <技能/子代理> --tool <工具/命令> [--status started|done|fail] [--note <说明>]" >&2
  echo "       bash trace-log.sh --decision --type <Mechanical|Taste|UserChallenge> --suggestion <建议> --user-action <approved|rejected|revised> [--reversibility <reversible|costly|one-way>] [--confidence <extracted|inferred|ambiguous>] [...]" >&2
  echo "       bash trace-log.sh --key-node <节点名> [--actor <谁>] [--status started|done|fail] [--note <说明>]" >&2
  exit 1
fi

# --key-node 模式（WP-Q2-lite 关键节点化）：落盘 .swarm-yuan/key-nodes.jsonl
# 八节点视角的"关键调用看板"——trace.jsonl 是全链路流水，key-nodes.jsonl 是节点级关键调用记录。
# 用法：bash trace-log.sh --key-node "①探查仓库" --actor "swarm-yuan/ai" --status started --note "三路并行+图谱工具"
#       bash trace-log.sh --key-node "⑦写回项目记忆" --status done --note "memory-writeback.sh"
if [[ "$KEY_NODE_MODE" -eq 1 ]]; then
  if [[ -z "$KEY_NODE_NAME" ]]; then
    echo "⚠ --key-node 缺节点名，降级记录（exit 0 不阻塞）" >&2
    exit 0
  fi
  STATE_DIR="${PROJECT_DIR:-$(pwd)}/.swarm-yuan"
  if mkdir -p "$STATE_DIR" 2>/dev/null; then
    ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    # JSON 最小转义
    _esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\r\n'; }
    _kn_line=$(printf '{"ts":"%s","key_node":"%s","actor":"%s","status":"%s","note":"%s"}' \
      "$ts" "$(_esc "$KEY_NODE_NAME")" "$(_esc "${ACTOR:-swarm-yuan/ai}")" \
      "$(_esc "$STATUS")" "$(_esc "$NOTE")")
    if ! printf '%s\n' "$_kn_line" >> "$STATE_DIR/key-nodes.jsonl" 2>/dev/null; then
      echo "⚠ trace-log: key-nodes.jsonl 落盘失败（不阻塞）" >&2
    else
      echo "→ [关键节点] ${KEY_NODE_NAME} · ${ACTOR:-swarm-yuan/ai} · ${STATUS}${NOTE:+ — ${NOTE}}"
    fi
  else
    echo "⚠ trace-log: 无法创建 ${STATE_DIR}（不阻塞）" >&2
  fi
  exit 0
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
  # 可逆性/置信度缺省（§2.4 + 知识溯源三标）
  [[ -z "$D_REVERSIBILITY" ]] && D_REVERSIBILITY="reversible"
  [[ -z "$D_CONFIDENCE" ]] && D_CONFIDENCE="inferred"
  # WP-R12-D：决策生命周期 outcome 缺省推导（dsh Agent Notes 四态吸收——未采纳决策也是治理证据）：
  # user_action=rejected → outcome=rejected；其余缺省 implemented；显式 --outcome 优先（superseded/proposed）
  if [[ -z "$D_OUTCOME" ]]; then
    case "$D_USER_ACTION" in
      rejected) D_OUTCOME="rejected" ;;
      *)        D_OUTCOME="implemented" ;;
    esac
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
    # R14（better-harness 吸收）：goal_id + closure——审计单元从"运行/会话"升级为"目标闭环"
    # （一个用户目标 + 一个验收边界；change set ↔ final validation set 链接才 closed）
    [[ -z "$D_CLOSURE" ]] && D_CLOSURE="open"
    _dec_line=$(printf '{"ts":"%s","phase":"%s","type":"%s","ai_suggestion":"%s","user_action":"%s","outcome":"%s","rationale":"%s","actor":"%s","alternatives":"%s","missing_context":"%s","cost_if_wrong":"%s","reversibility":"%s","confidence":"%s","goal_id":"%s","closure":"%s","repair_review":"%s"}' \
      "$ts" "$(_json_esc "$D_PHASE")" "$(_json_esc "$D_TYPE")" "$(_json_esc "$D_SUGGESTION")" \
      "$(_json_esc "$D_USER_ACTION")" "$(_json_esc "$D_OUTCOME")" "$(_json_esc "$D_RATIONALE")" "$(_json_esc "${ACTOR:-swarm-yuan/ai}")" \
      "$(_json_esc "$D_ALTERNATIVES")" "$(_json_esc "$D_MISSING_CONTEXT")" "$(_json_esc "$D_COST_IF_WRONG")" \
      "$(_json_esc "$D_REVERSIBILITY")" "$(_json_esc "$D_CONFIDENCE")" "$(_json_esc "$D_GOAL")" "$(_json_esc "$D_CLOSURE")" "$(_json_esc "$D_REPAIR_REVIEW")")
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
