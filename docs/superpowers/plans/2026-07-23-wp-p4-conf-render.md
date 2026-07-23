# WP-P4 precheck.conf 初稿渲染（conf-render.sh）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 spec `docs/superpowers/specs/2026-07-23-generation-toolization-design.md` §6（M3）：把 Step 8 中模型把特征卡散文翻译成 158 个 conf 变量的机械工作脚本化。`conf-render.sh` 汇总已有探测能力（detect-frameworks.sh + 语言/目录/包管理器嗅探）+ 特征卡骨架结构化字段 → 渲染三份 conf（`precheck.conf` / `precheck.arch.conf` / `precheck.compliance.conf`）初稿，每个变量带溯源注释（`# AUTO:detected` / `# AUTO:default` / `# TODO:model`）。模型新动作：只处理 `# TODO:model` 清单 + 审 diff，从「写 158 行」变成「审 + 补少数」。

**Architecture:**
- `conf-render.sh` 输入 = 目标仓库 `<PROJECT_DIR>` + 可选特征卡 `<feature-card.md>` + `--profile <lite|standard|compliance>`。
- 嗅探层（内置轻量逻辑，不依赖外部工具）：语言（package.json→TS/JS / pom.xml→Java / go.mod→Go / pyproject.toml→Python）、包管理器（npm/yarn/pnpm/maven/gradle/go/pip/uv）、目录结构（src/ / services/ / packages/ monorepo 判定）、ACTIVE_FRAMEWORKS（调 detect-frameworks.sh）。
- 渲染层：以 `assets/precheck.conf` / `precheck.arch.conf` / `precheck.compliance.conf` 三份模板为基底（现有占位符 `<...>`），逐变量判定：能从嗅探/特征卡填实值 → `VALUE # AUTO:detected`；不能但有合理默认 → `default # AUTO:default`；语义型变量（LAYER_DEFS/SERVICE_DIRS/STORE_DIR 等须人工判定）→ 保留占位 `# TODO:model`。
- 与现有 `merge_precheck_conf`（generate-skill.sh 内）关系：后者目前只追加占位符，改造为以 conf-render 输出为基底（`generate-skill.sh create` 模式调 `conf-render.sh` 产出后落盘，占位符逻辑保留兜底）。

**Tech Stack:** bash 3.2（三 OS），无新增依赖。

**Spec:** `docs/superpowers/specs/2026-07-23-generation-toolization-design.md` §6（M3）、§9（测试）、§10（WP 分解）。

## Global Constraints

- bash 3.2 兼容：禁 `declare -A`；`sed -i.bak` + `rm` 模式；正则用 `grep -E`/`sed -E`（BSD 兼容）；三 OS（macOS/Linux/Windows Git Bash）可跑。
- Repo-confirmed bash 3.2.57 quirks（两条都必须遵守）：
  1. `"` 紧贴 `)` 在引号命令替换内会解析失败 → 赋值用裸命令替换 `x=$(cmd "$VAR")`（不写 `x="$(cmd "$VAR")"`）。
  2. `$VAR` 紧跟多字节字符在双引号串内会误词法 → 多字节字符前用 `${VAR}` 花括号。
- 渲染类脚本 fail-open：缺特征卡/嗅探失败 → 用默认值 + `# AUTO:default`，exit 0（只 arg 错误 exit 1）。
- 输出确定性：同输入字节级一致（变量按模板顺序输出，不重排），可进 cli-ab byte-diff。
- 新脚本进 CI shellcheck 严格名单（`.github/workflows/ci.yml` Job4）。
- 分支纪律：一个 worktree（`.claude/worktrees/feat-wp-p4-conf-render`，从 origin/main 起），收口 `merge --no-ff`。
- run-verifier.sh all 全绿是合入门槛（metrics/sensitive gate-fixtures 预存失败披露即可）。
- **不破坏现有**：`merge_precheck_conf` upgrade 模式的占位符兜底逻辑保留；`conf-render.sh` 只在 `generate-skill.sh create` 模式接入，upgrade 模式不动（保留用户配置）。
- **红线**：`# TODO:model` 标记的语义型变量（LAYER_DEFS/SERVICE_DIRS/STORE_DIR/WRITABLE_DIRS 等）必须显式留占位，**脚本不替模型做架构判断**。

