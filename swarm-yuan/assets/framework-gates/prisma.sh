# ruleset: prisma  requires_conf: PRISMA_SCHEMA_GLOBS PRISMA_SRC_GLOBS
# gates: fw_prisma_migrate_deploy(fail) fw_prisma_transaction_timeout(warn) fw_prisma_n1_loop(warn) fw_prisma_queryraw_injection(fail) fw_prisma_connection_limit(warn) fw_prisma_id_strategy(warn) fw_prisma_relation_cascade(warn) fw_prisma_relation_index(warn) fw_prisma_middleware_removed(warn) fw_prisma_audit_fields(warn) fw_prisma_generator_output(warn) fw_prisma_query_log(warn)
# harvested-from: P4 调研（2026-07-17），规律源自 Prisma 6.x/7.x 官方文档与 releases（https://github.com/prisma/prisma/releases）
_fw_prisma_check() {
  echo "  [prisma] Prisma 6.x / 7.x 框架规律"

  # ---------- 收集 schema 清单（.prisma 入 scarr） ----------
  local scs scarr=()
  scs=$(_fw_resolve_globs ${PRISMA_SCHEMA_GLOBS[@]+"${PRISMA_SCHEMA_GLOBS[@]}"} 2>/dev/null | sort -u)
  while IFS= read -r ln; do
    [[ -n "$ln" ]] && scarr+=("$ln")
  done <<< "$scs"

  # ---------- 收集源码/部署清单（js/ts/json/Dockerfile/env 入 srcarr） ----------
  local srcs srcarr=()
  srcs=$(_fw_resolve_globs ${PRISMA_SRC_GLOBS[@]+"${PRISMA_SRC_GLOBS[@]}"} 2>/dev/null | sort -u)
  while IFS= read -r ln; do
    [[ -n "$ln" ]] && srcarr+=("$ln")
  done <<< "$srcs"

  if [[ ${#scarr[@]} -eq 0 && ${#srcarr[@]} -eq 0 ]]; then
    warn "prisma: PRISMA_SCHEMA_GLOBS/PRISMA_SRC_GLOBS 未配置或无文件可检"
    return
  fi

  # 拆分 js/ts 源码 vs Dockerfile/脚本
  local jsarr=() deparr=()
  local f
  for f in "${srcarr[@]+"${srcarr[@]}"}"; do
    case "$(basename "$f")" in
      *.js|*.mjs|*.cjs|*.ts) jsarr+=("$f") ;;
      Dockerfile|Dockerfile.*|*.sh) deparr+=("$f") ;;
    esac
  done

  # ====================================================================
  # fw_prisma_migrate_deploy(fail)：生产部署禁止 migrate dev
  # ====================================================================
  local md_bad=""
  for f in "${deparr[@]+"${deparr[@]}"}"; do
    local ln
    ln=$(grep -nE 'prisma migrate dev' "$f" 2>/dev/null || true)
    [[ -n "$ln" ]] && md_bad="${md_bad}${f}:${ln}
"
  done
  if [[ -n "$md_bad" ]]; then
    fail "fw_prisma_migrate_deploy: 部署脚本检出 prisma migrate dev（交互式/漂移 reset 风险，生产清库隐患 CWE-672；须 migrate deploy）:
${md_bad}"
  else
    pass "fw_prisma_migrate_deploy: 部署脚本未检出 migrate dev"
  fi

  # ====================================================================
  # fw_prisma_transaction_timeout(warn)：交互式事务显式 timeout
  # ====================================================================
  local tx_bad=""
  for f in "${jsarr[@]+"${jsarr[@]}"}"; do
    if ! grep -qE '\$transaction\([[:space:]]*async' "$f" 2>/dev/null; then
      continue
    fi
    if ! grep -qE 'timeout[[:space:]]*:' "$f" 2>/dev/null; then
      tx_bad="${tx_bad}${f}
"
    fi
  done
  if [[ -n "$tx_bad" ]]; then
    warn "fw_prisma_transaction_timeout: 交互式 \$transaction 未显式 timeout/maxWait（默认 5s/2s，长事务高并发大面积 P2028 回滚）:
${tx_bad}"
  else
    pass "fw_prisma_transaction_timeout: 交互式事务均配 timeout 或无交互式事务"
  fi

  # ====================================================================
  # fw_prisma_n1_loop(warn)：循环内 await prisma.* → N+1
  # ====================================================================
  local n1_bad=""
  for f in "${jsarr[@]+"${jsarr[@]}"}"; do
    if grep -qE 'for[[:space:]]*\(' "$f" 2>/dev/null && grep -qE 'await[[:space:]]+(this\.)?prisma\.' "$f" 2>/dev/null; then
      n1_bad="${n1_bad}${f}
"
    fi
  done
  if [[ -n "$n1_bad" ]]; then
    warn "fw_prisma_n1_loop: 同文件含 for 循环与 await prisma.*（疑似循环内查询 N+1；须 include/select 单查或 in:ids 批量）:
${n1_bad}"
  else
    pass "fw_prisma_n1_loop: 未检出循环内 prisma 查询"
  fi

  # ====================================================================
  # fw_prisma_queryraw_injection(fail)：原始查询注入面
  # ====================================================================
  local inj_bad=""
  for f in "${jsarr[@]+"${jsarr[@]}"}"; do
    local ln
    ln=$(grep -nE '\$(queryRawUnsafe|executeRawUnsafe)' "$f" 2>/dev/null || true)
    [[ -n "$ln" ]] && inj_bad="${inj_bad}${f}:${ln}
"
    ln=$(grep -nE '\$(queryRaw|executeRaw)\(' "$f" 2>/dev/null | grep -E '\+' || true)
    [[ -n "$ln" ]] && inj_bad="${inj_bad}${f}:${ln}
"
  done
  if [[ -n "$inj_bad" ]]; then
    fail "fw_prisma_queryraw_injection: 原始查询非参数化（\$queryRawUnsafe/字符串拼接 → SQL 注入 CWE-89；须 tagged template \$queryRaw\`...\` 自动参数化）:
${inj_bad}"
  else
    pass "fw_prisma_queryraw_injection: 原始查询均为 tagged template 或无原始查询"
  fi

  # ====================================================================
  # fw_prisma_connection_limit(warn)：连接池 connection_limit
  # ====================================================================
  local cl_hit=0
  for f in "${scarr[@]+"${scarr[@]}"}" "${srcarr[@]+"${srcarr[@]}"}"; do
    if grep -qE 'connection_limit' "$f" 2>/dev/null; then
      cl_hit=1
      break
    fi
  done
  if [[ "$cl_hit" -eq 1 ]]; then
    pass "fw_prisma_connection_limit: connection_limit 已规划"
  else
    warn "fw_prisma_connection_limit: 未检出 connection_limit（实例数×池大小须 ≤ 库 max_connections；serverless 冷启动须 connection_limit=1 或外部池）"
  fi

  # ====================================================================
  # fw_prisma_id_strategy(warn)：对外主键避免 autoincrement
  # ====================================================================
  local id_bad=""
  for f in "${scarr[@]+"${scarr[@]}"}"; do
    local ln
    ln=$(grep -nE 'Int[[:space:]]+@id[[:space:]]+@default\(autoincrement\(\)\)' "$f" 2>/dev/null || true)
    [[ -n "$ln" ]] && id_bad="${id_bad}${f}:${ln}
"
  done
  if [[ -n "$id_bad" ]]; then
    warn "fw_prisma_id_strategy: Int autoincrement 主键可枚举（URL 暴露即被遍历 CWE-639；对外资源须 uuid()/cuid()）:
${id_bad}"
  else
    pass "fw_prisma_id_strategy: 无 autoincrement 主键"
  fi

  # ====================================================================
  # fw_prisma_relation_cascade(warn)：@relation 显式 onDelete
  # ====================================================================
  local rc_bad=""
  for f in "${scarr[@]+"${scarr[@]}"}"; do
    local ln
    ln=$(grep -nE '@relation\(' "$f" 2>/dev/null | grep -vE 'onDelete' || true)
    [[ -n "$ln" ]] && rc_bad="${rc_bad}${f}:${ln}
"
  done
  if [[ -n "$rc_bad" ]]; then
    warn "fw_prisma_relation_cascade: @relation 未显式 onDelete（默认 NoAction/Restrict 跨库行为不一；须按业务 Cascade/SetNull/Restrict）:
${rc_bad}"
  else
    pass "fw_prisma_relation_cascade: 关联均显式 onDelete 或无关联"
  fi

  # ====================================================================
  # fw_prisma_relation_index(warn)：关系标量外键 @@index
  # ====================================================================
  local ri_bad=""
  for f in "${scarr[@]+"${scarr[@]}"}"; do
    if ! grep -qE '@relation\(fields:' "$f" 2>/dev/null; then
      continue
    fi
    if ! grep -qE '@@index' "$f" 2>/dev/null; then
      ri_bad="${ri_bad}${f}
"
    fi
  done
  if [[ -n "$ri_bad" ]]; then
    warn "fw_prisma_relation_index: schema 含关系标量（@relation(fields:)）但无 @@index（Postgres 不自动建 FK 索引，反查全表扫描）:
${ri_bad}"
  else
    pass "fw_prisma_relation_index: 关系外键均有 @@index 或无关系标量"
  fi

  # ====================================================================
  # fw_prisma_middleware_removed(warn)：$use 中间件 v7 已移除
  # ====================================================================
  local mw_bad=""
  for f in "${jsarr[@]+"${jsarr[@]}"}"; do
    local ln
    ln=$(grep -nE '\.\$use\(' "$f" 2>/dev/null || true)
    [[ -n "$ln" ]] && mw_bad="${mw_bad}${f}:${ln}
"
  done
  if [[ -n "$mw_bad" ]]; then
    warn "fw_prisma_middleware_removed: 检出 prisma.\$use 中间件（Prisma v7 已移除，须改 Client Extensions \$extends 实现软删除/审计）:
${mw_bad}"
  else
    pass "fw_prisma_middleware_removed: 未检出 \$use 中间件"
  fi

  # ====================================================================
  # fw_prisma_audit_fields(warn)：模型审计字段
  # ====================================================================
  local af_bad=""
  for f in "${scarr[@]+"${scarr[@]}"}"; do
    if ! grep -qE '^model[[:space:]]+[A-Z]' "$f" 2>/dev/null; then
      continue
    fi
    if ! grep -qE 'createdAt|updatedAt' "$f" 2>/dev/null; then
      af_bad="${af_bad}${f}
"
    fi
  done
  if [[ -n "$af_bad" ]]; then
    warn "fw_prisma_audit_fields: 模型无 createdAt/updatedAt 审计字段（追溯无据；须 @default(now())/@updatedAt 自动维护）:
${af_bad}"
  else
    pass "fw_prisma_audit_fields: 模型均含审计字段或无模型"
  fi

  # ====================================================================
  # fw_prisma_generator_output(warn)：generator output 必填（v7）
  # ====================================================================
  local go_bad=""
  for f in "${scarr[@]+"${scarr[@]}"}"; do
    if ! grep -qE 'generator[[:space:]]+[a-zA-Z_]+[[:space:]]*\{' "$f" 2>/dev/null; then
      continue
    fi
    if ! grep -qE 'output[[:space:]]*=' "$f" 2>/dev/null; then
      go_bad="${go_bad}${f}
"
    fi
  done
  if [[ -n "$go_bad" ]]; then
    warn "fw_prisma_generator_output: generator 块无 output（Prisma v7 必填，client 不再默认生成进 node_modules；import 路径须指向自定义输出）:
${go_bad}"
  else
    pass "fw_prisma_generator_output: generator output 已配置"
  fi

  # ====================================================================
  # fw_prisma_query_log(warn)：生产禁 log: ['query']
  # ====================================================================
  local ql_bad=""
  for f in "${jsarr[@]+"${jsarr[@]}"}"; do
    local ln
    ln=$(grep -nE "log[[:space:]]*:[[:space:]]*\[[^]]*['\"]query['\"]" "$f" 2>/dev/null || true)
    [[ -n "$ln" ]] && ql_bad="${ql_bad}${f}:${ln}
"
  done
  if [[ -n "$ql_bad" ]]; then
    warn "fw_prisma_query_log: log: ['query'] 全量查询日志（生产泄露查询敏感值 CWE-532 + 日志爆炸；须 ['warn','error'] 或事件采样）:
${ql_bad}"
  else
    pass "fw_prisma_query_log: 无 query 级日志配置"
  fi
}
