#!/usr/bin/env bash
# precheck.sh — 通用质量门禁检查脚本模板（由 swarm-yuan 生成器按项目定制）
# 对应材料 check 段 4 项：§1 测试 §2 业务规则 §3 数据勾稽(无多漏错重) §4 UI脱敏日志
# 用法:
#   bash precheck.sh                  # 核心 10 门禁（--all）
#   bash precheck.sh --all-full       # 标准 27 门禁（核心 10 + 架构 17）
#   bash precheck.sh --compliance-suite  # 合规 13 门禁套件（强监管交付按需；未配置静默跳过）
#   bash precheck.sh --branch         # 分支规范
#   bash precheck.sh --scope          # 改动范围（可改 vs 只读）
#   bash precheck.sh --build          # 构建状态
#   bash precheck.sh --test           # 测试（check §1）
#   bash precheck.sh --sensitive      # 敏感信息脱敏（check §4）
#   bash precheck.sh --consistency    # 业务规则 + 数据勾稽核对（check §2/§3）
#   bash precheck.sh --compliance     # 标准合规矩阵校验
#   bash precheck.sh --docs-pack      # 文档包完备性检查
#   bash precheck.sh --sbom           # SBOM 生成与许可证扫描
#   bash precheck.sh --privacy        # 个人信息（PII）扫描
#   bash precheck.sh --authz          # 授权类弱点检查（CWE-862/863/639/284）
#   bash precheck.sh --requirements   # 需求质量 lint（ISO/IEC/IEEE 29148）
#   bash precheck.sh --crypto         # 密码算法合规（GB/T 39786-2021 密评 profile=gm）
#   bash precheck.sh --rtm            # 需求追溯矩阵（ISO/IEC/IEEE 29148 RTM：REQ ↔ 测试/矩阵追溯）
#   bash precheck.sh --dengbao        # 等保 2.0 控制点映射（GB/T 22239-2019，DENGBAO_LEVEL=2/3）
#   bash precheck.sh --pia            # 隐私影响评估（个保法/GB/T 35273，PIA_REQUIRED=1）
#   bash precheck.sh --sast-deep      # 深度 SAST（semgrep→opengrep→内置词法降级链；GB/T 34943/34944/34946）
#   bash precheck.sh --oss-eval       # 开源代码安全评价（GB/T 43848-2024 四维；复用 --sbom 产物，OSS_EVAL_REQUIRED=1）
#   bash precheck.sh --quality-model  # 质量特性剪裁核验（GB/T 25000.10 八特性+25010 Safety，QUALITY_MODEL_REQUIRED=1）
#   bash precheck.sh --test-evidence  # 测试证据链（GB/T 15532/9386，TEST_EVIDENCE_DIR）
#   bash precheck.sh --review-record  # 评审记录与AI过程信息项（GB/T 8566/ISO 42001，REVIEW_RECORD_DIR）
#   bash precheck.sh --metrics        # 度量趋势告警（GB/T 25000.30，GATE_RUNS_DIR+METRICS_TREND_WINDOW）
#   bash precheck.sh --release-sign   # 发布签名与 provenance（SLSA Build L2 / SSDF PS.2 发布完整性）
#   bash precheck.sh --pr-quality     # PR 质量评分（gstack：变更规模+fingerprint去重+替代方案，advisory）
#   bash precheck.sh --skill-supply-chain  # Skill 供应链安全审计（cso P8：恶意模式扫描，advisory）
#   bash precheck.sh --state-phase    # 阶段状态机证据核验（comet：无证据不流转，advisory）
#   bash precheck.sh --upstream-baseline  # 上游运行时基线 drift 核验（advisory）
#   bash precheck.sh --learnings      # 学习闭环（R5 learn：learnings.jsonl 根因记录覆盖率，advisory）
#   bash precheck.sh --doctor         # conf 诊断（lint：路径/glob 可达/死变量/框架 requires_conf；非门禁、不入注册表）
#   bash precheck.sh --format json --all-full   # 运行结束追加 SARIF 子集 JSON（默认 stdout；GATE_JSON_OUT 环境变量可指定落盘）
# 生成目标技能时，替换 PROJECT_DIR / 可改目录 / 只读目录 / 命令 为项目实际值

set -euo pipefail

# 可移植 realpath 替代函数（BSD findutils 无 realpath，cd+pwd 三平台通用）
_resolve_path() {
  local p="$1"
  local dir base cand
  case "$p" in
    */*) dir="${p%/*}"; base="${p##*/}";;
    *) dir="."; base="$p";;
  esac
  if [[ -d "$dir" ]]; then
    # 修复左结合 bug：原 'cd && pwd -P || cd && pwd' 在 bash 左结合下解析为
    # ((cd && pwd -P) || cd) && pwd，正常路径会执行两次 pwd 返回两行值，
    # 致 -f "$cand" 永远 false（check_layer §3/§6、check_contract §2 沉睡）。
    # 方案 C：直接 cd && pwd -P（POSIX 规定 -P 物理路径，bash/BSD/GNU pwd 均支持）；
    # 失败时 cand 为空，走下方 echo "$p" + return 1 回退，与原失败路径行为等价。
    cand=$(cd "$dir" 2>/dev/null && pwd -P)
    if [[ -n "$cand" ]]; then
      echo "${cand%/}/$base"
      return 0
    fi
  fi
  echo "$p"
  return 1
}

# ===== 内部公共辅助（门禁共用的探查/解析小函数；行为与原内联写法一致）=====

# 变更基线探测：优先 main 分支，不存在则退回 HEAD~1（输出基线引用名）
_git_base() {
  local base="main"
  git rev-parse --verify "$base" >/dev/null 2>&1 || base="HEAD~1"
  printf '%s' "$base"
}

# 本次变更文件清单：git diff --name-only <base>...HEAD，无结果时退回 git diff --name-only HEAD
# 输出与 git 原输出一致：非空时带结尾换行（可供 wc -l 计数），空则无输出
_git_changed_files() {
  local base changed
  base=$(_git_base)
  changed=$(git diff --name-only "$base"...HEAD 2>/dev/null || true)
  [[ -z "$changed" ]] && changed=$(git diff --name-only HEAD 2>/dev/null || true)
  [[ -z "$changed" ]] || printf '%s\n' "$changed"
  return 0
}

# 按序探测候选路径（支持 glob，如 ".claude/skills/*/x.md"），回显第一个存在的文件；均无则输出空
_first_existing_file() {
  local cand f
  for cand in "$@"; do
    # 故意不加引号展开 $cand：让 glob 模式展开为实际文件列表（原内联写法即如此）
    for f in $cand; do
      if [[ -f "$f" ]]; then
        printf '%s' "$f"
        return 0
      fi
    done
  done
  return 0
}