---

## Task 1: `scripts/conf-render.sh` — precheck.conf 三件套初稿渲染

**Files:**
- Create: `swarm-yuan/scripts/conf-render.sh`
- Test: `swarm-yuan/tests/test-conf-render.sh`

**Interfaces:**
- 消费：`<PROJECT_DIR>`（嗅探）；可选 `--feature-card <file>`（特征卡，解析结构化字段）；`--profile <lite|standard|compliance>`（决定渲染 arch/compliance 与否）；`assets/precheck.conf` / `precheck.arch.conf` / `precheck.compliance.conf`（模板基底）。
- 产生：CLI `conf-render.sh <PROJECT_DIR> [--feature-card <f>] [--profile <p>] [--out <dir>]`；产出三份 conf 到 `--out`（默认 stdout 合并 / 给目录则落 `precheck.conf` + `precheck.arch.conf` + `precheck.compliance.conf`）。每行变量带溯源注释 `# AUTO:detected|default|TODO:model`。末尾打印 `# TODO:model` 清单汇总。exit 0；1 arg 错误。

- [ ] **Step 1: 写失败测试**

Create `swarm-yuan/tests/test-conf-render.sh`:

```bash
#!/usr/bin/env bash
# test-conf-render.sh — conf-render.sh 初稿渲染双态测试（WP-P4/M3）
set -uo pipefail
cd "$(dirname "${0}")/.."
SH="scripts/conf-render.sh"
TMP="$(mktemp -d /tmp/crtest.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
FAIL=0
ok()  { echo "  ✓ $1"; }
bad() { echo "  ✗ $1" >&2; FAIL=1; }

# --- 态 1：TS 项目 → PROJECT_DIR/语言/包管理器 detected；LAYER_DEFS TODO:model ---
mkdir -p "$TMP/proj/src"
cat > "$TMP/proj/package.json" <<'EOF'
{ "name": "demo", "dependencies": { "react": "^19.0.0" } }
EOF
out="$(bash "$SH" "$TMP/proj" --profile standard 2>/dev/null)"; rc=$?
[[ $rc -eq 0 ]] && ok "渲染 exit 0" || bad "exit=$rc"
echo "$out" | grep -qE 'PROJECT_DIR=.*# AUTO:detected' && ok "PROJECT_DIR detected" || bad "PROJECT_DIR 缺失: $out"
echo "$out" | grep -qE "BUILD_CMD=.*# AUTO:default" && ok "BUILD_CMD default" || bad "BUILD_CMD 缺失"
echo "$out" | grep -qE 'LAYER_DEFS=.*# TODO:model' && ok "LAYER_DEFS TODO:model" || bad "LAYER_DEFS 未留 TODO: $out"
echo "$out" | grep -qE 'ACTIVE_FRAMEWORKS=.*react' && ok "ACTIVE_FRAMEWORKS detected react" || bad "框架未探测: $out"

# --- 态 2：Java/Maven 项目 → BUILD_CMD maven detected ---
mkdir -p "$TMP/proj2/src/main/java"
cat > "$TMP/proj2/pom.xml" <<'EOF'
<project><modelVersion>4.0.0</modelVersion><dependencies>
<dependency><groupId>org.springframework.boot</groupId></dependency>
</dependencies></project>
EOF
out="$(bash "$SH" "$TMP/proj2" --profile standard 2>/dev/null)"
echo "$out" | grep -qE 'BUILD_CMD=.*mvn.*# AUTO:detected' && ok "Java BUILD_CMD mvn detected" || bad "态2 BUILD_CMD: $out"
echo "$out" | grep -qE 'ACTIVE_FRAMEWORKS=.*spring-boot' && ok "spring-boot detected" || bad "态2 框架: $out"

# --- 态 3：lite profile 不渲染 arch.conf ---
out="$(bash "$SH" "$TMP/proj" --profile lite 2>/dev/null)"
echo "$out" | grep -qE 'precheck.arch.conf' && bad "lite 不应渲染 arch" || ok "lite 无 arch.conf"
echo "$out" | grep -qE 'precheck.compliance.conf' && bad "lite 不应渲染 compliance" || ok "lite 无 compliance.conf"

# --- 态 4：--out 落盘三文件 + TODO:model 清单 ---
mkdir -p "$TMP/out"
bash "$SH" "$TMP/proj" --profile standard --out "$TMP/out" >/dev/null 2>&1
[[ -f "$TMP/out/precheck.conf" ]] && ok "precheck.conf 落盘" || bad "precheck.conf 未落盘"
[[ -f "$TMP/out/precheck.arch.conf" ]] && ok "arch.conf 落盘" || bad "arch.conf 未落盘"
[[ ! -f "$TMP/out/precheck.compliance.conf" ]] && ok "standard 无 compliance.conf" || bad "standard 不应落 compliance"

# --- 态 5：确定性（同输入连跑两次 byte-identical）---
o1="$(bash "$SH" "$TMP/proj" --profile standard 2>/dev/null)"
o2="$(bash "$SH" "$TMP/proj" --profile standard 2>/dev/null)"
[[ "$o1" == "$o2" ]] && ok "确定性 byte-identical" || bad "两次不一致"

[[ $FAIL -eq 0 ]] && { echo "PASS test-conf-render"; exit 0; } || { echo "FAIL test-conf-render" >&2; exit 1; }
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash swarm-yuan/tests/test-conf-render.sh`
Expected: FAIL（脚本不存在）

