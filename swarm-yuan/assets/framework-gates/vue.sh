# ruleset: vue  requires_conf: VUE_FILE_GLOBS VUE_REQUIRE_SCRIPT_SETUP VUE_FORBIDDEN_OPTIONS_API VUE_VHTML_SANITIZE_REQUIRED VUE_VHTML_SANITIZE_PATTERNS VUE_VFOR_FORBIDDEN_INDEX_KEY VUE_REACTIVE_WARN_THRESHOLD VUE_PINIA_FILE_GLOBS VUE_PINIA_DEFINESTORE_REQUIRED VUE_PINIA_AGGREGATE_STORE
# gates: fw_vue_script_setup(fail) fw_vue_no_options_api(fail) fw_vue_vhtml_sanitize(fail) fw_vue_vfor_index_key(warn) fw_vue_reactivity_threshold(warn) fw_vue_pinia_definestore(warn) fw_vue_pinia_aggregate(warn)
# harvested-from: ncwk-dev precheck.sh:2454-2509 (2026-07-17)；pinia 合并自 ncwk-dev precheck.sh:2536-2555 (2026-07-17)
_fw_vue_check() {
  echo "  [vue] Vue 3.5 框架规律"
  local files
  files=$(_fw_resolve_globs "${VUE_FILE_GLOBS[@]+"${VUE_FILE_GLOBS[@]}"}" | sort -u)
  [[ -z "$files" ]] && { warn "vue: 无 .vue 文件可检"; return; }
  local fa=()
  while IFS= read -r ln; do fa+=("$ln"); done <<< "$files"
  # 规律1: <script setup> 强制
  if [[ "$VUE_REQUIRE_SCRIPT_SETUP" == "1" ]]; then
    local total setup
    total=$(_fw_grep_count "<script" "${fa[@]}")
    setup=$(_fw_grep_count "<script setup" "${fa[@]}")
    if [[ "$total" -gt 0 && "$setup" -eq "$total" ]]; then
      pass "fw_vue_script_setup: 全部 SFC 用 <script setup> ($setup/$total)"
    else
      fail "fw_vue_script_setup: 存在非 <script setup> 的 SFC (setup=$setup total=$total)"
    fi
  fi
  # 规律2: 禁 Options API
  if [[ -n "$VUE_FORBIDDEN_OPTIONS_API" ]]; then
    local hits; hits=$(grep -rnE "$VUE_FORBIDDEN_OPTIONS_API" "${fa[@]}" 2>/dev/null || true)
    if [[ -z "$hits" ]]; then pass "fw_vue_no_options_api: 无 Options API"
    else fail "fw_vue_no_options_api: 检出 Options API: $hits"; fi
  fi
  # 规律3: v-html 须配套 sanitize（同文件级）
  if [[ "$VUE_VHTML_SANITIZE_REQUIRED" == "1" ]]; then
    local vhtml_files="" bad=0 offenders=""
    while IFS= read -r f; do vhtml_files="$vhtml_files $f"; done < <(grep -rlE "v-html" "${fa[@]}" 2>/dev/null || true)
    if [[ -z "${vhtml_files// }" ]]; then
      pass "fw_vue_vhtml_sanitize: 无 v-html 使用"
    else
      for f in $vhtml_files; do
        if ! grep -qE "$VUE_VHTML_SANITIZE_PATTERNS" "$f" 2>/dev/null; then
          offenders="$offenders $f"; bad=$((bad+1))
        fi
      done
      if [[ "$bad" -eq 0 ]]; then
        pass "fw_vue_vhtml_sanitize: v-html 均配套 sanitize ($(echo $vhtml_files | wc -w | xargs) 处)"
      else
        fail "fw_vue_vhtml_sanitize: v-html 未配套 sanitize: $offenders"
      fi
    fi
  fi
  # 规律4: v-for 禁 index 作 key（warn 级）
  if [[ -n "$VUE_VFOR_FORBIDDEN_INDEX_KEY" ]]; then
    local hits; hits=$(grep -rnE "$VUE_VFOR_FORBIDDEN_INDEX_KEY" "${fa[@]}" 2>/dev/null || true)
    if [[ -z "$hits" ]]; then pass "fw_vue_vfor_index_key: v-for 无 index 作 key"
    else warn "fw_vue_vfor_index_key: v-for 用 index 作 key（稳定数组可接受）: $hits"; fi
  fi
  # 规律5: reactive 用量预警
  local rc; rc=$( { grep -rhoE "\breactive\b" "${fa[@]}" 2>/dev/null || true; } | wc -l | xargs)
  if [[ -n "$VUE_REACTIVE_WARN_THRESHOLD" && "$rc" -gt "$VUE_REACTIVE_WARN_THRESHOLD" ]]; then
    warn "fw_vue_reactivity_threshold: reactive 用量 $rc 处（阈值 ${VUE_REACTIVE_WARN_THRESHOLD}），建议优先 ref/computed"
  fi

  # ====================================================================
  # fw_vue_pinia_definestore(warn)：Pinia store 须用 defineStore 定义
  # （合并自原 pinia.sh，门禁 id 由 fw_pinia_definestore 改名以遵循 fw_vue_<rule> 命名规范）
  # ====================================================================
  if [[ "${VUE_PINIA_DEFINESTORE_REQUIRED:-}" == "1" ]]; then
    local pinia_files pfa=()
    pinia_files=$(_fw_resolve_globs ${VUE_PINIA_FILE_GLOBS[@]+"${VUE_PINIA_FILE_GLOBS[@]}"} 2>/dev/null | sort -u)
    if [[ -z "$pinia_files" ]]; then
      warn "fw_vue_pinia_definestore: VUE_PINIA_FILE_GLOBS 未配置或无文件可检"
    else
      while IFS= read -r ln; do [[ -n "$ln" ]] && pfa+=("$ln"); done <<< "$pinia_files"
      local cnt; cnt=$(_fw_grep_count "defineStore" "${pfa[@]}")
      if [[ "$cnt" -gt 0 ]]; then
        pass "fw_vue_pinia_definestore: defineStore 定义（$cnt 文件）"
      else
        warn "fw_vue_pinia_definestore: 未检出 defineStore（疑似未用 Pinia 或漏定义）"
      fi
    fi
  fi

  # ====================================================================
  # fw_vue_pinia_aggregate(warn)：聚合层 store 须存在
  # （合并自原 pinia.sh，门禁 id 由 fw_pinia_aggregate_store 改名）
  # ====================================================================
  if [[ -n "${VUE_PINIA_AGGREGATE_STORE:-}" ]]; then
    if [[ -f "$VUE_PINIA_AGGREGATE_STORE" ]]; then
      pass "fw_vue_pinia_aggregate: 聚合层 store 存在（${VUE_PINIA_AGGREGATE_STORE}）"
    else
      warn "fw_vue_pinia_aggregate: 聚合层 store 未配置或不存在（VUE_PINIA_AGGREGATE_STORE=${VUE_PINIA_AGGREGATE_STORE}）"
    fi
  fi
}


