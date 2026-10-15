#!/usr/bin/env bash
# make-offline-bundle.sh — 离线安装包构建器（Windows 目标机；npm/pip 镜像可解决部分依赖）
#
# 产物：<out>/swarm-yuan-offline-<ver>.zip
#   swarm-yuan/            技能本体（离线完备：外部运行时未装时技能按诚实降级运行，不阻塞）
#   vendor/npm/*.tgz       清单中 npm 通道运行时的本地包（目标机 npm i -g ./xxx.tgz 免源安装）
#   vendor/pip/            清单中 pip 通道运行时（目标机 pip install --no-index --find-links 免源安装）
#   install-offline.bat/.sh/README-OFFLINE.md  Windows 入口 + 安装器 + 说明
#
# 用法：bash scripts/make-offline-bundle.sh <输出目录>（缺省 dist/）
# 清单：scripts/offline-manifest.conf（runtime|channel|spec|note；channel ∈ npm|pip|github）
#   github 通道运行时不入 vendor（源码仓不可免源分发）——README-OFFLINE 披露其离线不可得与降级语义。
# 依赖：zip、npm pack（在线拉包）；pip 通道需 pip download。缺 zip 降级 tar.gz。
set -euo pipefail

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# 技能本体目录：默认构建器所在 scripts/ 的上级；可用 SWARM_YUAN_DIR 覆盖（从任意位置运行）
SKILL_ROOT="${SWARM_YUAN_DIR:-$(cd "$SELF_DIR/.." && pwd)}"
[[ -f "$SKILL_ROOT/install.sh" ]] || { echo "✗ 技能目录无效（缺 install.sh）: $SKILL_ROOT——用 SWARM_YUAN_DIR=/path/to/swarm-yuan 指定" >&2; exit 1; }
MANIFEST="$SELF_DIR/offline-manifest.conf"
OUT_ROOT="${1:-$SKILL_ROOT/../dist}"
VER="$(git -C "$SKILL_ROOT" describe --tags --always 2>/dev/null || echo unknown)"
BUNDLE="$OUT_ROOT/swarm-yuan-offline-$VER"

command -v npm >/dev/null 2>&1 || { echo "✗ 缺 npm（vendor 拉包需要）" >&2; exit 1; }
[[ -f "$MANIFEST" ]] || { echo "✗ 清单缺失: $MANIFEST" >&2; exit 1; }

echo "=== 构建离线安装包: swarm-yuan-offline-$VER ==="
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/vendor/npm" "$BUNDLE/vendor/pip"