# 通用源码扫描：在目录中按 ERE 模式 grep（限定源码扩展名），并滤除 test/mock 等噪声行
# $1=ERE 模式；$2=逗号分隔扩展名（如 ts,js,py）；$3=排除用 BRE（\| 分隔，与原内联写法一致）
# 其余参数=扫描目录；无目录参数时 grep -r 退化为扫描当前目录（与原内联写法一致）
_scan_src() {
  local pat="$1" exts="$2" excl="$3"; shift 3
  local inc_args=() e d
  IFS=',' read -ra _exts <<< "$exts"
  for e in "${_exts[@]}"; do
    [[ -n "$e" ]] && inc_args+=("--include=*.$e")
  done
  if [[ $# -eq 0 ]]; then
    grep -rnE "$pat" "${inc_args[@]}" 2>/dev/null | grep -v -i "$excl" || true
    return
  fi
  for d in "$@"; do
    grep -rnE "$pat" "$d" "${inc_args[@]}" 2>/dev/null | grep -v -i "$excl" || true
  done
}

# 数值防御：归一为非负整数（去空白；非纯数字归 0），防 git/grep 异常输出触发数值比较错误
_norm_int() {
  local v
  v=$(echo "$1" | xargs)
  [[ "$v" =~ ^[0-9]+$ ]] || v=0
  printf '%s' "$v"
}

# 提取源文件的相对路径 import（./ ../）并解析为存在的目标文件路径（每行一个）
# 供 check_layer 聚合引用检测与 check_contract ACL 跨上下文检测共用
_resolve_rel_imports() {
  local af="$1"
  local imps imp dir target ext cand
  imps=$(grep -hoE "from ['\"][^'\"]+['\"]|import ['\"][^'\"]+['\"]" "$af" 2>/dev/null \
    | grep -oE "['\"][^'\"]+['\"]" | sed "s/['\"]//g" || true)
  while IFS= read -r imp; do
    [[ -z "$imp" ]] && continue
    case "$imp" in
      ./*|../*) ;;
      *) continue ;;
    esac
    dir=$(dirname "$af")
    target=""
    for ext in ".ts" ".js" ".py" ".tsx" ".jsx"; do
      cand=$(cd "$dir" 2>/dev/null && _resolve_path "${imp}${ext}" 2>/dev/null || echo "")
      if [[ -n "$cand" && -f "$cand" ]]; then target="$cand"; break; fi
    done
    [[ -n "$target" ]] && printf '%s\n' "$target"
  done <<< "$imps"
}

# ===== 配置加载 =====
# 配置变量从 precheck.conf 加载（与脚本同目录）。生成目标技能时按项目实际填充。
# 策略：先初始化全部 conf 变量默认值（避免 conf 未声明时 set -u 崩），
#       再若有 conf 则 source 覆盖。conf 可能含字面 ${}，source 时临时关 set -u。
# 注：框架适配变量（JAVA_BUILD_FILES/MYBATIS_* 等）由注入的 framework-gates 片段消费，
#     本文件内看似未使用，故关闭 SC2034。
# shellcheck disable=SC2034
_default_conf() {
  # 基础配置
  PROJECT_DIR="."
  BRANCH_REGEX='^(feat|fix|refactor)/.+'
  PROTECTED_BRANCHES=("main")
  WRITABLE_DIRS=()
  READONLY_DIRS=()
  TEST_CMD=""
  BUILD_CMD=""
  SCAN_DIRS=()
  CONSISTENCY_DIRS=()
  # DDD / 分层
  LAYER_DEFS=()
  LAYER_ORDER=()
  DOMAIN_LAYER=""
  DOMAIN_FORBIDDEN_IMPORTS=("react" "express" "@nestjs" "sequelize" "typeorm" "prisma" "mongoose" "koa" "fastify" "axios" "node:fs" "node:http" "node:net")
  STABLE_GLOBS=()
  AGGREGATE_DIR=""
  MAX_LINK_DEPTH=0
  # 依赖版本
  CODEBASE_REF=""
  SPEC_FILE=""
  # 认知映射表（check_cognition ④映射可选输入；conf 中 COGNITION_MAP 配置后接入）
  COGNITION_MAP=""
  # TOGAF 架构契约
  ADR_DIR=""
  TECH_DEBT_FILE=""
  CONTRACT_DIR=""
  ACL_DIR=""
  CONTEXT_DIRS=()
  GLOSSARY_FILE=""
  SOR_FILE=""
  IMPACT_SPEC_FILE=""
  # 微服务
  SERVICE_DIRS=()
  SHARED_LIBS_DIR=""
  DB_CONFIG_FILES=()
  API_GATEWAY=""
  MAX_SYNC_CHAIN=0
  API_SPEC_DIR=""
  WRITE_HANDLER_DIRS=()
  # 前端架构
  STORE_DIR=""
  MAX_STORE_LINES=0
  COMPONENT_DIR=""
  MAX_COMPONENT_DEPTH=0
  MAX_PROPS_COUNT=0
  BUNDLE_REPORT=""
  STYLE_DIR=""
  # 认知门禁
  COGNITION_BASELINE=""
  COG_SPEED_FILES=10
  COG_CUMULATIVE_TODO=20
  COG_STRENGTH_FANIN=8
  # 左移门禁（测试/变更/运维监控）
  TEST_DESIGN_FILE=""
  TEST_DIR_PATTERNS=()
  IMPL_DIR_PATTERNS=()
  CHANGE_IMPACT_FILE=""
  # ROLLBACK_KEYWORDS 用 ERE 交替符（不带反斜杠）：grep -E 下 `\|` 是字面量永不匹配，
  # 会把「有回滚预案」的 spec 误判为缺（fail）。本变量经 SPEC_FILE 可达且是硬门禁，2026-07-20 修复。
  # 注：BREAKING_DDL/METRIC/LOG/TRACE 等 warn-only 模式的 `\|` 按 paradigm-decisions.md 决策「保留沉睡」不动。
  ROLLBACK_KEYWORDS="回滚|revert|rollback|灰度|canary|feature.flag|功能开关"
  MIGRATION_DIRS=()
  BREAKING_DDL_PATTERNS="DROP TABLE\|DROP COLUMN\|TRUNCATE\|RENAME TABLE"
  OBSERVABILITY_FILE=""
  METRIC_ENDPOINTS=()
  METRIC_CODE_PATTERNS="metrics\.\|counter\.\|gauge\.\|histogram\.\|prometheus\|statsd\|emitMetric\|recordMetric"
  LOG_CODE_PATTERNS="logger\.\|console\.\(log\|warn\|error\)\|winston\|pino\|log4j\|logging\.\|@Slf4j\|@Log\|log\.\(info\|warn\|error\|debug\)"
  TRACE_CODE_PATTERNS="traceId\|spanId\|openTelemetry\|@Trace\|@Span\|tracer\."
  HEALTH_CHECK_URLS=()
  HEALTH_CHECK_TIMEOUT=3
  # 框架适配（约定式命名 <RULESET_ID>_<VAR>；未激活的框架变量留空数组/空串，门禁片段用 ${VAR:-} 安全展开）
  ACTIVE_FRAMEWORKS=()
  JAVA_BUILD_FILES=()
  MYBATIS_MAPPER_DIRS=()
  MYBATIS_SRC_GLOBS=()
  SQL_INJECTION_WHITELIST=()
  LOMBOK_SRC_GLOBS=()
  SHARDING_KEY_COLUMNS=()
  SHARDED_TABLES=()
  SHARDING_BROADCAST_TABLES=()
  SPRING_BATCH_JOB_DIRS=()
  # 标准合规
  COMPLIANCE_MATRIX_FILE=""
  COMPLIANCE_REQUIRED_SECTIONS=()
  DOCS_PACK_PROFILE=""
  DOCS_PACK_DIR=""
  DOCS_PACK_REQUIRED=()
  DOCS_PACK_ALLOW_TBD=0
  SBOM_REQUIRED=0
  SBOM_OUTPUT_DIR=""
  SBOM_FORMAT=""
  SBOM_TOOL=""
  SBOM_LICENSE_BLOCKLIST=()
  SBOM_LICENSE_EXEMPTIONS=()
  PRIVACY_SCAN_DIRS=()
  PRIVACY_EXTRA_PATTERNS=()
  PRIVACY_SENSITIVE_KEYWORDS=()
  PRIVACY_EXEMPTIONS=()
  # 安全门禁族深化（P1-3/P1-9）：工具链降级 + 授权/需求/密码门禁
  SENSITIVE_TOOL="auto"
  SECURITY_TOOL="auto"
  AUTHZ_SCAN_DIRS=()
  AUTHZ_EXTRA_PATTERNS=()
  REQUIREMENTS_STRICT=0
  REQUIREMENTS_ID_REQUIRED=0
  CRYPTO_PROFILE=""
  CRYPTO_SCAN_DIRS=()
  # 长期清单收口（P3）：需求追溯矩阵（--rtm）+ 发布签名（--release-sign，SLSA Build L2）
  RTM_REQUIRED=0
  RTM_MATRIX_FILE=""
  RTM_MATRIX_REQUIRED=0
  RELEASE_SIGN_REQUIRED=0
  RELEASE_ARTIFACTS_GLOB=""
  RELEASE_SIGN_TOOL=""
  RELEASE_PROVENANCE_REQUIRED=0
  RELEASE_PROVENANCE_FILE=""
  # 门禁工具化（P1-4/P1-5）：gate-runs 证据落盘目录（空=关闭，不影响任何既有输出）
  GATE_RUNS_DIR=""
}
# A 方向：--gate-stats 需读 env GATE_RUNS_DIR（_default_conf 会重置为空），重置前捕获
_ENV_GATE_RUNS_DIR="${GATE_RUNS_DIR:-}"
_default_conf
_CONF_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
# WP-Q1.5：--list-gates / --doctor 在 source conf 前拦截——
# lite 骨架无 precheck.compliance.conf，conf 末尾 `[[ -f X ]] && source X` 返回 1，
# set -e 下 source 返回 1 会退出。--list-gates / --doctor 不依赖 conf，提前拦截。
# 用 $1 直接判断（MODE 在 321 行才赋值，此处尚未解析）。
case "${1:-}" in
  --list-gates|--doctor|--gate-stats|--review-calibrate|--cwe-audit) _skip_conf=1 ;;
  *) _skip_conf=0 ;;
esac
if [[ "$_skip_conf" -eq 1 ]]; then
  : # 跳过 source conf，直接到下方 --doctor / --list-gates 拦截块
elif [[ -f "$_CONF_DIR/precheck.conf" ]]; then
  # 语法判定口径：bash 3.2 的 bash -n 对 EOF 类错误（如未闭合数组/引号）报错却仍 exit 0，
  # 故「stderr 非空 或 非零退出」才算语法错误。
  _conf_synerr=$(bash -n "$_CONF_DIR/precheck.conf" 2>&1 || true)
  if [[ -z "$_conf_synerr" ]]; then
    set +u
    # shellcheck disable=SC1090
    # shellcheck source=/dev/null
    # WP-R Bug#2: source conf 末条语句可能返回非零（[[ -f ]] && source 兄弟 conf 不存在时返回 1），
    # set -e 下会使 precheck.sh 在此退出（所有门禁静默失效）。|| true 兜底，conf 内容已 source 生效。
    source "$_CONF_DIR/precheck.conf" || true
    set -u
  else
    # conf 语法错误（P1-4 前置守卫）：原行为是 source 直接崩（exit 2 且报错文本随 bash 版本漂移）。
    # --doctor 是 conf lint，须能带病启动（走内置默认值，由 doctor ⑤ 报 fail）；
    # 其余模式配置不可靠，报清错误后 exit 2（与原 source 崩溃路径同码）。
    case " $* " in
      *\ --doctor\ *)
        echo "⚠ precheck.conf 语法错误——内置默认值兜底，--doctor 继续诊断" >&2
        ;;
      *)
        printf '%s\n' "$_conf_synerr" | head -3 >&2
        echo "✗ precheck.conf 语法错误，无法加载（可运行 --doctor 做完整诊断）" >&2
        exit 2
        ;;
    esac
  fi
  unset _conf_synerr
fi
# 兜底：source conf 后，对 conf 仍未声明的关键变量补空默认值（已声明的保留用户值）。
# 用 ${VAR+x} 判断是否已声明——未声明则补空数组/空串，防 set -u 崩。
# 数组变量（门禁片段用 ${VAR[@]+"${VAR[@]}"} 或 ${#VAR[@]} 引用，未声明会 unbound）
for _conf_var in MYBATIS_MAPPER_DIRS SQL_INJECTION_WHITELIST SHARDING_KEY_COLUMNS \
    SHARDED_TABLES SHARDING_BROADCAST_TABLES MYBATIS_SRC_GLOBS LOMBOK_SRC_GLOBS \
    SPRING_BATCH_JOB_DIRS JAVA_BUILD_FILES LAYER_DEFS TEST_DIR_PATTERNS \
    IMPL_DIR_PATTERNS MIGRATION_DIRS METRIC_ENDPOINTS HEALTH_CHECK_URLS \
    CONTEXT_DIRS DB_CONFIG_FILES WRITE_HANDLER_DIRS STABLE_GLOBS SERVICE_DIRS \
    COMPLIANCE_REQUIRED_SECTIONS DOCS_PACK_REQUIRED SBOM_LICENSE_BLOCKLIST \
    SBOM_LICENSE_EXEMPTIONS PRIVACY_SCAN_DIRS PRIVACY_EXTRA_PATTERNS \
    PRIVACY_SENSITIVE_KEYWORDS PRIVACY_EXEMPTIONS \
    AUTHZ_SCAN_DIRS AUTHZ_EXTRA_PATTERNS CRYPTO_SCAN_DIRS SECURITY_SCAN_DIRS \
    OSS_EVAL_REQUIRED QUALITY_MODEL_REQUIRED TEST_EVIDENCE_REQUIRED REVIEW_RECORD_REQUIRED \
    PIA_EXEMPTIONS SAST_DEEP_EXEMPTIONS \
    DRUID_CONFIG_FILES; do
  if [[ -z "${!_conf_var+x}" ]]; then eval "$_conf_var=()"; fi
done
unset _conf_var

# CLI 解析（P1-4/P1-5 扩展）：--format json|text（默认 text，text 模式输出与原实现逐字节一致）、
# --doctor 子命令（conf lint，非门禁、不入注册表）。其余参数沿用原语义：
# 第一个位置参数为 MODE，多余位置参数忽略（与原 MODE="${1:---all}" 行为一致——
# ${1:-} 对未设/空串同取默认值，故空串参数同样回落 --all）。
FORMAT="text"
MODE=""
FRAMEWORK_ID=""
_CAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      [[ $# -ge 2 ]] || { echo "✗ --format 缺少取值（json|text）" >&2; exit 1; }
      FORMAT="$2"; shift 2
      ;;
    --format=*)
      FORMAT="${1#--format=}"; shift
      ;;
    --framework)
      # --framework <id>：MODE=--framework，FRAMEWORK_ID=<id>（缺 id 则全量串联，兼容原行为）
      MODE="--framework"
      if [[ $# -ge 2 && "$2" != --* ]]; then FRAMEWORK_ID="$2"; shift 2; else shift; fi
      ;;
    --list-gates)
      # WP-Q1.5：列出所有门禁的 flag / 函数名 / enforce_level 三列表
      MODE="--list-gates"
      shift
      ;;
    --review-calibrate)
      # A 方向：置信度标定——保留后续参数（record --confidence/--verdict/--finding 或 stats）
      MODE="--review-calibrate"
      shift
      _CAL_ARGS=("$@")
      break
      ;;
    *)
      [[ -z "$MODE" ]] && MODE="$1"
      shift
      ;;
  esac
done
[[ -n "$MODE" ]] || MODE="--all"
case "$FORMAT" in
  json|text) ;;
  *) echo "✗ --format 仅支持 json|text（收到: ${FORMAT}）" >&2; exit 1 ;;
esac
FAIL=0
# SILENT=1 时，未配置的门禁静默跳过（不打印 warn），减少 --all-full/--compliance-suite 噪音
SILENT=0
[[ "$MODE" == "--all-full" || "$MODE" == "--compliance-suite" ]] && SILENT=1
# ===== WP-H 状态门：所属 skill 为 draft（骨架填充未完成）时禁用全量门禁集 =====
# draft = 生成器产出的未填充骨架（SKILL.md frontmatter `status: draft`）。
# 半填充产物跑全量门禁会给"接近可用"的错觉——禁用 --all-full/--compliance-suite；
# 单门禁与 --all 不受影响（填充中段仍需局部自检）。--mark-active 核验零占位符后解锁。
# 位置：须在 cd "$PROJECT_DIR" 之前（draft 骨架 conf 含占位路径，cd 会先失败掩盖本提示）。
_skill_md="${_CONF_DIR}/../SKILL.md"
if [[ -f "$_skill_md" ]] && grep -q '^status: draft' "$_skill_md" 2>/dev/null; then
  case "$MODE" in
    --all-full|--compliance-suite)
      echo "✗ 所属 skill 为 draft 状态（骨架填充未完成），--all-full/--compliance-suite 已禁用" >&2
      echo "  完成填充后运行: bash generate-skill.sh --mark-active <skill_dir>" >&2
      exit 2 ;;
  esac
fi
# WP-P6：profile 漂移检测（轻量，stderr 输出，不阻塞主流程；只升不降，质量优先）
# 重跑 auto_detect_profile 逻辑对比 frontmatter profile，升档漂移 warn 提示升级
if [[ -f "${_CONF_DIR}/detect-profile-drift.sh" ]]; then
  bash "${_CONF_DIR}/detect-profile-drift.sh" "${_CONF_DIR}/.." 2>/dev/null || true
fi
# WP-P7：spec 规模检测（轻量，stderr 输出，不阻塞主流程；规模与门禁集不匹配 warn 提示升档）
# 若 SPEC_FILE 存在，推断规模等级，当前 MODE < 推断档则 warn 提示升档（只升不降）
if [[ -n "${SPEC_FILE:-}" && -f "${SPEC_FILE}" && -f "${_CONF_DIR}/detect-spec-scale.sh" ]]; then
  _spec_scale=$(bash "${_CONF_DIR}/detect-spec-scale.sh" "${SPEC_FILE}" 2>/dev/null | tail -1 || true)
  case "$_spec_scale" in
    完整)
      case "$MODE" in --all) echo "⚠ spec 规模推断为「完整」，当前 --all 偏轻，建议升级 --all-full --shift-left（质量优先）" >&2;; esac
      ;;
    标准)
      case "$MODE" in --all) echo "⚠ spec 规模推断为「标准」，当前 --all 偏轻，建议升级 --all-full（质量优先）" >&2;; esac
      ;;
  esac
  unset _spec_scale
fi
# 执行汇总计数器（非破坏披露：只统计与末次汇总打印，不改任何门禁判定与输出行）
INVOKE_COUNT=0
SKIP_COUNT=0
SKIP_LIST=""
WARN_COUNT=0
FAIL_COUNT=0
# WP-B2：FAIL_IDS 收集 fail id（fail 首参数含 gate_xxx/fw_xxx id），供 fail 汇总段输出修复建议。
# 兼容 bash 3.2：用换行分隔的字符串累积（不用 declare -A），去重靠 grep -F。
FAIL_IDS=""
# _CURRENT_GATE：当前分发中的门禁函数名（三个分发循环赋值），供跳过计数去重
_CURRENT_GATE=""
pass() { echo "  ✓ $1"; }
# WP-B2：fail() 除 FAIL_COUNT++ 外，提取首参数的 fail id（gate_xxx/fw_xxx 前缀）追加到 FAIL_IDS。
# 首参数形如 "gate_requirements_tbd:12: spec 含 TBD" 或 "fw_vue_script_setup: ..."——取首个 : 前或整串。
fail() {
  echo "  ✗ $1"; FAIL=1; FAIL_COUNT=$((FAIL_COUNT+1));
  local _id="${1%%:*}"
  [[ "$_id" == "$1" ]] && _id="$1"
  # 去重累积
  if [[ -z "$FAIL_IDS" ]] || ! printf '%s\n' "$FAIL_IDS" | grep -qxF "$_id"; then
    FAIL_IDS="${FAIL_IDS}${FAIL_IDS:+$'\n'}${_id}"
  fi
}
warn() { WARN_COUNT=$((WARN_COUNT+1)); if [[ $SILENT -eq 0 ]]; then echo "  ⚠ $1"; fi; }
# skip_if_unconfigured: 未配置时静默跳过（--all-full/--compliance-suite）或 SKIPPED 单列提示（显式调用）
# WP-F 诚实化：跳过 ≠ 警告——不进 WARN_COUNT（防"绿≠合规"虚增），用独立 ⊘ SKIPPED 标记单列
skip_if_unconfigured() {
  # 跳过计数按 _CURRENT_GATE 去重（同一门禁内多次跳过只计一次）
  if [[ -n "$_CURRENT_GATE" ]]; then
    case " $SKIP_LIST " in
      *" $_CURRENT_GATE "*) ;;
      *) SKIP_LIST="${SKIP_LIST} ${_CURRENT_GATE}"; SKIP_COUNT=$((SKIP_COUNT+1));;
    esac
  fi
  if [[ $SILENT -eq 1 ]]; then return 0; fi
  echo "  ⊘ SKIPPED（未配置）: $1"
  return 0
}

# ===== 门禁注册表（--all/--all-full 执行序列 + 单门禁 flag 清单）=====
# 核心门禁（适用所有项目）：分支/范围/构建/敏感/一致性/审查/复用/依赖/安全/测试
ALL_GATES_CORE=(check_branch check_scope check_build check_sensitive check_consistency check_review check_reuse check_deps check_security check_test)
# 合规门禁（标准合规族 + P1 安全门禁族深化 + P3 长期清单 rtm/release-sign，仅 --compliance-suite/单门禁执行；未配置的静默跳过）
ALL_GATES_COMPLIANCE=(check_compliance check_docs_pack check_sbom check_privacy check_authz check_requirements check_crypto check_rtm check_dengbao check_pia check_sast_deep check_oss_eval check_quality_model check_test_evidence check_review_record check_metrics check_release_sign)
# 标准门禁（核心 10 + 架构 17 = 27）：--all-full 执行序列（合规 13 已拆出为 --compliance-suite 按需执行）
ALL_GATES_STANDARD=(check_branch check_scope check_build check_sensitive check_consistency check_review check_reuse check_deps check_security check_layer check_stable_diff check_link_depth check_adr check_contract check_consistency_cross check_impact check_service check_api check_state check_frontend check_cognition check_domain check_knowledge check_mermaid check_shift_left check_framework check_test)
# 全部门禁（含架构/认知/合规门禁，未配置的静默跳过；--fix-suggest 用）
ALL_GATES_FULL=(check_branch check_scope check_build check_sensitive check_consistency check_review check_reuse check_deps check_security check_layer check_stable_diff check_link_depth check_adr check_contract check_consistency_cross check_impact check_service check_api check_state check_frontend check_cognition check_domain check_knowledge check_mermaid check_shift_left check_framework check_compliance check_docs_pack check_sbom check_privacy check_authz check_requirements check_crypto check_rtm check_dengbao check_pia check_sast_deep check_oss_eval check_quality_model check_test_evidence check_review_record check_metrics check_release_sign check_test)
# 单门禁 flag 清单（Usage 顺序）。flag → 函数映射规则：check_ + flag 去 -- 前缀并将 - 转为 _
#（如 --stable-diff → check_stable_diff；--consistency-cross → check_consistency_cross）
GATE_FLAGS=(--branch --scope --build --test --sensitive --consistency --review --reuse --deps --security --layer --stable-diff --link-depth --adr --contract --consistency-cross --impact --service --api --state --frontend --cognition --domain --knowledge --mermaid --shift-left --framework --compliance --docs-pack --sbom --privacy --authz --requirements --crypto --rtm --dengbao --pia --sast-deep --oss-eval --quality-model --test-evidence --review-record --metrics --release-sign --operate --decision-audit --canary --cwe-audit --cert-audit --pr-quality --skill-supply-chain --state-phase --upstream-baseline --learnings)

# ===== 门禁分层 enforce_level（决策 19：strict/warn/advisory 三档）=====
# 自动按 fail() 调用数归类（gen-enforce-level.sh 生成 gate-enforce-level.conf）：
#   strict   ≥3 fail —— 真正能阻断交付的硬门禁（lite/standard/compliance 档都跑，真 fail）
#   warn     1-2 fail —— 混合 warn，能 fail 但触发条件窄（standard+ 档跑，fail+warn 都计数）
#   advisory 0 fail  —— 永不 fail，只 warn/pass（认知/观测类；advisory 路径在子shell 内
#                       重定义 fail/warn 为纯 echo，永不进 FAIL_COUNT/WARN_COUNT）
# 横切维度：与 core/standard/compliance 正交（一个门禁同时属于 core + strict，或 standard + advisory）。
# 手动覆盖：在下方 _ENFORCE_OVERRIDE 数组登记（优先级高于自动生成的 conf）。
_ENFORCE_OVERRIDE_K=()   # 手动覆盖的 check_<fn> 名（与 _ENFORCE_OVERRIDE_V 同下标对齐）
_ENFORCE_OVERRIDE_V=()   # 对应的 enforce_level（strict|warn|advisory）
# 示例（需用时取消注释）：
# _ENFORCE_OVERRIDE_K+=(check_review)
# _ENFORCE_OVERRIDE_V+=(strict)

# _enforce_of：查门禁的 enforce_level。$1=check_<fn>，stdout 输出 strict|warn|advisory。
# 优先级：_ENFORCE_OVERRIDE > gate-enforce-level.conf > 默认 warn（未登记走 warn，保守）。
# bash 3.2 兼容：不用 declare -A，用并行索引数组 + for 循环查表。
_enforce_of() {
  local fn="$1" i k
  # 1. 手动覆盖优先
  for i in "${!_ENFORCE_OVERRIDE_K[@]}"; do
    k="${_ENFORCE_OVERRIDE_K[$i]:-}"
    [[ "$k" == "$fn" ]] && { echo "${_ENFORCE_OVERRIDE_V[$i]:-warn}"; return; }
  done
  # 2. 读 gate-enforce-level.conf（若存在且已 source 过 GATE_ENFORCE_LEVEL_KV 字符串）
  if [[ -n "${GATE_ENFORCE_LEVEL_KV:-}" ]]; then
    # GATE_ENFORCE_LEVEL_KV 是换行分隔的 "fn=level" 字符串（bash 3.2 关联数组替代）
    local _lv
    _lv=$(printf '%s\n' "$GATE_ENFORCE_LEVEL_KV" | awk -F= -v k="$fn" '$1==k{print $2; exit}')
    [[ -n "$_lv" ]] && { echo "$_lv"; return; }
  fi
  # 3. 默认 warn（保守：未登记的门禁按 warn 处理，不降级 advisory）
  echo "warn"
}

# _load_enforce_levels：启动时读 gate-enforce-level.conf 到 GATE_ENFORCE_LEVEL_KV 字符串。
# 兼容 bash 3.2（不用 declare -A）。开发态：与 precheck.sh 同目录读 conf；
# 打包态（SWARM_YUAN_BUNDLED=1）：conf 内容已内联，本函数为 noop。
GATE_ENFORCE_LEVEL_KV=""
_load_enforce_levels() {
  local conf
  # 开发态：与 precheck.sh 同目录的 gate-enforce-level.conf
  conf="$(dirname "$0")/gate-enforce-level.conf"
  if [[ -f "$conf" ]]; then
    # 只取 "check_xxx=level" 行，跳过注释与空行
    GATE_ENFORCE_LEVEL_KV=$(grep -E '^check_[a-z_]+=(strict|warn|advisory)$' "$conf" 2>/dev/null || true)
    return
  fi
  # 打包态：conf 内容由 install.sh 内联为 GATE_ENFORCE_LEVEL_INLINE（多行字符串字面量）
  if [[ -n "${GATE_ENFORCE_LEVEL_INLINE:-}" ]]; then
    GATE_ENFORCE_LEVEL_KV="$GATE_ENFORCE_LEVEL_INLINE"
    return
  fi
  # conf 不存在且无内联：所有门禁走默认 warn（保守）
  :
}
_load_enforce_levels

# ===== WP-Q1.3 门禁函数 source 守卫（决策 19：三档拆分）=====
# 开发态：source gates-strict/warn/advisory.sh 三文件（与 precheck.sh 同目录）
# 打包态：install.sh 已内联三文件内容，SWARM_YUAN_BUNDLED=1 跳过 source
if [[ -z "${SWARM_YUAN_BUNDLED:-}" ]]; then
  for _gf in gates-strict.sh gates-warn.sh gates-advisory.sh; do
    _gp="$(dirname "$0")/$_gf"
    # WP-R Bug#2: [[ -f ]] && source 在循环末条时，文件缺失返回 1 会触发 set -e。|| true 兜底。
    [[ -f "$_gp" ]] && source "$_gp" || true
  done
fi

# Usage 文本由 GATE_FLAGS 生成
_usage() {
  local u="Usage: bash precheck.sh [--all|--all-full|--compliance-suite|--list-gates" f
  for f in "${GATE_FLAGS[@]}"; do u="${u}|${f}"; done
  echo "${u}]"
}

# ===== --doctor：conf 诊断（P1-4；非门禁、不入注册表、不参与门禁判定）=====
# 逐项 lint：①PROJECT_DIR 存在；②WRITABLE_DIRS/READONLY_DIRS/SCAN_DIRS 各 glob
# 可解出至少一个路径（不可解 warn）；③死变量（conf 定义但 precheck.sh 正文与
# framework-gates 片段均零引用，正文口径=剔除 _default_conf 与数组兜底循环；
# 参照 R2 审计的既有死变量先例——注意本注释不得点名具体变量，否则自引用失真）；
# ④ACTIVE_FRAMEWORKS 每个框架的 requires_conf 齐备；⑤conf 语法 sanity（bash -n）。
# 输出 pass/warn/fail 汇总，fail 才 exit 1。
_DR_PASS=0; _DR_WARN=0; _DR_FAIL=0
_dr_ok()   { _DR_PASS=$((_DR_PASS+1)); echo "  ✓ $1"; }
_dr_warn() { _DR_WARN=$((_DR_WARN+1)); echo "  ⚠ $1"; }
_dr_bad()  { _DR_FAIL=$((_DR_FAIL+1)); echo "  ✗ $1"; }

# 单条 glob/路径可解出判定（cwd 须已是 PROJECT_DIR）：与 _fw_resolve_globs 同算法拆 **；
# 无 ** 的通配走 nullglob 子壳展开（bash 3.2 兼容，不依赖 compgen -G），普通路径 -e 判定。
_dr_glob_resolves() {
  local g="$1" dir name
  case "$g" in
    *\*\**|*\[*|*\?*)
      dir="${g%%/\*\*/*}"
      if [[ "$dir" != "$g" ]]; then
        name="${g##*/}"
        [[ -d "$dir" ]] || return 1
        [[ -n "$(find "$dir" -name "$name" -print -quit 2>/dev/null)" ]]
      else
        ( shopt -s nullglob; set -- $g; [[ $# -gt 0 ]] )
      fi
      ;;
    *) [[ -e "$g" ]] ;;
  esac
}

# 目录数组逐 glob 可达检查（bash 3.2 无 nameref，用 eval 间接展开）
_dr_glob_check() { # $1=数组变量名
  local vn="$1" n i g
  eval "n=\${#${vn}[@]}"
  if [[ "$n" -eq 0 ]]; then
    _dr_warn "$vn 为空数组——未配置"
    return 0
  fi
  for (( i=0; i<n; i++ )); do
    eval "g=\"\${${vn}[$i]}\""
    if _dr_glob_resolves "$g"; then
      _dr_ok "$vn[$i] '$g' 可解出"
    else
      _dr_warn "$vn[$i] '$g' 不可解出任何路径（相对 PROJECT_DIR）"
    fi
  done
  return 0
}

_run_doctor() {
  local sh_dir conf sh
  sh_dir="$_CONF_DIR"
  conf="$sh_dir/precheck.conf"
  sh="$sh_dir/precheck.sh"
  echo "=== conf 诊断（--doctor）==="

  # ⑤ conf 语法 sanity（含数组语法；先于其余项，语法错时 source 语义已不可靠）
  # 判定口径同启动守卫：stderr 非空 或 非零退出 即语法错误（bash 3.2 -n 对 EOF 类错误仍 exit 0）
  if [[ -f "$conf" ]]; then
    local _synerr
    _synerr=$(bash -n "$conf" 2>&1 || true)
    if [[ -z "$_synerr" ]]; then
      _dr_ok "conf 语法 sanity：bash -n 通过"
    else
      _dr_bad "conf 语法错误：$(printf '%s\n' "$_synerr" | head -1)"
    fi
  else
    _dr_warn "conf 不存在（${conf}）——全部变量走内置默认值"
  fi
  # WP-I：兄弟 conf（arch/compliance）语法 sanity（存在才查）
  local _sib
  for _sib in "$sh_dir/precheck.arch.conf" "$sh_dir/precheck.compliance.conf"; do
    [[ -f "$_sib" ]] || continue
    local _synerr2
    _synerr2=$(bash -n "$_sib" 2>&1 || true)
    if [[ -z "$_synerr2" ]]; then
      _dr_ok "$(basename "$_sib") 语法 sanity：bash -n 通过"
    else
      _dr_bad "$(basename "$_sib") 语法错误：$(printf '%s\n' "$_synerr2" | head -1)"
    fi
  done

  # ① PROJECT_DIR 存在
  if [[ -d "$PROJECT_DIR" ]]; then
    _dr_ok "PROJECT_DIR 存在：$PROJECT_DIR"
  else
    _dr_bad "PROJECT_DIR 不存在：$PROJECT_DIR"
  fi

  # ② 三组目录数组逐 glob 可达（不可达只 warn；PROJECT_DIR 缺失时整项跳过）
  if [[ -d "$PROJECT_DIR" ]]; then
    cd "$PROJECT_DIR" 2>/dev/null || true
    local _dv
    for _dv in WRITABLE_DIRS READONLY_DIRS SCAN_DIRS; do
      _dr_glob_check "$_dv"
    done
  else
    _dr_warn "PROJECT_DIR 不可达——WRITABLE_DIRS/READONLY_DIRS/SCAN_DIRS glob 检查跳过"
  fi

  # ③ 死变量：conf 定义但「precheck.sh 正文（剔除 _default_conf 与数组兜底循环）
  #    + framework-gates/*.sh」均零引用 → warn 汇总列出
  if [[ -f "$conf" && -f "$sh" ]]; then
    local _refs _v _dead="" _f
    _refs=$(awk '
      /^_default_conf[(][)] [{]/ {indef=1; next}
      indef==1 && /^[}]/ {indef=0; next}
      indef==1 {next}
      /^for _conf_var in/ {inloop=1; next}
      inloop==1 && /^done/ {inloop=0; next}
      inloop==1 {next}
      {print}
    ' "$sh")
    for _f in "$sh_dir"/framework-gates/*.sh; do
      [[ -f "$_f" ]] && _refs="${_refs}
$(cat "$_f")"
    done
    # WP-I：conf 物理三分——变量定义扫描合并三个文件（存在的才拼），core/arch/compliance 全覆盖
    local _conf_all=""
    for _f in "$conf" "$sh_dir/precheck.arch.conf" "$sh_dir/precheck.compliance.conf"; do
      [[ -f "$_f" ]] && _conf_all="${_conf_all}
$(cat "$_f")"
    done
    for _v in $(printf '%s\n' "$_conf_all" | sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' | sort -u); do
      # 注：不能用 grep -q——pipefail 下 grep -q 提前退出会使 printf 收 SIGPIPE(141)，
      # 管道整体非零而把全部变量误判为死变量。grep -c 读全量输入，无此问题。
      if [[ $(printf '%s\n' "$_refs" | grep -c -w "$_v" || true) -eq 0 ]]; then
        _dead="${_dead} ${_v}"
      fi
    done
    if [[ -n "$_dead" ]]; then
      _dr_warn "死变量（conf 定义但脚本/片段零引用）：${_dead# }"
    else
      _dr_ok "无死变量（conf 定义项均有消费方）"
    fi
  elif [[ ! -f "$conf" ]]; then
    _dr_warn "conf 缺失——死变量检查跳过"
  fi

  # ④ ACTIVE_FRAMEWORKS 逐框架：实现存在（片段文件或已注入内联函数）+ requires_conf 齐备
  if [[ ${#ACTIVE_FRAMEWORKS[@]} -eq 0 ]]; then
    _dr_ok "ACTIVE_FRAMEWORKS 为空——无框架 requires_conf 待核"
  else
    local fw fn frag req v miss
    for fw in ${ACTIVE_FRAMEWORKS[@]+"${ACTIVE_FRAMEWORKS[@]}"}; do
      fn="_fw_$(printf '%s' "$fw" | tr '-' '_')_check"
      frag="$sh_dir/framework-gates/$fw.sh"
      req=""
      if [[ -f "$frag" ]]; then
        req=$(sed -n 's/^# ruleset:.*requires_conf: *//p' "$frag" | tr -s ' ')
      elif [[ -f "$sh" ]] && grep -q "^${fn}()" "$sh" 2>/dev/null; then
        # 已注入内联：requires_conf 头注释随片段一并注入（generate-skill.sh 注入契约）
        req=$(sed -n "s/^# ruleset: ${fw}  *requires_conf: *//p" "$sh" | tr -s ' ')
      else
        _dr_bad "框架 '$fw' 已激活但无门禁实现（$frag 缺失且未内联注入）"
        continue
      fi
      miss=""
      for v in $req; do
        [[ -z "${!v+x}" ]] && miss="${miss} ${v}"
      done
      if [[ -n "$miss" ]]; then
        _dr_warn "框架 '$fw' requires_conf 未声明：${miss# }（须补 conf 声明或重跑 generate-skill.sh --inject-frameworks）"
      else
        _dr_ok "框架 '$fw' requires_conf 齐备（${req:-无声明}）"
      fi
    done
  fi

  echo "—— doctor 汇总：pass ${_DR_PASS}，warn ${_DR_WARN}，fail ${_DR_FAIL} ——"
  [[ $_DR_FAIL -eq 0 ]]
}

# --doctor 在 cd 前拦截：PROJECT_DIR 本身即诊断对象，不存在时不能先 cd 崩溃
if [[ "$MODE" == "--doctor" ]]; then
  _dr_rc=0
  _run_doctor || _dr_rc=$?
  exit "$_dr_rc"
fi

# --list-gates 在 cd 前拦截：不需要 PROJECT_DIR，只读门禁注册表与 enforce_level
if [[ "$MODE" == "--list-gates" ]]; then
  printf '%-18s %-26s %-10s %s\n' "FLAG" "GATE_FN" "ENFORCE" "TIER"
  _i=""; _flag=""; _fn=""; _enf=""; _tier=""; _g=""; _s=0; _w=0; _a=0
  for _i in "${!GATE_FLAGS[@]}"; do
    _flag="${GATE_FLAGS[$_i]}"
    _fn="check_$(printf '%s' "${_flag#--}" | tr '-' '_')"
    _enf=$(_enforce_of "$_fn")
    _tier=""
    for _g in "${ALL_GATES_CORE[@]}"; do [[ "$_g" == "$_fn" ]] && _tier="${_tier}${_tier:+ }core"; done
    for _g in "${ALL_GATES_STANDARD[@]}"; do [[ "$_g" == "$_fn" ]] && _tier="${_tier}${_tier:+ }standard"; done
    for _g in "${ALL_GATES_COMPLIANCE[@]}"; do [[ "$_g" == "$_fn" ]] && _tier="${_tier}${_tier:+ }compliance"; done
    [[ -z "$_tier" ]] && _tier="(none)"
    printf '%-18s %-26s %-10s %s\n' "$_flag" "$_fn" "$_enf" "$_tier"
  done
  echo ""
  _s=0; _w=0; _a=0
  for _i in "${!GATE_FLAGS[@]}"; do
    _fn="check_$(printf '%s' "${GATE_FLAGS[$_i]#--}" | tr '-' '_')"
    case "$(_enforce_of "$_fn")" in
      strict) _s=$((_s+1)) ;;
      warn)   _w=$((_w+1)) ;;
      advisory) _a=$((_a+1)) ;;
    esac
  done
  echo "汇总：strict ${_s} / warn ${_w} / advisory ${_a} = ${#GATE_FLAGS[@]}"
  exit 0
fi

# --gate-stats（A 方向：adaptive gating 降级提示，gstack 吸收，治沉睡门禁）
# 读 gate-runs.jsonl 统计每门禁连续零发现（status=pass 且 ids 空）次数；
# advisory 门连续 N 次（默认 10）零发现 → warn 提示降级；安全类 NEVER_GATE 豁免。
# 仅提示不自动降级（用户决策）。不需 cd PROJECT_DIR（读 GATE_RUNS_DIR 或默认路径），cd 前拦截。
if [[ "$MODE" == "--gate-stats" ]]; then
  _stats_file="${GATE_RUNS_DIR:-${_ENV_GATE_RUNS_DIR:-${PROJECT_DIR:-$(pwd)}/.swarm-yuan/gate-runs}}/gate-runs.jsonl"
  if [[ ! -f "$_stats_file" ]]; then
    echo "⚠ 无 gate-runs.jsonl（${_stats_file}）——需配置 GATE_RUNS_DIR 并跑过门禁"
    exit 0
  fi
  _never_gate=" sensitive security authz privacy crypto sbom release-sign "
  echo "=== adaptive gating 降级提示（连续 10 次零发现的 advisory 门）==="
  # 提取所有出现过的门禁名（去重）
  _gs_gates=$(grep -oE '"gate":"[^"]*"' "$_stats_file" 2>/dev/null | sed 's/"gate":"//;s/"$//' | sort -u)
  for _g in $_gs_gates; do
    # 安全类 NEVER_GATE 跳过
    echo "$_never_gate" | grep -q " ${_g#check_} " && continue
    # 从尾部向前连续计数 had_finding=false（status=pass 且 ids 空 []）
    _streak=$(grep "\"gate\":\"$_g\"" "$_stats_file" 2>/dev/null | tac | \
      awk -F'"status":"' '{split($2,a,"\""); s=a[1]}
           /"ids":\[\]/{if(s=="pass") c++; else exit}
           /"ids":\[.\]/{exit}
           END{print c+0}')
    [[ "${_streak:-0}" -ge 10 ]] && \
      echo "  ⚠ ${_g} 连续 ${_streak} 次零发现，建议评估降级（adaptive gating；安全类 NEVER_GATE 已豁免）"
  done
  echo "  （仅提示不自动降级——用户决策；安全类门 sensitive/security/authz/privacy/crypto/sbom/release-sign 永不降级）"
  exit 0
fi

# --review-calibrate（A 方向：置信度标定学习闭环，gstack 吸收）
# 用法：--review-calibrate record --confidence <high|medium|low> --verdict <true|false> [--finding <描述>]
#       --review-calibrate stats
# record：落盘一条标定记录（置信度 + 用户确认结果）到 .swarm-yuan/review-calibration.jsonl
# stats：统计各置信度级别的真发现率（confirmed/total），反哺后续审查置信度阈值校准
# 姿态：独立子命令（非门禁），exit 0 不阻塞；标定历史反哺是 advisory。
if [[ "$MODE" == "--review-calibrate" ]]; then
  _cal_file="${PROJECT_DIR:-$(pwd)}/.swarm-yuan/review-calibration.jsonl"
  _cal_act="${_CAL_ARGS[0]:-stats}"
  case "$_cal_act" in
    record)
      _cal_conf=""; _cal_verdict=""; _cal_finding=""
      set -- ${_CAL_ARGS[@]+"${_CAL_ARGS[@]}"}
      shift 2>/dev/null || true  # 去掉 record
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --confidence) _cal_conf="${2:-}"; shift 2 ;;
          --verdict) _cal_verdict="${2:-}"; shift 2 ;;
          --finding) _cal_finding="${2:-}"; shift 2 ;;
          *) shift ;;
        esac
      done
      if [[ -z "$_cal_conf" || -z "$_cal_verdict" ]]; then
        echo "Usage: precheck.sh --review-calibrate record --confidence <high|medium|low> --verdict <true|false> [--finding <描述>]" >&2
        exit 1
      fi
      mkdir -p "$(dirname "$_cal_file")" 2>/dev/null
      printf '{"ts":"%s","confidence":"%s","verdict":"%s","finding":"%s"}\n' \
        "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$_cal_conf" "$_cal_verdict" \
        "$(printf '%s' "$_cal_finding" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\r\n')" >> "$_cal_file"
      echo "✓ 标定记录已落盘：confidence=${_cal_conf} verdict=${_cal_verdict} → ${_cal_file}"
      ;;
    stats|"")
      if [[ ! -f "$_cal_file" ]]; then
        echo "（无标定历史——用 '--review-calibrate record' 记录 finding 置信度+用户确认）"
        exit 0
      fi
      echo "=== 置信度标定统计（review-calibration.jsonl，gstack 标定学习）==="
      for _lv in high medium low; do
        # grep -c 零命中时输出 0 但 exit 1；|| true 保留 "0"，避免 || echo 0 双输出 "0\n0"
        _total=$(grep -c "\"confidence\":\"$_lv\"" "$_cal_file" 2>/dev/null || true)
        _true=$(grep "\"confidence\":\"$_lv\"" "$_cal_file" 2>/dev/null | grep -c '"verdict":"true"' || true)
        _total="${_total:-0}"; _true="${_true:-0}"
        if [[ "$_total" -gt 0 ]]; then
          _rate=$(( _true * 100 / _total ))
          echo "  ${_lv}: ${_true}/${_total} 真发现（${_rate}%）"
          # 标定反哺建议：某置信度真发现率过低 → 建议压附录/丢弃
          [[ "$_rate" -lt 30 && "$_total" -ge 5 ]] && \
            echo "    ⚠ ${_lv} 置信度真发现率仅 ${_rate}%（≥5 样本），建议该级 finding 压附录或提 pre-emit 引用门阈值"
        fi
      done
      ;;
    *) echo "未知操作: $_cal_act（record|stats）" >&2; exit 1 ;;
  esac
  exit 0
