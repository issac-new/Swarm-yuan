#!/usr/bin/env bash
# state-machine.sh — 通用阶段状态机脚本模板（comet 风格，由 swarm-yuan 生成器按项目定制）
# 对应方法论：comet 脚本背书状态机（非 prompt-only），survive context compaction
# 用法:
#   bash state-machine.sh init <change-name>          # 初始化状态文件
#   bash state-machine.sh get <field>                  # 读取字段
#   bash state-machine.sh set <field> <value>          # 设置字段
#   bash state-machine.sh transition <phase>           # 阶段转换（含门禁）
#   bash state-machine.sh guard <phase>                # 检查阶段准入条件
#   bash state-machine.sh next                         # 显示下一阶段
#   bash state-machine.sh status                       # 显示当前状态
#   bash state-machine.sh update                       # 原地修订 plan（openspec /opsx:update 能力）
# 生成目标技能时：替换 PHASES / GUARDS 为项目实际阶段与门禁

set -euo pipefail

# ===== 按项目定制 =====
STATE_DIR="${PROJECT_DIR:-$(pwd)}/.swarm-yuan"
STATE_FILE="$STATE_DIR/state.yaml"
# 阶段顺序（comet 5 阶段模式 + D 方向 operate 发布后运营，可按项目裁剪）
PHASES=("open" "design" "build" "verify" "archive" "operate")
# =====================

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; }

# A 方向：context-save 输入消毒（gstack 吸收，防注入）
# 用户输入白名单字符集过滤，防路径穿越/命令注入——"用户输入永不进 LLM 层拼路径"
sanitize_input() {
  printf '%s' "$1" | tr -cd 'a-zA-Z0-9._-'
}

# CLI 接线层运行时守卫（WP1.2）：comet CLI 真实接线
# comet 提供 `comet guard`（检查 Classic workflow phase guard）/ `comet state`（读写状态）。
# 项目用 comet 时（有 .comet/ 或 active change），guard_phase 调 comet guard 做状态一致性补充校验；
# 未装/项目未用 comet 时降级到本脚本自带的文件检查 guard_phase 逻辑。
has_comet() { command -v comet >/dev/null 2>&1; }

# WP-D3：trace_tool 辅助函数（全链路追踪——设计理念 2，state-machine 侧）
# 打印"→ [状态流转] 调用 工具 · X（started）"到 stderr + 落盘 trace.jsonl。
# 分级（WP-C 减重）：第三方工具「调用级」细节默认关闭，SWARM_YUAN_TRACE=verbose 时启用；
# 节点级（阶段迁移）追踪不受影响。
TRACE_LOG_SH="${STATE_DIR:-${PROJECT_DIR:-$(pwd)}/.swarm-yuan}/../scripts/trace-log.sh"
[[ -f "$TRACE_LOG_SH" ]] || TRACE_LOG_SH="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/trace-log.sh"
trace_tool() {  # $1=工具名 $2=操作
  [[ "${SWARM_YUAN_TRACE:-}" == "verbose" ]] || return 0
  [[ -f "$TRACE_LOG_SH" ]] || return 0
  bash "$TRACE_LOG_SH" --node "状态流转" --actor "工具" --tool "${1} ${2}" --status started >&2 2>/dev/null || true
}

init_state() {
  local change="${1:-}"
  [[ -z "$change" ]] && { echo "Usage: state-machine.sh init <change-name>"; exit 1; }
  # A 方向：change name 经白名单消毒（防路径穿越/命令注入）
  change=$(sanitize_input "$change")
  [[ -z "$change" ]] && { echo "ERROR: change name 全被过滤（含非法字符），请重命名"; exit 1; }
  mkdir -p "$STATE_DIR"
  if [[ -f "$STATE_FILE" ]]; then
    echo "WARN: 状态文件已存在: $STATE_FILE"
    read -rp "覆盖? (y/N) " confirm
    [[ "$confirm" != "y" ]] && exit 0
  fi
  cat > "$STATE_FILE" <<EOF
change: $change
phase: open
workflow: full
build_mode: subagent-driven-development
isolation: branch
verify_result: pending
branch_status: pending
created_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
  echo "✓ 状态已初始化: $STATE_FILE"
  echo "  change: $change"
  echo "  phase: open"
}

