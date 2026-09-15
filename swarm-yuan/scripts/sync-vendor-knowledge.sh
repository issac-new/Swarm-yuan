#!/usr/bin/env bash
# sync-vendor-knowledge.sh — 领域知识实体镜像同步脚本（学习研究用途）
#
# 用途：把本机 hermes 运行时的领域知识实体镜像到 swarm-yuan/vendor-knowledge/，
#      供 swarm-yuan 引用（industry-profile-payment.md §7）在迁移机器后仍可达。
# 立场：所镜像内容（书籍全文/专栏文章/行业规范）仅供学习研究使用，不分发、不商用；
#      大文件（standards/books/fulltext）走 git LFS 管理。
#
# 用法：
#   bash scripts/sync-vendor-knowledge.sh            # 从默认源 ~/.hermes 同步
#   bash scripts/sync-vendor-knowledge.sh --check    # 只校验镜像完整性（不拉取）
#   SRC=/path/to/hermes bash scripts/sync-vendor-knowledge.sh   # 自定义源
#
# 跨平台：bash 3.2+（Git Bash/WSL/麒麟/macOS），依赖 git + git-lfs + rsync（无 rsync 降级 cp -R）。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE="$(cd "$SCRIPT_DIR/.." && pwd)"          # swarm-yuan/
SRC="${SRC:-$HOME/.hermes}"                   # hermes 运行时根
VK="$BASE/vendor-knowledge"
MODE="${1:-sync}"

log()  { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# 跨平台目录拷贝：rsync 优先（排除 .git/.DS_Store），无 rsync 降级 cp -R 后清杂物
copy_tree() { # $1=src_dir $2=dst_dir
  local src="$1" dst="$2"
  [[ -d "$src" ]] || fail "源不存在：$src"
  mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude='.git' --exclude='.DS_Store' --exclude='._*' "$src/" "$dst/"
  else
    cp -R "$src/." "$dst/"
    find "$dst" \( -name '.git' -type d -prune -o -name '.DS_Store' -o -name '._*' \) 2>/dev/null | while IFS= read -r j; do
      case "$j" in */.git|*/.git/*) rm -rf "$j" 2>/dev/null;; *) rm -f "$j" 2>/dev/null;; esac
    done
  fi
}

# ===== --check：只校验镜像完整性 =====
if [[ "$MODE" == "--check" ]]; then
  log "=== vendor-knowledge 镜像完整性校验 ==="
  rc=0
  # 关键文件存在性
  for f in \
    "pay-team/references/pay-knowledge-index.md" \
    "pay-team/references/standards/known-conflicts.md" \
    "pay-team/references/chentianyu-kernel-frameworks.md" \
    "_shared/02-org-orchestration/four-lenses-charter.md" \
    "_shared/02-org-orchestration/language-standard.md" \
    "_shared/03-evolution-memory/output-contract.md"; do
    if [[ -f "$VK/$f" ]]; then log "  ✓ $f"; else log "  ✗ 缺失 $f"; rc=1; fi
  done
  # 体量计数（darwin/zsh set -u+多字节下 ${var} 须显式花括号）
  n="$(find "$VK" -type f 2>/dev/null | wc -l | tr -d '[:space:]')"
  log "  镜像文件总数：${n}（期望 ~300）"
  # LFS 指针 vs 实体：大文件若仍是 130B 指针，提示 git lfs pull
  ptr="$(git -C "$BASE" lfs ls-files 2>/dev/null | wc -l | tr -d '[:space:]')"
  log "  LFS 跟踪文件：${ptr}（版权大文件；克隆机须 git lfs pull 取回实体）"
  [[ "$rc" -eq 0 ]] && log "✓ 镜像完整" || log "✗ 镜像不完整，跑 bash scripts/sync-vendor-knowledge.sh 重建"
  exit "$rc"
fi

# ===== sync：从 hermes 运行时镜像 =====
log "=== vendor-knowledge 镜像同步（学习研究用途）==="
log "源：$SRC"
[[ -d "$SRC" ]] || fail "hermes 运行时根不存在：${SRC}（设 SRC=<path> 自定义）"

# git LFS 跟踪规则（大文件/版权材料入 LFS）
if command -v git-lfs >/dev/null 2>&1 || git lfs version >/dev/null 2>&1; then
  git -C "$BASE" lfs install --local >/dev/null 2>&1 || true
  for pat in \
    "swarm-yuan/vendor-knowledge/pay-team/references/standards/**" \
    "swarm-yuan/vendor-knowledge/pay-team/references/books/**" \
    "swarm-yuan/vendor-knowledge/pay-team/references/fulltext/**"; do
    git -C "$BASE" lfs track "$pat" >/dev/null 2>&1 || true
  done
  log "  ✓ git LFS 跟踪规则就绪（standards/books/fulltext）"
else
  log "  ⚠ 未检出 git-lfs：大文件将走普通 git（建议 brew install git-lfs / 包管理器装）"
fi

# 1) pay 知识库全量
log "→ 同步 pay-team 知识库"
copy_tree "$SRC/profiles/pay-orchestrator/references" "$VK/pay-team/references"

# 2) _shared 三文件（SOUL.md 实际引用项：四论四问/语言规范/输出契约）
log "→ 同步 _shared 引用项"
copy_tree "$SRC/profiles/_shared/02-org-orchestration" "$VK/_shared/02-org-orchestration" 2>/dev/null || true
mkdir -p "$VK/_shared/02-org-orchestration" "$VK/_shared/03-evolution-memory"
[[ -f "$SRC/profiles/_shared/02-org-orchestration/four-lenses-charter.md" ]] && cp "$SRC/profiles/_shared/02-org-orchestration/four-lenses-charter.md" "$VK/_shared/02-org-orchestration/"
[[ -f "$SRC/profiles/_shared/02-org-orchestration/language-standard.md" ]] && cp "$SRC/profiles/_shared/02-org-orchestration/language-standard.md" "$VK/_shared/02-org-orchestration/"
[[ -f "$SRC/profiles/_shared/03-evolution-memory/output-contract.md" ]] && cp "$SRC/profiles/_shared/03-evolution-memory/output-contract.md" "$VK/_shared/03-evolution-memory/"

# 清除任何混入的嵌套 .git（源头若是 git 仓）
find "$VK" -name '.git' -type d 2>/dev/null | while IFS= read -r g; do rm -rf "$g"; log "  清除嵌套 .git：$g"; done

n=$(find "$VK" -type f 2>/dev/null | wc -l | tr -d ' ')
log "✓ 同步完成：vendor-knowledge 共 $n 文件"
log "  下一步：git add vendor-knowledge && git commit（大文件已走 LFS）"
log "  校验：bash scripts/sync-vendor-knowledge.sh --check"
