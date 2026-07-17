#!/usr/bin/env bash
# run-e2e.sh — P1 端到端验证：四框架注入 + 门禁 fail 全链路
# 用法: bash tests/e2e/run-e2e.sh
set -u
BASE="$(cd "$(dirname "$0")/.." && pwd)"
DEMO="${BASE}/e2e/java-demo"
PARADIGM="$(cd "${BASE}/.." && pwd)"  # swarm-yuan 范式根（含 scripts/generate-skill.sh）
FIX_DIR="$(mktemp -d /tmp/fwe2e.XXXXXX)"
trap 'rm -rf "${FIX_DIR}"' EXIT

echo "▶ E2E: 四框架注入 + 门禁 fail 全链路验证"

# 1. 构造目标 skill 骨架（precheck.sh + conf）
mkdir -p "${FIX_DIR}/scripts"
cp "${PARADIGM}/assets/precheck.sh" "${FIX_DIR}/scripts/precheck.sh"
cat > "${FIX_DIR}/scripts/precheck.conf" <<'EOF'
PROJECT_DIR="__DEMO__"
ACTIVE_FRAMEWORKS=("mybatis" "lombok" "spring-batch" "sharding")
MYBATIS_MAPPER_DIRS=("__DEMO__/src/main/resources/mapper")
MYBATIS_SRC_GLOBS=("__DEMO__/src/main/java/**/*.java")
SQL_INJECTION_WHITELIST=("ORDER BY ${orderBy}")
LOMBOK_SRC_GLOBS=("__DEMO__/src/main/java/**/*.java")
SPRING_BATCH_JOB_DIRS=("__DEMO__/src/main/java/**/*.java")
SHARDED_TABLES=("t_order")
SHARDING_KEY_COLUMNS=("t_order=user_id")
SHARDING_BROADCAST_TABLES=("t_dict")
EOF
# 替换 __DEMO__ 为实际路径（heredoc 用单引号防 ${} 展开）
sed -i.bak "s|__DEMO__|${DEMO}|g" "${FIX_DIR}/scripts/precheck.conf" && rm -f "${FIX_DIR}/scripts/precheck.conf.bak"

# 2. 注入门禁片段
echo "== Step 1: --inject-frameworks 注入四框架 =="
bash "${PARADIGM}/scripts/generate-skill.sh" --inject-frameworks "${FIX_DIR}" 2>&1 | tail -3

# 断言1: 4 个 _fw_*_check 已注入
for fn in _fw_mybatis_check _fw_lombok_check _fw_spring_batch_check _fw_sharding_check; do
  grep -q "^${fn}()" "${FIX_DIR}/scripts/precheck.sh" && echo "✓ ${fn} 已注入" || { echo "✗ ${fn} 未注入"; exit 1; }
done

# 3. 跑 --framework，断言 exit≠0 且输出含四个 fail id
echo "== Step 2: --framework 实跑，断言四个 fail id =="
out="$(cd "${DEMO}" && bash "${FIX_DIR}/scripts/precheck.sh" --framework 2>&1 || true)"
rc=0
(cd "${DEMO}" && bash "${FIX_DIR}/scripts/precheck.sh" --framework >/dev/null 2>&1) || rc=1
[[ "$rc" -eq 1 ]] && echo "✓ --framework exit≠0（有 fail）" || { echo "✗ --framework exit=0（应有 fail）"; echo "$out" | tail -20; exit 1; }

for gid in fw_mybatis_dollar fw_lombok_data_jpa fw_batch_step_scope fw_sharding_key_in_dml; do
  echo "$out" | grep -q "$gid" && echo "✓ 输出含 fail id: $gid" || { echo "✗ 输出缺 fail id: $gid"; echo "$out" | grep -E '✗|✓' | head -15; exit 1; }
done

echo "E2E OK：四框架注入与门禁 fail 全链路验证通过"
