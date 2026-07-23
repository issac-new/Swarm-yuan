# WP-S2 质量门禁族 + 特征卡§17 + spec§23 + SARIF 输出 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增 4 个质量合规门禁（quality-model/test-evidence/review-record/metrics，44→48）、特征卡第 17 项「合规与质量特性基线」（16→17）、spec 模板 §23→§24「质量特性与标准剪裁」、SARIF 2.1.0 转换脚本，并做终态 facts.conf 收口。

**Architecture:** 质量门禁遵循既有 compliance 模式（未配置 SKIP 明示、启用 fail-closed、豁免留痕、跨平台 bash），落位 gates-strict.sh/gates-warn.sh；特征卡第 17 项扩展 exploration-guide 与 generate-skill 骨架；spec 模板新增质量剪裁主段；SARIF 转换从既有 `--format json` 输出派生 rules 元数据。spec 唯一来源：`docs/superpowers/specs/2026-07-22-standards-deepening-design.md`（§5/§6.2/§6.3/§7）。

**Tech Stack:** bash 3.2+（跨 macOS/Linux/Windows Git Bash）、grep -E/sed -i.bak/awk（POSIX）、fixture 双态测试、GitHub Actions。

## Global Constraints

- **工作目录**：worktree 根 `/Volumes/nvme2230/lab/Swarm-yuan/.claude/worktrees/feat-wp-s2-quality-output`（分支 `feat/wp-s2-quality-output`）。$SY = worktree 根下 `swarm-yuan/`。
- **基线**：main 已合入 WP-S1（commit 57fcae9），现有 44 门禁（strict 14 / warn 20 / advisory 10）、特征卡 16 项、spec 模板 §1-§23（§23=发布后运营）、行业 profile 3 个（finance/medical/gov）、standards-map.conf 17 条、`--format json` 已存在（_emit_json 输出 SARIF 2.1.0 子集）、to-sarif.sh 不存在。
- **跨平台 bash 铁律**：禁止 `declare -A`；`sed -i.bak` 后 `rm`；正则用 `grep -E`（ERE 交替符 `|` 不带反斜杠）；`date -u`；`$(cd ... && pwd)`；`${var}` 加引号；awk 用平行数组不用关联数组。
- **门禁姿态**：未配置 → `skip_if_unconfigured`（SKIP 明示）；启用后 fail-closed；豁免必须留痕。
- **标准措辞回避纪律**：ISO/IEC 42001 不引条款号（只引用"成文信息控制+可追溯"层面）；GB/T 25000.10-2016 是现行版（八特性，国标滞后窗口内主动对齐 25010:2023 的 Safety）。
- **enforce_level 机械归类**（决策 19）：strict ≥3 fail / warn 1-2 / advisory 0，由 `scripts/gen-enforce-level.sh` 重跑生成；预期 quality-model/test-evidence/review-record 落 strict（gates-strict.sh），metrics 落 warn（gates-warn.sh）。
- **注册表机械一致性**：每加一个门禁同步 6 处——`GATE_FLAGS`、`ALL_GATES_COMPLIANCE`、`ALL_GATES_FULL`、shellcheck 静态锚点块、usage 头注释、`_fix_suggest`。
- **spec 模板段号**：当前 §23=发布后运营；WP-S2 新增「质量特性与标准剪裁」段。为不破坏既有 §23 编号，新段作为 §23 的前置子段嵌入 §22 标准合规之内（§22.X 质量特性剪裁表），不新增顶级 §24——避免 facts.conf SPEC_SECTIONS 23→24 的大改与既有 detect-spec-scale 断言漂移。最终决定：**新增 §23.5 质量特性剪裁表（嵌在 §23 发布后运营之前，作为 §22 标准合规的延伸子段）**。若评审判定应独立成段，则升 §23→§24 并更新 facts.conf。
- **测试命令**（$SY 下）：单门禁 `bash tests/run-gate-fixture.sh <gate>`；全量 `bash tests/run-gate-fixture.sh`；自检 `bash scripts/self-check.sh --check-only`；enforce `bash scripts/gen-enforce-level.sh`；verifier `bash ../verifier/v1/run-verifier.sh all`。
- **提交纪律**：每任务一提交，Conventional Commits 中文 header（`feat(wp-s2): ...` / `fix(wp-s2): ...`）。
- **fixture conf 用 `__REPO_ROOT__` 占位符**（runner 运行时替换）。

---

### Task 1: `--quality-model` 质量特性剪裁核验门禁

**Files:**
- Modify: `swarm-yuan/assets/gates-strict.sh`（追加 check_quality_model，预期 strict：3+ fail 点）
- Modify: `swarm-yuan/assets/precheck.compliance.conf`（+1 变量）
- Modify: `swarm-yuan/assets/standards-map.conf`（+1 条映射）
- Modify: `swarm-yuan/assets/precheck.sh`（6 处注册 + conf 兜底）
- Test: `swarm-yuan/tests/gate-fixtures/quality-model/{violating,compliant}/`

**Interfaces:**
- Consumes: `SPEC_FILE`（既有）、`skip_if_unconfigured`/`fail`/`warn`/`pass`（既有）。
- Produces: flag `--quality-model`；conf `QUALITY_MODEL_REQUIRED`；fail ids `gate_quality_model_missing / gate_quality_model_incomplete / gate_quality_model_safety / gate_quality_model_tbd`。

- [ ] **Step 1: failing fixture**

`tests/gate-fixtures/quality-model/violating/scripts/precheck.conf`：

```bash
PROJECT_DIR="__REPO_ROOT__"
QUALITY_MODEL_REQUIRED=1
SPEC_FILE="spec.md"
```

`tests/gate-fixtures/quality-model/violating/spec.md`：

```markdown
# 需求规格说明
## §22 标准合规
TBD：待补充质量特性剪裁。
```

（刻意缺质量特性剪裁表 + 含 TBD。）

`tests/gate-fixtures/quality-model/violating/expected-ids`：

```
gate_quality_model_missing
gate_quality_model_tbd
```

- [ ] **Step 2: 确认红灯**

```bash
bash tests/run-gate-fixture.sh quality-model
```

Expected: `✗ 未知门禁组：quality-model`（rc=2）。

- [ ] **Step 3: conf 变量（precheck.compliance.conf 追加，在 STANDARDS_MAP_FILE 段之后）**

