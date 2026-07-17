# swarm-yuan 框架规则引擎实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 swarm-yuan 范式新增"框架规则引擎"——~56 框架规则库 + 门禁片段库 + 生成时注入机制 + 四要素量化验收闭环，根治生成的目标 skill 对特定框架适应性不足的问题。

**Architecture:** 范式侧新增 `references/frameworks/`（规则库，六段式/框架）与 `assets/framework-gates/`（门禁片段库）；模板 `precheck.sh` 内置 `check_framework()` 动态分发器 + 标记区块；`generate-skill.sh --inject-frameworks` 按目标项目 ACTIVE_FRAMEWORKS 幂等注入片段；ncwk-dev 已验证的 7 个手写门禁反哺为片段库种子并回灌验证零回归。

**Tech Stack:** bash 3.2+（三平台兼容）、markdown 规则库、WebSearch/WebFetch 官方文档调研。

**Spec:** `docs/2026-07-17-framework-rules-engine-design.md`（同仓库）

**仓库与分支:** `/Volumes/nvme2230/lab/Swarm-yuan`，分支 `feat/framework-rules-engine`

## Global Constraints

- **三平台兼容铁律**：不用 `declare -A`；`sed -i.bak+rm`；`grep -E`；`date -u`；`$(cd+pwd)` 替代 `readlink -f`；`wc|xargs`；`${var}` 防 C-locale
- **函数命名约定**：`_fw_<ruleset_id>_check`，ruleset_id 连字符转下划线（`spring-boot` → `_fw_spring_boot_check`）；片段文件名保留连字符（`spring-boot.sh`）
- **门禁 id 约定**：`fw_<ruleset_id>_<rule>`（id 中一律用下划线）
- **conf 变量约定**：`<RULESET_ID>_<VAR>`（RULESET_ID 全大写、连字符转下划线，如 `MYBATIS_MAPPER_DIRS`）
- **零占位符**：任何产出文件不得残留"待填充"/`<占位符>`（conf 注入占位除外，须同时 warn）
- **不自动推送 GitHub**；推送前须脱敏检查并经用户确认
- 每任务完成后按步骤 commit 到 `feat/framework-rules-engine`
- 收割来源：`/Volumes/nvme2230/lab/ncwk/.claude/skills/ncwk-dev/scripts/precheck.sh`（下称 `$NCWK_PRECHECK`）
- 已安装范式副本：`/Users/cuishi/.claude/skills/swarm-yuan/`（经 `install.sh` 同步）

---

### Task 1: precheck.sh 模板内置框架调度器 + 收割 ncwk-dev 7 门禁片段

**Files:**
- Create: `assets/framework-gates/vue.sh` `naiveui.sh` `pinia.sh` `koa.sh` `socketio.sh` `vite.sh` `vitest.sh`
- Modify: `assets/precheck.sh`（新增 check_framework/公共函数/标记区块/dispatch 项）

**Interfaces:**
- Produces: `check_framework()`（遍历 `ACTIVE_FRAMEWORKS`，动态分发 `_fw_<id>_check`）；`_fw_resolve_globs <globs...>`（stdout 文件列表）；`_fw_grep_count <pattern> <files...>`（stdout 计数）；7 个 `_fw_<id>_check` 片段函数。后续所有任务依赖这些名字。

- [ ] **Step 1: 收割 7 个门禁函数与 2 个公共函数（按精确行号提取）**

```bash
cd /Volumes/nvme2230/lab/Swarm-yuan
NCWK=/Volumes/nvme2230/lab/ncwk/.claude/skills/ncwk-dev/scripts/precheck.sh
mkdir -p assets/framework-gates
# 函数行号区间（已实测核对）：
#   _fw_resolve_globs 2431-2447  _fw_grep_count 2448-2453
#   vue 2454-2509  naiveui 2510-2535  pinia 2536-2555  koa 2556-2581
#   socketio 2582-2601  vite 2602-2632  vitest 2633-2654
sed -n '2454,2509p' "$NCWK"  > /tmp/fw_vue.body
sed -n '2510,2535p' "$NCWK"  > /tmp/fw_naiveui.body
sed -n '2536,2555p' "$NCWK"  > /tmp/fw_pinia.body
sed -n '2556,2581p' "$NCWK"  > /tmp/fw_koa.body
sed -n '2582,2601p' "$NCWK"  > /tmp/fw_socketio.body
sed -n '2602,2632p' "$NCWK"  > /tmp/fw_vite.body
sed -n '2633,2654p' "$NCWK"  > /tmp/fw_vitest.body
sed -n '2431,2453p' "$NCWK"  > /tmp/fw_helpers.body
# 核验：每个 body 首行是函数定义、末行是 }
head -1 /tmp/fw_vue.body    # 期望: _fw_vue_check() {
tail -1 /tmp/fw_vitest.body # 期望: }
```

- [ ] **Step 2: 为每个片段加契约头，生成片段文件**

以 vue 为例（其余 6 个照此模式，requires_conf 值取下表）：

```bash
{
  echo '# ruleset: vue  requires_conf: VUE_FILE_GLOBS VUE_REQUIRE_SCRIPT_SETUP VUE_VHTML_SANITIZE_REQUIRED'
  echo '# gates: fw_vue_setup(fail) fw_vue_reactivity(warn) fw_vue_vhtml_sanitize(fail) fw_vue_vfor_key(warn)'
  echo '# harvested-from: ncwk-dev precheck.sh:2454-2509 (2026-07-17)'
  cat /tmp/fw_vue.body
  echo ''
} > assets/framework-gates/vue.sh
```

| 片段 | requires_conf（从 ncwk-dev precheck.conf 实测） | gates |
|------|------|-------|
| naiveui | `NAIVEUI_FILE_GLOBS NAIVEUI_NAMED_IMPORT_REQUIRED` | fw_naiveui_named_import(fail) fw_naiveui_injection(fail) fw_naiveui_no_dual_ui(fail) |
| pinia | `PINIA_FILE_GLOBS PINIA_DEFINESTORE_REQUIRED` | fw_pinia_ownership(fail) fw_pinia_alias(fail) |
| koa | `KOA_FILE_GLOBS KOA_ROUTER_FACTORY_REQUIRED` | fw_koa_router_factory(fail) fw_koa_patch_inject(fail) fw_koa_input_validate(fail) |
| socketio | `SOCKETIO_FILE_GLOBS SOCKETIO_NAMESPACE_REQUIRED` | fw_socketio_namespace(fail) fw_socketio_patch_inject(fail) |
| vite | `VITE_ALIAS_ARRAY_FORM_REQUIRED VITE_ALIAS_ORDER_REQUIRED` | fw_vite_alias_order(fail) fw_vite_inject_idempotent(fail) |
| vitest | （函数体内引用的 conf 变量，收割时核对补齐） | fw_vitest_location(fail) fw_vitest_no_upstream_test(fail) |

注意：gates 列表须逐函数体核对（`grep -o 'fw_[a-z_]*' /tmp/fw_*.body`），以函数体内实际检查为准修正上表。

- [ ] **Step 3: 在模板 precheck.sh 中插入框架段**

在 `assets/precheck.sh` 的 `check_shift_left()` 结束之后（约 2408 行，即 case 分发 `--all)` 之前）插入：

```bash
# ===== 框架适配门禁（--framework）：由 --inject-frameworks 注入片段，动态分发 =====
check_framework() {
  echo "▶ 框架适配门禁 (--framework)"
  if [[ ${#ACTIVE_FRAMEWORKS[@]} -eq 0 ]]; then
    # 漏配检测：探查信号明显但未配置 → warn
    local hit
    hit=$(find "${PROJECT_DIR:-.}" -name '*Mapper.xml' -not -path '*/node_modules/*' 2>/dev/null | head -1)
    [[ -n "$hit" ]] && warn "发现 $hit 但 ACTIVE_FRAMEWORKS 未配置——疑似漏配 mybatis"
    skip_if_unconfigured "ACTIVE_FRAMEWORKS 未配置"; return
  fi
  local fw fn
  for fw in "${ACTIVE_FRAMEWORKS[@]}"; do
    fn="_fw_$(echo "$fw" | tr '-' '_')_check"
    if declare -f "$fn" >/dev/null 2>&1; then
      "$fn"
    else
      fail "框架 '$fw' 已激活但无门禁实现（$fn 缺失）——须运行 generate-skill.sh --inject-frameworks"
    fi
  done
}

# >>> swarm-yuan:framework-gates >>> （由 generate-skill.sh --inject-frameworks 维护，勿手改）
# <<< swarm-yuan:framework-gates <<<
```