fi

cd "$PROJECT_DIR"

# ===== 门禁工具化运行时（P1-4/P1-5）：--format json + gate-runs 证据落盘 =====
# 铁律约束：FORMAT=text 且 GATE_RUNS_DIR 为空时 _gate_exec 走原始分发路径
#（零包装、零输出差异，golden-vector / cli-ab 契约不破）；仅 json 模式或证据
# 落盘开启时才捕获门禁输出到临时文件再 cat 回放（stdout 仍逐字节一致）。
GATE_JSON_OUT="${GATE_JSON_OUT:-}"   # 环境变量：json 结果落盘路径（空=打印到 stdout 末尾）
GATE_RUNS_DIR="${GATE_RUNS_DIR:-}"   # conf 变量：证据落盘目录（空=关闭；_default_conf 兜底）
_EVIDENCE_ON=0
[[ "$FORMAT" == "json" || -n "$GATE_RUNS_DIR" ]] && _EVIDENCE_ON=1
_GATE_TMP=""
_JSON_RESULTS=""
_JSON_SEP=""
_JSON_EMITTED=0
# EXIT 兜底：单门禁 fail-fast 路径（set -e 直退、跳过末尾汇总，遗留语义）下
# json 结果仍会输出；text 模式永不触发 _emit_json（零输出差异）。trap 不改退出码。
_on_exit() {
  if [[ "$FORMAT" == "json" && "$_JSON_EMITTED" -eq 0 && -n "$_JSON_RESULTS" ]]; then
    _emit_json
  fi
  [[ -n "$_GATE_TMP" ]] && rm -f "$_GATE_TMP"
  return 0
}
if [[ "$_EVIDENCE_ON" -eq 1 ]]; then
  _GATE_TMP=$(mktemp /tmp/precheck-gate-capture.XXXXXX)
  trap '_on_exit' EXIT
  if [[ -n "$GATE_RUNS_DIR" ]]; then
    mkdir -p "$GATE_RUNS_DIR" 2>/dev/null || true
    if [[ ! -d "$GATE_RUNS_DIR" ]]; then
      warn "GATE_RUNS_DIR($GATE_RUNS_DIR) 不可创建——gate-runs 证据落盘降级关闭"
      GATE_RUNS_DIR=""
    fi
  fi