get_field() {
  local field="${1:-}"
  [[ -z "$field" ]] && { echo "Usage: state-machine.sh get <field>"; exit 1; }
  [[ ! -f "$STATE_FILE" ]] && { echo "ERROR: 状态文件不存在，先 init"; exit 1; }
  # WP-R Bug#1: grep|head -1|sed 在 set -euo pipefail 下,若同字段多行 grep 被 head 截断收 SIGPIPE(141)。
  # head -1 只取首行,改用 sed 取首行(无截断管道);grep 无匹配返回 1 也需 || true 兜底。
  grep "^$field:" "$STATE_FILE" 2>/dev/null | sed -n "1s/^$field: //p" || true
}

set_field() {
  local field="${1:-}" value="${2:-}"
  [[ -z "$field" ]] && { echo "Usage: state-machine.sh set <field> <value>"; exit 1; }
  [[ ! -f "$STATE_FILE" ]] && { echo "ERROR: 状态文件不存在，先 init"; exit 1; }
  if grep -q "^$field:" "$STATE_FILE"; then
    # value 含 | 会撞 sed 分隔符（报错且静默不写），含 & 会展开为匹配文本——
    # 改用 awk 按字面前缀重写该行（三平台兼容，mktemp+cat 防中途失败清空状态文件）
    local tmp
    tmp="$(mktemp /tmp/swarmstate.XXXXXX)"
    if ! awk -v f="$field" -v v="$value" \
      'index($0, f ":") == 1 && !done { print f ": " v; done=1; next } { print }' \
      "$STATE_FILE" > "$tmp"; then
      rm -f "$tmp"
      echo "ERROR: 更新字段失败: $field" >&2
      exit 1
    fi
    cat "$tmp" > "$STATE_FILE" || { rm -f "$tmp"; echo "ERROR: 写入状态文件失败" >&2; exit 1; }
    rm -f "$tmp"
  else
    echo "$field: $value" >> "$STATE_FILE"
  fi
  echo "✓ $field = $value"
}