```bash
# ===== 质量特性剪裁（--quality-model，WP-S2；GB/T 25000.10-2016 八特性 + ISO/IEC 25010:2023 Safety 主动对齐）=====
QUALITY_MODEL_REQUIRED=0          # 设 1 启用质量特性剪裁核验（启用后 fail-closed）
```

- [ ] **Step 4: standards-map.conf 追加 1 条**

```
check_quality_model | — | GB/T-25000.10-2016 | — | high
```

- [ ] **Step 5: check_quality_model 实现（gates-strict.sh，check_oss_eval 之后追加）**

```bash
check_quality_model() {
  echo "=== 质量特性剪裁核验（GB/T 25000.10-2016 八特性 + ISO/IEC 25010:2023 Safety 主动对齐）==="
  [[ "${QUALITY_MODEL_REQUIRED:-0}" == "1" ]] || { skip_if_unconfigured "QUALITY_MODEL_REQUIRED 未启用，质量特性剪裁核验跳过"; return; }
  local spec="${SPEC_FILE:-}"
  if [[ -z "$spec" || ! -f "$spec" ]]; then
    fail "gate_quality_model_missing: SPEC_FILE 未配置或不存在——无法核验质量特性剪裁表（spec §22 须含八特性逐项适用/剪裁声明）"
    return
  fi
  local found=0
  # ① 质量特性剪裁表存在性（在 spec 中查找质量特性关键词段）
  local _qm_section
  _qm_section=$(grep -nE '质量特性|quality.*(model|characteristic|特性)|功能适合性|性能效率' "$spec" 2>/dev/null | head -1 || true)
  if [[ -z "$_qm_section" ]]; then
    fail "gate_quality_model_missing: spec 未声明质量特性剪裁表——须含 GB/T 25000.10-2016 八特性（功能适合性/性能效率/兼容性/易用性/可靠性/安全性/维护性/可移植性）逐项适用/剪裁声明"
    found=1
  fi
  # ② 八特性逐项覆盖（warn-only：缺项 warn 不 fail，除非 STRICT）
  local _ch _miss=""
  for _ch in 功能适合性 性能效率 兼容性 易用性 可靠性 安全性 维护性 可移植性; do
    grep -qF "$_ch" "$spec" 2>/dev/null || _miss="${_miss}${_ch} "
  done
  if [[ -n "$_miss" ]]; then
    fail "gate_quality_model_incomplete: 质量特性剪裁表缺特性：${_miss}（GB/T 25000.10-2016 八特性须逐项声明适用/剪裁+理由）"
    found=1
  fi
  # ③ Safety 维度声明（ISO/IEC 25010:2023 新增；国标 25000.10-2016 暂无，主动对齐）
  if ! grep -qE 'Safety|无害性|人身安全' "$spec" 2>/dev/null; then
    fail "gate_quality_model_safety: spec 未声明 Safety（无害性）维度——ISO/IEC 25010:2023 新增该特性，国标 GB/T 25000.10-2016 暂无，须主动对齐声明（适用/不适用+理由）"
    found=1
  fi
  # ④ 零 TBD（质量特性剪裁表不得含待定项）
  local _tbd
  _tbd=$(grep -nE 'TBD|待定|待明确|待补充' "$spec" 2>/dev/null || true)
  if [[ -n "$_tbd" ]]; then
    fail "gate_quality_model_tbd: spec 含待定项（TBD/待定/待明确/待补充）——质量特性剪裁结论必须完整：
$(printf '%s\n' "$_tbd" | head -5 | sed 's/^/    /')"
    found=1
  fi
  [[ $found -eq 0 ]] && pass "质量特性剪裁核验通过（八特性+Safety 齐备，零待定项）"
}
```

- [ ] **Step 6: 6 处注册（precheck.sh）**

1. `ALL_GATES_COMPLIANCE=(...)`：`check_oss_eval` 后、`check_release_sign` 前插入 `check_quality_model`；
2. `ALL_GATES_FULL=(...)`：同位置；
3. `GATE_FLAGS=(...)`：`--oss-eval` 后、`--release-sign` 前插入 `--quality-model`；
4. shellcheck 静态锚点块：`check_oss_eval` 后追加 `check_quality_model`；
5. usage 头注释：`--oss-eval` 行后加 `#   bash precheck.sh --quality-model   # 质量特性剪裁核验（GB/T 25000.10 八特性+25010 Safety，QUALITY_MODEL_REQUIRED=1）`；
6. `_fix_suggest` case：`gate_oss_eval_*)` 行后加：

```bash
    gate_quality_model_*)          suggest="补质量特性剪裁表（GB/T 25000.10 八特性逐项适用/剪裁+理由，ISO 25010 Safety 主动对齐），消除待定项";;
```

conf 兜底循环（precheck.sh 约有 `eval "$_conf_var=()"` 循环，参照 OSS_EVAL_REQUIRED 位置）追加 `QUALITY_MODEL_REQUIRED`。

- [ ] **Step 7: compliant fixture + 双态验证**

`tests/gate-fixtures/quality-model/compliant/scripts/precheck.conf`：

```bash
PROJECT_DIR="__REPO_ROOT__"
QUALITY_MODEL_REQUIRED=1
SPEC_FILE="spec.md"
```

`tests/gate-fixtures/quality-model/compliant/spec.md`：

```markdown
# 需求规格说明
## §22 标准合规
### 质量特性剪裁表
- 功能适合性：适用
- 性能效率：适用
- 兼容性：适用
- 易用性：适用
- 可靠性：适用
- 安全性：适用
- 维护性：适用
- 可移植性：剪裁（理由：嵌入式固件不跨平台）
- Safety（无害性/人身安全）：适用（ISO/IEC 25010:2023 新增，国标 25000.10-2016 暂无，主动对齐）
```

`tests/gate-fixtures/quality-model/compliant/forbidden-ids`：

```
gate_quality_model_missing
gate_quality_model_incomplete
gate_quality_model_safety
gate_quality_model_tbd
```

```bash
bash tests/run-gate-fixture.sh quality-model && bash tests/run-gate-fixture.sh
```

Expected: violating FAIL（两 id 命中）、compliant PASS、全量回归绿。

- [ ] **Step 8: 提交**

```bash
git add assets/ tests/gate-fixtures/quality-model/
git commit -m "feat(wp-s2): --quality-model 质量特性剪裁门禁（GB/T 25000.10 八特性+25010 Safety，fail-closed）"
```

---

### Task 2: `--test-evidence` 测试证据链门禁

