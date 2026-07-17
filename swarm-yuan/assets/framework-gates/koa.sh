# ruleset: koa  requires_conf: KOA_FILE_GLOBS KOA_ROUTER_FACTORY_REQUIRED KOA_FORBIDDEN_GLOBAL_APPUSE KOA_INPUT_GUARD
# gates: fw_koa_router_factory(warn) fw_koa_no_bare_appuse(warn) fw_koa_input_guard(warn)
# harvested-from: ncwk-dev precheck.sh:2556-2581 (2026-07-17)
_fw_koa_check() {
  echo "  [koa] Koa 2.15 框架规律"
  local files fa=()
  files=$(_fw_resolve_globs "${KOA_FILE_GLOBS[@]+"${KOA_FILE_GLOBS[@]}"}" | sort -u)
  [[ -z "$files" ]] && { warn "koa: 无文件可检"; return; }
  while IFS= read -r ln; do fa+=("$ln"); done <<< "$files"
  # 规律1: 须 factory 注入
  if [[ "$KOA_ROUTER_FACTORY_REQUIRED" == "1" ]]; then
    local factory; factory=$(_fw_grep_count "create.*Router[[:space:]]*\(" "${fa[@]}")
    if [[ "$factory" -gt 0 ]]; then pass "koa: router factory 注入 ($factory 处)"
    else warn "koa: 未检出 router factory"; fi
  fi
  # 规律2: 禁裸 app.use(router)
  if [[ -n "$KOA_FORBIDDEN_GLOBAL_APPUSE" ]]; then
    local hits; hits=$(grep -rnE "$KOA_FORBIDDEN_GLOBAL_APPUSE" "${fa[@]}" 2>/dev/null || true)
    if [[ -z "$hits" ]]; then pass "koa: 无裸 app.use(router)"
    else warn "koa: 检出裸 app.use(router)（建议 factory）: $hits"; fi
  fi
  # 规律3: 须输入校验
  if [[ -n "$KOA_INPUT_GUARD" ]]; then
    local hits; hits=$(_fw_grep_count "$KOA_INPUT_GUARD" "${fa[@]}")
    if [[ "$hits" -gt 0 ]]; then pass "koa: 输入校验存在 ($hits 处)"
    else warn "koa: 未检出输入校验（url-guard/validate）"; fi
  fi
}


