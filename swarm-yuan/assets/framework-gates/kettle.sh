# ruleset: kettle  requires_conf: KETTLE_JOB_GLOBS
# gates: fw_kettle_password_encr(fail) fw_kettle_carte_default_auth(fail) fw_kettle_git_versioned(warn) fw_kettle_blocking_step(warn) fw_kettle_failure_mail(warn) fw_kettle_variable_scope(warn) fw_kettle_log_level(warn) fw_kettle_connection_pool(warn) fw_kettle_transaction(warn) fw_kettle_hop_migration(warn) fw_kettle_error_handling(warn)
# harvested-from: P3（2026-07-17），规律源自 Pentaho Data Integration CE 9.x / PDI 11 官方文档与 Apache Hop 2.x 文档
_fw_kettle_check() {
  echo "  [kettle] Pentaho Data Integration CE 9.x / PDI 11 框架规律"

  # ---------- 收集作业/转换文件清单（.kjb + .ktr 统一入 srcarr） ----------
  local srcs srcarr=()
  srcs=$(_fw_resolve_globs ${KETTLE_JOB_GLOBS[@]+"${KETTLE_JOB_GLOBS[@]}"} 2>/dev/null | sort -u)
  while IFS= read -r ln; do
    [[ -n "$ln" ]] && srcarr+=("$ln")
  done <<< "$srcs"

  if [[ ${#srcarr[@]} -eq 0 ]]; then
    warn "kettle: KETTLE_JOB_GLOBS 未配置或无 .kjb/.ktr 文件可检"
    return
  fi

  # 拆分 .kjb vs .ktr
  local jobarr=() transarr=()
  local f
  for f in "${srcarr[@]}"; do
    case "$(basename "$f")" in
      *.kjb) jobarr+=("$f") ;;
      *.ktr) transarr+=("$f") ;;
    esac
  done

  # Carte 配置文件（不属于 KETTLE_JOB_GLOBS，按文件名在 PROJECT_DIR 内单独收集）
  local carte_files=""
  if [[ -n "${PROJECT_DIR:-}" && -d "${PROJECT_DIR:-/nonexistent}" ]]; then
    carte_files=$(find "$PROJECT_DIR" -type f \( -name 'carte-config*.xml' -o -name 'slave-server-config*.xml' -o -name 'kettle.pwd' \) 2>/dev/null || true)
  fi

  # ====================================================================
  # fw_kettle_password_encr(fail)：数据库连接密码禁止明文
  # ====================================================================
  local pw_bad=""
  for f in "${srcarr[@]}"; do
    local vals v
    vals=$(grep -oE '<password>[^<]+</password>' "$f" 2>/dev/null || true)
    while IFS= read -r v; do
      [[ -z "$v" ]] && continue
      # 提取值本体
      v=$(printf '%s' "$v" | sed -E 's/<\/?password>//g')
      case "$v" in
        Encrypted*) continue ;;   # Kettle Encr 密文前缀
        *\$\{*) continue ;;       # 变量外置 ${...}
        "") continue ;;
        *) pw_bad="${pw_bad}${f}: <password>${v}</password>
" ;;
      esac
    done <<< "$vals"
  done
  if [[ -n "$pw_bad" ]]; then
    fail "fw_kettle_password_encr: kjb/ktr 数据库连接密码明文（须 Encr 加密 Encrypted 前缀或 \${VAR} 变量/JNDI，入 git 即永久泄露 CWE-312/CWE-798）:
${pw_bad}"
  else
    pass "fw_kettle_password_encr: 连接密码均 Encrypted/变量化"
  fi

  # ====================================================================
  # fw_kettle_carte_default_auth(fail)：Carte 默认口令 / 明文口令
  # ====================================================================
  local carte_bad=""
  if [[ -n "$carte_files" ]]; then
    local cf
    while IFS= read -r cf; do
      [[ -z "$cf" ]] && continue
      case "$(basename "$cf")" in
        kettle.pwd)
          local ln
          ln=$(grep -nE '^cluster[[:space:]]*[:=][[:space:]]*cluster' "$cf" 2>/dev/null || true)
          [[ -n "$ln" ]] && carte_bad="${carte_bad}${cf}:${ln}（kettle.pwd 默认 cluster/cluster）