# ① 技能本体（分发边界与 install.sh 一致：research/.swarm-yuan/offline-cache/ci 不入包）
echo "① 技能本体…"
SRC_BASE="$(basename "$SKILL_ROOT")"
mkdir -p "$BUNDLE/$SRC_BASE/scripts"
for item in "$SKILL_ROOT"/* "$SKILL_ROOT"/.[!.]*; do
  [[ -e "$item" ]] || continue
  base="$(basename "$item")"
  case "$base" in research|.swarm-yuan|offline-cache|ci) continue ;; esac
  cp -R "$item" "$BUNDLE/$SRC_BASE/"
done
# 构建器与清单随包（目标机可重打包/核对版本口径）
cp "$SELF_DIR/make-offline-bundle.sh" "$SELF_DIR/offline-manifest.conf" "$BUNDLE/$SRC_BASE/scripts/"

# ② vendor：按清单通道拉包（在线侧动作；失败逐条披露不中止——技能本体离线完备是底线）
echo "② vendor 运行时（npm/pip 本地包）…"
npm_fail=0; pip_fail=0; gh_list=""
while IFS='|' read -r rt ch spec note; do
  case "$rt" in ''|'#'*) continue ;; esac
  case "$ch" in
    npm)
      if (cd "$BUNDLE/vendor/npm" && npm pack "$spec" >/dev/null 2>&1); then
        echo "  ✓ npm: ${rt}（${spec}）"
      else
        echo "  ⚠ npm: ${rt}（${spec}）拉包失败——不入 vendor，目标机走镜像安装或降级" >&2
        npm_fail=$((npm_fail+1))
      fi ;;
    pip)
      # 用 python3 -m pip（裸 pip 可能是坏解释器垫片——brew 升级挪走旧 python 的实录坑）
      if python3 -m pip download "$spec" -d "$BUNDLE/vendor/pip" --no-deps -q >/dev/null 2>&1; then
        echo "  ✓ pip: ${rt}（${spec}）"
      else
        echo "  ⚠ pip: ${rt}（${spec}）下载失败——不入 vendor，目标机走镜像安装或降级" >&2
        pip_fail=$((pip_fail+1))
      fi ;;
    github)
      gh_list="$gh_list $rt"
      ;;
  esac
done < "$MANIFEST"

# ③ 离线安装器（Windows 入口 .bat + bash 安装器 + 说明）
echo "③ 离线安装器…"
cat > "$BUNDLE/install-offline.sh" <<'IOF'
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
IOF
chmod +x "$BUNDLE/install-offline.sh"

cat > "$BUNDLE/install-offline.bat" <<'IEOF'
@echo off
rem swarm-yuan 离线安装入口（Windows）：经 Git Bash 运行 install-offline.sh
rem 前置：安装 Git for Windows（含 bash/git），且 bash 在 PATH
where bash >nul 2>nul || (echo [ERROR] 未找到 bash——请先安装 Git for Windows 并将其加入 PATH & exit /b 1)
bash "%~dp0install-offline.sh" %*
IEOF

cat > "$BUNDLE/README-OFFLINE.md" <<'IMD'
# swarm-yuan 离线安装包（Windows）

## 前置条件（目标机）
- **Git for Windows**（提供 bash 与 git；技能脚本与门禁均为 bash——仓库三平台铁律：Windows 走 Git Bash）
- AI 编码工具任一：Claude Code / Codex / Cursor / Windsurf / OpenCode / Gemini CLI / Kimi / ZCode
- 可选：node+npm、python+pip（仅当用 --with-npm/--with-pip 装 vendor 运行时，或经内部镜像源补装）

## 安装
1. 解压本包到任意目录（路径不含空格更稳）。
2. 双击 `install-offline.bat`（或在其目录开 Git Bash 跑 `bash install-offline.sh`）——自动检测已装 AI 工具并安装技能。
3. 指定目标：`install-offline.bat --claude`；连 vendor 运行时一起装：`install-offline.bat --all --with-npm --with-pip`。

## vendor 与镜像源说明
- `vendor/npm/*.tgz`、`vendor/pip/`：构建机预拉的本地产物包，安装免网络（npm i -g ./xxx.tgz；pip --no-index --find-links）。
- 包不在 vendor 时（拉包失败或 github 通道），目标机可用内部 npm/pip 镜像源自行补装；装不上不影响技能运行。

## 外部运行时的离线语义（诚实降级）
技能的深度运行时（代码图谱/记忆插件等）未安装时**不阻塞**：相关门禁与能力按「未装披露」降级运行。
核心能力（生成技能、门禁检查、spec-first 四层拦截、提交时 pre-commit）零外部依赖，离线完备。
GitHub 通道运行时空白清单见 scripts/offline-manifest.conf（channel=github 行）。

## 首次使用
对 AI 说：「为 /path/to/project 生成开发技能」。之后每个需求按 SKILL.md 九节点工作流协作。
IMD

# ④ 打包（zip 优先，缺 zip 降级 tar.gz）
echo "④ 打包…"
if command -v zip >/dev/null 2>&1; then
  (cd "$OUT_ROOT" && zip -qr "swarm-yuan-offline-$VER.zip" "swarm-yuan-offline-$VER")
  ART="$OUT_ROOT/swarm-yuan-offline-$VER.zip"
else
  (cd "$OUT_ROOT" && tar -czf "swarm-yuan-offline-$VER.tar.gz" "swarm-yuan-offline-$VER")
  ART="$OUT_ROOT/swarm-yuan-offline-$VER.tar.gz"
fi

echo "=== 完成: $ART ==="
echo "  vendor: npm 失败 $npm_fail 个 / pip 失败 $pip_fail 个 / github 通道不入（${gh_list:-无}）——详见上方逐条披露"
du -sh "$ART" 2>/dev/null || true
