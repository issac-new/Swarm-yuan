#!/usr/bin/env bash
# self-check.sh — swarm-yuan 运行前自检：11 个项目运行时是否已安装，未装则自动安装最新版
#
# 安装策略（三类）：
#   1. npm 全局包（@latest）：npm i -g <pkg>@latest  或  npx -y <pkg>@latest <args>
#      · openspec / comet / gitnexus / gsd-core / claude-mem / ocr / ruflo
#   2. python 工具：uv tool install → pipx install → pip install 降级
#      · graphify
#   3. GitHub Release 源码包：下载 <name>-src.zip → 解压到目标目录 → ./setup
#      · gstack / superpowers / ECC（无法走包管理器的运行时）
#
# 用法:
#   bash self-check.sh                  # 检测 + 自动安装/升级到最新版
#   bash self-check.sh --check-only     # 仅检测不安装
#   bash self-check.sh --install <name> # 仅装指定项目（最新版）
#   bash self-check.sh --latest         # 已装的也升级到最新版
#
# 环境变量:
#   SRC_RELEASE_TAG   源码包 Release tag（默认 v<当天YYYYMMDD>-src，可覆盖）

# 注意：set -u 与管道中 read 配合时需谨慎；这里不用 set -e 以便单个失败不中断整体
set -uo pipefail
FAIL=0
pass(){ echo "  ✓ $1"; }
miss(){ echo "  ✗ $1 未安装"; FAIL=1; return 1; }
warn(){ echo "  ⚠ $1"; }

# ---------- 源码包 Release 配置 ----------
SRC_RELEASE_REPO="issac-new/Swarm-yuan"
SRC_RELEASE_TAG="${SRC_RELEASE_TAG:-v$(date -u +%Y%m%d)-src}"

# ---------- 工具检测 ----------
has_cmd(){ command -v "$1" &>/dev/null; }

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
  # 实质检测（R5 实证）：目录存在 ≠ 已安装。离线包曾只 vendor superpowers-marketplace
  # 目录仓（LICENSE/README/.claude-plugin/marketplace.json 等市场元数据），核心插件
  # v6.1.1 本体不在包内。须含核心插件证据——skills/ 子目录或 .claude-plugin/plugin.json
  # ——才视为已安装；仅 marketplace 元数据判空壳 miss（fail-closed）。
  local d
  for d in ~/.claude/plugins/superpowers ~/.claude/skills/superpowers; do
    [[ -d "$d" ]] || continue
    if [[ -d "$d/skills" || -f "$d/.claude-plugin/plugin.json" ]]; then
      pass "superpowers: 已安装（核心插件证据齐备）"; return 0
    fi
    miss "superpowers（空壳：marketplace 元数据非核心插件，需在线 /plugin install）"; return 1
  done
  miss "superpowers（需 /plugin install）"
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

# ---------- 通用：从 GitHub Release 源码包安装 ----------
# 参数: <项目名> <zip名> <目标目录> [可选 setup 命令]
# 流程: curl 下载 Release <tag>/<zip> → 解压 → cp 到 <目标目录> → 跑 setup
# 失败: 下载/解压失败 return 1（调用方计入 FAIL）；setup 失败 warn 不 return 1（文件已就位）
install_from_src_release(){
  local name="$1" zip="$2" dest="$3" setup="${4:-}"
  local url="https://github.com/${SRC_RELEASE_REPO}/releases/download/${SRC_RELEASE_TAG}/${zip}"
  local tmp; tmp="$(mktemp -d)"
  echo "  → [$name] 下载源码包: $url"
  if ! (cd "$tmp" && curl -fsSL -o "$zip" "$url"); then
    echo "  ✗ $name 源码包下载失败: $url"
    echo "    手工下载: 浏览器打开 $url，或确认 Release tag $SRC_RELEASE_TAG 存在"
    rm -rf "$tmp"; return 1
  fi
  if ! (cd "$tmp" && unzip -q "$zip" -d extracted); then
    echo "  ✗ $name 源码包解压失败"; rm -rf "$tmp"; return 1
  fi
  # zip 内为单层目录，取其内容；无单层目录则直接取 extracted/
  local inner; inner="$(find "$tmp/extracted" -mindepth 1 -maxdepth 1 -type d | head -1)"
  local src="${inner:-$tmp/extracted}"
  mkdir -p "$dest"
  cp -R "$src"/. "$dest/" 2>/dev/null || cp -R "$src"/* "$dest/" 2>/dev/null
  rm -rf "$dest/.git" 2>/dev/null || true
  rm -rf "$tmp"
  if [[ -n "$setup" ]]; then
    echo "  → [$name] 运行 setup: $setup"
    (cd "$dest" && eval "$setup") 2>&1 | tail -4 || warn "$name setup 失败（文件已就位，请手动检查）"
  fi
  echo "  ✓ $name 源码包安装完成: $dest"
}

# ---------- 安装函数（三类：npm / python / 源码包）----------
install_openspec(){
  echo "  → npm i -g @fission-ai/openspec@latest"; npm i -g @fission-ai/openspec@latest 2>&1|tail -2
}
install_comet(){
  echo "  → npm i -g @rpamis/comet@latest"; npm i -g @rpamis/comet@latest 2>&1|tail -2
}
install_gitnexus(){
  echo "  → npm i -g gitnexus@latest"; npm i -g gitnexus@latest 2>&1|tail -2
}
install_gsd_core(){
  # gsd-core 是运行时 artifact 安装器：npx 调用写入 ~/.claude 运行时 artifacts
  echo "  → npx -y @opengsd/gsd-core@latest --claude --global（写入运行时 artifacts）"
  npx -y @opengsd/gsd-core@latest --claude --global 2>&1 | tail -4
}
install_claude_mem(){
  echo "  → npx -y claude-mem@latest install"; npx -y claude-mem@latest install 2>&1|tail -4
}
install_ocr(){
  # ocr 的 postinstall 下载平台二进制，npm i -g @latest 最稳
  echo "  → npm i -g @alibaba-group/open-code-review@latest"; npm i -g @alibaba-group/open-code-review@latest 2>&1|tail -2
}
install_graphify(){
  # graphify 是 python 项目：uv → pipx → pip 降级
  echo "  → 安装 graphify (uv → pipx → pip)"
  if command -v uv &>/dev/null; then
    uv tool install graphifyy 2>&1|tail -3
    uv tool update-shell 2>/dev/null || true
  elif command -v pipx &>/dev/null; then
    pipx install graphifyy 2>&1|tail -3
  elif command -v pip3 &>/dev/null || command -v pip &>/dev/null; then
    local pipcmd; command -v pip3 &>/dev/null && pipcmd=pip3 || pipcmd=pip
    $pipcmd install --user graphifyy 2>&1|tail -3
    echo "  ℹ pip 安装的用户级 bin 须在 PATH（通常 ~/.local/bin 或 ~/Library/Python/*/bin）"
  else
    echo "  ✗ 需先安装 uv (curl -LsSf https://astral.sh/uv/install.sh | sh) 或 pipx 或 pip"
    return 1
  fi
}
install_ruflo(){
  echo "  → npm i -g ruflo@latest"; npm i -g ruflo@latest 2>&1|tail -2
}
install_gstack(){
  install_from_src_release "gstack" "gstack-src.zip" "$HOME/.claude/skills/gstack" "./setup" || return 1
}
install_superpowers(){
  # 安装目标优先 plugins/（与 check_superpowers L81 检测路径一致）
  install_from_src_release "superpowers" "superpowers-src.zip" "$HOME/.claude/plugins/superpowers" "" || return 1
}
install_ecc(){
  install_from_src_release "ECC" "ecc-src.zip" "$HOME/.claude/plugins/ecc" "" || return 1
}

