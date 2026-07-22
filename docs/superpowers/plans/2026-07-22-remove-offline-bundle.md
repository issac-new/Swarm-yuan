# 移除离线安装包 — 在线 npm/pip + 源码包一键安装 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 砍掉 swarm-yuan 的离线安装包体系,安装自检改为 npm/pip 在线安装,对无法走包管理器的 gstack/superpowers/ECC 用 GitHub Release 源码包一键安装。

**Architecture:** 删除 `offline-cache/` 目录与 build/install/fetch 三个离线脚本;改造 `self-check.sh` 删除"本地源码优先 + npm link"降级链,11 项运行时按 npm/pip/源码包三类重写安装函数;新增 `release-src-packages.sh` 手动发版脚本(克隆上游 → zip → `gh release upload`)。

**Tech Stack:** Bash(set -uo pipefail)、GitHub CLI(`gh`)、npm/pip/uv/pipx、GitHub Release。

## Global Constraints

- 保留 11 个 `check_*` 检测函数族不变,保留 `--check-only`/`--install`/`--latest` 三种模式语义,保留安装后复查逻辑,保留 superpowers 空壳 fail-closed 检测(self-check.sh L75-89)。
- 保留 self-check.sh 末尾的自举检查段(fw_freshness_check / fw_ruleset_verify / check_doc_consistency / upstream_baseline_check,L458-797)原样不动。
- 源码包 Release tag 形如 `v<YYYYMMDD>-src`,仓库 `issac-new/Swarm-yuan`,可由环境变量 `SRC_RELEASE_TAG` 覆盖。
- 所有改动在 worktree `feat/wp-offline-removal` 内进行,基线 `origin/main`,收口用 `git merge --no-ff`。
- commit 风格跟随仓库历史(中英文 Conventional Commits,如 `fix(adaptive): ...`)。

## File Structure

| 文件 | 操作 | 职责 |
|---|---|---|
| `swarm-yuan/scripts/self-check.sh` | 改造 | 删源码链,重写 11 个 install 函数,新增 `install_from_src_release()` |
| `swarm-yuan/scripts/release-src-packages.sh` | 新建 | 手动发版:克隆 gstack/superpowers/ECC → zip → `gh release upload` |
| `swarm-yuan/scripts/build-offline-win.sh` | 删除 | 离线打包脚本 |
| `swarm-yuan/scripts/install-offline-win.sh` | 删除 | 离线安装脚本 |
| `swarm-yuan/scripts/install-offline-win.bat` | 删除 | Windows 离线安装入口 |
| `swarm-yuan/scripts/fetch-offline-cache.sh` | 删除 | Release cache 拉取脚本 |
| `swarm-yuan/offline-cache/` | 删除 | 整个目录(UPSTREAM.md + npm/ + graphify-wheels/ + gstack/ + superpowers/ + 2 zip) |
| `swarm-yuan/.gitignore` | 改 | 删 offline-cache 规则块(L1-11) |
| `.gitignore`(根) | 改 | 删 offline-cache 治理块(L24-33) |
| `swarm-yuan/install.sh` | 改 | 删 offline-cache 排除守卫(L105/112) |
| `.github/workflows/ci.yml` | 改 | 删离线脚本 shellcheck 条目(L208),新增 release-src-packages.sh shellcheck |
| `README.md` | 改 | 改写目录树中 .gitignore 注释(L278) |
| `swarm-yuan/README.md` | 改 | 改写目录树中 .gitignore 注释(L283) |

---

### Task 1: 开 worktree

**Files:** 无(仅 git 操作)

- [ ] **Step 1: 确认在途 worktree < 3**

Run: `git worktree list`
Expected: 输出仅 main 一条(或 ≤2 条)

- [ ] **Step 2: 创建 worktree**

Run:
```bash
git fetch origin --prune
git worktree add .claude/worktrees/feat/wp-offline-removal -b feat/wp-offline-removal origin/main
cd .claude/worktrees/feat/wp-offline-removal
```
Expected: `Preparing worktree (new branch 'feat/wp-offline-removal')`

