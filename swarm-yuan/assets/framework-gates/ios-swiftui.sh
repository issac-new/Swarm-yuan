# ruleset: ios-swiftui  requires_conf: IOS_SWIFTUI_GLOBS
# gates: fw_ios_webview_js(fail) fw_ios_userdefaults_secret(fail) fw_ios_print(warn) fw_ios_ats(fail) fw_ios_keychain(warn) fw_ios_privacy_manifest(warn) fw_ios_state_object(warn) fw_ios_lazy_list(warn) fw_ios_swiftlint(warn) fw_ios_async(warn)
_fw_ios_swiftui_check() {
  echo "  [ios-swiftui] iOS Swift/SwiftUI 框架规律"
  local srcs srcarr=()
  srcs=$(_fw_resolve_globs ${IOS_SWIFTUI_GLOBS[@]+"${IOS_SWIFTUI_GLOBS[@]}"} 2>/dev/null | sort -u)
  while IFS= read -r ln; do [[ -n "$ln" ]] && srcarr+=("$ln"); done <<< "$srcs"
  [[ ${#srcarr[@]} -eq 0 ]] && { warn "ios-swiftui: IOS_SWIFTUI_GLOBS 未配置或无文件可检"; return; }

  # fw_ios_webview_js(fail)
  local bad=""
  for f in "${srcarr[@]}"; do
    local code; code=$(_fw_strip_comments_c "$f" 2>/dev/null || true)
    if echo "$code" | grep -qE 'WKWebView' && ! echo "$code" | grep -qE 'javaScriptEnabled\s*=\s*false'; then
      bad="${bad}${f}: WKWebView 未禁用 JavaScript\n"
    fi
  done
  _fw_report fail fw_ios_webview_js "$bad" "WKWebView 未禁用 JS（CWE-79）" "未检出 WKWebView JS 风险"

  # fw_ios_userdefaults_secret(fail)
  bad=""
  for f in "${srcarr[@]}"; do
    local code; code=$(_fw_strip_comments_c "$f" 2>/dev/null || true)
    if echo "$code" | grep -iE 'UserDefaults.*set.*\(.*(token|password|secret|apikey|credential)' 2>/dev/null | grep -q . && ! echo "$code" | grep -qE 'Keychain'; then
      bad="${bad}${f}: UserDefaults 存敏感数据（无 Keychain）\n"
    fi
  done
  _fw_report fail fw_ios_userdefaults_secret "$bad" "UserDefaults 存敏感数据（CWE-312）" "未检出 UserDefaults 敏感存储"

  # fw_ios_print(warn)
  bad=""
  for f in "${srcarr[@]}"; do
    local hits; hits=$(_fw_strip_comments_c "$f" 2>/dev/null | grep -nE 'print\(' || true)
    [[ -n "$hits" ]] && bad="${bad}${f}:\n${hits}\n"
  done
  _fw_report warn fw_ios_print "$bad" "检出 print()（CWE-209）" "未检出 print()"

  # fw_ios_ats(fail)
  bad=""
  for f in "${srcarr[@]}"; do
    if echo "$f" | grep -qE 'Info\.plist$' && grep -qE 'NSAllowsArbitraryLoads' "$f" 2>/dev/null | grep -q true; then
      bad="${bad}${f}: NSAllowsArbitraryLoads=true\n"
    fi
  done
  _fw_report fail fw_ios_ats "$bad" "ATS 禁用明文 HTTP（CWE-319）" "ATS 配置正确或无 Info.plist"

  # fw_ios_keychain(warn)
  bad=""
  for f in "${srcarr[@]}"; do
    local code; code=$(_fw_strip_comments_c "$f" 2>/dev/null || true)
    if echo "$code" | grep -iE 'password|token|secret|credential' 2>/dev/null | grep -q . && ! echo "$code" | grep -qE 'Keychain|kSecClass'; then
      bad="${bad}${f}: 敏感操作无 Keychain\n"
    fi
  done
  _fw_report warn fw_ios_keychain "$bad" "敏感操作无 Keychain（CWE-312）" "Keychain 使用正确"

  # fw_ios_privacy_manifest(warn)
  local pm_found=0
  for f in "${srcarr[@]}"; do
    echo "$f" | grep -qE 'PrivacyInfo\.xcprivacy$' && pm_found=1
  done
  [[ $pm_found -eq 0 ]] && warn "fw_ios_privacy_manifest: 无 PrivacyInfo.xcprivacy 文件" || pass "fw_ios_privacy_manifest: 隐私清单存在"

  # fw_ios_state_object(warn)
  bad=""
  for f in "${srcarr[@]}"; do
    local code; code=$(_fw_strip_comments_c "$f" 2>/dev/null || true)
    local sc; sc=$(echo "$code" | grep -cE '@State\b' || true)
    if [[ "$sc" -gt 3 ]] && ! echo "$code" | grep -qE '@StateObject|@ObservedObject'; then
      bad="${bad}${f}: 多 @State 无 @StateObject\n"
    fi
  done
  _fw_report warn fw_ios_state_object "$bad" "多 @State 无 @StateObject" "状态管理正确"

  # fw_ios_lazy_list(warn)
  bad=""
  for f in "${srcarr[@]}"; do
    local code; code=$(_fw_strip_comments_c "$f" 2>/dev/null || true)
    if echo "$code" | grep -qE 'VStack' && echo "$code" | grep -qE 'ForEach' && ! echo "$code" | grep -qE 'LazyVStack|LazyHStack'; then
      bad="${bad}${f}: VStack+ForEach 无 LazyVStack\n"
    fi
  done
  _fw_report warn fw_ios_lazy_list "$bad" "VStack+ForEach 无 LazyVStack" "长列表使用 LazyVStack"

  # fw_ios_swiftlint(warn)
  local sl_found=0
  for f in "${srcarr[@]}"; do
    echo "$f" | grep -qE '\.swiftlint\.yml$' && sl_found=1
  done
  [[ $sl_found -eq 0 ]] && warn "fw_ios_swiftlint: 无 .swiftlint.yml" || pass "fw_ios_swiftlint: SwiftLint 配置存在"

  # fw_ios_async(warn)
  bad=""
  for f in "${srcarr[@]}"; do
    local code; code=$(_fw_strip_comments_c "$f" 2>/dev/null || true)
    if echo "$code" | grep -qE 'URLSession.*completionHandler' && ! echo "$code" | grep -qE 'async'; then
      bad="${bad}${f}: URLSession completionHandler 无 async\n"
    fi
  done
  _fw_report warn fw_ios_async "$bad" "URLSession completionHandler 无 async" "async/await 使用正确"
}