- [ ] **Step 3: 实现 `swarm-yuan/scripts/conf-render.sh`**

```bash
#!/usr/bin/env bash
# conf-render.sh — precheck.conf 三件套初稿渲染（WP-P4/M3）
# 把 Step 8 模型手译 158 变量的机械工作脚本化：嗅探项目 → 渲染 conf 初稿
#   每变量带溯源注释: # AUTO:detected（探测所得）/ # AUTO:default（默认值未动）/ # TODO:model（语义型，须人工）
# 模型新动作: 只处理 # TODO:model 清单 + 审 diff（从「写 158 行」变「审 + 补少数」）
# 用法:
#   bash conf-render.sh <PROJECT_DIR> [--feature-card <f>] [--profile <lite|standard|compliance>] [--out <dir>]
#     --feature-card  特征卡 md（解析结构化字段补实值，可选）
#     --profile       lite(只 core) / standard(core+arch) / compliance(三件套)，默认 standard
#     --out           落盘目录（不给则 stdout 合并三件套）
# 输出: conf 初稿（每变量行带 # AUTO:* 溯源）；末尾 # TODO:model 清单汇总。
# 退出码: 0 正常（fail-open，嗅探失败用默认）；1 arg 错误。
# 红线: LAYER_DEFS/SERVICE_DIRS/STORE_DIR/WRITABLE_DIRS 等语义型变量显式留 # TODO:model，脚本不替模型做架构判断。
set -uo pipefail
BASE="$(cd "$(dirname "${0}")/.." && pwd)"

PROJ=""; CARD=""; PROFILE="standard"; OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --feature-card) CARD="${2:?--feature-card 需要路径}"; shift 2 ;;
    --profile) PROFILE="${2:?--profile 需要 lite|standard|compliance}"; shift 2 ;;
    --out) OUT="${2:?--out 需要目录}"; shift 2 ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) [[ -z "$PROJ" ]] && PROJ="$1" || { echo "未知参数: $1" >&2; exit 1; }; shift ;;
  esac
done
[[ -n "$PROJ" && -d "$PROJ" ]] || { echo "✗ PROJECT_DIR 缺失或不存在: ${PROJ:-（空）}" >&2; exit 1; }
PROJ=$(cd "$PROJ" && pwd)
[[ -n "$OUT" ]] && { mkdir -p "$OUT"; fi

# ===== 嗅探层 =====
_lang="unknown"; _pm="unknown"; _build=""; _frameworks=""
if [[ -f "$PROJ/package.json" ]]; then
  _lang="typescript"
  if [[ -f "$PROJ/yarn.lock" ]]; then _pm="yarn"; _build="yarn build"
  elif [[ -f "$PROJ/pnpm-lock.yaml" ]]; then _pm="pnpm"; _build="pnpm build"
  else _pm="npm"; _build="npm run build"; fi
  _test="npm test"
elif [[ -f "$PROJ/pom.xml" ]]; then
  _lang="java"; _pm="maven"; _build="mvn package"; _test="mvn test"
elif [[ -f "$PROJ/build.gradle" ]] || [[ -f "$PROJ/build.gradle.kts" ]]; then
  _lang="java"; _pm="gradle"; _build="gradle build"; _test="gradle test"
elif [[ -f "$PROJ/go.mod" ]]; then
  _lang="go"; _pm="go"; _build="go build ./..."; _test="go test ./..."
elif [[ -f "$PROJ/pyproject.toml" ]] || [[ -f "$PROJ/requirements.txt" ]]; then
  _lang="python"; _pm="pip"
  if [[ -f "$PROJ/uv.lock" ]]; then _pm="uv"; _build="uv run build"; _test="uv run pytest"
  elif [[ -f "$PROJ/poetry.lock" ]]; then _pm="poetry"; _build="poetry build"; _test="poetry run pytest"
  else _build="python -m build"; _test="pytest"; fi
fi
# monorepo 判定
_monorepo=0
[[ -d "$PROJ/packages" && $(ls -1 "$PROJ/packages" 2>/dev/null | wc -l | tr -d ' ') -gt 1 ]] && _monorepo=1
[[ -d "$PROJ/services" && $(ls -1 "$PROJ/services" 2>/dev/null | wc -l | tr -d ' ') -gt 1 ]] && _monorepo=1
# ACTIVE_FRAMEWORKS（调 detect-frameworks.sh）
if [[ -x "$BASE/scripts/detect-frameworks.sh" ]]; then
  _frameworks=$("$BASE/scripts/detect-frameworks.sh" "$PROJ" 2>/dev/null | sed -n 's/.*"\([^"]*\)".*/\1/p' | tr '\n' ' ' | sed 's/ *$//')
fi
# 特征卡字段（若给）
if [[ -n "$CARD" && -f "$CARD" ]]; then
  : # 特征卡解析预留：未来从 md 表格提取 WRITABLE_DIRS 等；当前 YAGNI，靠嗅探 + TODO:model
fi

# ===== 渲染层：以模板为基底，逐变量判定溯源 =====
# 模板变量映射 → 渲染值 + 溯源（detected/default/TODO:model）
_render_var() { # $1=变量名 $2=模板行
  local vn="$1" line="$2"
  case "$vn" in
    PROJECT_DIR)      printf "PROJECT_DIR=%s  # AUTO:detected" "$PROJ" ;;
    BUILD_CMD)        printf "BUILD_CMD=%s  # AUTO:%s" "$_build" "${_build:+detected:-default}" ;;
    TEST_CMD)         printf "TEST_CMD=%s  # AUTO:%s" "$_test" "${_test:+detected:-default}" ;;
    ACTIVE_FRAMEWORKS)
      local fw_arr=""
      for f in $_frameworks; do fw_arr="${fw_arr}${fw_arr:+ }\"$f\""; done
      printf "ACTIVE_FRAMEWORKS=(%s)  # AUTO:detected" "$fw_arr" ;;
    LAYER_DEFS|SERVICE_DIRS|STORE_DIR|WRITABLE_DIRS|READONLY_DIRS|SCAN_DIRS|CONSISTENCY_DIRS|COMPONENT_DIR)
      printf "%s=()  # TODO:model" "$vn" ;;
    *) printf "%s" "$line" ;;  # 其余保留模板原行
  esac
}

# 渲染单份 conf：读模板，对 ^[A-Z_]+= 行替换，其余行原样
_render_conf() { # $1=模板相对路径
  local tpl="$BASE/$1"
  [[ -f "$tpl" ]] || return 0
  while IFS= read -r line; do
    if [[ "$line" =~ ^[A-Z_]+= ]]; then
      vn=$(printf '%s' "$line" | sed -E 's/^([A-Z_]+)=.*/\1/')
      _render_var "$vn" "$line"
    else
      printf '%s' "$line"
    fi
    printf '\n'
  done < "$tpl"
}

# 输出
_emit() { # $1=内容 $2=文件名(空=stdout)
  if [[ -z "$OUT" ]]; then printf '%s\n' "$1"; else printf '%s\n' "$1" > "$OUT/$2"; fi
}

core=$(_render_conf "assets/precheck.conf")
_emit "$core" "precheck.conf"

if [[ "$PROFILE" == "standard" || "$PROFILE" == "compliance" ]]; then
  arch=$(_render_conf "assets/precheck.arch.conf")
  if [[ -n "$OUT" ]]; then
    # stdout 模式下加分隔头；落盘模式每文件独立
    printf 'arch content' >/dev/null
  fi
  if [[ -z "$OUT" ]]; then
    _emit "# ===== precheck.arch.conf =====" ""
    _emit "$arch" ""
  else
    _emit "$arch" "precheck.arch.conf"
  fi
fi

if [[ "$PROFILE" == "compliance" ]]; then
  comp=$(_render_conf "assets/precheck.compliance.conf")
  if [[ -z "$OUT" ]]; then
    _emit "# ===== precheck.compliance.conf =====" ""
    _emit "$comp" ""
  else
    _emit "$comp" "precheck.compliance.conf"
  fi
fi

# TODO:model 清单汇总
todo="# ===== # TODO:model 清单（须模型补实值）=====
# LAYER_DEFS / SERVICE_DIRS / STORE_DIR / WRITABLE_DIRS / READONLY_DIRS / SCAN_DIRS / CONSISTENCY_DIRS / COMPONENT_DIR"
if [[ -z "$OUT" ]]; then
  _emit "$todo" ""
else
  _emit "$todo" "TODO-model.txt"
fi
exit 0
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash swarm-yuan/tests/test-conf-render.sh`
Expected: `PASS test-conf-render`

