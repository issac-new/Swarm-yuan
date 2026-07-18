# ruleset: paimon  requires_conf: PAIMON_SRC_GLOBS PAIMON_TABLE_GLOBS
# gates: fw_paimon_pk_bucket(fail) fw_paimon_compaction(warn) fw_paimon_merge_engine(warn) fw_paimon_changelog_producer(warn) fw_paimon_stream_scan_mode(warn) fw_paimon_snapshot_retention(warn) fw_paimon_time_travel(warn) fw_paimon_partition(warn) fw_paimon_bucket_key(warn) fw_paimon_lookup_join(warn) fw_paimon_write_buffer(warn) fw_paimon_schema_evolution(warn) fw_paimon_file_format(warn)
# harvested-from: P3（2026-07-17），规律源自 Apache Paimon 1.x（现行稳定 1.4）官方文档
_fw_paimon_check() {
  echo "  [paimon] Apache Paimon 1.x（现行稳定 1.4）框架规律"

  # ---------- 收集文件清单：作业源（srcarr）+ 表 DDL（tablearr） ----------
  local srcs tbls srcarr=() tablearr=()
  srcs=$(_fw_resolve_globs ${PAIMON_SRC_GLOBS[@]+"${PAIMON_SRC_GLOBS[@]}"} 2>/dev/null | sort -u)
  while IFS= read -r ln; do
    [[ -n "$ln" ]] && srcarr+=("$ln")
  done <<< "$srcs"
  tbls=$(_fw_resolve_globs ${PAIMON_TABLE_GLOBS[@]+"${PAIMON_TABLE_GLOBS[@]}"} 2>/dev/null | sort -u)
  while IFS= read -r ln; do
    [[ -n "$ln" ]] && tablearr+=("$ln")
  done <<< "$tbls"

  if [[ ${#srcarr[@]} -eq 0 && ${#tablearr[@]} -eq 0 ]]; then
    warn "paimon: PAIMON_SRC_GLOBS/PAIMON_TABLE_GLOBS 未配置或无文件可检"
    return
  fi

  # ---------- 识别 paimon 表 DDL 与主键表 ----------
  # paimon 表：含 connector=paimon 或 paimon 特征配置项
  local pm_tables=""
  local tf
  for tf in ${tablearr[@]+"${tablearr[@]}"}; do
    if grep -qiE "connector'?[[:space:]]*=[[:space:]]*'?paimon|merge-engine|changelog-producer|scan\.mode" "$tf" 2>/dev/null; then
      pm_tables="${pm_tables}${tf}
"
    fi
  done
  # 主键表：paimon 表且含 PRIMARY KEY
  local pk_tables=""
  while IFS= read -r tf; do
    [[ -z "$tf" ]] && continue
    if grep -qiE 'PRIMARY KEY' "$tf" 2>/dev/null; then
      pk_tables="${pk_tables}${tf}
"
    fi
  done <<< "$pm_tables"

  # ====================================================================
  # fw_paimon_pk_bucket(fail)：主键表必须显式规划 bucket
  # ====================================================================
  local bkt_bad=""
  while IFS= read -r tf; do
    [[ -z "$tf" ]] && continue
    if ! grep -qiE "'bucket'|bucket-key|\"bucket\"" "$tf" 2>/dev/null; then
      bkt_bad="${bkt_bad}${tf}
"
    fi
  done <<< "$pk_tables"
  if [[ -n "$bkt_bad" ]]; then
    fail "fw_paimon_pk_bucket: 主键表未显式配 'bucket'（默认单 bucket 写入串行/compaction 无法并行/查询无法分桶裁剪，事后改 bucket 须重建表重灌）:
${bkt_bad}"
  else
    pass "fw_paimon_pk_bucket: 主键表均显式配 bucket 或无主键表"
  fi

  # ====================================================================
  # fw_paimon_compaction(warn)：主键表须配 compaction 参数
  # ====================================================================
  local cp_bad=""
  while IFS= read -r tf; do
    [[ -z "$tf" ]] && continue
    if ! grep -qiE 'num-sorted-run|compaction\.' "$tf" 2>/dev/null; then
      cp_bad="${cp_bad}${tf}
"
    fi
  done <<< "$pk_tables"
  if [[ -n "$cp_bad" ]]; then
    warn "fw_paimon_compaction: 主键表无 num-sorted-run/compaction.* 配置（依赖默认阈值待验证，读放大/小文件风险，须按写入速率显式调优）:
${cp_bad}"
  else
    pass "fw_paimon_compaction: 主键表均配 compaction 参数或无主键表"
  fi

  # ====================================================================
  # fw_paimon_merge_engine(warn)：非 deduplicate merge-engine 须确认语义
  # ====================================================================
  local me_hit=""
  while IFS= read -r tf; do
    [[ -z "$tf" ]] && continue
    local ln
    ln=$(grep -niE "merge-engine'?[[:space:]]*=[[:space:]]*'?(partial-update|aggregation|first-row)" "$tf" 2>/dev/null || true)
    [[ -n "$ln" ]] && me_hit="${me_hit}${tf}:${ln}
"
  done <<< "$pm_tables"
  if [[ -n "$me_hit" ]]; then
    warn "fw_paimon_merge_engine: 检出非默认 merge-engine（partial-update/aggregation/first-row 语义须人工确认匹配业务，误用整行覆盖丢列）:
${me_hit}"
  else
    pass "fw_paimon_merge_engine: 无非默认 merge-engine（deduplicate 默认安全）"
  fi

  # ====================================================================
  # fw_paimon_changelog_producer(warn)：流读 changelog 须配 changelog-producer
  # ====================================================================
  local scan_hit=0
  if grep -liE 'scan\.mode' ${srcarr[@]+"${srcarr[@]}"} ${tablearr[@]+"${tablearr[@]}"} 2>/dev/null | head -1 | grep -q .; then
    scan_hit=1
  fi
  if [[ "$scan_hit" -eq 0 ]]; then
    pass "fw_paimon_changelog_producer: 未检出流读 scan.mode，跳过"
  else
    local clp_ok=0
    while IFS= read -r tf; do
      [[ -z "$tf" ]] && continue
      if grep -qiE 'changelog-producer' "$tf" 2>/dev/null; then
        clp_ok=1
        break
      fi
    done <<< "$pm_tables"
    if [[ "$clp_ok" -eq 1 ]]; then
      pass "fw_paimon_changelog_producer: 流读 + changelog-producer 已配"
    else
      warn "fw_paimon_changelog_producer: 检出流读 scan.mode 但表无 changelog-producer（主键表 changelog 缺 -U 前像，下游 retract 聚合不收敛，须配 input/lookup/full-compaction）"
    fi
  fi

  # ====================================================================
  # fw_paimon_stream_scan_mode(warn)：scan.mode 选型确认
  # ====================================================================
  local sm_hit=""
  local sf
  for sf in ${srcarr[@]+"${srcarr[@]}"} ${tablearr[@]+"${tablearr[@]}"}; do
    local ln
    ln=$(grep -niE 'scan\.mode' "$sf" 2>/dev/null || true)
    [[ -n "$ln" ]] && sm_hit="${sm_hit}${sf}:${ln}
"
  done
  if [[ -n "$sm_hit" ]]; then
    warn "fw_paimon_stream_scan_mode: 检出 scan.mode 配置（latest 不扫存量/full 先快照后增量/compacted 读合并快照，补数场景用 latest 丢存量，须人工确认）:
${sm_hit}"
  else
    pass "fw_paimon_stream_scan_mode: 未检出 scan.mode（默认 latest 语义已知）"
  fi

  # ====================================================================
  # fw_paimon_snapshot_retention(warn)：快照须配过期保留
  # ====================================================================
  local sr_bad=""
  while IFS= read -r tf; do
    [[ -z "$tf" ]] && continue
    if ! grep -qiE 'snapshot\.time-retained|snapshot\.num-retained' "$tf" 2>/dev/null; then
      sr_bad="${sr_bad}${tf}
"
    fi
  done <<< "$pm_tables"
  if [[ -n "$sr_bad" ]]; then
    warn "fw_paimon_snapshot_retention: paimon 表无 snapshot.time-retained/num-retained（默认 1h 待验证，长周期快照/manifest 无限膨胀，须显式配保留窗口）:
${sr_bad}"
  else
    pass "fw_paimon_snapshot_retention: 表均配快照保留或无 paimon 表"
  fi

  # ====================================================================
  # fw_paimon_time_travel(warn)：回溯须在保留窗口内
  # ====================================================================
  local tt_hit=""
  for sf in ${srcarr[@]+"${srcarr[@]}"} ${tablearr[@]+"${tablearr[@]}"}; do
    local ln
    ln=$(grep -niE 'scan\.snapshot-id|scan\.timestamp' "$sf" 2>/dev/null || true)
    [[ -n "$ln" ]] && tt_hit="${tt_hit}${sf}:${ln}
"
  done
  if [[ -n "$tt_hit" ]]; then
    warn "fw_paimon_time_travel: 检出快照回溯（scan.snapshot-id/timestamp，目标快照须落在 time-retained 窗口内，长跨度须 tag/branch 固化）:
${tt_hit}"
  else
    pass "fw_paimon_time_travel: 未检出快照回溯"
  fi

  # ====================================================================
  # fw_paimon_partition(warn)：主键表须评估分区
  # ====================================================================
  local pt_bad=""
  while IFS= read -r tf; do
    [[ -z "$tf" ]] && continue
    if ! grep -qiE 'PARTITIONED BY' "$tf" 2>/dev/null; then
      pt_bad="${pt_bad}${tf}
"
    fi
  done <<< "$pk_tables"
  if [[ -n "$pt_bad" ]]; then
    warn "fw_paimon_partition: 主键表无 PARTITIONED BY（亿级+大表单表 bucket 压力集中且查询无法分区裁剪，须确认数据量级或按低基数业务字段分区）:
${pt_bad}"
  else
    pass "fw_paimon_partition: 主键表均分区或无主键表"
  fi

  # ====================================================================
  # fw_paimon_bucket_key(warn)：bucket-key 须为主键子集
  # ====================================================================
  local bk_hit=""
  while IFS= read -r tf; do
    [[ -z "$tf" ]] && continue
    local ln
    ln=$(grep -niE 'bucket-key' "$tf" 2>/dev/null || true)
    [[ -n "$ln" ]] && bk_hit="${bk_hit}${tf}:${ln}
"
  done <<< "$pm_tables"
  if [[ -n "$bk_hit" ]]; then
    warn "fw_paimon_bucket_key: 检出 bucket-key（须人工核对为 PRIMARY KEY 子集，否则同 key 落多桶、merge 去重失效产生重复行）:
${bk_hit}"
  else
    pass "fw_paimon_bucket_key: 未检出 bucket-key（默认按主键整体分桶）"
  fi

  # ====================================================================
  # fw_paimon_lookup_join(warn)：维表 lookup join 须配缓存
  # ====================================================================
  local lj_bad=""
  for sf in ${srcarr[@]+"${srcarr[@]}"}; do
    if grep -qiE 'FOR SYSTEM_TIME AS OF' "$sf" 2>/dev/null; then
      if ! grep -qiE 'lookup\.cache' "$sf" 2>/dev/null; then
        lj_bad="${lj_bad}${sf}
"
      fi
    fi
  done
  if [[ -n "$lj_bad" ]]; then
    warn "fw_paimon_lookup_join: 检出 temporal/lookup join 但无 lookup.cache 配置（每条流记录一次点查，吞吐断崖反压；须配缓存与 TTL 平衡新鲜度）:
${lj_bad}"
  else
    pass "fw_paimon_lookup_join: lookup join 均配缓存或无 lookup join"
  fi

  # ====================================================================
  # fw_paimon_write_buffer(warn)：写入须评估 write-buffer
  # ====================================================================
  local wb_bad=""
  for sf in ${srcarr[@]+"${srcarr[@]}"}; do
    if grep -qiE 'paimon' "$sf" 2>/dev/null; then
      if ! grep -qiE 'write-buffer' "$sf" 2>/dev/null; then
        wb_bad="${wb_bad}${sf}
"
      fi
    fi
  done
  if [[ -n "$wb_bad" ]]; then
    warn "fw_paimon_write_buffer: paimon sink 作业无 write-buffer 配置（buffer 过小 spill 小文件爆炸/过大 TM OOM，默认值待验证，须按 TM 内存显式调）:
${wb_bad}"
  else
    pass "fw_paimon_write_buffer: 作业均配 write-buffer 或无 paimon sink 作业源"
  fi

  # ====================================================================
  # fw_paimon_schema_evolution(warn)：列类型变更禁 narrowing
  # ====================================================================
  local se_hit=""
  while IFS= read -r tf; do
    [[ -z "$tf" ]] && continue
    local ln
    ln=$(grep -niE 'ALTER TABLE.*(MODIFY|CHANGE)[[:space:]]+(COLUMN)?' "$tf" 2>/dev/null || true)
    [[ -n "$ln" ]] && se_hit="${se_hit}${tf}:${ln}
"
  done <<< "$pm_tables"
  if [[ -n "$se_hit" ]]; then
    warn "fw_paimon_schema_evolution: 检出 ALTER TABLE 列类型变更（仅支持 widening，narrowing 截断历史数据；主键/分区列变更须重建表，人工确认）:
${se_hit}"
  else
    pass "fw_paimon_schema_evolution: 未检出列类型变更（ADD COLUMN 安全）"
  fi

  # ====================================================================
  # fw_paimon_file_format(warn)：file.format 选型确认
  # ====================================================================
  local ff_hit=""
  while IFS= read -r tf; do
    [[ -z "$tf" ]] && continue
    local ln
    ln=$(grep -niE 'file\.format' "$tf" 2>/dev/null || true)
    [[ -n "$ln" ]] && ff_hit="${ff_hit}${tf}:${ln}
"
  done <<< "$pm_tables"
  if [[ -n "$ff_hit" ]]; then
    warn "fw_paimon_file_format: 检出 file.format 配置（orc/parquet 分析列裁剪优、avro 行存 CDC 写入开销低；跨引擎须全支持，人工确认选型）:
${ff_hit}"
  else
    pass "fw_paimon_file_format: 未配 file.format（默认 orc 待验证）"
  fi
}
