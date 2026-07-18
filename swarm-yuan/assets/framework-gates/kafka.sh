# ruleset: kafka  requires_conf: KAFKA_SRC_GLOBS
# gates: fw_kafka_offset_semantics(fail) fw_kafka_acks(fail) fw_kafka_idempotent_consumer(warn) fw_kafka_consumer_le_partitions(warn) fw_kafka_idempotent_producer(warn) fw_kafka_transactional_producer(warn) fw_kafka_rebalance_cooperative(warn) fw_kafka_partitioner(warn) fw_kafka_dlq(warn) fw_kafka_lag_monitor(warn) fw_kafka_order_partition(warn) fw_kafka_schema_registry(warn) fw_kafka_group_mgmt(warn)
# harvested-from: P3 深化（2026-07-17），规律源自 Apache Kafka 4.x（KRaft 终态）/ spring-kafka 3.x 官方文档
_fw_kafka_check() {
  echo "  [kafka] Apache Kafka 4.x / spring-kafka 3.x 框架规律"

  # ---------- 收集源文件清单（Java + 配置文件统一入 srcarr） ----------
  local srcs srcarr=()
  srcs=$(_fw_resolve_globs ${KAFKA_SRC_GLOBS[@]+"${KAFKA_SRC_GLOBS[@]}"} 2>/dev/null | sort -u)
  while IFS= read -r ln; do
    [[ -n "$ln" ]] && srcarr+=("$ln")
  done <<< "$srcs"

  if [[ ${#srcarr[@]} -eq 0 ]]; then
    warn "kafka: KAFKA_SRC_GLOBS 未配置或无文件可检"
    return
  fi

  # 拆分 Java 文件 vs 配置/构建文件
  local javaarr=() cfgarr=()
  local f
  for f in "${srcarr[@]}"; do
    case "$(basename "$f")" in
      *.java) javaarr+=("$f") ;;
      *.yml|*.yaml|*.properties|pom.xml|build.gradle|*.gradle|*.gradle.kts) cfgarr+=("$f") ;;
    esac
  done

  # 代码正文过滤辅助（剥离行注释与块注释行，防注释中关键字误命中）
  _fw_kafka_code_only() {
    sed -E 's://.*$::; /^[[:space:]]*\*/d; /^[[:space:]]*\/\*/d' "$1" 2>/dev/null
  }

  # 常用检出集合
  local listener_files
  listener_files=$(grep -rlE '@KafkaListener\b' "${javaarr[@]+"${javaarr[@]}"}" 2>/dev/null || true)
  local kafka_usage=0
  [[ -n "$listener_files" ]] && kafka_usage=1
  if [[ "$kafka_usage" -eq 0 ]]; then
    local u
    u=$(grep -rlE 'KafkaTemplate|KafkaProducer|KafkaConsumer' "${javaarr[@]+"${javaarr[@]}"}" 2>/dev/null || true)
    [[ -n "$u" ]] && kafka_usage=1
  fi

  # ====================================================================
  # fw_kafka_offset_semantics(fail)：enable.auto.commit=true 即消息丢失
  # ====================================================================
  local ac_bad=""
  local c j
  for c in "${cfgarr[@]+"${cfgarr[@]}"}"; do
    local ln
    ln=$(grep -niE 'enable[.-]auto[.-]commit[[:space:]]*[:=][[:space:]]*true' "$c" 2>/dev/null || true)
    [[ -n "$ln" ]] && ac_bad="${ac_bad}${c}:${ln}
"
  done
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    local ln
    ln=$(_fw_kafka_code_only "$j" | grep -nE 'ENABLE_AUTO_COMMIT_CONFIG[[:space:]]*,[[:space:]]*"true"' || true)
    [[ -n "$ln" ]] && ac_bad="${ac_bad}${j}:${ln}
"
  done
  if [[ -n "$ac_bad" ]]; then
    fail "fw_kafka_offset_semantics: enable.auto.commit=true（offset 与业务处理脱钩，处理失败消息永久丢失；须 false + 业务成功后提交）:
${ac_bad}"
  else
    pass "fw_kafka_offset_semantics: 未检出 auto.commit=true"
  fi

  # ====================================================================
  # fw_kafka_acks(fail/warn)：acks=0 必丢；acks=1 须确认
  # ====================================================================
  local acks0_bad="" acks1_hit=""
  for c in "${cfgarr[@]+"${cfgarr[@]}"}"; do
    local ln
    ln=$(grep -niE 'acks[[:space:]]*[:=][[:space:]]*0([^0-9]|$)' "$c" 2>/dev/null || true)
    [[ -n "$ln" ]] && acks0_bad="${acks0_bad}${c}:${ln}
"
    ln=$(grep -niE 'acks[[:space:]]*[:=][[:space:]]*1([^0-9]|$)' "$c" 2>/dev/null || true)
    [[ -n "$ln" ]] && acks1_hit="${acks1_hit}${c}:${ln}
"
  done
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    local ln
    ln=$(_fw_kafka_code_only "$j" | grep -nE 'ACKS_CONFIG[[:space:]]*,[[:space:]]*"0"' || true)
    [[ -n "$ln" ]] && acks0_bad="${acks0_bad}${j}:${ln}
"
    ln=$(_fw_kafka_code_only "$j" | grep -nE 'ACKS_CONFIG[[:space:]]*,[[:space:]]*"1"' || true)
    [[ -n "$ln" ]] && acks1_hit="${acks1_hit}${j}:${ln}
"
  done
  if [[ -n "$acks0_bad" ]]; then
    fail "fw_kafka_acks: acks=0（消防水管语义，任何 broker 抖动即丢数据；业务消息须 acks=all + min.insync.replicas>=2）:
${acks0_bad}"
  elif [[ -n "$acks1_hit" ]]; then
    warn "fw_kafka_acks: acks=1（仅 leader 落盘，leader 宕机未同步即丢；业务消息建议 acks=all）:
${acks1_hit}"
  else
    pass "fw_kafka_acks: 未检出 acks=0/1（acks=all 或默认幂等约束）"
  fi

  # ====================================================================
  # fw_kafka_idempotent_consumer(warn)：消费端幂等
  # ====================================================================
  local idem_bad=""
  while IFS= read -r lf; do
    [[ -z "$lf" ]] && continue
    if ! _fw_kafka_code_only "$lf" | grep -qiE '幂等|idempot|dedup|去重|setIfAbsent|setnx|ON DUPLICATE|insertIgnore|uk_[a-z]|unique[[:space:]]+key|consumeOnce'; then
      idem_bad="${idem_bad}${lf}
"
    fi
  done <<< "$listener_files"
  if [[ -z "$listener_files" ]]; then
    pass "fw_kafka_idempotent_consumer: 无 @KafkaListener，跳过"
  elif [[ -n "$idem_bad" ]]; then
    warn "fw_kafka_idempotent_consumer: 消费端无幂等去重痕迹（rebalance/重提交必然重复投递，须业务唯一键去重）:
${idem_bad}"
  else
    pass "fw_kafka_idempotent_consumer: 消费端均有幂等痕迹"
  fi

  # ====================================================================
  # fw_kafka_consumer_le_partitions(warn)：消费者数 ≤ 分区数
  # ====================================================================
  if [[ -z "$listener_files" ]]; then
    pass "fw_kafka_consumer_le_partitions: 无 @KafkaListener，跳过"
  else
    local conc_hit=0
    for j in "${javaarr[@]+"${javaarr[@]}"}"; do
      _fw_kafka_code_only "$j" | grep -qE 'concurrency' && { conc_hit=1; break; }
    done
    if [[ "$conc_hit" -eq 0 ]]; then
      for c in "${cfgarr[@]+"${cfgarr[@]}"}"; do
        grep -qE 'concurrency' "$c" 2>/dev/null && { conc_hit=1; break; }
      done
    fi
    if [[ "$conc_hit" -eq 0 ]]; then
      warn "fw_kafka_consumer_le_partitions: @KafkaListener 未显式配置 concurrency（人工核对：实例数×concurrency ≤ 分区数，超额消费者永远空转）"
    else
      pass "fw_kafka_consumer_le_partitions: 已显式配置 concurrency"
    fi
  fi

  # ====================================================================
  # fw_kafka_idempotent_producer(warn)：显式关闭幂等生产者须理由
  # ====================================================================
  local idp_bad=""
  for c in "${cfgarr[@]+"${cfgarr[@]}"}"; do
    local ln
    ln=$(grep -niE 'enable[.-]idempotence[[:space:]]*[:=][[:space:]]*false' "$c" 2>/dev/null || true)
    [[ -n "$ln" ]] && idp_bad="${idp_bad}${c}:${ln}
"
  done
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    local ln
    ln=$(_fw_kafka_code_only "$j" | grep -nE 'ENABLE_IDEMPOTENCE_CONFIG[[:space:]]*,[[:space:]]*"false"' || true)
    [[ -n "$ln" ]] && idp_bad="${idp_bad}${j}:${ln}
"
  done
  if [[ -n "$idp_bad" ]]; then
    warn "fw_kafka_idempotent_producer: 显式关闭幂等生产者（4.x 默认开启；关闭后重试即可能重复，仅限兼容古董 broker）:
${idp_bad}"
  else
    pass "fw_kafka_idempotent_producer: 未显式关闭幂等生产者"
  fi

  # ====================================================================
  # fw_kafka_transactional_producer(warn)：事务须 read_committed 配对
  # ====================================================================
  local tx_hit="" rc_hit=""
  tx_hit=$(grep -rniE 'transactional[.-]id|TRANSACTIONAL_ID_CONFIG|transactionalIdPrefix' "${srcarr[@]}" 2>/dev/null || true)
  rc_hit=$(grep -rniE 'read_committed|READ_COMMITTED|isolation[.-]level' "${srcarr[@]}" 2>/dev/null || true)
  if [[ -z "$tx_hit" ]]; then
    pass "fw_kafka_transactional_producer: 无事务生产者，跳过"
  elif [[ -z "$rc_hit" ]]; then
    warn "fw_kafka_transactional_producer: 检出 transactional.id 但消费端无 isolation.level=read_committed（会读到中止事务的幽灵消息）"
  else
    pass "fw_kafka_transactional_producer: 事务生产者与 read_committed 配对"
  fi

  # ====================================================================
  # fw_kafka_rebalance_cooperative(warn)：rebalance 协议选型
  # ====================================================================
  local range_hit="" coop_hit=""
  range_hit=$(grep -rnE 'RangeAssignor' "${srcarr[@]}" 2>/dev/null || true)
  coop_hit=$(grep -rniE 'CooperativeSticky|cooperative-sticky|group\.protocol' "${srcarr[@]}" 2>/dev/null || true)
  if [[ -n "$range_hit" ]]; then
    warn "fw_kafka_rebalance_cooperative: 显式 RangeAssignor（eager 协议 rebalance 全组停摆；建议 CooperativeSticky / 4.x 新消费者组协议）:
${range_hit}"
  elif [[ -n "$coop_hit" ]]; then
    pass "fw_kafka_rebalance_cooperative: 已选 cooperative/新协议"
  else
    pass "fw_kafka_rebalance_cooperative: 未显式配置（按 broker/client 版本默认，人工核对 4.x 新协议默认行为）"
  fi

  # ====================================================================
  # fw_kafka_partitioner(warn)：分区器保键序
  # ====================================================================
  local part_bad=""
  part_bad=$(grep -rnE 'RoundRobinPartitioner|UniformStickyPartitioner|round\.robin' "${srcarr[@]}" 2>/dev/null || true)
  if [[ -n "$part_bad" ]]; then
    warn "fw_kafka_partitioner: 检出 RoundRobin/UniformSticky 分区器（同 key 消息打散多分区，键序被破坏；须默认 murmur2 或自定义保序分区器）:
${part_bad}"
  else
    pass "fw_kafka_partitioner: 未检出乱序分区器"
  fi

  # ====================================================================
  # fw_kafka_dlq(warn)：消费失败须 DLT
  # ====================================================================
  if [[ -z "$listener_files" ]]; then
    pass "fw_kafka_dlq: 无 @KafkaListener，跳过"
  else
    local dlt_hit=""
    dlt_hit=$(grep -rlE 'DeadLetterPublishingRecoverer|@RetryableTopic|@DltHandler|DefaultErrorHandler' "${javaarr[@]+"${javaarr[@]}"}" 2>/dev/null || true)
    if [[ -z "$dlt_hit" ]]; then
      warn "fw_kafka_dlq: @KafkaListener 无死信配置（毒丸消息无限重试阻塞分区；须 DefaultErrorHandler+DeadLetterPublishingRecoverer 或 @RetryableTopic）"
    else
      pass "fw_kafka_dlq: 已配死信恢复器"
    fi
  fi

  # ====================================================================
  # fw_kafka_lag_monitor(warn)：consumer lag 监控
  # ====================================================================
  if [[ "$kafka_usage" -eq 0 ]]; then
    pass "fw_kafka_lag_monitor: 无 Kafka 使用迹象，跳过"
  else
    local lag_hit=""
    lag_hit=$(grep -rniE 'micrometer|MeterRegistry|kafka_exporter|burrow|AdminClient' "${srcarr[@]}" 2>/dev/null || true)
    if [[ -z "$lag_hit" ]]; then
      warn "fw_kafka_lag_monitor: 检出 Kafka 使用但无 lag 监控痕迹（micrometer/exporter/Burrow/AdminClient；积压是消费第一故障信号）"
    else
      pass "fw_kafka_lag_monitor: 已配 lag 监控"
    fi
  fi

  # ====================================================================
  # fw_kafka_order_partition(warn)：顺序敏感业务必须带 key
  # ====================================================================
  local nokey_bad=""
  for j in "${javaarr[@]+"${javaarr[@]}"}"; do
    local ln
    ln=$(_fw_kafka_code_only "$j" | grep -nE 'ProducerRecord[^(]*\([^,)]*,[^,)]*\)' || true)
    [[ -n "$ln" ]] && nokey_bad="${nokey_bad}${j}:${ln}
"
  done
  if [[ -n "$nokey_bad" ]]; then
    warn "fw_kafka_order_partition: 检出 ProducerRecord 两参构造（topic, value 无 key → 轮询多分区全局乱序；顺序敏感业务须带业务键 key）:
${nokey_bad}"
  else
    pass "fw_kafka_order_partition: 未检出无 key 发送"
  fi

  # ====================================================================
  # fw_kafka_schema_registry(warn)：schema 演进约束
  # ====================================================================
  if [[ "$kafka_usage" -eq 0 ]]; then
    pass "fw_kafka_schema_registry: 无 Kafka 使用迹象，跳过"
  else
    local str_ser="" sr_hit=""
    str_ser=$(grep -rnE 'StringSerializer|StringDeserializer' "${srcarr[@]}" 2>/dev/null || true)
    sr_hit=$(grep -rniE 'schema[.-]registry|SchemaRegistryClient|KafkaAvroSerializer|KafkaProtobufSerializer|SpecificRecord' "${srcarr[@]}" 2>/dev/null || true)
    if [[ -n "$str_ser" && -z "$sr_hit" ]]; then
      warn "fw_kafka_schema_registry: 裸 String 序列化且无 Schema Registry（payload 演进无约束，生产者改字段即炸消费端；建议 Avro/Protobuf + 兼容策略）"
    elif [[ -n "$sr_hit" ]]; then
      pass "fw_kafka_schema_registry: 已用 Schema Registry / 结构化序列化"
    else
      pass "fw_kafka_schema_registry: 未检出裸 String 序列化"
    fi
  fi

  # ====================================================================
  # fw_kafka_group_mgmt(warn)：消费组复用规范
  # ====================================================================
  local dup_groups gm_bad=""
  dup_groups=$(grep -hoE 'groupId[[:space:]]*=[[:space:]]*"[^"]+"' "${javaarr[@]+"${javaarr[@]}"}" 2>/dev/null \
    | sed -E 's/.*"([^"]+)".*/\1/' | sort | uniq -d || true)
  while IFS= read -r grp; do
    [[ -z "$grp" ]] && continue
    local topics
    topics=$(grep -lE "groupId[[:space:]]*=[[:space:]]*\"${grp}\"" "${javaarr[@]+"${javaarr[@]}"}" 2>/dev/null \
      | xargs grep -hoE 'topics[[:space:]]*=[[:space:]]*"[^"]+"' 2>/dev/null \
      | sed -E 's/.*"([^"]+)".*/\1/' | sort -u || true)
    local tcount
    tcount=$(printf '%s\n' "$topics" | grep -cE '.' || true)
    if [[ "${tcount:-0}" -gt 1 ]]; then
      gm_bad="${gm_bad}groupId=${grp} 被 ${tcount} 个不同 topic 的 listener 复用（rebalance 联动 + 位点管理混乱）
"
    fi
  done <<< "$dup_groups"
  if [[ -n "$gm_bad" ]]; then
    warn "fw_kafka_group_mgmt: 不同业务 listener 复用同一 groupId（一 listener 一组，命名按业务域.用途.环境）:
${gm_bad}"
  else
    pass "fw_kafka_group_mgmt: 无跨 topic 消费组复用"
  fi
}
