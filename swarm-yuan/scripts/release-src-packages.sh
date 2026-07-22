#!/usr/bin/env bash
# release-src-packages.sh — 打包 gstack/superpowers/ECC 源码并上传 GitHub Release
#
# 这三个运行时无法走 npm/pip，发版时把上游源码打成 zip 挂到 Release v<ver>-src，
# self-check.sh 的 install_from_src_release() 从该 Release 拉取一键安装。
#
# 用法:
#   bash scripts/release-src-packages.sh [YYYYMMDD]    # 版本号默认当天
# 前置: 已安装 gh 并登录（gh auth status）
set -euo pipefail

REPO="issac-new/Swarm-yuan"
VERSION="${1:-$(date -u +%Y%m%d)}"
TAG="v${VERSION}-src"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 上游仓库（与 self-check.sh install_from_src_release 的 zip 名一致）
declare -a SOURCES=(
  "gstack|https://github.com/garrytan/gstack.git"
  "superpowers|https://github.com/obra/superpowers-marketplace.git"
  "ecc|https://github.com/affaan-m/ECC.git"
)

echo "=== swarm-yuan 源码包发版 ==="
echo "  版本: $VERSION  tag: $TAG"
echo "  临时目录: $TMP"
echo ""

# 前置检查
if ! command -v gh &>/dev/null; then
  echo "✗ 需先安装 GitHub CLI: https://cli.github.com/"
  exit 1
fi
if ! gh auth status &>/dev/null; then
  echo "✗ gh 未登录，请先 gh auth login"
  exit 1
fi
if ! command -v git &>/dev/null; then echo "✗ 需 git"; exit 1; fi

mkdir -p "$TMP/out"

# 1. 克隆 + 打包
for entry in "${SOURCES[@]}"; do
  IFS='|' read -r name url <<< "$entry"
  echo "--- $name ---"
  if ! git clone --depth 1 "$url" "$TMP/$name" 2>/dev/null; then
    echo "  ✗ $name 克隆失败: $url"; exit 1
  fi
  rm -rf "$TMP/$name/.git"
  (cd "$TMP" && zip -rq "$TMP/out/${name}-src.zip" "$name")
  echo "  ✓ ${name}-src.zip ($(du -h "$TMP/out/${name}-src.zip" | cut -f1))"
done

echo ""

# 2. 创建/更新 Release 并上传
if gh release view "$TAG" -R "$REPO" &>/dev/null; then
  echo "=== Release $TAG 已存在，上传覆盖 ==="
  gh release upload "$TAG" -R "$REPO" "$TMP/out/"*.zip --clobber
else
  echo "=== 创建 Release $TAG ==="
  gh release create "$TAG" -R "$REPO" \
    --title "swarm-yuan 源码包 $VERSION" \
    --notes "gstack / superpowers / ECC 源码包，供 self-check.sh install_from_src_release() 一键安装。
下载地址前缀: https://github.com/${REPO}/releases/download/${TAG}/" \
    "$TMP/out/"*.zip
fi

echo ""
echo "=== 完成 ==="
echo "  Release: https://github.com/${REPO}/releases/tag/${TAG}"
echo "  附件:"
for entry in "${SOURCES[@]}"; do
  IFS='|' read -r name _ <<< "$entry"
  echo "    - https://github.com/${REPO}/releases/download/${TAG}/${name}-src.zip"
done