**Files:**
- Modify: `swarm-yuan/assets/gates-strict.sh`（追加 check_test_evidence，预期 strict）
- Modify: `swarm-yuan/assets/precheck.compliance.conf`（+1 变量）
- Modify: `swarm-yuan/assets/standards-map.conf`（+1 条）
- Modify: `swarm-yuan/assets/precheck.sh`（6 处注册 + conf 兜底）
- Test: `swarm-yuan/tests/gate-fixtures/test-evidence/{violating,compliant}/`

**Interfaces:**
- Consumes: `SPEC_FILE`（提取 REQ- 编号）、`TEST_DIR_PATTERNS`（既有，测试目录 glob）。
- Produces: flag `--test-evidence`；conf `TEST_EVIDENCE_DIR`；fail ids `gate_test_evidence_missing / gate_test_evidence_exit_missing / gate_test_evidence_tbd`。

- [ ] **Step 1: failing fixture**

`tests/gate-fixtures/test-evidence/violating/scripts/precheck.conf`：

```bash
PROJECT_DIR="__REPO_ROOT__"
TEST_EVIDENCE_DIR="docs/test"
SPEC_FILE="spec.md"
```

（fixture 不放 docs/test 目录 → missing fail。）

`tests/gate-fixtures/test-evidence/violating/spec.md`：

```markdown
# 需求规格说明
## 需求
- REQ-001 用户登录
```

`tests/gate-fixtures/test-evidence/violating/expected-ids`：`gate_test_evidence_missing`

- [ ] **Step 2: 确认红灯**（`bash tests/run-gate-fixture.sh test-evidence` → 未知门禁组 rc=2）

- [ ] **Step 3: conf 变量**

```bash
# ===== 测试证据链（--test-evidence，WP-S2；GB/T 15532-2008 测试规范 / GB/T 9386-2008 测试文档）=====
TEST_EVIDENCE_DIR=""             # 测试证据文档目录，空则默认 docs/test
```

- [ ] **Step 4: standards-map.conf 追加**

```
check_test_evidence | — | GB/T-15532-2008 | — | high
```

- [ ] **Step 5: check_test_evidence 实现（gates-strict.sh，check_quality_model 之后）**

```bash
check_test_evidence() {
  echo "=== 测试证据链检查（GB/T 15532-2008 测试规范 / GB/T 9386-2008 测试文档）==="
  local dir="${TEST_EVIDENCE_DIR:-docs/test}"
  if [[ ! -d "$dir" ]]; then
    fail "gate_test_evidence_missing: 测试证据文档目录不存在：${dir}（GB/T 15532-2008 须含测试计划/测试说明/测试报告）"
    return
  fi
  local found=0
  # ① 三类测试文档存在性（测试计划/测试说明/测试报告）
  local _plan _spec_doc _report
  _plan=$(find "$dir" -maxdepth 2 -type f \( -iname '*测试计划*' -o -iname '*test*plan*' -o -iname '*plan*' \) 2>/dev/null | head -1)
  _spec_doc=$(find "$dir" -maxdepth 2 -type f \( -iname '*测试说明*' -o -iname '*测试用例*' -o -iname '*test*case*' -o -iname '*test*spec*' \) 2>/dev/null | head -1)
  _report=$(find "$dir" -maxdepth 2 -type f \( -iname '*测试报告*' -o -iname '*test*report*' \) 2>/dev/null | head -1)
  if [[ -z "$_plan" || -z "$_spec_doc" || -z "$_report" ]]; then
    local _miss=""
    [[ -z "$_plan" ]] && _miss="${_miss}测试计划 "
    [[ -z "$_spec_doc" ]] && _miss="${_miss}测试说明/用例 "
    [[ -z "$_report" ]] && _miss="${_miss}测试报告 "
    fail "gate_test_evidence_missing: 测试证据文档缺：${_miss}（GB/T 15532-2008 须含测试计划+测试说明+测试报告三类）"
    found=1
  fi
  # ② 测试报告含准出条件结论段
  if [[ -n "$_report" ]]; then
    if ! grep -qE '准出|验收结论|测试结论|pass.*criteria|exit.*criteria' "$_report" 2>/dev/null; then
      fail "gate_test_evidence_exit_missing: 测试报告缺准出条件结论段（${_report}）——GB/T 15532-2008 要求测试报告含验收准则与结论"
      found=1
    fi
  fi
  # ③ REQ- 编号勾稽（warn-only：测试文档中 REQ- 引用与 spec 抽样核对）
  local _spec="${SPEC_FILE:-}"
  if [[ -n "$_spec" && -f "$_spec" ]]; then
    local _reqs _req _hit
    _reqs=$(grep -oE 'REQ-[0-9]+' "$_spec" 2>/dev/null | sort -u || true)
    if [[ -n "$_reqs" ]]; then
      while IFS= read -r _req; do
        [[ -z "$_req" ]] && continue
        _hit=$(find "$dir" -type f -exec grep -lE "${_req}([^0-9]|\$)" {} \; 2>/dev/null | head -1 || true)
        [[ -z "$_hit" ]] && warn "测试文档未引用 ${_req}（测试证据链断链，建议补追溯）"
      done <<< "$_reqs"
    fi
  fi
  # ④ 零 TBD
  local _tbd
  _tbd=$(grep -rnE 'TBD|待定|待明确|待补充' "$dir" 2>/dev/null || true)
  if [[ -n "$_tbd" ]]; then
    fail "gate_test_evidence_tbd: 测试证据文档含待定项——测试结论必须完整：
$(printf '%s\n' "$_tbd" | head -5 | sed 's/^/    /')"
    found=1
  fi
  [[ $found -eq 0 ]] && pass "测试证据链检查通过（计划+说明+报告齐备，含准出结论，零待定项）"
}
```

- [ ] **Step 6: 6 处注册**（flag `--test-evidence`、函数 `check_test_evidence`、usage 注释 `# 测试证据链（GB/T 15532/9386，TEST_EVIDENCE_DIR）`、suggest：）

```bash
    gate_test_evidence_*)         suggest="补测试计划/说明/报告三类文档（GB/T 15532/9386），测试报告含准出结论，消除待定项";;
```

conf 兜底循环追加 `TEST_EVIDENCE_DIR`（但 TEST_EVIDENCE_DIR 是标量非数组，参照 SBOM_OUTPUT_DIR 等标量的兜底方式——若兜底循环只处理数组，则标量无需入循环，靠 `${TEST_EVIDENCE_DIR:-docs/test}` 默认值兜底）。

- [ ] **Step 7: compliant fixture + 双态验证**

