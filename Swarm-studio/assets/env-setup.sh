#!/usr/bin/env bash
# env-setup.sh — ncwk overlay 环境加载与资源检测脚本
# 对应材料 assets §1 加载开发环境 + §2 检测资源连接、工具权限
# 用法: bash env-setup.sh
# ncwk 特点：embedded SQLite，无外部 DB/Redis/MQ/ELK；Node>=23, Python>=3.11<3.14

set -uo pipefail

FAIL=0
pass() { echo "  ✓ $1"; }
warn() { echo "  ⚠ $1"; }
fail() { echo "  ✗ $1"; FAIL=1; }

PROJECT_DIR="${PROJECT_DIR:-/Volumes/nvme2230/lab/ncwk/overlay}"

echo "=== 开发环境检测 ==="

# 版本比较：返回 0 若 installed >= required
ver_ge() {
  # 用 sort -V 比较；printf 去除前导 v
  local installed="$1" required="$2"
  local inst_clean req_clean
  inst_clean=$(printf '%s' "$installed" | sed 's/^v//')
  req_clean=$(printf '%s' "$required" | sed 's/^v//')
  [[ "$inst_clean" == "$(printf '%s\n%s' "$inst_clean" "$req_clean" | sort -V | head -1)" ]]
}

# Node >= 23.0.0（overlay package.json engines.node>=23.0.0）
if command -v node &>/dev/null; then
  NODE_VER=$(node --version 2>&1)   # v23.x.x
  if ver_ge "$NODE_VER" "23.0.0"; then
    pass "Node.js: $NODE_VER (>=23.0.0)"
  else
    fail "Node.js $NODE_VER 低于 23.0.0（overlay engines.node>=23.0.0）"
  fi
else
  fail "Node.js 未安装（要求 >= 23.0.0）"
fi

# Python >= 3.11 < 3.14（hermes-agent 运行时）
if command -v python3 &>/dev/null; then
  PY_VER=$(python3 --version 2>&1 | awk '{print $2}')   # 3.12.x
  if ver_ge "$PY_VER" "3.11.0" && ! ver_ge "$PY_VER" "3.14.0"; then
    pass "Python: $PY_VER (>=3.11 <3.14, hermes-agent)"
  elif ver_ge "$PY_VER" "3.14.0"; then
    fail "Python $PY_VER >= 3.14（hermes-agent 要求 <3.14）"
  else
    fail "Python $PY_VER 低于 3.11（hermes-agent 要求 >=3.11）"
  fi
else
  fail "Python3 未安装（要求 >=3.11 <3.14, hermes-agent 运行时）"
fi

echo ""
echo "=== 工具权限检测 ==="

check_tool() {
  local cmd="$1" label="$2"
  if command -v "$cmd" &>/dev/null; then
    pass "$label: $("$cmd" --version 2>&1 | head -1)"
  else
    warn "$label 未安装（部分功能受限）"
  fi
}
check_tool git "Git"
check_tool gh "GitHub CLI"
check_tool docker "Docker（desktop 打包可选）"

echo ""
echo "=== 外部资源连通性检测 ==="
echo "  ncwk 使用 embedded SQLite（node:sqlite DatabaseSync），无外部 DB/Redis/MQ/ELK。"
pass "无外部资源依赖（embedded SQLite + 本地文件）"

echo ""
echo "=== overlay 注入态检测 ==="
if [[ -d "$PROJECT_DIR" ]]; then
  cd "$PROJECT_DIR"
  if [[ -f ".overlay-injected.json" ]]; then
    pass "注入清单存在: .overlay-injected.json"
  else
    warn "未检测到注入清单（运行 npm run ensure-injected）"
  fi
  if [[ -f "vite.config.overlay.ts" ]]; then
    pass "vite.config.overlay.ts 已生成（inject 产物）"
  else
    warn "vite.config.overlay.ts 不存在（运行 npm run inject）"
  fi
  if [[ -f "patches/series" ]]; then
    PATCH_COUNT=$(grep -cv '^#\|^$' patches/series 2>/dev/null || echo 0)
    pass "patches/series: $PATCH_COUNT 个活跃 patch"
  else
    fail "patches/series 不存在"
  fi
else
  fail "overlay 目录不存在: $PROJECT_DIR"
fi

echo ""
echo "=== 代码仓库状态检测 ==="
if [[ -d "$PROJECT_DIR/.git" ]]; then
  cd "$PROJECT_DIR"
  pass "git 仓库分支: $(git branch --show-current 2>/dev/null || echo 'detached')"
  pass "工作树: $(git status --porcelain 2>/dev/null | wc -l | xargs) 个改动"
else
  warn "$PROJECT_DIR 不是 git 仓库"
fi

echo ""
echo "=== desktop prepare:runtime 检测（发布前才需要）==="
DESKTOP_DIR="$PROJECT_DIR/packages/desktop"
if [[ -d "$DESKTOP_DIR" ]]; then
  pass "packages/desktop 存在（swarmstudio v0.6.23, electron）"
  if [[ -f "$DESKTOP_DIR/package.json" ]]; then
    pass "desktop package.json 存在"
  fi
  echo "  prepare:runtime 需 fetch:node(python-build-standalone PBS_TAG=20260510 PBS_PY=3.12.13) + fetch:git(Windows only)"
  echo "  发布前运行: npm run build:dmg:mac（会自动 inject→build:full→npm ci→tsc main→electron-builder）"
else
  warn "packages/desktop 不存在（仅 Web 开发可忽略）"
fi

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo "✓ 环境检测通过"
  exit 0
else
  echo "✗ 环境检测未通过，请修复上述问题"
  exit 1
fi