# 升级已安装的 npm 包到最新版（静默，仅在有新版本时输出）
upgrade_npm_pkg(){
  local pkg="$1" bin="$2"
  command -v "$bin" &>/dev/null || return 0
  local cur latest
  cur=$("$bin" --version 2>/dev/null | head -1 | tr -d '[:space:]')
  cur="${cur#v}"
  [[ -z "$cur" ]] && return 0
  latest=$(npm view "$pkg" version 2>/dev/null | head -1 | tr -d '[:space:]')
  latest="${latest#v}"
  [[ -z "$latest" ]] && return 0
  if [[ "$cur" != "$latest" ]]; then
    echo "  ↻ 升级 $pkg: $cur → $latest"
    npm i -g "${pkg}@latest" 2>&1 | tail -1
  fi
}

# 升级源码包类（重下 Release 覆盖安装）
upgrade_src_pkg(){
  local name="$1" zip="$2" dest="$3" setup="${4:-}"
  [[ -d "$dest" ]] || return 0
  echo "  ↻ [$name] 重装源码包到最新"
  install_from_src_release "$name" "$zip" "$dest" "$setup"
}

# 11 个项目定义（唯一数据源，检测/安装/升级/复查全部从此表驱动）：
#   name|check_func|install_func|auto_installable|npm_pkg
#   npm_pkg：npm 全局包名（--latest npm 模式比对 version 用）；空=非 npm 包（python/源码包）
# 注：self-check 生成的 hooks.json PreToolUse 命令须发射 Claude Code 和 Cursor 都接受的
#   {"permission":"allow"} verdict（参考 ruflo v3.25.6 #2613 修复）
# 注：若目标技能注册 MCP，须检测重复注册（同一 binary 注册 claude-flow + ruflo 两个 key）
#   并通过 ruflo doctor 自愈——canonical MCP key 保留一个（参考 ruflo v3.25.6 #2612 修复）
# 注：hooks.json 须无 BOM（UTF-8 无 BOM），否则 Codex 严格 JSON 解析失败（参考 ruflo v3.32.1 修复）
PROJECTS=(
  "openspec|check_openspec|install_openspec|1|@fission-ai/openspec"
  "comet|check_comet|install_comet|1|@rpamis/comet"
  "gitnexus|check_gitnexus|install_gitnexus|1|gitnexus"
  "gsd-core|check_gsd_core|install_gsd_core|1|"
  "claude-mem|check_claude_mem|install_claude_mem|1|"
  "ocr|check_ocr|install_ocr|1|@alibaba-group/open-code-review"
  "graphify|check_graphify|install_graphify|1|"
  "superpowers|check_superpowers|install_superpowers|1|"
  "gstack|check_gstack|install_gstack|1|"
  "ruflo|check_ruflo|install_ruflo|1|ruflo"
  "ECC|check_ecc|install_ecc|1|"
)

