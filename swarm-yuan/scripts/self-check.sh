#!/usr/bin/env bash
# self-check.sh — swarm-yuan 运行前自检：10 个项目运行时是否已安装，未装则自动安装最新版
#
# 安装策略（优先级从高到低）：
#   1. 本地源码（RESEARCH_DIR 下各项目 git clone）：git pull → install 依赖 → build → npm link
#      · 适合开发/调试：能改源码、能跟上游最新 commit
#   2. npm 全局包（@latest）：npm i -g <pkg>@latest
#      · 适合纯使用：无源码、无 build、即装即用
#   3. npx 一次性调用（@latest）：npx -y <pkg>@latest <args>
#      · 适合不愿全局安装的场景
#
# 用法:
#   bash self-check.sh                  # 检测 + 自动安装/升级到最新版（优先用 research 源码）
#   bash self-check.sh --check-only     # 仅检测不安装
#   bash self-check.sh --install <name> # 仅装指定项目（最新版）
#   bash self-check.sh --npm            # 强制用 npm 全局包安装（跳过 research 源码）
#   bash self-check.sh --latest         # 已装的也升级到最新版
#
# 环境变量:
#   RESEARCH_DIR  本地源码根目录（默认推断：脚本所在 skills/swarm-yuan 的上层 research 目录）

# 注意：set -u 与管道中 read 配合时需谨慎；这里不用 set -e 以便单个失败不中断整体
set -uo pipefail
FAIL=0
pass(){ echo "  ✓ $1"; }
miss(){ echo "  ✗ $1 未安装"; FAIL=1; return 1; }
warn(){ echo "  ⚠ $1"; }

# ---------- 推断 RESEARCH_DIR（research 目录下有各项目 git clone）----------
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"
# swarm-yuan/scripts/self-check.sh → 上 3 级是项目根，再 upstream/research
_default_research=""
for cand in \
  "$SCRIPT_PATH/../../../../upstream/research" \
  "$HOME/upstream/research"; do
  if [[ -d "$cand" ]]; then _default_research="$cand"; break; fi
done
RESEARCH_DIR="${RESEARCH_DIR:-$_default_research}"

# ---------- 探测可用包管理器 ----------
has_cmd(){ command -v "$1" &>/dev/null; }
pick_pm(){
  # 给定项目根目录，返回该项目的包管理器命令
  local root="$1"
  if [[ -f "$root/pnpm-lock.yaml" ]] && has_cmd pnpm; then echo "pnpm"
  elif [[ -f "$root/bun.lockb" || -f "$root/bunfig.toml" ]] && has_cmd bun; then echo "bun"
  elif [[ -f "$root/yarn.lock" ]] && has_cmd yarn; then echo "yarn"
  else echo "npm"; fi
}

# ---------- 检测函数（miss 时 return 1，pass 时 return 0）----------
check_openspec(){ command -v openspec &>/dev/null && pass "OpenSpec: $(openspec --version 2>&1|head -1)" || miss "OpenSpec"; }
check_comet(){ command -v comet &>/dev/null && pass "comet: $(comet --version 2>&1|head -1)" || miss "comet"; }
check_gitnexus(){ command -v gitnexus &>/dev/null && pass "GitNexus: $(gitnexus --version 2>&1|head -1)" || miss "GitNexus"; }
check_gsd_core(){ command -v gsd-tools &>/dev/null && pass "gsd-core: gsd-tools 可用" || miss "gsd-core"; }
check_claude_mem(){ command -v claude-mem &>/dev/null && pass "claude-mem: $(claude-mem --version 2>&1|head -1)" || { [[ -d ~/.claude-mem ]] && pass "claude-mem: 已安装（~/.claude-mem 存在）" || miss "claude-mem"; }; }
check_ocr(){ command -v ocr &>/dev/null && pass "open-code-review: $(ocr --version 2>&1|head -1)" || miss "open-code-review (ocr)"; }
check_graphify(){ command -v graphify &>/dev/null && pass "graphify: $(graphify --help 2>&1|head -1)" || miss "graphify"; }
check_superpowers(){ [[ -d ~/.claude/plugins/superpowers || -d ~/.claude/skills/superpowers ]] && pass "superpowers: 已安装" || miss "superpowers（需 /plugin install）"; }
check_gstack(){ [[ -d ~/.claude/skills/gstack ]] && pass "gstack: 已安装" || miss "gstack（需 git clone + setup）"; }
check_ruflo(){ command -v ruflo &>/dev/null && pass "ruflo: $(ruflo --version 2>&1|head -1)" || miss "ruflo"; }

