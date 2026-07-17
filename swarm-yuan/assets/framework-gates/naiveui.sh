# ruleset: naiveui  requires_conf: NAIVEUI_FILE_GLOBS NAIVEUI_NAMED_IMPORT_REQUIRED NAIVEUI_FORBIDDEN_GLOBAL_REGISTER NAIVEUI_FORBIDDEN_DUAL_UI
# gates: fw_naiveui_named_import(warn) fw_naiveui_no_global_register(fail) fw_naiveui_no_dual_ui(fail)
# harvested-from: ncwk-dev precheck.sh:2510-2535 (2026-07-17)
_fw_naiveui_check() {
  echo "  [naiveui] NaiveUI 2.44 框架规律"
  local files fa=()
  files=$(_fw_resolve_globs "${NAIVEUI_FILE_GLOBS[@]}" | sort -u)
  [[ -z "$files" ]] && { warn "naiveui: 无文件可检"; return; }
  while IFS= read -r ln; do fa+=("$ln"); done <<< "$files"
  # 规律1: 须具名导入
  if [[ "$NAIVEUI_NAMED_IMPORT_REQUIRED" == "1" ]]; then
    local named; named=$(_fw_grep_count "from 'naive-ui'" "${fa[@]}")
    if [[ "$named" -gt 0 ]]; then pass "naiveui: 具名导入 ($named 文件)"
    else warn "naiveui: 未检出具名导入（或未使用 NaiveUI）"; fi
  fi
  # 规律2: 禁全局注册
  if [[ -n "$NAIVEUI_FORBIDDEN_GLOBAL_REGISTER" ]]; then
    local hits; hits=$(grep -rnE "$NAIVEUI_FORBIDDEN_GLOBAL_REGISTER" "${fa[@]}" 2>/dev/null || true)
    if [[ -z "$hits" ]]; then pass "naiveui: 无全局注册组件"
    else fail "naiveui: 检出全局注册组件（须具名导入）: $hits"; fi
  fi
  # 规律3: 禁第二套 UI 库
  if [[ -n "$NAIVEUI_FORBIDDEN_DUAL_UI" ]]; then
    local hits; hits=$(grep -rnE "$NAIVEUI_FORBIDDEN_DUAL_UI" overlay/package.json 2>/dev/null || true)
    if [[ -z "$hits" ]]; then pass "naiveui: 无第二套 UI 库"
    else fail "naiveui: 检出第二套 UI 库: $hits"; fi
  fi
}


