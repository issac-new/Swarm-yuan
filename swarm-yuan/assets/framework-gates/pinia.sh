# ruleset: pinia  requires_conf: PINIA_FILE_GLOBS PINIA_DEFINESTORE_REQUIRED PINIA_AGGREGATE_STORE
# gates: fw_pinia_definestore(warn) fw_pinia_aggregate_store(warn)
# harvested-from: ncwk-dev precheck.sh:2536-2555 (2026-07-17)
_fw_pinia_check() {
  echo "  [pinia] Pinia 3.0 框架规律"
  local files fa=()
  files=$(_fw_resolve_globs "${PINIA_FILE_GLOBS[@]+"${PINIA_FILE_GLOBS[@]}"}" | sort -u)
  [[ -z "$files" ]] && { warn "pinia: 无文件可检"; return; }
  while IFS= read -r ln; do fa+=("$ln"); done <<< "$files"
  # 规律1: 须 defineStore
  if [[ "$PINIA_DEFINESTORE_REQUIRED" == "1" ]]; then
    local cnt; cnt=$(_fw_grep_count "defineStore" "${fa[@]}")
    if [[ "$cnt" -gt 0 ]]; then pass "pinia: defineStore 定义 ($cnt 文件)"
    else warn "pinia: 未检出 defineStore（或未用 Pinia）"; fi
  fi
  # 规律2: 聚合层 store 须只读消费（存在性检查）
  if [[ -n "$PINIA_AGGREGATE_STORE" && -f "$PINIA_AGGREGATE_STORE" ]]; then
    pass "pinia: 聚合层 store 存在 ($PINIA_AGGREGATE_STORE)"
  else
    warn "pinia: 聚合层 store 未配置或不存在"
  fi
}