guard_phase() {
  local phase="${1:-}"
  [[ -z "$phase" ]] && { echo "Usage: state-machine.sh guard <phase>"; exit 1; }
  [[ ! -f "$STATE_FILE" ]] && { echo "ERROR: 状态文件不存在"; exit 1; }
  echo "=== 阶段门禁检查: $phase ==="
  local ok=1
  case "$phase" in
    design)
      # WP-C1：实装产出物检查（替换原占位 pass）。检查 open 阶段产出 proposal.md 存在。
      # 可配 PROPOSAL_FILE（默认 $PROJECT_DIR/.swarm-yuan/proposal.md 或 $SPEC_FILE）。
      local proposal="${PROPOSAL_FILE:-}"
      [[ -z "$proposal" ]] && proposal="${PROJECT_DIR:-$(pwd)}/.swarm-yuan/proposal.md"
      if [[ -f "$proposal" ]]; then
        pass "design 准入: open 阶段产出存在（${proposal}）"
      else
        # 降级：未配置 PROPOSAL_FILE 且默认路径无文件时，检查 SPEC_FILE（项目可能用 spec.md 替代 proposal）
        local spec_f="${SPEC_FILE:-}"
        if [[ -n "$spec_f" && -f "$spec_f" ]]; then
          pass "design 准入: spec 存在（${spec_f}，作为 proposal 等价物）"
        else
          fail "design 准入失败: 缺 open 阶段产出（$proposal 不存在；可在 precheck.conf 配 PROPOSAL_FILE 指向实际路径）"
          ok=0
        fi
      fi
      # G1：design 准入 warn 检查 decisions.jsonl（warn 不 fail，不阻塞流转）
      local _dec_file="${STATE_DIR}/decisions.jsonl"
      if [[ ! -f "$_dec_file" ]]; then
        echo "  ⚠ decisions.jsonl 未创建（决策未留痕，G1 决策治理）"
      elif [[ ! -s "$_dec_file" ]]; then
        echo "  ℹ decisions.jsonl 存在但为空（draft 期允许）"
      else
        pass "decisions.jsonl 已有决策记录"
      fi
      ;;
    build)
      # 门禁：design 阶段产出 design doc + tasks
      local bm iso
      bm=$(get_field build_mode); iso=$(get_field isolation)
      [[ -z "$bm" ]] && { fail "build_mode 未设置"; ok=0; }
      [[ -z "$iso" ]] && { fail "isolation 未设置"; ok=0; }
      [[ $ok -eq 1 ]] && pass "build 准入: build_mode=$bm, isolation=$iso"
      ;;
    verify)
      # WP-C1：实装产出物检查（替换原占位 pass）。检查 tasks.md 全部 - [x]（所有任务完成）。
      # 可配 TASKS_FILE（默认 $PROJECT_DIR/.swarm-yuan/tasks.md）。未配置/不存在时降级 skip（不阻塞）。
      local tasks_f="${TASKS_FILE:-}"
      [[ -z "$tasks_f" ]] && tasks_f="${PROJECT_DIR:-$(pwd)}/.swarm-yuan/tasks.md"
      if [[ -f "$tasks_f" ]]; then
        local unchecked
        # grep -c 零命中时打印 0 但 exit 1——用 || true 保留输出 "0"；
        # 误用 || echo 0 会得到 "0\n0"，-eq 判失败把全勾 tasks 误判为未完成
        unchecked=$(grep -cE '^- \[ \]' "$tasks_f" 2>/dev/null || true)
        if [[ "$unchecked" -eq 0 ]]; then
          pass "verify 准入: tasks 全部完成（${tasks_f}）"
        else
          fail "verify 准入失败: ${tasks_f} 有 ${unchecked} 项未勾选（- [ ]）"
          ok=0
        fi
      else
        # 降级：无 tasks.md 时不阻塞（项目可能用其他任务追踪方式），仅提示
        echo "  (未找到 ${tasks_f}，verify 准入降级跳过——可配 TASKS_FILE 启用检查)"
      fi
      ;;
    archive)
      # 门禁：verify 通过
      local vr
      vr=$(get_field verify_result)
      [[ "$vr" != "pass" ]] && { fail "verify_result=${vr}，须先 pass"; ok=0; }
      [[ $ok -eq 1 ]] && pass "archive 准入: verify_result=${vr}"
      ;;
    operate)
      # D 方向：operate 发布后运营准入——verify 通过 + 运营报告（warn 不 fail，可选延伸阶段）
      local vr
      vr=$(get_field verify_result)
      [[ "$vr" != "pass" ]] && echo "  ⚠ operate 准入: verify_result=${vr}（建议先 verify pass）"
      local op_report="${PROJECT_DIR:-$(pwd)}/.swarm-yuan/operate-report.md"
      if [[ -f "$op_report" ]]; then
        pass "operate 准入: 运营报告存在（${op_report}）"
      else
        echo "  ⚠ operate 准入: 运营报告未创建（可选延伸阶段，warn 不阻塞）"
      fi
      pass "operate 阶段（发布后运营，可选延伸）"
      ;;
    *)
      fail "未知阶段: $phase"; ok=0
      ;;
  esac
  # comet CLI 接线（WP1.2）：项目用 comet 时，跑 `comet guard` 做状态一致性补充校验。
  # comet guard 无 active change 时 rc=0 不报错；有 change 时校验 phase guard 一致性，失败 → fail。
  if has_comet; then
    local comet_root="${PROJECT_DIR:-$(pwd)}"
    if [[ -d "$comet_root/.comet" ]]; then
      trace_tool "comet" "guard"
      local comet_out; comet_out=$(cd "$comet_root" && comet guard 2>&1 || true)
      if echo "$comet_out" | grep -qiE 'error|fail|invalid|不一致'; then
        fail "comet guard: 状态一致性校验失败（详见输出）"
        echo "$comet_out" | tail -5 | sed 's/^/    /'
        ok=0
      else
        pass "comet guard: 状态一致性校验通过（或无 active change）"
      fi
    fi
  fi
  [[ $ok -eq 1 ]] && echo "✓ 门禁通过" || { echo "✗ 门禁未通过"; exit 1; }
}