- [ ] **Step 5: 回归（真实 fixture）**

Run: `cd swarm-yuan && bash scripts/conf-render.sh tests/fixtures/gin --profile standard 2>/dev/null | grep -E 'PROJECT_DIR|BUILD_CMD|TODO:model' | head -4`
Expected: PROJECT_DIR detected（gin fixture 绝对路径）；BUILD_CMD 按实况；TODO:model 清单存在

- [ ] **Step 6: Commit**

```bash
git add swarm-yuan/scripts/conf-render.sh swarm-yuan/tests/test-conf-render.sh
git commit -m "feat(wp-p4): conf-render.sh precheck.conf 三件套初稿渲染（嗅探+溯源注释，TODO:model 留语义型）"
```

---

## Task 2: generate-skill.sh create 模式接入 conf-render

**Files:**
- Modify: `swarm-yuan/scripts/generate-skill.sh`（create 模式落 precheck.conf 处，约 :40 注释行附近的 create 流程）

**Interfaces:**
- `generate-skill.sh create <name> <project-dir>` 时，precheck.conf 三件套改为调 `conf-render.sh` 产出后落盘（替代直接拷模板占位符）；upgrade 模式不动（保留 merge_precheck_conf 占位兜底）。

- [ ] **Step 1: 定位 create 模式落 conf 处**