# 自动安装失败时的人工安装提示（按 name 查，集中于一处）
install_hint() {
  case "$1" in
    superpowers)
      echo "    自动安装失败。手工：从 Release $SRC_RELEASE_TAG 下载 superpowers-src.zip"
      echo "    解压到 ~/.claude/plugins/superpowers（须含 skills/ 或 .claude-plugin/plugin.json）"
      ;;
    gstack)
      echo "    自动安装失败。手工：从 Release $SRC_RELEASE_TAG 下载 gstack-src.zip"
      echo "    解压到 ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup"
      ;;
    ECC)
      echo "    自动安装失败。手工：从 Release $SRC_RELEASE_TAG 下载 ecc-src.zip"
      echo "    解压到 ~/.claude/plugins/ecc"
      ;;
    graphify)
      echo "    需先安装 uv (curl -LsSf https://astral.sh/uv/install.sh | sh) 或 pipx 或 pip"
      ;;
    *) echo "    （无人工安装指引，请查阅项目文档）" ;;
  esac
}

CHECK_ONLY=0
SINGLE=""
FORCE_LATEST=1   # 默认拉最新版

# 循环解析全部参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only) CHECK_ONLY=1; FORCE_LATEST=0; shift ;;
    --install) SINGLE="${2:-}"; shift; [[ $# -gt 0 ]] && shift ;;
    --latest) FORCE_LATEST=1; shift ;;
    *) echo "✗ 未知参数: $1"; echo "用法: bash self-check.sh [--check-only] [--install <name>] [--latest]"; exit 1 ;;
  esac
done

echo "=========================================="
echo "  swarm-yuan 自检：11 个项目运行时"
if [[ $FORCE_LATEST -eq 1 ]]; then
  echo "  （自动安装/升级到最新版 已启用）"
else
  echo "  （仅检测，不安装/升级）"
fi
echo "  源码包 Release: $SRC_RELEASE_TAG"
echo "=========================================="
echo ""

if [[ -n "$SINGLE" ]]; then
  # 仅安装单个
  for p in "${PROJECTS[@]}"; do
    IFS='|' read -r name chk inst auto npmpkg <<< "$p"
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
  IFS='|' read -r name chk inst auto npmpkg <<< "$p"
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
# 运行时接线分层标注（WP1.4）：让用户清楚每个运行时的真实接线程度，不假装全深接
echo "  接线分层："
echo "    深度接线(4,precheck.sh 真实命令调用)：gitnexus / graphify / claude-mem / ocr"
echo "    CLI 接线(3,门禁/状态机按需调用 CLI)：openspec / comet / gsd-core"
echo "    方法论引用(4,AI 按节点引用模式)：superpowers / gstack / ruflo / ECC"
echo "  （每层有自带降级载体，未装不阻塞——详见 SKILL.md「它整合的方法论」分层表）"

# 即便全部已装，若启用 --latest 则升级到最新版
if [[ $FORCE_LATEST -eq 1 && $CHECK_ONLY -eq 0 ]]; then
  echo ""
  echo "=== 升级到最新版 ==="
  for p in "${PROJECTS[@]}"; do
    IFS='|' read -r name chk inst auto npmpkg <<< "$p"
    case "$name" in
      openspec|comet|gitnexus|ocr|ruflo)
        [[ -n "$npmpkg" ]] && upgrade_npm_pkg "$npmpkg" "$name" ;;
      gsd-core)
        echo "  ↻ [gsd-core] npx 拉最新运行时 artifacts"
        npx -y @opengsd/gsd-core@latest --claude --global 2>&1 | tail -3 || true ;;
      claude-mem)
        echo "  ↻ [claude-mem] npx 拉最新"
        npx -y claude-mem@latest install 2>&1 | tail -3 || true ;;
      graphify)
        if [[ -d "$HOME/.local/share/uv/tools/graphifyy" ]] || command -v graphify &>/dev/null; then
          echo "  ↻ [graphify] uv tool reinstall"
          command -v uv &>/dev/null && uv tool install --force graphifyy 2>&1 | tail -2 || true
        fi ;;
      gstack)
        upgrade_src_pkg "gstack" "gstack-src.zip" "$HOME/.claude/skills/gstack" "./setup" ;;
      superpowers)
        upgrade_src_pkg "superpowers" "superpowers-src.zip" "$HOME/.claude/plugins/superpowers" "" ;;
      ECC)
        upgrade_src_pkg "ECC" "ecc-src.zip" "$HOME/.claude/plugins/ecc" "" ;;
    esac
  done
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
  echo "（--check-only 模式，不自动安装；继续执行本地检查段：文档一致性 / 框架规则集核验 / 上游基线）"
  # 历史缺陷修复（2026-07-21）：原此处直接 `exit 1`，导致后续纯本地的
  # 文档一致性 / 框架规则集核验 / 上游基线检查段在 --check-only（CLAUDE.md/README
  # 推荐的人工检测命令）下永不执行——号称的"自举文档一致性门禁"在自己推荐的
  # 检测模式下是死的。改为跳过自动安装段，继续跑本地检查段，末尾统一 exit $FAIL。
  # 运行时缺失的 FAIL=1 已在 miss() 置位，不会丢失。
else
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
fi  # end of `if CHECK_ONLY -eq 1`

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
      warn "$(basename "$f") 调研于 ${d}（${age} 天前 >365 天），建议重新核实版本区间"
    elif [[ "$age" -gt 180 ]]; then
      warn "$(basename "$f") 调研于 ${d}（${age} 天前 >180 天），建议关注版本变化"
    fi
  done
}
fw_freshness_check

