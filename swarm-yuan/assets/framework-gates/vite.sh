# ruleset: vite  requires_conf: VITE_CONFIG_FILE VITE_INJECT_SCRIPT
# gates: fw_vite_alias_array_form(fail) fw_vite_alias_order(fail) fw_vite_inject_clean(fail)
# harvested-from: ncwk-dev precheck.sh:2602-2632 (2026-07-17)
_fw_vite_check() {
  echo "  [vite] Vite 8.0 框架规律"
  # 规律1: alias 须数组形式 + @/custom 在 @ 前
  if [[ -n "$VITE_CONFIG_FILE" && -f "$VITE_CONFIG_FILE" ]]; then
    if grep -qE "alias:\s*\[" "$VITE_CONFIG_FILE" 2>/dev/null; then
      pass "vite: alias 数组形式"
    else
      fail "vite: alias 须用数组形式（保证顺序）"
    fi
    # 检查 @/custom 在 @ 之前
    local custom_line at_line
    custom_line=$( { grep -nE "@/custom" "$VITE_CONFIG_FILE" 2>/dev/null || true; } | head -1 | cut -d: -f1)
    at_line=$( { grep -nE "find:\s*['\"]@['\"]" "$VITE_CONFIG_FILE" 2>/dev/null || true; } | head -1 | cut -d: -f1)
    if [[ -n "$custom_line" && -n "$at_line" && "$custom_line" -lt "$at_line" ]]; then
      pass "vite: @/custom 在 @ 之前 (行 $custom_line < $at_line)"
    else
      fail "vite: @/custom 须在 @ 之前 (custom=$custom_line at=$at_line)"
    fi
  else
    warn "vite: 配置文件未配置或不存在 ($VITE_CONFIG_FILE)"
  fi
  # 规律2: inject 幂等（inject.mjs 存在 --clean 分支）
  if [[ -n "$VITE_INJECT_SCRIPT" && -f "$VITE_INJECT_SCRIPT" ]]; then
    if grep -qE "\-\-clean" "$VITE_INJECT_SCRIPT" 2>/dev/null; then
      pass "vite: inject.mjs 含 --clean 回滚分支"
    else
      fail "vite: inject.mjs 须支持 --clean 回滚"
    fi
  fi
}