- [ ] **Step 3: 确认基线干净**

Run: `git log --oneline -1`
Expected: 显示 origin/main 最新 commit

---

### Task 2: 新增 `install_from_src_release()` 并重写 self-check.sh 安装函数

**Files:**
- Modify: `swarm-yuan/scripts/self-check.sh`(L1-309 主区,安装函数与参数解析;L458 起的自举检查段不动)

**Interfaces:**
- Produces: `install_from_src_release(name tag zip dest setup)` —— 供 install_gstack/install_superpowers/install_ecc 调用
- Produces: 重写后的 `install_openspec/install_comet/.../install_graphify/install_gstack/install_superpowers/install_ecc` —— 供 PROJECTS 表 `install_func` 字段引用

- [ ] **Step 1: 替换头部策略注释 + 删 RESEARCH_DIR 推断 + 删 pick_pm/has_cmd 中仅源码用的部分**

把 self-check.sh L1-49(从 `#!/usr/bin/env bash` 到 `pick_pm` 函数结束的 `}` 之前,即 L1-49)替换为:

```bash
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
```

注意:原 L29-49 的 `RESEARCH_DIR` 推断块、`has_cmd`、`pick_pm` 三段中,`has_cmd` 保留(后续 graphify 安装用),`RESEARCH_DIR` 与 `pick_pm` 整段删除。替换后 `pick_pm` 不再存在(下面 install_from_source 一起删)。

- [ ] **Step 2: 保留 check_* 检测函数族(L51-98)不动**

确认 L51-98 的 11 个 `check_*` 函数原样保留,不改动。

- [ ] **Step 3: 删除 install_from_source / src_root_* / 旧 install_* / upgrade_from_source,替换为新安装函数族**

把 self-check.sh L100-250(从 `# ---------- 通用：从 research 源码安装` 注释到 `upgrade_from_source` 函数结束 `}` )整体替换为:

```bash
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
```

- [ ] **Step 4: 重写 PROJECTS 表(删 src_root_func 列,补 3 个源码类 install_func)**

把 L261-273 的 `PROJECTS=(...)` 块替换为(注意:列结构从 `name|check|install|auto|src_root_func|npm_pkg` 改为 `name|check|install|auto|npm_pkg`,删第 5 列 src_root_func):

```bash
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
```

- [ ] **Step 5: 重写 install_hint()(3 个源码类已可自动装,改提示文案)**

把 L275-293 的 `install_hint()` 函数替换为:

```bash
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
```

- [ ] **Step 6: 重写参数解析(删 --npm / USE_NPM_ONLY)**

把 L295-309 的变量初始化与参数循环替换为:

```bash
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
```

- [ ] **Step 7: 重写头部模式提示块(删源码/npm 模式分支)**

把 L311-325 的提示块替换为:

```bash
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
```

- [ ] **Step 8: 重写 --latest 升级段(删源码模式,统一 npm 比对 + 源码包重装)**

把 L372-407 的 `if [[ $FORCE_LATEST -eq 1 ...` 升级块替换为:

```bash
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
```

- [ ] **Step 9: 语法校验**

Run: `cd .claude/worktrees/feat/wp-offline-removal && bash -n swarm-yuan/scripts/self-check.sh`
Expected: 无输出(语法 OK)

- [ ] **Step 10: 端到端 check-only 跑通**

Run: `cd .claude/worktrees/feat/wp-offline-removal && bash swarm-yuan/scripts/self-check.sh --check-only 2>&1 | head -30`
Expected: 输出 11 项检测 + "源码包 Release: v...-src" + 末尾自举检查段(fw_freshness_check 等),无语法错、无 "RESEARCH_DIR" / "源码优先" 字样

- [ ] **Step 11: 确认无残留旧符号**

