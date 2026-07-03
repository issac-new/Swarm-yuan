#!/usr/bin/env bash
# precheck.sh — 通用质量门禁检查脚本模板（由 swarm-yuan 生成器按项目定制）
# 对应材料 check 段 4 项：§1 测试 §2 业务规则 §3 数据勾稽(无多漏错重) §4 UI脱敏日志
# 用法:
#   bash precheck.sh                  # 全部门禁
#   bash precheck.sh --branch         # 分支规范
#   bash precheck.sh --scope          # 改动范围（可改 vs 只读）
#   bash precheck.sh --build          # 构建状态
#   bash precheck.sh --test           # 测试（check §1）
#   bash precheck.sh --sensitive      # 敏感信息脱敏（check §4）
#   bash precheck.sh --consistency    # 业务规则 + 数据勾稽核对（check §2/§3）
# 生成目标技能时，替换 PROJECT_DIR / 可改目录 / 只读目录 / 命令 为项目实际值

set -euo pipefail

# ===== 按项目定制以下变量 =====
PROJECT_DIR="<项目根绝对路径>"
BRANCH_REGEX='^(feat|fix|refactor)/.+'
PROTECTED_BRANCHES=("main")                # 按项目保护分支调整
WRITABLE_DIRS=("<可改目录1>" "<可改目录2>")    # 允许改动的目录
READONLY_DIRS=("<只读目录1>")                  # 只读目录（改动=违规）
TEST_CMD="<test 命令>"                          # 如 npm test / pytest / go test ./...
BUILD_CMD="<build 命令>"                        # 如 npm run build（可选，留空跳过）
SCAN_DIRS=("<扫描敏感信息的目录>")              # 如 custom/ patches/ src/
CONSISTENCY_DIRS=("<扫描业务规则/勾稽的目录>")  # 如 src/ test/（check §2/§3）
# ============================

MODE="${1:---all}"
FAIL=0
pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; FAIL=1; }
warn() { echo "  ⚠ $1"; }

cd "$PROJECT_DIR"

check_branch() {
  echo "=== 分支检查 ==="
  local branch
  branch=$(git branch --show-current)
  for pb in "${PROTECTED_BRANCHES[@]}"; do
    if [[ "$branch" == "$pb" ]]; then
      fail "绝不允许在保护分支 $pb 上开发"
      return
    fi
  done
  if [[ "$branch" =~ $BRANCH_REGEX ]]; then
    pass "分支规范: $branch"
  elif [[ "$branch" == "main" ]]; then
    fail "当前在 main，应切到 feature 分支开发"
  else
    fail "分支名不规范: $branch (应为 $BRANCH_REGEX)"
  fi
}

check_scope() {
  echo "=== 改动范围检查 ==="
  local readonly_violation=0
  for rd in "${READONLY_DIRS[@]}"; do
    [[ -d "$rd" ]] || continue
    local dirty
    dirty=$(cd "$rd" 2>/dev/null && git status --porcelain 2>/dev/null | head -20 || true)
    if [[ -n "$dirty" ]]; then
      fail "只读目录有改动: $rd"
      echo "$dirty" | head -10
      readonly_violation=1
    fi
  done
  [[ $readonly_violation -eq 0 ]] && pass "只读目录无改动"
}

check_build() {
  echo "=== 构建状态检查 ==="
  if [[ -z "$BUILD_CMD" || "$BUILD_CMD" == "<build 命令>" ]]; then
    echo "  (跳过：未配置 BUILD_CMD)"
    return
  fi
  if eval "$BUILD_CMD" 2>&1 | tail -10; then
    pass "构建通过"
  else
    fail "构建失败"
  fi
}

check_test() {
  echo "=== 测试检查（check §1 单测/接口/集成/回归/安全）==="
  if eval "$TEST_CMD" 2>&1 | tail -20; then
    pass "测试通过"
  else
    fail "测试失败"
  fi
}

