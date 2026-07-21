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
SIGNALS

# 扫描依赖文件，收集所有依赖字符串
_all_deps=""
# package.json
if [[ -f "$PROJ/package.json" ]]; then
  # 提取 dependencies + devDependencies 的 key
  _deps=$(grep -E '^\s+"[^"]+":\s' "$PROJ/package.json" 2>/dev/null | sed -E 's/^\s+"([^"]+)":.*/\1/' || true)
  _all_deps="${_all_deps}
$(printf '%s\n' "$_deps")"
fi
# pom.xml
if [[ -f "$PROJ/pom.xml" ]]; then
  _deps=$(grep -oE '<artifactId>[^<]+</artifactId>' "$PROJ/pom.xml" 2>/dev/null | sed 's/<\/\?artifactId>//g' || true)
  _all_deps="${_all_deps}
$(printf '%s\n' "$_deps")"
fi
# go.mod
if [[ -f "$PROJ/go.mod" ]]; then
  _deps=$(grep -E '^\s*[a-z]' "$PROJ/go.mod" 2>/dev/null | awk '{print $1}' || true)
  _all_deps="${_all_deps}
$(printf '%s\n' "$_deps")"
fi
# requirements.txt
if [[ -f "$PROJ/requirements.txt" ]]; then
  _deps=$(grep -vE '^\s*#|^\s*$' "$PROJ/requirements.txt" 2>/dev/null | sed -E 's/[=<>~!].*//; s/\[.*//; s/\s//g' || true)
  _all_deps="${_all_deps}
$(printf '%s\n' "$_deps")"
fi
# pyproject.toml
if [[ -f "$PROJ/pyproject.toml" ]]; then
  _deps=$(grep -E '^\s*[a-zA-Z]' "$PROJ/pyproject.toml" 2>/dev/null | sed -E 's/[=<>~!].*//; s/\[.*//; s/"//g; s/\s//g' || true)
  _all_deps="${_all_deps}
$(printf '%s\n' "$_deps")"
fi

# 匹配信号表，输出命中的框架 ID
_detected=""
while IFS='|' read -r fw pattern ftype; do
  [[ "$fw" =~ ^# ]] && continue
  [[ -z "$fw" || -z "$pattern" ]] && continue
  # 在 _all_deps 里找 pattern
  if printf '%s\n' "$_all_deps" | grep -qF "$pattern"; then
    # 去重添加
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
