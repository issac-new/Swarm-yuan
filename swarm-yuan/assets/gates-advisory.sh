#!/usr/bin/env bash
# advisory (6) 门禁（由 scripts/split-gates.sh 从 precheck.sh 抽取，决策 19）
# 被 precheck.sh source（开发态）或 install.sh 内联（打包态）。
# 不要单独执行——依赖 precheck.sh 主文件的 fail()/warn()/pass() 与全局变量。

check_consistency() {
  echo "=== 业务规则 + 数据勾稽核对（check §2/§3 无多漏错重）==="
  for dir in ${CONSISTENCY_DIRS[@]+"${CONSISTENCY_DIRS[@]}"}; do
    [[ -d "$dir" ]] || continue
    # 检查是否有未标注幂等的重复写入逻辑（粗筛：同名 INSERT/create 多处出现）
    local dup_writes
    dup_writes=$(_scan_src '(INSERT INTO|\.create\(|db\.(insert|create))' 'ts,js,py,go,java' 'test\|mock\|seed\|fixture\|migration' "$dir")
    if [[ -n "$dup_writes" ]]; then
      local count
      count=$(echo "$dup_writes" | wc -l | xargs)
      if [[ $count -gt 5 ]]; then
        warn "  ⚠ $dir 有 $count 处写入逻辑，请确认幂等性（重复请求不产生副作用）"
      fi
    fi
  done
  pass "业务规则与勾稽核对完成（详见 reference-manual.md §数据勾稽核对）"
  echo "  提示: 无多漏错重核对项见 reference-manual.md §数据勾稽核对："
  echo "    - 无遗漏：关联记录无缺失"
  echo "    - 无多余：无冗余/重复记录"
  echo "    - 记录正确：字段值符合业务规则"
  echo "    - 勾稽正确：外键/聚合/关联关系正确"
  echo "    - 一致性：同源数据多处一致"
  echo "    - 幂等性：重复请求不产生副作用"
}

check_link_depth() {
  echo "=== 调用链深度检查（DDD：链路膨胀/跨聚合事务/Repository 查询泄漏）==="
  local found=0

  if [[ "$MAX_LINK_DEPTH" -le 0 ]]; then
    skip_if_unconfigured "MAX_LINK_DEPTH=0，跳过调用链深度检查"
    return
  fi

  # ---- 1. 优先用 gitnexus trace（最准确，基于代码图谱）----
  if has_gitnexus && gitnexus_indexed; then
    trace_tool "gitnexus" "trace --format text"
    local depth_output; depth_output=$(gitnexus trace --format text 2>/dev/null | head -50 || true)
    if [[ -n "$depth_output" ]]; then
      local max_depth; max_depth=$(echo "$depth_output" | grep -oE '[0-9]+' | sort -n | tail -1 || echo 0)
      if [[ "$max_depth" -gt "$MAX_LINK_DEPTH" ]]; then
        warn "调用链最大深度 ${max_depth}（gitnexus trace）超过阈值 ${MAX_LINK_DEPTH}，建议拆分中转层"
      fi
      pass "调用链深度检查完成（基于 gitnexus trace，最大深度 ${max_depth}）"
      return
    fi
  fi

  # ---- 2. 降级 graphify path ----
  if has_graphify && graphify_built; then
    trace_tool "graphify" "explain"
    local report; report=$(graphify explain 2>/dev/null | head -50 || true)
    if echo "$report" | grep -qiE "depth|max.*path|longest"; then
      local depths; depths=$(echo "$report" | grep -oE '[0-9]+' | sort -n | tail -1 || true)
      if [[ -n "$depths" && "$depths" -gt "$MAX_LINK_DEPTH" ]]; then
        warn "调用链最大深度 ${depths} 超过阈值 ${MAX_LINK_DEPTH}（graphify 报告，建议拆分中间适配层）"
      fi
    fi
    pass "调用链深度检查完成（基于 graphify 图谱）"
    return
  fi

  # ---- 3. 降级 madge ----
  if has_madge; then
    local tree _madge_err
    _madge_err=$(mktemp "${TMPDIR:-/tmp}/swarm-yuan-madge.XXXXXX")
    tree=$(madge --tree --extensions ts,js "$PROJECT_DIR" 2>"$_madge_err" || true)
    if [[ -z "$tree" ]]; then
      warn "madge 执行无输出（stderr: $(head -1 "$_madge_err" 2>/dev/null || echo 空)）——调用链深度降级为纯转发统计"
      rm -f "$_madge_err"
    else
      rm -f "$_madge_err"
      local max_indent=0
      while IFS= read -r line; do
        local spaces; spaces=$(echo "$line" | grep -oE '^[ ]*' | wc -c | xargs)
        [[ "$spaces" -gt "$max_indent" ]] && max_indent=$spaces
      done <<< "$tree"
      local depth=$(( max_indent / 2 ))
      if [[ "$depth" -gt "$MAX_LINK_DEPTH" ]]; then
        warn "调用链最大深度约 ${depth}（madge 估算）超过阈值 ${MAX_LINK_DEPTH}，建议拆分中转层"
      fi
      pass "调用链深度检查完成（基于 madge，最大深度约 ${depth}）"
      return
    fi
  fi

  # ---- 2. 降级：统计"纯转发函数"（只调用下一个函数、无其他逻辑）作为链路膨胀信号 ----
  local forwarders=0
  local dir
  for dir in ${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}; do
    [[ -d "$dir" ]] || continue
    # 粗筛：函数体只有一行 return xxx()，疑似纯转发
    local hits
    hits=$(grep -rnE '^\s*(export\s+)?(async\s+)?function\s+\w+.*\{$' "$dir" \
      --include='*.ts' --include='*.js' 2>/dev/null | wc -l | xargs || true)
    # 进一步：找函数体只有 return 调用的（粗略，需多行匹配）
    local pure_fwd
    pure_fwd=$(grep -rzoP 'function\s+\w+\([^)]*\)\s*\{\s*return\s+\w+\([^)]*\)\s*;?\s*\}' "$dir" \
      --include='*.ts' --include='*.js' 2>/dev/null | grep -c 'function' || true)
    forwarders=$((forwarders + ${pure_fwd:-0}))
  done
  if [[ $forwarders -gt 5 ]]; then
    warn "检测到 $forwarders 个疑似纯转发函数（只 return 调用下一个函数）——可能是链路膨胀的适配层堆叠，建议合并"
  fi
  warn "未安装 graphify/madge，调用链深度检查降级为纯转发函数统计。安装 madge（npm i -g madge）或 graphify（uv tool install graphifyy）以获得准确调用链深度"
  pass "调用链深度检查完成（降级模式）"
}