并在其后紧跟插入 `_fw_resolve_globs` 与 `_fw_grep_count`（来自 `/tmp/fw_helpers.body`，注意放在标记区块**之外**——公共函数属模板本体，不被注入替换）。

dispatch 处修改三处：

```bash
# 1) --all-full) 列表中 check_shift_left 之后、check_test 之前加：
    check_framework
# 2) 单命令 case 中加：
  --framework) check_framework ;;
# 3) Usage 串中 --shift-left 后加 |--framework
```

- [ ] **Step 4: 语法与冒烟验证**

```bash
bash -n assets/precheck.sh && echo "syntax OK"
for f in assets/framework-gates/*.sh; do bash -n "$f" || echo "SYNTAX FAIL: $f"; done
# 冒烟：构造最小环境实跑
mkdir -p /tmp/fw-smoke && cd /tmp/fw-smoke
cat > precheck.conf <<'EOF'
PROJECT_DIR="/tmp/fw-smoke"
ACTIVE_FRAMEWORKS=("vue")
VUE_FILE_GLOBS=("src/**/*.vue")
VUE_REQUIRE_SCRIPT_SETUP=1
VUE_VHTML_SANITIZE_REQUIRED=1
EOF
mkdir -p src && printf '<template><div/></template>\n<script setup>\n</script>\n' > src/a.vue
# 把 7 片段之一 + 模板拼合实跑（模拟注入）：
cp /Volumes/nvme2230/lab/Swarm-yuan/assets/precheck.sh scripts_precheck.sh
# 手动将 vue.sh 内容贴入标记区块后：
bash scripts_precheck.sh --framework
# 期望输出: ▶ 框架适配门禁 (--framework) → [vue] ... → pass/fail 明确，非"未知命令"
```

- [ ] **Step 5: Commit**

```bash
cd /Volumes/nvme2230/lab/Swarm-yuan
git add assets/framework-gates/ assets/precheck.sh
git commit -m "feat: precheck 模板内置 check_framework 动态分发器 + 收割 ncwk-dev 7 门禁片段"
```

---

### Task 2: generate-skill.sh `--inject-frameworks` 注入机制

**Files:**
- Modify: `scripts/generate-skill.sh`

**Interfaces:**
- Consumes: Task 1 的片段库与标记区块；目标 skill 的 `scripts/precheck.conf` 中 `ACTIVE_FRAMEWORKS`
- Produces: `inject_frameworks <skill_dir>` 函数（幂等）；`.swarm-yuan-version` 中记录 `framework_gates_sha`。Task 5/10 依赖。

- [ ] **Step 1: 实现注入函数（追加到 generate-skill.sh 主体函数区）**

```bash
# inject_frameworks <skill_dir>：按目标 conf 的 ACTIVE_FRAMEWORKS 幂等注入门禁片段
inject_frameworks() {
  local skill_dir="$1"
  local paradigm_dir="$(cd "$(dirname "$0")/.." && pwd)"
  local sh="$skill_dir/scripts/precheck.sh"
  local conf="$skill_dir/scripts/precheck.conf"
  local ver="$skill_dir/.swarm-yuan-version"
  [[ -f "$sh" ]] || { echo "✗ 未找到 $sh"; return 1; }

  ACTIVE_FRAMEWORKS=()
  [[ -f "$conf" ]] && . "$conf"
  if [[ ${#ACTIVE_FRAMEWORKS[@]} -eq 0 ]]; then
    echo "⚠ ACTIVE_FRAMEWORKS 未配置，跳过门禁注入"; return 0
  fi

  # 1) 构建新区块 + 校验 requires_conf
  local block; block="$(mktemp /tmp/fwblock.XXXXXX)"
  local uncovered=() missing_conf=()
  echo '# >>> swarm-yuan:framework-gates >>> （由 generate-skill.sh --inject-frameworks 维护，勿手改）' > "$block"
  local fw frag req var
  for fw in "${ACTIVE_FRAMEWORKS[@]}"; do
    frag="$paradigm_dir/assets/framework-gates/$fw.sh"
    if [[ -f "$frag" ]]; then
      cat "$frag" >> "$block"
      for req in $(sed -n 's/^# ruleset:.*requires_conf: *//p' "$frag"); do
        for var in $req; do
          grep -q "^${var}=" "$conf" 2>/dev/null || missing_conf+=("$var")
        done
      done
    else
      uncovered+=("$fw")
    fi
  done
  echo '# <<< swarm-yuan:framework-gates <<<' >> "$block"

  # 2) 幂等替换标记区块（awk 三平台兼容）
  local tmp; tmp="$(mktemp /tmp/fwprecheck.XXXXXX)"
  awk -v blockfile="$block" '
    /^# >>> swarm-yuan:framework-gates >>>/ { while ((getline l < blockfile) > 0) print l; skip=1; next }
    /^# <<< swarm-yuan:framework-gates <<</ { skip=0; next }
    !skip { print }
  ' "$sh" > "$tmp" && cat "$tmp" > "$sh"
  rm -f "$tmp"

  # 3) 缺失 conf 变量：注入占位 + warn（不静默）
  for var in ${missing_conf[@]+"${missing_conf[@]}"}; do
    printf '%s=()  # TODO(framework-gates): 由生成流程 Step 7.5 填充\n' "$var" >> "$conf"
    echo "⚠ conf 缺失变量 $var，已注入占位（须填充）"
  done

  # 4) 未覆盖框架：warn 列出（不静默跳过）
  for fw in ${uncovered[@]+"${uncovered[@]}"}; do
    echo "⚠ 框架 '$fw' 无对应门禁片段（references/frameworks/$fw.md 缺失）——列入未覆盖清单"
  done

  # 5) 记录区块哈希（供冲突检测）
  local sha
  sha=$(sed -n '/^# >>> swarm-yuan:framework-gates >>>/,/^# <<< swarm-yuan:framework-gates <<</p' "$sh" | cksum | awk '{print $1}')
  { echo "framework_gates_injected_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "framework_gates_sha=$sha"; } >> "$ver"
  echo "✓ 门禁片段注入完成（${#ACTIVE_FRAMEWORKS[@]} 个框架，区块 sha=$sha）"
}
```

冲突检测（手改裁决）：替换前比较现有区块 `cksum` 与 `.swarm-yuan-version` 中 `framework_gates_sha`，不一致且非空 → 输出"区块被手改，须用户裁决覆盖/保留"并 `return 2`。

- [ ] **Step 2: 接入命令行**

在 generate-skill.sh 的参数分发处新增：

```bash
  --inject-frameworks) inject_frameworks "$2" ;;
```

并在 `--upgrade` 流程末尾追加 `inject_frameworks "$SKILL_DIR"`（升级自动重注入）。

- [ ] **Step 3: 幂等与异常测试**

```bash
cd /Volumes/nvme2230/lab/Swarm-yuan
# 构造 fixture 目标 skill
mkdir -p /tmp/fw-target/scripts
cp assets/precheck.sh /tmp/fw-target/scripts/precheck.sh
cat > /tmp/fw-target/scripts/precheck.conf <<'EOF'
PROJECT_DIR="/tmp/fw-target"
ACTIVE_FRAMEWORKS=("vue" "mybatis")
EOF
bash scripts/generate-skill.sh --inject-frameworks /tmp/fw-target
# 断言1: vue 函数已注入
grep -c '_fw_vue_check' /tmp/fw-target/scripts/precheck.sh   # 期望 ≥2（定义+分发探测处）
# 断言2: mybatis 无片段 → warn 未覆盖（此时 mybatis.sh 尚未建）
# 断言3: 幂等——再跑一次，diff 无变化
cp /tmp/fw-target/scripts/precheck.sh /tmp/run1.sh
bash scripts/generate-skill.sh --inject-frameworks /tmp/fw-target
diff /tmp/run1.sh /tmp/fw-target/scripts/precheck.sh && echo "幂等 OK"
# 断言4: bash -n 通过
bash -n /tmp/fw-target/scripts/precheck.sh && echo "syntax OK"
```

