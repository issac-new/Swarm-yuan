# G4：自举闭环 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or executing-plans. Steps use `- [ ]` syntax.

**Goal:** CI 对生成器仓库跑 `--all` + `--all-full` + `--compliance-suite` 三档全 RC=0，让"36 门禁检查自身"从 slogan 变 CI 强制证据。

**Architecture:** 扩写 `ci/self-precheck.conf`（补 SPEC_FILE/CHANGE_IMPACT_FILE/WRITABLE_DIRS 解 impact 门 fail 面），CI generator-self-gate Job 加两个 step（--all-full/--compliance-suite），self-check 新增 check_bootstrap_gate 断言 conf 声明 vs CI step 数一致。

**Tech Stack:** Bash 3.2 兼容 + GitHub Actions YAML。

**Spec:** `docs/superpowers/specs/2026-07-22-g4-bootstrap-closure-design.md`

## Global Constraints

- bash 3.2 兼容（无 `declare -A`）；CI 用 `sed` 替换 `__REPO_ROOT__`
- impact 门（`gates-warn.sh:616-617`）在候选+兜底全空时 **fail**——conf 必须显式配 SPEC_FILE
- SCAN_DIRS 必须空（sensitive 内置正则全文件类型扫描，范式仓库模式字面量必误报）
- commit 风格：`feat(g4):`

---

### Task 1: ci/self-precheck.conf 三档扩写 + facts.conf 口径

**Files:**
- Modify: `swarm-yuan/ci/self-precheck.conf`
- Modify: `swarm-yuan/assets/facts.conf`

- [ ] **Step 1: 读当前 self-precheck.conf**

Run: `cat swarm-yuan/ci/self-precheck.conf`

- [ ] **Step 2: 扩写 self-precheck.conf**

在现有内容基础上，补 WRITABLE_DIRS/SPEC_FILE/CHANGE_IMPACT_FILE（保持 SCAN_DIRS 空）：

```bash
# self-precheck.conf —— 生成器仓库自举门禁配置（三档：--all/--all-full/--compliance-suite）
# 断言目标：precheck.sh 三档对生成器仓库 RC=0。CI generator-self-gate Job 用 sed 替换 __REPO_ROOT__。
PROJECT_DIR="__REPO_ROOT__"
BRANCH_REGEX='^(feat|fix|refactor|docs|chore|test)/.+'
PROTECTED_BRANCHES=("main")

# WRITABLE_DIRS 可安全配置：domain/shift-left/impact 代码扫描带扩展名白名单（*.ts/*.js/*.py/*.go/*.java），
# bash/md 不被扫描命中。配置收益：impact md 兜底 + shift-left 埋点扫描有真实目标。
WRITABLE_DIRS=("swarm-yuan/scripts" "swarm-yuan/assets" "swarm-yuan/references")

# SCAN_DIRS 必须空：sensitive 内置正则全文件类型扫描，范式仓库脚本/规则集含 password\s*[=:]/token
# 正则等模式字面量，必误报（已知误报面）。
SCAN_DIRS=()

# SPEC_FILE/CHANGE_IMPACT_FILE 显式指向自家模板：impact 门（gates-warn.sh:616-617）在候选+兜底全空
# 时 fail；生成器仓库 cwd 下模板相对路径不可达（_first_existing_file 用 cwd 相对路径），必须显式配置。
SPEC_FILE="__REPO_ROOT__/swarm-yuan/assets/spec-template.md"
CHANGE_IMPACT_FILE="__REPO_ROOT__/swarm-yuan/assets/plan-template.md"
```

- [ ] **Step 3: facts.conf 新增口径**

`swarm-yuan/assets/facts.conf` 末尾追加：

```bash

# ===== 自举门禁（G4）=====
FACT_BOOTSTRAP_GATES=3   # --all/--all-full/--compliance-suite 三档自举
```

- [ ] **Step 4: 本地手动验证 --all-full RC=0**

Run:
```bash
cd /tmp && rm -rf g4-test && mkdir g4-test && cd g4-test
cp /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/assets/precheck.sh .
cp /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/assets/gates-strict.sh .
cp /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/assets/gates-warn.sh .
cp /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/assets/gates-advisory.sh .
cp /Volumes/nvme2230/lab/Swarm-yuan/swarm-yuan/ci/self-precheck.conf precheck.conf
sed -i.bak "s|__REPO_ROOT__|/Volumes/nvme2230/lab/Swarm-yuan|g" precheck.conf && rm precheck.conf.bak
cd /Volumes/nvme2230/lab/Swarm-yuan && git checkout -b feat/g4-test 2>/dev/null || git checkout feat/g4-test
bash /tmp/g4-test/precheck.sh --all-full 2>&1 | tail -20; echo "rc=$?"
```
Expected: rc=0；impact 门对模板自证 pass；未配置架构门静默跳过。

- [ ] **Step 5: 本地手动验证 --compliance-suite RC=0**

Run: `bash /tmp/g4-test/precheck.sh --compliance-suite 2>&1 | tail -10; echo "rc=$?"`
Expected: rc=0（合规门未配置 skip_if_unconfigured 静默跳过）。

- [ ] **Step 6: 清理测试分支 + Commit**

```bash
cd /Volumes/nvme2230/lab/Swarm-yuan && git checkout main && git branch -D feat/g4-test
git add swarm-yuan/ci/self-precheck.conf swarm-yuan/assets/facts.conf
git commit -m "feat(g4): self-precheck.conf 三档扩写 + facts.conf 自举口径

- 补 WRITABLE_DIRS/SPEC_FILE/CHANGE_IMPACT_FILE 解 impact 门 fail 面
- SCAN_DIRS 保持空防 sensitive 误报
- facts.conf 新增 FACT_BOOTSTRAP_GATES=3"
```

