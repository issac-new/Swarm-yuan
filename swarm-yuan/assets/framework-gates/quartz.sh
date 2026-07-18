# ruleset: quartz  requires_conf: QUARTZ_SRC_GLOBS
# gates: fw_quartz_scheduled_lock(fail) fw_quartz_cluster_jobstore(warn) fw_quartz_misfire(warn) fw_quartz_threadpool(warn) fw_quartz_jobdatamap(warn) fw_quartz_idempotent(warn) fw_quartz_disallow_concurrent(warn) fw_quartz_timezone(warn)
# harvested-from: P3（2026-07-17），规律源自 Quartz 2.5.x 官方文档/releases 与 Spring Scheduling 工程实践
_fw_quartz_check() {
  echo "  [quartz] Quartz 2.5.x / Spring Scheduling 框架规律"

  # ---------- 收集源文件清单（Java + 配置 + 构建文件统一入 srcarr） ----------
  local srcs srcarr=()
  srcs=$(_fw_resolve_globs ${QUARTZ_SRC_GLOBS[@]+"${QUARTZ_SRC_GLOBS[@]}"} 2>/dev/null | sort -u)
  while IFS= read -r ln; do
    [[ -n "$ln" ]] && srcarr+=("$ln")
  done <<< "$srcs"

  if [[ ${#srcarr[@]} -eq 0 ]]; then
    warn "quartz: QUARTZ_SRC_GLOBS 未配置或无文件可检"
    return
  fi

  # 拆分 Java 文件 vs 配置/构建文件
  local javaarr=() cfgarr=()
  local f
  for f in "${srcarr[@]}"; do
    case "$(basename "$f")" in
      *.java) javaarr+=("$f") ;;
      *.yml|*.yaml|*.properties|pom.xml|*.xml|build.gradle|*.gradle|*.gradle.kts) cfgarr+=("$f") ;;
    esac
  done

  # 代码正文过滤：去 // 行注释与块注释行，防注释里的关键字造成误判
  _fw_quartz_code_only() {
    sed -E 's://.*$::; /^[[:space:]]*\*/d; /^[[:space:]]*\/\*/d' "$1" 2>/dev/null
  }
  # 配置正文过滤：去 # 注释行
  _fw_quartz_cfg_only() {
    grep -vE '^[[:space:]]*#' "$1" 2>/dev/null
  }

  local j c ln

  # ====================================================================
  # fw_quartz_scheduled_lock(fail)：多实例 @Scheduled 须分布式锁
  # ====================================================================
  local has_scheduled=0 has_lock=0
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    if _fw_quartz_code_only "$j" | grep -qE '@Scheduled\b'; then has_scheduled=1; fi
    if _fw_quartz_code_only "$j" | grep -qE '@SchedulerLock|ShedLock|shedlock|RedissonClient|tryLock'; then has_lock=1; fi
  done
  for c in "${cfgarr[@]+"${cfgarr[@]}"}"; do
    if _fw_quartz_cfg_only "$c" | grep -qE 'shedlock'; then has_lock=1; fi
  done
  if [[ "$has_scheduled" -eq 0 ]]; then
    pass "fw_quartz_scheduled_lock: 无 @Scheduled 任务，跳过"
  elif [[ "$has_lock" -eq 1 ]]; then
    pass "fw_quartz_scheduled_lock: @Scheduled 任务有 ShedLock/分布式锁痕迹"
  else
    fail "fw_quartz_scheduled_lock: 检出 @Scheduled 但全仓库无 ShedLock/Redisson 分布式锁（多实例部署任务重复执行，须 @SchedulerLock 或迁 Quartz 集群）"
  fi

  # ====================================================================
  # fw_quartz_cluster_jobstore(warn)：生产禁止 RAMJobStore，集群须 JDBC JobStore
  # ====================================================================
  local ram_hit="" qcfg=0 clustered=0
  for c in "${cfgarr[@]+"${cfgarr[@]}"}"; do
    ln=$(_fw_quartz_cfg_only "$c" | grep -nE 'RAMJobStore' || true)
    [[ -n "$ln" ]] && ram_hit="${ram_hit}${c}:${ln}
"
    if _fw_quartz_cfg_only "$c" | grep -qE 'org\.quartz|spring\.quartz|quartz-scheduler|spring-boot-starter-quartz'; then qcfg=1; fi
    if _fw_quartz_cfg_only "$c" | grep -qE 'job-store-type.*jdbc|jobStore\.class|isClustered|LocalDataSourceJobStore|JDBCJobStore'; then clustered=1; fi
  done
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    if _fw_quartz_code_only "$j" | grep -qE 'RAMJobStore|SchedulerFactoryBean|StdSchedulerFactory'; then
      qcfg=1
      ln=$(_fw_quartz_code_only "$j" | grep -nE 'RAMJobStore' || true)
      [[ -n "$ln" ]] && ram_hit="${ram_hit}${j}:${ln}
"
      if _fw_quartz_code_only "$j" | grep -qE 'LocalDataSourceJobStore|JDBCJobStore|setDataSource'; then clustered=1; fi
    fi
  done
  if [[ -n "$ram_hit" ]]; then
    warn "fw_quartz_cluster_jobstore: 检出 RAMJobStore（内存存储，多实例重复调度 + 宕机丢调度状态，生产须 JDBC JobStore + isClustered=true）:
${ram_hit}"
  elif [[ "$qcfg" -eq 1 && "$clustered" -eq 0 ]]; then
    warn "fw_quartz_cluster_jobstore: 检出 Quartz 使用但未见 JDBC JobStore/集群配置（多实例部署须 spring.quartz.job-store-type=jdbc + isClustered=true）"
  else
    pass "fw_quartz_cluster_jobstore: JobStore 集群配置齐备或无 Quartz 使用"
  fi

  # ====================================================================
  # fw_quartz_misfire(warn)：CronTrigger 须显式 misfire 策略
  # ====================================================================
  local cron_hit=0 mis_ok=0
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    if _fw_quartz_code_only "$j" | grep -qE 'CronScheduleBuilder|CronTrigger'; then cron_hit=1; fi
    if _fw_quartz_code_only "$j" | grep -qE 'withMisfireHandlingInstruction|MISFIRE_INSTRUCTION'; then mis_ok=1; fi
  done
  for c in "${cfgarr[@]+"${cfgarr[@]}"}"; do
    if _fw_quartz_cfg_only "$c" | grep -qE 'misfire'; then mis_ok=1; fi
  done
  if [[ "$cron_hit" -eq 0 ]]; then
    pass "fw_quartz_misfire: 无 CronTrigger 定义，跳过"
  elif [[ "$mis_ok" -eq 1 ]]; then
    pass "fw_quartz_misfire: misfire 策略已显式选型"
  else
    warn "fw_quartz_misfire: CronScheduleBuilder 未配 withMisfireHandlingInstruction（默认 smart policy 恢复时补跑，须按业务选型防补跑风暴/数据缺口）"
  fi

  # ====================================================================
  # fw_quartz_threadpool(warn)：threadCount 须显式配置
  # ====================================================================
  local qprop=0 tc_ok=0
  for c in "${cfgarr[@]+"${cfgarr[@]}"}"; do
    if _fw_quartz_cfg_only "$c" | grep -qE 'org\.quartz|spring\.quartz'; then qprop=1; fi
    if _fw_quartz_cfg_only "$c" | grep -qE 'threadCount|thread-count'; then tc_ok=1; fi
  done
  if [[ "$qprop" -eq 0 ]]; then
    pass "fw_quartz_threadpool: 无 quartz 配置，跳过"
  elif [[ "$tc_ok" -eq 1 ]]; then
    pass "fw_quartz_threadpool: threadCount 已显式配置"
  else
    warn "fw_quartz_threadpool: quartz 配置无 org.quartz.threadPool.threadCount（并发任务上限未规划，过小排队 misfire / 过大资源争抢）"
  fi

  # ====================================================================
  # fw_quartz_jobdatamap(warn)：JobDataMap 仅基本类型，禁存对象
  # ====================================================================
  local jdm_bad=""
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    ln=$(_fw_quartz_code_only "$j" | grep -nE 'usingJobData\(|getJobDataMap\(\)\.put\(|jobDataMap\.put\(|dataMap\.put\(' | grep -E 'new[[:space:]]+[A-Z]' || true)
    [[ -n "$ln" ]] && jdm_bad="${jdm_bad}${j}:${ln}
"
  done
  if [[ -n "$jdm_bad" ]]; then
    warn "fw_quartz_jobdatamap: JobDataMap 存入对象构造（JDBC JobStore 序列化进 QRTZ 表，禁存 DTO/Entity，仅放 String/基本类型 id 回源查库）:
${jdm_bad}"
  else
    pass "fw_quartz_jobdatamap: JobDataMap 未见对象存储"
  fi

  # ====================================================================
  # fw_quartz_idempotent(warn)：任务含写操作须幂等
  # ====================================================================
  local idem_bad=""
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    _fw_quartz_code_only "$j" | grep -qE 'implements Job|extends QuartzJobBean|@Scheduled\b' || continue
    _fw_quartz_code_only "$j" | grep -qE '\.(insert|update|save|delete)[A-Z(]|\.(insert|update|save|delete)\(|jdbcTemplate\.(update|execute)' || continue
    if ! _fw_quartz_code_only "$j" | grep -qE '幂等|idempot|[Dd]edup|去重|唯一键|uniqueKey|onDuplicateKey|INSERT[[:space:]]+IGNORE|insertIgnore|状态机'; then
      idem_bad="${idem_bad}${j}
"
    fi
  done
  if [[ -n "$idem_bad" ]]; then
    warn "fw_quartz_idempotent: 任务类含写操作但无幂等痕迹（misfire 补跑/故障转移/手动重触发会重复执行）:
${idem_bad}"
  else
    pass "fw_quartz_idempotent: 任务幂等性痕迹齐备或无写操作任务"
  fi

  # ====================================================================
  # fw_quartz_disallow_concurrent(warn)：有状态 Job 须串行
  # ====================================================================
  local dc_bad=""
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    _fw_quartz_code_only "$j" | grep -qE 'implements Job|extends QuartzJobBean' || continue
    if ! _fw_quartz_code_only "$j" | grep -qE '@DisallowConcurrentExecution'; then
      dc_bad="${dc_bad}${j}
"
    fi
  done
  if [[ -n "$dc_bad" ]]; then
    warn "fw_quartz_disallow_concurrent: Job 实现类无 @DisallowConcurrentExecution（同一 JobDetail 多 Trigger 并发执行，有共享状态须串行 + @PersistJobDataAfterExecution）:
${dc_bad}"
  else
    pass "fw_quartz_disallow_concurrent: Job 类已声明串行或无 Job 实现"
  fi

  # ====================================================================
  # fw_quartz_timezone(warn)：cron 须显式时区
  # ====================================================================
  local tz_bad=""
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    # @Scheduled cron 无 zone
    ln=$(_fw_quartz_code_only "$j" | grep -nE '@Scheduled\(' | grep -E 'cron' | grep -vE 'zone' || true)
    [[ -n "$ln" ]] && tz_bad="${tz_bad}${j}:${ln}
"
    # CronScheduleBuilder 无 inTimeZone
    if _fw_quartz_code_only "$j" | grep -qE 'CronScheduleBuilder' && ! _fw_quartz_code_only "$j" | grep -qE 'inTimeZone'; then
      tz_bad="${tz_bad}${j}(CronScheduleBuilder 无 inTimeZone)
"
    fi
  done
  if [[ -n "$tz_bad" ]]; then
    warn "fw_quartz_timezone: cron 触发未显式声明时区（容器默认 UTC，与 Asia/Shanghai 差 8h，须 @Scheduled zone= 或 inTimeZone）:
${tz_bad}"
  else
    pass "fw_quartz_timezone: cron 时区显式声明或无 cron 定义"
  fi
}