Run: `cd .claude/worktrees/feat/wp-offline-removal && grep -nE "RESEARCH_DIR|USE_NPM_ONLY|install_from_source|src_root_|upgrade_from_source|pick_pm" swarm-yuan/scripts/self-check.sh`
Expected: 无输出(旧符号全删)

- [ ] **Step 12: shellcheck**

Run: `cd .claude/worktrees/feat/wp-offline-removal && shellcheck -x -e SC2086,SC1090,SC1091,SC2155,SC2034,SC2230,SC2004,SC2312,SC1087 swarm-yuan/scripts/self-check.sh 2>&1 | grep -E 'SC[0-9]+ \(error\)' || echo "NO ERRORS"`
Expected: `NO ERRORS`

- [ ] **Step 13: 提交**

```bash
cd .claude/worktrees/feat/wp-offline-removal
git add swarm-yuan/scripts/self-check.sh
git commit -m "refactor(adaptive): self-check 删源码链改在线npm/pip+源码包安装

- 删除 RESEARCH_DIR 本地源码优先 + npm link 降级链
- 11 项运行时重分类：8 项 npm/pip 在线装，gstack/superpowers/ECC 走 Release 源码包
- 新增 install_from_src_release() 从 GitHub Release 拉 zip 解压安装
- 删 --npm 参数与 USE_NPM_ONLY（源码链已无意义）
- 保留 11 个 check_* 检测、--check-only/--install/--latest、复查、自举检查段"
```

---

### Task 3: 新增 `release-src-packages.sh` 发版脚本

**Files:**
- Create: `swarm-yuan/scripts/release-src-packages.sh`

**Interfaces:**
- Produces: 可执行脚本 `bash swarm-yuan/scripts/release-src-packages.sh [YYYYMMDD]`,产物为 Release `v<ver>-src` 含 `gstack-src.zip` / `superpowers-src.zip` / `ecc-src.zip`

- [ ] **Step 1: 创建脚本**

写入 `swarm-yuan/scripts/release-src-packages.sh`:

```bash
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
  "superpowers|https://github.com/obra/superpowers.git"
  "ECC|https://github.com/affaan-m/ECC.git"
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
```

- [ ] **Step 2: 加可执行权限**

Run: `cd .claude/worktrees/feat/wp-offline-removal && chmod +x swarm-yuan/scripts/release-src-packages.sh`
Expected: 无输出

- [ ] **Step 3: 语法校验**

Run: `cd .claude/worktrees/feat/wp-offline-removal && bash -n swarm-yuan/scripts/release-src-packages.sh`
Expected: 无输出

- [ ] **Step 4: shellcheck**

Run: `cd .claude/worktrees/feat/wp-offline-removal && shellcheck -x -e SC2086,SC1090,SC1091,SC2155,SC2034 swarm-yuan/scripts/release-src-packages.sh 2>&1 | grep -E 'SC[0-9]+ \(error\)' || echo "NO ERRORS"`
Expected: `NO ERRORS`

- [ ] **Step 5: 提交**

```bash
cd .claude/worktrees/feat/wp-offline-removal
git add swarm-yuan/scripts/release-src-packages.sh
git commit -m "feat(adaptive): 新增 release-src-packages.sh 源码包发版脚本

克隆 gstack/superpowers/ECC 上游 → 打 zip → gh release upload 到 v<ver>-src
供 self-check.sh install_from_src_release() 一键安装（无法走 npm/pip 的运行时）"
```

---

### Task 4: 删除离线脚本与 offline-cache 目录

**Files:**
- Delete: `swarm-yuan/scripts/build-offline-win.sh`
- Delete: `swarm-yuan/scripts/install-offline-win.sh`
- Delete: `swarm-yuan/scripts/install-offline-win.bat`
- Delete: `swarm-yuan/scripts/fetch-offline-cache.sh`
- Delete: `swarm-yuan/offline-cache/`(整个目录)

- [ ] **Step 1: 确认待删文件均被 git 跟踪或不影响**