- [ ] **Step 4: Commit**

```bash
git add scripts/generate-skill.sh
git commit -m "feat: generate-skill --inject-frameworks 幂等注入门禁片段（含 requires_conf 校验/冲突裁决/未覆盖清单）"
```

---

### Task 3: 规则文件模板 + 范式侧四要素核验脚本 + 信号索引生成脚本 + conf 通用化

**Files:**
- Create: `references/frameworks/_template.md`
- Create: `scripts/verify-framework-ruleset.sh`
- Create: `scripts/gen-framework-index.sh`
- Modify: `assets/precheck.conf`

**Interfaces:**
- Produces: `verify-framework-ruleset.sh <ruleset_id>`（exit 0/1，供 Task 6-11 每个框架任务调用）；`gen-framework-index.sh`（重写 exploration-guide.md §C+.0.5 信号索引标记区块）

- [ ] **Step 1: 写 `references/frameworks/_template.md`**

完整内容 = 设计文档 §4.1 的六段式结构（frontmatter: ruleset_id/适用版本/最后调研/深度门槛 + §1 探查信号 + §2 构件枚举 + §3 领域规律五要素 + §4 门禁清单 + §5 跨框架交互 + §6 版本陷阱），顶部附"使用说明：复制本模板为 <fw>.md，逐段填充，硬约束见设计文档 §4.1 三条"。

- [ ] **Step 2: 写 `scripts/verify-framework-ruleset.sh`**

```bash
#!/usr/bin/env bash
# 用法: verify-framework-ruleset.sh <ruleset_id>  —— 范式侧四要素机械核验
set -u
BASE="$(cd "$(dirname "$0")/.." && pwd)"
ID="$1"
FN="_fw_$(echo "$ID" | tr '-' '_')_check"
RULE="$BASE/references/frameworks/$ID.md"
GATE="$BASE/assets/framework-gates/$ID.sh"
FAIL=0
err() { echo "✗ $1"; FAIL=1; }
ok()  { echo "✓ $1"; }

[[ -f "$RULE" ]] || { err "规则文件缺失: $RULE"; exit 1; }
[[ -f "$GATE" ]] || err "门禁片段缺失: $GATE"

# 要素2: §3 规律数 >= 深度门槛（frontmatter 声明，默认 10）
TH=$(sed -n 's/^深度门槛: *//p' "$RULE" | head -1); TH=${TH:-10}
CNT=$(grep -c '^### 规律' "$RULE")
[[ "$CNT" -ge "$TH" ]] && ok "规律数 $CNT >= 门槛 $TH" || err "规律数 $CNT < 门槛 $TH"

# 要素2b: 每条规律含 对应门禁 或 人工检查
NOGATE=$(awk '/^### 规律/{c++} /^### 规律/,/^### |^## /{if(/对应门禁|人工检查/)g[c]=1} END{for(i=1;i<=c;i++)if(!g[i])n++ ; print n+0}' "$RULE")
[[ "$NOGATE" -eq 0 ]] && ok "全部规律挂门禁/人工检查" || err "$NOGATE 条规律未挂门禁"

# 要素3: §4 门禁 id ⊆ 片段 gates: 头注释，且函数存在
IDS=$(awk '/^## §4/,/^## §5/' "$RULE" | grep -oE 'fw_[a-z0-9_]+' | sort -u)
for gid in $IDS; do
  grep -q "$gid" "$GATE" || err "门禁 $id 在 $GATE 中无实现痕迹"
done
[[ -f "$GATE" ]] && { grep -q "^${FN}()" "$GATE" && ok "函数 $FN 存在" || err "函数 $FN 不存在于 $GATE"; }

# 要素3b: 片段三平台兼容语法
bash -n "$GATE" 2>/dev/null && ok "片段语法 OK" || err "片段语法错误"
grep -q 'declare -A' "$GATE" && err "片段用了 declare -A（违反三平台铁律）"

# 要素4: fixture 双态（存在 fixtures 才核验）
FX="$BASE/tests/fixtures/$ID"
if [[ -d "$FX/violating" && -d "$FX/compliant" ]]; then
  bash "$BASE/tests/run-framework-fixture.sh" "$ID" >/dev/null 2>&1 \
    && ok "fixture 双态通过" || err "fixture 双态失败（运行 tests/run-framework-fixture.sh $ID 查看）"
else
  echo "⚠ 无 fixture（$FX），跳过双态核验"
fi
[[ "$FAIL" -eq 0 ]] && echo "规则集 $ID 核验通过" || { echo "规则集 $ID 核验未通过"; exit 1; }
```

- [ ] **Step 3: 写 `tests/run-framework-fixture.sh`**（双态运行器，供 verify 调用）

```bash
#!/usr/bin/env bash
# 用法: run-framework-fixture.sh <ruleset_id> —— violating 期望 FAIL / compliant 期望 PASS
set -u
BASE="$(cd "$(dirname "$0")/.." && pwd)"
ID="$1"
FX="$BASE/tests/fixtures/$ID"
run_one() {  # $1=violating|compliant  $2=expect fail|pass
  local mode="$1" expect="$2" tmp
  tmp="$(mktemp -d /tmp/fwfx.XXXXXX)"
  mkdir -p "$tmp/scripts"
  cp "$BASE/assets/precheck.sh" "$tmp/scripts/precheck.sh"
  cp "$FX/$mode/precheck.conf" "$tmp/scripts/precheck.conf"
  # 注入片段（直接用范式片段拼入标记区块，模拟 --inject-frameworks 结果）
  awk -v frag="$BASE/assets/framework-gates/$ID.sh" '
    /^# >>> swarm-yuan:framework-gates >>>/ { print; while ((getline l < frag) > 0) print l; skip=1; next }
    /^# <<< swarm-yuan:framework-gates <<</ { skip=0 }
    !skip { print }
  ' "$tmp/scripts/precheck.sh" > "$tmp/scripts/p2.sh" && mv "$tmp/scripts/p2.sh" "$tmp/scripts/precheck.sh"
  ( cd "$FX/$mode" && bash "$tmp/scripts/precheck.sh" --framework ) >/dev/null 2>&1
  local rc=$?
  rm -rf "$tmp"
  if [[ "$expect" == "fail" ]]; then [[ $rc -ne 0 ]]; else [[ $rc -eq 0 ]]; fi
}
run_one violating fail && echo "✓ violating → FAIL（符合预期）" || { echo "✗ violating 未 FAIL"; exit 1; }
run_one compliant pass && echo "✓ compliant → PASS（符合预期）" || { echo "✗ compliant 未 PASS"; exit 1; }
```

- [ ] **Step 4: 写 `scripts/gen-framework-index.sh`**（扫描各规则文件 §1 表，重写 exploration-guide.md §C+.0.5 中 `# >>> framework-signal-index >>>` 标记区块；区块不存在则报错误退出——Task 4 负责加入标记）

- [ ] **Step 5: precheck.conf 框架段加通用化约定注释**

在 `assets/precheck.conf` 框架适配段顶部插入：

```bash
# ===== 框架适配（约定式命名：<RULESET_ID>_<VAR>，RULESET_ID 全大写、连字符转下划线）=====
# 每个激活框架的变量由对应门禁片段头注释 requires_conf 声明；
# --inject-frameworks 注入时自动核对缺失变量并注入占位 + warn。
```

- [ ] **Step 6: 自测 + Commit**