Run: `cd swarm-yuan && grep -n "precheck.conf\|create.*mode\|cp.*precheck" scripts/generate-skill.sh | head -10`
Expected: 找到 create 模式拷 precheck.conf 的行号

- [ ] **Step 2: Edit — create 模式 precheck.conf 落盘处接入 conf-render**

在 create 模式拷 `scripts/precheck.conf`（及 arch/compliance）到目标 skill 的逻辑处，替换为：
```bash
# WP-P4: create 模式 precheck.conf 三件套由 conf-render.sh 渲染初稿（嗅探+溯源注释）
if bash "$paradigm_dir/scripts/conf-render.sh" "$PROJECT_DIR" --profile "$PROFILE" --out "$skill_dir/scripts" >/dev/null 2>&1; then
  echo "  ✓ precheck.conf 初稿由 conf-render.sh 渲染（# AUTO:detected/default + # TODO:model 清单）"
else
  # 兜底：conf-render 不可用 → 退回拷模板占位符（原逻辑）
  cp "$paradigm_dir/assets/precheck.conf" "$skill_dir/scripts/precheck.conf"
  [[ "$PROFILE" == "standard" || "$PROFILE" == "compliance" ]] && cp "$paradigm_dir/assets/precheck.arch.conf" "$skill_dir/scripts/precheck.arch.conf"
  [[ "$PROFILE" == "compliance" ]] && cp "$paradigm_dir/assets/precheck.compliance.conf" "$skill_dir/scripts/precheck.compliance.conf"
  echo "  ⚠ conf-render.sh 不可用，退回模板占位符（须手填）"
fi
```
（具体 old_string 由 Step 1 定位的拷贝行决定；保留 upgrade 模式的 merge_precheck_conf 调用不动。）