check_consistency_cross() {
  echo "=== BDAT 跨域一致性检查（TOGAF：业务-应用-数据命名一致 + 数据所有权 SoR）==="
  local found=0

  # ---- 1. 业务域术语表 vs 代码标识符命名一致性 ----
  if [[ -z "$GLOSSARY_FILE" ]]; then
    warn "未配置 GLOSSARY_FILE，跳过 BDAT 命名一致性检查（新建 GLOSSARY_FILE，格式：| 业务名 | 代码标识符 |（每行一个概念，供 --consistency-cross 校验））"
  elif [[ ! -f "$GLOSSARY_FILE" ]]; then
    warn "术语表文件不存在：${GLOSSARY_FILE}（TOGAF 要求业务域有统一术语表，避免同名异义/异名同义）"
  else
    # 解析术语表：每行 "业务名 <TAB> 代码标识符" 或 "| 业务名 | 代码标识符 |"
    # 跳过表头行（恰好是"业务名"）与分隔行（---）
    local entries; entries=$(awk '
      /^\|/ {
        gsub(/^\||\|$/,""); n=split($0,a,"|");
        if (n>=2) {
          gsub(/^ +| +$/,"",a[1]); gsub(/^ +| +$/,"",a[2]);
          if(a[1]!=""&&a[2]!="" && a[1]!="业务名" && a[1]!="业务" && a[1]!="名字" && a[1]!="标识符" && a[2] !~ /^[-:]+$/)
            print a[1]"\t"a[2]
        }
      }
      /\t/ { n=split($0,a,"\t"); if(a[1]!=""&&a[2]!=""&&a[1]!="业务名") print a[1]"\t"a[2] }
    ' "$GLOSSARY_FILE" 2>/dev/null || true)
    if [[ -n "$entries" ]]; then
      local biz code
      while IFS=$'\t' read -r biz code; do
        [[ -z "$biz" || -z "$code" ]] && continue
        # 检查代码中是否存在该标识符（粗筛：grep 类名/函数名/表名）
        # 注意 BSD grep：--include 必须紧跟 -r 选项，pattern 用 -e 防止 - 开头
        local hits
        hits=$(grep -rnwF --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.sql' -e "$code" "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}" 2>/dev/null | wc -l | xargs || true)
        if [[ "$hits" -eq 0 ]]; then
          warn "术语表中的代码标识符 '${code}'（业务名：${biz}）在代码中未找到——可能命名已漂移或术语表过时"
        fi
      done <<< "$entries"
    fi
  fi

  # ---- 2. 数据所有权（System of Record）检查 ----
  if [[ -z "$SOR_FILE" ]]; then
    warn "未配置 SOR_FILE，跳过数据所有权检查（新建 SOR_FILE，格式：| 实体 | 权威源 | 允许读 | 允许写 |（每个数据实体一行））"
  elif [[ ! -f "$SOR_FILE" ]]; then
    warn "数据所有权文件不存在：${SOR_FILE}（TOGAF 要求明确每个数据实体的 System of Record，避免双写不一致）"
  else
    # 解析 SoR 表：| 实体 | 权威源 | 允许读 | 允许写 |
    local sor_entries; sor_entries=$(awk '
      /^\|/ && !/^\|[-: ]+\|/ && !/实体|实体名/ {
        gsub(/^\||\|$/,""); n=split($0,a,"|");
        if (n>=2) { gsub(/^ +| +$/,"",a[1]); gsub(/^ +| +$/,"",a[2]); if(a[1]!="") print a[1]"\t"a[2] }
      }
    ' "$SOR_FILE" 2>/dev/null || true)
    if [[ -n "$sor_entries" ]]; then
      # 仅校验 SoR 表存在且实体有登记，详细双写检测需人工
      pass "数据所有权表存在（${SOR_FILE}），含 $(echo "$sor_entries" | wc -l | xargs) 个实体登记"
    fi
  fi

  if [[ $found -eq 0 ]]; then
    pass "BDAT 跨域一致性检查通过"
  fi
}

check_state() {
  echo "=== 状态管理检查（巨型store/prop drilling/派生状态）==="
  local found=0

  # ---- 1. 巨型 store 检测：store 文件行数 ----
  if [[ -n "$STORE_DIR" && -d "$STORE_DIR" ]]; then
    if [[ "$MAX_STORE_LINES" -gt 0 ]]; then
      local sf
      while IFS= read -r sf; do
        [[ -z "$sf" ]] && continue
        local lines; lines=$(wc -l < "$sf" 2>/dev/null | xargs || echo 0)
        if [[ "$lines" -gt "$MAX_STORE_LINES" ]]; then
          warn "${sf} 有 ${lines} 行（>阈值 ${MAX_STORE_LINES}）——巨型 store 会导致改一个字段全组件重渲染，建议按领域拆分"
        fi
      done < <(find "$STORE_DIR" -type f \( -name '*.ts' -o -name '*.js' \) 2>/dev/null)
    fi
  else
    warn "未配置 STORE_DIR，跳过 store 检查"
  fi

  # ---- 2. Prop Drilling 深度检测：组件 props 透传链 ----
  if [[ -n "$COMPONENT_DIR" && -d "$COMPONENT_DIR" ]]; then
    # 粗筛：检测组件接收 props 后原样透传给子组件（...props / {...this.props}）
    local drilling
    drilling=$(_scan_src '\.\.\.props|\{\.\.\.props\}|\{\.\.\.this\.props\}|rest\.props|remaining.*props' 'ts,tsx,js,jsx,vue,svelte' 'test\|mock\|node_modules' "$COMPONENT_DIR")
    if [[ -n "$drilling" ]]; then
      local dcount; dcount=$(echo "$drilling" | wc -l | xargs || true)
      if [[ "$dcount" -gt 5 ]]; then
        warn "检测到 ${dcount} 处 props 透传（...props）——深度 prop drilling 会使中间组件被迫接收无关 props，建议 Context/compose"
      fi
    fi
  fi

  # ---- 3. 派生状态用 useState 检测（应改 useMemo/直接计算）----
  if [[ -n "$COMPONENT_DIR" && -d "$COMPONENT_DIR" ]]; then
    local derived
    derived=$(_scan_src 'useState\([^)]*(\.map|\.filter|\.reduce|\.sort|\.find|\.length|\.concat)' 'ts,tsx,js,jsx' 'test\|mock\|node_modules' "$COMPONENT_DIR")
    if [[ -n "$derived" ]]; then
      local dcount; dcount=$(echo "$derived" | wc -l | xargs || true)
      warn "检测到 ${dcount} 处 useState 内做派生计算（.map/.filter/.reduce 等）——派生状态应直接计算或 useMemo，存 state 会导致不同步"
      echo "$derived" | head -3 | sed 's/^/    /'
    fi
  fi

  if [[ $found -eq 0 ]]; then
    pass "状态管理检查通过"
  fi
}

check_cognition() {
  # WP-P5: 认知扩展包 §14-§18 按 profile 门控——节不存在 → SKIP 披露（不 fail，不静默）
  # spec-template.md 无 §14 → profile=lite/standard 已裁剪该节（generate-skill.sh 按 profile 分层拷贝）
  # 路径解析：技能根 = $_CONF_DIR/..（precheck.sh 在 scripts/，assets/ 在技能根）；
  # precheck 运行时已 cd "$PROJECT_DIR"，故 $PWD 是项目目录而非技能目录——不能依赖 $PWD。
  # 多路回退：_CONF_DIR/.. → SKILL_DIR → CONF_DIR → $PWD；找不到模板则不 SKIP（放行正常流程）。
  local _st="" _skill_root=""
  [[ -n "${_CONF_DIR:-}" ]] && _skill_root="$(cd "${_CONF_DIR}/.." 2>/dev/null && pwd)"
  for _cand in "$_skill_root" "${SKILL_DIR:-}" "${CONF_DIR:-}" "${PWD:-}"; do
    [[ -z "$_cand" ]] && continue
    if [[ -f "${_cand}/assets/spec-template.md" ]]; then _st="${_cand}/assets/spec-template.md"; break; fi
    if [[ -f "${_cand}/spec-template.md" ]]; then _st="${_cand}/spec-template.md"; break; fi
  done
  if [[ -n "$_st" ]] && ! grep -q '^## 14\.' "$_st" 2>/dev/null; then
    echo "=== 认知检查（check_cognition）==="
    echo "  ⊘ SKIP: 认知扩展包 §14-§18 未启用（profile=lite/standard，spec-template 已裁剪该节）"
    pass "认知检查 SKIP（profile 门控，节不存在）"
    return
  fi
  echo "=== 认知递进体检（六阶认知链 + 六维动力学）==="
  echo "  理念：先有概念→结构→空间→映射→规律→处理；关系在时空变化中呈现速度/聚散/趋势/强度/能耗/累积量"
  echo "  ℹ 性质：认知体检报告（warn-only，永不 fail，不参与门禁否决；计分供认知基线参考）"
  echo ""

  # ---- ①概念定义：项目核心概念是否被定义 ----
  echo "  ①概念定义（是什么）"
  local concept_score=0
  if [[ -n "$GLOSSARY_FILE" && -f "$GLOSSARY_FILE" ]]; then
    local term_count; term_count=$(awk '/^\|/ && !/^\|[-: ]+\|/ && !/业务名|代码/ {c++} END{print c+0}' "$GLOSSARY_FILE" 2>/dev/null || echo 0)
    echo "    业务术语表：${GLOSSARY_FILE}（${term_count} 个概念定义）"
    [[ "$term_count" -gt 0 ]] && concept_score=$((concept_score+1))
  else
    warn "无业务术语表（GLOSSARY_FILE 未配置）——概念未显式定义，依赖口头约定"
  fi
  # 稳定单元清单（reference-manual §4/5/6）
  local rm_file
  rm_file=$(_first_existing_file "references/reference-manual.md" "reference-manual.md" ".claude/skills/*/references/reference-manual.md")
  if [[ -n "$rm_file" ]]; then
    local unit_count; unit_count=$(awk '/^#+ .*[§4-6].*(组件|依赖链路|接口)/{in_sec=1} /^#+ /&&!/[§4-6]/{in_sec=0} in_sec&&/^\|/&&!/^\|[-: ]+\|/{c++} END{print c+0}' "$rm_file" 2>/dev/null || echo 0)
    echo "    稳定单元清单：${rm_file}（${unit_count} 个单元登记）"
    [[ "$unit_count" -gt 0 ]] && concept_score=$((concept_score+1))
  else
    warn "无 reference-manual.md——稳定单元未盘点"
  fi
  echo "    ①概念定义认知度：${concept_score}/2"

  # ---- ②结构：概念怎么组织成结构 ----
  echo ""
  echo "  ②结构（怎么组织）"
  local struct_score=0
  if [[ ${#LAYER_DEFS[@]} -gt 0 ]]; then
    echo "    分层定义：${#LAYER_DEFS[@]} 层（${LAYER_ORDER[*]+"${LAYER_ORDER[*]}"})"
    struct_score=$((struct_score+1))
  else
    warn "无分层定义（LAYER_DEFS）——结构未显式声明"
  fi
  if [[ -n "$AGGREGATE_DIR" && -d "$AGGREGATE_DIR" ]]; then
    local agg_count; agg_count=$(find "$AGGREGATE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | xargs || echo 0)
    echo "    聚合边界：${AGGREGATE_DIR}（${agg_count} 个聚合根）"
    [[ "$agg_count" -gt 0 ]] && struct_score=$((struct_score+1))
  fi
  if [[ ${#CONTEXT_DIRS[@]} -gt 0 ]]; then
    echo "    限界上下文：${#CONTEXT_DIRS[@]} 个"
    struct_score=$((struct_score+1))
  fi
  echo "    ②结构认知度：${struct_score}/3"

  # ---- ③空间：结构占据什么空间 ----
  echo ""
  echo "  ③空间（在哪里）"
  local space_score=0
  if [[ ${#SERVICE_DIRS[@]} -gt 0 ]]; then
    echo "    服务空间：${#SERVICE_DIRS[@]} 个服务目录"
    space_score=$((space_score+1))
  fi
  if [[ -n "$COMPONENT_DIR" && -d "$COMPONENT_DIR" ]]; then
    local comp_count; comp_count=$(find "$COMPONENT_DIR" -type f \( -name '*.tsx' -o -name '*.jsx' -o -name '*.vue' -o -name '*.svelte' \) 2>/dev/null | wc -l | xargs || echo 0)
    echo "    组件空间：${COMPONENT_DIR}（${comp_count} 个组件）"
    space_score=$((space_score+1))
  fi
  if [[ -n "$STORE_DIR" && -d "$STORE_DIR" ]]; then
    echo "    状态空间：${STORE_DIR}"
    space_score=$((space_score+1))
  fi
  echo "    ③空间认知度：${space_score}/3"

  # ---- ④三者映射：概念↔结构↔空间是否一致 ----
  echo ""
  echo "  ④三者映射（概念↔结构↔空间是否一致）"
  local map_score=0
  # COGNITION_MAP：认知映射表（可选；配置且存在时纳入映射检查输入——原死变量接入，不改变 /3 计分口径）
  if [[ -n "${COGNITION_MAP:-}" && -f "${COGNITION_MAP}" ]]; then
    echo "    认知映射表：${COGNITION_MAP}（已配置，纳入映射检查）"
  fi
  # 术语表标识符 vs 代码存在性（概念↔空间映射）
  if [[ -n "$GLOSSARY_FILE" && -f "$GLOSSARY_FILE" && ${#WRITABLE_DIRS[@]} -gt 0 ]]; then
    local drift_count=0
    local entries; entries=$(awk '
      /^\|/ {
        gsub(/^\||\|$/,""); n=split($0,a,"|");
        if (n>=2) { gsub(/^ +| +$/,"",a[1]); gsub(/^ +| +$/,"",a[2]);
          if(a[1]!=""&&a[2]!=""&&a[1]!="业务名"&&a[2] !~ /^[-:]+$/) print a[2]
        }
      }
    ' "$GLOSSARY_FILE" 2>/dev/null || true)
    if [[ -n "$entries" ]]; then
      local code
      while IFS= read -r code; do
        [[ -z "$code" ]] && continue
        local hits; hits=$(grep -rnwF --include='*.ts' --include='*.js' --include='*.py' --include='*.go' -e "$code" "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}" 2>/dev/null | wc -l | xargs || true)
        [[ "$hits" -eq 0 ]] && drift_count=$((drift_count+1))
      done <<< "$entries"
      if [[ $drift_count -eq 0 ]]; then
        echo "    术语↔代码映射：一致（无漂移）"
        map_score=$((map_score+1))
      else
        warn "术语↔代码映射：${drift_count} 个术语在代码中未找到（概念↔空间漂移）"
      fi
    fi
  fi
  # 分层↔目录映射（结构↔空间）
  if [[ ${#LAYER_DEFS[@]} -gt 0 ]]; then
    echo "    分层↔目录映射：${#LAYER_DEFS[@]} 层均绑定目录 glob"
    map_score=$((map_score+1))
  fi
  # 数据所有权↔服务映射（概念↔空间）
  if [[ -n "$SOR_FILE" && -f "$SOR_FILE" ]]; then
    echo "    数据所有权↔服务映射：${SOR_FILE} 存在"
    map_score=$((map_score+1))
  fi
  echo "    ④映射认知度：${map_score}/3"

  # ---- ⑤认知规律：从映射中发现的规律是否被编码 ----
  echo ""
  echo "  ⑤认知规律（规律是否被编码成门禁）"
  local rule_count=0
  [[ ${#LAYER_DEFS[@]} -gt 0 ]] && { echo "    规律：依赖单向（上层→下层）→ --layer"; rule_count=$((rule_count+1)); }
  [[ -n "$AGGREGATE_DIR" ]] && { echo "    规律：聚合间只引用 ID → --layer"; rule_count=$((rule_count+1)); }
  [[ ${#STABLE_GLOBS[@]} -gt 0 ]] && { echo "    规律：稳定单元不可擅改 → --stable-diff"; rule_count=$((rule_count+1)); }
  [[ -n "$ACL_DIR" ]] && { echo "    规律：跨上下文须经 ACL → --contract"; rule_count=$((rule_count+1)); }
  [[ ${#DB_CONFIG_FILES[@]} -gt 0 ]] && { echo "    规律：每服务独立 DB → --service"; rule_count=$((rule_count+1)); }
  [[ -n "$API_SPEC_DIR" ]] && { echo "    规律：契约须版本化 → --api"; rule_count=$((rule_count+1)); }
  [[ -n "$ADR_DIR" ]] && { echo "    规律：决策须可追溯 → --adr"; rule_count=$((rule_count+1)); }
  echo "    ⑤规律编码数：${rule_count}（每个规律对应一个门禁）"

  # ---- ⑥处理关系：关系被破坏时如何处理 ----
  echo ""
  echo "  ⑥处理关系（违规时的处置机制）"
  local handle_score=0
  [[ -n "$SPEC_FILE" || -f "spec-template.md" ]] && { echo "    spec 声明变更（MODIFIED 段）"; handle_score=$((handle_score+1)); }
  [[ -n "$ADR_DIR" && -d "$ADR_DIR" ]] && { echo "    ADR 记录决策"; handle_score=$((handle_score+1)); }
  [[ -n "$TECH_DEBT_FILE" && -f "$TECH_DEBT_FILE" ]] && { echo "    技术债登记"; handle_score=$((handle_score+1)); }
  echo "    处置机制：${handle_score}/3（spec/ADR/技术债）"

  # ---- 六维动力学观测 ----
  echo ""
  echo "  ── 六维关系动力学观测（关系的时空变化）──"

  # 速度：单次变更文件数
  local speed_val=0
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    speed_val=$(_git_changed_files | wc -l | xargs || true)
  fi
  echo "    速度：本次变更 ${speed_val} 个文件", "$([[ "$COG_SPEED_FILES" -gt 0 && "$speed_val" -gt "$COG_SPEED_FILES" ]] && echo "⚠ 过快（>${COG_SPEED_FILES}，耦合扩散风险）" || echo "正常")"

  # 聚散：服务/组件数
  local gather_val=0
  [[ ${#SERVICE_DIRS[@]} -gt 0 ]] && gather_val=${#SERVICE_DIRS[@]}
  [[ -n "$COMPONENT_DIR" && -d "$COMPONENT_DIR" ]] && gather_val=$((gather_val + $(find "$COMPONENT_DIR" -type f \( -name '*.tsx' -o -name '*.vue' -o -name '*.svelte' -o -name '*.jsx' \) 2>/dev/null | wc -l | xargs || echo 0)))
  echo "    聚散：${gather_val} 个服务/组件单元", "$([[ "$gather_val" -gt 50 ]] && echo "趋向分散" || echo "聚合适中")"

  # 趋势：依赖深度变化（与基线对比）
  local trend_val="未知"
  if [[ -n "$COGNITION_BASELINE" && -f "$COGNITION_BASELINE" ]]; then
    local base_depth; base_depth=$(grep -iE '依赖深度|depth' "$COGNITION_BASELINE" 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo "")
    if [[ -n "$base_depth" ]]; then trend_val="基线深度 ${base_depth}"; fi
  fi
  echo "    趋势：依赖深度 ${trend_val}（对比基线判断上升/下降）"

  # 强度：高 fan-in 文件（被多处引用）
  if [[ "$COG_STRENGTH_FANIN" -gt 0 && ${#WRITABLE_DIRS[@]} -gt 0 ]]; then
    local strong_files=0
    local wd
    for wd in "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}"; do
      [[ -d "$wd" ]] || continue
      # 找被 >COG_STRENGTH_FANIN 个文件 import 的模块（粗筛：找高频 import 目标）
      local hot
      hot=$(grep -rhoE "from ['\"][^'\"]+['\"]" "$wd" --include='*.ts' --include='*.js' 2>/dev/null \
        | sed "s/.*['\"]//;s/['\"]$//" | sort | uniq -c | sort -rn \
        | awk -v th="$COG_STRENGTH_FANIN" '$1>th{c++} END{print c+0}' || true)
      strong_files=$((strong_files + ${hot:-0}))
    done
    echo "    强度：${strong_files} 个高 fan-in 模块（被 >${COG_STRENGTH_FANIN} 处引用）", "$([[ "$strong_files" -gt 3 ]] && echo "⚠ 强依赖集中" || echo "强度分散")"
  fi

  # 能耗：巨型文件数（store/组件）
  local energy_val=0
  [[ -n "$STORE_DIR" && "$MAX_STORE_LINES" -gt 0 ]] && energy_val=$(find "$STORE_DIR" -type f \( -name '*.ts' -o -name '*.js' \) 2>/dev/null | while read -r f; do wc -l < "$f"; done | awk -v th="$MAX_STORE_LINES" '$1>th{c++} END{print c+0}' || true)
  echo "    能耗：${energy_val:-0} 个巨型 store 文件（>${MAX_STORE_LINES} 行，认知负荷高）"

  # 累积量：TODO/FIXME 累积
  local cumul_val=0
  if [[ "$COG_CUMULATIVE_TODO" -gt 0 && ${#WRITABLE_DIRS[@]} -gt 0 ]]; then
    cumul_val=$(_scan_src 'TODO|FIXME|HACK|XXX' 'ts,js,py' 'node_modules\|\.patch' "${WRITABLE_DIRS[@]+"${WRITABLE_DIRS[@]}"}" | wc -l | xargs || true)
    echo "    累积量：${cumul_val} 处 TODO/FIXME", "$([[ "$cumul_val" -gt "$COG_CUMULATIVE_TODO" ]] && echo "⚠ 技术债累积过载（>${COG_CUMULATIVE_TODO}）" || echo "正常")"
  fi

  # ---- 认知总结 ----
  echo ""
  local total_score=$((concept_score + struct_score + space_score + map_score + handle_score))
  echo "  ── 认知递进总结（第一层）──"
  echo "    ①概念(${concept_score}/2) → ②结构(${struct_score}/3) → ③空间(${space_score}/3) → ④映射(${map_score}/3) → ⑤规律(${rule_count}条) → ⑥处理(${handle_score}/3)"
  echo "    认知总分：${total_score}/14 + ${rule_count} 条规律编码"
  if [[ $total_score -ge 8 && $rule_count -ge 4 ]]; then
    pass "第一层认知递进完整（${total_score}/14 + ${rule_count} 条规律）——关系脉络清晰，可处理关系而非仅计数"
  elif [[ $total_score -ge 5 ]]; then
    warn "第一层认知递进部分建立（${total_score}/14）——存在认知断层，建议补全缺失阶（见上表 ⚠ 项）"
  else
    warn "第一层认知递进不足（${total_score}/14）——概念/结构/空间未显式定义，门禁沦为计数，建议先建立 ①概念定义"
  fi

  # ---- 五层认知基底完整性检查（第二/三/四/五层）----
  echo ""
  echo "  ── 五层认知基底完整性（第一层 + 第二/三/四/五层）──"
  local layer2_score=0 layer3_score=0 layer4_score=0

  # 第二层：思维语言框架——spec 含三导向段（§1.1现状/§1.2目标/§14交付衰减/§15蓝图）
  local spec_for_cog="${SPEC_FILE:-}"
  [[ -z "$spec_for_cog" ]] && spec_for_cog=$(_first_existing_file "spec-template.md" "specs/spec-template.md" "docs/spec-template.md")
  if [[ -n "$spec_for_cog" && -f "$spec_for_cog" ]]; then
    # 强化：要求 §14/§15 章节标题存在（非仅关键词），且段落有实质内容
    grep -qE '^## 14\..*交付衰减' "$spec_for_cog" 2>/dev/null && layer2_score=$((layer2_score+1))
    grep -qE '^## 15\..*蓝图' "$spec_for_cog" 2>/dev/null && layer2_score=$((layer2_score+1))
    # §1.1 现状须含"痛点/根因/溯因"之一（实质内容，非仅标题）
    awk '/^## 1\.1|^### 1\.1/{in_sec=1} /^## [0-9]/{if(in_sec)in_sec=0} in_sec && /痛点|根因|溯因|为什么/{found=1} END{exit !found}' "$spec_for_cog" 2>/dev/null && layer2_score=$((layer2_score+1))
    echo "    第二层(思维语言)：spec §14交付衰减/§15蓝图/§1.1现状溯因 ${layer2_score}/3"
  else
    warn "第二层(思维语言)：未找到 spec，三导向段无法检查"
  fi

  # 第三层：认知辩证——reference-manual 含逻辑谬误图谱 + spec 含思维模型对照
  if [[ -n "$rm_file" ]]; then
    # 须含 2+ 个剃刀/谬误信号（非仅一个关键词）
    local l3_hits=0
    grep -qiE '逻辑剃刀|谬误图谱' "$rm_file" 2>/dev/null && l3_hits=$((l3_hits+1))
    grep -qiE '对抗审查|灵魂拷问|降维反驳' "$rm_file" 2>/dev/null && l3_hits=$((l3_hits+1))
    [[ $l3_hits -ge 2 ]] && layer3_score=$((layer3_score+1))
  fi
  if [[ -n "$spec_for_cog" && -f "$spec_for_cog" ]]; then
    # spec §16.2 思维模型对照须有实际表格行（非仅标题）
    awk '/思维模型对照/{in_sec=1} in_sec && /^\|[^|]+\|[^|]+\|/{row++} in_sec && /^### /{if(in_sec&&row>0){found=1}} END{exit !found}' "$spec_for_cog" 2>/dev/null && layer3_score=$((layer3_score+1))
  fi
  echo "    第三层(认知辩证)：reference-manual 逻辑剃刀+谬误图谱(2+信号) + spec §16.2 思维模型对照(有行) ${layer3_score}/2"

  # 第四层：认知偏差防范——spec §16 认知偏差自检段须有实质内容
  if [[ -n "$spec_for_cog" && -f "$spec_for_cog" ]]; then
    # §16 章节标题存在 + 五维偏差表有行
    grep -qE '^## 16\..*认知偏差自检' "$spec_for_cog" 2>/dev/null && layer4_score=$((layer4_score+1))
    # 偏差扫描表须含"感知/记忆/社会/决策/元认知"至少 3 维
    local bias_dims=0
    grep -qiE '感知.*确认偏误|确认偏误.*感知' "$spec_for_cog" 2>/dev/null && bias_dims=$((bias_dims+1))
    grep -qiE '决策.*沉没成本|沉没成本.*决策' "$spec_for_cog" 2>/dev/null && bias_dims=$((bias_dims+1))
    grep -qiE '元认知.*达克|达克.*元认知' "$spec_for_cog" 2>/dev/null && bias_dims=$((bias_dims+1))
    [[ $bias_dims -ge 2 ]] && layer4_score=$((layer4_score+1))
  fi
  echo "    第四层(偏差防范)：spec §16 章节存在 + 五维偏差表(≥2维有内容) ${layer4_score}/2"

  # ---- 第五层：辩证认知——reference-manual 含辩证映射表 ----
  local layer5_score=0
  if [[ -n "$rm_file" ]]; then
    # 检查含"辩证映射表"或 7 对辩证关系中的 ≥3 对
    local dialectic_hits=0
    grep -qiE '辩证映射表|辩证关系|辩证认知' "$rm_file" 2>/dev/null && dialectic_hits=$((dialectic_hits+1))
    grep -qiE '内容与形式|内容.*形式.*辩证' "$rm_file" 2>/dev/null && dialectic_hits=$((dialectic_hits+1))
    grep -qiE '原因与结果|因果.*辩证' "$rm_file" 2>/dev/null && dialectic_hits=$((dialectic_hits+1))
    grep -qiE '必然与偶然|必然.*偶然' "$rm_file" 2>/dev/null && dialectic_hits=$((dialectic_hits+1))
    grep -qiE '现实与可能|现实.*可能' "$rm_file" 2>/dev/null && dialectic_hits=$((dialectic_hits+1))
    grep -qiE '实践与认识|实践.*认识' "$rm_file" 2>/dev/null && dialectic_hits=$((dialectic_hits+1))
    grep -qiE '真理与谬误|真理.*谬误' "$rm_file" 2>/dev/null && dialectic_hits=$((dialectic_hits+1))
    grep -qiE '绝对.*相对.*真理|相对.*绝对.*真理' "$rm_file" 2>/dev/null && dialectic_hits=$((dialectic_hits+1))
    [[ $dialectic_hits -ge 3 ]] && layer5_score=1
  fi
  echo "    第五层(辩证认知)：reference-manual 辩证映射表+7对辩证关系(≥3对) ${layer5_score}/1"

  # 五层总评
  local five_layer_total=$((total_score + layer2_score + layer3_score + layer4_score + layer5_score))
  local five_layer_max=22  # 14 + 3 + 2 + 2 + 1
  echo "    五层认知基底总分：${five_layer_total}/${five_layer_max}"
  if [[ $five_layer_total -ge 15 ]]; then
    pass "五层认知基底完整（${five_layer_total}/${five_layer_max}）——本质(①-④)+实践认识(思维语言)+现象分析(逻辑剃刀)+真理边界(偏差防范)+辩证统一(7对范畴)"
  elif [[ $five_layer_total -ge 10 ]]; then
    warn "五层认知基底部分建立（${five_layer_total}/${five_layer_max}）——补全缺失层（见上表）"
  else
    warn "五层认知基底不足（${five_layer_total}/${five_layer_max}）——认知有系统性漏洞，建议先补第一层+第四层+第五层"
  fi
}

check_mermaid() {
  echo "=== Mermaid 可视化检查（架构图/流程图/调用链是否用 Mermaid）==="
  local found=0

  # 检查 reference-manual.md 是否含 mermaid 图
  local rm_file
  rm_file=$(_first_existing_file "references/reference-manual.md" "reference-manual.md" ".claude/skills/*/references/reference-manual.md")
  local has_mermaid=0
  if [[ -n "$rm_file" ]]; then
    grep -qiE '```mermaid|<mermaid' "$rm_file" 2>/dev/null && has_mermaid=1
  fi

  # 检查 spec-template.md 是否含 mermaid 引导
  local spec_file
  spec_file=$(_first_existing_file "spec-template.md" "specs/spec-template.md" "docs/spec-template.md")
  local spec_mermaid=0
  if [[ -n "$spec_file" ]]; then
    grep -qiE 'mermaid|架构图.*可视化|流程图.*Mermaid' "$spec_file" 2>/dev/null && spec_mermaid=1
  fi

  if [[ $has_mermaid -eq 1 ]]; then
    pass "reference-manual.md 含 Mermaid 可视化"
  else
    warn "reference-manual.md 未检测到 Mermaid 图——涉及架构/流程/调用链时须用 Mermaid 可视化（mermaid 代码块）"
  fi
  if [[ $spec_mermaid -eq 1 ]]; then
    pass "spec-template 含 Mermaid 引导"
  fi

  if [[ $found -eq 0 ]]; then
    pass "Mermaid 可视化检查通过"
  fi
}


# --operate：发布后运营验证（D 方向，warn 级 advisory——环境依赖型检查硬 fail 风险高）
# 检查：spec §23 灰度观察声明 / 健康检查端点可访问 / 告警阈值已配置 / runbook 已更新。
# 全未配置则跳过（与 advisory 姿态一致）；健康检查/告警/runbook 依赖部署环境，CI 不可达不硬 fail。
check_operate() {
  echo "=== 发布后运营（--operate，advisory）==="
  # ① spec §23 灰度观察声明
  local spec_f="${SPEC_FILE:-}"
  [[ -z "$spec_f" ]] && spec_f=$(_first_existing_file "docs/spec.md" "spec.md" "docs/spec-template.md" "spec-template.md")
  if [[ -n "$spec_f" && -f "$spec_f" ]]; then
    if grep -qE '## 23|发布后运营|灰度观察' "$spec_f" 2>/dev/null; then
      pass "spec 含 §23 发布后运营段（${spec_f}）"
    else
      warn "spec 缺 §23 发布后运营段（完整级别必填，D 方向研发全流程闭环）"
    fi
  else
    warn "未找到 spec 文件，跳过 §23 检查（可配 SPEC_FILE 启用）"
  fi
  # ② 健康检查端点（HEALTH_CHECK_URL 配置时 curl 探测，超时 5s）
  if [[ -n "${HEALTH_CHECK_URL:-}" ]]; then
    if command -v curl >/dev/null 2>&1; then
      if curl -sf --max-time 5 "$HEALTH_CHECK_URL" >/dev/null 2>&1; then
        pass "健康检查端点可访问（${HEALTH_CHECK_URL}）"
      else
        warn "健康检查端点不可达（${HEALTH_CHECK_URL}，环境依赖）"
      fi
    else
      warn "curl 不可用，跳过健康检查探测"
    fi
  fi
  # ③ 告警阈值配置（ALERT_CONFIG_FILE 存在且非空）
  if [[ -n "${ALERT_CONFIG_FILE:-}" ]]; then
    if [[ -s "$ALERT_CONFIG_FILE" ]]; then
      pass "告警阈值配置存在（${ALERT_CONFIG_FILE}）"
    else
      warn "告警配置文件缺失或为空：${ALERT_CONFIG_FILE}"
    fi
  fi
  # ④ runbook（RUNBOOK_FILE 存在）
  if [[ -n "${RUNBOOK_FILE:-}" ]]; then
    if [[ -f "$RUNBOOK_FILE" ]]; then
      pass "runbook 存在（${RUNBOOK_FILE}）"
    else
      warn "runbook 缺失：${RUNBOOK_FILE}"
    fi
  fi
  # 全未配置 → 跳过提示
  if [[ -z "${HEALTH_CHECK_URL:-}${ALERT_CONFIG_FILE:-}${RUNBOOK_FILE:-}" ]]; then
    echo "  (operate 监控项未配置，跳过——可配 HEALTH_CHECK_URL/ALERT_CONFIG_FILE/RUNBOOK_FILE 启用)"
  fi
}

# --decision-audit：决策审计轨迹完整性检查（G1 C 档，warn 级 advisory）
# 检查 .swarm-yuan/decisions.jsonl：① 每行 JSON 合法 ② UserChallenge 行五要素非空
# ③ 每阶段≥1 决策（有 phase 字段的行）。对齐 ISO/IEC 42001 人工监督留痕。
# 姿态：warn 级（决策留痕缺失不阻断开发，只提示可审计性缺口）。
check_decision_audit() {
  echo "=== 决策审计轨迹完整性（--decision-audit，advisory）==="
  local dec_file="${PROJECT_DIR:-$(pwd)}/.swarm-yuan/decisions.jsonl"
  if [[ ! -f "$dec_file" ]]; then
    warn "decisions.jsonl 不存在（决策未留痕，G1 决策治理；生成流程 draft 期可空）"
    return 0
  fi
  if [[ ! -s "$dec_file" ]]; then
    echo "  ℹ decisions.jsonl 存在但为空（draft 期允许）"
    return 0
  fi
  # ①② 逐行 JSON 合法性 + UserChallenge 五要素（有 python3 用 json.loads，无则 grep 降级）
  local issues=0
  if command -v python3 >/dev/null 2>&1; then
    local py_out
    py_out=$(python3 -c '
import sys, json
phases=set()
for i, line in enumerate(sys.stdin, 1):
    line=line.strip()
    if not line: continue
    try: obj=json.loads(line)
    except Exception as e:
        print("%d: 非法JSON (%s)" % (i, e)); continue
    if obj.get("phase"): phases.add(obj["phase"])
    if obj.get("type")=="UserChallenge":
        for k in ("alternatives","missing_context","cost_if_wrong"):
            if not obj.get(k): print("%d: UserChallenge 缺 %s" % (i, k))
print("PHASES:"+",".join(sorted(phases)) if phases else "PHASES:none")
' < "$dec_file" 2>/dev/null || true)
    # 提取问题行（非 PHASES 行）
    local problems
    problems=$(printf '%s\n' "$py_out" | grep -v '^PHASES:' || true)
    if [[ -n "$problems" ]]; then
      issues=$(printf '%s\n' "$problems" | grep -c . || true)
      printf '%s\n' "$problems" | while IFS= read -r p; do warn "decisions.jsonl:$p"; done
    fi
    local phases
    phases=$(printf '%s\n' "$py_out" | grep '^PHASES:' | sed 's/^PHASES://')
    [[ "$phases" != "none" && -n "$phases" ]] && pass "决策覆盖阶段：$phases"
  else
    # 降级：grep 字段存在性
    local ln=0 dline
    while IFS= read -r dline; do
      ln=$((ln + 1))
      echo "$dline" | grep -q '"type"' || { warn "decisions.jsonl:$ln: 非法JSON（缺 type）"; issues=$((issues+1)); continue; }
      echo "$dline" | grep -q '"type":"UserChallenge"' || continue
      for k in alternatives missing_context cost_if_wrong; do
        echo "$dline" | grep -q "\"$k\"" || { warn "decisions.jsonl:$ln: UserChallenge 缺 $k"; issues=$((issues+1)); }
      done
    done < "$dec_file"
  fi
  # 汇总
  local total
  total=$(grep -c . "$dec_file" 2>/dev/null || echo 0)
  if [[ "$issues" -eq 0 ]]; then
    pass "决策审计轨迹完整（${total} 条决策，JSON 合法 + UserChallenge 五要素齐备）"
  else
    warn "决策审计轨迹有 ${issues} 处完整性缺口（共 ${total} 条决策）"
  fi
}

# --canary：发布后基线对比监控（A 方向，gstack canary 吸收，warn 级 advisory）
# 哲学："alert on changes, not absolutes"（告警变化非绝对值）+ "don't cry wolf"（连续 2 次才告警）。
# 记录发布后健康指标（响应时间/错误率）基线到 .swarm-yuan/canary-baseline.jsonl，
# check_learnings（--learnings，WP-W）：learn 闭环——检查 .swarm-yuan/learnings.jsonl
# 存在且对近期 fail 门禁有对应学习记录。advisory 级，不阻断交付。
# 理念来源：gstack learn 的 learnings.jsonl + 置信度 + operational self-improvement 闭环（R5 §七.4）。
check_learnings() {
  echo "=== 学习闭环检查（--learnings，advisory）==="
  local learn_file="${PROJECT_DIR:-$(pwd)}/.swarm-yuan/learnings.jsonl"
  if [[ ! -f "$learn_file" ]]; then
    warn "learnings.jsonl 不存在（学习未留痕；R5 learn 闭环——建议对近期 门禁失败记录根因与修复模式）"
    return 0
  fi
  if [[ ! -s "$learn_file" ]]; then
    echo "  ℹ learnings.jsonl 存在但为空（尚无学习记录）"
    return 0
  fi
  # 检查 JSONL 合法性 + 近 30 天记录覆盖率
  local issues=0 total=0 recent=0
  if command -v python3 >/dev/null 2>&1; then
    local py_out
    py_out=$(python3 -c '
import sys, json, time
now = time.time()
total = 0
recent = 0
for i, line in enumerate(sys.stdin, 1):
    line = line.strip()
    if not line: continue
    total += 1
    try:
        obj = json.loads(line)
    except Exception:
        print("%d: 非法JSON" % i); continue
    ts = obj.get("ts", "")
    if ts:
        try:
            t = time.mktime(time.strptime(ts[:19], "%Y-%m-%dT%H:%M:%S"))
            if now - t < 30 * 86400: recent += 1
        except Exception: pass
    for k in ("gate", "root_cause", "fix_pattern"):
        if not obj.get(k):
            print("%d: 缺 %s 字段" % (i, k)); break
print("TOTAL:%d RECENT:%d" % (total, recent))
' < "$learn_file" 2>/dev/null || true)
    while IFS= read -r ln; do
      [[ -z "$ln" ]] && continue
      case "$ln" in
        TOTAL:*)
          total=$(echo "$ln" | sed 's/.*TOTAL:\([0-9]*\).*/\1/')
          recent=$(echo "$ln" | sed 's/.*RECENT:\([0-9]*\)/\1/')
          ;;
        *) echo "  ⚠ $ln"; issues=$((issues+1));;
      esac
    done <<< "$py_out"
  else
    # 无 python3 降级：只查行数和非空
    total=$(grep -c . "$learn_file" 2>/dev/null || echo 0)
    echo "  ℹ 无 python3，降级为行数检查（${total} 条记录）"
  fi
  if [[ "$total" -gt 0 && "$recent" -eq 0 ]]; then
    warn "learnings.jsonl 有 ${total} 条记录但近 30 天无新增——学习闭环停滞（R5 learn：门禁失败应触发根因记录）"
  elif [[ "$total" -gt 0 ]]; then
    echo "  ✓ 学习闭环活跃（${total} 条记录，近 30 天 ${recent} 条）"
  fi
  if [[ $issues -eq 0 ]]; then
    pass "学习闭环检查通过（learnings.jsonl 格式合法，${total} 条记录）"
  fi
}

# check_state_phase（--state-phase，WP-X）：comet 硬前置——阶段状态机证据核验
# 理念来源：comet "无证据不流转"（R6 P0）。advisory 级（warn-only），不阻断交付。
# 检查 .swarm-yuan/state.json 存在且当前阶段有 evidence 记录。
check_state_phase() {
  echo "=== 阶段状态机证据核验（--state-phase，advisory；comet 理念：无证据不流转）==="
  local state_file="${PROJECT_DIR:-$(pwd)}/.swarm-yuan/state.json"
  if [[ ! -f "$state_file" ]]; then
    warn "state.json 不存在（comet 风格状态机未初始化；建议用 state-machine.sh init 初始化变更状态跟踪）"
    return 0
  fi
  if [[ ! -s "$state_file" ]]; then
    echo "  ℹ state.json 存在但为空（draft 期允许）"
    return 0
  fi
  # 解析 JSON：当前阶段 + evidence 字段
  local issues=0 phase="" has_evidence=0
  if command -v python3 >/dev/null 2>&1; then
    local py_out
    py_out=$(python3 -c '
import sys, json
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
except Exception as e:
    print("PARSE_ERROR: " + str(e)); sys.exit(0)
phase = data.get("current_phase") or data.get("phase") or ""
evidence = data.get("evidence") or data.get("phase_evidence") or {}
if not phase:
    print("MISSING_PHASE")
else:
    print("PHASE:" + phase)
    if isinstance(evidence, dict):
        for ph, ev in evidence.items():
            if not ev:
                print("NO_EVIDENCE:" + ph)
    elif isinstance(evidence, list):
        if len(evidence) == 0:
            print("NO_EVIDENCE:" + phase)
    elif not evidence:
        print("NO_EVIDENCE:" + phase)
    else:
        print("HAS_EVIDENCE")
' "$state_file" 2>/dev/null || true)
    while IFS= read -r ln; do
      [[ -z "$ln" ]] && continue
      case "$ln" in
        PARSE_ERROR:*) echo "  ⚠ state.json JSON 解析失败：${ln#PARSE_ERROR: }"; issues=$((issues+1));;
        MISSING_PHASE*) echo "  ⚠ state.json 缺 current_phase 字段"; issues=$((issues+1));;
        PHASE:*) phase="${ln#PHASE:}";;
        NO_EVIDENCE:*) echo "  ⚠ 阶段 ${ln#NO_EVIDENCE:} 无 evidence 记录（comet：无证据不流转）"; issues=$((issues+1));;
        HAS_EVIDENCE*) has_evidence=1;;
      esac
    done <<< "$py_out"
  else
    # 无 python3 降级：grep 检查关键字段
    phase=$(grep -oE '"current_phase"\s*:\s*"[^"]*"' "$state_file" 2>/dev/null | head -1 || true)
    [[ -z "$phase" ]] && { echo "  ⚠ state.json 缺 current_phase 字段"; issues=$((issues+1)); }
    grep -qE '"evidence"' "$state_file" 2>/dev/null || { echo "  ⚠ state.json 无 evidence 字段"; issues=$((issues+1)); }
  fi
  if [[ $issues -eq 0 ]]; then
    if [[ -n "$phase" ]]; then
      pass "阶段状态机证据核验通过（当前阶段：${phase#PHASE:}，evidence 在案）"
    else
      pass "阶段状态机证据核验通过"
    fi
  fi
}

# check_upstream_baseline（--upstream-baseline，WP-X）：上游运行时基线 drift 核验
# 理念来源：R6 §上游基线漂移（comet/graphify/ruflo 版本落后）。
# 检查 docs/upstream-baseline.md 的 baseline_status 标记，drifted 项 warn。
check_upstream_baseline() {
  echo "=== 上游运行时基线 drift 核验（--upstream-baseline，advisory）==="
  local bl_file="${PROJECT_DIR:-$(pwd)}/docs/upstream-baseline.md"
  if [[ ! -f "$bl_file" ]]; then
    # 兜底：SKILL_DIR/../docs/
    local _sd="${SKILL_DIR:-${_CONF_DIR:-$(pwd)}/..}"
    bl_file="${_sd}/docs/upstream-baseline.md"
  fi
  if [[ ! -f "$bl_file" ]]; then
    warn "upstream-baseline.md 不存在（上游运行时版本基线未登记）"
    return 0
  fi
  local drifted=0 synced=0 watch=0 license_risk=0
  # 扫 baseline_status= 标记
  while IFS= read -r ln; do
    [[ -z "$ln" ]] && continue
    case "$ln" in
      *baseline_status=synced*) synced=$((synced+1));;
      *baseline_status=drifted*) drifted=$((drifted+1));;
      *baseline_status=watch*) watch=$((watch+1));;
      *baseline_status=license-risk*) license_risk=$((license_risk+1));;
    esac
  done < "$bl_file" 2>/dev/null
  echo "  ⓘ 上游基线：synced=${synced} drifted=${drifted} watch=${watch} license-risk=${license_risk}"
  if [[ $drifted -gt 0 ]]; then
    warn "上游运行时 ${drifted} 项 drifted（引用基线落后上游最新版）——建议重核并更新基线"
    grep -nE 'baseline_status=drifted' "$bl_file" 2>/dev/null | head -5 | sed 's/^/    /'
  fi
  if [[ $license_risk -gt 0 ]]; then
    warn "上游运行时 ${license_risk} 项 license-risk（许可证冲突风险）——须法务评估"
    grep -nE 'baseline_status=license-risk' "$bl_file" 2>/dev/null | head -5 | sed 's/^/    /'
  fi
  if [[ $drifted -eq 0 && $license_risk -eq 0 ]]; then
    pass "上游运行时基线核验通过（${synced} synced / ${watch} watch，无 drift 无 license-risk）"
  fi
}

# check_pr_quality（--pr-quality，WP-Y）：PR 质量评分 + fingerprint 去重
# 理念来源：gstack PR Quality Score + fingerprint 去重 +1 boost / Red Team（R5 §七.4）。
# advisory 级（warn-only）。轻量实现：从 git diff 计算变更规模 + 重复模式检测。
check_pr_quality() {
  echo "=== PR 质量评分（--pr-quality，advisory；gstack 理念：变更规模 + 重复模式检测）==="
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    warn "非 git 仓库，PR 质量评分跳过"
    return 0
  fi
  local found=0
  # ① 变更规模评分（行数/文件数）
  local diff_stat; diff_stat=$(git diff --cached --stat 2>/dev/null || git diff --stat 2>/dev/null || true)
  if [[ -z "$diff_stat" ]]; then
    # 无 staged 变更，检查 working tree
    diff_stat=$(git diff --stat 2>/dev/null || true)
  fi
  if [[ -z "$diff_stat" ]]; then
    echo "  ℹ 无变更（clean working tree），PR 质量评分跳过"
    return 0
  fi
  local files_changed; files_changed=$(echo "$diff_stat" | grep -cE '^\s' || true)
  local lines_added=0 lines_deleted=0
  local diff_numstat; diff_numstat=$(git diff --cached --numstat 2>/dev/null || git diff --numstat 2>/dev/null || true)
  while IFS=$'\t' read -r add del _f; do
    [[ "$add" =~ ^[0-9]+$ ]] && lines_added=$((lines_added + add))
    [[ "$del" =~ ^[0-9]+$ ]] && lines_deleted=$((lines_deleted + del))
  done <<< "$diff_numstat"
  local total_lines=$((lines_added + lines_deleted))
  echo "  ⓘ 变更规模：${files_changed} 文件，+${lines_added}/-${lines_deleted}（合计 ${total_lines} 行）"
  # 规模评分：>500 行 warn（大型变更须拆分）
  if [[ $total_lines -gt 500 ]]; then
    warn "PR 变更规模 ${total_lines} 行（>500）——大型变更建议拆分为多个小 PR（gstack：小 PR 质量更高）"
    found=1
  fi
  # ② fingerprint 去重：检测重复代码模式（相同函数签名跨文件）
  if [[ $files_changed -gt 1 ]]; then
    local changed_files; changed_files=$(git diff --cached --name-only 2>/dev/null || git diff --name-only 2>/dev/null || true)
    local dup_funcs=""
    while IFS= read -r cf; do
      [[ -z "$cf" ]] && continue
      [[ -f "$cf" ]] || continue
      case "$cf" in
        *.ts|*.js|*.py|*.java|*.go|*.kt|*.cs|*.c|*.cpp)
          local funcs; funcs=$(grep -oE '\b(function|def|func|public|private|protected)\s+[a-zA-Z_][a-zA-Z0-9_]*' "$cf" 2>/dev/null || true)
          [[ -n "$funcs" ]] && dup_funcs="${dup_funcs}${funcs}\n"
          ;;
      esac
    done <<< "$changed_files"
    # 检测重复函数名
    if [[ -n "$dup_funcs" ]]; then
      local dups; dups=$(printf '%b\n' "$dup_funcs" | sort | uniq -d | head -5 || true)
      if [[ -n "$dups" ]]; then
        warn "检出重复函数签名跨文件（fingerprint 去重）：
$(printf '%s\n' "$dups" | head -3 | sed 's/^/    /')"
        found=1
      fi
    fi
  fi
  # ③ Red Team 检查：spec 是否含"替代方案"段（gstack Red Team：考虑替代方案）
  local spec_file="${SPEC_FILE:-}"
  if [[ -n "$spec_file" && -f "$spec_file" ]]; then
    if ! grep -qE '替代方案|alternative|备选|trade.off|权衡' "$spec_file" 2>/dev/null; then
      warn "spec 未含'替代方案/权衡'段（gstack Red Team：每个设计决策须考虑替代方案）"
      found=1
    fi
  fi
  [[ $found -eq 0 ]] && pass "PR 质量评分通过（规模合理，无重复模式，含替代方案）"
}

# check_skill_supply_chain（--skill-supply-chain，WP-Y）：Skill 供应链安全审计
# 理念来源：cso Phase 8 Skill Supply Chain（R5 §七.4）。advisory 级。
# 扫描 .claude/skills/ 下第三方 skill 的已知恶意模式。
check_skill_supply_chain() {
  echo "=== Skill 供应链安全审计（--skill-supply-chain，advisory；cso P8 理念）==="
  local skills_dir="${PROJECT_DIR:-$(pwd)}/.claude/skills"
  if [[ ! -d "$skills_dir" ]]; then
    # 兜底：~/.claude/skills
    skills_dir="${HOME}/.claude/skills"
  fi
  if [[ ! -d "$skills_dir" ]]; then
    echo "  ℹ 无 .claude/skills 目录，Skill 供应链审计跳过"
    return 0
  fi
  local found=0
  # ① 恶意模式扫描：eval/exec/反引号 + 网络请求（curl/wget/fetch）的组合
  local suspicious_files=""
  local skill_sh
  while IFS= read -r skill_sh; do
    [[ -z "$skill_sh" ]] && continue
    # 检测 eval/exec + 网络请求组合
    if grep -qE '\beval\s*\(' "$skill_sh" 2>/dev/null && grep -qE 'curl\s|wget\s|fetch\(' "$skill_sh" 2>/dev/null; then
      suspicious_files="${suspicious_files}${skill_sh}: eval+网络请求\n"
      found=1
    fi
    # 检测混淆代码（base64 解码后执行）
    if grep -qE 'base64.*decode.*\|.*bash|base64.*-d.*\|.*sh' "$skill_sh" 2>/dev/null; then
      suspicious_files="${suspicious_files}${skill_sh}: base64 混淆执行\n"
      found=1
    fi
    # 检测硬编码外部 URL + 下载执行
    if grep -qE 'curl.*\|.*bash|wget.*\|.*sh' "$skill_sh" 2>/dev/null; then
      suspicious_files="${suspicious_files}${skill_sh}: 远程脚本下载执行\n"
      found=1
    fi
  done < <(find "$skills_dir" -name '*.sh' -type f 2>/dev/null || true)
  if [[ -n "$suspicious_files" ]]; then
    warn "检出 Skill 供应链可疑模式（cso P8：恶意 skill 可能利用 eval/网络请求/混淆执行）：
$(printf '%b\n' "$suspicious_files" | head -5 | sed 's/^/    /')"
  fi
  # ② UPSTREAM.md / 许可证登记检查（warn-only）
  local upstream_count
  upstream_count=$(find "$skills_dir" -name 'UPSTREAM.md' -o -name 'LICENSE' 2>/dev/null | wc -l | xargs || true)
  local total_skills
  total_skills=$(find "$skills_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | xargs || true)
  if [[ $total_skills -gt 0 && $upstream_count -lt $total_skills ]]; then
    warn "Skills 目录有 ${total_skills} 个 skill 但仅 ${upstream_count} 个有 UPSTREAM.md/LICENSE——供应链溯源不完整"
    found=1
  fi
  [[ $found -eq 0 ]] && pass "Skill 供应链安全审计通过（无恶意模式，溯源登记完整）"
}

# 记录发布后健康指标（响应时间/错误率）基线到 .swarm-yuan/canary-baseline.jsonl，
check_canary() {
  echo "=== 发布后基线对比监控（--canary，advisory）==="
  local baseline="${PROJECT_DIR:-$(pwd)}/.swarm-yuan/canary-baseline.jsonl"
  # 当前指标（可配 CANARY_LATENCY_MS 当前响应时间毫秒 / CANARY_ERROR_RATE 当前错误率 0-1）
  local lat="${CANARY_LATENCY_MS:-}" err="${CANARY_ERROR_RATE:-}"
  if [[ -z "$lat" && -z "$err" ]]; then
    echo "  (未提供当前指标——设 CANARY_LATENCY_MS/CANARY_ERROR_RATE 后重跑；首次运行建立基线)"
    # 首次运行：若基线不存在且提供了指标则建立
    [[ ! -f "$baseline" ]] && echo "  ℹ 无基线——首次提供指标后建立"
    return 0
  fi
  mkdir -p "$(dirname "$baseline")" 2>/dev/null
  local ts; ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  # 读上次基线
  local prev_lat="" prev_err=""
  if [[ -f "$baseline" ]]; then
    prev_lat=$(tail -1 "$baseline" | sed -E 's/.*"latency_ms":([0-9]+).*/\1/' 2>/dev/null)
    prev_err=$(tail -1 "$baseline" | sed -E 's/.*"error_rate":([0-9.]+).*/\1/' 2>/dev/null)
  fi
  # 追加当前基线
  printf '{"ts":"%s","latency_ms":%s,"error_rate":%s}\n' "$ts" "${lat:-0}" "${err:-0}" >> "$baseline"
  # 对比上次基线（变化 >CANARY_THRESHOLD% 记异常，默认 50%）
  local threshold="${CANARY_THRESHOLD:-50}"
  local anomaly=0
  if [[ -n "$prev_lat" && "$prev_lat" -gt 0 && -n "$lat" ]]; then
    local delta=$(( (lat - prev_lat) * 100 / prev_lat ))
    [[ "$delta" -lt 0 ]] && delta=$(( -delta ))
    if [[ "$delta" -gt "$threshold" ]]; then
      anomaly=1
      echo "  ⚠ 响应时间变化 ${delta}%（${prev_lat}ms → ${lat}ms，阈值 ${threshold}%）"
    fi
  fi
  # don't cry wolf：连续 2 次异常才告警（读最近 2 次基线趋势）
  if [[ "$anomaly" -eq 1 ]]; then
    local consec
    consec=$(tail -2 "$baseline" | grep -c . || echo 0)
    # 简化：本次异常即 warn（连续判定需历史趋势，基线初期单次也提示）
    warn "canary 基线异常：响应时间变化超阈值（alert on changes；连续异常须人工复核趋势）"
  elif [[ -z "$prev_lat" ]]; then
    pass "canary 基线已建立（首次记录 latency=${lat:-0}ms error_rate=${err:-0}）"
  else
    pass "canary 基线对比正常（latency ${prev_lat}ms → ${lat:-0}ms，变化 <${threshold}%）"
  fi
}

# --cwe-audit：CWE 元数据库对账（B 方向完整分级，advisory）
# 检查仓库内所有 CWE-[0-9]+ 标注是否在 cwe-database.md 登记 + 每条有检查点 + 严重度分级。
# 对齐 ISO/IEC 5055:2021 / GB/T 34943 / CWE Top 25:2025。
check_cwe_audit() {
  echo "=== CWE 元数据库对账（--cwe-audit，advisory）==="
  local base="${PROJECT_DIR:-$(pwd)}"
  # 生成器自身：base=swarm-yuan/；目标 skill：base=项目根（references/cwe-database.md 拷贝自生成器）
  local cwe_db=""
  for cand in "$base/references/cwe-database.md" "$base/swarm-yuan/references/cwe-database.md"; do
    [[ -f "$cand" ]] && cwe_db="$cand" && break
  done
  if [[ -z "$cwe_db" ]]; then
    warn "cwe-database.md 不存在（CWE 元数据库未生成）"
    return 0
  fi
  local db_cwes
  db_cwes=$(grep -oE 'CWE-[0-9]+' "$cwe_db" | sort -u)
  local db_cnt; db_cnt=$(echo "$db_cwes" | grep -c . || true)
  echo "  cwe-database.md 登记条目: ${db_cnt} 条"

  # 收集仓库内所有 CWE 标注（框架规则 md + framework-gates + security-spec）
  local scan_dirs=()
  for d in "$base/references/frameworks" "$base/swarm-yuan/references/frameworks" "$base/references" "$base/swarm-yuan/references" "$base/assets/framework-gates" "$base/swarm-yuan/assets/framework-gates"; do
    [[ -d "$d" ]] && scan_dirs+=("$d")
  done
  local repo_cwes="" _found
  for d in ${scan_dirs[@]+"${scan_dirs[@]}"}; do
    _found=$(grep -rhoE 'CWE-[0-9]+' "$d"/*.md "$d"/*.sh 2>/dev/null || true)
    [[ -n "$_found" ]] && repo_cwes="${repo_cwes}${repo_cwes:+$'\n'}$_found"
  done
  # security-spec.md 也扫
  for f in "$base/references/security-spec.md" "$base/swarm-yuan/references/security-spec.md"; do
    [[ -f "$f" ]] && repo_cwes="${repo_cwes}${repo_cwes:+$'\n'}$(grep -oE 'CWE-[0-9]+' "$f" 2>/dev/null || true)"
  done
  repo_cwes=$(echo "$repo_cwes" | sort -u | grep . || true)
  local repo_cnt; repo_cnt=$(echo "$repo_cwes" | grep -c . || true)
  echo "  仓库内 CWE 标注（去重）: ${repo_cnt} 条"

  # 对账：仓库内有但数据库无 → 未登记
  local unregistered=0
  local cwe
  while IFS= read -r cwe; do
    [[ -z "$cwe" ]] && continue
    if ! echo "$db_cwes" | grep -qxF "$cwe"; then
      warn "CWE 未在 cwe-database.md 登记: $cwe"
      unregistered=$((unregistered + 1))
    fi
  done <<< "$repo_cwes"

  # 数据库有但仓库无 → 无检查点（孤儿条目）
  local orphans=0
  while IFS= read -r cwe; do
    [[ -z "$cwe" ]] && continue
    if ! echo "$repo_cwes" | grep -qxF "$cwe"; then
      orphans=$((orphans + 1))
    fi
  done <<< "$db_cwes"

  if [[ "$unregistered" -eq 0 && "$orphans" -eq 0 ]]; then
    pass "CWE 元数据库对账通过（${db_cnt} 条全登记 + 全有检查点，ISO 5055/GB 34943 对齐）"
  else
    [[ "$unregistered" -gt 0 ]] && warn "${unregistered} 条 CWE 标注未在 cwe-database.md 登记"
    [[ "$orphans" -gt 0 ]] && echo "  ℹ ${orphans} 条 CWE 在数据库登记但仓库无标注（文档级锚点，非缺陷）"
  fi
}

# --cert-audit：安全认证合规聚合门禁（等保4级/BCP5级/GB22240/PCI-DSS/ISO27001）
# 按 CERT_PROFILE 配置，聚合检查各认证标准的可机器化项 + 列出人工核对清单。
# 详见 references/security-certification-profiles.md。
# 姿态：聚合调度现有门禁（--crypto/--privacy/--security/--authz/--sbom/--shift-left/--operate/--compliance），
#       按认证标准要求组合检查 + 人工核对项 warn 提示。advisory 级（不重复各门禁的 fail 逻辑）。
check_cert_audit() {
  echo "=== 安全认证合规聚合（--cert-audit，advisory）==="
  local profile="${CERT_PROFILE:-}"
  if [[ -z "$profile" ]]; then
    echo "  (CERT_PROFILE 未配置——可选：dengbao4|bcp5|gb22240|jrt0142|pcidss|iso27001|all)"
    echo "  配置后在 precheck.compliance.conf 设 CERT_PROFILE 或环境变量传入"
    return 0
  fi
  local spec_f="${SPEC_FILE:-}"
  local has_spec=0
  [[ -n "$spec_f" && -f "$spec_f" ]] && has_spec=1
  local checks=0 warns=0

  _cert_check() { # $1=检查项名 $2=关联门禁 $3=状态(pass/warn/fail) $4=说明
    checks=$((checks + 1))
    case "$3" in
      pass) echo "  ✓ [$1] $2: $4" ;;
      warn) warns=$((warns + 1)); echo "  ⚠ [$1] $2: $4" ;;
      *)    warns=$((warns + 1)); echo "  ✗ [$1] $2: $4" ;;
    esac
  }

  # 等保4级（dengbao4）
  if [[ "$profile" == "dengbao4" || "$profile" == "all" ]]; then
    echo "--- 等保4级（GB/T 22239-2019 9.1.4.x）---"
    _cert_check "数据保密性" "--crypto" "pass" "须 CRYPTO_PROFILE=gm 启用国密 SM4 加密（9.1.4.8），运行 --crypto 联检"
    _cert_check "个人信息保护" "--privacy+--crypto" "pass" "须 --privacy 扫描 + 密码技术保护（9.1.4.11）"
    _cert_check "数据完整性" "--crypto" "warn" "国密 SM3 哈希正向核查（9.1.4.7），须 CRYPTO_PROFILE=gm"
    _cert_check "审计日志留存" "--shift-left" "warn" "spec §21 须声明日志留存≥6个月 + 异地实时备份（9.1.4.3）"
    _cert_check "灾备恢复等级" "--shift-left" "warn" "spec §20 须声明灾备≥4级（9.1.4.9，联动 BCP5级）"
    _cert_check "强制访问控制MAC" "人工核对" "warn" "9.1.4.2 MAC 是 OS/DB 层——人工核对策略配置"
    _cert_check "入侵检测IDS" "人工核对" "warn" "9.1.4.4 HIDS/NIDS 是运行态设施——人工核对"
    _cert_check "可信验证TPM" "人工核对" "warn" "9.1.4.6 可信根是硬件级——人工核对 TPM/TCM 实现"
    _cert_check "介质剩余信息" "人工核对" "warn" "9.1.4.10 密码技术擦除存储介质——人工核对"
    _cert_check "等保4级门禁联检" "--dengbao" "pass" "DENGBAO_LEVEL=4 启用 --dengbao 逐项检查（含 SM4/MFA/审计）"
  fi

  # BCP5级（bcp5）
  if [[ "$profile" == "bcp5" || "$profile" == "all" ]]; then
    echo "--- 业务连续性5级（GB/T 20988-2007 第5级）---"
    if [[ $has_spec -eq 1 ]]; then
      grep -qE 'RTO|RPO|灾备|灾难恢复' "$spec_f" 2>/dev/null \
        && _cert_check "灾备RTO/RPO声明" "--shift-left §20" "pass" "spec 含 RTO/RPO 声明" \
        || _cert_check "灾备RTO/RPO声明" "--shift-left §20" "warn" "spec §20 须声明 RTO≤6h/RPO≤15min（一类系统，GB/T 20988 6.3.2）"
      grep -qE '演练|灾备.*验证' "$spec_f" 2>/dev/null \
        && _cert_check "灾备演练记录" "--operate" "pass" "spec 含演练记录声明" \
        || _cert_check "灾备演练记录" "--operate" "warn" "spec §23 须声明灾备演练≥1次/年（GB/T 20988 第10章）"
    else
      _cert_check "灾备RTO/RPO声明" "--shift-left" "warn" "SPEC_FILE 未配置，无法核查灾备声明"
    fi
    _cert_check "实时数据传输" "人工核对" "warn" "第5级标志：实时数据传输是运行态设施——人工核对"
    _cert_check "应用级自动切换" "人工核对" "warn" "第5级标志：自动切换是运行态设施——人工核对"
  fi

  # GB/T 22240 定级（gb22240）
  if [[ "$profile" == "gb22240" || "$profile" == "all" ]]; then
    echo "--- GB/T 22240-2020 等保定级指南 ---"
    if [[ $has_spec -eq 1 ]]; then
      grep -qE '安全保护等级|等保.*级|定级' "$spec_f" 2>/dev/null \
        && _cert_check "定级声明" "--compliance" "pass" "spec 含定级声明" \
        || _cert_check "定级声明" "--compliance" "warn" "spec §22 须含安全保护等级声明（GB/T 22240-2020）"
    else
      _cert_check "定级声明" "--compliance" "warn" "SPEC_FILE 未配置"
    fi
    _cert_check "定级文档存在" "人工核对" "warn" "须有定级报告文档（定级→备案→按级保护）"
  fi

  # JR/T 0142-2016 银行卡清算业务设施技术要求（jrt0142）
  if [[ "$profile" == "jrt0142" || "$profile" == "all" ]]; then
    echo "--- JR/T 0142-2016 银行卡清算业务设施 + 《清算机构管理办法》---"
    _cert_check "国密SM2/3/4加密" "--crypto" "pass" "须 CRYPTO_PROFILE=gm（GB/T 39786 8.4 联动）"
    _cert_check "C3信息保护" "--sensitive+--crypto" "pass" "不得明文存储/传输/展示（JR/T 0171 6.1.1 联动）"
    _cert_check "多因素鉴别" "--dengbao" "pass" "须 DENGBAO_LEVEL=3（等保三级 8.1.4.1 d 联动）"
    _cert_check "PAN持卡人数据扫描" "--privacy" "pass" "须 --privacy 扩展 PAN 模式（PCI-DSS Req 3 对标）"
    _cert_check "漏洞管理CVE" "--sbom" "pass" "CVE 阈值门禁（PCI-DSS Req 6 对标）"
    _cert_check "审计日志≥6个月" "--shift-left" "warn" "spec §21 须声明日志留存≥6个月（网安法§21 联动）"
    _cert_check "灾备RTO/RPO" "--shift-left" "warn" "spec §20 须声明 RTO≤6h/RPO≤15min/能力≥5级（JR/T 0044 联动）"
    _cert_check "灾备演练≥1次/年" "--operate" "warn" "spec §23 须声明灾备演练记录（JR/T 0044 第10章）"
    _cert_check "数据本地化声明" "spec§22" "warn" "境外机构数据须境内存储（《清算机构管理办法》§31）"
    _cert_check "独立清算+灾备系统" "spec§22" "warn" "须声明独立/安全/高效清算系统+灾备系统（§10 准入条件）"
    _cert_check "网络分区分域" "人工核对" "warn" "边界防护/入侵检测是网络设施——人工核对"
    _cert_check "高可用双活/主备" "人工核对" "warn" "可用性架构是运行态——人工核对"
  fi

  # PCI-DSS 4.0（pcidss）
  if [[ "$profile" == "pcidss" || "$profile" == "all" ]]; then
    echo "--- PCI-DSS 4.0 ---"
    _cert_check "持卡人数据PAN扫描" "--privacy" "pass" "须 --privacy 扩展 PAN 模式扫描（Req 3）"
    _cert_check "传输加密" "--security" "pass" "禁用弱 TLS（Req 4）——--security §1.8"
    _cert_check "存储加密" "--crypto" "pass" "AES-256/SM4 加密存储（Req 3）"
    _cert_check "漏洞管理" "--sbom" "pass" "CVE 阈值门禁（Req 6）——--sbom CVE_THRESHOLD"
    _cert_check "访问控制MFA" "--authz" "pass" "缺鉴权/IDOR 检测（Req 7/8）"
    _cert_check "默认密码更改" "--security" "pass" "硬编码密码检测（Req 2）——--security §1.1"
    _cert_check "审计日志留存≥1年" "--shift-left" "warn" "spec §21 须声明日志留存≥1年（Req 10）"
    _cert_check "安全策略文档" "--compliance" "warn" "spec §22 须含安全策略声明（Req 12）"
  fi

  # ISO 27001:2022（iso27001）
  if [[ "$profile" == "iso27001" || "$profile" == "all" ]]; then
    echo "--- ISO/IEC 27001:2022 技术控制（Annex A.8）---"
    _cert_check "A.8.5身份验证" "--authz" "pass" "授权类门禁覆盖"
    _cert_check "A.8.7恶意代码" "--security/--sbom" "pass" "安全扫描+SBOM CVE 覆盖"
    _cert_check "A.8.8漏洞管理" "--sbom" "pass" "CVE 阈值门禁"
    _cert_check "A.8.11数据掩码" "--privacy" "pass" "PII 扫描覆盖"
    _cert_check "A.8.23 Web安全" "--security" "pass" "XSS/CSRF/注入检测"
    _cert_check "A.8.24密码学" "--crypto" "pass" "弱算法+国密检查"
    _cert_check "A.8.25-28安全SDLC" "--security+--shift-left" "pass" "安全开发+左移覆盖"
    _cert_check "A.8.33测试数据保护" "--privacy" "pass" "测试目录 PII 扫描"
    _cert_check "A.8.9配置管理" "--security" "warn" "调试模式/CORS 检测（部分）"
    _cert_check "A.8.15日志记录" "--shift-left" "warn" "spec §21 日志声明"
    _cert_check "A.8.31环境分离" "人工核对" "warn" "开发/测试/生产分离——人工核查配置"
    _cert_check "A.8.32变更管理" "--shift-left" "warn" "spec §20 变更左移声明"
    _cert_check "A.8.16监控/IDS" "人工核对" "warn" "入侵检测是运行态设施——人工核对"
    _cert_check "A.8.21网络隔离" "人工核对" "warn" "网络隔离是网络设施——人工核对"
  fi

  echo ""
  echo "  汇总：${checks} 项检查（${warns} 项须人工核对/声明补全），fail-closed 项由各门禁独立判定"
  echo "  边界：认证本身需机构测评/审计（等保测评机构/PCI QSA/ISO 27001 认证机构），本门禁是门禁级可查+文档锚点"
}
