#!/usr/bin/env bash
# self-check.sh — swarm-yuan 运行前自检：11 个项目运行时是否已安装，未装则自动安装最新版
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
# swarm-yuan/scripts/self-check.sh → 上 4 级（scripts→swarm-yuan→skills→.claude→HOME），再 upstream/research
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

# ---------- 检测函数（miss 时 return 1，pass 时 return 0；if/else 形式避免 A&&B||C 误判）----------
check_openspec(){
  if command -v openspec &>/dev/null; then pass "OpenSpec: $(openspec --version 2>&1|head -1)"; else miss "OpenSpec"; fi
}
check_comet(){
  if command -v comet &>/dev/null; then pass "comet: $(comet --version 2>&1|head -1)"; else miss "comet"; fi
}
check_gitnexus(){
  if command -v gitnexus &>/dev/null; then pass "GitNexus: $(gitnexus --version 2>&1|head -1)"; else miss "GitNexus"; fi
}
check_gsd_core(){
  if command -v gsd-tools &>/dev/null; then pass "gsd-core: gsd-tools 可用"; else miss "gsd-core"; fi
}
check_claude_mem(){
  if command -v claude-mem &>/dev/null; then pass "claude-mem: $(claude-mem --version 2>&1|head -1)"
  elif [[ -d ~/.claude-mem ]]; then pass "claude-mem: 已安装（~/.claude-mem 存在）"
  else miss "claude-mem"; fi
}
check_ocr(){
  if command -v ocr &>/dev/null; then pass "open-code-review: $(ocr --version 2>&1|head -1)"; else miss "open-code-review (ocr)"; fi
}
check_graphify(){
  if command -v graphify &>/dev/null; then pass "graphify: $(graphify --help 2>&1|head -1)"; else miss "graphify"; fi
}
check_superpowers(){
  if [[ -d ~/.claude/plugins/superpowers || -d ~/.claude/skills/superpowers ]]; then pass "superpowers: 已安装"; else miss "superpowers（需 /plugin install）"; fi
}
check_gstack(){
  if [[ -d ~/.claude/skills/gstack ]]; then pass "gstack: 已安装"; else miss "gstack（需 git clone + setup）"; fi
}
check_ruflo(){
  if command -v ruflo &>/dev/null; then pass "ruflo: $(ruflo --version 2>&1|head -1)"; else miss "ruflo"; fi
}
check_ecc(){
  if [[ -d ~/.claude/plugins/ecc || -d ~/.claude/skills/ecc ]]; then pass "ECC: 已安装"; else miss "ECC（需 /plugin marketplace add https://github.com/affaan-m/ECC && /plugin install ecc）"; fi
}

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
  echo "  → npm i -g ruflo@latest"
  npm i -g ruflo@latest 2>&1|tail -2
}

# 升级已安装的 npm 包到最新版（静默，仅在有新版本时输出）
upgrade_npm_pkg(){
  local pkg="$1" bin="$2"
  command -v "$bin" &>/dev/null || return 0
  local cur latest
  cur=$("$bin" --version 2>/dev/null | head -1 | tr -d '[:space:]')
  cur="${cur#v}"   # 剥离前导 v（v3.25.6 → 3.25.6）再比对
  [[ -z "$cur" ]] && return 0
  latest=$(npm view "$pkg" version 2>/dev/null | head -1 | tr -d '[:space:]')
  latest="${latest#v}"
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

# 11 个项目定义（唯一数据源，检测/安装/升级/复查全部从此表驱动）：
#   name|check_func|install_func|auto_installable|src_root_func|npm_pkg
#   src_root_func：research 源码根函数（--latest 源码模式升级用）；空=无源码入口
#   npm_pkg：npm 全局包名（--latest npm 模式比对 version 用）；空=npx 调用或不可自动装
# 注：self-check 生成的 hooks.json PreToolUse 命令须发射 Claude Code 和 Cursor 都接受的
#   {"permission":"allow"} verdict（参考 ruflo v3.25.6 #2613 修复）
# 注：若目标技能注册 MCP，须检测重复注册（同一 binary 注册 claude-flow + ruflo 两个 key）
#   并通过 ruflo doctor 自愈——canonical MCP key 保留一个（参考 ruflo v3.25.6 #2612 修复）
# 注：hooks.json 须无 BOM（UTF-8 无 BOM），否则 Codex 严格 JSON 解析失败（参考 ruflo v3.32.1 修复）
PROJECTS=(
  "openspec|check_openspec|install_openspec|1|src_root_openspec|@fission-ai/openspec"
  "comet|check_comet|install_comet|1|src_root_comet|@rpamis/comet"
  "gitnexus|check_gitnexus|install_gitnexus|1|src_root_gitnexus|gitnexus"
  "gsd-core|check_gsd_core|install_gsd_core|1|src_root_gsd_core|"
  "claude-mem|check_claude_mem|install_claude_mem|1|src_root_claude_mem|"
  "ocr|check_ocr|install_ocr|1|src_root_ocr|@alibaba-group/open-code-review"
  "graphify|check_graphify|install_graphify|1||"
  "superpowers|check_superpowers||0||"
  "gstack|check_gstack||0||"
  "ruflo|check_ruflo|install_ruflo|1||ruflo"
  "ECC|check_ecc||0||"
)

# 无法 bash 自动安装项目的人工安装提示（按 name 查，集中于一处）
install_hint() {
  case "$1" in
    superpowers)
      echo "    在 Claude Code 中运行: /plugin install superpowers@claude-plugins-official"
      echo "    或: /plugin marketplace add obra/superpowers-marketplace && /plugin install superpowers"
      ;;
    gstack)
      echo "    git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack"
      echo "    cd ~/.claude/skills/gstack && ./setup"
      ;;
    ECC)
      echo "    在 Claude Code 中运行:"
      echo "    /plugin marketplace add https://github.com/affaan-m/ECC"
      echo "    /plugin install ecc"
      ;;
    *) echo "    （无人工安装指引，请查阅项目文档）" ;;
  esac
}

