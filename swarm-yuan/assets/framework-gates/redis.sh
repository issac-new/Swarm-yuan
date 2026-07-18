# ruleset: redis  requires_conf: REDIS_SRC_GLOBS
# gates: fw_redis_no_expire(fail) fw_redis_lock(fail) fw_redis_penetration(warn) fw_redis_breakdown(warn) fw_redis_avalanche(warn) fw_redis_serializer(warn) fw_redis_pipeline(warn) fw_redis_key_naming(warn) fw_redis_pool(warn) fw_redis_db_consistency(warn)
# harvested-from: P3（2026-07-17），规律源自 Redis 7.2/8.x 官方文档与 Spring Data Redis / Redisson 工程实践
_fw_redis_check() {
  echo "  [redis] Redis 7.2 / 8.x 框架规律"

  # ---------- 收集源文件清单（Java + 配置文件统一入 srcarr） ----------
  local srcs srcarr=()
  srcs=$(_fw_resolve_globs ${REDIS_SRC_GLOBS[@]+"${REDIS_SRC_GLOBS[@]}"} 2>/dev/null | sort -u)
  while IFS= read -r ln; do
    [[ -n "$ln" ]] && srcarr+=("$ln")
  done <<< "$srcs"

  if [[ ${#srcarr[@]} -eq 0 ]]; then
    warn "redis: REDIS_SRC_GLOBS 未配置或无文件可检"
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
  _fw_redis_code_only() {
    sed -E 's://.*$::; /^[[:space:]]*\*/d; /^[[:space:]]*\/\*/d' "$1" 2>/dev/null
  }
  # 配置正文过滤：去 # 注释行
  _fw_redis_cfg_only() {
    grep -vE '^[[:space:]]*#' "$1" 2>/dev/null
  }

  local j c ln

  # ====================================================================
  # fw_redis_no_expire(fail)：缓存 set 必须带 TTL
  # ====================================================================
  # 判定：二参 opsForValue().set(k, v)（无 timeout 参数）且同文件无 expire(/entryTtl → fail
  local ttl_bad=""
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    _fw_redis_code_only "$j" | grep -qE 'RedisTemplate|opsForValue\(\)|opsForHash' || continue
    ln=$(_fw_redis_code_only "$j" | grep -nE '\.set\([^,]*,[^,]*\)[[:space:]]*;' | grep -vE 'TimeUnit|Duration|timeout|Timeout' || true)
    if [[ -n "$ln" ]]; then
      if ! _fw_redis_code_only "$j" | grep -qE '\.expire\(|entryTtl|setDefaultTimeToLive'; then
        ttl_bad="${ttl_bad}${j}:${ln}
"
      fi
    fi
  done
  if [[ -n "$ttl_bad" ]]; then
    fail "fw_redis_no_expire: 缓存 set 未带 TTL 且无 expire 兜底（无过期 key 脏数据永不自愈 + 内存膨胀）:
${ttl_bad}"
  else
    pass "fw_redis_no_expire: 缓存写入均带过期时间或无裸 set"
  fi

  # ====================================================================
  # fw_redis_lock(fail)：分布式锁须 Redisson 或 SET NX PX + owner
  # ====================================================================
  local lock_bad=""
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    _fw_redis_code_only "$j" | grep -qE 'setnx|setIfAbsent|SETNX' || continue
    # 完整实现痕迹：Redisson / owner 标识 / 过期参数
    if ! _fw_redis_code_only "$j" | grep -qE 'RedissonClient|RLock|UUID|owner|Owner|expire|Duration|TimeUnit'; then
      lock_bad="${lock_bad}${j}
"
    fi
  done
  if [[ -n "$lock_bad" ]]; then
    fail "fw_redis_lock: 裸 setnx/setIfAbsent 锁无 owner 标识与过期时间（误删他人锁/死锁，须用 Redisson RLock 看门狗，CWE-667）:
${lock_bad}"
  else
    pass "fw_redis_lock: 分布式锁走 Redisson 或完整 NX PX + owner 实现"
  fi

  # ====================================================================
  # fw_redis_penetration(warn)：读穿场景须空值缓存/布隆过滤
  # ====================================================================
  local pen_bad=""
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    _fw_redis_code_only "$j" | grep -qE 'opsForValue\(\)\.get\(|@Cacheable' || continue
    _fw_redis_code_only "$j" | grep -qE 'select|findBy|getBy|Mapper|Repository' || continue
    if ! _fw_redis_code_only "$j" | grep -qE 'BloomFilter|bloom|Bloom|空值|nullValue|CACHE_NULL|NULL_VALUE|emptyPlaceholder'; then
      pen_bad="${pen_bad}${j}
"
    fi
  done
  if [[ -n "$pen_bad" ]]; then
    warn "fw_redis_penetration: 缓存 miss 回源但无空值缓存/布隆过滤痕迹（恶意不存在 id 可穿透打库）:
${pen_bad}"
  else
    pass "fw_redis_penetration: 读穿场景有空值缓存/布隆痕迹或无回源"
  fi

  # ====================================================================
  # fw_redis_breakdown(warn)：热点重建须互斥
  # ====================================================================
  local brk_bad=""
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    # miss→查库→回写 三步特征同文件
    _fw_redis_code_only "$j" | grep -qE 'opsForValue\(\)\.get\(' || continue
    _fw_redis_code_only "$j" | grep -qE 'select|findBy|getBy|Mapper|Repository' || continue
    _fw_redis_code_only "$j" | grep -qE '\.set\(' || continue
    if ! _fw_redis_code_only "$j" | grep -qE 'setIfAbsent|tryLock|RLock|RedissonClient|逻辑过期|asyncRefresh|异步刷新|synchronized|ReentrantLock'; then
      brk_bad="${brk_bad}${j}
"
    fi
  done
  if [[ -n "$brk_bad" ]]; then
    warn "fw_redis_breakdown: miss-回源-回写 无互斥痕迹（热点 key 过期瞬间并发重建压垮 DB，须互斥锁/逻辑过期）:
${brk_bad}"
  else
    pass "fw_redis_breakdown: 回源重建有互斥痕迹或无热点重建路径"
  fi

  # ====================================================================
  # fw_redis_avalanche(warn)：批量 TTL 须随机抖动
  # ====================================================================
  local const_ttl=0 jitter=0
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    if _fw_redis_code_only "$j" | grep -qE 'Duration\.ofHours\(|Duration\.ofDays\(|Duration\.ofMinutes\('; then
      const_ttl=1
    fi
    if _fw_redis_code_only "$j" | grep -qE 'ThreadLocalRandom|new Random|RandomUtils|jitter|抖动'; then
      jitter=1
    fi
  done
  if [[ "$const_ttl" -eq 1 && "$jitter" -eq 0 ]]; then
    warn "fw_redis_avalanche: 检出常量 TTL（Duration.ofHours/ofDays）但全仓库无随机抖动（批量同刻过期形成雪崩）"
  else
    pass "fw_redis_avalanche: TTL 有抖动或无常量批量 TTL"
  fi

  # ====================================================================
  # fw_redis_serializer(warn)：RedisTemplate 序列化器须显式配置
  # ====================================================================
  local has_tpl=0 has_ser=0
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    if _fw_redis_code_only "$j" | grep -qE 'RedisTemplate'; then has_tpl=1; fi
    if _fw_redis_code_only "$j" | grep -qE 'setKeySerializer|setValueSerializer|Jackson2JsonRedisSerializer|GenericJackson2JsonRedisSerializer|StringRedisSerializer|RedisSerializer\.'; then
      has_ser=1
    fi
  done
  if [[ "$has_tpl" -eq 0 ]]; then
    pass "fw_redis_serializer: 无 RedisTemplate，跳过"
  elif [[ "$has_ser" -eq 1 ]]; then
    pass "fw_redis_serializer: 已显式配置序列化器"
  else
    warn "fw_redis_serializer: RedisTemplate 未显式配置序列化器（默认 JDK 序列化 key 不可读 + 多端不一致，CWE-502 面须收敛）"
  fi

  # ====================================================================
  # fw_redis_pipeline(warn)：循环逐条访问须改 multiGet/pipeline
  # ====================================================================
  local pipe_bad=""
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    _fw_redis_code_only "$j" | grep -qE 'for[[:space:]]*\(|while[[:space:]]*\(' || continue
    _fw_redis_code_only "$j" | grep -qE 'opsForValue\(\)\.(get|set)\(' || continue
    if ! _fw_redis_code_only "$j" | grep -qE 'multiGet|executePipelined|multiSet|Pipeline'; then
      pipe_bad="${pipe_bad}${j}
"
    fi
  done
  if [[ -n "$pipe_bad" ]]; then
    warn "fw_redis_pipeline: 循环体内逐条 get/set（N 个 RTT 线性放大，须 multiGet/executePipelined 批量）:
${pipe_bad}"
  else
    pass "fw_redis_pipeline: 批量访问走 multiGet/pipeline 或无循环访问"
  fi

  # ====================================================================
  # fw_redis_key_naming(warn)：key 须 业务:模块:标识 分层
  # ====================================================================
  local key_bad=""
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    _fw_redis_code_only "$j" | grep -qE 'opsForValue\(\)|opsForHash|RedisTemplate' || continue
    # 字符串字面量 key 无冒号
    ln=$(_fw_redis_code_only "$j" | grep -nE '\.(get|set|delete|hasKey)\("[A-Za-z0-9_.-]+"' | grep -v ':' || true)
    [[ -n "$ln" ]] && key_bad="${key_bad}${j}:${ln}
"
  done
  if [[ -n "$key_bad" ]]; then
    warn "fw_redis_key_naming: 字符串字面量 key 无冒号分层（须 业务:模块:标识，裸 key 无法按前缀治理）:
${key_bad}"
  else
    pass "fw_redis_key_naming: key 命名带分层前缀或无字面量 key"
  fi

  # ====================================================================
  # fw_redis_pool(warn)：Lettuce 连接池须显式配置
  # ====================================================================
  local has_redis_cfg=0 has_pool=0
  for c in "${cfgarr[@]+"${cfgarr[@]}"}"; do
    if _fw_redis_cfg_only "$c" | grep -qE 'spring\.data\.redis|spring\.redis'; then has_redis_cfg=1; fi
    if _fw_redis_cfg_only "$c" | grep -qE 'lettuce.*pool|pool\.max-active|max-active|jedis.*pool'; then has_pool=1; fi
  done
  if [[ "$has_redis_cfg" -eq 0 ]]; then
    pass "fw_redis_pool: 无 spring redis 配置，跳过"
  elif [[ "$has_pool" -eq 1 ]]; then
    pass "fw_redis_pool: 连接池已显式配置"
  else
    warn "fw_redis_pool: spring redis 配置无 lettuce.pool.*（阻塞命令场景共享连接争抢，须配 max-active/max-wait）"
  fi

  # ====================================================================
  # fw_redis_db_consistency(warn)：写库须删缓存（Cache Aside）
  # ====================================================================
  local cons_bad=""
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    _fw_redis_code_only "$j" | grep -qE 'RedisTemplate|redisTemplate' || continue
    _fw_redis_code_only "$j" | grep -qE '\.(insert|update|save)[A-Z(]|\.(insert|update|save)\(' || continue
    if ! _fw_redis_code_only "$j" | grep -qE '\.delete\(|@CacheEvict|evict|延迟双删|deleteCache'; then
      cons_bad="${cons_bad}${j}
"
    fi
  done
  if [[ -n "$cons_bad" ]]; then
    warn "fw_redis_db_consistency: 写库操作无删缓存痕迹（须 Cache Aside：先更库再删缓存，禁止改缓存）:
${cons_bad}"
  else
    pass "fw_redis_db_consistency: 写库路径有缓存失效痕迹或无写库"
  fi
}