transition_phase() {
  local target="${1:-}"
  [[ -z "$target" ]] && { echo "Usage: state-machine.sh transition <phase>"; exit 1; }
  local current; current=$(get_field phase)
  echo "=== 阶段转换: $current → $target ==="
  # 检查顺序
  local cur_idx=-1 tgt_idx=-1
  for i in "${!PHASES[@]}"; do
    [[ "${PHASES[$i]}" == "$current" ]] && cur_idx=$i
    [[ "${PHASES[$i]}" == "$target" ]] && tgt_idx=$i
  done
  if [[ $tgt_idx -le $cur_idx ]]; then
    echo "ERROR: 不能回退到 ${target}（当前 ${current}）"
    exit 1
  fi
  # 门禁
  guard_phase "$target" || exit 1
  set_field phase "$target"
  # G1：阶段流转决策留痕（Taste 类，guard 通过即 approved）
  _sm_tl="${STATE_DIR:-${PROJECT_DIR:-$(pwd)}/.swarm-yuan}/../scripts/trace-log.sh"
  [[ -f "$_sm_tl" ]] || _sm_tl="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/trace-log.sh"
  if [[ -f "$_sm_tl" ]]; then
    bash "$_sm_tl" --decision --type Taste \
      --suggestion "$target" --user-action approved \
      --rationale "guard 通过，阶段从 $current 流转到 $target" \
      --phase "$target" >&2 2>/dev/null || true
  fi
  echo "✓ 已转换到: $target"
}