```bash
bash -n scripts/verify-framework-ruleset.sh && bash -n scripts/gen-framework-index.sh
bash scripts/verify-framework-ruleset.sh vue   # 期望: vue 规则文件尚未建 → ✗ 规则文件缺失（exit 1，证明脚本工作）
git add references/frameworks/_template.md scripts/verify-framework-ruleset.sh scripts/gen-framework-index.sh tests/run-framework-fixture.sh assets/precheck.conf
git commit -m "feat: 规则模板 + verify-framework-ruleset 四要素核验 + gen-framework-index + conf 约定式命名"
```

---

### Task 4: 生成流程文档改造（SKILL.md / template-spec.md / exploration-guide.md / domain-knowledge.md）

**Files:**
- Modify: `SKILL.md`、`references/template-spec.md`、`references/exploration-guide.md`、`references/domain-knowledge.md`

**Interfaces:**
- Consumes: Task 3 的 gen-framework-index.sh 标记约定
- Produces: 生成流程含 Step 4.5/7.5、Step 12 四要素核验、framework-knowledge.md 正式入六段式

- [ ] **Step 1: SKILL.md 改造**（4 处）

1. 生成流程图插入 `④.5框架深化(逐激活框架:枚举+规律实例化)` 于 ④ 之后，`⑦.5门禁注入(--inject-frameworks)` 于 ⑦ 之前（按现文案对齐编号）
2. 六段式模板表 reference 行补 `framework-knowledge.md（按激活框架实例化的规律与门禁依据）`
3. Step 12 最终检查追加：「框架适配四要素核验：对 ACTIVE_FRAMEWORKS 每个框架——①构件枚举计数≥实际×0.95 ②framework-knowledge.md 规律数≥规则文件声明门槛且100%含证据字段 ③precheck.sh 含 `_fw_<id>_check` 且 `--framework` 实跑 exit 0 ④dev-guide §10 含该框架约束段≥3 条。任一不过→回 Step 4.5」
4. reference 文件清单表加一行：`框架规则库（~56 框架，生成时按 ACTIVE_FRAMEWORKS 读取） | references/frameworks/`

- [ ] **Step 2: template-spec.md 改造**

新增「framework-knowledge.md 填充规范」小节：骨架由 `--inject-frameworks` 自 `references/frameworks/<fw>.md` §3 生成；AI 逐条用项目代码验证实例化（成立→附"证据:"；不成立→剔除记录原因；版本区间外→标"待验证"）；残留种子=占位符零容忍。核对清单追加四要素核验 4 条 checkbox（同 Step 12 文案）。

- [ ] **Step 3: exploration-guide.md §C+.0.5 改造**

1. 「框架信号→规则集激活表」整表替换为标记区块 `# >>> framework-signal-index >>>` / `# <<< framework-signal-index <<<`（初始内容保留表现有 20 行，后续由 gen-framework-index.sh 重写）
2. 表后追加：「探查时须同时提取各框架**版本号**（pom.xml/build.gradle/package.json/go.mod/pyproject.toml），与规则文件 §3 规律的适用版本区间匹配；区间外规律标'待验证'」
3. §C+.1-FW 各框架枚举命令段保留，但段首注明「各框架完整枚举命令以 references/frameworks/<fw>.md §2 为准」

- [ ] **Step 4: domain-knowledge.md 瘦身**

「## 框架特定领域规则集」整节（388-600 行）替换为索引：「框架规则已迁移至 `references/frameworks/`（每框架 1 文件，六段式）。生成时按 §C+.0.5 探查结果读取对应文件。本文件保留通用领域速查（数据库/缓存/网络/安全/并发/业务/架构/管理/运维）。」

- [ ] **Step 5: 一致性检查 + Commit**

```bash
grep -n "framework-knowledge" SKILL.md references/template-spec.md | head -5   # 断言均已提及
bash scripts/gen-framework-index.sh   # 断言: 成功重写索引区块（无报错）
git add SKILL.md references/template-spec.md references/exploration-guide.md references/domain-knowledge.md
git commit -m "feat: 生成流程接入框架深化/门禁注入/四要素核验，framework-knowledge 正式入六段式"
```

---

### Task 5: ncwk-dev 回灌零回归验证（P0 验收门禁）

**Files:**
- 不涉及新文件；操作对象：`/Volumes/nvme2230/lab/ncwk/.claude/skills/ncwk-dev/`

**Interfaces:**
- Consumes: Task 1-4 全部产物

- [ ] **Step 1: 同步范式到安装目录**

```bash
cd /Volumes/nvme2230/lab/Swarm-yuan && bash install.sh   # 同步 ~/.claude/skills/swarm-yuan
```

- [ ] **Step 2: 回灌前基线采集**

```bash
NC=/Volumes/nvme2230/lab/ncwk/.claude/skills/ncwk-dev
bash $NC/scripts/precheck.sh --all-full > /tmp/baseline-allfull.txt 2>&1; echo "exit=$?"
bash $NC/scripts/precheck.sh --framework > /tmp/baseline-framework.txt 2>&1
grep -c 'pass\|fail\|warn' /tmp/baseline-framework.txt   # 记录基线检查项数（≥28）
```

- [ ] **Step 3: 执行升级 + 注入**

```bash
cd /Users/cuishi/.claude/skills/swarm-yuan
bash scripts/generate-skill.sh --upgrade ncwk-dev $NC   # 按现有 --upgrade 用法
bash scripts/generate-skill.sh --inject-frameworks $NC
```

- [ ] **Step 4: 零回归断言**

```bash
# 1) 手写函数等价迁入标记区块（内容一致，仅位置变化）
grep -A2 '_fw_vue_check' $NC/scripts/precheck.sh | head -5
# 2) 26 门禁全 pass
bash $NC/scripts/precheck.sh --all-full > /tmp/after-allfull.txt 2>&1
diff <(grep -c '^✗' /tmp/baseline-allfull.txt) <(grep -c '^✗' /tmp/after-allfull.txt)  # 期望相等且为 0（或失败项集不增）
# 3) --framework 检查项不减少
[[ $(grep -c 'pass\|fail\|warn' /tmp/after-allfull.txt) -ge 0 ]]  # 重新单跑:
bash $NC/scripts/precheck.sh --framework > /tmp/after-framework.txt 2>&1
[[ $(grep -cE '✓|✗|⚠' /tmp/after-framework.txt) -ge $(grep -cE '✓|✗|⚠' /tmp/baseline-framework.txt) ]] && echo "零回归 OK"
# 4) .swarm-yuan-version 含 framework_gates_sha
grep framework_gates_sha $NC/.swarm-yuan-version
```

任一断言失败 → 修复范式后重跑本任务，**不允许带着回归进入 P1**。

- [ ] **Step 5: Commit（范式侧记录）**

```bash
cd /Volumes/nvme2230/lab/Swarm-yuan
git add -A && git commit -m "test: ncwk-dev 回灌零回归验证通过（基线/结果记录）" --allow-empty
```

---

### Task 6: P1 — mybatis 规则集（完整范例，后续框架照此结构）

**Files:**
- Create: `references/frameworks/mybatis.md`
- Create: `assets/framework-gates/mybatis.sh`
- Create: `tests/fixtures/mybatis/violating/`（`UserMapper.xml` + `precheck.conf`）、`tests/fixtures/mybatis/compliant/`（同构）

**Interfaces:**
- Produces: `_fw_mybatis_check()`；门禁 id `fw_mybatis_dollar` `fw_mybatis_binding` `fw_mybatis_foreach` `fw_mybatis_plus_page`；conf 变量 `MYBATIS_MAPPER_DIRS` `MYBATIS_SRC_GLOBS` `SQL_INJECTION_WHITELIST`

- [ ] **Step 1: 联网调研（2026-07 现行版本）**

检索清单（WebSearch/WebFetch，结果记入规则文件头部"来源"）：
1. `mybatis 3.5 latest release changelog site:github.com/mybatis/mybatis-3` — 确认现行 3.5.x 版本号与行为变化
2. `mybatis-plus 3.5.x pagination interceptor DbType site:baomidou.com` — 分页插件现行配置
3. `mybatis ${} #{} SQL injection official docs site:mybatis.org`
4. `mybatis resultMap association collection N+1 lazy loading official docs`
5. `mybatis foreach batch size limit OOM`
6. `mybatis TypeHandler registration mybatis-spring-boot-starter`
7. `mybatis-plus 3.5.7+ 分页插件须声明 DbType`（核实具体版本点）
8. `mybatis-spring-boot-starter mapperLocations 默认值`