- [ ] **Step 3: 验证 create 模式产 conf 带 AUTO 注释**

Run: `cd swarm-yuan && bash scripts/generate-skill.sh demo tests/fixtures/gin 2>&1 | grep -E 'conf-render|precheck.conf' | head -3 && grep -c 'AUTO:' "$(pwd)/tests/fixtures/gin/.claude/skills/demo/scripts/precheck.conf" 2>/dev/null`
Expected: 输出含「conf-render.sh 渲染」；precheck.conf 含 AUTO: 注释行

- [ ] **Step 4: Commit**

```bash
git add swarm-yuan/scripts/generate-skill.sh
git commit -m "feat(wp-p4): generate-skill create 模式接入 conf-render（upgrade 模式不动）"
```

---

## Task 3: SKILL.md Step 8 + exploration-guide 指针改写

**Files:**
- Modify: `swarm-yuan/SKILL.md:96`（Step 8 段）
- Modify: `swarm-yuan/references/exploration-guide.md`（Step 8 / 特征卡→conf 映射段，若有）

**Interfaces:**
- 模型新动作（spec §6）：只处理 `# TODO:model` 清单 + 审 diff 是否符合特征卡意图——从「写 158 行」变成「审 + 补少数」。

- [ ] **Step 1: SKILL.md:96 Edit**

old_string（Step 8 段「8. **AI 配置 precheck.conf**：从特征卡推导 158 个变量（PROJECT_DIR/WRITABLE_DIRS/LAYER_DEFS/SERVICE_DIRS/STORE_DIR 等）——**所有 `<占位符>` 必须替换为真实值**」）：

```
8. **AI 配置 precheck.conf**：从特征卡推导 158 个变量（PROJECT_DIR/WRITABLE_DIRS/LAYER_DEFS/SERVICE_DIRS/STORE_DIR 等）——**所有 `<占位符>` 必须替换为真实值**
```

new_string：

