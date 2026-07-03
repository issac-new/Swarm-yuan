#!/usr/bin/env bash
# branch-setup.sh — ncwk overlay 分支准备脚本（hermes-overlay 二次开发）
# 用法: bash branch-setup.sh <branch-name>
# 基于 main 创建 feat/fix/refactor/chore 分支，含起点核验 + 测试基线

set -euo pipefail

# ===== ncwk 定制 =====
PROJECT_DIR="/Volumes/nvme2230/lab/ncwk/overlay"
BRANCH_REGEX='^(feat|fix|refactor|chore)/.+'
PROTECTED_BRANCHES=("main" "backup/pre-squash")
TEST_CMD="npm test"
# =====================

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
