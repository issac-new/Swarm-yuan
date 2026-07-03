#!/usr/bin/env bash
# self-check.sh — swarm-yuan 运行前自检：9 个项目运行时是否已安装，未装则自动安装
# 用法: bash self-check.sh [--check-only] [--install <name>]
#   --check-only       仅检测，不安装
#   --install <name>   仅安装指定项目（openspec/comet/gitnexus/gsd-core/claude-mem/ocr/graphify/superpowers/gstack）
# 无参数 = 检测全部 + 自动安装缺失的（可自动装的）

set -uo pipefail
FAIL=0
pass(){ echo "  ✓ $1"; }
miss(){ echo "  ✗ $1 未安装"; FAIL=1; return 1; }
warn(){ echo "  ⚠ $1"; }

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

# ---------- 安装函数 ----------
install_openspec(){ echo "  → npm i -g @fission-ai/openspec"; npm i -g @fission-ai/openspec 2>&1|tail -2; }
install_comet(){ echo "  → npm i -g @rpamis/comet"; npm i -g @rpamis/comet 2>&1|tail -2; }
install_gitnexus(){ echo "  → npm i -g gitnexus"; npm i -g gitnexus 2>&1|tail -2; }
install_gsd_core(){ echo "  → npx @opengsd/gsd-core --claude --global"; npx @opengsd/gsd-core --claude --global 2>&1|tail -5; }
install_claude_mem(){ echo "  → npx claude-mem install"; npx claude-mem install 2>&1|tail -5; }
install_ocr(){ echo "  → npm i -g @alibaba-group/open-code-review"; npm i -g @alibaba-group/open-code-review 2>&1|tail -2; }
install_graphify(){
  echo "  → uv tool install graphifyy"
  if command -v uv &>/dev/null; then
    uv tool install graphifyy 2>&1|tail -3
    uv tool update-shell 2>/dev/null || true
  elif command -v pipx &>/dev/null; then
    pipx install graphifyy 2>&1|tail -3
  else
    echo "  ✗ 需先安装 uv (curl -LsSf https://astral.sh/uv/install.sh | sh) 或 pipx"
  fi
}

# 9 个项目定义：name|check_func|install_func|auto_installable
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
)

CHECK_ONLY=0
SINGLE=""

[[ "${1:-}" == "--check-only" ]] && CHECK_ONLY=1
[[ "${1:-}" == "--install" ]] && SINGLE="${2:-}"

echo "=========================================="
echo "  swarm-yuan 自检：9 个项目运行时"
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
    echo "=== 安装 $name ==="
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
  echo "✓ 全部 9 个项目运行时已安装"
  exit 0
fi

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
echo "=== 自动安装（可自动装的）==="
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
    graphify) check_graphify ;; superpowers) check_superpowers ;; gstack) check_gstack ;;
  esac
done

echo ""
[[ $FAIL -eq 0 ]] && echo "✓ 自检通过" || echo "⚠ 部分未通过（手动安装的需按提示操作后重跑）"
exit $FAIL
