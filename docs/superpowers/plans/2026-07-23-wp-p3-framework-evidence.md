# WP-P3 框架规律证据台账（framework-evidence.sh + 62 文件 verify 块迁移）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 spec `docs/superpowers/specs/2026-07-23-generation-toolization-design.md` §5（M2）：把 Step 4.5 中模型对 62 个框架文件逐个读 §1–§6、手工执行每条规律 grep 验证、逐个抄证据 file:line（62 文件共 12,027 行，生成期最大 token 消耗点）的机械工作脚本化。两步：(P3a) 62 个框架文件「验证方法」散文迁移为机器可读 `verify` 块；(P3b) `framework-evidence.sh` 读 verify 块批量执行 → 输出证据台账 TSV，模型只读台账做适用/不适用判断（判断语义完整保留，红线 template-spec.md:346）。

**Architecture:**
- **P3a 格式迁移**：每个 `references/frameworks/<fw>.md` 的 `### 规律：<标题>` 条目下，散文「验证方法」保留不变，其下新增机器可读 ```` ```verify ```` 块（`id: <fw>-rNN` / `cmd: <grep/find 命令，含 ${PROJECT_DIR} 占位>` / `expect: hits>0|hits=0|always`）。迁移用辅助脚本 `scripts/migrate-verify-blocks.sh` 解析现有「验证方法」行里的 grep 语句生成块草稿，人工/脚本校对一次；无 grep 语句的「人工检查」规律 → `expect: always`（脚本不执行，台账标 manual）。
- **P3b 台账脚本**：`framework-evidence.sh` 输入 = 目标仓库 + ACTIVE_FRAMEWORKS 列表（直接吃 `detect-frameworks.sh` 输出）→ 逐框架提取 verify 块并批量执行 → 输出证据台账 TSV：`framework | rule_id | rule_title | hits | evidence(top-N file:line) | SUGGEST(applicable/unclear/likely-na)`。SUGGEST 只是启发式（hits=0 → likely-na），**不是判决**。
- **模型新动作**（Step 4.5 改写）：读台账而非跑 grep；对每条规律做适用/不适用判断并记录理由。规律计数 ≥ 深度门槛的校验由 `verify-framework-ruleset.sh` 继续兜底（已存在，不动）。

**Tech Stack:** bash 3.2（三 OS），无新增依赖。

**Spec:** `docs/superpowers/specs/2026-07-23-generation-toolization-design.md` §5（M2）、§9（测试）、§10（WP 分解，P3 可拆 P3a/P3b）。

## Global Constraints

- bash 3.2 兼容：禁 `declare -A`；`sed -i.bak` + `rm` 模式；正则用 `grep -E`/`sed -E`（BSD 兼容）；三 OS（macOS/Linux/Windows Git Bash）可跑。
- Repo-confirmed bash 3.2.57 quirks（两条都必须遵守）：
  1. `"` 紧贴 `)` 在引号命令替换内会解析失败 → 赋值用裸命令替换 `x=$(cmd "$VAR")`（不写 `x="$(cmd "$VAR")"`）。
  2. `$VAR` 紧跟多字节字符在双引号串内会误词法 → 多字节字符前用 `${VAR}` 花括号。
- 计量/核验类脚本 fail-open：缺文件/缺数据 exit 0（只 arg 错误 exit 1）。
- 输出确定性：同输入字节级一致（排序后输出，evidence file:line 截断后排序），可进 cli-ab byte-diff。
- 新脚本进 CI shellcheck 严格名单（`.github/workflows/ci.yml` Job4）。
- 分支纪律：一个 worktree（`.claude/worktrees/feat-wp-p3-framework-evidence`，从 origin/main 起），收口 `merge --no-ff`。
- run-verifier.sh all 全绿是合入门槛（metrics/sensitive gate-fixtures 预存失败披露即可）。
- **红线（template-spec.md:346）**：framework-knowledge.md 规律骨架故意不由脚本生成；脚本只到证据台账 + 启发式 SUGGEST 为止，**适用/不适用判断由模型保留**。
- **不破坏现有**：`verify-framework-ruleset.sh` 的规律计数/挂门禁/freshness 核验逻辑不动（verify 块是 §3 条目下的新增内容，不影响 `grep -c '^### 规律'` 与「对应门禁/人工检查」扫描）。