- [ ] **Step 2: 写 `references/frameworks/mybatis.md`**（复制 `_template.md`，深度门槛: 15）

§3 规律候选清单（逐条调研验证后撰写五要素，≥15 条；以下为必须覆盖的主题，调研后增补）：
1. `#{}` vs `${}` 分工与白名单 2. Mapper↔XML namespace 绑定 3. resultMap 嵌套 N+1 4. `<foreach>` IN 列表 size 上限 5. MP 分页须 Page 对象/分页插件 6. MP 3.5.7+ 分页插件须显式 DbType 7. TypeHandler 注册 8. `<if test>` OGNL 空串/0 陷阱（`!= ''` 对数值误伤）9. 动态表名只能 `${}` 且须枚举校验 10. `useGeneratedKeys` 批量插入限制 11. `<select>` resultType vs resultMap 不可同存 12. `#{param}` 类型推断 jdbcType 与 NULL 13. 二级缓存与多表关联脏数据 14. MP 逻辑删除须全局配置 + SQL 不带 deleted 条件 15. MP Wrapper 字符串列名注入面（`last()`/`having()` 拼接）16. 多数据源下 SqlSessionFactory 隔离

§5 交互：mybatis × sharding（DML 含分片键）、mybatis × lombok（@Data 排除懒加载字段）、mybatis × spring-boot（@MapperScan 与 @Mapper 二选一）。

- [ ] **Step 3: 写 `assets/framework-gates/mybatis.sh`（完整实现）**

```bash
# ruleset: mybatis  requires_conf: MYBATIS_MAPPER_DIRS MYBATIS_SRC_GLOBS SQL_INJECTION_WHITELIST
# gates: fw_mybatis_dollar(fail) fw_mybatis_binding(fail) fw_mybatis_foreach(warn) fw_mybatis_plus_page(warn)
_fw_mybatis_check() {
  echo "  [mybatis] MyBatis 框架规律"
  local xmls
  xmls=$(for d in ${MYBATIS_MAPPER_DIRS[@]+"${MYBATIS_MAPPER_DIRS[@]}"}; do
    [[ -d "$d" ]] && find "$d" -type f -name '*.xml'
  done)
  if [[ -z "$xmls" ]]; then warn "mybatis: 无 mapper XML 可检（MYBATIS_MAPPER_DIRS）"; return; fi

  # fw_mybatis_dollar(fail)：XML 中 ${} 须命中白名单
  local bad wl line safe
  bad=""
  while IFS= read -r line; do
    safe=0
    for wl in ${SQL_INJECTION_WHITELIST[@]+"${SQL_INJECTION_WHITELIST[@]}"}; do
      case "$line" in *"$wl"*) safe=1 ;; esac
    done
    [[ "$safe" -eq 0 ]] && bad="$bad$line\n"
  done <<EOF
$(echo "$xmls" | xargs grep -n '\${' 2>/dev/null || true)
EOF
  if [[ -n "$bad" ]]; then
    fail "fw_mybatis_dollar: \${} 未命中白名单（SQL 注入风险 CWE-89）:\n$bad"
  else
    pass "fw_mybatis_dollar: 全部 \${} 命中白名单"
  fi

  # fw_mybatis_binding(fail)：@Mapper/@MapperScan 接口数 vs XML namespace 数
  local mfiles mcnt xcnt
  mfiles=$(_fw_resolve_globs ${MYBATIS_SRC_GLOBS[@]+"${MYBATIS_SRC_GLOBS[@]}"} 2>/dev/null)
  mcnt=$({ grep -lE '@Mapper|extends BaseMapper' $mfiles 2>/dev/null || true; } | wc -l | xargs)
  xcnt=$(echo "$xmls" | xargs grep -l '<mapper namespace=' 2>/dev/null | wc -l | xargs)
  if [[ "$mcnt" -ne "$xcnt" ]]; then
    fail "fw_mybatis_binding: Mapper 接口数($mcnt) ≠ XML namespace 数($xcnt)，存在未绑定映射"
  else
    pass "fw_mybatis_binding: Mapper↔XML 绑定一致 ($mcnt)"
  fi

  # fw_mybatis_foreach(warn)：foreach 须人工确认 IN 列表 size 上限
  local fc
  fc=$(echo "$xmls" | xargs grep -c '<foreach' 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
  [[ "$fc" -gt 0 ]] && warn "fw_mybatis_foreach: 存在 $fc 处 <foreach>，须人工确认 IN 列表 size 上限（防 OOM/超 max_allowed_packet）"

  # fw_mybatis_plus_page(warn)：selectList 无 Page 的分页嫌疑（仅 MP 项目）
  if [[ -n "$mfiles" ]] && echo "$mfiles" | xargs grep -lq 'extends BaseMapper' 2>/dev/null; then
    local np
    np=$(echo "$mfiles" | xargs grep -nE 'selectList\(' 2>/dev/null | grep -v 'Page' | head -5 || true)
    [[ -n "$np" ]] && warn "fw_mybatis_plus_page: 疑似无分页 selectList（须用 Page 对象）:\n$np"
  fi
}
```

- [ ] **Step 4: 写 fixture（violating 含 1 处未白名单 `${}`；compliant 全合规）**

`tests/fixtures/mybatis/violating/UserMapper.xml`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN" "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="com.example.UserMapper">
  <select id="list" resultType="map">
    SELECT * FROM t_user ORDER BY ${col}
  </select>
</mapper>
```

`tests/fixtures/mybatis/violating/precheck.conf`：

```bash
PROJECT_DIR="/Volumes/nvme2230/lab/Swarm-yuan/tests/fixtures/mybatis/violating"
ACTIVE_FRAMEWORKS=("mybatis")
MYBATIS_MAPPER_DIRS=("/Volumes/nvme2230/lab/Swarm-yuan/tests/fixtures/mybatis/violating")
MYBATIS_SRC_GLOBS=()
SQL_INJECTION_WHITELIST=("ORDER BY \${orderBy}")
```

`compliant/UserMapper.xml` 把 `${col}` 改为 `#{col}`（其余相同），conf 同构改路径。注意：binding 检查在 fixture 中 mcnt=0 且 xcnt=1 会 fail——因此 fixture 的 conf 将 `MYBATIS_SRC_GLOBS` 置空数组，且 violating fixture 期望 fail 的主因是 dollar 检查；为让 compliant 全 pass，在 compliant 侧同时放一个含 `<mapper namespace=` 且同名 `.java` 占位的配对，或将 binding 设计为"仅当 MYBATIS_SRC_GLOBS 非空时才断言数量一致"——实现时采用后者（在函数中加 `[[ ${#MYBATIS_SRC_GLOBS[@]} -eq 0 ]] && 跳过 binding` 守卫）。

- [ ] **Step 5: 双态 + 四要素核验**

```bash
cd /Volumes/nvme2230/lab/Swarm-yuan
bash tests/run-framework-fixture.sh mybatis     # 期望: violating→FAIL, compliant→PASS
bash scripts/verify-framework-ruleset.sh mybatis # 期望: 核验通过
```

- [ ] **Step 6: 更新信号索引 + Commit**

```bash
bash scripts/gen-framework-index.sh
git add references/frameworks/mybatis.md assets/framework-gates/mybatis.sh tests/fixtures/mybatis/ references/exploration-guide.md
git commit -m "feat(mybatis): 规则集(≥15规律) + 门禁片段 + fixture 双态"
```

---

### Task 7: P1 — lombok 规则集

**Files:**
- Create: `references/frameworks/lombok.md`（深度门槛: 12）
- Create: `assets/framework-gates/lombok.sh`
- Create: `tests/fixtures/lombok/{violating,compliant}/`

