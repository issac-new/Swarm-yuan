#!/usr/bin/env bash
# build-offline-win.sh — 构建 Windows 离线安装包
# 预下载 swarm-yuan 的 10 个运行时到 offline-cache/，然后打包成 zip
# 用法: bash scripts/build-offline-win.sh [输出目录]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_DIR="$SKILL_DIR/offline-cache"
OUTPUT_DIR="${1:-$CACHE_DIR}"
VERSION="$(date -u +%Y%m%d)"
ZIP_NAME="swarm-yuan-offline-win-${VERSION}.zip"
ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"

echo "=== swarm-yuan Windows 离线包构建 ==="
echo "  技能目录: $SKILL_DIR"
echo "  缓存目录: $CACHE_DIR"
echo "  输出: $ZIP_PATH"

mkdir -p "$CACHE_DIR/npm" "$CACHE_DIR/graphify-wheels" "$CACHE_DIR/superpowers" "$CACHE_DIR/gstack"

# ===== 1. npm 包（7 个）=====
echo "=== 1/5 下载 npm 离线包（7 个）==="
NPM_PKGS=(
  "@fission-ai/openspec"
  "@rpamis/comet"
  "gitnexus"
  "@opengsd/gsd-core"
  "claude-mem"
  "@alibaba-group/open-code-review"
  "ruflo"
)
for pkg in "${NPM_PKGS[@]}"; do
  echo "  → npm pack $pkg ..."
  (cd "$CACHE_DIR/npm" && npm pack "$pkg" 2>/dev/null) && echo "    ✓ $pkg" || echo "    ✗ $pkg 失败（跳过）"
done
echo "  npm tarball 数: $(ls "$CACHE_DIR/npm/"*.tgz 2>/dev/null | wc -l | xargs)"

# ===== 2. graphify（Python wheel）=====
echo "=== 2/5 下载 graphify Python wheels ==="
if command -v uv >/dev/null 2>&1; then
  echo "  → uv pip download graphifyy ..."
  uv pip download graphifyy -o "$CACHE_DIR/graphify-wheels/" 2>/dev/null && echo "    ✓ graphify wheels" || echo "    ✗ graphify 下载失败（跳过）"
elif command -v pip3 >/dev/null 2>&1; then
  echo "  → pip3 download graphifyy ..."
  pip3 download graphifyy -d "$CACHE_DIR/graphify-wheels/" 2>/dev/null && echo "    ✓ graphify wheels" || echo "    ✗ graphify 下载失败（跳过）"
else
  echo "  ⚠ uv/pip3 均不可用，跳过 graphify"
fi
echo "  wheel 文件数: $(ls "$CACHE_DIR/graphify-wheels/"*.whl 2>/dev/null | wc -l | xargs)"

# ===== 3. superpowers（git clone）=====
echo "=== 3/5 克隆 superpowers ==="
if [[ ! -d "$CACHE_DIR/superpowers/.git" ]]; then
  git clone --depth 1 https://github.com/obra/superpowers-marketplace.git "$CACHE_DIR/superpowers" 2>/dev/null && echo "  ✓ superpowers" || echo "  ✗ superpowers 克隆失败（跳过）"
else
  echo "  ✓ superpowers 已存在（跳过）"
fi

# ===== 4. gstack（git clone）=====
echo "=== 4/5 克隆 gstack ==="
if [[ ! -d "$CACHE_DIR/gstack/.git" ]]; then
  git clone --depth 1 https://github.com/garrytan/gstack.git "$CACHE_DIR/gstack" 2>/dev/null && echo "  ✓ gstack" || echo "  ✗ gstack 克隆失败（跳过）"
else
  echo "  ✓ gstack 已存在（跳过）"
fi

# ===== 5. 打包 zip =====
echo "=== 5/5 打包 zip ==="
cd "$SKILL_DIR"
# 清理不需要的文件
find . -name '.DS_Store' -delete 2>/dev/null || true
rm -rf .upgrade-backup-* 2>/dev/null || true

zip -r "$ZIP_PATH" . \
  -x ".git/*" \
  -x ".DS_Store" \
  -x "offline-cache/.tmp/*" \
  -x "*.pyc" \
  -x "__pycache__/*" \
  2>/dev/null && echo "  ✓ $ZIP_NAME" || echo "  ✗ 打包失败"

ZIP_SIZE=$(du -h "$ZIP_PATH" 2>/dev/null | cut -f1 | xargs)
echo ""
echo "=== 构建完成 ==="
echo "  产物: $ZIP_PATH"
echo "  大小: $ZIP_SIZE"
echo "  npm tarball: $(ls "$CACHE_DIR/npm/"*.tgz 2>/dev/null | wc -l | xargs) 个"
echo "  graphify wheels: $(ls "$CACHE_DIR/graphify-wheels/"*.whl 2>/dev/null | wc -l | xargs) 个"
echo "  superpowers: $([ -d "$CACHE_DIR/superpowers" ] && echo '有' || echo '无')"
echo "  gstack: $([ -d "$CACHE_DIR/gstack" ] && echo '有' || echo '无')"
echo ""
echo "  Windows 安装命令:"
echo "    1. 下载 $ZIP_NAME"
echo "    2. 解压到任意目录"
echo "    3. 双击 install-offline-win.bat"
