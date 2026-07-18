# ruleset: koa  requires_conf: KOA_SRC_GLOBS
# gates: fw_koa_router_factory(warn) fw_koa_no_bare_appuse(warn) fw_koa_input_guard(warn) fw_koa_error_handler(fail) fw_koa_helmet(fail) fw_koa_onion_try_catch(warn) fw_koa_ctx_state(warn) fw_koa_body_limit(warn) fw_koa_ctx_throw(warn) fw_koa_async_middleware(warn) fw_koa_cors(warn)
# harvested-from: ncwk-dev precheck.sh:2556-2581 (2026-07-17) + P4 调研 Koa 3.x 官方文档
# 兼容说明：KOA_SRC_GLOBS 未配置时回退 ncwk-dev 约定 KOA_FILE_GLOBS；
#           KOA_ROUTER_FACTORY_REQUIRED / KOA_FORBIDDEN_GLOBAL_APPUSE / KOA_INPUT_GUARD 缺省时用默认值（仍生效）。
_fw_koa_check() {
  echo "  [koa] Koa 3.x / 2.x 框架规律"

  # ---------- 收集源文件清单（KOA_SRC_GLOBS 优先，回退 KOA_FILE_GLOBS） ----------
  local srcs srcarr=()
  srcs=$(_fw_resolve_globs ${KOA_SRC_GLOBS[@]+"${KOA_SRC_GLOBS[@]}"} 2>/dev/null | sort -u)
  if [[ -z "$srcs" ]]; then
    srcs=$(_fw_resolve_globs ${KOA_FILE_GLOBS[@]+"${KOA_FILE_GLOBS[@]}"} 2>/dev/null | sort -u)
  fi
  while IFS= read -r ln; do
    [[ -n "$ln" ]] && srcarr+=("$ln")
  done <<< "$srcs"

  if [[ ${#srcarr[@]} -eq 0 ]]; then
    warn "koa: KOA_SRC_GLOBS/KOA_FILE_GLOBS 未配置或无文件可检"
    return
  fi

  # 兼容 ncwk-dev 三个开关变量：缺省给默认值（保持门禁生效）
  local factory_required="${KOA_ROUTER_FACTORY_REQUIRED:-1}"
  local forbidden_appuse="${KOA_FORBIDDEN_GLOBAL_APPUSE:-app\.use\([[:space:]]*[A-Za-z0-9_.]*[Rr]outer[[:space:]]*\)}"
  local input_guard="${KOA_INPUT_GUARD:-validate|validator|joi|Joi|zod|yup|ajv|checkSchema}"

  # ====================================================================
  # fw_koa_router_factory(warn)：路由须 factory 注入（createRouter(deps) 返回 Router）
  # ====================================================================
  if [[ "$factory_required" == "1" ]]; then
    local factory
    factory=$(_fw_grep_count "create.*Router[[:space:]]*\(" "${srcarr[@]+"${srcarr[@]}"}")
    if [[ "$factory" -gt 0 ]]; then
      pass "fw_koa_router_factory: router factory 注入存在 ($factory 处)"
    else
      warn "fw_koa_router_factory: 未检出 router factory（须 createRouter(deps) 返回 Router，依赖显式注入便于测试）"
    fi
  fi

  # ====================================================================
  # fw_koa_no_bare_appuse(warn)：禁裸 app.use(router)，须 app.use(router.routes())
  # ====================================================================
  if [[ -n "$forbidden_appuse" ]]; then
    local hits
    hits=$(grep -rnE "$forbidden_appuse" "${srcarr[@]+"${srcarr[@]}"}" 2>/dev/null || true)
    if [[ -z "$hits" ]]; then
      pass "fw_koa_no_bare_appuse: 无裸 app.use(router)"
    else
      warn "fw_koa_no_bare_appuse: 检出裸 app.use(router)（Koa 须 app.use(router.routes())；全局直挂须改 factory 注入）:
${hits}"
    fi
  fi

  # ====================================================================
  # fw_koa_input_guard(warn)：路由参数/请求体须输入校验
  # ====================================================================
  if [[ -n "$input_guard" ]]; then
    local ig
    ig=$(_fw_grep_count "$input_guard" "${srcarr[@]+"${srcarr[@]}"}")
    if [[ "$ig" -gt 0 ]]; then
      pass "fw_koa_input_guard: 输入校验存在 ($ig 处)"
    else
      warn "fw_koa_input_guard: 未检出输入校验（@koa/router 参数与 body 须白名单校验 CWE-20）"
    fi
  fi

  # ====================================================================
  # fw_koa_error_handler(fail)：统一错误处理（try/catch 包裹 await next() 或 app.on('error')）
  # ====================================================================
  local eh_hit
  eh_hit=$(grep -rlE "app\.on\(['\"]error['\"]" "${srcarr[@]+"${srcarr[@]}"}" 2>/dev/null || true)
  if [[ -z "$eh_hit" ]]; then
    # 无 app.on('error') 时，须存在 try + await next() 的错误兜底中间件
    local f
    for f in "${srcarr[@]+"${srcarr[@]}"}"; do
      if grep -qE 'await[[:space:]]+next\(\)' "$f" 2>/dev/null && grep -qE 'try[[:space:]]*\{' "$f" 2>/dev/null; then
        eh_hit="$f"
        break
      fi
    done
  fi
  if [[ -n "$eh_hit" ]]; then
    pass "fw_koa_error_handler: 统一错误处理存在（try/catch 洋葱兜底或 app.on('error')）"
  else
    fail "fw_koa_error_handler: 无统一错误处理（中间件抛错将由 Koa 默认 onerror 泄露栈，须首个中间件 try/catch 包裹 await next() + app.on('error')）"
  fi

  # ====================================================================
  # fw_koa_helmet(fail)：koa-helmet 安全头基线
  # ====================================================================
  local helmet_hit
  helmet_hit=$(grep -rlE "koa-helmet|require\(['\"]helmet['\"]\)|helmet\(\)" "${srcarr[@]+"${srcarr[@]}"}" 2>/dev/null || true)
  if [[ -n "$helmet_hit" ]]; then
    pass "fw_koa_helmet: koa-helmet 安全头已启用"
  else
    fail "fw_koa_helmet: 未检出 koa-helmet（生产基线安全头缺失 CWE-693）"
  fi

  # ====================================================================
  # fw_koa_onion_try_catch(warn)：洋葱模型——跨中间件逻辑须 try/catch 包裹 await next()
  # ====================================================================
  local ot_bad=""
  for f in "${srcarr[@]+"${srcarr[@]}"}"; do
    if grep -qE 'await[[:space:]]+next\(\)' "$f" 2>/dev/null && ! grep -qE 'try[[:space:]]*\{' "$f" 2>/dev/null; then
      ot_bad="${ot_bad}${f}
"
    fi
  done
  if [[ -n "$ot_bad" ]]; then
    warn "fw_koa_onion_try_catch: await next() 未包裹 try/catch（下游错误冒泡越过本中间件，洋葱模型断裂）:
${ot_bad}"
  else
    pass "fw_koa_onion_try_catch: await next() 均有 try/catch 包裹或无跨中间件逻辑"
  fi

  # ====================================================================
  # fw_koa_ctx_state(warn)：跨中间件共享数据须挂 ctx.state，禁直接污染 ctx
  # ====================================================================
  local cs_bad=""
  for f in "${srcarr[@]+"${srcarr[@]}"}"; do
    local ln
    ln=$(grep -nE 'ctx\.[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[^=]' "$f" 2>/dev/null \
       | grep -vE 'ctx\.(body|status|state|type|headers|url|method|query|path|request|response|app|cookies|params|href|host|hostname|origin|protocol|secure|ip|ips|length|fresh|stale|socket|originalUrl|req|res|respond|writable|flushHeaders|attachment|redirect|set|get|is|accepts|throw|assert|toJSON|inspect)[.[:space:]]' || true)
    [[ -n "$ln" ]] && cs_bad="${cs_bad}${f}:${ln}
"
  done
  if [[ -n "$cs_bad" ]]; then
    warn "fw_koa_ctx_state: 直接向 ctx 挂自定义属性（污染命名空间、与库冲突；共享数据须 ctx.state.xxx）:
${cs_bad}"
  else
    pass "fw_koa_ctx_state: 跨中间件共享经 ctx.state 或无自定义挂载"
  fi

  # ====================================================================
  # fw_koa_body_limit(warn)：koa-bodyparser 须配 jsonLimit/formLimit
  # ====================================================================
  local bl_bad=""
  for f in "${srcarr[@]+"${srcarr[@]}"}"; do
    local ln
    ln=$(grep -nE 'bodyParser\(\s*\)|bodyParser\(\{[^}]*\}\)' "$f" 2>/dev/null || true)
    [[ -z "$ln" ]] && continue
    if ! grep -qE 'jsonLimit|formLimit|textLimit' "$f" 2>/dev/null; then
      bl_bad="${bl_bad}${f}:${ln}
"
    fi
  done
  if [[ -n "$bl_bad" ]]; then
    warn "fw_koa_body_limit: koa-bodyparser 未配 jsonLimit/formLimit（大包 DoS 风险 CWE-400）:
${bl_bad}"
  else
    pass "fw_koa_body_limit: bodyparser 已配 limit 或未使用 bodyparser"
  fi

  # ====================================================================
  # fw_koa_ctx_throw(warn)：业务错误须 ctx.throw(status)，禁裸 throw new Error
  # ====================================================================
  local ct_bad=""
  for f in "${srcarr[@]+"${srcarr[@]}"}"; do
    local ln
    ln=$(grep -nE 'throw[[:space:]]+new[[:space:]]+Error' "$f" 2>/dev/null || true)
    [[ -n "$ln" ]] && ct_bad="${ct_bad}${f}:${ln}
"
  done
  if [[ -n "$ct_bad" ]]; then
    warn "fw_koa_ctx_throw: 裸 throw new Error 无 HTTP 状态码语义（统一错误处理按 500 处理；业务错误须 ctx.throw(4xx)）:
${ct_bad}"
  else
    pass "fw_koa_ctx_throw: 业务错误经 ctx.throw 或无裸抛"
  fi

  # ====================================================================
  # fw_koa_async_middleware(warn)：Koa 2+/3 中间件须 async/await，禁 generator/回调式
  # ====================================================================
  local am_bad=""
  for f in "${srcarr[@]+"${srcarr[@]}"}"; do
    local ln
    ln=$(grep -nE 'app\.use\([[:space:]]*function[[:space:]]*\*|module\.exports[[:space:]]*=[[:space:]]*function[[:space:]]*\*' "$f" 2>/dev/null || true)
    [[ -n "$ln" ]] && am_bad="${am_bad}${f}:${ln}
"
  done
  if [[ -n "$am_bad" ]]; then
    warn "fw_koa_async_middleware: 检出 generator 中间件（Koa 1.x 遗产，Koa 2+/3 已移除，须改 async/await）:
${am_bad}"
  else
    pass "fw_koa_async_middleware: 中间件均为 async/await 风格"
  fi

  # ====================================================================
  # fw_koa_cors(warn)：CORS 须显式 origin
  # ====================================================================
  local cors_bad=""
  for f in "${srcarr[@]+"${srcarr[@]}"}"; do
    local ln
    ln=$(grep -nE 'cors\(\s*\)' "$f" 2>/dev/null || true)
    [[ -n "$ln" ]] && cors_bad="${cors_bad}${f}:${ln}
"
    ln=$(grep -nE "origin[[:space:]]*:[[:space:]]*['\"]\*['\"]" "$f" 2>/dev/null || true)
    [[ -n "$ln" ]] && cors_bad="${cors_bad}${f}:${ln}
"
  done
  if [[ -n "$cors_bad" ]]; then
    warn "fw_koa_cors: CORS 未显式配置 origin 白名单（@koa/cors 空参 / origin:* 放行任意源 CWE-942）:
${cors_bad}"
  else
    pass "fw_koa_cors: CORS origin 白名单已配或未启用 CORS"
  fi
}