**Interfaces:**
- Produces: `_fw_lombok_check()`；id `fw_lombok_data_jpa` `fw_lombok_slf4j_dup` `fw_lombok_builder_jackson` `fw_lombok_equals_lazy`；conf `LOMBOK_SRC_GLOBS`

- [ ] **Step 1: 联网调研**：`lombok 1.18.x latest changelog`、`@Data @Entity StackOverflow lazy loading`、`@Builder Jackson deserialization @NoArgsConstructor`、`@EqualsAndHashCode exclude lazy field`、`delombok jakarta validation 兼容性`、`lombok @Slf4j topic 字段名`
- [ ] **Step 2: 规则文件**（§3 必覆盖：@Data+JPA 递归/懒加载触发、@Slf4j 字段名冲突、@Builder+Jackson、@RequiredArgsConstructor final 注入与循环依赖、@EqualsAndHashCode callSuper、@SneakyThrows 受检异常隐藏、@Cleanup 与 try-with-resources 选型、@Val/var 可读性边界、@Getter(lazy=true) 双重检查锁开销、@NonNull 与 Bean Validation 分工、lombok.config 集中管控、与 MapStruct 的版本联动）
- [ ] **Step 3: 门禁片段**（完整实现，风格同 Task 6）：

  - `fw_lombok_data_jpa`(fail)：同一 .java 同时含 `@Entity` 与 `@Data` → fail（改建议 `@Getter @Setter`）
  - `fw_lombok_slf4j_dup`(fail)：`@Slf4j` 与 `LoggerFactory.getLogger` 同文件 → fail
  - `fw_lombok_builder_jackson`(warn)：`@Builder` 且无 `@AllArgsConstructor`/`@NoArgsConstructor` → warn
  - `fw_lombok_equals_lazy`(warn)：`@EqualsAndHashCode` 无 `exclude`/`of` 且类含 `@OneToMany`/`@ManyToOne` → warn

  实现均基于 `_fw_resolve_globs "${LOMBOK_SRC_GLOBS[@]}"` + `_fw_grep_count` 组合（参照 Task 6 mybatis.sh 结构）。
- [ ] **Step 4-6: fixture 双态（violating: `@Entity @Data class User`）→ run-framework-fixture → verify-framework-ruleset → gen-framework-index → commit**（命令同 Task 6 Step 5-6，替换 id 为 lombok）

---

### Task 8: P1 — spring-batch 规则集

**Files:**
- Create: `references/frameworks/spring-batch.md`（深度门槛: 12）
- Create: `assets/framework-gates/spring-batch.sh`
- Create: `tests/fixtures/spring-batch/{violating,compliant}/`

**Interfaces:**
- Produces: `_fw_spring_batch_check()`；id `fw_batch_step_scope` `fw_batch_chunk_commit` `fw_batch_restart` `fw_batch_jobrepo_tx`；conf `SPRING_BATCH_JOB_DIRS`

- [ ] **Step 1: 联网调研**：`spring batch 5.x latest (spring boot 3/4 适配)`、`@StepScope @Value late binding`、`JobRepository transactionManager 与业务事务隔离`、`chunk commit-interval 默认值变更 (Spring Batch 5)`、`JobParametersIncrementer 重启语义`、`ItemReader restartable ItemWriter 幂等 官方文档`
- [ ] **Step 2: 规则文件**（§3 必覆盖：@StepScope/@JobScope late binding、Step 三件套、chunk 提交间隔、JobRepository 事务隔离、重启策略 allowStartIfComplete/preventRestart、读写幂等与 skip/retry 策略、JobParameters 递增器、分区/远程分块选型、监听器异常吞没、ItemProcessor 返回 null 语义、ExecutionContext 序列化限制、Spring Batch 5 中 JobBuilderFactory→JobBuilder 迁移）
- [ ] **Step 3: 门禁片段**：

  - `fw_batch_step_scope`(fail)：`SPRING_BATCH_JOB_DIRS` 下含 `@Value("#{jobParameters` 或 `@Value("#{stepExecutionContext` 的 Bean 缺 `@StepScope`/`@JobScope` → fail
  - `fw_batch_chunk_commit`(warn)：`new StepBuilder`/`.chunk(` 出现但同文件无 `.chunk(` 参数（提交间隔）→ warn
  - `fw_batch_restart`(warn)：Job 定义文件无 `preventRestart`/`allowStartIfComplete`/`Incrementer` 任一关键字 → warn
  - `fw_batch_jobrepo_tx`(warn)：Batch 配置类中 `@EnableBatchProcessing` 与自定义 `transactionManager` Bean 同现但无 `BatchConfigurer`/`DefaultBatchConfigurer` → warn
- [ ] **Step 4-6**: fixture（violating: Job 配置含 `@Value("#{jobParameters['x']}")` 无 `@StepScope`）→ 双态 → verify → 索引 → commit

---

### Task 9: P1 — sharding 规则集

**Files:**
- Create: `references/frameworks/sharding.md`（深度门槛: 12）
- Create: `assets/framework-gates/sharding.sh`
- Create: `tests/fixtures/sharding/{violating,compliant}/`

**Interfaces:**
- Produces: `_fw_sharding_check()`；id `fw_sharding_key_in_dml` `fw_sharding_broadcast_write` `fw_sharding_binding_join` `fw_sharding_xa`；conf `SHARDING_KEY_COLUMNS` `SHARDED_TABLES` `SHARDING_BROADCAST_TABLES` `MYBATIS_MAPPER_DIRS`

- [ ] **Step 1: 联网调研**：`shardingsphere 5.5.x latest features`、`sharding-jdbc 分片键 全路由 broadcast table binding table 官方文档`、`shardingsphere 分布式事务 XA Seata 集成`、`shardingsphere 不支持的 SQL 清单 官方文档`、`shardingsphere hint 强制路由`
- [ ] **Step 2: 规则文件**（§3 必覆盖：分片键必含于 DML、广播表只读、绑定表 JOIN 含分片键、跨分片排序分页归并陷阱、分布式主键雪花/UUID、跨分片事务 XA/Seata、不支持 SQL 清单（版本区间）、Hint 强制路由使用边界、分片算法确定性与扩容、读写分离与分片组合、ShardingSphere-Proxy vs JDBC 选型、inline 表达式与标准算法类二选一）
- [ ] **Step 3: 门禁片段**：

  - `fw_sharding_key_in_dml`(fail)：对 `SHARDED_TABLES` 每表，在 mapper XML/SQL 文件中找到 `update <table>`/`delete from <table>` 语句块且同行/语句不含对应 `SHARDING_KEY_COLUMNS` → fail（grep 近似实现：以表名为锚抽取语句段核验）
  - `fw_sharding_broadcast_write`(fail)：对 `SHARDING_BROADCAST_TABLES` 出现 `insert into <table>`/`update <table>`/`delete` → fail（广播表只读）
  - `fw_sharding_binding_join`(warn)：JOIN 语句涉及两张分片表且未见分片键 → warn
  - `fw_sharding_xa`(warn)：存在 `@Transactional` 方法体内调用跨分片写（近似：同文件同时含 `@Transactional` 与 ≥2 个分片表名）→ warn 提示 XA/Seata
- [ ] **Step 4-6**: fixture（violating: `UserMapper.xml` 含 `update t_order set status=#{s} where id=#{id}` 缺 `user_id` 分片键）→ 双态 → verify → 索引 → commit

---

### Task 10: P1 收尾 — 端到端 Java fixture 项目全流程验证

**Files:**
- Create: `tests/e2e/java-demo/`（迷你 Java 项目 fixture：pom.xml 含 mybatis+lombok+spring-batch+sharding 依赖声明 + 故意违例源码）
- Create: `tests/e2e/run-e2e.sh`

**Interfaces:**
- Consumes: Task 6-9 全部产物

- [ ] **Step 1: 构造 `tests/e2e/java-demo/`**

```
tests/e2e/java-demo/
├── pom.xml                        # 依赖: mybatis-plus-boot-starter, lombok, spring-boot-starter-batch, shardingsphere-jdbc
├── src/main/java/com/demo/User.java            # @Entity @Data（lombok 违例）
├── src/main/java/com/demo/BatchJobConfig.java  # @Value jobParameters 无 @StepScope（违例）
└── src/main/resources/mapper/UserMapper.xml    # ${col} 未白名单 + update t_order 缺分片键（违例）
```