# ---------- 通用：从 research 源码安装（git pull + install + build + link）----------
# 参数: <项目名> <源码根目录> [可选 bin 名用于 link]
# 鲁棒性：install 用 --ignore-scripts 避免 prepare/postinstall 触发子 pm 失败；
#        build 单独执行；link 用 npm link（pnpm link --global 需 PATH 配置，不稳）；
#        任一步失败则返回非 0，调用方降级到 npm i -g @latest
install_from_source(){
  local name="$1" root="$2"
  local pj="$root/package.json"
  if [[ ! -f "$pj" ]]; then
    echo "  ✗ $name 源码目录无 package.json: $root"
    return 1
  fi
  local pm; pm=$(pick_pm "$root")
  echo "  → [$name] 源码安装 ($pm): $root"
  # 1. git pull 拉最新（research 目录是只读参考，pull --ff-only 不改未提交内容）
  if [[ -d "$root/.git" ]]; then
    echo "  → git pull --ff-only"
    (cd "$root" && git pull --ff-only 2>&1 | tail -2) || warn "$name git pull 失败（可能本地有改动，继续用当前版本）"
  fi
  # 2. install 依赖（--ignore-scripts 跳过 prepare/postinstall，避免子 pm 触发失败）
  echo "  → $pm install --ignore-scripts"
  (cd "$root" && $pm install --ignore-scripts 2>&1 | tail -2) || { warn "$name $pm install 失败"; return 1; }
  # 3. build（单独执行，更可控）
  local build_script
  build_script=$(node -e "const p=require('$pj'); console.log((p.scripts&&p.scripts.build)||'')" 2>/dev/null)
  if [[ -n "$build_script" ]]; then
    echo "  → $pm run build"
    (cd "$root" && $pm run build 2>&1 | tail -4) || { warn "$name build 失败"; return 1; }
  fi
  # 4. npm link 全局注册 bin（npm link 比 pnpm link --global 兼容性更好）
  #    但 npm link 会触发 prepare，故用 --no-scripts 避免重复 build
  echo "  → npm link --no-scripts"
  if (cd "$root" && npm link --no-scripts 2>&1 | tail -2); then
    echo "  ✓ $name 源码安装完成（npm link 已注册）"
  else
    warn "$name npm link 失败，降级 npm i -g @latest"
    return 1
  fi
}

# ---------- research 源码根目录定位 ----------
src_root_openspec(){ echo "$RESEARCH_DIR/openspec"; }
src_root_comet(){    echo "$RESEARCH_DIR/comet"; }
src_root_gitnexus(){ echo "$RESEARCH_DIR/gitnexus/gitnexus"; }  # 嵌套：外层 monorepo，内层才是包
src_root_gsd_core(){ echo "$RESEARCH_DIR/gsd-core"; }
src_root_claude_mem(){ echo "$RESEARCH_DIR/claude-mem"; }
src_root_ocr(){      echo "$RESEARCH_DIR/open-code-review"; }

