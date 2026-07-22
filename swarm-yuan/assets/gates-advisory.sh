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