Run: `cd .claude/worktrees/feat/wp-offline-removal && git ls-files swarm-yuan/scripts/build-offline-win.sh swarm-yuan/scripts/install-offline-win.sh swarm-yuan/scripts/install-offline-win.bat swarm-yuan/scripts/fetch-offline-cache.sh swarm-yuan/offline-cache/`
Expected: 列出 4 个脚本路径 + `swarm-yuan/offline-cache/UPSTREAM.md`(二进制与 gstack/superpowers 被 gitignore,不入索引,符合预期)

- [ ] **Step 2: 删除文件**

Run:
```bash
cd .claude/worktrees/feat/wp-offline-removal
git rm swarm-yuan/scripts/build-offline-win.sh \
       swarm-yuan/scripts/install-offline-win.sh \
       swarm-yuan/scripts/install-offline-win.bat \
       swarm-yuan/scripts/fetch-offline-cache.sh \
       swarm-yuan/offline-cache/UPSTREAM.md
rm -rf swarm-yuan/offline-cache/
```
Expected: 5 个文件 staged 为 deleted;`rm -rf` 清掉工作区残留(gstack/ superpowers/ npm/ graphify-wheels/ zip)

- [ ] **Step 3: 确认工作区无 offline-cache 残留**

Run: `cd .claude/worktrees/feat/wp-offline-removal && ls swarm-yuan/offline-cache/ 2>&1`
Expected: `No such file or directory`

- [ ] **Step 4: 提交**

```bash
cd .claude/worktrees/feat/wp-offline-removal
git commit -m "chore(adaptive): 删除离线安装包体系

- 删 offline-cache/（UPSTREAM.md + npm tgz + graphify wheels + gstack/superpowers clone + 2 zip）
- 删 build-offline-win.sh / install-offline-win.sh / install-offline-win.bat / fetch-offline-cache.sh
- 改为在线 npm/pip 安装 + Release 源码包（self-check.sh + release-src-packages.sh）"
```

---

### Task 5: 清理 .gitignore(根 + swarm-yuan)

**Files:**
- Modify: `.gitignore`(根 L24-33 offline-cache 治理块)
- Modify: `swarm-yuan/.gitignore`(L1-11 offline-cache 规则块)

- [ ] **Step 1: 删根 .gitignore 的 offline-cache 治理块**

把 `.gitignore` 中的这一段(含 L24-33):

```
# ---- 悬空子模块占位 ----
# swarm-yuan/offline-cache/{gstack,superpowers} 曾是无 .gitmodules 的 gitlink(160000)，
# clone 后为空目录且 submodule update 报错，已从索引移除并在此忽略。
# 如需本地使用请手动 clone 到对应路径；勿重新 git add 成 gitlink。
swarm-yuan/offline-cache/gstack/
swarm-yuan/offline-cache/superpowers/

# 注意：swarm-yuan/offline-cache/ 的二进制（*.whl/*.tgz/*.zip）自 v2026.07.20 起
# 已迁移 GitHub Release 附件（v2026.07.20-offline tag），不再纳入 git 跟踪
#（忽略规则见 swarm-yuan/.gitignore；拉取用 swarm-yuan/scripts/fetch-offline-cache.sh）。
# git 索引内仅保留 offline-cache/UPSTREAM.md（上游溯源登记）。
```

整体删除(连同空行整理,保留其后 `.claude/worktrees/` 与 `.zcode/` 两行)。

- [ ] **Step 2: 删 swarm-yuan/.gitignore 的 offline-cache 块**

把 `swarm-yuan/.gitignore` 全部内容替换为(仅留 `.swarm-yuan/` 这条非 offline 规则):

```
# swarm-yuan 生成器本地状态
.swarm-yuan/
```

- [ ] **Step 3: 确认无 offline 残留**

Run: `cd .claude/worktrees/feat/wp-offline-removal && grep -rn -i offline .gitignore swarm-yuan/.gitignore`
Expected: 无输出

- [ ] **Step 4: 提交**