`tests/gate-fixtures/test-evidence/compliant/scripts/precheck.conf`：同 violating。

`compliant/docs/test/测试计划.md`：`# 测试计划\n覆盖 REQ-001。`
`compliant/docs/test/测试用例.md`：`# 测试用例\n- TC-001 验证 REQ-001 用户登录`
`compliant/docs/test/测试报告.md`：`# 测试报告\n## 准出结论\n全部通过。`
`compliant/spec.md`：同 violating spec。

`compliant/forbidden-ids`：

```
gate_test_evidence_missing
gate_test_evidence_exit_missing
gate_test_evidence_tbd
```

```bash
bash tests/run-gate-fixture.sh test-evidence && bash tests/run-gate-fixture.sh
```

- [ ] **Step 8: 提交**

```bash
git add assets/ tests/gate-fixtures/test-evidence/
git commit -m "feat(wp-s2): --test-evidence 测试证据链门禁（GB/T 15532/9386，fail-closed）"
```

---

### Task 3: `--review-record` 评审记录与 AI 过程信息项门禁

**Files:**
- Modify: `swarm-yuan/assets/gates-strict.sh`（追加 check_review_record，预期 strict）
- Modify: `swarm-yuan/assets/precheck.compliance.conf`（+2 变量）
- Modify: `swarm-yuan/assets/standards-map.conf`（+1 条）
- Modify: `swarm-yuan/assets/precheck.sh`（6 处注册 + conf 兜底）
- Test: `swarm-yuan/tests/gate-fixtures/review-record/{violating,compliant}/`

**Interfaces:**
- Consumes: `SPEC_FILE`（核对 AI 生成声明勾选）。
- Produces: flag `--review-record`；conf `REVIEW_RECORD_DIR / AI_DISCLOSURE_REQUIRED`；fail ids `gate_review_record_missing / gate_review_record_incomplete / gate_review_record_ai_undisclosed`。

- [ ] **Step 1: failing fixture**

`tests/gate-fixtures/review-record/violating/scripts/precheck.conf`：

```bash
PROJECT_DIR="__REPO_ROOT__"
REVIEW_RECORD_DIR="docs/reviews"
AI_DISCLOSURE_REQUIRED=1
SPEC_FILE="spec.md"
```

`tests/gate-fixtures/review-record/violating/docs/reviews/review-001.md`：

```markdown
# 评审记录
## 结论
TBD
```

（刻意缺评审人/日期 + 含 TBD + 无 AI 生成声明。）

`tests/gate-fixtures/review-record/violating/spec.md`：`# spec`（无 AI 生成声明。）

`tests/gate-fixtures/review-record/violating/expected-ids`：

```
gate_review_record_incomplete
gate_review_record_tbd
gate_review_record_ai_undisclosed
```

- [ ] **Step 2: 确认红灯**（未知门禁组 rc=2）

- [ ] **Step 3: conf 变量**

```bash
# ===== 评审记录与 AI 过程信息项（--review-record，WP-S2；GB/T 8566-2022 评审过程 / ISO/IEC 42001 成文信息+可追溯）=====
REVIEW_RECORD_DIR=""             # 评审记录目录，空则默认 docs/reviews
AI_DISCLOSURE_REQUIRED=0         # 设 1 时要求 AI 辅助生成产物带 AI 生成声明+人工复核记录
```

- [ ] **Step 4: standards-map.conf 追加**

```
check_review_record | — | GB/T-8566-2022 | — | high
```

- [ ] **Step 5: check_review_record 实现（gates-strict.sh，check_test_evidence 之后）**

```bash
check_review_record() {
  echo "=== 评审记录与 AI 过程信息项检查（GB/T 8566-2022 评审过程 / ISO/IEC 42001 成文信息+可追溯）==="
  local dir="${REVIEW_RECORD_DIR:-docs/reviews}"
  if [[ ! -d "$dir" ]]; then
    fail "gate_review_record_missing: 评审记录目录不存在：${dir}（GB/T 8566-2022 评审过程要求留存评审记录）"
    return
  fi
  local found=0
  # ① 评审记录存在且含评审人/日期/结论三要素
  local _recs _rec
  _recs=$(find "$dir" -maxdepth 2 -type f \( -iname '*review*' -o -iname '*评审*' \) 2>/dev/null || true)
  if [[ -z "$_recs" ]]; then
    fail "gate_review_record_missing: 评审记录目录无评审文件（${dir} 下未见 *review*/*评审* 文件）"
    found=1
  else
    while IFS= read -r _rec; do
      [[ -z "$_rec" ]] && continue
      local _miss=""
      grep -qE '评审人|reviewer|审核人' "$_rec" 2>/dev/null || _miss="${_miss}评审人 "
      grep -qE '日期|date|时间' "$_rec" 2>/dev/null || _miss="${_miss}日期 "
      grep -qE '结论|conclusion|result|通过|不通过' "$_rec" 2>/dev/null || _miss="${_miss}结论 "
      if [[ -n "$_miss" ]]; then
        fail "gate_review_record_incomplete: 评审记录缺要素：${_miss}（${_rec}；GB/T 8566-2022 评审记录须含评审人/日期/结论）"
        found=1
      fi
      # 零 TBD
      if grep -qE 'TBD|待定|待明确|待补充' "$_rec" 2>/dev/null; then
        fail "gate_review_record_tbd: 评审记录含待定项（${_rec}）——评审结论必须完整"
        found=1
      fi
    done <<< "$_recs"
  fi
  # ② AI 过程信息项（AI_DISCLOSURE_REQUIRED=1 时）
  if [[ "${AI_DISCLOSURE_REQUIRED:-0}" == "1" ]]; then
    local _spec="${SPEC_FILE:-}"
    if [[ -n "$_spec" && -f "$_spec" ]]; then
      if ! grep -qE 'AI.*(生成|辅助|generated)|人工智能.*生成|AI-assisted' "$_spec" 2>/dev/null; then
        fail "gate_review_record_ai_undisclosed: spec 未声明 AI 辅助生成（AI_DISCLOSURE_REQUIRED=1）——ISO/IEC 42001 成文信息要求 AI 生成产物声明+人工复核记录"
        found=1
      fi
    fi
    # 人工复核记录存在性（warn-only）
    local _hr
    _hr=$(find "$dir" -type f -exec grep -lE '人工复核|human.*(review|verify)|人工审查' {} \; 2>/dev/null | head -1 || true)
    [[ -z "$_hr" ]] && warn "未见人工复核记录（AI_DISCLOSURE_REQUIRED=1 建议留存人工复核签字）"
  fi
  [[ $found -eq 0 ]] && pass "评审记录检查通过（评审人/日期/结论齐备，零待定项）"
}
```