fi

# 从门禁捕获输出提取 id 清单（best-effort）：取 "✓ id:"/"✗ id:"/"⚠ id:" 行第二令牌，
# 剥结尾冒号后须为纯 id 字符集（过滤散文行/多级行号行），sort -u 去重。
_gate_ids() { # $1=捕获输出文件；stdout=空格分隔 id 清单
  awk '{ t=$2; if (t != "" && sub(/:$/, "", t) && t ~ /^[A-Za-z0-9_.-]+$/) print t }' "$1" \
    | sort -u | tr '\n' ' '
}

# 累加单门禁 SARIF result 片段（bash 3.2 无关联数组，按执行序串接）
_json_add_result() { # $1=gate $2=status $3=ids(空格分隔)
  local _ids_json="" _sep="" _id
  for _id in $3; do
    _ids_json="${_ids_json}${_sep}\"${_id}\""
    _sep=","
  done
  _JSON_RESULTS="${_JSON_RESULTS}${_JSON_SEP}{\"gate\":\"$1\",\"status\":\"$2\",\"ids\":[${_ids_json}]}"
  _JSON_SEP=","
}

# gate-runs.jsonl 追加一行（ts 为 UTC；对齐 GB/T 15532 过程文档与 standards-compliance.md §F 证据列）
_gate_evidence() { # $1=gate $2=status $3=ids(空格分隔) $4=duration_s
  local _ids_json="" _sep="" _id
  for _id in $3; do
    _ids_json="${_ids_json}${_sep}\"${_id}\""
    _sep=","
  done
  printf '{"ts":"%s","gate":"%s","status":"%s","ids":[%s],"duration_s":%s}\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" "$2" "$_ids_json" "$4" \
    >> "$GATE_RUNS_DIR/gate-runs.jsonl"
}