- [ ] **Step 2: 写 `tests/e2e/run-e2e.sh`**：模拟生成流程 Step 7.5+12——对 java-demo 生成 conf（ACTIVE_FRAMEWORKS=(mybatis lombok spring-batch sharding)）→ 跑 `--inject-frameworks` → 断言 4 个 `_fw_*_check` 已注入 → 跑 `--framework` 断言 exit≠0 且输出含 `fw_mybatis_dollar`/`fw_lombok_data_jpa`/`fw_batch_step_scope`/`fw_sharding_key_in_dml` 四个 fail id

- [ ] **Step 3: 运行 + Commit**

```bash
bash tests/e2e/run-e2e.sh && echo "E2E OK"
git add tests/e2e/ && git commit -m "test: P1 端到端 Java fixture — 四框架注入与门禁 fail 全链路验证"
```

---

### Task 11: P2–P5 批量框架（参数化任务模板 + 每框架调研焦点）

**每个框架一个子任务，严格按 Task 6 的 Step 1-6 结构执行**（调研→规则文件→门禁片段→fixture 双态→verify→索引→commit）。统一验收：`bash scripts/verify-framework-ruleset.sh <id>` exit 0 + `bash tests/run-framework-fixture.sh <id>` 双态通过。**每批结束跑全量回归**：`for f in references/frameworks/*.md; do id=$(basename $f .md); [[ "$id" != "_template" ]] && bash scripts/verify-framework-ruleset.sh "$id"; done`

每框架调研焦点（执行时按此清单联网核实，规则主题须覆盖但不限于）：

**P2 — Java 核心 7 个：**

| ruleset_id | 深度门槛 | 调研焦点（联网核实现行版本） |
|---|---|---|
| spring-boot | 15 | Spring Boot 4.x 现行版本与 javax→jakarta 终态；@Transactional 代理/自调用/回滚规则；构造器注入；@Configuration proxyBeanMethods；Profile 与 @Conditional 链；Actuator 端点暴露面；配置属性绑定 relaxed binding |
| spring-cloud | 12 | 现行 2025.x release train 与 Boot 4 兼容矩阵；OpenFeign 超时/重试传递；LoadBalancer 重试幂等；Config Bus 刷新范围；Gateway 路由谓词顺序与 StripPrefix；服务注册心跳 |
| spring-security | 12 | Security 7.x lambda DSL（废弃 WebSecurityConfigurerAdapter）；PasswordEncoder 选型；JWT 验签与密钥轮换；CSRF 何时可关；方法级 @PreAuthorize SpEL；CORS 与 Security 过滤链顺序 |
| spring-data-jpa | 12 | Hibernate 7 现行版本；N+1 与 EntityGraph；@Transactional(readOnly) 脏检查关闭；open-in-view 反模式；审计 @CreatedDate；悲观/乐观锁；save() 合并语义陷阱 |
| mapstruct | 10 | 现行 1.6.x；unmappedTargetPolicy 默认；@MappingTarget 更新语义；与 lombok 的 annotationProcessor 顺序（lombok-mapstruct-binding）；循环引用；表达式/spi 注入面 |
| validation | 10 | Hibernate Validator 9 / Jakarta EE 11；@Valid 级联；分组序列；自定义 ConstraintValidator 线程安全；@Validated 类级 vs 方法级；嵌套集合校验 |
| jackson | 10 | Jackson 3.0 现行状态与 2.x 差异；JSR310 JavaTimeModule；多态 @JsonTypeInfo 反序列化攻击面（CVE 史）；FAIL_ON_UNKNOWN_PROPERTIES；序列化时区；@JsonIgnore 与密码字段 |
| junit5-mockito | 10 | JUnit 5.13/6 现行；@Transactional 测试回滚 vs 真实提交；Mockito strict stubs；@MockBean 上下文缓存污染；@ParameterizedTest 边界；Testcontainers 集成基线 |

**P3 — Java 分布式 8 + 数据集成/流计算 3 + MQ/缓存/调度深化 6：**

| ruleset_id | 深度门槛 | 调研焦点 |
|---|---|---|
| dubbo | 10 | Dubbo 3.3 现行；超时/重试与幂等；triple 协议；泛化调用安全；qos 端口暴露；注册中心 Nacos/ZK 选型 |
| seata | 10 | Seata 2.x 现行；AT 模式全局锁与脏写；TCC 空回滚/幂等/悬挂三问题；@GlobalTransactional 与本地事务边界 |
| sentinel | 10 | Sentinel 2.x 状态；熔断规则与 RT/异常比；热点参数限流；规则持久化（Nacos 数据源）；@SentinelResource fallback 语义 |
| nacos | 10 | Nacos 3.x 现行；命名空间/分组隔离；配置加密；持久化实例 vs 临时实例；灰度配置发布 |
| xxl-job | 10 | XXL-Job 3.x；路由策略与分片广播；失败重试与幂等；GLUE 代码注入面；执行器鉴权 accessToken |
| elasticsearch | 10 | ES 9.x / Java Client 现行；深分页 search_after；写入 refresh 与一致性；mapping 爆炸；批量 bulk 背压 |
| netty | 10 | Netty 4.1 现行（4.2/5 状态）；EventLoop 不可阻塞；ByteBuf 泄漏与 ReferenceCounted；IdleStateHandler 心跳；channel.writeAndFlush 线程模型 |
| kettle | 10 | Pentaho Data Integration CE 9.x 终态与 Hop 分叉；kjb/ktr 文件版本管控；数据库连接明文密码加密（Encr）；Carte 远程执行安全；转换步骤阻塞与行分发；作业失败邮件/告警 |
| flink | 15 | Flink 2.x 现行状态（1.20/2.0 差异）；checkpoint/savepoint 语义与恢复；exactly-once 两阶段提交；watermark 与乱序/迟到；状态后端选型（RocksDB）与 TTL；DataStream vs Table API/SQL 选型；flink-cdc 3.x 断点续传；反压定位 |
| paimon | 10 | Apache Paimon 1.x 现行；主键表 Changelog 语义；Compaction 与小文件；与 Flink 读写协同（lookup join/流读）；分区与 bucket 选型；快照过期与回溯 |
| rocketmq | 10（深化） | RocketMQ 5.x 现行；消费幂等；顺序消息；事务消息回查；重试与死信；堆积治理 |
| kafka | 10（深化） | Kafka 4.x（KRaft 终态）；offset 语义；幂等/事务生产者；rebalance cooperative；消费者数≤分区数 |
| rabbitmq | 10（深化） | RabbitMQ 4.x；手动 ACK；DLQ；队列持久化与 quorum queue；连接/channel 复用 |
| redis | 10（深化） | Redis 8.x 现行；穿透/击穿/雪崩；分布式锁 Redisson；序列化一致性；pipeline；bigkey/热key 治理 |
| quartz | 10（深化） | Quartz 现行 2.5；集群 DB 锁；misfire 策略；JobDataMap 序列化限制；线程池上限 |
| elasticjob | 10（深化） | ElasticJob 3.x 现行状态（活跃度核实）；分片调度；失效转移；幂等；与 ZK 依赖 |

**P4 — 数据库 3 + Node 6 + Python 6：**