---

## Task 1（P3a 辅助）: `scripts/migrate-verify-blocks.sh` — verify 块草稿生成

**Files:**
- Create: `swarm-yuan/scripts/migrate-verify-blocks.sh`
- Test: `swarm-yuan/tests/test-migrate-verify-blocks.sh`

**Interfaces:**
- 产生：CLI `migrate-verify-blocks.sh <framework.md>` → stdout 该文件的 verify 块草稿（不直接写文件，供人工/Task 2 校对后落盘）；`--apply` 直接落盘（先 `sed -i.bak` 备份）。每条 `### 规律` 下若已有 verify 块则跳过（幂等）。

- [ ] **Step 1: 写失败测试**

Create `swarm-yuan/tests/test-migrate-verify-blocks.sh`:

```bash
#!/usr/bin/env bash
# test-migrate-verify-blocks.sh — migrate-verify-blocks.sh 草稿生成测试（WP-P3a）
set -uo pipefail
cd "$(dirname "${0}")/.."
SH="scripts/migrate-verify-blocks.sh"
TMP="$(mktemp -d /tmp/mvbtest.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

# 构造一个迷你框架文件（含 grep 验证方法 + 人工检查两种规律）
cat > "$TMP/fw.md" <<'EOF'
## §3 领域规律

### 规律：Hooks 须在组件顶层调用
- **适用版本**: React 16.8+
- **规律**: ...散文...
- **违反后果**: ...
- **验证方法**: `grep -rnE 'useState|useEffect' --include='*.tsx' ${PROJECT_DIR}` 命中 if 块内 → fail。
- **对应门禁**: fw_react_hooks_top_level(fail)

### 规律：自定义 Hook 须以 use 开头
- **适用版本**: React 16.8+
- **规律**: ...散文...
- **违反后果**: ...
- **验证方法**: 检出含 useState 的函数不以 use 开头 → 人工确认。
- **对应门禁**: 人工检查
EOF

# 态 1：草稿模式 stdout 含两个 verify 块
out="$(bash "$SH" "$TMP/fw.md" 2>/dev/null)"; rc=$?
[[ $rc -eq 0 ]] && ok "草稿 exit 0" || bad "exit=$rc"
echo "$out" | grep -qE 'id: fw-r1' && ok "规律1 id 生成" || bad "缺 id fw-r1: $out"
echo "$out" | grep -qE 'cmd: grep -rnE' && ok "规律1 cmd 从验证方法提取" || bad "规律1 cmd 缺失"
echo "$out" | grep -qE 'expect: hits>0' && ok "规律1 expect hits>0" || bad "规律1 expect 缺失"
echo "$out" | grep -qE 'expect: always' && ok "规律2（人工检查）expect always" || bad "规律2 expect 缺失"

# 态 2：幂等（已有 verify 块的文件再跑不重复生成）
printf '\n```verify\nid: fw-r1\ncmd: x\nexpect: hits>0\n```\n' >> "$TMP/fw.md"
out2="$(bash "$SH" "$TMP/fw.md" 2>/dev/null)"
echo "$out2" | grep -c 'id: fw-r1' | grep -q '^1$' && ok "幂等不重复" || bad "幂等失败: $(echo "$out2" | grep -c 'id: fw-r1')"

[[ $FAIL -eq 0 ]] && { echo "PASS test-migrate-verify-blocks"; exit 0; } || { echo "FAIL test-migrate-verify-blocks" >&2; exit 1; }
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash swarm-yuan/tests/test-migrate-verify-blocks.sh`
Expected: FAIL（脚本不存在）

- [ ] **Step 3: 实现 `swarm-yuan/scripts/migrate-verify-blocks.sh`**

