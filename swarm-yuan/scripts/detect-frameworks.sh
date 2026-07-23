#!/usr/bin/env bash
# detect-frameworks.sh —— 扫描项目依赖文件，识别 ACTIVE_FRAMEWORKS
# 用途：替代 AI 手工探查 §C+.0.5（exploration-guide.md），机器判定框架列表
#
# 扫描文件：package.json / pom.xml / go.mod / pyproject.toml / requirements.txt
# 匹配源：references/frameworks-index.md（由 gen-framework-index.sh 生成的信号表）
# 输出：ACTIVE_FRAMEWORKS=("spring-boot" "mybatis" ...) 可直接写入 precheck.arch.conf
#
# 兼容 bash 3.2（不用 declare -A）
set -u

BASE="$(cd "$(dirname "${0}")/.." && pwd)"
PROJ="${1:-.}"

if [[ ! -d "$PROJ" ]]; then
  echo "✗ 项目目录不存在: $PROJ" >&2
  exit 1
fi

# 61 个已知框架 ID（来自 assets/framework-gates/*.sh 文件名）
KNOWN_FWS=""
for f in "$BASE"/assets/framework-gates/*.sh; do
  [[ -f "$f" ]] || continue
  KNOWN_FWS="${KNOWN_FWS} $(basename "$f" .sh)"
done

# 框架信号表（从 framework-gates 头部 # gates: 行提取依赖信号）
# 格式：framework_id|package_pattern
# 用 framework-gates 头部的 # ruleset: 行 + 文件名匹配
_tmpfile="$(mktemp /tmp/dfw.XXXXXX)"

# 简化的框架→依赖信号映射（覆盖 61 框架的主要识别模式）
# 按依赖文件类型组织
cat > "$_tmpfile" <<'SIGNALS'
# format: framework_id|pattern|file_type
# file_type: pkgjson(pacakge.json deps) / pom(pom.xml artifactId) / gomod(go.mod require) / pyreq(requirements.txt) / pyproject(pyproject.toml)
spring-boot|org.springframework.boot|pom
spring-cloud|org.springframework.cloud|pom
spring-data-jpa|org.springframework.data|pom
spring-security|org.springframework.security|pom
spring-batch|org.springframework.batch|pom
mybatis|org.mybatis|pom
mybatis|mybatis|pyreq
mybatis|mybatis|pyproject
dubbo|org.apache.dubbo|pom
nacos|com.alibaba.nacos|pom
nacos|nacos-sdk-python|pyreq
rocketmq|org.apache.rocketmq|pom
seata|io.seata|pom
sentinel|com.alibaba.csp|pom
sentinel|sentinel|pyreq
sharding|org.apache.shardingsphere|pom
elasticsearch|org.elasticsearch|pom
elasticsearch|elasticsearch-java|pom
elasticsearch|elasticsearch|pyreq
netty|io.netty|pom
jackson|com.fasterxml.jackson|pom
lombok|org.projectlombok|pom
mapstruct|org.mapstruct|pom
xxl-job|com.xuxueli|pom
elasticjob|org.apache.shardingsphere.elasticjob|pom
quartz|org.quartz-scheduler|pom
antd|antd|pkgjson
antd|@ant-design|pkgjson
vue|vue|pkgjson
vue|pinia|pkgjson
react|react|pkgjson
angular|@angular/core|pkgjson
element|element-plus|pkgjson
naiveui|naive-ui|pkgjson
nextjs|next|pkgjson
nuxt|nuxt|pkgjson
vite|vite|pkgjson
webpack|webpack|pkgjson
tailwind|tailwindcss|pkgjson
koa|koa|pkgjson
express|express|pkgjson
fastify|fastify|pkgjson
nestjs|@nestjs|pkgjson
django|Django|pyreq
django|django|pyproject
fastapi|fastapi|pyreq
fastapi|fastapi|pyproject
flask|Flask|pyreq
flask|flask|pyproject
sqlalchemy|SQLAlchemy|pyreq
sqlalchemy|sqlalchemy|pyproject
pytest|pytest|pyreq
pytest|pytest|pyproject
langchain|langchain|pyreq
langchain|langchain|pyproject
kratos|github.com/go-kratos|gomod
gin|github.com/gin-gonic|gomod
gorm|gorm.io/gorm|gomod
gorm|github.com/jinzhu/gorm|gomod
prisma|@prisma/client|pkgjson
prisma|prisma|pkgjson
typeorm|typeorm|pkgjson
validation|express-validator|pkgjson
validation|class-validator|pkgjson
jest-vitest|jest|pkgjson
jest-vitest|vitest|pkgjson
junit5-mockito|org.junit.jupiter|pom
junit5-mockito|org.mockito|pom
mysql|mysql-connector|pom
mysql|mysql|pyreq
postgresql|postgresql|pom
postgresql|psycopg2|pyreq
sqlserver|com.microsoft.sqlserver|pom
dameng|com.dameng|pom
dameng|dm-python|pyreq
redis|redis|pom
redis|redis|pyreq
redis|ioredis|pkgjson
kafka|org.apache.kafka|pom
kafka|kafka-python|pyreq
kafka|kafkajs|pkgjson
rabbitmq|com.rabbitmq|pom
rabbitmq|pika|pyreq
rabbitmq|amqplib|pkgjson
paimon|org.apache.paimon|pom
kettle|pentaho|pom
terraform|hashicorp/terraform|gomod
# WP-R Bug#3/A4: 补全缺失信号
celery|celery|pyreq
celery|celery|pyproject
flink|org.apache.flink|pom
flink|flink-python|pyreq
flink|apache-flink|pyproject
# druid（WP-R A4 新增，双信号 groupId+artifactId 兜底）
druid|com.alibaba.druid|pom
druid|druid-spring-boot-starter|pom
# WP-U：opentelemetry（可观测性）——三语言生态信号
opentelemetry|@opentelemetry/api|pkgjson
opentelemetry|opentelemetry-sdk|pyproject
opentelemetry|opentelemetry|pyreq
opentelemetry|go.opentelemetry.io/otel|gomod
opentelemetry|io.opentelemetry|pom
# WP-U：cargo（Rust 生态）——detect-frameworks.sh 不支持 file 类型探测
# （Cargo.toml 文件存在即激活，非依赖字符串匹配）。须手动配置 ACTIVE_FRAMEWORKS=("cargo")
SIGNALS

# WP-R Bug#3: 重构依赖收集——分桶(file_type) + pom 同时提取 groupId+artifactId +
# 递归扫描子模块 pom/package.json + pkgjson 短词单词边界。消除三个子根因:
#   ① pom 信号用 groupId 但只提取 artifactId → 27个 groupId 信号失效
#   ② file_type 字段被忽略 → 跨语言误匹配(pyreq 信号命中 Java pom)
#   ③ 不递归子模块 → Maven 多模块项目根 pom 无依赖全漏
# 兼容 bash 3.2(不用 declare -A,用分桶变量)
_pom_deps=""
_pkgjson_deps=""
_gomod_deps=""
_pyreq_deps=""
_pyproject_deps=""

# --- package.json: 递归扫描(前端 monorepo),排除 node_modules ---
# 提取 dependencies + devDependencies 的 key(pkg 名)
# WP-R Bug#3: \s 在 BSD sed(macOS)不识别,改 [[:space:]];提取后 trim 前导空白(边界匹配依赖纯净 key)
while IFS= read -r _pj; do
  _deps=$(grep -E '^[[:space:]]+"[^"]+":[[:space:]]' "$_pj" 2>/dev/null | sed -E 's/^[[:space:]]+"([^"]+)":.*/\1/' || true)
  _pkgjson_deps="${_pkgjson_deps}