# SARIF 2.1.0 子集输出：version/runs/results（每门禁 {gate,status,ids[]}）
_emit_json() {
  local _out _sk_json="" _g
  # WP-F：skipped 数组披露未配置跳过的门禁（绿≠合规在 JSON 侧同样显式化）
  for _g in $SKIP_LIST; do _sk_json="${_sk_json}${_sk_json:+,}\"${_g}\""; done
  _out="{\"version\":\"2.1.0\",\"runs\":[{\"tool\":{\"driver\":{\"name\":\"swarm-yuan precheck.sh\",\"properties\":{\"skipped\":[${_sk_json}]}}},\"results\":[${_JSON_RESULTS}]}]}"
  _JSON_EMITTED=1
  if [[ -n "$GATE_JSON_OUT" ]]; then
    if ! printf '%s\n' "$_out" > "$GATE_JSON_OUT" 2>/dev/null; then
      echo "✗ GATE_JSON_OUT($GATE_JSON_OUT) 写入失败——改打印到 stdout" >&2
      printf '%s\n' "$_out"
    fi
  else
    printf '%s\n' "$_out"
  fi
}

# 门禁执行包装：$1=门禁函数名 $2=容错标志（1=--all 循环 `|| true` 语义；0=单门禁原样直通）
_gate_exec() {
  _CURRENT_GATE="$1"
  INVOKE_COUNT=$((INVOKE_COUNT+1))
  # WP-D1：门禁级 trace-log（设计理念 2：全链路追踪）——每门禁调用前/后向 stderr 输出追踪行 + 落盘 trace.jsonl
  if [[ -f "${TRACE_LOG_SH:-}" ]]; then
    bash "$TRACE_LOG_SH" --node "门禁" --tool "$1" --status started >&2 2>/dev/null || true
  fi
  local _trace_bf=$FAIL_COUNT _trace_bw=$WARN_COUNT
  # WP-Q1（决策 19）：门禁分层 enforce_level 分流——advisory 门禁永不 fail/warn 计数。
  # 在子 shell 内重定义 fail()/warn()/pass() 为纯 echo，advisory 门禁的 fail/warn 调用变成纯输出行，
  # 不进 FAIL_COUNT/WARN_COUNT/SKIP_COUNT——"advisory 是观测类门禁，不阻断交付"语义机器化。
  # strict/warn 门禁走原路径（fail/warn 正常计数），行为不变。
  local _enforce
  _enforce=$(_enforce_of "$1")
  if [[ "$_enforce" == "advisory" ]]; then
    # 非证据模式：子 shell 内重定义 fail/warn/pass，原样调用门禁
    if [[ "$_EVIDENCE_ON" -eq 0 ]]; then
      (
        fail() { echo "  ⚠ advisory: $1"; }   # advisory 不进 FAIL_COUNT
        warn() { echo "  ⚠ advisory: $1"; }   # advisory 不进 WARN_COUNT
        pass() { echo "  ✓ advisory: $1"; }
        if [[ "$2" == "1" ]]; then "$1" || true; else "$1"; fi
      )
      if [[ -f "${TRACE_LOG_SH:-}" ]]; then
        bash "$TRACE_LOG_SH" --node "门禁" --tool "$1" --status advisory >&2 2>/dev/null || true
      fi
      return 0
    fi
    # 证据模式：子 shell 内捕获输出（advisory 门禁状态恒为 advisory，不进 fail/warn/skip 计数）
    _t0=$(date +%s)
    (
      fail() { echo "  ⚠ advisory: $1"; }
      warn() { echo "  ⚠ advisory: $1"; }
      pass() { echo "  ✓ advisory: $1"; }
      if [[ "$2" == "1" ]]; then "$1" || true; else "$1"; fi
    ) > "$_GATE_TMP" 2>&1 || true
    _t1=$(date +%s)
    cat "$_GATE_TMP"
    _st="advisory"
    _ids=$(_gate_ids "$_GATE_TMP")
    _json_add_result "$1" "$_st" "$_ids"
    if [[ -n "$GATE_RUNS_DIR" ]]; then _gate_evidence "$1" "$_st" "$_ids" "$((_t1-_t0))" || true; fi
    if [[ -f "${TRACE_LOG_SH:-}" ]]; then
      bash "$TRACE_LOG_SH" --node "门禁" --tool "$1" --status advisory >&2 2>/dev/null || true
    fi
    # advisory 永不 fail（子shell 内重定义保证），容错标志 1 时直接返回 0
    [[ "$2" == "1" ]] && return 0
    return 0
  fi
  # strict/warn 门禁：走原分发路径（fail/warn 正常计数）
  # 非证据模式：与原分发语句逐语句等价（含 set -e 传播语义）
  if [[ "$_EVIDENCE_ON" -eq 0 ]]; then
    if [[ "$2" == "1" ]]; then "$1" || true; else "$1"; fi
    # 门禁级 trace-log done/fail/warn（按计数器增量判定）
    if [[ -f "${TRACE_LOG_SH:-}" ]]; then
      local _tst="done"
      [[ $FAIL_COUNT -gt $_trace_bf ]] && _tst="fail"
      [[ "$_tst" == "done" && $WARN_COUNT -gt $_trace_bw ]] && _tst="warn"
      bash "$TRACE_LOG_SH" --node "门禁" --tool "$1" --status "$_tst" >&2 2>/dev/null || true
    fi
    return
  fi
  # 证据模式：捕获输出→回放→按计数器增量判定状态→登记 json/jsonl
  local _bf=$FAIL_COUNT _bw=$WARN_COUNT _bs=$SKIP_COUNT _rc=0 _t0 _t1 _st _ids
  _t0=$(date +%s)
  if [[ "$2" == "1" ]]; then
    "$1" > "$_GATE_TMP" || true
  else
    "$1" > "$_GATE_TMP" || _rc=$?
  fi
  _t1=$(date +%s)
  cat "$_GATE_TMP"
  # 状态优先级 fail > skip > warn > pass（skip_if_unconfigured 非静默时同时计 warn，fail 最严）
  if [[ $FAIL_COUNT -gt $_bf ]]; then _st="fail"
  elif [[ $SKIP_COUNT -gt $_bs ]]; then _st="skip"
  elif [[ $WARN_COUNT -gt $_bw ]]; then _st="warn"
  else _st="pass"; fi
  _ids=$(_gate_ids "$_GATE_TMP")
  _json_add_result "$1" "$_st" "$_ids"
  if [[ -n "$GATE_RUNS_DIR" ]]; then _gate_evidence "$1" "$_st" "$_ids" "$((_t1-_t0))" || true; fi
  # WP-D1：门禁级 trace-log done/fail/skip/warn/pass（证据模式）
  if [[ -f "${TRACE_LOG_SH:-}" ]]; then
    bash "$TRACE_LOG_SH" --node "门禁" --tool "$1" --status "$_st" >&2 2>/dev/null || true
  fi
  if [[ "$2" == "1" ]]; then return 0; fi
  return "$_rc"
}