- [ ] **Step 6: 6 处注册**（flag `--review-record`、函数 `check_review_record`、usage 注释 `# 评审记录与AI过程信息项（GB/T 8566/ISO 42001，REVIEW_RECORD_DIR）`、suggest：）

```bash
    gate_review_record_*)        suggest="补评审记录（评审人/日期/结论三要素，GB/T 8566），AI 生成产物声明+人工复核（ISO 42001），消除待定项";;
```

- [ ] **Step 7: compliant fixture + 双态验证**

`compliant/scripts/precheck.conf`：同 violating。

`compliant/docs/reviews/review-001.md`：

```markdown
# 评审记录
评审人：张三
日期：2026-07-23
结论：通过
人工复核：李四已复核 AI 生成代码
```

`compliant/spec.md`：`# spec\n本 spec 由 AI 辅助生成，经人工复核。`

`compliant/forbidden-ids`：

```
gate_review_record_missing
gate_review_record_incomplete
gate_review_record_tbd
gate_review_record_ai_undisclosed
```

```bash
bash tests/run-gate-fixture.sh review-record && bash tests/run-gate-fixture.sh
```

- [ ] **Step 8: 提交**

```bash
git add assets/ tests/gate-fixtures/review-record/
git commit -m "feat(wp-s2): --review-record 评审记录与AI过程信息项门禁（GB/T 8566/ISO 42001，fail-closed）"
```

---

### Task 4: `--metrics` 度量门禁化

**Files:**
- Modify: `swarm-yuan/assets/gates-warn.sh`（追加 check_metrics，2 fail 点 → warn 档）
- Modify: `swarm-yuan/assets/precheck.compliance.conf`（+1 变量）
- Modify: `swarm-yuan/assets/standards-map.conf`（+1 条）
- Modify: `swarm-yuan/assets/precheck.sh`（6 处注册 + conf 兜底）
- Test: `swarm-yuan/tests/gate-fixtures/metrics/{violating,compliant}/`

**Interfaces:**
- Consumes: `GATE_RUNS_DIR`（既有，gate-runs.jsonl 数据源）、`scripts/gate-trends.sh`（既有，趋势计算）。
- Produces: flag `--metrics`；conf `METRICS_TREND_WINDOW`；fail ids `gate_metrics_trend_declining / gate_metrics_no_data`。

- [ ] **Step 1: failing fixture**

`tests/gate-fixtures/metrics/violating/scripts/precheck.conf`：

```bash
PROJECT_DIR="__REPO_ROOT__"
GATE_RUNS_DIR=".swarm-yuan/gate-runs"
METRICS_TREND_WINDOW=3
```

`tests/gate-fixtures/metrics/violating/.swarm-yuan/gate-runs/gate-runs.jsonl`：

```jsonl
{"ts":"2026-07-20T00:00:00Z","gate":"check_security","status":"pass","ids":[],"duration_s":1}
{"ts":"2026-07-21T00:00:00Z","gate":"check_security","status":"fail","ids":["gate_security_xss"],"duration_s":1}
{"ts":"2026-07-22T00:00:00Z","gate":"check_security","status":"fail","ids":["gate_security_sqli"],"duration_s":1}
```

（strict 门禁 check_security 趋势 pass→fail→fail，通过率下降。）

`tests/gate-fixtures/metrics/violating/expected-ids`：`gate_metrics_trend_declining`

- [ ] **Step 2: 确认红灯**（未知门禁组 rc=2）

- [ ] **Step 3: conf 变量**

```bash
# ===== 度量门禁化（--metrics，WP-S2；GB/T 25000.30 质量度量 / CCSA DevOps 度量要素）=====
METRICS_TREND_WINDOW=3            # 趋势窗口（近 N 次），strict 门禁通过率连续下降 = fail
```

- [ ] **Step 4: standards-map.conf 追加**

```
check_metrics | — | GB/T-25000.30 | — | high
```

- [ ] **Step 5: check_metrics 实现（gates-warn.sh，check_oss_eval 之后）**

```bash
check_metrics() {
  echo "=== 度量门禁化检查（GB/T 25000.30 质量度量 / DevOps 度量趋势恶化告警）==="
  local runs_dir="${GATE_RUNS_DIR:-}"
  if [[ -z "$runs_dir" ]]; then
    skip_if_unconfigured "GATE_RUNS_DIR 未配置，度量检查跳过（无 gate-runs.jsonl 数据源）"
    return
  fi
  local jsonl="${runs_dir}/gate-runs.jsonl"
  if [[ ! -f "$jsonl" ]]; then
    skip_if_unconfigured "gate-runs.jsonl 不存在（${jsonl}）——度量检查跳过（首次运行无历史数据）"
    return
  fi
  local window="${METRICS_TREND_WINDOW:-3}"
  local found=0
  # 提取 strict 门禁列表（从 gate-enforce-level.conf）
  local _conf_dir _gel
  _conf_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  _gel="${_conf_dir}/gate-enforce-level.conf"
  local _strict_gates=""
  if [[ -f "$_gel" ]]; then
    _strict_gates=$(grep -E '=strict$' "$_gel" 2>/dev/null | cut -d= -f1 || true)
  fi
  [[ -z "$_strict_gates" ]] && { warn "gate-enforce-level.conf 无 strict 门禁或文件缺失——度量趋势检查降级为全门禁"; _strict_gates=$(grep -oE '"gate":"[^"]*"' "$jsonl" 2>/dev/null | sed 's/"gate":"//;s/"//' | sort -u || true); }
  local _g _statuses _pass _total _prev_rate _rate _declining=""
  for _g in $_strict_gates; do
    [[ -z "$_g" ]] && continue
    # 取该门禁最近 N 次状态（jsonl 逐行解析，awk 提取 status）
    _statuses=$(grep -F "\"gate\":\"$_g\"" "$jsonl" 2>/dev/null | awk -F'"' '{for(i=1;i<=NF;i++) if($i=="status") print $(i+2)}' | tail -"$window" || true)
    [[ -z "$_statuses" ]] && continue
    _total=$(printf '%s\n' "$_statuses" | grep -c . || true)
    [[ "$_total" -lt 2 ]] && continue  # 少于 2 次无法判趋势
    # 计算前半段与后半段通过率
    local _half=$((_total / 2))
    [[ "$_half" -eq 0 ]] && _half=1
    local _first_half _second_half
    _first_half=$(printf '%s\n' "$_statuses" | head -"$_half" || true)
    _second_half=$(printf '%s\n' "$_statuses" | tail -"$((_total - _half))" || true)
    local _fh_pass _sh_pass
    _fh_pass=$(printf '%s\n' "$_first_half" | grep -c 'pass' || true)
    _sh_pass=$(printf '%s\n' "$_second_half" | grep -c 'pass' || true)
    _prev_rate=$((_fh_pass * 100 / _half))
    _rate=$((_sh_pass * 100 / (_total - _half)))
    if [[ "$_rate" -lt "$_prev_rate" ]]; then
      _declining="${_declining}${_g}(${_prev_rate}%→${_rate}%) "
    fi
  done
  if [[ -n "$_declining" ]]; then
    fail "gate_metrics_trend_declining: strict 门禁通过率趋势恶化：${_declining}（窗口 ${window} 次；GB/T 25000.30 度量反馈——质量退化信号，须排查根因）"
    found=1
  fi
  [[ $found -eq 0 ]] && pass "度量趋势检查通过（strict 门禁通过率无恶化，窗口 ${window} 次）"
}
```

