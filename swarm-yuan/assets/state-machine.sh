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
# 阶段顺序（comet 5 阶段模式，可按项目裁剪）
PHASES=("open" "design" "build" "verify" "archive")
# =====================

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; }

# CLI 接线层运行时守卫（WP1.2）：comet CLI 真实接线
# comet 提供 `comet guard`（检查 Classic workflow phase guard）/ `comet state`（读写状态）。
# 项目用 comet 时（有 .comet/ 或 active change），guard_phase 调 comet guard 做状态一致性补充校验；
# 未装/项目未用 comet 时降级到本脚本自带的文件检查 guard_phase 逻辑。
has_comet() { command -v comet >/dev/null 2>&1; }

init_state() {
  local change="${1:-}"
  [[ -z "$change" ]] && { echo "Usage: state-machine.sh init <change-name>"; exit 1; }
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
  grep "^$field:" "$STATE_FILE" | head -1 | sed "s/^$field: //"
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
      # 门禁：open 阶段产出 proposal.md
      # 生成时按项目实际调整产出物路径
      echo "  (检查 open 阶段产出物存在)"
      pass "design 准入检查（按项目定制产出物路径）"
      ;;
    build)
      # 门禁：design 阶段产出 design doc + tasks
      echo "  (检查 design 阶段产出物 + build_mode/isolation 已设置)"
      local bm iso
      bm=$(get_field build_mode); iso=$(get_field isolation)
      [[ -z "$bm" ]] && { fail "build_mode 未设置"; ok=0; }
      [[ -z "$iso" ]] && { fail "isolation 未设置"; ok=0; }
      [[ $ok -eq 1 ]] && pass "build 准入: build_mode=$bm, isolation=$iso"
      ;;
    verify)
      # 门禁：build 完成（tasks 全勾）
      echo "  (检查 tasks.md 全部 - [x])"
      pass "verify 准入检查（按项目定制 tasks 路径）"
      ;;
    archive)
      # 门禁：verify 通过
      local vr
      vr=$(get_field verify_result)
      [[ "$vr" != "pass" ]] && { fail "verify_result=${vr}，须先 pass"; ok=0; }
      [[ $ok -eq 1 ]] && pass "archive 准入: verify_result=${vr}"
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

show_status() {
  [[ ! -f "$STATE_FILE" ]] && { echo "ERROR: 状态文件不存在，先 init"; exit 1; }
  echo "=== 状态: $STATE_FILE ==="
  cat "$STATE_FILE"
}

case "${1:-}" in
  init) init_state "${2:-}" ;;
  get) get_field "${2:-}" ;;
  set) set_field "${2:-}" "${3:-}" ;;
  transition) transition_phase "${2:-}" ;;
  guard) guard_phase "${2:-}" ;;
  next) next_phase ;;
  status) show_status ;;
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