# ---------- 安装函数（优先 research 源码，降级 npm/npx）----------
# 模式：源码优先 → 失败则降级 npm i -g @latest / npx -y @latest
install_openspec(){
  if [[ -n "$RESEARCH_DIR" && -d "$(src_root_openspec)" && $USE_NPM_ONLY -eq 0 ]]; then
    install_from_source "openspec" "$(src_root_openspec)" \
      || { echo "  ↻ 降级 npm i -g @fission-ai/openspec@latest"; npm i -g @fission-ai/openspec@latest 2>&1|tail -2; }
  else
    echo "  → npm i -g @fission-ai/openspec@latest"; npm i -g @fission-ai/openspec@latest 2>&1|tail -2
  fi
}
install_comet(){
  if [[ -n "$RESEARCH_DIR" && -d "$(src_root_comet)" && $USE_NPM_ONLY -eq 0 ]]; then
    install_from_source "comet" "$(src_root_comet)" \
      || { echo "  ↻ 降级 npm i -g @rpamis/comet@latest"; npm i -g @rpamis/comet@latest 2>&1|tail -2; }
  else
    echo "  → npm i -g @rpamis/comet@latest"; npm i -g @rpamis/comet@latest 2>&1|tail -2
  fi
}
install_gitnexus(){
  if [[ -n "$RESEARCH_DIR" && -d "$(src_root_gitnexus)" && $USE_NPM_ONLY -eq 0 ]]; then
    install_from_source "gitnexus" "$(src_root_gitnexus)" \
      || { echo "  ↻ 降级 npm i -g gitnexus@latest"; npm i -g gitnexus@latest 2>&1|tail -2; }
  else
    echo "  → npm i -g gitnexus@latest"; npm i -g gitnexus@latest 2>&1|tail -2
  fi
}
install_gsd_core(){
  # gsd-core 是运行时 artifact 安装器：源码 build+link 提供 gsd-tools bin，
  # 但仍需 npx 调用写入 ~/.claude 运行时 artifacts
  if [[ -n "$RESEARCH_DIR" && -d "$(src_root_gsd_core)" && $USE_NPM_ONLY -eq 0 ]]; then
    install_from_source "gsd-core" "$(src_root_gsd_core)" || true
  fi
  echo "  → npx -y @opengsd/gsd-core@latest --claude --global（写入运行时 artifacts）"
  npx -y @opengsd/gsd-core@latest --claude --global 2>&1 | tail -4
}
install_claude_mem(){
  # claude-mem 用 bun（有 bunfig.toml）；research 源码 build 后 npm link
  if [[ -n "$RESEARCH_DIR" && -d "$(src_root_claude_mem)" && $USE_NPM_ONLY -eq 0 ]]; then
    install_from_source "claude-mem" "$(src_root_claude_mem)" \
      || { echo "  ↻ 降级 npx -y claude-mem@latest install"; npx -y claude-mem@latest install 2>&1|tail -4; }
  else
    echo "  → npx -y claude-mem@latest install"; npx -y claude-mem@latest install 2>&1|tail -4
  fi
}
install_ocr(){
  # ocr 的 postinstall 下载平台二进制，源码 link 不稳；优先 npm i -g @latest
  echo "  → npm i -g @alibaba-group/open-code-review@latest"; npm i -g @alibaba-group/open-code-review@latest 2>&1|tail -2
}
install_graphify(){
  # graphify 是 python 项目（uv/pipx），research 源码可 uv tool install --from <dir>
  local src="$RESEARCH_DIR/graphify"
  if [[ -n "$RESEARCH_DIR" && -d "$src" && $USE_NPM_ONLY -eq 0 ]]; then
    echo "  → git pull + uv tool install --force --from $src"
    (cd "$src" && git pull --ff-only 2>&1 | tail -2) || warn "graphify git pull 失败"
    if command -v uv &>/dev/null; then
      uv tool install --force --from "$src" graphifyy 2>&1 | tail -3
      uv tool update-shell 2>/dev/null || true
    elif command -v pipx &>/dev/null; then
      pipx install --force-venv --force "git+file://$src" 2>&1 | tail -3
    else
      echo "  ✗ 需先安装 uv (curl -LsSf https://astral.sh/uv/install.sh | sh) 或 pipx"
    fi
  else
    echo "  → uv tool install --force graphifyy"
    if command -v uv &>/dev/null; then
      uv tool install --force graphifyy 2>&1|tail -3
      uv tool update-shell 2>/dev/null || true
    elif command -v pipx &>/dev/null; then
      pipx install --force-venv graphifyy 2>&1|tail -3
    else
      echo "  ✗ 需先安装 uv (curl -LsSf https://astral.sh/uv/install.sh | sh) 或 pipx"
    fi
  fi
}
install_ruflo(){
  echo "  → npm i -g ruflo"
  npm i -g ruflo 2>&1|tail -2
}

# 升级已安装的 npm 包到最新版（静默，仅在有新版本时输出）
upgrade_npm_pkg(){
  local pkg="$1" bin="$2"
  command -v "$bin" &>/dev/null || return 0
  local cur latest
  cur=$("$bin" --version 2>/dev/null | head -1 | tr -d '[:space:]')
  [[ -z "$cur" ]] && return 0
  latest=$(npm view "$pkg" version 2>/dev/null | head -1 | tr -d '[:space:]')
  [[ -z "$latest" ]] && return 0
  if [[ "$cur" != "$latest" ]]; then
    echo "  ↻ 升级 $pkg: $cur → $latest"
    npm i -g "${pkg}@latest" 2>&1 | tail -1
  fi
}

# 从 research 源码升级（git pull + rebuild + re-link，比 npm 版本更新更激进）
upgrade_from_source(){
  local name="$1" root="$2"
  [[ -z "$root" || ! -d "$root" ]] && return 0
  echo "  ↻ [$name] 源码升级: git pull + rebuild + re-link"
  install_from_source "$name" "$root" 2>&1 | tail -2 || warn "$name 源码升级失败"
}