# ===== 运行时工具检测辅助 =====
# swarm-yuan 的门禁优先调用已安装的运行时工具（gitnexus/graphify/ocr/claude-mem/gsd-tools），
# 降级到内置 grep 检测。这样"有能力就用，无能力降级"——不浪费已安装工具的能力。

has_gitnexus() { command -v gitnexus >/dev/null 2>&1; }
has_graphify() { command -v graphify >/dev/null 2>&1; }
has_ocr() { command -v ocr >/dev/null 2>&1; }
has_claude_mem() { command -v claude-mem >/dev/null 2>&1 || [[ -d "$HOME/.claude-mem" ]]; }
# CLI 接线层运行时守卫（WP1：OpenSpec/comet/gsd-core 半接线→真接线）
has_openspec() { command -v openspec >/dev/null 2>&1; }
has_comet() { command -v comet >/dev/null 2>&1; }
has_gsd_tools() { command -v gsd-tools >/dev/null 2>&1; }
has_madge() { command -v madge >/dev/null 2>&1; }

# WP-D1：trace_tool 辅助函数（全链路追踪——设计理念 2）
# 在第三方工具调用前调用，打印"→ [工具] 调用 X · Y（started）"到 **stderr**（不污染 stdout/cli-ab 逐字节等价）
# + 落盘 trace.jsonl。trace-log.sh 路径优先 $_CONF_DIR/trace-log.sh，缺失则静默跳过（不阻塞）。
# 口径：只 trace 实际工作调用；has_*/indexed/built 等守卫探测（如 gitnexus status）不 trace，避免噪音。
# 分级（WP-C 减重）：本函数全部调用点均为第三方工具「调用级」细节——默认不落盘不输出，
# 仅 SWARM_YUAN_TRACE=verbose 时启用；门禁级（_gate_exec）节点追踪不受影响，始终落盘。
TRACE_LOG_SH="${_CONF_DIR:-$(cd "$(dirname "$0")" 2>/dev/null && pwd)}/trace-log.sh"
trace_tool() {  # $1=工具名 $2=命令/操作描述 [--note 说明]（第 3 参数可选作 note）
  [[ "${SWARM_YUAN_TRACE:-}" == "verbose" ]] || return 0
  local _tool="$1" _op="$2" _note="${3:-}"
  [[ -f "$TRACE_LOG_SH" ]] || return 0
  if [[ -n "$_note" ]]; then
    bash "$TRACE_LOG_SH" --node "门禁" --actor "工具" --tool "${_tool} ${_op}" --status started --note "$_note" >&2 2>/dev/null || true
  else
    bash "$TRACE_LOG_SH" --node "门禁" --actor "工具" --tool "${_tool} ${_op}" --status started >&2 2>/dev/null || true
  fi
}

# gitnexus 已索引当前仓库？（检查 .gitnexus/ 或 gitnexus status）
gitnexus_indexed() {
  [[ -d "$PROJECT_DIR/.gitnexus" ]] && return 0
  if has_gitnexus; then
    gitnexus status 2>/dev/null | grep -qiE "indexed|up to date" && return 0
  fi
  return 1
}

# graphify 已构建图谱？（检查 graphify-out/graph.json）
graphify_built() { [[ -f "$PROJECT_DIR/graphify-out/graph.json" ]]; }





# --sensitive 工具链降级辅助（P1-3）：gitleaks 路径。
# 返回：0=已处理（pass/fail 已记录）；1=gitleaks 执行失败（调用方降级内置）；2=SCAN_DIRS 空（交回内置披露路径）




# ===== DDD / 分层 / 拼装门禁（--layer / --stable-diff / --link-depth）=====
# 防范：层级穿透 / 依赖倒置 / 循环依赖 / 领域层污染框架 / 稳定单元被篡改 / 调用链膨胀





# 依赖版本提取（输出 name<TAB>version，跨平台 awk，兼容 5 类依赖文件）

# 去除版本前缀符号 ^ ~ > < = 及尾部约束，便于跨版本比较