# ===== 框架规则集核验（61 规则集四要素机械核验）=====
fw_ruleset_verify() {
  local base; base="$(cd "$(dirname "$0")/.." && pwd)"
  local vfy="$base/scripts/verify-framework-ruleset.sh"
  # 存在性守卫：生成的目标 skill 不带规则库与核验脚本（generate-skill.sh 不复制），静默跳过
  [[ -f "$vfy" && -d "$base/references/frameworks" ]] || return 0
  echo "▶ 框架规则集核验"
  local f id ok_cnt=0 fail_cnt=0 fail_ids=""
  for f in "$base/references/frameworks/"*.md; do
    [[ -f "$f" ]] || continue
    id=$(basename "$f" .md)
    [[ "$id" == "_template" ]] && continue
    # 逐 id 调四要素核验（与本脚本同目录），聚合计数不逐条刷屏
    if bash "$vfy" "$id" >/dev/null 2>&1; then
      ok_cnt=$((ok_cnt + 1))
    else
      fail_cnt=$((fail_cnt + 1))
      fail_ids="$fail_ids $id"
    fi
  done
  if [[ $fail_cnt -eq 0 ]]; then
    echo "  ✓ 框架规则集核验全部通过（$ok_cnt/$((ok_cnt + fail_cnt))）"
  else
    warn "框架规则集核验未通过 $fail_cnt/$((ok_cnt + fail_cnt)) 个:${fail_ids}（bash scripts/verify-framework-ruleset.sh <id> 查看详情）"
    FAIL=1
  fi
}
fw_ruleset_verify