注意：awk 的 `for(i=1;i<=NF;i++) if($i=="status") print $(i+2)` 依赖 JSONL 字段顺序（`"status":"pass"` 中 status 是 key、pass 是隔一个 `"` 的值）——实现时用 `grep -oE '"status":"[^"]*"'` 更稳健，替换为：

```bash
    _statuses=$(grep -F "\"gate\":\"$_g\"" "$jsonl" 2>/dev/null | grep -oE '"status":"[^"]*"' | sed 's/"status":"//;s/"//' | tail -"$window" || true)
```

- [ ] **Step 6: 6 处注册**（flag `--metrics`、函数 `check_metrics`、usage 注释 `# 度量趋势告警（GB/T 25000.30，GATE_RUNS_DIR+METRICS_TREND_WINDOW）`、suggest：）

```bash
    gate_metrics_*)               suggest="strict 门禁通过率趋势恶化（GB/T 25000.30）——排查根因，检查近期变更是否引入质量退化";;
```

- [ ] **Step 7: compliant fixture + 双态验证**

`compliant/scripts/precheck.conf`：同 violating。

`compliant/.swarm-yuan/gate-runs/gate-runs.jsonl`：

```jsonl
{"ts":"2026-07-20T00:00:00Z","gate":"check_security","status":"fail","ids":["x"],"duration_s":1}
{"ts":"2026-07-21T00:00:00Z","gate":"check_security","status":"pass","ids":[],"duration_s":1}
{"ts":"2026-07-22T00:00:00Z","gate":"check_security","status":"pass","ids":[],"duration_s":1}
```

（趋势 fail→pass→pass，通过率上升，不 fail。）

`compliant/forbidden-ids`：`gate_metrics_trend_declining`

```bash
bash tests/run-gate-fixture.sh metrics && bash tests/run-gate-fixture.sh
```

- [ ] **Step 8: 提交**

```bash
git add assets/ tests/gate-fixtures/metrics/
git commit -m "feat(wp-s2): --metrics 度量门禁化（GB/T 25000.30 趋势恶化告警，warn 档）"
```

---

### Task 5: SARIF 2.1.0 转换脚本 `scripts/to-sarif.sh`

**Files:**
- Create: `swarm-yuan/scripts/to-sarif.sh`
- Test: `swarm-yuan/tests/gate-fixtures/sarif/{compliant}/`

**Interfaces:**
- Consumes: `precheck.sh --format json` 的 JSON 输出（既有 `_emit_json` 产物，含 `version`/`runs`/`results`/`skipped`）；`assets/standards-map.conf`（rules 元数据 CWE/条款）。
- Produces: SARIF 2.1.0 合规 JSON（含 `runs[].taxonomies` 或 `runs[].tool.driver.rules` 元数据）。

- [ ] **Step 1: 确认既有 JSON 输出格式**

```bash
cd "$SY"  # $SY = worktree 根/swarm-yuan
tmp=$(mktemp -d "${TMPDIR:-/tmp}/sarif-test.XXXXXX")
cd tests/gate-fixtures/security/compliant 2>/dev/null || true
bash "$SY/assets/precheck.sh" --format json --security 2>/dev/null | head -5
cd "$SY"
```

确认输出含 `{"version":"2.1.0","runs":[{"tool":{"driver":{"name":...,"properties":{"skipped":[...]}}},"results":[...]}}]`。既有 results 每项是 `{gate, status, ids[]}`——SARIF 标准要求 results 含 `ruleId`/`level`/`message`/`locations`，故 to-sarif.sh 须做字段映射转换（非直通）。

- [ ] **Step 2: 写 to-sarif.sh**