# 安全扫描辅助：在指定目录中按 ERE 模式扫描，返回 文件:行号:内容

# --security 工具链降级辅助（P1-3）：semgrep 路径（--config auto --json，ERROR 级命中 → fail）。
# 返回：0=已处理（pass/fail 已记录）；1=semgrep 执行失败（调用方降级内置）；2=无可扫目录（交回内置披露路径）


# ===== TOGAF 架构契约门禁（--adr / --contract / --consistency-cross / --impact）=====
# 防范：架构决策无文档 / 接口无版本 / BDAT 命名不一致 / 数据所有权模糊 / 变更无影响分析 / 遗留无 ACL





# ===== 微服务架构门禁（--service / --api）=====
# 防范：共享数据库 / 同步调用链过长 / 共享模型库 / 无网关 / 无trace透传 / 契约无版本 / 无幂等 / 跨服务事务



# ===== 前端架构门禁（--state / --frontend）=====
# 防范：巨型store / prop drilling / 派生状态useState / 组件层级深 / 容器展示混合 / props过多 / 重复依赖 / 循环依赖 / 全局CSS污染



# ===== 认知递进门禁（--cognition）=====
# 理念：先有概念定义→结构→空间→三者映射→认知规律→处理关系
#       关系在时空中变化：速度/聚散/趋势/强度/能耗/累积量
# 本门禁不判违规（不 fail），而是呈现"认知体检报告"——六阶认知链完整性 + 六维动力学状态
# 让开发者看见关系的递进与演化方向，而非仅数量计数





# ===== 左移门禁（--shift-left：测试左移+变更左移+运维监控左移）=====

# ===== 标准合规门禁族（--compliance/--docs-pack/--sbom/--privacy）=====
# 语义全新，不改既有门禁判定；未配置静默跳过，安全类启用后 fail-closed。

# --compliance：标准合规矩阵校验（6 锚点存在性 + 全文占位符扫描 + spec §22 段）

# --docs-pack：交付文档包完备性（profile→必备清单，存在性 + TBD 扫描）

# --sbom：SBOM 生成与许可证块名单扫描（SBOM_REQUIRED=1 启用，启用后 fail-closed）

# --privacy：个人信息（PII）扫描（PRIVACY_SCAN_DIRS 配置启用，启用后 fail-closed）

# ===== 安全门禁族深化（P1-3/P1-9：--authz/--requirements/--crypto）=====
# 语义全新，不改既有门禁判定；未配置静默跳过，启用后按门禁姿态 fail-closed / 开关执法 / warn-only。

# --authz：授权类弱点检查（CWE-862 缺失授权 / CWE-863 不正确授权 / CWE-639 用户可控键值 / CWE-284 不当访问控制）
# 粗放词法检测，fail 项（3 个稳定 id）与 warn-only 项分清：
#   fail：控制器缺鉴权注解（missing_check）、IDOR 主键直取（idor）、CORS 全放行带凭据（permissive）
#   warn-only：permitAll() 全放行、AUTHZ_EXTRA_PATTERNS 自定义模式（可能为有意设计，须人工复核）

# --requirements：需求质量 lint（ISO/IEC/IEEE 29148：需求完备无待定项、唯一标识、EARS 句式）
# SPEC_FILE 存在才执行；STRICT/ID_REQUIRED 开关默认 0（不执法），EARS 覆盖率为 warn-only。

# --crypto：密码算法合规（GB/T 39786-2021 密评，profile=gm）
# CRYPTO_PROFILE 空 → 静默跳过；=gm 时在 CRYPTO_SCAN_DIRS 扫描弱算法 ERE
#（MD5/SHA1/DES/RSA-1024/ECDSA，滤注释行与 example/mock）→ fail；国密白名单 SM2/SM3/SM4。

# ===== 长期清单收口（P3）：--rtm / --release-sign =====
# 语义全新，不改既有门禁判定；未配置静默跳过，启用后 fail-closed。

# --rtm：需求追溯矩阵（ISO/IEC/IEEE 29148 RTM 落地：每条 REQ- 编号需求须可追溯）
# 追溯源二选一命中即算已追溯：① TEST_DIR_PATTERNS 测试目录内含该 REQ 引用；
# ② 追溯矩阵文件（RTM_MATRIX_FILE，缺省 docs/rtm.md）含该 REQ 引用。
# RTM_MATRIX_REQUIRED=1 时矩阵文件必须存在（fail-closed 锚点）；输出追溯率百分比。

# --release-sign：发布签名与 provenance 检查（SLSA Build L2 对齐 / NIST SSDF PS.2 发布完整性）
# 每个发布产物（RELEASE_ARTIFACTS_GLOB，缺省 dist/*.tar.gz dist/*.zip dist/*.jar）须有
# 伴随签名/证明（.sig/.asc/.att/.bundle 其一）；cosign 可用时走 verify-blob 验签
#（.bundle keyless 优先，其次 .sig；.asc/.att 非 cosign 可验，存在性兜底），验签失败即 fail；
# 无 cosign 时降级为存在性检查（输出注明降级）。RELEASE_PROVENANCE_REQUIRED=1 时
# 还要求 SLSA provenance 文件存在（fail-closed）。

# ===== 框架适配门禁（--framework）：由 --inject-frameworks 注入片段，动态分发 =====

# >>> swarm-yuan:framework-gates >>> （由 generate-skill.sh --inject-frameworks 维护，勿手改）
# <<< swarm-yuan:framework-gates <<<

# 将 *_FILE_GLOBS（含 ** 递归通配）解析为实际文件列表（兼容 bash 3.2 无 globstar）。
# 每个 glob 形如 "overlay/custom/client/**/*.vue" → find overlay/custom/client -name '*.vue'
# 输出：以空格分隔的文件路径串（供 unquoted 展开给 grep 作 path 参数）。
_fw_resolve_globs() {
  local g dir name
  for g in "$@"; do
    # 拆分为 ** 之前的目录前缀 与 末段文件名
    dir="${g%%/\*\*/*}"
    name="${g##*/}"
    # 若拆分后 dir == g 说明无 **，整体当作单个路径/文件
    if [[ "$dir" == "$g" ]]; then
      # WP-R P1-1: 无 ** 的 glob（如 src/store/modules/*.js）原仅 [[ -e ]] 判定，
      # 对含通配符的 glob 永远 false（字面路径 *.js 不存在）→ 门禁静默失效（假 warn）。
      # 修复：含通配符的用 shopt nullglob + compgen 展开；纯路径/文件用 [[ -e ]]
      if [[ "$g" == *['*?[]'* ]]; then
        # 含通配符：在当前目录(cwd=PROJECT_DIR)下用 compgen 展开
        local _expanded
        _expanded=$(compgen -G "$g" 2>/dev/null || true)
        [[ -n "$_expanded" ]] && printf '%s\n' "$_expanded"
      else
        [[ -e "$g" ]] && printf '%s\n' "$g"
      fi
    else
      [[ -d "$dir" ]] || continue
      find "$dir" -type f -name "$name" 2>/dev/null
    fi
  done
}

# grep 计数包装：规避 set -e + pipefail 在无匹配（grep exit 1）时整体退出。
_fw_grep_count() {
  # $1=pattern, $@=files...
  local pat="$1"; shift
  { grep -rlE "$pat" "$@" 2>/dev/null || true; } | wc -l | xargs
}

# ===== 框架门禁公共库（供 framework-gates 片段调用；勿改名，片段依赖）=====
# 以下注释剥离器与各片段原内联嵌套实现字节级同语义（同 sed/grep 表达式、
# 同 2>/dev/null 处理）；管道统一 || true 加固，不依赖 check_framework 的兜底。
# 家族聚类依据：57 片段嵌套函数体逐字节比对（见 verifier/v1/gate-ab-diff.sh 契约注释）。

# C 系（// 行内 + 块注释行；Java/Go/JS/TS 等 14 片段同体）：
# angular/elasticjob/kafka/lombok/mapstruct/netty/quartz/rabbitmq/react/redis/
# rocketmq/spring-batch/spring-boot/spring-cloud
_fw_strip_comments_c() {
  { sed -E 's://.*$::; /^[[:space:]]*\*/d; /^[[:space:]]*\/\*/d' "$1" 2>/dev/null || true; }
}

# C 系变体：多剥行内 /* */（gin/gorm 同体）
_fw_strip_comments_c_inline() {
  { sed -E 's://.*$::; s:/\*.*\*/::g; /^[[:space:]]*\*/d; /^[[:space:]]*\/\*/d' "$1" 2>/dev/null || true; }
}

# Python 系（# 行内；django/fastapi/flask/sqlalchemy 同体）
_fw_strip_comments_hash() {
  { sed -E 's:#.*$::' "$1" 2>/dev/null || true; }
}

# 配置系（剔 # 注释行；elasticjob/quartz/redis 的 *_cfg_only 同体）
_fw_strip_comments_cfg() {
  { grep -vE '^[[:space:]]*#' "$1" 2>/dev/null || true; }
}

# SQL 系（-- 行内；postgresql/sqlserver 同体）
_fw_strip_comments_sql() {
  { sed -E 's:--.*$::' "$1" 2>/dev/null || true; }
}

# MySQL 系（-- 行内 + # 注释行；mysql 独有）
_fw_strip_comments_mysql() {
  { sed -E 's:--.*$::; /^[[:space:]]*#/d' "$1" 2>/dev/null || true; }
}

# JS 行首系（仅剥行首 // 与块注释行，保留行内 // 防误伤 URL；nextjs/nuxt 同语义）
_fw_strip_comments_js_head() {
  { sed -E 's:^[[:space:]]*//.*$::; /^[[:space:]]*\*/d; /^[[:space:]]*\/\*/d' "$1" 2>/dev/null || true; }
}

# XML 系（awk 状态机剥 <!-- --> 跨行注释；mapstruct 独有）
_fw_strip_comments_xml() {
  { awk '
      {
        rest=$0; out=""
        while (length(rest)) {
          if (inc) {
            i=index(rest,"-->")
            if (!i) { rest=""; break }
            rest=substr(rest,i+3); inc=0
          } else {
            i=index(rest,"<!--")
            if (!i) { out=out rest; break }
            out=out substr(rest,1,i-1); rest=substr(rest,i+4); inc=1
          }
        }
        print out
      }' "$1" 2>/dev/null || true; }
}

# 规范形报告尾收编：bad 非空 → fail|warn "id: msg:\n<bad>"；空 → pass "id: ok"。
# 与手写 if/else/fi 输出逐字节等价（含换行结构）。
# 用法: _fw_report <fail|warn> <gate_id> <bad内容> <bad文案(不含结尾冒号)> <ok文案>
_fw_report() {
  if [[ -n "$3" ]]; then
    "$1" "$2: $4:
$3"
  else
    pass "$2: $5"
  fi
}

# ===== shellcheck 静态锚点（运行时恒假，零副作用）=====
# 门禁经数组循环动态分发（"$_gate" / "$_gate_fn"），静态分析无法追踪间接调用，
# 会使全部门禁函数体被误报不可达（SC2317 级联）。此处静态引用全部门禁函数，
# 使调用图对 shellcheck 可达；条件中 _gate_fn 在此处恒未赋值，分支体永不执行。
if [[ -z "${_gate_fn:-x}" ]]; then
  check_branch; check_scope; check_build; check_test; check_sensitive; check_consistency
  check_review; check_reuse; check_deps; check_security; check_layer; check_stable_diff
  check_link_depth; check_adr; check_contract; check_consistency_cross; check_impact
  check_service; check_api; check_state; check_frontend; check_cognition; check_domain
  check_knowledge; check_mermaid; check_shift_left; check_framework
  check_compliance; check_docs_pack; check_sbom; check_privacy
  check_authz; check_requirements; check_crypto; check_rtm; check_dengbao; check_pia; check_sast_deep; check_oss_eval; check_quality_model; check_test_evidence; check_review_record; check_metrics; check_release_sign
fi

case "$MODE" in
  --all)
    # 容错标志 1（原 `|| true`）：单门禁 fail 路径若以非零返回（如 check_scope/sensitive/review 末句 `[[ ]] && pass`），
    # 不得因 set -e 中断后续门禁——FAIL 全局已记录失败，最终由末尾汇总判定。
    for _gate in "${ALL_GATES_CORE[@]}"; do _gate_exec "$_gate" 1; done
    ;;
  --all-full)
    # 标准门禁 27（核心 10 + 架构 17）；合规 13 拆出为 --compliance-suite 按需执行
    for _gate in "${ALL_GATES_STANDARD[@]}"; do _gate_exec "$_gate" 1; done
    ;;
  --compliance-suite)
    # 合规 13 门禁独立套件（强监管交付场景按需执行；未配置的静默跳过）
    for _gate in "${ALL_GATES_COMPLIANCE[@]}"; do _gate_exec "$_gate" 1; done
    ;;
  --fix-suggest)
    # WP-B3：跑全量门禁收集 fail，只输出修复建议不 exit 1（rc=0）。供 AI/用户 fail 后单独看建议。
    for _gate in "${ALL_GATES_FULL[@]}"; do _gate_exec "$_gate" 1; done
    echo ""
    echo "—— 修复建议（--fix-suggest 模式：只输出建议，不阻塞，rc=0）——"
    if [[ -z "$FAIL_IDS" ]]; then
      echo "  ✓ 无 fail，无需修复建议"
    else
      _fs_id=""
      while IFS= read -r _fs_id || [[ -n "$_fs_id" ]]; do
        [[ -z "$_fs_id" ]] && continue
        _fix_suggest "$_fs_id"
      done <<< "$FAIL_IDS"
    fi
    exit 0
    ;;
  --*)
    # 单门禁分发：精确匹配 GATE_FLAGS 后按映射规则得函数名（如 --stable-diff → check_stable_diff）
    _gate_fn=""
    for _gate_flag in "${GATE_FLAGS[@]}"; do
      if [[ "$MODE" == "$_gate_flag" ]]; then
        _gate_fn="check_$(printf '%s' "${MODE#--}" | tr '-' '_')"
        break
      fi
    done
    if [[ -n "$_gate_fn" ]]; then
      _gate_exec "$_gate_fn" 0
    else
      _usage
      exit 1
    fi
    ;;
  *)
    _usage
    exit 1
    ;;