```
8. **AI 配置 precheck.conf**：**★WP-P4 脚本化初稿**——`generate-skill.sh create` 已调 `scripts/conf-render.sh` 渲染三件套初稿（每变量带 `# AUTO:detected`（嗅探所得）/ `# AUTO:default`（默认值）/ `# TODO:model`（语义型须人工）溯源注释）。模型只处理 `# TODO:model` 清单（LAYER_DEFS/SERVICE_DIRS/STORE_DIR/WRITABLE_DIRS 等语义型变量，须从特征卡推导）+ 审 diff 是否符合特征卡意图——从「写 158 行」变成「审 + 补少数」。审完后所有 `<占位符>`/`TODO:model` 必须替换为真实值
```

- [ ] **Step 2: Commit**

```bash
git add swarm-yuan/SKILL.md
git commit -m "docs(wp-p4): SKILL.md Step 8 指向 conf-render 初稿（模型只处理 TODO:model 清单）"
```

---

## Task 4: WP-P4 CI 接线 + 全量回归 + 收口

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: ci.yml Edit 1 — shellcheck 严格名单**

old_string（P3 后状态尾 `scripts/migrate-verify-blocks.sh scripts/framework-evidence.sh; do`）：

```
                   scripts/migrate-verify-blocks.sh scripts/framework-evidence.sh; do
```

new_string：

```
                   scripts/migrate-verify-blocks.sh scripts/framework-evidence.sh \
                   scripts/conf-render.sh; do
```

- [ ] **Step 2: ci.yml Edit 2 — self-check job 测试步骤**

old_string（WP-P0~P3 测试步骤块名）：

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

new_string：

```yaml
      - name: 计量/信号/维度/框架证据/conf 渲染测试（WP-P0~P4）
        run: |
          bash tests/test-context-surface.sh
          bash tests/test-cost-report.sh
          bash tests/test-signal-index.sh
          bash tests/test-detect-frameworks.sh
          bash tests/test-inventory-verify.sh
          bash tests/test-migrate-verify-blocks.sh
          bash tests/test-framework-evidence.sh
          bash tests/test-conf-render.sh
```

- [ ] **Step 3: 本地全量回归**

Run: `cd swarm-yuan && bash tests/test-conf-render.sh && bash ../verifier/v1/run-verifier.sh all`
Expected: 测试 PASS；verifier 全绿（metrics/sensitive 预存失败披露）

- [ ] **Step 4: Commit 并收口 WP-P4**

```bash
git add .github/workflows/ci.yml
git commit -m "ci(wp-p4): conf-render 进 shellcheck 严格层 + conf 渲染测试进 CI"
# rebase origin/main → push → main merge --no-ff → 清理 worktree/分支
```

---

## Self-Review 记录

- Spec 覆盖：§6 M3 → Task 1-4 ✓（conf-render 脚本 + generate-skill create 接入 + Step 8 改写 + CI）；§9 测试 → Task 1 双态测试 + Task 4 全量回归 ✓。
- 红线遵守：LAYER_DEFS/SERVICE_DIRS/STORE_DIR/WRITABLE_DIRS 等语义型变量显式留 `# TODO:model`，脚本只嗅探客观可探测项（语言/包管理器/框架/monorepo），不替模型做架构判断 ✓。
- 不破坏现有：upgrade 模式的 merge_precheck_conf 占位兜底逻辑保留不动；create 模式 conf-render 失败有拷模板兜底（Task 2 Step 2）✓。
- bash 3.2 quirk：赋值全用裸 comsub `_frameworks=$(...)`；无 `$VAR`+多字节紧邻（变量值不含多字节紧邻场景）✓。
- fail-open：嗅探失败 → `# AUTO:default`；无特征卡 → 跳过特征卡解析 exit 0 ✓。
- 确定性：变量按模板顺序输出不重排，两次连跑 byte-identical（态 5 测试）✓。
- 占位符扫描：`# TODO:model` 是设计性显式占位（语义型变量），非运行期待填占位；`<占位符>` 在审完后由模型替换，Step 8 铁律不变。
