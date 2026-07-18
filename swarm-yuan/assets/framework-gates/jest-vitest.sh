# ruleset: jest-vitest  requires_conf: VITEST_CONFIG_GLOBS VITEST_TEST_GLOBS
# gates: fw_jest_test_location(warn) fw_jest_mock_hoisted(warn) fw_jest_snapshot_governance(warn) fw_jest_coverage_threshold(fail) fw_jest_jest_fn_to_vi(warn) fw_jest_environment(warn) fw_jest_setup_files(warn) fw_jest_globals(warn) fw_jest_in_source(warn) fw_jest_bench(warn) fw_jest_typecheck(warn)
# harvested-from: P5 范例（2026-07-17），规律源自 Vitest 3.x/4.x 与 Jest 兼容官方文档
_fw_jest_vitest_check() {
  echo "  [jest-vitest] Vitest 3.x/4.x（Jest 兼容）框架规律"

  # ---------- 收集配置文件 ----------
  local cfgs cfgarr=()
  cfgs=$(_fw_resolve_globs ${VITEST_CONFIG_GLOBS[@]+"${VITEST_CONFIG_GLOBS[@]}"} 2>/dev/null | sort -u)
  while IFS= read -r ln; do
    [[ -n "$ln" ]] && cfgarr+=("$ln")
  done <<< "$cfgs"

  # ---------- 收集测试文件 ----------
  local tests testarr=()
  tests=$(_fw_resolve_globs ${VITEST_TEST_GLOBS[@]+"${VITEST_TEST_GLOBS[@]}"} 2>/dev/null | sort -u)
  while IFS= read -r ln; do
    [[ -n "$ln" ]] && testarr+=("$ln")
  done <<< "$tests"

  if [[ ${#cfgarr[@]} -eq 0 && ${#testarr[@]} -eq 0 ]]; then
    warn "jest-vitest: VITEST_CONFIG_GLOBS / VITEST_TEST_GLOBS 未配置或无文件可检"
    return
  fi

  # ====================================================================
  # fw_jest_test_location(warn)：测试文件须在 config include 内
  # ====================================================================
  # 简化：测试文件路径须含 test/spec/__tests__ 约定（与 include 一致）
  local loc_bad=""
  local f
  for f in "${testarr[@]+"${testarr[@]}"}"; do
    if ! printf '%s' "$f" | grep -qE '\.test\.|\.spec\.|__tests__'; then
      loc_bad="${loc_bad}${f}
"
    fi
  done
  # 配置 include 须含 test/spec/__tests__
  local include_ok=0
  for c in "${cfgarr[@]+"${cfgarr[@]}"}"; do
    if grep -qE "include:|include =" "$c" 2>/dev/null; then
      if grep -qE 'test|spec|__tests__' "$c" 2>/dev/null; then
        include_ok=1
      fi
    fi
  done
  if [[ -n "$loc_bad" ]]; then
    warn "fw_jest_test_location: 测试文件不在 test/spec/__tests__ 约定位置（须与 vitest.config include 一致，否则不被收集）:
${loc_bad}"
  elif [[ "$include_ok" -eq 0 && ${#cfgarr[@]} -gt 0 ]]; then
    warn "fw_jest_test_location: vitest.config 未明确 include test/spec 约定"
  else
    pass "fw_jest_test_location: 测试位置约定与 include 一致"
  fi

  # ====================================================================
  # fw_jest_mock_hoisted(warn)：跨变量引用 mock 须用 vi.hoisted
  # ====================================================================
  local hoist_bad=""
  for f in "${testarr[@]+"${testarr[@]}"}"; do
    # 检出 vi.mock( 第一个参数是模板字符串引用外部变量（非纯字符串字面量）
    local ln
    ln=$(grep -nE "vi\.mock\(" "$f" 2>/dev/null || true)
    [[ -z "$ln" ]] && continue
    # 同文件用 vi.mock 但无 vi.hoisted，且 mock factory 引用外部变量
    if ! grep -qE 'vi\.hoisted\(' "$f" 2>/dev/null; then
      # 简化：检出 vi.mock 含 factory 箭头函数（=>）即疑似需 hoisted
      if grep -qE "vi\.mock\([^)]*,[[:space:]]*\(\)[[:space:]]*=>" "$f" 2>/dev/null; then
        hoist_bad="${hoist_bad}${f}: vi.mock factory 须 vi.hoisted 提升变量
"
      fi
    fi
  done
  if [[ -n "$hoist_bad" ]]; then
    warn "fw_jest_mock_hoisted: vi.mock factory 引用变量未用 vi.hoisted 提升（Vitest mock 提升到顶部，外部变量未定义 ReferenceError）:
${hoist_bad}"
  else
    pass "fw_jest_mock_hoisted: 未检出需 vi.hoisted 的 mock（或已用）"
  fi

  # ====================================================================
  # fw_jest_snapshot_governance(warn)：快照须有治理标记（禁无脑 --update）
  # ====================================================================
  local snap_bad=""
  for f in "${testarr[@]+"${testarr[@]}"}"; do
    local ln
    ln=$(grep -nE 'toMatchSnapshot\(|toMatchInlineSnapshot\(' "$f" 2>/dev/null || true)
    [[ -n "$ln" ]] && snap_bad="${snap_bad}${f}:${ln}
"
  done
  if [[ -n "$snap_bad" ]]; then
    warn "fw_jest_snapshot_governance: 检出快照断言（须定期评审 + 禁无脑 -u 更新，CI 须 --ci 防止生成新快照）:
${snap_bad}"
  else
    pass "fw_jest_snapshot_governance: 未检出快照断言（或无快照风险）"
  fi

  # ====================================================================
  # fw_jest_coverage_threshold(fail)：须配覆盖率阈值门禁
  # ====================================================================
  local cov_ok=0
  for c in "${cfgarr[@]+"${cfgarr[@]}"}"; do
    if grep -qE 'thresholds|coverage\.thresholds|@vitest/coverage' "$c" 2>/dev/null; then
      cov_ok=1
    fi
  done
  if [[ ${#cfgarr[@]} -eq 0 ]]; then
    pass "fw_jest_coverage_threshold: 无配置文件，跳过"
  elif [[ "$cov_ok" -eq 1 ]]; then
    pass "fw_jest_coverage_threshold: 已配覆盖率阈值"
  else
    fail "fw_jest_coverage_threshold: 未配 coverage.thresholds（无阈值则覆盖率无门禁，回归无感知）"
  fi

  # ====================================================================
  # fw_jest_jest_fn_to_vi(warn)：禁残留 Jest API（jest.fn/jest.mock）
  # ====================================================================
  local jest_bad=""
  for f in "${testarr[@]+"${testarr[@]}"}"; do
    local ln
    ln=$(grep -nE '\bjest\.(fn|mock|spyOn|useFakeTimers|clearAllMocks)\(' "$f" 2>/dev/null || true)
    [[ -n "$ln" ]] && jest_bad="${jest_bad}${f}:${ln}
"
  done
  if [[ -n "$jest_bad" ]]; then
    warn "fw_jest_jest_fn_to_vi: 检出残留 Jest API（Vitest 须用 vi.fn/vi.mock，Jest API 仅兼容模式可用）:
${jest_bad}"
  else
    pass "fw_jest_jest_fn_to_vi: 未检出残留 Jest API（已用 vi.*）"
  fi

  # ====================================================================
  # fw_jest_environment(warn)：须显式配置 environment（jsdom/happy-dom/node）
  # ====================================================================
  local env_ok=0
  for c in "${cfgarr[@]+"${cfgarr[@]}"}"; do
    if grep -qE 'environment:' "$c" 2>/dev/null; then
      env_ok=1
    fi
  done
  if [[ ${#cfgarr[@]} -eq 0 ]]; then
    pass "fw_jest_environment: 无配置文件，跳过"
  elif [[ "$env_ok" -eq 1 ]]; then
    pass "fw_jest_environment: 已显式配置 environment"
  else
    warn "fw_jest_environment: 未配 environment（默认 node，DOM 测试须 jsdom/happy-dom，否则 document undefined）"
  fi

  # ====================================================================
  # fw_jest_setup_files(warn)：DOM 环境须配 setupFiles（@testing-library/jest-dom）
  # ====================================================================
  local setup_hit=0 dom_hit=0
  for c in "${cfgarr[@]+"${cfgarr[@]}"}"; do
    grep -qE 'setupFiles' "$c" 2>/dev/null && setup_hit=1
    grep -qE 'jsdom|happy-dom' "$c" 2>/dev/null && dom_hit=1
  done
  if [[ "$dom_hit" -eq 0 ]]; then
    pass "fw_jest_setup_files: 非 DOM 环境，跳过 setupFiles"
  elif [[ "$setup_hit" -eq 1 ]]; then
    pass "fw_jest_setup_files: DOM 环境已配 setupFiles"
  else
    warn "fw_jest_setup_files: DOM 环境未配 setupFiles（须引入 @testing-library/jest-dom 扩展 matcher）"
  fi

  # ====================================================================
  # fw_jest_globals(warn)：禁开 globals: true（显式 import 更安全）
  # ====================================================================
  local g_hit=0
  for c in "${cfgarr[@]+"${cfgarr[@]}"}"; do
    if grep -qE 'globals:[[:space:]]*true' "$c" 2>/dev/null; then
      g_hit=1
    fi
  done
  if [[ "$g_hit" -eq 1 ]]; then
    warn "fw_jest_globals: globals: true（全局 describe/it 污染全局作用域，推荐显式 import { describe, it } from 'vitest'）"
  else
    pass "fw_jest_globals: 未开 globals（或已显式 import）"
  fi

  # ====================================================================
  # fw_jest_in_source(warn)：in-source testing 须隔离 if(import.meta.vitest)
  # ====================================================================
  local insrc_bad=""
  for f in "${testarr[@]+"${testarr[@]}"}"; do
    : # 测试文件本身不算 in-source
  done
  # 检查配置是否声明了 in-source 约定但无对应隔离（简化：配置含 include src 即提示）
  for c in "${cfgarr[@]+"${cfgarr[@]}"}"; do
    if grep -qE "include:.*src/" "$c" 2>/dev/null; then
      insrc_bad="${c}: in-source testing 须用 if(import.meta.vitest) 隔离 + 生产构建剔除"
    fi
  done
  if [[ -n "$insrc_bad" ]]; then
    warn "fw_jest_in_source: 配置 include src/（in-source testing 须 if(import.meta.vitest) 隔离，否则生产打包含测试）:
${insrc_bad}"
  else
    pass "fw_jest_in_source: 无 in-source 配置（或已隔离）"
  fi

  # ====================================================================
  # fw_jest_bench(warn)：benchmark 须用 .bench.ts 约定
  # ====================================================================
  local bench_hit=0
  for c in "${cfgarr[@]+"${cfgarr[@]}"}"; do
    if grep -qE 'bench' "$c" 2>/dev/null; then
      bench_hit=1
    fi
  done
  if [[ "$bench_hit" -eq 1 ]]; then
    pass "fw_jest_bench: 已配置 benchmark"
  else
    warn "fw_jest_bench: 未配 benchmark（性能敏感模块须 .bench.ts 基准，防回归）"
  fi

  # ====================================================================
  # fw_jest_typecheck(warn)：类型测试须启用 typecheck
  # ====================================================================
  local tc_hit=0
  for c in "${cfgarr[@]+"${cfgarr[@]}"}"; do
    if grep -qE 'typecheck' "$c" 2>/dev/null; then
      tc_hit=1
    fi
  done
  if [[ "$tc_hit" -eq 1 ]]; then
    pass "fw_jest_typecheck: 已启用 typecheck"
  else
    warn "fw_jest_typecheck: 未启 typecheck（类型断言测试须 typecheck: { enabled: true }）"
  fi
}
