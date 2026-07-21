#!/usr/bin/env bash
# fetch-offline-cache.sh — 从 GitHub Release 拉取 offline-cache（WP-J：196MB 二进制不入 git）
# 用法: bash scripts/fetch-offline-cache.sh [--release <tag>] [--force]
#   --release  覆盖默认 Release tag（默认 v2026.07.20-offline，与 install-offline-win.sh 一致）
#   --force    本地已有 whl/tgz 时仍重新下载
# 退出码：成功/已存在 0；无网络或下载失败 1（附手工指引）。zip 解压后自动删除。
set -euo pipefail

RELEASE="${OFFLINE_CACHE_RELEASE:-v2026.07.20-offline}"
FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) RELEASE="${2:?--release 需要 tag 名}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数: $1（--help 查看用法）" >&2; exit 1 ;;
  esac
done

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="$SKILL_DIR/offline-cache"
URL="https://github.com/issac-new/Swarm-yuan/releases/download/${RELEASE}/swarm-yuan-offline-cache.zip"

if [[ "$FORCE" -eq 0 && -d "$CACHE_DIR" ]]; then
  _n=$(find "$CACHE_DIR" -type f \( -name "*.whl" -o -name "*.tgz" \) 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$_n" -gt 0 ]]; then
    echo "✓ offline-cache 已存在（${_n} 个 whl/tgz），跳过下载（--force 可重下）"
    exit 0
  fi
fi

command -v curl >/dev/null 2>&1 || { echo "✗ 需要 curl（未安装）" >&2; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "✗ 需要 unzip（未安装）" >&2; exit 1; }

echo "=== 下载 offline-cache ==="
echo "  Release: $RELEASE"
echo "  URL: $URL"
mkdir -p "$CACHE_DIR"
_tmp="$(mktemp /tmp/offline-cache.XXXXXX.zip)"
if ! curl -fSL --connect-timeout 15 -o "$_tmp" "$URL"; then
  rm -f "$_tmp"
  echo "✗ 下载失败（无网络或 Release 不存在）" >&2
  echo "  手工指引：浏览器下载 $URL 后解压到 $CACHE_DIR/" >&2
  exit 1
fi
unzip -oq "$_tmp" -d "$CACHE_DIR"
rm -f "$_tmp"
_n=$(find "$CACHE_DIR" -type f \( -name "*.whl" -o -name "*.tgz" \) 2>/dev/null | wc -l | tr -d ' ')
echo "✓ offline-cache 已就绪：${_n} 个 whl/tgz（$CACHE_DIR）"
