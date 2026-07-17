# ruleset: vue  requires_conf: VUE_FILE_GLOBS VUE_REQUIRE_SCRIPT_SETUP VUE_FORBIDDEN_OPTIONS_API VUE_VHTML_SANITIZE_REQUIRED VUE_VHTML_SANITIZE_PATTERNS VUE_VFOR_FORBIDDEN_INDEX_KEY VUE_REACTIVE_WARN_THRESHOLD
# gates: fw_vue_script_setup(fail) fw_vue_no_options_api(fail) fw_vue_vhtml_sanitize(fail) fw_vue_vfor_index_key(warn) fw_vue_reactivity_threshold(warn)
# harvested-from: ncwk-dev precheck.sh:2454-2509 (2026-07-17)
_fw_vue_check() {
  echo "  [vue] Vue 3.5 框架规律"
  local files
  files=$(_fw_resolve_globs "${VUE_FILE_GLOBS[@]}" | sort -u)
  [[ -z "$files" ]] && { warn "vue: 无 .vue 文件可检"; return; }
  local fa=()
  while IFS= read -r ln; do fa+=("$ln"); done <<< "$files"
  # 规律1: <script setup> 强制
  if [[ "$VUE_REQUIRE_SCRIPT_SETUP" == "1" ]]; then
    local total setup
    total=$(_fw_grep_count "<script" "${fa[@]}")
    setup=$(_fw_grep_count "<script setup" "${fa[@]}")
    if [[ "$total" -gt 0 && "$setup" -eq "$total" ]]; then
      pass "vue: 全部 SFC 用 <script setup> ($setup/$total)"
    else
      fail "vue: 存在非 <script setup> 的 SFC (setup=$setup total=$total)"
    fi
  fi
  # 规律2: 禁 Options API
  if [[ -n "$VUE_FORBIDDEN_OPTIONS_API" ]]; then
    local hits; hits=$(grep -rnE "$VUE_FORBIDDEN_OPTIONS_API" "${fa[@]}" 2>/dev/null || true)
    if [[ -z "$hits" ]]; then pass "vue: 无 Options API"
    else fail "vue: 检出 Options API: $hits"; fi
  fi
  # 规律3: v-html 须配套 sanitize（同文件级）
  if [[ "$VUE_VHTML_SANITIZE_REQUIRED" == "1" ]]; then
    local vhtml_files="" bad=0 offenders=""
    while IFS= read -r f; do vhtml_files="$vhtml_files $f"; done < <(grep -rlE "v-html" "${fa[@]}" 2>/dev/null || true)
    if [[ -z "${vhtml_files// }" ]]; then
      pass "vue: 无 v-html 使用"
    else
      for f in $vhtml_files; do
        if ! grep -qE "$VUE_VHTML_SANITIZE_PATTERNS" "$f" 2>/dev/null; then
          offenders="$offenders $f"; bad=$((bad+1))
        fi
      done
      if [[ "$bad" -eq 0 ]]; then
        pass "vue: v-html 均配套 sanitize ($(echo $vhtml_files | wc -w | xargs) 处)"
      else
        fail "vue: v-html 未配套 sanitize: $offenders"
      fi
    fi
  fi
  # 规律4: v-for 禁 index 作 key（warn 级）
  if [[ -n "$VUE_VFOR_FORBIDDEN_INDEX_KEY" ]]; then
    local hits; hits=$(grep -rnE "$VUE_VFOR_FORBIDDEN_INDEX_KEY" "${fa[@]}" 2>/dev/null || true)
    if [[ -z "$hits" ]]; then pass "vue: v-for 无 index 作 key"
    else warn "vue: v-for 用 index 作 key（稳定数组可接受）: $hits"; fi
  fi
  # 规律5: reactive 用量预警
  local rc; rc=$( { grep -rhoE "\breactive\b" "${fa[@]}" 2>/dev/null || true; } | wc -l | xargs)
  if [[ -n "$VUE_REACTIVE_WARN_THRESHOLD" && "$rc" -gt "$VUE_REACTIVE_WARN_THRESHOLD" ]]; then
    warn "vue: reactive 用量 $rc 处（阈值 $VUE_REACTIVE_WARN_THRESHOLD），建议优先 ref/computed"
  fi
}