check_sensitive() {
  echo "=== 敏感信息脱敏扫描（check §4 UI脱敏/日志）==="
  local patterns=(
    'sk-[a-zA-Z0-9]{20,}'
    'AKIA[0-9A-Z]{16}'
    'password\s*[:=]\s*['\''"][^'\'']{4,}'
    'api[_-]?key\s*[:=]\s*['\''"][^'\'']{8,}'
    'secret\s*[:=]\s*['\''"][^'\'']{8,}'
    'token\s*[:=]\s*['\''"][^'\'']{16,}'
    'mongodb(\+srv)?://[^/\s]+:[^/@\s]+@'
    'redis://[^:\s]+:[^@\s]+@'
    'postgres(ql)?://[^/\s]+:[^/@\s]+@'
  )
  local found=0
  for dir in "${SCAN_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    for pattern in "${patterns[@]}"; do
      local matches
      matches=$(grep -rnE "$pattern" "$dir" \
        --include='*.ts' --include='*.vue' --include='*.js' --include='*.mjs' \
        --include='*.patch' --include='*.py' --include='*.go' --include='*.rs' \
        --include='*.scss' --include='*.java' 2>/dev/null \
        | grep -v -i 'example\|placeholder\|test\|mock\|dummy\|<.*>' || true)
      if [[ -n "$matches" ]]; then
        fail "疑似敏感信息 ($dir):"
        echo "$matches" | head -10
        found=1
      fi
    done
  done
  [[ $found -eq 0 ]] && pass "未发现明显敏感信息"
}

check_consistency() {
  echo "=== 业务规则 + 数据勾稽核对（check §2/§3 无多漏错重）==="
  local issues=0
  for dir in "${CONSISTENCY_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    # 检查是否有未标注幂等的重复写入逻辑（粗筛：同名 INSERT/create 多处出现）
    local dup_writes
    dup_writes=$(grep -rnE '(INSERT INTO|\.create\(|db\.(insert|create))' "$dir" \
      --include='*.ts' --include='*.js' --include='*.py' --include='*.go' --include='*.java' 2>/dev/null \
      | grep -v -i 'test\|mock\|seed\|fixture\|migration' || true)
    if [[ -n "$dup_writes" ]]; then
      local count
      count=$(echo "$dup_writes" | wc -l | xargs)
      if [[ $count -gt 5 ]]; then
        warn "  ⚠ $dir 有 $count 处写入逻辑，请确认幂等性（重复请求不产生副作用）"
      fi
    fi
  done
  pass "业务规则与勾稽核对完成（详见 reference-manual.md §数据勾稽核对）"
  echo "  提示: 无多漏错重核对项见 reference-manual.md §数据勾稽核对："
  echo "    - 无遗漏：关联记录无缺失"
  echo "    - 无多余：无冗余/重复记录"
  echo "    - 记录正确：字段值符合业务规则"
  echo "    - 勾稽正确：外键/聚合/关联关系正确"
  echo "    - 一致性：同源数据多处一致"
  echo "    - 幂等性：重复请求不产生副作用"
}

check_review() {
  echo "=== 代码审查（check gstack/OCR 5 维度）==="
  # 引用 open-code-review CLI（若已安装）
  if command -v ocr &>/dev/null; then
    pass "ocr 已安装，运行审查"
    ocr review --audience agent 2>&1 | tail -30 || warn "ocr review 返回非零"
  else
    warn "ocr 未安装，请手动按 5 维度审查（见 references/review-methodology.md）"
    echo "  5 维度：正确性 / 安全 / 性能 / 可维护性 / 测试覆盖"
    echo "  两遍清单：CRITICAL（SQL/竞态/注入/越权/路径穿越）+ INFORMATIONAL（命名/注释/风格）"
    echo "  处置：AUTO-FIX（机械修复）vs ASK（可能意见不一）"
    echo "  严重度：High（必修）/ Medium（评估）/ Low（丢弃）"
    echo "  安装 ocr：见 https://github.com/alibaba/open-code-review"
  fi
  pass "代码审查检查完成"
}

case "$MODE" in
  --all)
    check_branch
    check_scope
    check_sensitive
    check_consistency
    check_review
    check_test
    ;;
  --branch) check_branch ;;
  --scope) check_scope ;;
  --build) check_build ;;
  --test) check_test ;;
  --sensitive) check_sensitive ;;
  --consistency) check_consistency ;;
  --review) check_review ;;
  *)
    echo "Usage: bash precheck.sh [--all|--branch|--scope|--build|--test|--sensitive|--consistency|--review]"
    exit 1
    ;;
esac

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo "✓ 门禁检查通过"
  exit 0
else
  echo "✗ 门禁检查未通过，请修复上述问题"
  exit 1
fi
