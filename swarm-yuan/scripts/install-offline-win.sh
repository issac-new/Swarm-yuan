#!/usr/bin/env bash
# install-offline-win.sh — Windows 离线安装（从 offline-cache/ 本地安装 10 个运行时 + swarm-yuan 技能）
# 由 install-offline-win.bat 调用，也可直接 bash 运行
#
# offline-cache 降级链（建议4 迁移 Release 后）：
#   1. 本地 offline-cache/ 存在 → 直接用（开发仓库自带 / 用户手动放入）
#   2. 本地不存在 → 从 GitHub Release v<date>-offline 下载 swarm-yuan-offline-cache-<date>.zip 解压
#   3. 下载失败 → 在线安装各运行时（各步骤内部已有在线 fallback）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_DIR="$SKILL_DIR/offline-cache"

# ===== offline-cache 降级链：本地无 cache 时从 Release 下载 =====
# OFFLINE_CACHE_RELEASE 变量可覆盖默认 Release tag（默认用最新 -offline tag）
OFFLINE_CACHE_RELEASE="${OFFLINE_CACHE_RELEASE:-v2026.07.20-offline}"
OFFLINE_CACHE_URL="https://github.com/issac-new/Swarm-yuan/releases/download/${OFFLINE_CACHE_RELEASE}/swarm-yuan-offline-cache.zip"

if [[ ! -d "$CACHE_DIR" || $(find "$CACHE_DIR" -type f \( -name "*.whl" -o -name "*.tgz" \) 2>/dev/null | wc -l) -eq 0 ]]; then
  echo "=== offline-cache 本地不存在，从 Release 下载 ==="
  echo "  Release: $OFFLINE_CACHE_RELEASE"
  echo "  URL: $OFFLINE_CACHE_URL"
  if command -v curl >/dev/null 2>&1; then
    mkdir -p "$CACHE_DIR"
    tmp_zip="$(mktemp /tmp/swarm-yuan-cache.XXXXXX.zip)"
    if curl -fL --retry 2 "$OFFLINE_CACHE_URL" -o "$tmp_zip" 2>/dev/null; then
      echo "  ✓ 下载完成，解压到 $CACHE_DIR"
      unzip -q -o "$tmp_zip" -d "$CACHE_DIR" 2>/dev/null && echo "  ✓ 解压完成" || { echo "  ✗ 解压失败（unzip 不可用或 zip 损坏）"; }
      rm -f "$tmp_zip"
    else
      echo "  ⚠ 下载失败（$OFFLINE_CACHE_RELEASE 可能不存在或网络问题），降级到在线安装"
      rm -f "$tmp_zip"
    fi
  else
    echo "  ⚠ curl 不可用，无法下载，降级到在线安装"
  fi
fi

echo "=== swarm-yuan Windows 离线安装 ==="
echo "  技能目录: $SKILL_DIR"
echo "  离线缓存: $CACHE_DIR"

errors=0

# ===== 1. 安装 npm 包（7 个）=====
echo "=== 1/5 安装 npm 离线包 ==="
if [[ -d "$CACHE_DIR/npm" ]]; then
  TARBALLS=("$CACHE_DIR/npm/"*.tgz)
  if [[ ${#TARBALLS[@]} -gt 0 && -f "${TARBALLS[0]}" ]]; then
    for tb in "${TARBALLS[@]}"; do
      [[ -f "$tb" ]] || continue
      echo "  → npm i -g $(basename "$tb")"
      npm i -g "$tb" --offline 2>/dev/null && echo "    ✓" || { echo "    ✗ 失败（尝试在线安装）"; npm i -g "$tb" 2>/dev/null && echo "    ✓ (在线)" || { echo "    ✗ 跳过"; errors=$((errors+1)); }; }
    done
  else
    echo "  ⚠ 无 npm tarball"
  fi
else
  echo "  ⚠ offline-cache/npm 不存在"
fi

# ===== 2. 安装 graphify（Python wheel 离线）=====
echo "=== 2/5 安装 graphify ==="
if [[ -d "$CACHE_DIR/graphify-wheels" ]] && ls "$CACHE_DIR/graphify-wheels/"*.whl >/dev/null 2>&1; then
  if command -v uv >/dev/null 2>&1; then
    echo "  → uv tool install --offline graphifyy"
    uv tool install --offline --from "$CACHE_DIR/graphify-wheels/" graphifyy 2>/dev/null && echo "    ✓" || { echo "    ✗ 离线失败（尝试在线）"; uv tool install --force graphifyy 2>/dev/null && echo "    ✓ (在线)" || { echo "    ✗ 跳过"; errors=$((errors+1)); }; }
  elif command -v pipx >/dev/null 2>&1; then
    echo "  → pipx install --no-index --find-links"
    pipx install --no-index --find-links "$CACHE_DIR/graphify-wheels/" graphifyy 2>/dev/null && echo "    ✓" || { echo "    ✗ 跳过"; errors=$((errors+1)); }
  else
    echo "  ⚠ uv/pipx 均不可用，跳过 graphify（需先安装 uv 或 pipx）"
  fi
else
  echo "  ⚠ 无 graphify wheels（跳过）"
fi

# ===== 3. 安装 gstack =====
echo "=== 3/5 安装 gstack ==="
if [[ -d "$CACHE_DIR/gstack" ]]; then
  DEST="$HOME/.claude/skills/gstack"
  mkdir -p "$HOME/.claude/skills"
  if [[ -d "$DEST" ]]; then
    echo "  → gstack 已存在，更新..."
    rm -rf "$DEST"
  fi
  cp -r "$CACHE_DIR/gstack" "$DEST"
  echo "  → 运行 setup ..."
  (cd "$DEST" && bash ./setup 2>/dev/null) && echo "    ✓ gstack" || { echo "    ⚠ setup 失败（gstack 目录已复制，可手动运行 ./setup）"; }
else
  echo "  ⚠ offline-cache/gstack 不存在（跳过）"
fi

# ===== 4. 安装 superpowers =====
echo "=== 4/5 安装 superpowers ==="
if [[ -d "$CACHE_DIR/superpowers" ]]; then
  DEST="$HOME/.claude/plugins/superpowers"
  mkdir -p "$HOME/.claude/plugins"
  if [[ -d "$DEST" ]]; then
    echo "  → superpowers 已存在，更新..."
    rm -rf "$DEST"
  fi
  cp -r "$CACHE_DIR/superpowers" "$DEST"
  echo "    ✓ superpowers（目录已复制，需在 Claude Code 中 /plugin enable）"
else
  echo "  ⚠ offline-cache/superpowers 不存在（跳过）"
fi

# ===== 5. 安装 swarm-yuan 技能 =====
echo "=== 5/5 安装 swarm-yuan 技能 ==="
if [[ -f "$SKILL_DIR/install.sh" ]]; then
  bash "$SKILL_DIR/install.sh" --claude 2>/dev/null && echo "    ✓ swarm-yuan 技能已安装" || { echo "    ✗ 安装失败"; errors=$((errors+1)); }
else
  echo "  ⚠ install.sh 不存在"
fi

# ===== 总结 =====
echo ""
echo "=== 安装完成 ==="
echo "  错误数: $errors"
if [[ $errors -eq 0 ]]; then
  echo "  ✓ 全部成功"
else
  echo "  ⚠ 有 $errors 个失败项（见上方日志）"
fi
echo ""
echo "  验证命令:"
echo "    bash ~/.claude/skills/swarm-yuan/scripts/self-check.sh --check-only"