${_deps}"
done < <(find "$PROJ" -name package.json -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null || true)

# --- pom.xml: 递归扫描子模块(排除 target),同时提取 groupId 和 artifactId ---
# 关键: pom 信号 pattern 多为 groupId(org.apache.dubbo),须提取 <groupId> 才能命中
while IFS= read -r _pom; do
  # 提取 artifactId
  # WP-R Bug#3: BSD sed(macOS)BRE 模式不支持 \?,须用 -E(ERE);否则标签不剥离,groupId 信号匹配失效
  _a=$(grep -oE '<artifactId>[^<]+</artifactId>' "$_pom" 2>/dev/null | sed -E 's/<\/?artifactId>//g' || true)
  # 提取 groupId(WP-R Bug#3 ①: 原 logic 只取 artifactId,27个 groupId 信号全失效)
  _g=$(grep -oE '<groupId>[^<]+</groupId>' "$_pom" 2>/dev/null | sed -E 's/<\/?groupId>//g' || true)
  _pom_deps="${_pom_deps}
${_a}
${_g}"
done < <(find "$PROJ" -name pom.xml -not -path '*/target/*' -not -path '*/.git/*' 2>/dev/null || true)

# --- go.mod: 只读根(Go 项目通常单 go.mod;多模块各自 go.mod 也递归) ---
while IFS= read -r _gm; do
  _deps=$(grep -E '^\s*[a-z]' "$_gm" 2>/dev/null | awk '{print $1}' || true)
  _gomod_deps="${_gomod_deps}