# 9 个项目定义：name|check_func|install_func|auto_installable
# 注：self-check 生成的 hooks.json PreToolUse 命令须发射 Claude Code 和 Cursor 都接受的
#   {"permission":"allow"} verdict（参考 ruflo v3.25.6 #2613 修复）
# 注：若目标技能注册 MCP，须检测重复注册（同一 binary 注册 claude-flow + ruflo 两个 key）
#   并通过 ruflo doctor 自愈——canonical MCP key 保留一个（参考 ruflo v3.25.6 #2612 修复）
PROJECTS=(
  "openspec|check_openspec|install_openspec|1"
  "comet|check_comet|install_comet|1"
  "gitnexus|check_gitnexus|install_gitnexus|1"
  "gsd-core|check_gsd_core|install_gsd_core|1"
  "claude-mem|check_claude_mem|install_claude_mem|1"
  "ocr|check_ocr|install_ocr|1"
  "graphify|check_graphify|install_graphify|1"
  "superpowers|check_superpowers||0"
  "gstack|check_gstack||0"
  "ruflo|check_ruflo|install_ruflo|1"
)

CHECK_ONLY=0
SINGLE=""
FORCE_LATEST=1   # 默认拉最新版
USE_NPM_ONLY=0   # --npm 时跳过 research 源码

[[ "${1:-}" == "--check-only" ]] && { CHECK_ONLY=1; FORCE_LATEST=0; }
[[ "${1:-}" == "--install" ]] && SINGLE="${2:-}"
[[ "${1:-}" == "--latest" ]] && FORCE_LATEST=1
[[ "${1:-}" == "--npm" ]] && USE_NPM_ONLY=1

echo "=========================================="
echo "  swarm-yuan 自检：10 个项目运行时"
if [[ $FORCE_LATEST -eq 1 ]]; then
  echo "  （自动安装/升级到最新版 已启用）"
else
  echo "  （仅检测，不安装/升级）"
fi
if [[ -n "$RESEARCH_DIR" && -d "$RESEARCH_DIR" && $USE_NPM_ONLY -eq 0 ]]; then
  echo "  源码优先: $RESEARCH_DIR"
elif [[ $USE_NPM_ONLY -eq 1 ]]; then
  echo "  模式: npm 全局包（跳过 research 源码）"
else
  echo "  模式: npm/npx（未找到 research 目录）"
fi
echo "=========================================="
echo ""

if [[ -n "$SINGLE" ]]; then
  # 仅安装单个
  for p in "${PROJECTS[@]}"; do
    IFS='|' read -r name chk inst auto <<< "$p"
    [[ "$name" == "$SINGLE" ]] || continue
    if [[ -z "$inst" ]]; then
      echo "✗ $name 无法 bash 自动安装（需 Claude Code /plugin 或手动 clone）"
      exit 1
    fi
    echo "=== 安装 ${name}（最新版）==="
    "$inst"
    exit 0
  done
  echo "✗ 未知项目: $SINGLE"
  echo "  可用: openspec comet gitnexus gsd-core claude-mem ocr graphify superpowers gstack"
  exit 1
fi

# 检测全部
echo "=== 检测 ==="
MISSING=()
for p in "${PROJECTS[@]}"; do
  IFS='|' read -r name chk inst auto <<< "$p"
  if "$chk" 2>/dev/null; then
    :
  else
    MISSING+=("$name|$inst|$auto")
  fi
done