# ===== 文档一致性检查（防文档-实现漂移）=====
# 从 shell 文件机械解析数组赋值的元素个数（支持跨行数组；数组未定义时输出 0）
_count_gate_array() {
  awk -v name="$1" '
    $0 ~ "^" name "=\\(" { inarr=1 }
    inarr {
      line=$0
      sub(/^[^(]*\(/, "", line)
      if (index(line, ")") > 0) { sub(/\).*/, "", line); done=1 }
      n=split(line, a, /[ \t]+/)
      for (i=1; i<=n; i++) if (a[i] != "") cnt++
      if (done) exit
    }
    END { print cnt+0 }
  ' "$2" 2>/dev/null || echo 0
}

# WP-Q1.3：拆分后 check_* 函数在 gates-strict/warn/advisory.sh 三文件，不在 precheck.sh 主文件。
# 所有"数 check_* 函数"的 grep 须扫四文件（precheck.sh + gates-*.sh）。
# 打包态（install.sh bundle）下三文件已内联回 precheck.sh，gates-*.sh 不存在，此时只扫 precheck.sh。
_all_gate_files() {
  local base="$1" f
  printf '%s\n' "$base/assets/precheck.sh"
  for f in gates-strict.sh gates-warn.sh gates-advisory.sh; do
    [[ -f "$base/assets/$f" ]] && printf '%s\n' "$base/assets/$f"
  done
}
_count_check_fns() {
  local base="$1"
  _all_gate_files "$base" | xargs grep -hcE '^check_[a-z_]+\(\)' 2>/dev/null | awk '{s+=$1} END{print s+0}'
}

check_doc_consistency() {
  echo "▶ 文档一致性检查"
  local base; base="$(cd "$(dirname "$0")/.." && pwd)"

  # WP-P1：source facts.conf（catchphrase 单一事实源）。
  # facts.conf 是文档口径的权威源；本函数先用代码真值对账 facts.conf 自身是否漂移，
  # 再用 ${FACT_*} 值扫描散文文档（文档口径 → facts.conf → 代码真值，单向传递）。
  # 注意：目标 skill 是 swarm-yuan 生成的"子 skill"（如 .claude/skills/<proj>-dev/），
  # 其 precheck.sh 拷贝自 swarm-yuan 但 ACTIVE_FRAMEWORKS/conf 文件已被项目定制，
  # GATES_TOTAL/CONF_VARS 等口径与 swarm-yuan 声明的 facts.conf 不同——此时跳过对账。
  # 仅当本 skill 自身的真值与 facts.conf 声明同量级时才对账（即 swarm-yuan 自身或未定制的副本）。
  local facts_conf="$base/assets/facts.conf"
  if [[ -f "$facts_conf" ]]; then
    set +u; # shellcheck disable=SC1090
    source "$facts_conf"; set -u
  fi

  # 1. 框架规则文件数 == 门禁片段数（真值机械计数，当前 61 == 61）
  local rule_cnt gate_cnt
  rule_cnt=$(ls "$base/references/frameworks/"*.md 2>/dev/null | grep -v _template | wc -l | xargs)
  gate_cnt=$(ls "$base/assets/framework-gates/"*.sh 2>/dev/null | wc -l | xargs)
  if [[ "$rule_cnt" == "$gate_cnt" ]]; then
    echo "  ✓ 框架规则文件数($rule_cnt) == 门禁片段数($gate_cnt)"
  else
    warn "框架规则文件数($rule_cnt) != 门禁片段数($gate_cnt)——孤立片段或缺片段"
    FAIL=1
  fi
  # 1.5 precheck.sh 实际位置（scripts/ 或 assets/，按 UNIVERSAL_FILES 历史）
  local precheck_sh="$base/scripts/precheck.sh"
  [[ -f "$precheck_sh" ]] || precheck_sh="$base/assets/precheck.sh"
  # 2. SKILL.md 声明的门禁数 vs precheck.sh 实际 check_* 函数数（口径可能不同，仅 warn 提示）
  local skill_gates declared_gates actual_gates
  declared_gates=$(grep -oE "[0-9]+ ?个?质量门禁|[0-9]+ ?quality gates" "$base/SKILL.md" 2>/dev/null | head -1 | grep -oE "[0-9]+" || echo "?")
  actual_gates=$(_count_check_fns "$base")
  echo "  ℹ SKILL.md 声明 $declared_gates 门禁，precheck.sh+gates-*.sh check_* 函数 $actual_gates 个（差额为子门禁/聚合门禁，人工确认）"
  # 3. SKILL.md 声明的 conf 变量数 vs precheck.conf 实际变量数
  #    修复(2026-07-20)：交替须用 ERE 标准 `|`——grep -E 下 `\|` 按字面管道解析、永不命中，
  #    导致 declared_vars 恒为空而误报文档漂移（docs/paradigm-decisions.md 记录的 `\|` 字面 bug 家族又一例）。
  local declared_vars actual_vars
  declared_vars=$(grep -oE "precheck\.conf[^。]*([0-9]+) ?变量|([0-9]+) ?变量" "$base/SKILL.md" 2>/dev/null | grep -oE "[0-9]+" | head -1 || echo "?")
  actual_vars=$(cat "$base/scripts/precheck.conf" "$base/scripts/precheck.arch.conf" "$base/scripts/precheck.compliance.conf" "$base/assets/precheck.conf" "$base/assets/precheck.arch.conf" "$base/assets/precheck.compliance.conf" 2>/dev/null | grep -cE '^[A-Z_][A-Z0-9_]*=' | xargs)  # WP-I：三文件合计（scripts/ + assets/ 双路径兜底）
  if [[ "$declared_vars" != "?" && "$declared_vars" != "$actual_vars" ]]; then
    warn "SKILL.md 声明 precheck.conf $declared_vars 变量，实际 $actual_vars 个——文档漂移，请更新 SKILL.md"
    FAIL=1
  else
    echo "  ✓ conf 变量数一致($actual_vars)"
  fi
  # 4. references/ 文件数 vs SKILL.md 声明数（粗略）
  local ref_cnt declared_refs
  ref_cnt=$(ls "$base/references/"*.md 2>/dev/null | wc -l | xargs)
  echo "  ℹ references/*.md 共 $ref_cnt 个（SKILL.md 表格行数人工确认）"

  # 5. 头部数字跨文档一致性（特征卡 / 门禁 / 架构门禁 / 合规门禁 / conf 变量 / references 数）。
  #    历史漂移：USAGE.md/PROMO.md 曾长期停留在 14特征/25门禁/45变量/架构15，
  #    与代码实际不符——故此处从代码计算真值并扫描全部散文文档（真值随代码演进：
  #    门禁 27→31、conf 146→162、references 13→14，均机械解析，不写死）。
  #    口径注意：门禁总数按「N 个质量门禁 / N 个门禁」匹配，避免误伤「核心 10」等子计数；
  #    conf 变量按「N 个(配置|门禁)?变量」匹配，避免把「146 个门禁」误判为变量数。
  local true_gates true_vars true_fw
  # 门禁函数含下划线（stable_diff/shift_left/...），须用 [a-z_]+ 计数，否则漏数（23≠27）
  true_gates=$(_count_check_fns "$base")
  # 架构/合规门禁数真值：从 precheck.sh 注册表数组机械解析——架构=FULL−CORE−COMPLIANCE。
  # 合规族未合入时 ALL_GATES_COMPLIANCE 未定义，按 0 计（向后兼容旧版 precheck.sh）。
  local true_core true_compliance true_full
  true_core=$(_count_gate_array ALL_GATES_CORE "$precheck_sh")
  true_compliance=$(_count_gate_array ALL_GATES_COMPLIANCE "$precheck_sh")
  true_full=$(_count_gate_array ALL_GATES_FULL "$precheck_sh")
  local true_arch=$((true_full - true_core - true_compliance))
  true_vars=$(cat "$base/scripts/precheck.conf" "$base/scripts/precheck.arch.conf" "$base/scripts/precheck.compliance.conf" "$base/assets/precheck.conf" "$base/assets/precheck.arch.conf" "$base/assets/precheck.compliance.conf" 2>/dev/null | grep -cE '^[A-Z_][A-Z0-9_]*=' | xargs)  # WP-I：三文件合计（scripts/ + assets/ 双路径兜底）
  true_fw=$(ls "$base/references/frameworks/"*.md 2>/dev/null | grep -v _template | wc -l | xargs)

  # WP-P1：facts.conf 自身一致性对账（代码真值 vs 声明真值）。
  # 如果 facts.conf 自身漂移，文档扫描结果不可信——先 fail-soft 报告 facts.conf 漂移，
  # 然后仍用代码真值做文档扫描（不阻塞）。
  # 边界：目标 skill（swarm-yuan 生成的 .claude/skills/<proj>-dev/）拷贝了 facts.conf
  # 但其 precheck.sh/conf 已按项目定制（ACTIVE_FRAMEWORKS/conf 文件被改），GATES_TOTAL
  # 等口径与 facts.conf 声明不同——此时跳过对账（仅 swarm-yuan 自身对账）。
  # 启发式：真值 ≥ 声明 × 0.5 且 ≠ 0 才对账（目标 skill 的真值常为 0 或远小于声明）。
  if [[ -n "${FACT_GATES_TOTAL:-}" && "$true_gates" -ge $((FACT_GATES_TOTAL / 2)) && "$true_gates" -gt 0 ]]; then
    local facts_drift=""
    [[ "${FACT_GATES_TOTAL:-0}" != "$true_gates" ]] && facts_drift="${facts_drift} GATES_TOTAL(声明=${FACT_GATES_TOTAL}/真值=${true_gates});"
    [[ "${FACT_GATES_CORE:-0}" != "$true_core" ]] && facts_drift="${facts_drift} GATES_CORE(声明=${FACT_GATES_CORE}/真值=${true_core});"
    [[ "${FACT_GATES_COMPLIANCE:-0}" != "$true_compliance" ]] && facts_drift="${facts_drift} GATES_COMPLIANCE(声明=${FACT_GATES_COMPLIANCE}/真值=${true_compliance});"
    [[ "${FACT_GATES_ARCH:-0}" != "$true_arch" ]] && facts_drift="${facts_drift} GATES_ARCH(声明=${FACT_GATES_ARCH}/真值=${true_arch});"
    [[ "${FACT_CONF_VARS:-0}" != "$true_vars" ]] && facts_drift="${facts_drift} CONF_VARS(声明=${FACT_CONF_VARS}/真值=${true_vars});"
    [[ "${FACT_FRAMEWORKS:-0}" != "$true_fw" ]] && facts_drift="${facts_drift} FRAMEWORKS(声明=${FACT_FRAMEWORKS}/真值=${true_fw});"
    [[ "${FACT_REFERENCES:-0}" != "$ref_cnt" ]] && facts_drift="${facts_drift} REFERENCES(声明=${FACT_REFERENCES}/真值=${ref_cnt});"
    if [[ -n "$facts_drift" ]]; then
      warn "facts.conf 与代码真值漂移（请先同步 facts.conf）：${facts_drift}"
      FAIL=1
    else
      echo "  ✓ facts.conf 与代码真值一致（权威断言通过）"
    fi
  fi

  # G1：决策治理口径存在性断言（FACT_DECISION_TYPES/LOG/ELEMENTS + decision-governance.md）
  if [[ -n "${FACT_DECISION_TYPES:-}" ]]; then
    [[ -f "$base/references/decision-governance.md" ]] || { warn "decision-governance.md 缺失（G1 决策治理）"; FAIL=1; }
    grep -q 'Mechanical' "$base/references/decision-governance.md" 2>/dev/null && \
    grep -q 'UserChallenge' "$base/references/decision-governance.md" 2>/dev/null || \
      { warn "decision-governance.md 缺决策分类（Mechanical/UserChallenge）"; FAIL=1; }
    echo "  ✓ 决策治理口径（${FACT_DECISION_TYPES} 类 + ${FACT_DECISION_LOG:-decisions.jsonl}）"
  fi
  local doc dfound bad docpath
  # 根 CLAUDE.md（仓库根，$base 的上一层）是 AI 进入仓库首读文件，必须纳入一致性扫描；
  # 安装到 ~/.claude/skills/<skill>/ 后该文件不存在，[[ -f ]] 守卫自动跳过。
  # 注意：$doc 可能是相对路径（拼 $base/）或绝对路径（$root_claude），用 case 区分。
  local root_claude="$base/../CLAUDE.md"
  for doc in README.md docs/USAGE.md docs/PROMO.md .claude/commands/swarm-yuan.md "$root_claude"; do
    case "$doc" in
      /*) docpath="$doc" ;;
      *)  docpath="$base/$doc" ;;
    esac
    [[ -f "$docpath" ]] || continue
    dfound=""
    local docname; docname="$(basename "$docpath")"
    # 门禁总数：仅匹配「N 个质量门禁」（带「质量」前缀，是总数的固定表述），不匹配
    # 「核心 10」「架构 17」「146 个门禁(变量驱动)」等子计数/指代，避免误伤。
    bad=$(grep -oE "[0-9]+ ?个质量门禁" "$docpath" 2>/dev/null \
          | grep -oE "[0-9]+" | sort -u | grep -vx "$true_gates" || true)
    [[ -n "$bad" ]] && dfound="${dfound} 门禁数出现非${true_gates}值($(echo $bad | tr '\n' ' '));"
    # 架构门禁数：「架构 17」「架构门禁额外 17 个」「（核心 10 + 架构 17）」等。
    bad=$(grep -oE "架构门禁[^0-9]{0,8}[0-9]+ ?个|架构 [0-9]+" "$docpath" 2>/dev/null \
          | grep -oE "[0-9]+" | sort -u | grep -vx "$true_arch" || true)
    [[ -n "$bad" ]] && dfound="${dfound} 架构门禁数出现非${true_arch}值($(echo $bad | tr '\n' ' '));"
    # conf 变量数：「N 个变量」「N 个配置变量」「N 个门禁变量」
    bad=$(grep -oE "[0-9]+ ?个(配置|门禁)?变量" "$docpath" 2>/dev/null \
          | grep -oE "[0-9]+" | sort -u | grep -vx "$true_vars" || true)
    [[ -n "$bad" ]] && dfound="${dfound} conf变量数出现非${true_vars}值($(echo $bad | tr '\n' ' '));"
    # 合规门禁数：「合规 4」「合规门禁额外 4 个」等（真值为 0 即合规族未合入，跳过该口径）
    if [[ "$true_compliance" -gt 0 ]]; then
      bad=$(grep -oE "合规门禁[^0-9]{0,8}[0-9]+ ?个|合规 [0-9]+" "$docpath" 2>/dev/null \
            | grep -oE "[0-9]+" | sort -u | grep -vx "$true_compliance" || true)
      [[ -n "$bad" ]] && dfound="${dfound} 合规门禁数出现非${true_compliance}值($(echo $bad | tr '\n' ' '));"
    fi
    # references 参考文档数：「N 个参考文档」（真值=references/*.md 实际计数，不含 frameworks/ 子目录）
    bad=$(grep -oE "[0-9]+ ?个参考文档" "$docpath" 2>/dev/null \
          | grep -oE "[0-9]+" | sort -u | grep -vx "$ref_cnt" || true)
    [[ -n "$bad" ]] && dfound="${dfound} references数出现非${ref_cnt}值($(echo $bad | tr '\n' ' '));"
    if [[ -n "$dfound" ]]; then
      warn "$docname 头部数字与代码真值不符（真值: 门禁${true_gates}/架构${true_arch}/合规${true_compliance}/conf${true_vars}/refs${ref_cnt}）：${dfound}"
      FAIL=1
    else
      echo "  ✓ $docname 头部数字一致（门禁${true_gates}/架构${true_arch}/合规${true_compliance}/conf${true_vars}/refs${ref_cnt}）"
    fi
  done
  # 6. 框架信号索引时效：regen 后比对是否漂移（提示运行 gen-framework-index.sh）
  if [[ -x "$base/scripts/gen-framework-index.sh" || -f "$base/scripts/gen-framework-index.sh" ]]; then
    local guide_tmp; guide_tmp="$(mktemp /tmp/egcheck.XXXXXX)"
    cp "$base/references/exploration-guide.md" "$guide_tmp"
    if bash "$base/scripts/gen-framework-index.sh" >/dev/null 2>&1; then
      if ! diff -q "$guide_tmp" "$base/references/exploration-guide.md" >/dev/null 2>&1; then
        # regen 已就地修正（幂等），提示但不判 fail——索引已被重写为最新
        echo "  ⚠ framework-signal-index 已漂移，本次由 gen-framework-index.sh 自动重写为最新（建议提交）"
      else
        echo "  ✓ framework-signal-index 与 ${true_fw} 框架同步"
      fi
    fi
    rm -f "$guide_tmp"
  fi

  # WP-P4：task-type-gates.conf 一致性断言（7 类任务齐全）
  local ttg="$base/assets/task-type-gates.conf"
  if [[ -f "$ttg" ]]; then
    local tt_types="feature fix refactor chore docs test exp" tt_missing="" tt
    for tt in $tt_types; do
      if ! grep -q "^TASK_TYPE_${tt}=" "$ttg" 2>/dev/null; then
        tt_missing="${tt_missing} ${tt}"
      fi
    done
    if [[ -n "$tt_missing" ]]; then
      warn "task-type-gates.conf 缺失任务类型映射：${tt_missing# }（须补 TASK_TYPE_<type>）"
      FAIL=1
    else
      echo "  ✓ task-type-gates.conf 7 类任务齐全（feature/fix/refactor/chore/docs/test/exp）"
    fi
  fi

  # WP-P6：profile 漂移检测（只升不降，warn 不阻塞）
  local drift_sh="$base/scripts/detect-profile-drift.sh"
  if [[ -f "$drift_sh" ]]; then
    local drift_out
    drift_out=$(bash "$drift_sh" "$base" 2>&1 || true)
    if [[ -n "$drift_out" ]]; then
      echo "  ⚠ profile 漂移检测：${drift_out}"
    else
      echo "  ✓ profile 漂移检测：无漂移"
    fi
  fi

  # 7. WP-Q1 门禁分层一致性（决策 19）：gate-enforce-level.conf 与 precheck.sh 实际 fail() 数一致。
  #    gen-enforce-level.sh 重生成 conf，与现文件 diff——漂移则 warn + FAIL=1（防 fail 数变了 conf 没更新）。
  if [[ -f "$base/scripts/gen-enforce-level.sh" ]]; then
    local gel_tmp; gel_tmp="$(mktemp /tmp/gelcheck.XXXXXX)"
    cp "$base/assets/gate-enforce-level.conf" "$gel_tmp" 2>/dev/null || true
    if bash "$base/scripts/gen-enforce-level.sh" >/dev/null 2>&1; then
      if ! diff -q "$gel_tmp" "$base/assets/gate-enforce-level.conf" >/dev/null 2>&1; then
        warn "gate-enforce-level.conf 与 precheck.sh fail() 数不一致——已由 gen-enforce-level.sh 自动重写为最新（建议提交）"
      else
        local _s _w _a
        _s=$(grep -cE '=strict$' "$base/assets/gate-enforce-level.conf" 2>/dev/null || echo 0)
        _w=$(grep -cE '=warn$' "$base/assets/gate-enforce-level.conf" 2>/dev/null || echo 0)
        _a=$(grep -cE '=advisory$' "$base/assets/gate-enforce-level.conf" 2>/dev/null || echo 0)
        echo "  ✓ 门禁分层一致（strict ${_s} / warn ${_w} / advisory ${_a}）"
      fi
    fi
    rm -f "$gel_tmp"
  fi

  # 8. WP-Q1 strict 门禁必含 fail()（决策 19）：声明 strict 的门禁函数体必须有 ≥1 个 fail() 调用，
  #    防 strict 声明空壳（fail_calls=0 却标 strict）。advisory 必须是 0 fail（否则分类矛盾）。
  if [[ -f "$base/assets/gate-enforce-level.conf" ]]; then
    local _fn _lv _fc _bad=""
    # WP-Q1.3：拆分后 check_* 在 gates-*.sh，须扫四文件统计 fail() 数
    local _gate_files; _gate_files=$(_all_gate_files "$base")
    while IFS='=' read -r _fn _lv; do
      [[ "$_fn" =~ ^check_[a-z_]+$ ]] || continue
      # 用 gen-enforce-level.sh 同款 awk 统计该函数 fail() 数（扫四文件）
      _fc=$(awk -v target="$_fn" '
        /^check_[a-z_]+\(\)/ { in_fn = ($0 ~ "^"target"\\(\\)"); cnt=0; next }
        in_fn && /^\}/ { in_fn=0; print cnt; exit }
        in_fn { s=$0; while (match(s, /(^|[^a-zA-Z0-9_])fail[ \t]+/)) { cnt++; s=substr(s, RSTART+RLENGTH) } }
      ' $_gate_files 2>/dev/null || echo 0)
      case "$_lv" in
        strict) [[ "$_fc" -lt 1 ]] && _bad="${_bad} ${_fn}(strict 但 ${_fc} fail);" ;;
        advisory) [[ "$_fc" -gt 0 ]] && _bad="${_bad} ${_fn}(advisory 但 ${_fc} fail——分类矛盾);" ;;
      esac
    done < "$base/assets/gate-enforce-level.conf"
    if [[ -n "$_bad" ]]; then
      warn "门禁分层矛盾：$_bad"
      FAIL=1
    fi
  fi
}
check_doc_consistency

# ===== 自举门禁三档断言（G4）=====
# 对账 ci/self-precheck.conf 存在 + SPEC_FILE 显式配置（impact 门 --all-full fail 面）
# + CI generator-self-gate Job 含 --all/--all-full/--compliance-suite 三档 step。
# 口径漂移机器执法：任一项不符 warn + FAIL=1。
check_bootstrap_gate() {
  local base; base="$(cd "$(dirname "$0")/.." && pwd)"
  local conf="$base/ci/self-precheck.conf" ci="$base/../.github/workflows/ci.yml"
  # 安装态（~/.claude/skills/swarm-yuan/）无 ci/ 目录与 .github/，静默跳过
  [[ -f "$conf" ]] || return 0
  echo "▶ 自举门禁三档断言（G4）"
  # conf 显式配置 SPEC_FILE（impact 门在候选+兜底全空时 fail，必须 conf 指向自家模板）
  if grep -q '^SPEC_FILE=' "$conf"; then
    echo "  ✓ self-precheck.conf 显式配置 SPEC_FILE（impact 门 fail 面已闭合）"
  else
    warn "self-precheck.conf 缺 SPEC_FILE（impact 门 --all-full fail 面）"
    FAIL=1
  fi
  # CI 含三档 step（--all/--all-full/--compliance-suite）
  if [[ -f "$ci" ]]; then
    local n
    n=$(grep -cE 'precheck\.sh"? --(all|all-full|compliance-suite)' "$ci" 2>/dev/null || echo 0)
    if [[ "$n" -ge 3 ]]; then
      echo "  ✓ CI 自举三档 step 齐全（$n 处，含 --all/--all-full/--compliance-suite）"
    else
      warn "CI 自举 step 数=$n < 3（应含 --all/--all-full/--compliance-suite）"
      FAIL=1
    fi
  else
    warn "CI workflow 不存在: $ci（无法对账三档 step）"
    FAIL=1
  fi
}
check_bootstrap_gate

# ===== 上游基线漂移忠告（不联网，仅读登记表机器标记行）=====
upstream_baseline_check() {
  local base; base="$(cd "$(dirname "$0")/.." && pwd)"
  # 登记表在仓库根 docs/（T8 维护）；安装到 ~/.claude/skills 后无此文件，静默跳过
  local bl="$base/../docs/upstream-baseline.md"
  [[ -f "$bl" ]] || return 0
  local drifted
  drifted=$(grep -c 'baseline_status=drifted' "$bl" 2>/dev/null)
  [[ "${drifted:-0}" -eq 0 ]] && return 0
  echo "▶ 上游基线漂移忠告"
  # 契约：drifted 条目所在行必含字面 baseline_status=drifted（表格行，第二列为名称）；
  # 仅 warn 不置 FAIL——版本漂移是提醒而非门禁失败
  grep 'baseline_status=drifted' "$bl" | while IFS='|' read -r _ name _rest; do
    name=$(echo "$name" | sed 's/^ *//;s/ *$//')
    warn "上游基线 drifted：${name:-（未命名行）}——引用基线落后上游最新版，详见 docs/upstream-baseline.md（重核列入 P1-7）"
  done
}
upstream_baseline_check

echo ""
[[ $FAIL -eq 0 ]] && echo "✓ 自检通过" || echo "⚠ 部分未通过（手动安装的需按提示操作后重跑）"
exit $FAIL