```bash
#!/usr/bin/env bash
# migrate-verify-blocks.sh — 框架文件 verify 块草稿生成（WP-P3a 辅助，一次性迁移工具）
# 解析 references/frameworks/<fw>.md §3 每条「### 规律」的「验证方法」行：
#   - 含 grep/find 命令 → 提取为 cmd，expect=hits>0（命中即 applicable 候选）
#   - 「人工检查」/无 grep → expect=always（脚本不执行，台账标 manual）
# 默认 stdout 草稿（不写文件）；--apply 用 sed -i.bak 落盘到每条规律「对应门禁」行后。
# 幂等：已有 ```verify 块的规律跳过。
# 用法: migrate-verify-blocks.sh <framework.md> [--apply]
# 退出码: 0 正常；1 arg 错误。
set -uo pipefail

APPLY=0
F=""
for a in "$@"; do
  case "$a" in
    --apply) APPLY=1 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) [[ -z "$F" ]] && F="$a" || { echo "未知参数: $a" >&2; exit 1; } ;;
  esac
done
[[ -n "$F" && -f "$F" ]] || { echo "✗ 框架文件缺失或不存在: ${F:-（空）}" >&2; exit 1; }
FW=$(basename "$F" .md)

# 逐行扫：进入「### 规律」段，找「验证方法」行，提取 grep/find 命令；找「对应门禁」行作为插入点
# bash 3.2 无关联数组，用「规则序号|字段」管道传递
awk -v fw="$FW" -v apply="$APPLY" '
  /^### 规律/ { rid++; have_verify=0; vm=""; gate_line=""; inrule=1; title=$0; next }
  inrule && /^```verify/ { have_verify=1 }
  inrule && /^### |^## / { inrule=0 }
  inrule && /验证方法/ { vm=$0 }
  inrule && /对应门禁/ { gate_line=$0 }
  inrule && have_verify==0 && gate_line != "" {
    # 提取 grep/find 命令（反引号内或管道）
    cmd=""; expect="always"
    if (match(vm, /`[^`]*grep[^`]*`/)) {
      cmd=substr(vm, RSTART+1, RLENGTH-2); expect="hits>0"
      gsub(/\$\{PROJECT_DIR\}|\"\$\{PROJECT_DIR\}"/, "${PROJECT_DIR}", cmd)
    } else if (match(vm, /`[^`]*find[^`]*`/)) {
      cmd=substr(vm, RSTART+1, RLENGTH-2); expect="hits>0"
    }
    # 规则号 padded 2 位
    printf "id: %s-r%02d\n", fw, rid
    printf "cmd: %s\n", cmd
    printf "expect: %s\n", expect
    printf "---\n"
    gate_line=""
  }
' "$F"
exit 0
```

（注：`--apply` 模式实现复杂度高，本 Task 只交付草稿模式 stdout；62 文件迁移在 Task 2 用草稿 + 人工/脚本落盘完成。`--apply` 留作 YAGNI，草稿模式已足够支撑一次性迁移。）

- [ ] **Step 4: 跑测试确认通过**

Run: `bash swarm-yuan/tests/test-migrate-verify-blocks.sh`
Expected: `PASS test-migrate-verify-blocks`

- [ ] **Step 5: Commit**

```bash
git add swarm-yuan/scripts/migrate-verify-blocks.sh swarm-yuan/tests/test-migrate-verify-blocks.sh
git commit -m "feat(wp-p3a): migrate-verify-blocks.sh verify 块草稿生成器（一次性迁移辅助）"
```

---

## Task 2（P3a 落地）: 62 框架文件 verify 块迁移 + 校对