echo ""
if [[ ${#MISSING[@]} -eq 0 ]]; then
  echo "✓ 全部 10 个项目运行时已安装"
fi

# 即便全部已装，若启用 --latest 则升级到最新版
if [[ $FORCE_LATEST -eq 1 && $CHECK_ONLY -eq 0 ]]; then
  echo ""
  echo "=== 升级到最新版 ==="
  if [[ -n "$RESEARCH_DIR" && -d "$RESEARCH_DIR" && $USE_NPM_ONLY -eq 0 ]]; then
    # research 源码模式：对每个有源码的项目 git pull + rebuild + re-link
    upgrade_from_source "openspec" "$(src_root_openspec)"
    upgrade_from_source "comet"    "$(src_root_comet)"
    upgrade_from_source "gitnexus" "$(src_root_gitnexus)"
    upgrade_from_source "gsd-core" "$(src_root_gsd_core)"
    upgrade_from_source "claude-mem" "$(src_root_claude_mem)"
    upgrade_from_source "open-code-review" "$(src_root_ocr)"
    # graphify python
    if [[ -d "$RESEARCH_DIR/graphify" ]]; then
      echo "  ↻ [graphify] 源码升级: git pull + uv tool reinstall"
      (cd "$RESEARCH_DIR/graphify" && git pull --ff-only 2>&1 | tail -2) || warn "graphify git pull 失败"
      if command -v uv &>/dev/null; then
        uv tool install --force --from "$RESEARCH_DIR/graphify" graphifyy 2>&1 | tail -2
      fi
    fi
    echo "  （gsd-core 额外运行 npx 拉最新运行时 artifacts）"
    npx -y @opengsd/gsd-core@latest --claude --global 2>&1 | tail -3 || true
  else
    # npm 模式：比对 npm view version 升级
    upgrade_npm_pkg "@fission-ai/openspec" "openspec"
    upgrade_npm_pkg "@rpamis/comet" "comet"
    upgrade_npm_pkg "gitnexus" "gitnexus"
    upgrade_npm_pkg "@alibaba-group/open-code-review" "ocr"
    # gsd-core / claude-mem 是 npx 调用，无法本地查版本，跳过自动升级（下次 install 时自动拉最新）
    echo "  （gsd-core / claude-mem 为 npx 调用，下次运行自动拉最新版）"
  fi
fi

if [[ ${#MISSING[@]} -eq 0 ]]; then
  echo ""
  [[ $FAIL -eq 0 ]] && echo "✓ 自检通过" || echo "⚠ 部分未通过"
  exit $FAIL
fi

echo ""
echo "=== 缺失: ${#MISSING[@]} 个 ==="
for m in "${MISSING[@]}"; do
  IFS='|' read -r name inst auto <<< "$m"
  echo "  - $name"
done

if [[ $CHECK_ONLY -eq 1 ]]; then
  echo ""
  echo "（--check-only 模式，不自动安装）"
  exit 1
fi

echo ""
echo "=== 自动安装最新版（可自动装的）==="
for m in "${MISSING[@]}"; do
  IFS='|' read -r name inst auto <<< "$m"
  if [[ "$auto" == "1" && -n "$inst" ]]; then
    echo "--- $name ---"
    "$inst"
    echo ""
  else
    warn "$name 无法 bash 自动安装："
    case "$name" in
      superpowers)
        echo "    在 Claude Code 中运行: /plugin install superpowers@claude-plugins-official"
        echo "    或: /plugin marketplace add obra/superpowers-marketplace && /plugin install superpowers"
        ;;
      gstack)
        echo "    git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack"
        echo "    cd ~/.claude/skills/gstack && ./setup"
        ;;
    esac
    echo ""
  fi
done

echo "=== 安装后复查 ==="
for m in "${MISSING[@]}"; do
  IFS='|' read -r name inst auto <<< "$m"
  case "$name" in
    openspec) check_openspec ;; comet) check_comet ;; gitnexus) check_gitnexus ;;
    gsd-core) check_gsd_core ;; claude-mem) check_claude_mem ;; ocr) check_ocr ;;
    graphify) check_graphify ;; superpowers) check_superpowers ;; gstack) check_gstack ;; ruflo) check_ruflo ;;
  esac
done

echo ""
# ===== 框架规则库时效检查 =====
fw_freshness_check() {
  echo "▶ 框架规则库时效检查"
  local now d ts age f id
  now=$(date -u +%s)
  for f in "$(cd "$(dirname "$0")/.." && pwd)/references/frameworks"/*.md; do
    id=$(basename "$f" .md)
    [[ "$id" == "_template" ]] && continue
    d=$(sed -n 's/^最后调研: *\([0-9-]*\).*/\1/p' "$f" | head -1)
    d=${d:-}
    if [[ -z "$d" ]]; then
      warn "$(basename "$f") 缺'最后调研'日期"
      continue
    fi
    # 兼容 macOS date -j 与 GNU date -d
    ts=$(date -u -j -f "%Y-%m-%d" "$d" +%s 2>/dev/null || date -u -d "$d" +%s 2>/dev/null || echo 0)
    if [[ "$ts" -eq 0 ]]; then
      warn "$(basename "$f") 日期格式异常: $d"
      continue
    fi
    age=$(( (now - ts) / 86400 ))
    if [[ "$age" -gt 365 ]]; then
      warn "$(basename "$f") 调研于 $d（${age} 天前 >365 天），建议重新核实版本区间"
    elif [[ "$age" -gt 180 ]]; then
      warn "$(basename "$f") 调研于 $d（${age} 天前 >180 天），建议关注版本变化"
    fi
  done
}
fw_freshness_check

echo ""
[[ $FAIL -eq 0 ]] && echo "✓ 自检通过" || echo "⚠ 部分未通过（手动安装的需按提示操作后重跑）"
exit $FAIL
