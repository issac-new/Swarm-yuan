# ruleset: vite  requires_conf: VITE_CONFIG_FILE VITE_INJECT_SCRIPT
# gates: fw_vite_alias_array_form(fail) fw_vite_alias_order(fail) fw_vite_inject_clean(fail) fw_vite_env_prefix(warn) fw_vite_manual_chunks(warn) fw_vite_build_target(warn) fw_vite_sourcemap_prod(warn) fw_vite_base_path(warn) fw_vite_optimize_deps(warn) fw_vite_proxy_target(warn) fw_vite_esbuild_minify(warn)
# harvested-from: ncwk-dev precheck.sh:2602-2632 (2026-07-17) + P5 扩展（2026-07-17），规律源自 Vite 8.x / 7.x 官方文档
_fw_vite_check() {
  echo "  [vite] Vite 8.x / 7.x 框架规律"
  local cfg="$VITE_CONFIG_FILE"

  if [[ -z "$cfg" || ! -f "$cfg" ]]; then
    warn "vite: VITE_CONFIG_FILE 未配置或不存在 ($cfg)"
    return
  fi

  # ====================================================================
  # fw_vite_alias_array_form(fail)：alias 须数组形式
  # ====================================================================
  if grep -qE "alias:[[:space:]]*\[" "$cfg" 2>/dev/null; then
    pass "fw_vite_alias_array_form: alias 数组形式"
  else
    fail "fw_vite_alias_array_form: alias 须用数组形式（保证顺序）"
  fi

  # ====================================================================
  # fw_vite_alias_order(fail)：@/custom 须在 @ 之前
  # ====================================================================
  local custom_line at_line
  custom_line=$( { grep -nE "@/custom" "$cfg" 2>/dev/null || true; } | head -1 | cut -d: -f1)
  at_line=$( { grep -nE "find:[[:space:]]*['\"]@['\"]" "$cfg" 2>/dev/null || true; } | head -1 | cut -d: -f1)
  if [[ -n "$custom_line" && -n "$at_line" && "$custom_line" -lt "$at_line" ]]; then
    pass "fw_vite_alias_order: @/custom 在 @ 之前 (行 $custom_line < $at_line)"
  else
    fail "fw_vite_alias_order: @/custom 须在 @ 之前 (custom=$custom_line at=$at_line)"
  fi

  # ====================================================================
  # fw_vite_inject_clean(fail)：inject.mjs 须支持 --clean 回滚
  # ====================================================================
  if [[ -n "$VITE_INJECT_SCRIPT" && -f "$VITE_INJECT_SCRIPT" ]]; then
    if grep -qE "\-\-clean" "$VITE_INJECT_SCRIPT" 2>/dev/null; then
      pass "fw_vite_inject_clean: inject.mjs 含 --clean 回滚分支"
    else
      fail "fw_vite_inject_clean: inject.mjs 须支持 --clean 回滚"
    fi
  else
    pass "fw_vite_inject_clean: 无 inject 脚本，跳过"
  fi

  # ====================================================================
  # fw_vite_env_prefix(warn)：环境变量须 VITE_ 前缀，防泄漏敏感配置
  # ====================================================================
  # 检出 process.env / import.meta.env 引用非 VITE_ 前缀变量（疑似泄漏后端密钥到客户端）
  local env_bad=""
  local ln
  ln=$(grep -nE "(process|import\.meta)\.env\.[A-Z]" "$cfg" 2>/dev/null \
     | grep -vE 'VITE_|MODE|BASE_URL|PROD|DEV|SSR' || true)
  [[ -n "$ln" ]] && env_bad="$ln"
  # 同时检查 .env 文件含敏感 key（password/secret/key/token）非 VITE_ 前缀
  local envdir
  envdir=$(dirname "$cfg")
  local envfile
  for envfile in "$envdir"/.env "$envdir"/.env.local "$envdir"/.env.production; do
    [[ -f "$envfile" ]] || continue
    local fln
    fln=$(grep -nE '^(PASSWORD|SECRET|API_KEY|TOKEN|PRIVATE_KEY)=' "$envfile" 2>/dev/null || true)
    [[ -n "$fln" ]] && env_bad="${env_bad}${envfile}:${fln}
"
  done
  _fw_report warn fw_vite_env_prefix "$env_bad" "检出非 VITE_ 前缀的敏感环境变量引用（Vite 仅注入 VITE_ 前缀到客户端，敏感配置应放后端）" "未检出敏感环境变量泄漏"

  # ====================================================================
  # fw_vite_manual_chunks(warn)：构建须配 manualChunks 拆分
  # ====================================================================
  if grep -qE 'manualChunks|rollupOptions' "$cfg" 2>/dev/null; then
    pass "fw_vite_manual_chunks: 已配 manualChunks/rollupOptions 分包"
  else
    warn "fw_vite_manual_chunks: 未配 manualChunks（单 chunk 过大，首屏加载慢，须按路由/依赖拆分）"
  fi

  # ====================================================================
  # fw_vite_build_target(warn)：build.target 须显式配置浏览器兼容
  # ====================================================================
  if grep -qE 'target:|target =' "$cfg" 2>/dev/null; then
    pass "fw_vite_build_target: 已显式配置 build.target"
  else
    warn "fw_vite_build_target: 未配 build.target（默认 'baseline-widely-available'，须按兼容性需求显式声明）"
  fi

  # ====================================================================
  # fw_vite_sourcemap_prod(warn)：生产构建须关闭 sourcemap
  # ====================================================================
  if grep -qE "sourcemap:[[:space:]]*true|sourcemap:[[:space:]]*'hidden'" "$cfg" 2>/dev/null; then
    # 检查是否在 build 块内且无环境判断
    if ! grep -qE "sourcemap:[[:space:]]*(mode|import\.meta|process\.env|isProd|prod)" "$cfg" 2>/dev/null; then
      warn "fw_vite_sourcemap_prod: sourcemap 开启但无生产环境判断（生产 sourcemap 泄露源码 CWE-540）"
    else
      pass "fw_vite_sourcemap_prod: sourcemap 配置含环境判断"
    fi
  else
    pass "fw_vite_sourcemap_prod: 未开启 sourcemap（或默认关闭）"
  fi

  # ====================================================================
  # fw_vite_base_path(warn)：base 路径须显式配置（部署子路径）
  # ====================================================================
  if grep -qE "^[[:space:]]*base:|base[[:space:]]*=" "$cfg" 2>/dev/null; then
    pass "fw_vite_base_path: 已显式配置 base 路径"
  else
    warn "fw_vite_base_path: 未配 base（默认 '/'，部署到子路径时资源 404）"
  fi

  # ====================================================================
  # fw_vite_optimize_deps(warn)：预构建缓存须显式管理
  # ====================================================================
  if grep -qE 'optimizeDeps|optimize-deps' "$cfg" 2>/dev/null; then
    pass "fw_vite_optimize_deps: 已配 optimizeDeps 预构建"
  else
    warn "fw_vite_optimize_deps: 未配 optimizeDeps（CJS 依赖须 include 预构建，否则 dev 启动重复全量预构建）"
  fi

  # ====================================================================
  # fw_vite_proxy_target(warn)：server.proxy 须配 target，禁裸 rewrite
  # ====================================================================
  local proxy_bad=""
  if grep -qE 'proxy:' "$cfg" 2>/dev/null; then
    if ! grep -qE 'target:' "$cfg" 2>/dev/null; then
      proxy_bad=$(grep -nE 'proxy:' "$cfg" 2>/dev/null | head -1)
    fi
  fi
  _fw_report warn fw_vite_proxy_target "$proxy_bad" "server.proxy 未配 target（代理须显式 target，否则转发无效）" "proxy 配置合理（或无 proxy）"

  # ====================================================================
  # fw_vite_esbuild_minify(warn)：生产压缩须 esbuild/minify，禁留未压缩
  # ====================================================================
  if grep -qE 'minify:' "$cfg" 2>/dev/null; then
    if grep -qE "minify:[[:space:]]*false|minify:[[:space:]]*'none'" "$cfg" 2>/dev/null; then
      warn "fw_vite_esbuild_minify: minify 关闭（生产须 esbuild 压缩，包体过大）"
    else
      pass "fw_vite_esbuild_minify: minify 配置合理"
    fi
  else
    pass "fw_vite_esbuild_minify: minify 默认 esbuild（或未显式关闭）"
  fi
}