**Files:**
- Modify: `swarm-yuan/references/frameworks/*.md`（62 个，每条 `### 规律` 下新增 ```` ```verify ```` 块）
- Modify: `swarm-yuan/references/frameworks/_template.md`（模板加 verify 块示范）

**Interfaces:**
- 每条规律下 verify 块格式（spec §5）：
  ````
  ### 规律 N：<标题>
  ...散文不变...
  - **对应门禁**: fw_xxx(fail)

  ```verify
  id: <fw>-rNN
  cmd: grep -rnE "pattern" --include="*.ts" "${PROJECT_DIR}"
  expect: hits>0
  ```
  ````

- [ ] **Step 1: _template.md 加 verify 块示范**

在 `_template.md` 的 `### 规律：<示例标题>` 条目「对应门禁」行后插入示范块（让新框架文件作者有模板可循）：

````
```verify
id: <fw>-r01
cmd: grep -rnE "pattern" --include="*.ext" "${PROJECT_DIR}"
expect: hits>0
```
````

并在 _template.md 头部注释补一行：`§3 每条规律下须有 ```verify 块（id/cmd/expect，由 migrate-verify-blocks.sh 草稿生成 + 人工校对；framework-evidence.sh 消费）`。

- [ ] **Step 2: 跑草稿生成器对 62 文件批量产出草稿**

Run:
```bash
cd swarm-yuan
for f in references/frameworks/*.md; do
  [[ "$f" == *"_template"* ]] && continue
  echo "=== $(basename "$f") ==="
  bash scripts/migrate-verify-blocks.sh "$f" 2>/dev/null
done > /tmp/verify-drafts.txt
wc -l /tmp/verify-drafts.txt
```
Expected: 草稿文件含每条规律的 id/cmd/expect 三行 + `---` 分隔（62 文件 × ~5 规律 ≈ 300+ 块）

- [ ] **Step 3: 逐文件落盘 verify 块（脚本辅助 + 人工校对）**

对每个 `references/frameworks/<fw>.md`：取 Task 2 Step 2 的草稿，在每条「### 规律」的「对应门禁」行后插入 verify 块。落盘用 `sed -i.bak` + `rm` 模式（bash 3.2 兼容）。人工校对要点：
- `cmd` 里的 `${PROJECT_DIR}` 占位保留（framework-evidence.sh 替换）；
- 「人工检查」规律的 `expect: always`（脚本跳过执行，台账标 manual）；
- grep 命令的 `--include` 与文件类型与原「验证方法」一致；
- 规则号 `rNN` 从 01 递增，与「### 规律」出现顺序一致。

批量校验脚本（落盘后跑，确保每条规律都有 verify 块）：
```bash
cd swarm-yuan
miss=0
for f in references/frameworks/*.md; do
  [[ "$f" == *"_template"* ]] && continue
  rules=$(grep -c '^### 规律' "$f")
  blocks=$(awk '/^```verify/{c++} END{print c+0}' "$f")
  if [[ "$rules" -ne "$blocks" ]]; then
    echo "✗ $(basename "$f"): 规律 $rules vs verify 块 $blocks 不一致"
    miss=$((miss+1))
  fi
done
echo "miss=$miss"
```
Expected: `miss=0`（62 文件全部规律有 verify 块）

- [ ] **Step 4: 回归 — verify-framework-ruleset.sh 不受影响**

Run: `cd swarm-yuan && bash scripts/verify-framework-ruleset.sh react 2>&1 | tail -5`
Expected: 仍输出「规则集 react 核验通过」（verify 块是新增内容，不影响 `grep -c '^### 规律'` 计数与「对应门禁/人工检查」扫描）

- [ ] **Step 5: Commit**

```bash
git add swarm-yuan/references/frameworks/
git commit -m "feat(wp-p3a): 62 框架文件 §3 规律 verify 块迁移（机器可读证据台账前置）"
```

---

## Task 3（P3b）: `scripts/framework-evidence.sh` — 证据台账

**Files:**
- Create: `swarm-yuan/scripts/framework-evidence.sh`
- Test: `swarm-yuan/tests/test-framework-evidence.sh`

**Interfaces:**
- 消费：目标仓库 `<PROJECT_DIR>` + ACTIVE_FRAMEWORKS 列表（`detect-frameworks.sh` 输出或 `--frameworks` 参数）；`references/frameworks/<fw>.md` 的 verify 块。
- 产生：CLI `framework-evidence.sh <PROJECT_DIR> [--frameworks <fw1,fw2>] [--top 3]`；stdout TSV `framework | rule_id | rule_title | hits | evidence | SUGGEST`。evidence = top-N `file:line`（默认 3，按路径排序截断）。SUGGEST：hits>0 → applicable；hits=0 且 expect≠always → likely-na；expect=always → manual。exit 0（fail-open）；1 arg 错误。

- [ ] **Step 1: 写失败测试**

Create `swarm-yuan/tests/test-framework-evidence.sh`:

```bash
#!/usr/bin/env bash
# test-framework-evidence.sh — framework-evidence.sh 台账双态测试（WP-P3b/M2）
set -uo pipefail
cd "$(dirname "${0}")/.."
SH="scripts/framework-evidence.sh"
TMP="$(mktemp -d /tmp/fetest.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

# 构造一个迷你 react 框架文件（含 verify 块）→ 临时替换 BASE/references/frameworks/react.md
# 为不污染真实框架库，用 --frameworks-dir 指向临时目录
mkdir -p "$TMP/fwdir"
cat > "$TMP/fwdir/react.md" <<'EOF'
---
ruleset_id: react
深度门槛: 2
最后调研: 2026-07-17
---
# React
## §3 领域规律
### 规律：Hooks 须在组件顶层调用
- **验证方法**: ...
- **对应门禁**: fw_react_hooks_top_level(fail)

```verify
id: react-r01
cmd: grep -rnE 'useState|useEffect' --include='*.tsx' "${PROJECT_DIR}"
expect: hits>0
```
### 规律：自定义 Hook 命名
- **对应门禁**: 人工检查

```verify
id: react-r02
cmd:
expect: always
```
EOF

# 态 1：项目含 useState → react-r01 hits>0 SUGGEST=applicable
mkdir -p "$TMP/proj/src"
printf 'useState(0)\n' > "$TMP/proj/src/a.tsx"
out="$(bash "$SH" "$TMP/proj" --frameworks react --frameworks-dir "$TMP/fwdir" --top 2 2>/dev/null)"; rc=$?
[[ $rc -eq 0 ]] && ok "台账 exit 0" || bad "exit=$rc"
echo "$out" | grep -qE 'react	react-r01	.*[1-9][0-9]*	.*applicable' && ok "r01 hits>0 applicable" || bad "r01 异常: $out"
echo "$out" | grep -qE 'react	react-r02	.*manual' && ok "r02 expect=always manual" || bad "r02 异常: $out"
echo "$out" | grep -qE 'a\.tsx:[0-9]+' && ok "evidence 含 file:line" || bad "evidence 缺失: $out"

# 态 2：项目无 useState → r01 hits=0 SUGGEST=likely-na
mkdir -p "$TMP/proj2/src"
printf 'console.log(1)\n' > "$TMP/proj2/src/b.ts"
out="$(bash "$SH" "$TMP/proj2" --frameworks react --frameworks-dir "$TMP/fwdir" 2>/dev/null)"
echo "$out" | grep -qE 'react	react-r01	0	.*likely-na' && ok "r01 hits=0 likely-na" || bad "态2 r01 异常: $out"

# 态 3：确定性（同输入连跑两次 evidence 段一致）
o1="$(bash "$SH" "$TMP/proj" --frameworks react --frameworks-dir "$TMP/fwdir" --top 2 2>/dev/null)"
o2="$(bash "$SH" "$TMP/proj" --frameworks react --frameworks-dir "$TMP/fwdir" --top 2 2>/dev/null)"
[[ "$o1" == "$o2" ]] && ok "确定性 byte-identical" || bad "两次不一致"

[[ $FAIL -eq 0 ]] && { echo "PASS test-framework-evidence"; exit 0; } || { echo "FAIL test-framework-evidence" >&2; exit 1; }
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash swarm-yuan/tests/test-framework-evidence.sh`
Expected: FAIL（脚本不存在）

- [ ] **Step 3: 实现 `swarm-yuan/scripts/framework-evidence.sh`**

```bash
#!/usr/bin/env bash
# framework-evidence.sh — 框架规律证据台账（WP-P3b/M2，最大 token 池脚本化）
# 输入: 目标仓库 + ACTIVE_FRAMEWORKS → 逐框架提取 references/frameworks/<fw>.md §3 verify 块
#       → 批量执行 cmd（${PROJECT_DIR} 替换为实参）→ 输出证据台账 TSV
# 输出: stdout TSV「framework | rule_id | rule_title | hits | evidence(top-N file:line) | SUGGEST」
#   SUGGEST 启发式（非判决）: hits>0 → applicable; hits=0 且 expect≠always → likely-na; expect=always → manual
# 红线（template-spec.md:346）: 本脚本只产证据台账 + 启发式 SUGGEST，不替模型做适用/不适用判断。
# 用法:
#   bash framework-evidence.sh <PROJECT_DIR> [--frameworks <fw1,fw2>] [--frameworks-dir <dir>] [--top <N>]
#     --frameworks       逗号分隔框架 id 列表（不给则调 detect-frameworks.sh 自动探测）
#     --frameworks-dir   框架文件目录（默认 references/frameworks，测试用）
#     --top              evidence 截断条数（默认 3）
# 退出码: 0 正常（fail-open，框架文件缺失跳过）；1 arg 错误。
set -uo pipefail
BASE="$(cd "$(dirname "${0}")/.." && pwd)"

PROJ=""; FWS=""; FWDIR="$BASE/references/frameworks"; TOP=3
while [[ $# -gt 0 ]]; do
  case "$1" in
    --frameworks) FWS="${2:?--frameworks 需要列表}"; shift 2 ;;
    --frameworks-dir) FWDIR="${2:?--frameworks-dir 需要路径}"; shift 2 ;;
    --top) TOP="${2:?--top 需要 N}"; shift 2 ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) [[ -z "$PROJ" ]] && PROJ="$1" || { echo "未知参数: $1" >&2; exit 1; }; shift ;;
  esac
done
[[ -n "$PROJ" && -d "$PROJ" ]] || { echo "✗ PROJECT_DIR 缺失或不存在: ${PROJ:-（空）}" >&2; exit 1; }
PROJ="$(cd "$PROJ" && pwd)"

# 框架列表：--frameworks > detect-frameworks.sh
if [[ -z "$FWS" ]]; then
  if [[ -x "$BASE/scripts/detect-frameworks.sh" ]]; then
    FWS=$("$BASE/scripts/detect-frameworks.sh" "$PROJ" 2>/dev/null | sed -n 's/.*"\([^"]*\)".*/\1/p' | tr '\n' ',' | sed 's/,$//')
  fi
  [[ -z "$FWS" ]] && { echo "（无 ACTIVE_FRAMEWORKS，台账为空）"; exit 0; }