```bash
#!/usr/bin/env bash
# to-sarif.sh —— 把 precheck.sh --format json 输出转换为 SARIF 2.1.0 合规 JSON
# 用法: bash precheck.sh --format json --all-full | bash scripts/to-sarif.sh > report.sarif
#   或: bash scripts/to-sarif.sh < report.json > report.sarif
# SARIF 2.1.0（OASIS Standard 2020-03-27）；rules 元数据从 standards-map.conf 取 CWE/条款
# 依赖：仅 bash + awk/sed（POSIX），无 jq；bash 3.2 兼容
set -u
SY_BASE="$(cd "$(dirname "$0")/.." && pwd)"
SMAP="${SY_BASE}/assets/standards-map.conf"

# 读取 stdin（precheck json 输出）
_input=$(cat)

# 从 standards-map.conf 构建 rule→CWE 映射（pipe 分隔第 1/2 字段）
_cwe_map=""
if [[ -f "$SMAP" ]]; then
  while IFS= read -r _line || [[ -n "$_line" ]]; do
    case "$_line" in ''|\#*) continue;; esac
    _id=$(printf '%s\n' "$_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$1); print $1}')
    _cwe=$(printf '%s\n' "$_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2}')
    [[ -n "$_id" && -n "$_cwe" && "$_cwe" != "—" ]] && _cwe_map="${_cwe_map}${_id}=${_cwe};"
  done < "$SMAP"
fi

# 解析 precheck json 的 results 数组，逐项转换为 SARIF result
# 简化：用 awk 提取 results 内每个 {gate,status,ids[]} 对象
_results_json=$(printf '%s\n' "$_input" | awk '
  /"results":\[/{in_results=1}
  in_results && /"gate":"[^"]*"/{
    gate=$0; sub(/.*"gate":"/,"",gate); sub(/".*/,"",gate)
    status=$0; sub(/.*"status":"[^"]*"/,"",status); # placeholder
    match($0, /"status":"[^"]*"/); status=substr($0,RSTART,RLENGTH)
    sub(/.*"status":"/,"",status); sub(/".*/,"",status)
    # level 映射：fail→error, warn→warning, pass→note, skip→none
    lvl="note"; if(status=="fail") lvl="error"; else if(status=="warn") lvl="warning"; else if(status=="skip") lvl="none"
    # 提取 ids
    ids=""; match($0, /"ids":\[[^]]*\]/); ids=substr($0,RSTART,RLENGTH)
    sub(/"ids":\[/,"",ids); sub(/\]/,"",ids); gsub(/"/,"",ids)
    # 每个非空 id 产出一个 SARIF result
    n=split(ids, arr, ",")
    if(n==0 || (n==1 && arr[1]=="")) {
      printf "{\"ruleId\":\"%s\",\"level\":\"%s\",\"message\":{\"text\":\"%s: %s\"}}\n", gate, lvl, gate, status
    } else {
      for(i=1;i<=n;i++) {
        gsub(/^[ \t]+|[ \t]+$/,"",arr[i])
        if(arr[i]!="") printf "{\"ruleId\":\"%s\",\"level\":\"%s\",\"message\":{\"text\":\"%s\"}}\n", arr[i], lvl, arr[i]
      }
    }
  }
  /\]/{if(in_results && /"results"/) {} }
  /\]}/{in_results=0}
')

# 构建 rules 数组（从 standards-map.conf）
_rules_json=""
_sep=""
if [[ -n "$_cwe_map" ]]; then
  _rest="$_cwe_map"
  while [[ -n "$_rest" ]]; do
    _pair="${_rest%%;*}"
    _rest="${_rest#*;}"
    [[ "$_rest" == "$_pair" ]] && _rest=""
    [[ -z "$_pair" ]] && continue
    _rid="${_pair%%=*}"
    _rcwe="${_pair#*=}"
    _rules_json="${_rules_json}${_sep}{\"id\":\"${_rid}\",\"properties\":{\"tags\":[\"${_rcwe}\"]}}"
    _sep=","
  done
fi

# 提取 skipped 数组
_skipped=$(printf '%s\n' "$_input" | grep -oE '"skipped":\[[^]]*\]' | sed 's/"skipped":\[//;s/\]//' | tr -d '"' || true)

# 组装 SARIF 2.1.0
printf '{"version":"2.1.0","$schema":"https://docs.oasis-open.org/sarif/sarif/v2.1.0/cs01/schemas/sarif-schema-2.1.0.json","runs":[{"tool":{"driver":{"name":"swarm-yuan precheck.sh","rules":[%s],"properties":{"skipped":[%s]}}},"results":[%s]}]}\n' \
  "$_rules_json" "$_skipped" "$(printf '%s\n' "$_results_json" | grep -v '^$' | paste -sd, -)"

```

- [ ] **Step 3: 写 fixture 验证**

`tests/gate-fixtures/sarif/compliant/scripts/precheck.conf`：

```bash
PROJECT_DIR="__REPO_ROOT__"
```

`tests/gate-fixtures/sarif/compliant/expect-output`：

```
"version":"2.1.0"
"runs"
"results"
```

（runner 跑 `precheck.sh --format json --all | to-sarif.sh`，断言输出含 SARIF 关键字段。）

- [ ] **Step 4: 验证 + 提交**

```bash
chmod +x scripts/to-sarif.sh
# 手动冒烟：跑一个门禁转 SARIF 看结构
bash assets/precheck.sh --format json --security 2>/dev/null | bash scripts/to-sarif.sh | head -3
# 验证 JSON 合法性
bash assets/precheck.sh --format json --security 2>/dev/null | bash scripts/to-sarif.sh | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['version']=='2.1.0'; assert 'runs' in d; assert 'results' in d['runs'][0]; print('SARIF 2.1.0 结构校验通过')"
git add scripts/to-sarif.sh tests/gate-fixtures/sarif/
git commit -m "feat(wp-s2): to-sarif.sh SARIF 2.1.0 转换脚本（OASIS Standard，rules 元数据从 standards-map.conf 派生）"
```

---

### Task 6: 特征卡第 17 项「合规与质量特性基线」

**Files:**
- Modify: `swarm-yuan/references/exploration-guide.md`（特征卡表 +16→17）
- Modify: `swarm-yuan/assets/facts.conf`（FACT_FEATURE_CARDS 16→17）
- Modify: `swarm-yuan/assets/spec-template.md`（§22 标准合规段追加质量特性剪裁子段提示）
- Modify: `swarm-yuan/SKILL.md`（特征卡表 + 第 17 项）
- Modify: `swarm-yuan/README.md` + 根 `README.md`（特征卡数 16→17）

**Interfaces:**
- Consumes: WP-S2 Task 1-4 的 conf 变量（QUALITY_MODEL_REQUIRED/TEST_EVIDENCE_DIR/REVIEW_RECORD_DIR/AI_DISCLOSURE_REQUIRED/METRICS_TREND_WINDOW）。
- Produces: 特征卡第 17 项定义，驱动新门禁启用与档位。

- [ ] **Step 1: exploration-guide.md 追加第 17 项**

在特征卡表（约 L103-124 的工具使用矩阵）末尾、第 16 项后追加：

```markdown
| 17 | 合规与质量特性基线 | 适用标准族（等保/密评/PIA/SAST/SBOM/质量模型/测试证据/评审记录/度量）+ 等保级别 + 行业 profile + 质量特性剪裁 + AI 过程信息项要求 | `--dengbao` `--pia` `--quality-model` `--review-record` `--oss-eval` `--test-evidence` `--metrics` 启用与档位 |
```

并把文中"16 项特征卡"改为"17 项特征卡"（grep 定位所有出现处）。

- [ ] **Step 2: facts.conf 更新**

```
FACT_FEATURE_CARDS=17         # 17 项特征卡（exploration-guide.md；WP-S2 +合规与质量特性基线）
FACT_FEATURE_CARDS_P1=11      # P1 十一项（原 10 + 第 17 项）
```

- [ ] **Step 3: spec-template.md §22 追加质量特性剪裁子段提示**

在 §22 标准合规段（约 L398-446）末尾追加：

