#!/usr/bin/env bash
# install-offline.sh — swarm-yuan 离线安装器（Windows 经 Git Bash 运行；同伴 .bat 为入口）
# 用法：bash install-offline.sh [--claude|--zcode|--codex|--cursor|--windsurf|--opencode|--gemini|--kimi|--all]
#                 [--with-npm] [--with-pip]   # 默认只装技能本体；带旗标才装 vendor 运行时
# 前置：bash（Git Bash）、git；vendor 安装另需 node/npm 或 python/pip。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR=""
for _c in "$HERE"/swarm-yuan "$HERE"/Swarm-yuan; do
  [[ -d "$_c" ]] && { SKILL_DIR="$_c"; break; }
done
[[ -z "$SKILL_DIR" ]] && { echo "✗ 未找到技能目录（$HERE/swarm-yuan）" >&2; exit 1; }

WITH_NPM=0; WITH_PIP=0; MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-npm) WITH_NPM=1; shift ;;
    --with-pip) WITH_PIP=1; shift ;;
    --claude|--zcode|--codex|--cursor|--windsurf|--opencode|--gemini|--kimi|--all) MODE="$MODE $1"; shift ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done

echo "=== ① 安装技能本体 ==="
if [[ -n "$MODE" ]]; then
  bash "$SKILL_DIR/install.sh" $MODE
else
  bash "$SKILL_DIR/install.sh"
fi

if [[ "$WITH_NPM" -eq 1 ]]; then
  echo "=== ② vendor npm 运行时（本地包，免源安装）==="
  shopt -s nullglob 2>/dev/null || true
  _n=0
  for tgz in "$HERE"/vendor/npm/*.tgz; do
    [[ -e "$tgz" ]] || continue
    npm install -g "$tgz" && _n=$((_n+1)) || echo "  ⚠ $(basename "$tgz") 安装失败（目标机可用镜像源重试：npm i -g <包名>）" >&2
  done
  echo "  npm 本地包安装完成（$_n 个）"
fi
if [[ "$WITH_PIP" -eq 1 ]]; then
  echo "=== ③ vendor pip 运行时（本地包，--no-index 免源安装）==="
  # 包名从随包清单读（wheel 文件名推导不可靠）；用 python3 -m pip（裸 pip 垫片可能坏解释器）
  _mf="$SKILL_DIR/scripts/offline-manifest.conf"
  if [[ -d "$HERE/vendor/pip" ]] && command -v python3 >/dev/null 2>&1 && [[ -f "$_mf" ]]; then
    _pkgs=""
    while IFS='|' read -r _rt _ch _spec _note; do
      case "$_rt" in ''|'#'*) continue ;; esac
      [[ "$_ch" == "pip" ]] || continue
      _name="${_spec%%[=<>~]*}"
      _pkgs="${_pkgs} ${_name}"
    done < "$_mf"
    if [[ -n "$_pkgs" ]]; then
      # shellcheck disable=SC2086
      python3 -m pip install --no-index --find-links "$HERE/vendor/pip" --no-deps $_pkgs \
        || echo "  ⚠ pip 本地包安装失败（目标机可用镜像源重试：pip install <包名>）" >&2
    else
      echo "  · 清单无 pip 通道条目，跳过"
    fi
  else
    echo "  ⚠ 缺 python3 / vendor/pip 为空 / 清单缺失，跳过"
  fi
fi

echo "=== 离线安装完成 ==="
echo "后续：对 AI 说「为 /path/to/project 生成开发技能」；外部运行时缺装时技能按诚实降级运行（披露不阻塞）——详见 README-OFFLINE.md"
