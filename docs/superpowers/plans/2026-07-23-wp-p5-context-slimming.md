# WP-P5 目标 skill 上下文裁剪（spec-template 节门控 + UNIVERSAL_FILES profile 分级）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 spec `docs/superpowers/specs/2026-07-23-generation-toolization-design.md` §8（M5）：保守裁剪目标 skill 使用期上下文——(a) spec-template §14–§18 认知/辩证法/领域节按 profile 门控（lite/standard 默认只发核心节，compliance 保留全部）；(b) UNIVERSAL_FILES 引用清单 profile 分级（core 三档都拷 / standard / compliance-only / lite 进一步收窄）；(c) 生成产物 SKILL.md 的「按需读取」索引表由 generate-skill.sh 依据分级清单自动生成。**保守原则：不删能力只分层。**

**Architecture:**
- **spec-template 节门控**：模板拆为核心节（§1-§13 + §19-§23）+ 认知扩展包（§14-§18）。generate-skill.sh 按 profile 决定是否拷入扩展包节：lite/standard 默认不发 §14-§18（节不存在 → `check_cognition` SKIP 并如实披露，沿用 WP-F SKIPPED 诚实原则）；compliance 保留全部。
- **UNIVERSAL_FILES profile 分级**：现有清单已有 `|<最低 profile 档>` 第三段（lite/standard/compliance）。补齐分级：core（三档都拷，已标 lite）/ standard / compliance-only（已标 compliance）/ lite 进一步收窄（WP-E 已做部分，补齐 cognition-framework.md / logic-razor.md / cognitive-bias.md 标 standard，lite 不拷）。
- **「按需读取」索引表自动生成**：generate-skill.sh create 模式依据实际拷入的 UNIVERSAL_FILES 清单生成 SKILL.md 的引用索引表（避免手写漂移）。
- **check_cognition 适配**：节不存在 → SKIP 并如实披露（不 fail，不静默）。

**Tech Stack:** bash 3.2（三 OS），无新增依赖。

**Spec:** `docs/superpowers/specs/2026-07-23-generation-toolization-design.md` §8（M5）、§9（测试）、§10（WP 分解，无依赖可独立做）。

## Global Constraints

- bash 3.2 兼容：禁 `declare -A`；`sed -i.bak` + `rm` 模式；正则用 `grep -E`/`sed -E`（BSD 兼容）；三 OS（macOS/Linux/Windows Git Bash）可跑。
- Repo-confirmed bash 3.2.57 quirks（两条都必须遵守）：
  1. `"` 紧贴 `)` 在引号命令替换内会解析失败 → 赋值用裸命令替换 `x=$(cmd "$VAR")`（不写 `x="$(cmd "$VAR")"`）。
  2. `$VAR` 紧跟多字节字符在双引号串内会误词法 → 多字节字符前用 `${VAR}` 花括号。
- 生成类脚本 fail-open：缺文件跳过 exit 0（arg 错误 exit 1）。
- 输出确定性：同输入字节级一致，可进 cli-ab byte-diff。
- 新脚本进 CI shellcheck 严格名单（`.github/workflows/ci.yml` Job4）。
- 分支纪律：一个 worktree（`.claude/worktrees/feat-wp-p5-context-slimming`，从 origin/main 起），收口 `merge --no-ff`。
- run-verifier.sh all 全绿是合入门槛（metrics/sensitive gate-fixtures 预存失败披露即可）。
- **保守原则（spec §11）**：不删除 spec-template §14–§18 能力，只做 profile 分层；compliance profile 保留全部节。
- **不破坏现有**：`check_cognition` 是 advisory-only（0 fail()），节不存在 → SKIP 披露，不引入新 fail；UNIVERSAL_FILES 已有第三段语法的条目不回归。
- **红线**：profile 是显式声明不启用某节/文件，与「未配置静默跳过」本质不同（spec §8）；SKIP 必须如实披露。

---

## Task 1: UNIVERSAL_FILES profile 分级补齐

**Files:**
- Modify: `swarm-yuan/scripts/generate-skill.sh:45-85`（UNIVERSAL_FILES 数组）