next_phase() {
  [[ ! -f "$STATE_FILE" ]] && { echo "ERROR: 状态文件不存在"; exit 1; }
  local current; current=$(get_field phase)
  local cur_idx=-1
  for i in "${!PHASES[@]}"; do
    [[ "${PHASES[$i]}" == "$current" ]] && cur_idx=$i
  done
  local next_idx=$((cur_idx + 1))
  if [[ $next_idx -ge ${#PHASES[@]} ]]; then
    echo "已是最后阶段: $current"
  else
    echo "下一阶段: ${PHASES[$next_idx]}"
  fi
}

# WP-C2：auto 子命令——自动判定下一阶段并尝试流转（免去用户记阶段名）。
# 语义：读当前 phase → 找下一个 → 跑 guard → 通过则 transition，失败则提示缺什么产出物。
# 不跳过 guard（守卫仍检查产出物），只免去显式传阶段名。设计理念 1：连贯动作。
auto_phase() {
  [[ ! -f "$STATE_FILE" ]] && { echo "ERROR: 状态文件不存在，先 init"; exit 1; }
  local current; current=$(get_field phase)
  local cur_idx=-1
  for i in "${!PHASES[@]}"; do
    [[ "${PHASES[$i]}" == "$current" ]] && cur_idx=$i
  done
  local next_idx=$((cur_idx + 1))
  if [[ $next_idx -ge ${#PHASES[@]} ]]; then
    echo "已是最后阶段: ${current}（无可流转的下一阶段）"
    return 0
  fi
  local target="${PHASES[$next_idx]}"
  echo "=== auto: 当前 $current → 尝试流转到 $target ==="
  # guard 检查（guard_phase 内部 exit 1 时会中断；这里捕获其退出码不直接 exit）
  if guard_phase "$target"; then
    set_field phase "$target"
    # G1：auto 流转决策留痕
    _sm_tl="${STATE_DIR:-${PROJECT_DIR:-$(pwd)}/.swarm-yuan}/../scripts/trace-log.sh"
    [[ -f "$_sm_tl" ]] || _sm_tl="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/trace-log.sh"
    if [[ -f "$_sm_tl" ]]; then
      bash "$_sm_tl" --decision --type Taste \
        --suggestion "$target" --user-action approved \
        --rationale "auto: guard 通过，$current → $target" \
        --phase "$target" >&2 2>/dev/null || true
    fi
    echo "✓ auto 流转成功: $current → $target"
  else
    echo "✗ auto 流转失败: $target 准入未通过（上方 guard 输出说明了缺什么产出物）"
    echo "  提示: 补齐产出物后重新运行 auto，或手动 transition <phase> 指定其他阶段"
    return 1
  fi
}

show_status() {
  [[ ! -f "$STATE_FILE" ]] && { echo "ERROR: 状态文件不存在"; exit 1; }
  echo "=== 状态: $STATE_FILE ==="
  cat "$STATE_FILE"
}

# ===== G1 C 档：checkpoint/restore 阶段级可回滚 =====
# 与决策 13 断点续传（文件级幂等补缺）正交——checkpoint 是显式的阶段级一致性快照，
# restore 回滚到指定快照（恢复 phase + 截断 decisions.jsonl 到快照行数 + 报告关键文件哈希变化）。
# 快照存 $STATE_DIR/checkpoints/<ts>-<phase>.ckpt（bash 3.2 兼容：KEY=VALUE 行，无 declare -A）。

# 计算关键文件哈希（decisions.jsonl / trace.jsonl / state.yaml 行数 + cksum）
_ckpt_fingerprint() {
  local dec="$STATE_DIR/decisions.jsonl" tr="$STATE_DIR/trace.jsonl"
  local dec_lines=0 tr_lines=0 dec_sum="-" tr_sum="-"
  [[ -f "$dec" ]] && dec_lines=$(wc -l < "$dec" | tr -d ' ')
  [[ -f "$tr" ]] && tr_lines=$(wc -l < "$tr" | tr -d ' ')
  command -v cksum >/dev/null 2>&1 || { echo "nocksum"; return; }
  [[ -f "$dec" ]] && dec_sum=$(cksum < "$dec" | awk '{print $1}')
  [[ -f "$tr" ]] && tr_sum=$(cksum < "$tr" | awk '{print $1}')
  echo "decisions_lines=$dec_lines trace_lines=$tr_lines decisions_cksum=$dec_sum trace_cksum=$tr_sum"
}

checkpoint_phase() {
  [[ ! -f "$STATE_FILE" ]] && { echo "ERROR: 状态文件不存在，先 init"; exit 1; }
  local current; current=$(get_field phase)
  local cp_dir="$STATE_DIR/checkpoints"
  mkdir -p "$cp_dir" 2>/dev/null || { echo "ERROR: 无法创建 $cp_dir"; exit 1; }
  local ts; ts="$(date -u +%Y%m%dT%H%M%SZ)"
  local cp_file="$cp_dir/${ts}-${current}.ckpt"
  {
    echo "checkpoint_ts=$ts"
    echo "phase=$current"
    echo "created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    _ckpt_fingerprint
  } > "$cp_file"
  echo "✓ checkpoint 已创建: $cp_file"
  echo "  phase=$current · $(_ckpt_fingerprint)"
}

list_checkpoints() {
  local cp_dir="$STATE_DIR/checkpoints"
  if [[ ! -d "$cp_dir" ]] || [[ -z "$(ls -A "$cp_dir" 2>/dev/null)" ]]; then
    echo "（无 checkpoint；用 'state-machine.sh checkpoint' 创建阶段级快照）"
    return 0
  fi
  echo "=== checkpoints（${cp_dir}）==="
  local f
  for f in "$cp_dir"/*.ckpt; do
    [[ -f "$f" ]] || continue
    echo "--- $(basename "$f") ---"
    cat "$f"
  done
}

restore_phase() {
  local target_ckpt="${1:-}"
  local cp_dir="$STATE_DIR/checkpoints"
  # 未指定则用最新 checkpoint
  if [[ -z "$target_ckpt" ]]; then
    target_ckpt=$(ls -t "$cp_dir"/*.ckpt 2>/dev/null | head -1)
    [[ -z "$target_ckpt" ]] && { echo "ERROR: 无 checkpoint 可恢复（先 'checkpoint' 创建）"; exit 1; }
  fi
  [[ -f "$target_ckpt" ]] || target_ckpt="$cp_dir/$target_ckpt"
  [[ -f "$target_ckpt" ]] || { echo "ERROR: checkpoint 不存在: $target_ckpt"; exit 1; }
  # 读快照（KEY=VALUE；fingerprint 行是单行多空格串，取首个字段值）
  local cp_phase cp_dec_lines
  cp_phase=$(grep '^phase=' "$target_ckpt" | sed 's/^phase=//' | awk '{print $1}')
  cp_dec_lines=$(grep '^decisions_lines=' "$target_ckpt" | sed 's/^decisions_lines=//' | awk '{print $1}')
  echo "=== restore 到 checkpoint: $(basename "$target_ckpt") ==="
  # 恢复 phase（允许回退——restore 是显式回滚操作，与 transition 的"不可回退"约束正交）
  set_field phase "$cp_phase" >/dev/null
  echo "  phase 已回滚到: $cp_phase"
  # 截断 decisions.jsonl 到快照行数（回滚快照之后的决策）
  local dec="$STATE_DIR/decisions.jsonl"
  # 防御：cp_dec_lines 规范化（fingerprint 单行多值时取首字段，非数字降级为空）
  cp_dec_lines=$(printf '%s' "$cp_dec_lines" | awk '{print $1}')
  echo "$cp_dec_lines" | grep -qE '^[0-9]+$' || cp_dec_lines=""
  if [[ -f "$dec" && -n "$cp_dec_lines" && "$cp_dec_lines" -ge 0 ]]; then
    local cur_lines; cur_lines=$(wc -l < "$dec" | tr -d ' ')
    if [[ "$cur_lines" -gt "$cp_dec_lines" ]]; then
      local tmp; tmp="$(mktemp /tmp/swarmdec.XXXXXX)"
      head -n "$cp_dec_lines" "$dec" > "$tmp" && cat "$tmp" > "$dec" && rm -f "$tmp"
      echo "  decisions.jsonl 截断: ${cur_lines} → ${cp_dec_lines} 行（回滚 $((cur_lines-cp_dec_lines)) 条快照后决策）"
    else
      echo "  decisions.jsonl 无需截断（当前 $cur_lines 行 ≤ 快照 $cp_dec_lines 行）"
    fi
  fi
  echo "✓ restore 完成（仅回滚 phase 与决策记录；文件内容不回滚——文件级恢复走决策 13 断点续传/git）"
}

case "${1:-}" in
  init) init_state "${2:-}" ;;
  get) get_field "${2:-}" ;;
  set) set_field "${2:-}" "${3:-}" ;;
  transition) transition_phase "${2:-}" ;;
  guard) guard_phase "${2:-}" ;;
  next) next_phase ;;
  auto) auto_phase ;;
  status) show_status ;;
  checkpoint) checkpoint_phase ;;
  checkpoints|list-checkpoints) list_checkpoints ;;
  restore) restore_phase "${2:-}" ;;
  # update: 原地修订 plan + reconcile 关联 artifacts（openspec v1.6.0 /opsx:update 能力的脚本背书）
  # 不回退到 open 阶段，在当前 design 阶段内修订 plan
  update)
    echo "=== 原地修订 plan ==="
    current=$(get_field phase)
    if [[ "$current" != "design" && "$current" != "build" ]]; then
      echo "ERROR: update 仅在 design/build 阶段可用（当前 ${current}）"
      exit 1
    fi
    echo "  当前阶段: $current — 允许原地修订 plan + reconcile tasks"
    echo "  → 若装了 openspec: openspec update $(get_field change)"
    echo "  → 修订后须重跑 guard $current 确认门禁仍通过"
    ;;
  *) echo "Usage: state-machine.sh {init|get|set|transition|guard|next|status|update} [args]"; exit 1 ;;
esac
