#!/usr/bin/env bash
# branch-setup.sh — 通用分支准备脚本模板（由 swarm-yuan 生成器按项目定制）
# 用法: bash branch-setup.sh <branch-name>
# 生成目标技能时，替换 PROJECT_DIR / PROTECTED_BRANCHES / 分支名正则 为项目实际值

set -euo pipefail

# ===== 按项目定制以下变量 =====
PROJECT_DIR="<项目根绝对路径>"
BRANCH_REGEX='^(feat|fix|refactor)/.+'   # 按项目分支规范调整
PROTECTED_BRANCHES=("main")                # 按项目保护分支调整，可追加如 "release/*" 等
TEST_CMD="<test 命令>"                   # 如 npm test / pytest / go test ./...
# ============================

BRANCH_NAME="${1:-}"

if [[ -z "$BRANCH_NAME" ]]; then
  echo "Usage: bash branch-setup.sh <branch-name>"
  echo "  e.g. bash branch-setup.sh feat/my-feature"
  exit 1
fi

# 校验分支名规范
if [[ ! "$BRANCH_NAME" =~ $BRANCH_REGEX ]]; then
  echo "ERROR: 分支名不符合规范: $BRANCH_REGEX"
  exit 1
fi

# 校验不是保护分支
for pb in "${PROTECTED_BRANCHES[@]}"; do
  if [[ "$BRANCH_NAME" == "$pb" ]]; then
    echo "ERROR: 绝不允许在保护分支 $pb 上开发"
    exit 1
  fi
done

cd "$PROJECT_DIR"

echo "=== 起点核验 ==="

CURRENT=$(git branch --show-current)
if [[ "$CURRENT" != "main" ]]; then
  echo "WARN: 当前分支为 '$CURRENT'，切换到 main"
  git checkout main
fi

HEAD_REV=$(git rev-parse HEAD)
MAIN_REV=$(git rev-parse main)
if [[ "$HEAD_REV" != "$MAIN_REV" ]]; then
  echo "ERROR: HEAD ($HEAD_REV) 与 main ($MAIN_REV) 不一致，可能处于游离 commit"
  exit 1
fi

# 检查工作树（忽略文档类改动）
DIRTY=$(git status --porcelain | grep -v -E '\.md$' || true)
if [[ -n "$DIRTY" ]]; then
  echo "ERROR: 工作树有非文档改动:"
  echo "$DIRTY"
  echo "  请先 commit 或 stash"
  exit 1
fi

echo "  ✓ 在 main，HEAD = main，工作树干净（文档除外）"

echo "=== 创建分支: $BRANCH_NAME ==="
git checkout -b "$BRANCH_NAME"

echo ""
echo "=== 测试基线 ==="
eval "$TEST_CMD" 2>&1 | tail -5 || echo "(测试未通过，请检查环境)"

echo ""
echo "✓ 分支已创建: $BRANCH_NAME"