${_deps}"
done < <(find "$PROJ" -name go.mod -not -path '*/.git/*' 2>/dev/null || true)

# --- requirements.txt: 递归(Python 多环境/子项目) ---
while IFS= read -r _rq; do
  _deps=$(grep -vE '^\s*#|^\s*$' "$_rq" 2>/dev/null | sed -E 's/[=<>~!].*//; s/\[.*//; s/\s//g' || true)
  _pyreq_deps="${_pyreq_deps}
${_deps}"
done < <(find "$PROJ" -name requirements.txt -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null || true)

# --- pyproject.toml: 递归 ---
while IFS= read -r _pp; do
  _deps=$(grep -E '^\s*[a-zA-Z]' "$_pp" 2>/dev/null | sed -E 's/[=<>~!].*//; s/\[.*//; s/"//g; s/\s//g' || true)
  _pyproject_deps="${_pyproject_deps}
${_deps}"
done < <(find "$PROJ" -name pyproject.toml -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null || true)

# 匹配信号表,输出命中的框架 ID
# WP-R Bug#3 ②: 强制使用 file_type 分桶匹配,消除跨语言误匹配
# WP-R Bug#3 ③: pkgjson 短词加单词边界,消除 next→i18next 子串误报
_detected=""
while IFS='|' read -r fw pattern ftype; do
  [[ "$fw" =~ ^# ]] && continue
  [[ -z "$fw" || -z "$pattern" ]] && continue
  # 按 ftype 选对应桶
  case "$ftype" in
    pom)       _bucket="$_pom_deps" ;;
    pkgjson)   _bucket="$_pkgjson_deps" ;;
    gomod)     _bucket="$_gomod_deps" ;;
    pyreq)     _bucket="$_pyreq_deps" ;;
    pyproject) _bucket="$_pyproject_deps" ;;
    *)         continue ;;
  esac
  _hit=0
  if [[ "$ftype" == "pkgjson" ]]; then
    # pkgjson: 单词边界匹配,消除子串误报(next→i18next / vue→vuepress 等)
    # 边界: 行首 或 / 或 @ 之后,且 pattern 后跟 行尾 或 - / @ . _
    # pattern 可能含正则元字符(如 @ant-design 的 @),用 grep -E 需转义;这里 pattern
    # 多为简单标识符,对含特殊字符的用 grep -qF 兜底(无边界但精确)
    if [[ "$pattern" == *@* || "$pattern" == *.* ]]; then
      # scoped 包(@xxx/yyy)或含点的,固定字符串精确匹配(自带边界)
      printf '%s\n' "$_bucket" | grep -qxF "$pattern" && _hit=1
    else
      # 普通包名,加单词边界: (^|/|@)pattern($|-|/|@|.|_)
      printf '%s\n' "$_bucket" | grep -qE "(^|/|@)${pattern}(\$|-|/|@|\.|_)" && _hit=1
    fi
  else
    # pom/gomod/pyreq/pyproject: groupId/artifactId/模块名,固定字符串包含匹配
    # (groupId 如 org.apache.dubbo 是完整前缀,包含匹配即可;artifactId 短名同理)
    printf '%s\n' "$_bucket" | grep -qF "$pattern" && _hit=1
  fi
  if [[ "$_hit" -eq 1 ]]; then
    case " $_detected " in
      *" $fw "*) ;;
      *) _detected="${_detected}${_detected:+ }$fw" ;;
    esac
  fi
done < "$_tmpfile"

rm -f "$_tmpfile"

# 输出 ACTIVE_FRAMEWORKS 格式（可直接写入 precheck.arch.conf）
if [[ -n "$_detected" ]]; then
  # bash 数组格式
  echo "# 由 scripts/detect-frameworks.sh 自动探测（$(date +%Y-%m-%d)）"
  # 转成数组元素（带引号）
  _arr=""
  _cnt=0
  for fw in $_detected; do
    _arr="${_arr}${_arr:+ }\"$fw\""
    _cnt=$((_cnt+1))
  done
  echo "ACTIVE_FRAMEWORKS=($_arr)"
  echo "" >&2
  echo "探测到 ${_cnt} 个框架: $_detected" >&2
else
  echo "# 未探测到任何已知框架（scripts/detect-frameworks.sh $(date +%Y-%m-%d)）"
  echo "ACTIVE_FRAMEWORKS=()"
  echo "" >&2
  echo "未探测到已知框架（项目可能用自定义/冷门框架，需 AI 手工探查 §C+.0.5）" >&2
fi