```bash
cd .claude/worktrees/feat/wp-offline-removal
git add .gitignore swarm-yuan/.gitignore
git commit -m "chore(adaptive): 清理 .gitignore 中 offline-cache 规则

离线包体系已删除，相关忽略规则与治理说明一并移除"
```

---

### Task 6: 清理 install.sh 与 CI 与 README

**Files:**
- Modify: `swarm-yuan/install.sh`(L105/112 offline-cache 排除守卫)
- Modify: `.github/workflows/ci.yml`(L208 离线脚本 shellcheck 条目)
- Modify: `README.md`(L278 目录树注释)
- Modify: `swarm-yuan/README.md`(L283 目录树注释)

- [ ] **Step 1: 删 install.sh 的 offline-cache 排除守卫**

把 `swarm-yuan/install.sh` L105-114 的复制循环段:

```bash
  # 复制（排除 offline-cache/：33MB 离线安装缓存，不应进入每个运行时 skill 目录；
  # 逐项 cp -R 覆盖隐藏文件，三平台兼容，无需 tar --exclude）
  mkdir -p "$skill_dir" "$dest"
  local item base
  for item in "$SRC_DIR"/* "$SRC_DIR"/.[!.]* "$SRC_DIR"/..?*; do
    [[ -e "$item" ]] || continue
    base="$(basename "$item")"
    [[ "$base" == "offline-cache" ]] && continue
    cp -R "$item" "$dest/"
  done
```

替换为:

```bash
  # 复制（逐项 cp -R 覆盖隐藏文件，三平台兼容，无需 tar --exclude）
  mkdir -p "$skill_dir" "$dest"
  local item base
  for item in "$SRC_DIR"/* "$SRC_DIR"/.[!.]* "$SRC_DIR"/..?*; do
    [[ -e "$item" ]] || continue
    cp -R "$item" "$dest/"
  done
```

- [ ] **Step 2: 改 ci.yml 删离线脚本 shellcheck 条目 + 加新脚本**

把 `.github/workflows/ci.yml` L207-211 信息层循环中的:

```
          for f in assets/state-machine.sh scripts/gate-report.sh scripts/gate-trends.sh \
                   scripts/install-offline-win.sh scripts/build-offline-win.sh \
                   tests/run-gate-fixture.sh tests/e2e/run-e2e.sh \
```

替换为(删两行离线脚本,加一行新发版脚本):

```
          for f in assets/state-machine.sh scripts/gate-report.sh scripts/gate-trends.sh \
                   scripts/release-src-packages.sh \
                   tests/run-gate-fixture.sh tests/e2e/run-e2e.sh \
```

- [ ] **Step 3: 改 README.md 目录树注释**

把 `README.md` L278:

```
├── .gitignore                    ← 含 offline-cache 治理说明（whl/tgz 已迁 Release 附件，拉取：swarm-yuan/scripts/fetch-offline-cache.sh）
```

替换为:

```
├── .gitignore                    ← 忽略 worktree/zcode 等本地状态
```

- [ ] **Step 4: 改 swarm-yuan/README.md 目录树注释**

把 `swarm-yuan/README.md` L283:

```
├── .gitignore                    ← 含 offline-cache 治理说明（whl/tgz 为离线安装所需，故意跟踪勿删）
```

替换为:

```
├── .gitignore                    ← 忽略 swarm-yuan 本地状态
```

- [ ] **Step 5: 全仓扫 offline 残留**

Run: `cd .claude/worktrees/feat/wp-offline-removal && grep -rn -i -E "offline-cache|install-offline|build-offline|fetch-offline" --include="*.sh" --include="*.md" --include="*.yml" --include="*.bat" . | grep -v "docs/superpowers/"`
Expected: 无输出(或仅 docs/plans 历史文档残留——历史计划文档不改,但应无)

- [ ] **Step 6: 提交**