fi

printf 'framework\trule_id\trule_title\thits\tevidence\tSUGGEST\n'
IFS=',' read -r _fws <<< "$FWS"
for fw in $_fws; do
  [[ -n "$fw" ]] || continue
  rule="$FWDIR/$fw.md"
  [[ -f "$rule" ]] || { printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$fw" "-" "-" "-" "-" "NO_RULE_FILE"; continue; }
  # 状态机式扫 verify 块：进入 ```verify 段，收 id/cmd/expect；退出时执行
  awk -v fw="$fw" -v proj="$PROJ" -v top="$TOP" '
    /^```verify/ { inblk=1; id=""; cmd=""; expect="always"; next }
    inblk && /^```/ { inblk=0; printf "VBLK\t%s\t%s\t%s\t%s\n", id, cmd, expect, title; next }
    inblk && /^id:/ { id=$2 }
    inblk && /^cmd:/ { sub(/^cmd:[[:space:]]*/,""); cmd=$0 }
    inblk && /^expect:/ { expect=$2 }
    /^### 规律/ { title=$0; sub(/^### 规律[：:]?[[:space:]]*/,"",title) }
  ' "$rule" | while IFS="$(printf '\t')" read -r tag vid vcmd vexp vtitle; do
    [[ "$tag" == "VBLK" ]] || continue
    if [[ "$vexp" == "always" || -z "$vcmd" ]]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$fw" "$vid" "$vtitle" "-" "-" "manual"
      continue
    fi
    # 替换 ${PROJECT_DIR} 并执行（eval 处理引号；fail-open 失败计 0）
    _cmd=$(printf '%s' "$vcmd" | sed "s|\${PROJECT_DIR}|$PROJ|g")
    _hits=$($_cmd 2>/dev/null | grep -c . || echo 0)
    _evid=$(eval "$_cmd" 2>/dev/null | sed -E 's|^'"$PROJ"'/||' | sort | head -"$TOP" | tr '\n' ';' | sed 's/;$//')
    if [[ "$_hits" -gt 0 ]]; then _sug="applicable"; else _sug="likely-na"; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$fw" "$vid" "$vtitle" "$_hits" "$_evid" "$_sug"
  done
done
exit 0
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash swarm-yuan/tests/test-framework-evidence.sh`
Expected: `PASS test-framework-evidence`

- [ ] **Step 5: 回归（真实框架库 + fixture）**

Run: `cd swarm-yuan && bash scripts/framework-evidence.sh tests/fixtures/gin --frameworks gin --top 2 2>/dev/null | head -4`
Expected: TSV 表头 + gin 规律行（hits/evidence 按实况，fail-open 不崩）

- [ ] **Step 6: Commit**

```bash
git add swarm-yuan/scripts/framework-evidence.sh swarm-yuan/tests/test-framework-evidence.sh
git commit -m "feat(wp-p3b): framework-evidence.sh 框架规律证据台账（hits+evidence+SUGGEST 启发式，判断语义保留）"
```

---

## Task 4: SKILL.md Step 4.5 + exploration-guide 指针改写

**Files:**
- Modify: `swarm-yuan/SKILL.md`（Step 4.5 框架深化段，约 :86 行附近「★项目形态判定」块后）
- Modify: `swarm-yuan/references/exploration-guide.md`（§4.5 框架深化段，若有）

**Interfaces:**
- 模型新动作（spec §5）：读台账而非跑 grep；对每条规律做适用/不适用判断并记录理由（判断语义完整保留）；证据 file:line 从台账直接引用。

- [ ] **Step 1: 定位 Step 4.5 段**

Run: `cd swarm-yuan && grep -n "4.5\|框架深化\|framework-knowledge" SKILL.md | head -5`
Expected: 找到 Step 4.5 框架深化段行号

- [ ] **Step 2: SKILL.md Edit — Step 4.5 段插入台账指引**

在 Step 4.5 框架深化段「依据 `references/frameworks/<fw>.md` §3+§4 构建」句后插入：

```
**★WP-P3 框架证据台账脚本化**：跑 `bash scripts/framework-evidence.sh <项目根> --frameworks <ACTIVE_FRAMEWORKS>` 产出证据台账 TSV（framework/rule_id/rule_title/hits/evidence/SUGGEST）。模型读台账而非逐条跑 grep——对每条规律做适用/不适用判断并记录理由（判断语义完整保留，红线 template-spec.md:346），证据 file:line 从台账直接引用；SUGGEST 只是启发式（hits=0 → likely-na），不是判决。规律计数 ≥ 深度门槛的校验由 `verify-framework-ruleset.sh` 继续兜底。框架文件 §3 每条规律下的 ```verify 块（id/cmd/expect）是台账数据源，新增/改规律须同步 verify 块。
```

- [ ] **Step 3: Commit**

```bash
git add swarm-yuan/SKILL.md
git commit -m "docs(wp-p3): SKILL.md Step 4.5 指向 framework-evidence.sh 台账（判断语义保留）"
```

---

## Task 5: WP-P3 CI 接线 + 全量回归 + 收口

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: ci.yml Edit 1 — shellcheck 严格名单**

old_string（`scripts/context-surface.sh scripts/inventory-verify.sh; do`，P2 后状态）：

```
                   scripts/context-surface.sh scripts/inventory-verify.sh; do
```

new_string：

```
                   scripts/context-surface.sh scripts/inventory-verify.sh \
                   scripts/migrate-verify-blocks.sh scripts/framework-evidence.sh; do
```

- [ ] **Step 2: ci.yml Edit 2 — self-check job 测试步骤**

old_string（WP-P0/P1/P2 测试步骤块）：

```yaml
      - name: 计量/信号索引/维度核验测试（WP-P0/P1/P2）
        run: |
          bash tests/test-context-surface.sh
          bash tests/test-cost-report.sh
          bash tests/test-signal-index.sh
          bash tests/test-detect-frameworks.sh
          bash tests/test-inventory-verify.sh
```

new_string：

```yaml
      - name: 计量/信号/维度/框架证据测试（WP-P0~P3）
        run: |
          bash tests/test-context-surface.sh
          bash tests/test-cost-report.sh
          bash tests/test-signal-index.sh
          bash tests/test-detect-frameworks.sh
          bash tests/test-inventory-verify.sh
          bash tests/test-migrate-verify-blocks.sh
          bash tests/test-framework-evidence.sh
```

- [ ] **Step 3: 本地全量回归**

Run:
```bash
cd swarm-yuan
bash scripts/verify-framework-ruleset.sh react 2>&1 | tail -1   # 不受 verify 块影响
bash tests/test-migrate-verify-blocks.sh && bash tests/test-framework-evidence.sh
bash ../verifier/v1/run-verifier.sh all
```
Expected: verify-framework-ruleset 通过；两测试 PASS；verifier 全绿（metrics/sensitive 预存失败披露）

- [ ] **Step 4: Commit 并收口 WP-P3**

```bash
git add .github/workflows/ci.yml
git commit -m "ci(wp-p3): framework-evidence 进 shellcheck 严格层 + 框架证据测试进 CI"
# rebase origin/main → push → main merge --no-ff → 清理 worktree/分支
```

---

## Self-Review 记录

- Spec 覆盖：§5 M2 → Task 1-5 ✓（P3a 迁移辅助脚本 + 62 文件落地 + P3b 台账脚本 + Step 4.5 改写 + CI）；§9 测试 → Task 1/3 双态测试 + Task 5 全量回归 ✓。
- 红线遵守：framework-evidence.sh 只产 evidence + SUGGEST（启发式），不替模型做适用/不适用判断；framework-knowledge.md 规律骨架仍由模型在 Step 4.5 构建 ✓。
- 不破坏现有：verify 块是 §3 条目下新增内容，verify-framework-ruleset.sh 的 `grep -c '^### 规律'` 计数与「对应门禁/人工检查」扫描不受影响（Task 2 Step 4 验证）✓。
- bash 3.2 quirk：赋值全用裸 comsub；evidence 段用 `sed -E 's|^...||'` 处理路径，无 `$VAR`+多字节紧邻 ✓。
- fail-open：框架文件缺失 → NO_RULE_FILE 行 + continue；无 ACTIVE_FRAMEWORKS → 空台账 exit 0 ✓。
- 确定性：evidence top-N 按 `sort` 截断，两次连跑 byte-identical（态 3 测试）✓。
- P3a/P3b 拆分：spec §10 允许 P3 拆 P3a 格式迁移 / P3b 脚本；本计划 Task 1-2=P3a，Task 3-5=P3b，可在同一 worktree 内顺序完成 ✓。
- 占位符扫描：verify 块的 `${PROJECT_DIR}` 是 eval 替换占位（脚本 sed 替换为实参），非设计占位。
