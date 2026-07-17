# ruleset: vitest  requires_conf: VITEST_CONFIG_FILE VITEST_FORBIDDEN_UPSTREAM_TEST
# gates: fw_vitest_include_custom(warn) fw_vitest_no_upstream_test(fail)
# harvested-from: ncwk-dev precheck.sh:2633-2654 (2026-07-17)
_fw_vitest_check() {
  echo "  [vitest] Vitest 3.2 框架规律"
  # 规律1: 测试须在 custom 下
  if [[ -n "$VITEST_CONFIG_FILE" && -f "$VITEST_CONFIG_FILE" ]]; then
    if grep -qE "custom" "$VITEST_CONFIG_FILE" 2>/dev/null; then
      pass "vitest: 配置 include custom 测试"
    else
      warn "vitest: 配置未明确 include custom"
    fi
  else
    warn "vitest: 配置文件不存在 ($VITEST_CONFIG_FILE)"
  fi
  # 规律2: 禁 upstream 测试
  # 说明：本仓库 upstream/ 全为只读第三方快照（element-web/hermes-agent/hermes-studio/research），
  # 其自带测试非 ncwk 违规；故 prune 掉 upstream/<子包>/，仅保留对 upstream/ 直属文件的检测，
  # 以捕获 ncwk 未来直接在 upstream/ 顶层新增测试的真实违规。
  if [[ -n "$VITEST_FORBIDDEN_UPSTREAM_TEST" ]]; then
    local hits; hits=$( { find . \( -path ./node_modules -o -path "./upstream/*" \) -prune -o -name "*.test.ts" -print 2>/dev/null | grep -E "$VITEST_FORBIDDEN_UPSTREAM_TEST" | head -5 || true; } )
    if [[ -z "$hits" ]]; then pass "vitest: 无 upstream 测试文件"
    else fail "vitest: 检出 upstream 测试文件（违反只读）: $hits"; fi
  fi
}