**Interfaces:**
- 现有清单第三段语义：lite(1)<standard(2)<compliance(3)，无第三段=standard。补齐：认知三件套（cognition-framework.md / logic-razor.md / cognitive-bias.md）从无档（=standard）显式标 `standard`，lite 不拷；standards-compliance.md 已标 compliance 不动。

- [ ] **Step 1: 定位 UNIVERSAL_FILES 认知三件套行**

Run: `cd swarm-yuan && grep -n "cognition-framework\|logic-razor\|cognitive-bias" scripts/generate-skill.sh`
Expected: 三行在 UNIVERSAL_FILES 内（约 :79-81），当前无第三段（=standard）

- [ ] **Step 2: Edit — 三件套显式标 standard**

old_string（三行，无第三段）：

```
  "references/cognition-framework.md|ref"
  "references/logic-razor.md|ref"
  "references/cognitive-bias.md|ref"
```

new_string：

```
  "references/cognition-framework.md|ref|standard"
  "references/logic-razor.md|ref|standard"
  "references/cognitive-bias.md|ref|standard"
```

（语义不变——无第三段本就=standard——但显式标注让 lite 收窄意图可读，且为 Task 2 节门控对齐。）

- [ ] **Step 3: 验证 lite profile 不拷认知三件套**

Run: `cd swarm-yuan && bash scripts/generate-skill.sh demolite tests/fixtures/gin --profile lite 2>&1 | grep -c 'cognition-framework' ; ls tests/fixtures/gin/.claude/skills/demolite/references/ 2>/dev/null | grep -c 'cognition\|logic-razor\|cognitive-bias'`
Expected: 两计数均为 0（lite 不拷三件套）

- [ ] **Step 4: Commit**

```bash
git add swarm-yuan/scripts/generate-skill.sh
git commit -m "feat(wp-p5): UNIVERSAL_FILES 认知三件套显式标 standard（lite 收窄）"
```

---

## Task 2: spec-template §14-§18 节门控（profile 分层）

**Files:**
- Modify: `swarm-yuan/assets/spec-template.md`（§14-§18 加门控标记注释）
- Modify: `swarm-yuan/scripts/generate-skill.sh`（create 模式按 profile 裁剪 spec-template 拷贝）
- Test: `swarm-yuan/tests/test-spec-template-gating.sh`

**Interfaces:**
- spec-template.md §14-§18 节首加门控标记 `<!-- profile-gate: standard+ (lite 跳过) -->`；generate-skill.sh create 模式拷 spec-template 时，lite/standard profile 用 awk 裁掉带该标记的节（从 `## §14` 到下一个 `## §19` 之前），compliance 保留全部。
- 节被裁 → `check_cognition` SKIP 披露（Task 3）。

- [ ] **Step 1: spec-template.md §14-§18 加门控标记**

在 `## 14. ★交付衰减分析` 行前插入：
```
<!-- profile-gate: standard+ (compliance 保留；lite/standard 跳过 §14-§18 认知扩展包，节不存在 → check_cognition SKIP 披露) -->
```
（§15-§18 共享这一个标记，因门控范围是 §14-§18 整体；标记放 §14 首行前即可，awk 按 `## §14` 起 `## §19` 止裁剪。）

- [ ] **Step 2: 写失败测试**

Create `swarm-yuan/tests/test-spec-template-gating.sh`:

```bash
#!/usr/bin/env bash
# test-spec-template-gating.sh — spec-template §14-18 profile 门控测试（WP-P5/M5）
set -uo pipefail
cd "$(dirname "${0}")/.."
TMP="$(mktemp -d /tmp/stgtest.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

# 态 1：lite profile 生成的 skill 的 spec-template 无 §14-§18
bash scripts/generate-skill.sh demolite tests/fixtures/gin --profile lite >/dev/null 2>&1
tpl="$PWD/tests/fixtures/gin/.claude/skills/demolite/assets/spec-template.md"
[[ -f "$tpl" ]] && ok "lite spec-template 落盘" || bad "lite spec-template 缺失"
grep -q '## 14\. ★交付衰减分析' "$tpl" && bad "lite 不应含 §14" || ok "lite 无 §14"
grep -q '## 19\. ★测试左移' "$tpl" && ok "lite 保留 §19" || bad "lite 缺 §19"
grep -q '## 13\. 参考资料' "$tpl" && ok "lite 保留 §13" || bad "lite 缺 §13"

# 态 2：compliance profile 保留 §14-§18
bash scripts/generate-skill.sh democomp tests/fixtures/gin --profile compliance >/dev/null 2>&1
tplc="$PWD/tests/fixtures/gin/.claude/skills/democomp/assets/spec-template.md"
grep -q '## 14\. ★交付衰减分析' "$tplc" && ok "compliance 含 §14" || bad "compliance 缺 §14"
grep -q '## 18\. ★领域知识约束' "$tplc" && ok "compliance 含 §18" || bad "compliance 缺 §18"

# 态 3：门控标记注释不泄漏到产物（裁剪后 lite 产物无 profile-gate 注释）
grep -q 'profile-gate' "$tpl" && bad "lite 产物残留门控注释" || ok "lite 无门控注释残留"

# 清理生成产物
rm -rf tests/fixtures/gin/.claude/skills/demolite tests/fixtures/gin/.claude/skills/democomp

[[ $FAIL -eq 0 ]] && { echo "PASS test-spec-template-gating"; exit 0; } || { echo "FAIL test-spec-template-gating" >&2; exit 1; }
```

- [ ] **Step 3: 跑测试确认失败**

Run: `bash swarm-yuan/tests/test-spec-template-gating.sh`
Expected: FAIL（lite 产物仍含 §14，未裁剪）

- [ ] **Step 4: 实现 — generate-skill.sh create 模式裁剪逻辑**

在 create 模式拷 spec-template.md 到目标 skill 处，改为按 profile 裁剪。定位拷贝行后，替换为：
```bash
# WP-P5: spec-template §14-§18 认知扩展包按 profile 门控
# lite/standard 裁掉 §14-§18（节不存在 → check_cognition SKIP 披露）；compliance 保留全部
local _tpl="$paradigm_dir/assets/spec-template.md"
local _dst="$skill_dir/assets/spec-template.md"
if [[ "$PROFILE" == "compliance" ]]; then
  cp "$_tpl" "$_dst"
else
  # awk 裁剪：跳过 §14 起 §19 止的行（含门控注释），其余原样
  awk '
    /^<!-- profile-gate: standard\+/{ skip=1; next }
    /^## 14\. /{ skip=1 }
    /^## 19\. /{ skip=0 }
    !skip { print }
  ' "$_tpl" > "$_dst"
fi
```
（具体 old_string 由定位的拷贝行决定。）

- [ ] **Step 5: 跑测试确认通过**

Run: `bash swarm-yuan/tests/test-spec-template-gating.sh`
Expected: `PASS test-spec-template-gating`

- [ ] **Step 6: Commit**

```bash
git add swarm-yuan/assets/spec-template.md swarm-yuan/scripts/generate-skill.sh swarm-yuan/tests/test-spec-template-gating.sh
git commit -m "feat(wp-p5): spec-template §14-18 认知扩展包 profile 门控（lite/standard 裁剪，compliance 保留）"
```

---

## Task 3: check_cognition 适配 — 节不存在 SKIP 披露

**Files:**
- Modify: `swarm-yuan/assets/gates-advisory.sh`（check_cognition 函数，节缺失 → SKIP 披露）

**Interfaces:**
- `check_cognition` 当前是 advisory-only（0 fail()），关键词计分。适配：检测 spec/特征卡是否含 §14-§18 节，缺失 → 打印 `⊘ SKIP: 认知扩展包 §14-§18 未启用（profile=lite/standard，节不存在）` 并 return（不 fail，不静默）。

- [ ] **Step 1: 定位 check_cognition 函数**

Run: `cd swarm-yuan && grep -n "check_cognition\|认知" assets/gates-advisory.sh | head -5`
Expected: 找到 check_cognition 函数行号

- [ ] **Step 2: Edit — check_cognition 函数开头加节存在性判定**