| ruleset_id | 深度门槛 | 调研焦点 |
|---|---|---|
| mysql | 10（深化） | MySQL 8.4/9.x 现行；索引覆盖与深分页；RR 幻读 next-key lock；utf8mb4；死锁检测；online DDL |
| postgresql | 10（深化） | PG 17/18 现行；autovacuum；IDENTITY；JSONB 索引；MVCC 隔离；连接池 PgBouncer |
| sqlserver | 10（深化） | SQL Server 2022/2025 现行；NOLOCK 脏读；锁升级分批；隔离级别；链接服务器权限 |
| express | 10 | Express 5.x 现行（Promise 错误自动捕获变化）；中间件顺序；helmet 基线；express-validator；body-parser 限制 |
| koa | 10 | Koa 3.x 现行；洋葱模型错误冒泡；ctx.state 约定；koa-helmet；路由 factory 注入模式 |
| nestjs | 12 | NestJS 11 现行；DI 作用域（REQUEST 作用域性能）；Guard/Interceptor/Pipe 执行序；CQRS 模块边界；ValidationPipe 全局白名单 |
| fastify | 10 | Fastify 5.x；schema 校验（Ajv）；封装上下文与插件隔离；onSend 钩子副作用 |
| typeorm | 10 | TypeORM 0.3.x；迁移不可手改已执行；N+1 与 relations；事务 QueryRunner；synchronize 生产禁用 |
| prisma | 10 | Prisma 6.x 现行；迁移工作流；$transaction 交互式超时；N+1 与 include；连接池与 serverless 限制 |
| django | 12 | Django 5.x/6.x 现行；ORM N+1（select_related/prefetch_related）；transaction.atomic；CSRF/中间件顺序；迁移不可回滚操作；settings 多环境 |
| flask | 10 | Flask 3.x；应用/请求上下文；蓝图注册序；SQLAlchemy 会话作用域；配置密钥管理 |
| fastapi | 12 | FastAPI 现行；Pydantic v2 迁移要点；依赖注入作用域；async 路由阻塞事件循环；BackgroundTasks vs Celery 边界 |
| sqlalchemy | 10 | SQLAlchemy 2.x 风格（select() vs query()）；会话生命周期；懒加载雷区（DetachedInstanceError）；连接池回收 |
| celery | 10 | Celery 5.x；任务幂等与 acks_late；重试退避；结果后端选型；时区；worker 并发模型 |
| pytest | 10 | pytest 8.x/9.x；fixture 作用域；parametrize 边界；conftest 层级；xdist 并行隔离；asyncio 模式 |

**P5 — Go 2 + 前端 12：**

| ruleset_id | 深度门槛 | 调研焦点 |
|---|---|---|
| gin | 10 | Gin 1.10+；中间件顺序与 c.Next；绑定校验；Context 不可协程间传递（Copy）； graceful shutdown |
| gorm | 10 | GORM 现行；N+1 Preload；事务嵌套 SavePoint；软删除约定；连接池；DryRun 审计 |
| vue | 15（深化） | Vue 3.6 现行（Vapor Mode 状态）；ref/reactive 边界；`<script setup>`；v-html sanitize；Teleport/Suspense；shallowRef 大对象 |
| react | 15（深化） | React 19 现行（Compiler/Actions 状态）；Hooks 规则；useEffect 依赖；key 稳定；不可变更新；memo/useMemo 收益 |
| angular | 10 | Angular 19/20 现行；standalone 组件；signal 与 zoneless；OnPush；RxJS 订阅泄漏（takeUntilDestroyed） |
| nextjs | 12 | Next.js 15/16 现行；RSC 与 'use client' 边界；缓存四层语义；Server Actions 鉴权；中间件 matcher |
| nuxt | 10 | Nuxt 4 现行；useFetch/useAsyncData 键控；SSR 水合一致性；auto-import 冲突 |
| element | 10（深化） | Element Plus 现行；按需引入；表单 rules；el-table 虚拟滚动；i18n |
| antd | 10（深化） | Ant Design 6 现行状态；App.useApp；Form API；Table 虚拟滚动；ConfigProvider 主题 token |
| naiveui | 10（深化） | NaiveUI 现行；n-config-provider；useMessage 注入式；data-table virtual-scroll；darkTheme |
| vite | 10（深化） | Vite 8 现行（Rolldown 状态）；alias 顺序；环境变量前缀；构建 chunk 拆分；预构建缓存 |
| webpack | 10 | webpack 5.x 维护态；持久缓存；splitChunks；动态 import chunk 命名；DefinePlugin |
| tailwind | 10 | Tailwind 4.x 现行（CSS-first 配置）；content 扫描路径；任意值滥用边界；与组件库主题冲突 |
| jest-vitest | 10 | Vitest 3.x/4.x 现行；测试位置约定；mock 提升（vi.hoisted）；快照治理；覆盖率阈值门禁 |

执行纪律：每框架子任务**必须**先联网核实调研焦点中的"现行版本"类问题（2026-07 时点），版本相关结论全部标注区间；不确定的结论写"待验证"并降 warn 级，禁止臆造。

---

### Task 12: 收尾 — 时效检查 + 全量回归 + 文档

**Files:**
- Modify: `scripts/self-check.sh`（新增规则库时效检查）
- Modify: `docs/USAGE.md`（框架规则引擎使用说明）
- Modify: `README.md`（特性清单更新：57 框架规则库）

- [ ] **Step 1: self-check.sh 新增规则库时效检查**

```bash
# 追加到 self-check.sh 末尾：
echo "▶ 框架规则库时效检查"
now=$(date -u +%s)
for f in references/frameworks/*.md; do
  [[ "$(basename "$f")" == "_template.md" ]] && continue
  d=$(sed -n 's/^最后调研: *\([0-9-]*\).*/\1/p' "$f" | head -1)
  [[ -z "$d" ]] && { echo "  ⚠ $(basename $f) 缺'最后调研'日期"; continue; }
  ts=$(date -u -j -f "%Y-%m-%d" "$d" +%s 2>/dev/null || date -u -d "$d" +%s 2>/dev/null || echo 0)
  age=$(( (now - ts) / 86400 ))
  [[ "$age" -gt 180 ]] && echo "  ⚠ $(basename $f) 调研于 $d（${age} 天前 >180 天），建议重新核实版本区间"
done
```

- [ ] **Step 2: 全量回归**

```bash
cd /Volumes/nvme2230/lab/Swarm-yuan
pass=0; failed=""
for f in references/frameworks/*.md; do
  id=$(basename "$f" .md); [[ "$id" == "_template" ]] && continue
  if bash scripts/verify-framework-ruleset.sh "$id" >/dev/null 2>&1; then pass=$((pass+1)); else failed="$failed $id"; fi
done
echo "规则集核验: $pass 通过; 失败:$failed"
[[ -z "$failed" ]]
bash tests/e2e/run-e2e.sh
bash scripts/self-check.sh
bash -n assets/precheck.sh scripts/generate-skill.sh scripts/verify-framework-ruleset.sh scripts/gen-framework-index.sh
```

- [ ] **Step 3: 文档更新 + Commit**

USAGE.md 新增「框架规则引擎」小节（生成时如何激活/如何贡献新规则集/`--inject-frameworks` 用法）；README.md 特性徽章与清单更新（~56 框架规则库 + 四要素验收闭环）。

```bash
git add -A && git commit -m "docs: 框架规则引擎使用说明 + 时效检查 + 全量回归通过"
```

- [ ] **Step 4: 合并 main（不推送）**

```bash
git checkout main && git merge feat/framework-rules-engine
# 遵守全局规则：不自动推送 GitHub；推送前脱敏检查并等用户确认
```

---

## Self-Review 记录

- **Spec 覆盖**：设计文档 §3 架构（Task 1-3）/§4 契约（Task 1-3）/§5 流程与验收（Task 4、5、10、12）/§6 清单（Task 6-11）/§7 批次（Task 5-12）/§8 验证（Task 5、10、12）——全覆盖
- **占位符扫描**：无 TBD；P2-P5 采用参数化模板 + 明确调研焦点清单，非占位（每框架的代码与规则在各自子任务内按 Task 6 结构产出，属执行时工作内容）
- **类型一致**：`_fw_<id>_check` / `fw_<id>_<rule>` / `<RULESET_ID>_<VAR>` 命名在 Task 1-12 全程一致；verify 脚本消费的 frontmatter 字段（深度门槛/最后调研）与 _template.md 产出一致
- **已知取舍**：mybatis binding 检查对 MYBATIS_SRC_GLOBS 为空的情形加了守卫（Task 6 Step 4 已注明）；fixture 路径用绝对路径（$BASE 派生）保证可移植