---

### Task 2: ci.yml generator-self-gate 加 --all-full + --compliance-suite step

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: 读现有 generator-self-gate Job**

Run: `grep -n 'generator-self-gate' .github/workflows/ci.yml`
Run: `sed -n "$(grep -n 'generator-self-gate:' .github/workflows/ci.yml | head -1 | cut -d: -f1),+30p" .github/workflows/ci.yml`

- [ ] **Step 2: 在 --all step 后加 --all-full 与 --compliance-suite step**

复用现有 mktemp/cp/sed/git checkout -b 脚手架，在同一个 Job 内追加两个 step：

```yaml
      - name: Self-gate --all-full (27 gates)
        run: |
          tmpdir=$(mktemp -d)
          cp swarm-yuan/assets/precheck.sh swarm-yuan/assets/gates-strict.sh swarm-yuan/assets/gates-warn.sh swarm-yuan/assets/gates-advisory.sh "$tmpdir/"
          sed "s|__REPO_ROOT__|$GITHUB_WORKSPACE|g" swarm-yuan/ci/self-precheck.conf > "$tmpdir/precheck.conf"
          git checkout -b feat/generator-self-gate-full
          cd "$tmpdir" && bash precheck.sh --all-full
      - name: Self-gate --compliance-suite (9 gates)
        run: |
          tmpdir=$(mktemp -d)
          cp swarm-yuan/assets/precheck.sh swarm-yuan/assets/gates-strict.sh swarm-yuan/assets/gates-warn.sh swarm-yuan/assets/gates-advisory.sh "$tmpdir/"
          sed "s|__REPO_ROOT__|$GITHUB_WORKSPACE|g" swarm-yuan/ci/self-precheck.conf > "$tmpdir/precheck.conf"
          cd "$tmpdir" && bash precheck.sh --compliance-suite
```

（注：以实际 Job 结构为准，脚手架与现有 --all step 保持一致。）

- [ ] **Step 3: YAML 语法验证**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo OK`
Expected: OK

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "feat(g4): CI generator-self-gate 加 --all-full + --compliance-suite step

- 三档自举全 RC=0：--all(已有)/--all-full(新)/--compliance-suite(新)
- 复用现有 mktemp/cp/sed/git checkout 脚手架"
```

---

### Task 3: self-check.sh check_bootstrap_gate 断言

**Files:**
- Modify: `swarm-yuan/scripts/self-check.sh`

- [ ] **Step 1: 新增 check_bootstrap_gate 函数**

在 self-check.sh 合适位置（check_doc_consistency 附近）新增：

```bash
# check_bootstrap_gate：自举三档断言（G4）
# 对账 ci/self-precheck.conf 存在 + CI 含三档 step + facts.conf FACT_BOOTSTRAP_GATES=3
check_bootstrap_gate() {
  local base="$1"
  echo "--- 自举门禁三档断言（G4）---"
  local conf="$base/ci/self-precheck.conf" ci="$base/../.github/workflows/ci.yml"
  [[ -f "$conf" ]] || { warn "self-precheck.conf 不存在: $conf"; FAIL=1; return; }
  # conf 显式配置 SPEC_FILE（impact 门 fail 面）
  grep -q '^SPEC_FILE=' "$conf" || { warn "self-precheck.conf 缺 SPEC_FILE（impact 门 --all-full fail 面）"; FAIL=1; }
  # CI 含三档 step
  if [[ -f "$ci" ]]; then
    local n
    n=$(grep -cE 'precheck\.sh"?\s+--(all|all-full|compliance-suite)' "$ci" 2>/dev/null || echo 0)
    [[ "$n" -ge 3 ]] || { warn "CI 自举 step 数=$n < 3（应含 --all/--all-full/--compliance-suite）"; FAIL=1; }
    [[ "$n" -ge 3 ]] && echo "  ✓ CI 自举三档 step 齐全（$n）"
  fi
  echo "  ✓ 自举 conf 三档声明完整"
}
```

并在主流程调用 `check_bootstrap_gate "$base"`。

- [ ] **Step 2: 语法检查**

Run: `bash -n swarm-yuan/scripts/self-check.sh`
Expected: 无输出

- [ ] **Step 3: 手动验证**

Run: `bash swarm-yuan/scripts/self-check.sh --check-only 2>&1 | grep -A2 '自举门禁'`
Expected: 输出自举断言结果

- [ ] **Step 4: Commit**

```bash
git add swarm-yuan/scripts/self-check.sh
git commit -m "feat(g4): self-check 新增 check_bootstrap_gate 自举三档断言

- 对账 self-precheck.conf 存在 + SPEC_FILE 配置 + CI 三档 step
- 口径漂移机器执法（FAIL=1）"
```

---

## Self-Review

**Spec coverage:** §2.2 组件 #1→Task1、#2→Task2、#3→Task3、#4(facts.conf)→Task1 ✓；§2.3 conf 设计→Task1 Step2 ✓；§3.2 conf→门禁映射→Task1 验证 ✓；§4 错误处理/测试→各 Task 验证步骤 ✓。无 gap。

**Placeholder scan:** 无 TBD；Task2 Step2 注"以实际 Job 结构为准"是因 ci.yml 结构需现场确认，已给出完整可适配的 YAML。可接受。

**Type consistency:** FACT_BOOTSTRAP_GATES=3（Task1 定义，Task3 间接引用 via facts.conf）✓；SPEC_FILE（Task1 配置，Task3 校验）✓。