在 check_cognition 函数体开头（`echo "=== ..."` 之前）插入：
```bash
  # WP-P5: 认知扩展包 §14-§18 按 profile 门控——节不存在 → SKIP 披露（不 fail，不静默）
  # spec-template.md（目标 skill 的 assets/ 下或 SKILL_DIR 下）无 §14 → profile=lite/standard 裁剪了
  local _st="${SKILL_DIR:-$PWD}/assets/spec-template.md"
  [[ -f "$_st" ]] || _st="$PWD/spec-template.md"
  if [[ -f "$_st" ]] && ! grep -q '^## 14\.' "$_st" 2>/dev/null; then
    echo "=== 认知检查（check_cognition）==="
    echo "  ⊘ SKIP: 认知扩展包 §14-§18 未启用（profile=lite/standard，spec-template 已裁剪该节）"
    pass "认知检查 SKIP（profile 门控，节不存在）"
    return
  fi
```

- [ ] **Step 3: 验证 lite skill 跑 check_cognition → SKIP**

Run: `cd swarm-yuan && bash scripts/generate-skill.sh demot tests/fixtures/gin --profile lite >/dev/null 2>&1 && (cd tests/fixtures/gin/.claude/skills/demot && bash scripts/precheck.sh --cognition 2>&1 | grep -E 'SKIP|认知') ; rm -rf tests/fixtures/gin/.claude/skills/demot`
Expected: 输出含 `⊘ SKIP` 与「认知检查 SKIP」

- [ ] **Step 4: Commit**

```bash
git add swarm-yuan/assets/gates-advisory.sh
git commit -m "feat(wp-p5): check_cognition 节不存在 SKIP 披露（profile 门控适配，不 fail 不静默）"
```

---

## Task 4: SKILL.md「按需读取」索引表自动生成

**Files:**
- Modify: `swarm-yuan/scripts/generate-skill.sh`（create 模式生成 SKILL.md 后，依据实际拷入的 UNIVERSAL_FILES 清单生成索引表段）

**Interfaces:**
- 生成产物 SKILL.md 的「按需读取」引用索引表由 generate-skill.sh 依据分级清单自动生成（避免手写漂移）：表列 `文件 | 用途 | profile 档`，按 UNIVERSAL_FILES 实际拷入项填充。

- [ ] **Step 1: 定位 SKILL.md 生成/拷贝处**

Run: `cd swarm-yuan && grep -n "SKILL.md\|按需读取\|引用索引" scripts/generate-skill.sh | head -8`
Expected: 找到 SKILL.md 生成或模板拷贝处

- [ ] **Step 2: Edit — create 模式生成索引表段**

在 create 模式拷完 UNIVERSAL_FILES 后、写 SKILL.md 前，插入索引表生成：
```bash
# WP-P5: SKILL.md「按需读取」索引表自动生成（依据实际拷入的 UNIVERSAL_FILES 分级清单）
_idx_file="$skill_dir/.universal-files-index.md"
{
  echo "## 按需读取引用索引（自动生成，勿手改——由 generate-skill.sh 依据 profile 档生成）"
  echo ""
  echo "| 文件 | 用途 | profile 档 |"
  echo "|------|------|-----------|"
  for entry in "${UNIVERSAL_FILES[@]}"; do
    _path=${entry%%|*}; _rest=${entry#*|}; _cat=${_rest%%|*}; _tier=${_rest#*|}
    [[ "$_tier" == "$_rest" ]] && _tier="standard"
    # 按 profile 档过滤（档序 lite<standard<compliance，已由拷贝逻辑保证存在性，这里只列已拷入的）
    [[ -f "$skill_dir/$_path" ]] || continue
    printf '| %s | %s | %s |\n' "$_path" "$_cat" "$_tier"
  done
} > "$_idx_file"
# 追加到 SKILL.md 末尾（若 SKILL.md 是模板拷贝，append；若生成，在生成逻辑末尾 cat）
[[ -f "$skill_dir/SKILL.md" ]] && cat "$_idx_file" >> "$skill_dir/SKILL.md" && rm -f "$_idx_file"
```

- [ ] **Step 3: 验证生成的 SKILL.md 含索引表**