CHECK_ONLY=0
SINGLE=""
FORCE_LATEST=1   # 默认拉最新版
USE_NPM_ONLY=0   # --npm 时跳过 research 源码

# 循环解析全部参数（原只解析 $1，组合参数被静默忽略）
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only) CHECK_ONLY=1; FORCE_LATEST=0; shift ;;
    --install) SINGLE="${2:-}"; shift; [[ $# -gt 0 ]] && shift ;;
    --latest) FORCE_LATEST=1; shift ;;
    --npm) USE_NPM_ONLY=1; shift ;;
    *) echo "✗ 未知参数: $1"; echo "用法: bash self-check.sh [--check-only] [--install <name>] [--latest] [--npm]"; exit 1 ;;
  esac
done

echo "=========================================="
echo "  swarm-yuan 自检：11 个项目运行时"
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
    IFS='|' read -r name chk inst auto srcf npmpkg <<< "$p"
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
  avail=""
  for p in "${PROJECTS[@]}"; do IFS='|' read -r name _ <<< "$p"; avail="$avail $name"; done
  echo "  可用:$avail"
  exit 1
fi

# 检测全部（MISSING 条目携带 check 函数，供安装后复查直接调用）
echo "=== 检测 ==="
MISSING=()
for p in "${PROJECTS[@]}"; do
  IFS='|' read -r name chk inst auto srcf npmpkg <<< "$p"
  if "$chk" 2>/dev/null; then
    :
  else
    MISSING+=("$name|$chk|$inst|$auto")
  fi
done

echo ""
if [[ ${#MISSING[@]} -eq 0 ]]; then
  echo "✓ 全部 11 个项目运行时已安装"
fi

# 即便全部已装，若启用 --latest 则升级到最新版
if [[ $FORCE_LATEST -eq 1 && $CHECK_ONLY -eq 0 ]]; then
  echo ""
  echo "=== 升级到最新版 ==="
  if [[ -n "$RESEARCH_DIR" && -d "$RESEARCH_DIR" && $USE_NPM_ONLY -eq 0 ]]; then
    # research 源码模式（表驱动）：有源码根的项目 git pull + rebuild + re-link；
    # 无源码根但有 npm 包的项目（如 ruflo）走 npm 版本比对
    for p in "${PROJECTS[@]}"; do
      IFS='|' read -r name chk inst auto srcf npmpkg <<< "$p"
      [[ "$name" == "graphify" ]] && continue   # python 项目，下面单独处理
      if [[ -n "$srcf" ]]; then
        upgrade_from_source "$name" "$("$srcf")"
      elif [[ -n "$npmpkg" ]]; then
        upgrade_npm_pkg "$npmpkg" "$name"
      fi
    done
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
    # npm 模式（表驱动）：比对 npm view version 升级
    for p in "${PROJECTS[@]}"; do
      IFS='|' read -r name chk inst auto srcf npmpkg <<< "$p"
      [[ -n "$npmpkg" ]] || continue
      upgrade_npm_pkg "$npmpkg" "$name"
    done
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
  IFS='|' read -r name chk inst auto <<< "$m"
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
  IFS='|' read -r name chk inst auto <<< "$m"
  if [[ "$auto" == "1" && -n "$inst" ]]; then
    echo "--- $name ---"
    "$inst"
    echo ""
  else
    warn "$name 无法 bash 自动安装："
    install_hint "$name"
    echo ""
  fi
done

echo "=== 安装后复查 ==="
# 复查重算 FAIL：初检 miss 置位不代表终态——自动安装成功且复查 pass 的项目不算失败，
# 只有复查仍 miss（含需手动安装的）才保持 FAIL=1。
FAIL=0
for m in "${MISSING[@]}"; do
  IFS='|' read -r name chk inst auto <<< "$m"
  "$chk"
done

echo ""
# ===== 框架规则库时效检查 =====
fw_freshness_check() {
  local fw_dir; fw_dir="$(cd "$(dirname "$0")/.." && pwd)/references/frameworks"
  # 存在性守卫：生成的目标 skill 不含 references/frameworks/（generate-skill.sh 不复制），
  # 无目录时 glob 不展开会打印垃圾告警（"⚠ *.md 缺'最后调研'日期"），直接跳过。
  [[ -d "$fw_dir" ]] || return 0
  echo "▶ 框架规则库时效检查"
  local now d ts age f id
  now=$(date -u +%s)
  for f in "$fw_dir"/*.md; do
    [[ -f "$f" ]] || continue
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
