# ruleset: react  requires_conf: REACT_SRC_GLOBS
# gates: fw_react_hooks_top_level(fail) fw_react_effect_deps(fail) fw_react_list_key(warn) fw_react_immutable_state(fail) fw_react_memo_benefit(warn) fw_react_error_boundary(warn) fw_react_context_split(warn) fw_react_lazy_suspense(warn) fw_react_server_client_boundary(warn) fw_react_no_render_subscribe(warn) fw_react_ref_callback_explicit(warn) fw_react_no_forwardref(warn)
# harvested-from: P5 范例（2026-07-17），规律源自 React 19.x / 18.x 官方文档 + eslint-plugin-react-hooks；规律14/15 为 React 19 升级指南补充
_fw_react_check() {
  echo "  [react] React 19.x / 18.x 框架规律"

  # ---------- 收集源文件清单 ----------
  local srcs srcarr=()
  srcs=$(_fw_resolve_globs ${REACT_SRC_GLOBS[@]+"${REACT_SRC_GLOBS[@]}"} 2>/dev/null | sort -u)
  while IFS= read -r ln; do
    [[ -n "$ln" ]] && srcarr+=("$ln")
  done <<< "$srcs"

  if [[ ${#srcarr[@]} -eq 0 ]]; then
    warn "react: REACT_SRC_GLOBS 未配置或无文件可检"
    return
  fi

  # 代码正文过滤辅助（去单行注释与块注释行，避免注释误报）
  _fw_react_code_only() {
    sed -E 's://.*$::; /^[[:space:]]*\*/d; /^[[:space:]]*\/\*/d' "$1" 2>/dev/null
  }

  # ====================================================================
  # fw_react_hooks_top_level(fail)：Hook 须顶层调用，禁条件/循环/嵌套函数
  # ====================================================================
  local hook_bad=""
  local f
  for f in "${srcarr[@]}"; do
    local body
    body=$(_fw_react_code_only "$f")
    # 检测 Hook 调用出现在 if(/for(/while(/} else 块内（粗粒度：行内同时含控制结构与 Hook 调用）
    local ln
    ln=$(printf '%s\n' "$body" | grep -nE '^\s*(if|else if|for|while|switch)\b.*\b(use[A-Z][a-zA-Z]*|useState|useEffect|useMemo|useCallback|useRef|useReducer|useContext)\(' 2>/dev/null || true)
    [[ -n "$ln" ]] && hook_bad="${hook_bad}${f}:${ln}
"
  done
  if [[ -n "$hook_bad" ]]; then
    fail "fw_react_hooks_top_level: Hook 调用出现在条件/循环块内（须顶层同步调用，否则调用顺序错乱）:
${hook_bad}"
  else
    pass "fw_react_hooks_top_level: 未检出条件/循环内 Hook 调用"
  fi

  # ====================================================================
  # fw_react_effect_deps(fail)：useEffect 须配依赖数组
  # ====================================================================
  local eff_bad=""
  for f in "${srcarr[@]}"; do
    local body
    body=$(_fw_react_code_only "$f")
    # 检测 useEffect( ... ) 未配第二参数（无逗号后跟 [ 或 useEffect(fn) 直接闭合）
    # 简化：useEffect 调用行 + 后续 1-3 行内未出现 , [ 或 ,[
    local ln
    ln=$(printf '%s\n' "$body" | grep -nE 'useEffect\(' 2>/dev/null || true)
    [[ -z "$ln" ]] && continue
    # 对每个 useEffect 调用，取该行起 4 行窗口检查是否有依赖数组
    local lineno firstline
    firstline=$(printf '%s\n' "$ln" | head -1 | cut -d: -f1)
    if [[ -n "$firstline" ]]; then
      local window
      window=$(printf '%s\n' "$body" | sed -n "${firstline},$((firstline+4))p" 2>/dev/null)
      # 依赖数组迹象：, [ 或 ,[ 或 useEffect(fn, []) 同行
      if ! printf '%s\n' "$window" | grep -qE ',[[:space:]]*\[|useEffect\([^,]*,[[:space:]]*\[' 2>/dev/null; then
        eff_bad="${eff_bad}${f}:${firstline}: useEffect 疑似无依赖数组
"
      fi
    fi
  done
  if [[ -n "$eff_bad" ]]; then
    fail "fw_react_effect_deps: useEffect 未配依赖数组（漏依赖用旧值/省略 deps 每次 render 触发）:
${eff_bad}"
  else
    pass "fw_react_effect_deps: useEffect 均配依赖数组（或无 useEffect）"
  fi

  # ====================================================================
  # fw_react_list_key(warn)：列表渲染禁用 index 作 key
  # ====================================================================
  local key_hit=""
  for f in "${srcarr[@]}"; do
    local body
    body=$(_fw_react_code_only "$f")
    local ln
    ln=$(printf '%s\n' "$body" | grep -nE 'key=\{(index|i|idx)\}|key="index"|key=\{idx\}' 2>/dev/null || true)
    [[ -n "$ln" ]] && key_hit="${key_hit}${f}:${ln}
"
  done
  if [[ -n "$key_hit" ]]; then
    warn "fw_react_list_key: 列表渲染用 index 作 key（增删/排序时 DOM 复用错位，稳定列表可接受）:
${key_hit}"
  else
    pass "fw_react_list_key: 未检出 index 作 key"
  fi

  # ====================================================================
  # fw_react_immutable_state(fail)：state 须不可变更新
  # ====================================================================
  local mut_bad=""
  for f in "${srcarr[@]}"; do
    local body
    body=$(_fw_react_code_only "$f")
    # 检出 setState 后紧接 mutate：.push(/.splice(/.pop(/.shift(/.unshift( 或直接属性赋值 state.x =
    # 模式1：直接对 state 变量调用 mutate 方法（如 items.push(...)）
    local ln
    ln=$(printf '%s\n' "$body" | grep -nE '\b(items|list|state|data|arr|todos|cart)\b\.(push|splice|pop|shift|unshift|sort|reverse)\(' 2>/dev/null || true)
    [[ -n "$ln" ]] && mut_bad="${mut_bad}${f}:${ln}
"
    # 模式2：setState 调用同表达式中 mutate（setItems(items.push(...))）
    ln=$(printf '%s\n' "$body" | grep -nE 'set[A-Z][a-zA-Z]*\([^)]*\.(push|splice|pop)\(' 2>/dev/null || true)
    [[ -n "$ln" ]] && mut_bad="${mut_bad}${f}:${ln}
"
  done
  if [[ -n "$mut_bad" ]]; then
    fail "fw_react_immutable_state: 直接 mutate state（须 spread/immer 返回新引用，否则 React 不 re-render）:
${mut_bad}"
  else
    pass "fw_react_immutable_state: 未检出直接 mutate state"
  fi

  # ====================================================================
  # fw_react_memo_benefit(warn)：useMemo/useCallback 漏依赖风险
  # ====================================================================
  local memo_bad=""
  for f in "${srcarr[@]}"; do
    local body
    body=$(_fw_react_code_only "$f")
    # useCallback(fn, []) 或 useMemo(() => fn, []) 且函数体引用 props/state（疑似漏依赖）
    local ln
    ln=$(printf '%s\n' "$body" | grep -nE 'use(Callback|Memo)\([^,]*,[[:space:]]*\[\][[:space:]]*\)' 2>/dev/null || true)
    [[ -n "$ln" ]] && memo_bad="${memo_bad}${f}:${ln}
"
  done
  if [[ -n "$memo_bad" ]]; then
    warn "fw_react_memo_benefit: useMemo/useCallback 依赖为 []（若函数体引用 props/state 则漏依赖，须人工确认）:
${memo_bad}"
  else
    pass "fw_react_memo_benefit: 未检出空依赖 memo（或无 memo 调用）"
  fi

  # ====================================================================
  # fw_react_error_boundary(warn)：须有 ErrorBoundary
  # ====================================================================
  local has_jsx=0 has_eb=0
  for f in "${srcarr[@]}"; do
    if grep -qE '<[A-Z][a-zA-Z]*[[:space:]]|return[[:space:]]*\(' "$f" 2>/dev/null; then
      has_jsx=1
    fi
    if grep -qE 'componentDidCatch|getDerivedStateFromError' "$f" 2>/dev/null; then
      has_eb=1
    fi
  done
  if [[ "$has_jsx" -eq 0 ]]; then
    pass "fw_react_error_boundary: 无 JSX 渲染，跳过"
  elif [[ "$has_eb" -eq 1 ]]; then
    pass "fw_react_error_boundary: 已配 ErrorBoundary"
  else
    warn "fw_react_error_boundary: JSX 渲染存在但无 componentDidCatch/getDerivedStateFromError（缺错误边界，渲染错误白屏）"
  fi

  # ====================================================================
  # fw_react_context_split(warn)：Context 巨型 value 拆分
  # ====================================================================
  local ctx_bad=""
  for f in "${srcarr[@]}"; do
    local body
    body=$(_fw_react_code_only "$f")
    # 检出 Provider value={{ a, b, c, d, e, f, ... }}（>5 字段）— 简化：value={{ 后字段数
    local ln
    ln=$(printf '%s\n' "$body" | grep -nE 'value=\{\{[^}]*,[^}]*,[^}]*,[^}]*,[^}]*,[^}]*' 2>/dev/null || true)
    [[ -n "$ln" ]] && ctx_bad="${ctx_bad}${f}:${ln}
"
  done
  if [[ -n "$ctx_bad" ]]; then
    warn "fw_react_context_split: Context value 含 >5 字段巨型对象（任意变更全树 re-render，须拆分）:
${ctx_bad}"
  else
    pass "fw_react_context_split: 未检出巨型 Context value"
  fi

  # ====================================================================
  # fw_react_lazy_suspense(warn)：lazy 须配 Suspense
  # ====================================================================
  local lazy_hit=0 sus_hit=0 lazy_files=""
  for f in "${srcarr[@]}"; do
    if grep -qE 'React\.lazy\(|lazy\(' "$f" 2>/dev/null; then
      lazy_hit=1
      lazy_files="${lazy_files}${f}
"
    fi
    if grep -qE '<Suspense' "$f" 2>/dev/null; then
      sus_hit=1
    fi
  done
  if [[ "$lazy_hit" -eq 0 ]]; then
    pass "fw_react_lazy_suspense: 无 lazy 组件，跳过"
  elif [[ "$sus_hit" -eq 1 ]]; then
    pass "fw_react_lazy_suspense: lazy 组件已配 Suspense"
  else
    warn "fw_react_lazy_suspense: React.lazy 调用但未检出 <Suspense 包裹（加载期无 fallback 白屏）:
${lazy_files}"
  fi

  # ====================================================================
  # fw_react_server_client_boundary(warn)：RSC 内禁 Hook/浏览器 API
  # ====================================================================
  # 仅在 Next.js App Router 项目（检出 app/ 目录或 'use client' 用法）触发
  local is_app_router=0
  for f in "${srcarr[@]}"; do
    if grep -qE "'use client'|\"use client\"" "$f" 2>/dev/null; then
      is_app_router=1
      break
    fi
  done
  if [[ "$is_app_router" -eq 0 ]]; then
    pass "fw_react_server_client_boundary: 非 App Router 项目，跳过"
  else
    local rsc_bad=""
    for f in "${srcarr[@]}"; do
      local body firstline
      body=$(_fw_react_code_only "$f")
      firstline=$(printf '%s\n' "$body" | head -1)
      # 文件首行无 'use client' 但含 Hook/浏览器 API
      if ! printf '%s' "$firstline" | grep -qE "'use client'|\"use client\""; then
        if printf '%s\n' "$body" | grep -qE 'useState\(|useEffect\(|useRef\(|window\.|document\.|localStorage\.' 2>/dev/null; then
          rsc_bad="${rsc_bad}${f}
"
        fi
      fi
    done
    if [[ -n "$rsc_bad" ]]; then
      warn "fw_react_server_client_boundary: 含 Hook/浏览器 API 但文件首行无 'use client'（Server Component 内禁用，须标 'use client'）:
${rsc_bad}"
    else
      pass "fw_react_server_client_boundary: 交互组件均标 'use client'"
    fi
  fi

  # ====================================================================
  # fw_react_no_render_subscribe(warn)：render 阶段禁订阅事件/定时器
  # ====================================================================
  local sub_bad=""
  for f in "${srcarr[@]}"; do
    local body
    body=$(_fw_react_code_only "$f")
    # 粗粒度：addEventListener/setInterval/setTimeout 出现在文件中，但同文件无 useEffect 包裹（简化启发式）
    local has_sub has_eff
    has_sub=$(printf '%s\n' "$body" | grep -cE 'addEventListener\(|setInterval\(' 2>/dev/null || true)
    has_eff=$(printf '%s\n' "$body" | grep -cE 'useEffect\(' 2>/dev/null || true)
    if [[ "${has_sub:-0}" -gt 0 && "${has_eff:-0}" -eq 0 ]]; then
      local ln
      ln=$(printf '%s\n' "$body" | grep -nE 'addEventListener\(|setInterval\(' 2>/dev/null || true)
      [[ -n "$ln" ]] && sub_bad="${sub_bad}${f}:${ln}
"
    fi
  done
  if [[ -n "$sub_bad" ]]; then
    warn "fw_react_no_render_subscribe: 检出 addEventListener/setInterval 但同文件无 useEffect 包裹（render 阶段订阅会泄漏，须移入 effect + cleanup）:
${sub_bad}"
  else
    pass "fw_react_no_render_subscribe: 未检出 render 阶段订阅（或已用 useEffect 包裹）"
  fi

  # ====================================================================
  # fw_react_ref_callback_explicit(warn)：ref callback 须显式块语法，禁隐式返回（React 19）
  # ====================================================================
  local refcb_bad=""
  for f in "${srcarr[@]}"; do
    local body
    body=$(_fw_react_code_only "$f")
    # 检出 ref={... => ( 隐式返回箭头（无块 {} 包裹）——简化：ref= 后跟箭头函数且 => 后紧跟 ( 而非 {
    local ln
    ln=$(printf '%s\n' "$body" | grep -nE 'ref=\{[^}]*=>[[:space:]]*\(' 2>/dev/null || true)
    [[ -n "$ln" ]] && refcb_bad="${refcb_bad}${f}:${ln}
"
  done
  if [[ -n "$refcb_bad" ]]; then
    warn "fw_react_ref_callback_explicit: ref callback 隐式返回（React 19 须块语法 ref={c => { x = c }}，否则返回值误判 cleanup 函数报错）:
${refcb_bad}"
  else
    pass "fw_react_ref_callback_explicit: 未检出 ref callback 隐式返回"
  fi

  # ====================================================================
  # fw_react_no_forwardref(warn)：React 19 起 ref 可作 prop，新组件禁用 forwardRef
  # ====================================================================
  local fwd_hit=""
  for f in "${srcarr[@]}"; do
    local body
    body=$(_fw_react_code_only "$f")
    local ln
    ln=$(printf '%s\n' "$body" | grep -nE '\bforwardRef\(' 2>/dev/null || true)
    [[ -n "$ln" ]] && fwd_hit="${fwd_hit}${f}:${ln}
"
  done
  if [[ -n "$fwd_hit" ]]; then
    warn "fw_react_no_forwardref: 检出 forwardRef（React 19 起 ref 可作 prop 直传，新组件禁用 forwardRef 包裹；存量组件标注待迁移）:
${fwd_hit}"
  else
    pass "fw_react_no_forwardref: 未检出 forwardRef"
  fi
}