```bash
cd .claude/worktrees/feat/wp-offline-removal
git add swarm-yuan/install.sh .github/workflows/ci.yml README.md swarm-yuan/README.md
git commit -m "chore(adaptive): 清理 install.sh/CI/README 中离线引用

- install.sh 删 offline-cache 排除守卫（目录已删）
- ci.yml 删离线脚本 shellcheck，加 release-src-packages.sh
- README 目录树注释更新"
```

---

### Task 7: 端到端验证 + 收口合并

**Files:** 无(验证 + 合并操作)

- [ ] **Step 1: self-check 语法 + check-only 端到端**

Run:
```bash
cd .claude/worktrees/feat/wp-offline-removal
bash -n swarm-yuan/scripts/self-check.sh
bash swarm-yuan/scripts/self-check.sh --check-only 2>&1 | tail -15
```
Expected: 无语法错;末尾输出"自检通过"或"部分未通过"(运行时 miss 在 CI/本地属正常),且含"源码包 Release: v...-src"

- [ ] **Step 2: release-src-packages.sh 语法 + dry(不实际发版)**

Run:
```bash
cd .claude/worktrees/feat/wp-offline-removal
bash -n swarm-yuan/scripts/release-src-packages.sh
```
Expected: 无输出(语法 OK)。实际发版留待用户在已登录 gh 的环境手动跑。

- [ ] **Step 3: rebase 到最新 main**

Run:
```bash
cd .claude/worktrees/feat/wp-offline-removal
git fetch origin --prune
git rebase origin/main
```
Expected: 干净 rebase(基线未变,无冲突)

- [ ] **Step 4: 推送分支**

Run: `cd .claude/worktrees/feat/wp-offline-removal && git push -u origin feat/wp-offline-removal`
Expected: 推送成功

- [ ] **Step 5: 切回 main 合并**

Run:
```bash
cd /Volumes/nvme2230/lab/Swarm-yuan
git checkout main
git pull --ff-only origin main
git merge --no-ff feat/wp-offline-removal
git push origin main
```
Expected: merge commit 创建并推送成功

- [ ] **Step 6: 清理 worktree 与分支**

Run:
```bash
cd /Volumes/nvme2230/lab/Swarm-yuan
git worktree remove .claude/worktrees/feat/wp-offline-removal
git branch -d feat/wp-offline-removal
git push origin --delete feat/wp-offline-removal
git worktree prune
git worktree list
```
Expected: worktree list 只剩 main

---

## Self-Review 结果

**Spec coverage:**
- §3.1 删除清单 → Task 4(脚本+目录) + Task 5(gitignore) + Task 6(install.sh/CI/README)
- §3.2 新增 release-src-packages.sh → Task 3
- §3.3 改造 self-check.sh(删源码链/重写 install/新增 install_from_src_release/重写表/重写 install_hint/删 --npm/重写升级段) → Task 2
- §3.4 数据流 → Task 2 + Task 3 覆盖
- §3.5 发版流程 → Task 3
- §4 错误处理(install_from_src_release 下载/解压失败 return 1,setup warn) → Task 2 Step 3 代码已含
- §5 测试(bash -n / shellcheck / check-only / CI) → Task 2 Step 9-12 + Task 7

**Placeholder scan:** 无 TODO/TBD,所有代码步骤含完整代码。

**Type consistency:** `install_from_src_release(name zip dest setup)` 在 Task 2 定义,install_gstack/superpowers/ecc 与 upgrade_src_pkg 调用签名一致;PROJECTS 表 5 列结构在 Step 4 定义,Step 8 升级段 `IFS='|' read -r name chk inst auto npmpkg` 与之匹配(5 字段);zip 名 gstack-src.zip/superpowers-src.zip/ecc-src.zip 在 self-check 与 release-src-packages 两侧一致。

**ECC/superpowers 目标路径:** §7 已定 —— superpowers→`~/.claude/plugins/superpowers`(与 check L81 一致),ECC→`~/.claude/plugins/ecc`(check L97 两路径均判 pass,择 plugins),gstack→`~/.claude/skills/gstack`(check L91)。Task 2 代码已落实。