esac

echo ""
# 执行汇总披露（非破坏：仅追加本行，不改既有输出行与退出码判定）
echo "—— 执行汇总：调用 ${INVOKE_COUNT}，执行 $((INVOKE_COUNT-SKIP_COUNT))，跳过 ${SKIP_COUNT}（${SKIP_LIST# }），fail ${FAIL_COUNT}，warn ${WARN_COUNT} ——"
# WP-F 诚实化收口：跳过单列披露——「通过」≠ 全量覆盖（绿≠合规洞显式化）
if [[ $SKIP_COUNT -gt 0 ]]; then
  echo "—— 注意：${SKIP_COUNT} 个门禁未配置跳过（${SKIP_LIST# }），「通过」≠ 全量覆盖——"
fi
# WP-B1：fail 修复建议映射表（常见 fail id → 建议文案）。未映射的输出通用建议。
# 设计理念 1（连贯动作）：门禁 fail 后脚本自动给出修复建议，而非只 exit 1 让用户/AI 猜。
_fix_suggest() {
  local id="$1" suggest=""
  case "$id" in
    gate_requirements_tbd*)         suggest="删除 spec 中的 TBD/待定/待明确项，或显式标注暂缓理由（29148 要求需求集完备）";;
    gate_requirements_no_id*)       suggest="为每条需求条目补 REQ- 唯一编号（29148 要求可唯一标识）";;
    gate_requirements_openspec*)    suggest="修正 openspec delta spec 合法性（缺 scenario WHEN-THEN / markdown 结构错）——运行 openspec validate <spec> --strict 查详情";;
    gate_sbom_license_blocked*)     suggest="更换被禁许可证依赖，或把该依赖加入 precheck.conf 的 LICENSE_WHITELIST";;
    gate_privacy_pii_found*)        suggest="扫描出的 PII 须脱敏/加密存储，或加入 PRIVACY_WHITELIST（确认非 PII 的误报）";;
    gate_release_sign_missing*)     suggest="发布前用 cosign/gpg 对产物签名，并生成 provenance.json（SLSA L2）";;
    gate_release_provenance_missing*) suggest="补 provenance.json（SLSA Build L2 provenance，含 buildType/materials/byproducts）";;
    gate_docs_pack_missing*)        suggest="补齐交付文档包缺失项（按 DOCS_PACK_PROFILE=gbt8567/rusp 校验）";;
    gate_docs_pack_tbd*)            suggest="交付文档中不得残留 TBD/待定，补全内容或移除占位";;
    gate_compliance_anchor_incomplete*) suggest="补全 standards-compliance.md 的 6 锚点矩阵（A-F），缺哪个补哪个";;
    gate_compliance_placeholder*)   suggest="standards-compliance.md 不得残留占位符，填实际值";;
    gate_authz_*)                   suggest="服务端 API 须默认拒绝+显式授权（OWASP ASVS V8），补 @PreAuthorize/@RequiresPermissions 等授权注解";;
    gate_crypto_*)                  suggest="替换弱密码算法（MD5/SHA1/DES/RSA-1024）为国密 SM2/SM3/SM4 或强算法（GB/T 39786）";;
    gate_dengbao_*)                suggest="等保控制点缺口（GB/T 22239-2019）——补双因子/审计日志/审计字段声明，或在 DENGBAO_EXEMPT_FILE 四字段登记豁免";;
    gate_pia_*)                    suggest="补 PIA 评估文档与个人信息处理活动清单（个保法第55-56条/GB/T 35273），消除文档待定项";;
    gate_sast_deep_*)              suggest="深度 SAST 检出漏洞（GB/T 34943/44/46）——修复代码执行/注入 sink，或升级 SAST_DEEP_SEVERITY 阈值语义";;
    gate_oss_eval_*)               suggest="开源代码评价缺口（GB/T 43848-2024）——先跑 --sbom 生成成分清单，清理块名单许可证或登记五字段豁免";;
    gate_quality_model_*)          suggest="补质量特性剪裁表（GB/T 25000.10 八特性逐项适用/剪裁+理由，ISO 25010 Safety 主动对齐），消除待定项";;
    gate_test_evidence_*)          suggest="补测试计划/说明/报告三类文档（GB/T 15532/9386），测试报告含准出结论，消除待定项";;
    gate_review_record_*)        suggest="补评审记录（评审人/日期/结论三要素，GB/T 8566），AI 生成产物声明+人工复核（ISO 42001），消除待定项";;
    gate_metrics_*)               suggest="strict 门禁通过率趋势恶化（GB/T 25000.30）——排查根因，检查近期变更是否引入质量退化";;
    fw_vue_script_setup*)           suggest="将 Vue SFC 改为 <script setup> 语法（项目特征卡要求）";;
    fw_vue_no_options_api*)         suggest="移除 Options API（data/methods/computed），改用 Composition API";;
    fw_vue_vhtml_sanitize*)         suggest="v-html 须配套 sanitize（DOMPurify 等），防 XSS";;
    fw_mybatis_dollar*)             suggest="MyBatis mapper 把 ${} 改为 #{}（防 SQL 注入），或在 SQL_INJECTION_WHITELIST 登记确认安全的动态列名";;
    fw_sboot_transactional_selfinvoke*) suggest="@Transactional 方法不得同类自调用（代理失效），拆到另一个 Bean 或用 AopContext.currentProxy()";;
    fw_lombok_data_jpa*)            suggest="@Data + @Entity 冲突（equals/hashCode 破坏 JPA），改用 @Getter @Setter 或单独实现 equals/hashCode";;
    fw_batch_step_scope*)           suggest="Spring Batch ItemReader/Processor/Writer 须加 @StepScope（late binding 失效）";;
    fw_sharding_key_in_dml*)        suggest="分表 DML 须含分片键（sharding-key），否则全表扫描";;
    gate_scope_*)                   suggest="修改超出了 WRITABLE_DIRS 范围，把改动收回到可写目录或在 conf 登记只读区修改机制";;
    gate_sensitive_*)               suggest="扫描出敏感信息（密钥/凭证/IP），移除或改用环境变量/密钥管理服务";;
    gate_layer_*|gate_stable_diff_*|gate_link_depth_*) suggest="分层/稳定单元/调用链门禁——查看上方具体 fail 行，按 DDD 层边界调整依赖方向";;
    gate_test_*)                    suggest="测试未通过——运行 TEST_CMD 查看失败用例，修复测试或被测代码";;
    gate_build_*)                   suggest="构建失败——运行 BUILD_CMD 查看编译错误，修复语法/依赖/配置";;
    *)                              suggest="运行 precheck.sh <对应门禁> --doctor 查看详情，或参考 references/ 对应方法论文档";;
  esac
  echo "  • ${id}: ${suggest}"
  # G1：决策留痕提示（不改变 fail 语义，只增强诊断输出）
  echo "    （决策留痕：若涉及多方案/依赖升级/安全冲突，须按 references/decision-governance.md §User Challenge 记录到 decisions.jsonl）"
}

# WP-S1 跳过透明化（R1-G5）：SILENT 模式被抑制的未配置跳过在汇总段显式披露——绿≠合规
if [[ $SKIP_COUNT -gt 0 ]]; then
  echo "⊘ 跳过 ${SKIP_COUNT} 个门禁（未配置；逐门禁详情见 --doctor 或单跑该门禁）："
  for _sk in $SKIP_LIST; do echo "    - ${_sk#check_}"; done
fi

if [[ $FAIL -eq 0 ]]; then
  echo "✓ 门禁检查通过"
  _final_rc=0
else
  echo "✗ 门禁检查未通过，请修复上述问题"
  # WP-B1：fail 修复建议（设计理念 1：连贯动作——fail 后自动给修复建议，非让用户猜）
  if [[ -n "$FAIL_IDS" ]]; then
    echo "—— 修复建议（${FAIL_COUNT} 项 fail，按 id 去重后 $(printf '%s\n' "$FAIL_IDS" | grep -c .) 项）——"
    local_id=""
    while IFS= read -r local_id || [[ -n "$local_id" ]]; do
      [[ -z "$local_id" ]] && continue
      _fix_suggest "$local_id"
    done <<< "$FAIL_IDS"
    echo "—— 修复建议结束（执行修复仍需 AI/用户确认，与「用户决策」原则一致）——"
  fi
  _final_rc=1
fi
# P1-5：json 模式在运行结束输出 SARIF 子集（text 默认模式无此行，输出与改造前逐字节一致）
if [[ "$FORMAT" == "json" ]]; then _emit_json; fi
exit "$_final_rc"