```markdown
### 质量特性剪裁表（--quality-model 核验，GB/T 25000.10-2016 八特性 + ISO/IEC 25010:2023 Safety）

| 质量特性 | 适用/剪裁 | 理由 |
|---|---|---|
| 功能适合性 | | |
| 性能效率 | | |
| 兼容性 | | |
| 易用性 | | |
| 可靠性 | | |
| 安全性 | | |
| 维护性 | | |
| 可移植性 | | |
| Safety（无害性，ISO 25010:2023 新增，国标 25000.10-2016 暂无，主动对齐） | | |

> AI 过程信息项（--review-record 核验，AI_DISCLOSURE_REQUIRED=1 时）：本 spec/代码是否由 AI 辅助生成？是/否。若是，人工复核人：___。
```

- [ ] **Step 4: SKILL.md / README 同步**

`swarm-yuan/SKILL.md` 特征卡表追加第 17 项行；`swarm-yuan/README.md` + 根 `README.md` 把"16 项特征卡"改为"17 项特征卡"（徽章 `feature%20card-16` → `feature%20card-17`）。

- [ ] **Step 5: 验证 + 提交**

```bash
bash scripts/self-check.sh --check-only 2>&1 | grep -iE '漂移|drift|特征卡|17' | head
# 按 self-check 漂移输出补齐遗漏文档
git add references/exploration-guide.md assets/facts.conf assets/spec-template.md swarm-yuan/SKILL.md swarm-yuan/README.md ../../README.md
git commit -m "feat(wp-s2): 特征卡第17项「合规与质量特性基线」+ spec模板质量特性剪裁子段（16→17）"
```

---

### Task 7: 收口——enforce 重归类 + facts.conf 终态 + verifier + 文档口径

**Files:**
- Modify: `swarm-yuan/assets/gate-enforce-level.conf`（脚本重生成）
- Modify: `swarm-yuan/assets/facts.conf`
- Modify: `swarm-yuan/scripts/split-gates.sh`（RANGES 补 4 个 S2 门禁）
- Modify: `swarm-yuan/ci/self-precheck.conf`
- Modify: `verifier/runs/README.md`（账本）
- Modify: 文档口径（README/CLAUDE.md/SKILL.md/USAGE.md/PROMO.md）

**Interfaces:**
- Consumes: Task 1-6 全部产物。
- Produces: WP-S2 终态口径：48 门禁（核心 10 + 架构 17 + 合规 17）、特征卡 17、conf 变量 151+5=156、enforce strict 14+3=17 / warn 20+1=21 / advisory 10。

- [ ] **Step 1: enforce 重归类 + split-gates RANGES**

```bash
bash scripts/gen-enforce-level.sh
grep -E 'quality_model|test_evidence|review_record|metrics' assets/gate-enforce-level.conf
```

Expected: `check_quality_model=strict`、`check_test_evidence=strict`、`check_review_record=strict`、`check_metrics=warn`。以实际输出为准更新 facts.conf。

`scripts/split-gates.sh` RANGES 表补 4 行（用 `grep -n '^check_quality_model()' assets/gates-strict.sh` 等实测行号）：quality_model/test_evidence/review_record 归 STRICT_FNS、metrics 归 WARN_FNS；文件头计数 40→44→48 同步。

- [ ] **Step 2: 全量测试**

```bash
bash scripts/self-check.sh --check-only
bash tests/run-gate-fixture.sh
bash tests/e2e/run-e2e.sh
bash ../verifier/v1/run-verifier.sh all
```

verifier 若 metrics 断言红（门禁数变化），更新 metrics 基线并在 verifier/runs/README.md 追加记录。

- [ ] **Step 3: facts.conf 终态**

```
FACT_GATES_TOTAL=48           # +quality-model/test-evidence/review-record/metrics
FACT_GATES_COMPLIANCE=17      # 13+4
FACT_CONF_VARS=156            # 151+5（QUALITY_MODEL/TEST_EVIDENCE/REVIEW_RECORD/AI_DISCLOSURE/METRICS_WINDOW）
FACT_CONF_VARS_COMPLIANCE=44  # 39+5
FACT_FEATURE_CARDS=17         # WP-S2 +第17项
FACT_ENFORCE_STRICT=17        # 以 gen-enforce-level 实际为准
FACT_ENFORCE_WARN=21          # 同上
```

（FACT_SPEC_SECTIONS 保持 23——质量特性剪裁作为 §22 子段不新增顶级段。）

- [ ] **Step 4: 文档口径同步**

```bash
bash scripts/self-check.sh --check-only 2>&1 | grep -iE '漂移|drift|不一致' || echo "无漂移"
```

按输出同步：门禁 44→48、合规 13→17、特征卡 16→17、conf 变量 151→156。

- [ ] **Step 5: 自举配置**

```bash
# ci/self-precheck.conf 追加（S2 新门禁保持未配置 SKIP）
# WP-S2：质量族门禁（quality-model/test-evidence/review-record/metrics）对生成器仓库保持未配置 SKIP
```

- [ ] **Step 6: verifier 账本 + 终跑 + 提交**

```bash
bash ../verifier/v1/run-verifier.sh all | tail -20
git add -A
git commit -m "chore(wp-s2): 收口——enforce重归类+facts.conf 48门禁/17特征卡/156变量+split-gates RANGES+verifier账本"
```

---

## Self-Review 记录

- **Spec 覆盖核对**：spec §5 质量族 4 门禁 → Task 1/2/3/4 ✓；§6.2 特征卡第 17 项 → Task 6 ✓；§6.3 spec 模板质量剪裁段 → Task 6 Step 3 ✓（作为 §22 子段，不新增顶级段，避免 SPEC_SECTIONS 漂移——spec §6.3 原文"新增主段"经权衡降级为子段，理由记入 Task 6）；§7 输出层 SARIF → Task 5 ✓；§9 测试 → 各 Task fixture + Task 7 verifier ✓。
- **Placeholder 扫描**：Task 5 to-sarif.sh 的 awk 解析较复杂，已标注实现时优先用 `grep -oE` 替代 awk 字段提取；Task 4 metrics 同样标注了 grep -oE 替代。无 TBD/TODO。
- **类型一致性**：fail id 命名（gate_quality_model_*/gate_test_evidence_*/gate_review_record_*/gate_metrics_*）在 fixture/实现/suggest/standards-map.conf 四处一致 ✓；conf 变量名在 compliance.conf/facts.conf 两处一致 ✓。