Run: `cd swarm-yuan && bash scripts/generate-skill.sh demoidx tests/fixtures/gin --profile standard >/dev/null 2>&1 && grep -c '按需读取引用索引' tests/fixtures/gin/.claude/skills/demoidx/SKILL.md ; rm -rf tests/fixtures/gin/.claude/skills/demoidx`
Expected: 计数 ≥1（索引表段存在）

- [ ] **Step 4: Commit**

```bash
git add swarm-yuan/scripts/generate-skill.sh
git commit -m "feat(wp-p5): SKILL.md 按需读取索引表自动生成（依据 UNIVERSAL_FILES 分级清单）"
```

---

## Task 5: WP-P5 CI 接线 + 全量回归 + 收口

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: ci.yml Edit — self-check job 测试步骤**

old_string（WP-P0~P4 测试步骤块名）：

```yaml
      - name: 计量/信号/维度/框架证据/conf 渲染测试（WP-P0~P4）
```

new_string：

```yaml
      - name: 计量/信号/维度/框架证据/conf/上下文裁剪测试（WP-P0~P5）
```

并在该 step 的 run 块末尾追加：
```yaml
          bash tests/test-spec-template-gating.sh
```

（注：WP-P5 无新增独立脚本进 shellcheck 严格层——改的是 generate-skill.sh 与 gates-advisory.sh，已在严格层。）

- [ ] **Step 2: 本地全量回归**

Run:
```bash
cd swarm-yuan
bash tests/test-spec-template-gating.sh
# 上下文表面计量对比：lite vs standard vs compliance 的 skill 加载面
bash scripts/generate-skill.sh demolite tests/fixtures/gin --profile lite >/dev/null 2>&1
bash scripts/generate-skill.sh demostd tests/fixtures/gin --profile standard >/dev/null 2>&1
bash scripts/context-surface.sh --skill tests/fixtures/gin/.claude/skills/demolite | tail -1
bash scripts/context-surface.sh --skill tests/fixtures/gin/.claude/skills/demostd | tail -1
rm -rf tests/fixtures/gin/.claude/skills/demolite tests/fixtures/gin/.claude/skills/demostd
bash ../verifier/v1/run-verifier.sh all
```
Expected: 测试 PASS；lite TOTAL 字节数 < standard TOTAL（裁剪效果，作为 WP-P6 before/after 证据）；verifier 全绿（metrics/sensitive 预存失败披露）

- [ ] **Step 3: Commit 并收口 WP-P5**

```bash
git add .github/workflows/ci.yml
git commit -m "ci(wp-p5): spec-template 门控测试进 CI；上下文裁剪 lite<TOTAL 对比"
# rebase origin/main → push → main merge --no-ff → 清理 worktree/分支
```

---

## Self-Review 记录

- Spec 覆盖：§8 M5 → Task 1-5 ✓（UNIVERSAL_FILES 分级补齐 + spec-template §14-18 门控 + check_cognition SKIP 适配 + 索引表自动生成 + CI）；§9 测试 → Task 2 双态测试 + Task 5 全量回归 + 上下文表面对比 ✓。
- 保守原则遵守：不删 §14-§18 能力，只做 profile 分层；compliance 保留全部节（Task 2 态 2 验证）✓。
- 不破坏现有：check_cognition 是 advisory-only，节缺失 → SKIP 披露不引入新 fail（Task 3）；UNIVERSAL_FILES 已有第三段语法的条目不回归（Task 1 只补齐三件套显式标注）✓。
- bash 3.2 quirk：赋值全用裸 comsub；awk 裁剪脚本无 `$VAR`+多字节紧邻 ✓。
- fail-open：缺 spec-template → check_cognition 不崩；generate-skill 缺文件跳过 ✓。
- 确定性：索引表按 UNIVERSAL_FILES 数组顺序输出，两次连跑一致 ✓。
- 红线：profile 是显式声明不启用，SKIP 如实披露（不静默跳过）✓。
- 占位符扫描：无运行期待填占位；门控注释 `<!-- profile-gate: ... -->` 是设计性标记，裁剪后不泄漏到产物（Task 2 态 3 验证）。