"
          ;;
        *)
          if grep -qE '<username>cluster</username>' "$cf" 2>/dev/null \
             && grep -qE '<password>cluster</password>' "$cf" 2>/dev/null; then
            carte_bad="${carte_bad}${cf}: <username>cluster</username> + <password>cluster</password>（出厂默认弱口令，Carte 远程执行 = RCE 后门 CWE-1391）
"
          else
            # 非默认但明文：slaveserver 密码须 Encrypted/变量
            local pv
            pv=$(grep -oE '<password>[^<]+</password>' "$cf" 2>/dev/null | sed -E 's/<\/?password>//g' || true)
            while IFS= read -r v; do
              [[ -z "$v" ]] && continue
              case "$v" in
                Encrypted*) ;;
                *\$\{*) ;;
                *) carte_bad="${carte_bad}${cf}: slaveserver 密码明文 <password>${v}</password>
" ;;
              esac
            done <<< "$pv"
          fi
          ;;
      esac
    done <<< "$carte_files"
  fi
  if [[ -n "$carte_bad" ]]; then
    fail "fw_kettle_carte_default_auth: Carte 远程执行凭据不合规（默认 cluster/cluster 必改；密码须 Encr/变量化）:
${carte_bad}"
  else
    pass "fw_kettle_carte_default_auth: 无 Carte 默认/明文口令"
  fi

  # ====================================================================
  # fw_kettle_git_versioned(warn)：kjb/ktr 纳入 git
  # ====================================================================
  local tracked=0
  if [[ -n "${PROJECT_DIR:-}" ]] && command -v git >/dev/null 2>&1; then
    tracked=$(git -C "$PROJECT_DIR" ls-files '*.kjb' '*.ktr' 2>/dev/null | wc -l | xargs)
  fi
  if [[ "$tracked" -gt 0 ]]; then
    pass "fw_kettle_git_versioned: kjb/ktr 已纳入 git 跟踪（${tracked} 个）"
  else
    warn "fw_kettle_git_versioned: 工作区存在 kjb/ktr 但 git 未跟踪（XML 可读可 diff，须入版本管控走评审）"
  fi

  # ====================================================================
  # fw_kettle_blocking_step(warn)：BlockingStep / SortRows 内存评估
  # ====================================================================
  local bs_hit=""
  for f in "${transarr[@]+"${transarr[@]}"}"; do
    local ln
    ln=$(grep -nE '<type>BlockingStep</type>|<type>SortRows</type>' "$f" 2>/dev/null || true)
    [[ -n "$ln" ]] && bs_hit="${bs_hit}${f}:${ln}
"
  done
  if [[ -n "$bs_hit" ]]; then
    warn "fw_kettle_blocking_step: 检出 BlockingStep/SortRows（缓存全量行，须确认数据量与内存/排序目录容量）:
${bs_hit}"
  else
    pass "fw_kettle_blocking_step: 未检出阻塞型步骤"
  fi

  # ====================================================================
  # fw_kettle_failure_mail(warn)：作业失败邮件/告警
  # ====================================================================
  local mail_bad=""
  for f in "${jobarr[@]+"${jobarr[@]}"}"; do
    grep -qE '<entries>' "$f" 2>/dev/null || continue
    if ! grep -qE '<type>MAIL</type>' "$f" 2>/dev/null; then
      mail_bad="${mail_bad}${f}
"
    fi
  done
  if [[ -n "$mail_bad" ]]; then
    warn "fw_kettle_failure_mail: 作业无 MAIL entry（失败 hop 须挂邮件/告警，kitchen 调度下失败静默即缺数）:
${mail_bad}"
  else
    pass "fw_kettle_failure_mail: 作业均含失败告警 entry"
  fi

  # ====================================================================
  # fw_kettle_variable_scope(warn)：环境特有值硬编码
  # ====================================================================
  local vs_hit=""
  for f in "${srcarr[@]}"; do
    local ln
    ln=$(grep -nE '<server>[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}</server>|/home/[a-zA-Z0-9_/-]+|/opt/[a-zA-Z0-9_/-]+|[A-Z]:\\\\' "$f" 2>/dev/null || true)
    [[ -n "$ln" ]] && vs_hit="${vs_hit}${f}:${ln}
"
  done
  if [[ -n "$vs_hit" ]]; then
    warn "fw_kettle_variable_scope: 检出硬编码 IP/绝对路径（环境特有值须 \${VAR} 变量化：kettle.properties/命名参数/环境变量）:
${vs_hit}"
  else
    pass "fw_kettle_variable_scope: 未检出硬编码环境值"
  fi

  # ====================================================================
  # fw_kettle_log_level(warn)：生产日志级别收敛
  # ====================================================================
  local ll_hit=""
  for f in "${srcarr[@]}"; do
    local ln
    ln=$(grep -nE '<loglevel>(Detailed|Debug|Rowlevel)</loglevel>' "$f" 2>/dev/null || true)
    [[ -n "$ln" ]] && ll_hit="${ll_hit}${f}:${ln}
"
  done
  if [[ -n "$ll_hit" ]]; then
    warn "fw_kettle_log_level: 检出 Detailed/Debug/Rowlevel 日志级别（生产固定 Basic/Minimal，Rowlevel 泄露行数据 CWE-532）:
${ll_hit}"
  else
    pass "fw_kettle_log_level: 日志级别收敛"
  fi

  # ====================================================================
  # fw_kettle_connection_pool(warn)：连接池 / JNDI
  # ====================================================================
  local pool_bad=""
  for f in "${transarr[@]+"${transarr[@]}"}"; do
    grep -qE '<connection>' "$f" 2>/dev/null || continue
    if grep -qE '<access>JNDI</access>' "$f" 2>/dev/null; then
      continue
    fi
    if ! grep -qE '<pooling>' "$f" 2>/dev/null; then
      pool_bad="${pool_bad}${f}
"
    fi
  done
  if [[ -n "$pool_bad" ]]; then
    warn "fw_kettle_connection_pool: 转换数据库连接无池化且非 JNDI（高频转换打满 max_connections 风险）:
${pool_bad}"
  else
    pass "fw_kettle_connection_pool: 连接池/JNDI 已配"
  fi

  # ====================================================================
  # fw_kettle_transaction(warn)：多表写入事务边界
  # ====================================================================
  local tx_bad=""
  for f in "${transarr[@]+"${transarr[@]}"}"; do
    local n_out
    n_out=$(grep -cE '<type>TableOutput</type>|<type>InsertUpdate</type>' "$f" 2>/dev/null || echo 0)
    if [[ "$n_out" -ge 2 ]] && grep -qE '<unique_connections>Y</unique_connections>' "$f" 2>/dev/null; then
      tx_bad="${tx_bad}${f}: ${n_out} 个写入步骤 + unique_connections=Y（每步独立连接，无统一事务）
"
    fi
  done
  if [[ -n "$tx_bad" ]]; then
    warn "fw_kettle_transaction: 多表写入转换开 unique_connections（部分提交即脏数据，须明确转换级/作业级事务边界）:
${tx_bad}"
  else
    pass "fw_kettle_transaction: 事务边界合理"
  fi

  # ====================================================================
  # fw_kettle_hop_migration(warn)：PDI CE 9.x 终态迁移评估
  # ====================================================================
  local mig_hit=""
  for f in "${srcarr[@]}"; do
    local ln
    ln=$(grep -nE '<transversion>(8|9)\.' "$f" 2>/dev/null | head -1 || true)
    [[ -n "$ln" ]] && mig_hit="${mig_hit}${f}:${ln}
"
  done
  if [[ -n "$mig_hit" ]]; then
    warn "fw_kettle_hop_migration: 检出 PDI 9.x/8.x 制品（CE 9.x 终态，EOL 待验证；须评估锁版维稳/升 PDI 11/迁 Apache Hop 2.x）:
${mig_hit}"
  else
    pass "fw_kettle_hop_migration: 未检出旧版本制品"
  fi

  # ====================================================================
  # fw_kettle_error_handling(warn)：写入步骤错误处理策略
  # ====================================================================
  local eh_bad=""
  for f in "${transarr[@]+"${transarr[@]}"}"; do
    grep -qE '<type>TableOutput</type>|<type>InsertUpdate</type>' "$f" 2>/dev/null || continue
    if ! grep -qE '<error_handling>' "$f" 2>/dev/null; then
      eh_bad="${eh_bad}${f}
"
    fi
  done
  if [[ -n "$eh_bad" ]]; then
    warn "fw_kettle_error_handling: 写入步骤未定义错误处理（须错误行路由到错误表 + 原因码，或明确中止语义配作业告警）:
${eh_bad}"
  else
    pass "fw_kettle_error_handling: 写入步骤错误处理已定义"
  fi
}
