# WP-S1 安全门禁族 + 标准映射层 + 地基修复 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增 4 个安全合规门禁（dengbao/pia/sast-deep/oss-eval，36→40）、标准映射层 standards-map.conf、政务行业 profile gov，并修复 5 项阻断执法的地基缺陷（BSD grep 字面量、madge stderr、spring-boot 沉睡 ×2、SKIP 透明化、冒烟 CI）。

**Architecture:** 新门禁遵循既有 compliance 门禁模式（未配置 SKIP 明示、启用 fail-closed、豁免留痕、跨平台 bash），函数落位 gates-strict.sh/gates-warn.sh（由 fail() 数机械归类）；映射层为 pipe 分隔 conf，由 check_compliance 扩展核验；spec 唯一来源：`docs/superpowers/specs/2026-07-22-standards-deepening-design.md`。

**Tech Stack:** bash 3.2+（跨 macOS/Linux/Windows Git Bash）、grep -E/sed -i.bak/awk（POSIX）、fixture 双态测试、GitHub Actions。

## Global Constraints

- **工作目录**：`/Volumes/nvme2230/lab/Swarm-yuan/.claude/worktrees/feat-wp-s-standards-deepening`（worktree，分支 `feat/wp-s-standards-deepening`）。所有相对路径以此 + `/swarm-yuan` 为基准（记作 `$SY`）。
- **跨平台 bash 铁律**：禁止 `declare -A`；`sed -i.bak` 后 `rm`；正则用 `grep -E`（ERE 交替符 `|` 不带反斜杠）；`date -u`；`$(cd ... && pwd)` 代替 `readlink -f`；`${var}` 加引号。
- **门禁姿态**：未配置 → `skip_if_unconfigured`（SKIP 明示）；启用后 fail-closed；豁免必须留痕（五字段或四字段登记）。
- **标准措辞回避纪律**：GB/T 43848-2024 只说"成分清单/许可证纳入评价体系"，不写"强制 SBOM"；ISO/IEC 42001 不引条款号；GB/T 34943/44/46 不引漏洞类别具体数量。
- **enforce_level 机械归类**（决策 19）：strict ≥3 fail / warn 1-2 / advisory 0，由 `scripts/gen-enforce-level.sh` 重跑生成，不手工指定；预期 dengbao/pia 落 strict（gates-strict.sh），sast-deep/oss-eval 落 warn（gates-warn.sh）。
- **注册表机械一致性**：每加一个门禁必须同步 6 处——`GATE_FLAGS`、`ALL_GATES_COMPLIANCE`、`ALL_GATES_FULL`、shellcheck 静态锚点块、usage 头注释、`_fix_suggest` 映射；缺一处 gate-fixture runner 或 shellcheck 会红。
- **测试命令**（$SY 下）：单门禁 fixture `bash tests/run-gate-fixture.sh <gate>`；全量 `bash tests/run-gate-fixture.sh`；框架 fixture `bash tests/run-framework-fixture.sh spring-boot`；静态检查 `shellcheck -x -e SC2086,SC1090,SC1091,SC2155,SC2034,SC2230,SC2004,SC2312 assets/precheck.sh assets/gates-strict.sh assets/gates-warn.sh`（本机无 shellcheck 则跳过并注明）；自举 `bash scripts/self-check.sh --check-only`。
- **提交纪律**：每任务一提交，Conventional Commits 中文 header（跟随仓库历史，如 `feat(wp-s1): ...` / `fix(wp-s1): ...`）。
- **fixture conf 用 `__REPO_ROOT__` 占位符**（runner 运行时替换），工具一律 fixture 内 mock（批次铁律④：不依赖宿主工具链）。

---

### Task 1: 地基修复 A——BSD grep 字面量 ×4 + spring-boot 沉睡 ×2

**Files:**
- Modify: `swarm-yuan/assets/precheck.sh`（gitnexus status 探测，约 L943）
- Modify: `swarm-yuan/assets/gates-strict.sh`（privacy 噪声过滤，约 L876/L883）
- Modify: `swarm-yuan/assets/gates-warn.sh`（噪声过滤，约 L141）
- Modify: `swarm-yuan/assets/framework-gates/spring-boot.sh`（transactional `[]` 字符类 + actuator YAML 块列表）
- Test: `swarm-yuan/tests/fixtures/spring-boot/`（双态回归）

**Interfaces:**
- Consumes: 无（纯 bug 修复，不改任何门禁判定语义——GNU 端行为不变，BSD 端从"恒不匹配"恢复为正确匹配）。
- Produces: 后续任务依赖的"fixture 双态 + macOS 本机验证"工作流（本机即 macOS，可直接验证 BSD 修复）。

背景：BSD grep（macOS 自带）下 BRE 的 `\|` 是字面量不是交替符（GNU 才是交替），导致 4 处过滤/探测在 macOS 恒不匹配（R2 已确认，决策 2 标注"留独立版本评估"——本轮即该版本）。spring-boot 两处为 R4 新发现：transactional 正则含空字符类 `[]`（BSD 解析失败→恒 pass）；actuator 门禁不识别 YAML 块列表形式（`include:` 下挂 `- "*"`）。

- [ ] **Step 1: 复现确认（本机 macOS 即 BSD 环境）**

```bash
cd /Volumes/nvme2230/lab/Swarm-yuan/.claude/worktrees/feat-wp-s-standards-deepening/swarm-yuan
grep --version | head -1   # BSD grep（无版本号输出即 BSD）
printf 'up to date\n' | grep -qi "indexed\|up to date"; echo "BRE \\| 命中? rc=$?"   # 预期 rc=1（字面量不命中）
printf 'up to date\n' | grep -qiE "indexed|up to date"; echo "ERE 命中? rc=$?"        # 预期 rc=0
printf 'x=[]\n' | grep -oE '[A-Za-z_][][A-Za-z0-9_]*' ; echo "空字符类 rc=$?"           # 预期报错或 rc!=0
```

Expected: 前两行证明 `\|` 在 BSD 下不命中；第三行证明 `[]` 空字符类异常。

- [ ] **Step 2: 修 4 处 `\|` 字面量（BRE → ERE）**

`assets/precheck.sh`（gitnexus_indexed 内）：

```bash
# 旧：
    gitnexus status 2>/dev/null | grep -qi "indexed\|up to date" && return 0
# 新（ERE 交替符不带反斜杠；BSD/GNU 双端语义一致）：
    gitnexus status 2>/dev/null | grep -qiE "indexed|up to date" && return 0
```

`assets/gates-strict.sh` 两处（check_privacy 噪声过滤）：

```bash
# L876 旧：
      hits=$(grep -rnIE "$pat" "$d" 2>/dev/null | grep -v -i 'example\|mock\|dummy\|placeholder\|样例' || true)
# 新：
      hits=$(grep -rnIE "$pat" "$d" 2>/dev/null | grep -viE 'example|mock|dummy|placeholder|样例' || true)
# L883 旧：
        hits=$(grep -rniF "$kw" "$d" 2>/dev/null | grep -v -i 'example\|mock\|dummy\|placeholder\|样例' || true)
# 新：
        hits=$(grep -rniF "$kw" "$d" 2>/dev/null | grep -viE 'example|mock|dummy|placeholder|样例' || true)
```

`assets/gates-warn.sh` L141（同样模式）：

```bash
# 旧：
        | grep -v -i 'example\|placeholder\|test\|mock\|dummy\|<.*>' || true)
# 新：
        | grep -viE 'example|placeholder|test|mock|dummy|<.*>' || true)
```

- [ ] **Step 3: 验证 privacy 门禁 macOS 端恢复 + fixture 不回归**

```bash
bash tests/run-gate-fixture.sh privacy
bash tests/run-gate-fixture.sh sensitive
printf 'nothing here\n' | grep -viE 'example|mock'; echo "rc=$?"   # rc=1 无匹配，行为同 GNU
```

Expected: fixture 双态全绿（violating FAIL / compliant PASS）。注意：修复后 macOS 端过滤生效，若 compliant fixture 样本含 `example` 字样会被滤掉——这正是 GNU 端既有行为，fixture 本来就是按 GNU 语义设计的，不应回归；若出现回归说明 fixture 样本依赖了 BSD 失灵，如实记录并修 fixture（不是回退修复）。

- [ ] **Step 4: 修 spring-boot transactional 空字符类（`assets/framework-gates/spring-boot.sh`，fw_sboot_transactional_selfinvoke 段）**

```bash
# 旧（[A-Za-z_][] 中的 [] 是空字符类，BSD grep 解析失败 → tx_methods 恒空 → 门禁恒 pass）：
      tx_methods=$(printf '%s\n' "$code" | grep -A3 -E '^[[:space:]]*@Transactional\b' \
        | grep -oE '\b(public|protected|private)?[[:space:]]*(static[[:space:]]+)?[A-Za-z_][][A-Za-z0-9_<>,. ]*[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)\(' \
        | sed -E 's/.*[[:space:]]([a-zA-Z_][a-zA-Z0-9_]*)\(/\1/' | sort -u)
# 新（原意是"返回类型字符集含方括号泛型"，用显式字符类 [A-Za-z0-9_<>,.\[\]]）：
      tx_methods=$(printf '%s\n' "$code" | grep -A3 -E '^[[:space:]]*@Transactional\b' \
        | grep -oE '\b(public|protected|private)?[[:space:]]*(static[[:space:]]+)?[A-Za-z_][A-Za-z0-9_<>,.\[\]]*[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)\(' \
        | sed -E 's/.*[[:space:]]([a-zA-Z_][a-zA-Z0-9_]*)\(/\1/' | sort -u)
```

- [ ] **Step 5: spring-boot violating fixture 补"块列表 YAML"样本 + 修 actuator 门禁**

在 `tests/fixtures/spring-boot/violating/` 下找 actuator 违规样本所在配置文件（`grep -rn 'exposure' tests/fixtures/spring-boot/violating/ | head -5` 定位），在其同目录新增 `application-actuator-list.yml`：

```yaml
management:
  endpoints:
    web:
      exposure:
        include:
          - "*"
```

修 `assets/framework-gates/spring-boot.sh` 的 actuator awk：现 awk 只在 `path == "management.endpoints.web.exposure.include"` 行取值，块列表值在后续 `- item` 行。在 awk 的 `printf` 之后追加块列表捕获（完整替换现 awk 块）：

```awk
      flat=$(awk '
        /^[[:space:]]*(#|$)/ { next }
        {
          line = $0
          match(line, /^[[:space:]]*/)
          indent = RLENGTH
          sub(/^[[:space:]]*/, "", line)
          # 块列表项：上一命中键为 include 且缩进更深 → 取值
          if (line ~ /^-[[:space:]]/ && inc_path != "" && indent > inc_indent) {
            val = line; sub(/^-[[:space:]]*/, "", val)
            printf "%s=%s\n", inc_path, val
            next
          }
          if (line !~ /^[A-Za-z0-9_.-]+[[:space:]]*:/) next
          key = line
          sub(/[[:space:]]*:.*/, "", key)
          sub(/[[:space:]]+$/, "", key)
          while (depth > 0 && ind[depth] >= indent) depth--
          depth++
          ind[depth] = indent
          name[depth] = key
          path = name[1]
          for (i = 2; i <= depth; i++) path = path "." name[i]
          if (path == "management.endpoints.web.exposure.include" || path == "management.server.port") {
            val = line
            sub(/^[^:]*:[[:space:]]*/, "", val)
            printf "%s=%s\n", path, val
            if (path == "management.endpoints.web.exposure.include" && val == "") {
              inc_path = path; inc_indent = indent
            } else {
              inc_path = ""
            }
          } else {
            inc_path = ""
          }
        }
      ' "$cfile" 2>/dev/null || true)
```

（awk 用平行数组 ind[]/name[]/depth，无 declare -A，BSD awk 兼容；`inc_path` 初始为空串，awk 未初始化变量默认空，无需 BEGIN。）

- [ ] **Step 6: 运行 spring-boot 全回路验证（本机 macOS = BSD 现场）**

```bash
bash scripts/verify-framework-ruleset.sh spring-boot
bash tests/run-framework-fixture.sh spring-boot
```

Expected: 四要素核验过；violating 非零退出且输出含 `fw_sboot_transactional_selfinvoke` 与 `fw_sboot_actuator_expose`；compliant 零退出。**如实汇报**：若 transactional 修复在 violating 样本上暴露 GNU 端此前也在沉睡（CI ubuntu 未发病是因为 GNU 把 `[]` 当字面 `]` 字符类碰巧能匹配部分样本），允许出现新增 fail 行——只要 violating 仍非零、compliant 仍零即合格；若 compliant 被误伤，收窄正则后重跑。

- [ ] **Step 7: 全量 fixture 回归 + 提交**

```bash
bash tests/run-gate-fixture.sh            # 36 组全绿
bash verifier/v1/run-verifier.sh fixtures # 61 框架金向量不变（exit code 向量不受输出变化影响）
git add assets/precheck.sh assets/gates-strict.sh assets/gates-warn.sh assets/framework-gates/spring-boot.sh tests/fixtures/spring-boot/
git commit -m "fix(wp-s1): 地基修复A——BSD grep \\| 字面量×4 + spring-boot transactional 空字符类 + actuator YAML 块列表"
```

---

### Task 2: 地基修复 B——madge stderr 捕获 ×2 + SKIP 汇总透明化

**Files:**
- Modify: `swarm-yuan/assets/gates-advisory.sh`（check_link_depth madge 分支，约 L68-82）
- Modify: `swarm-yuan/assets/gates-warn.sh`（check_frontend 循环依赖段，约 L928-937）
- Modify: `swarm-yuan/assets/precheck.sh`（末尾汇总段，`if [[ $FAIL -eq 0 ]]` 之前）
- Test: `swarm-yuan/tests/gate-fixtures/link-depth/`、`swarm-yuan/tests/gate-fixtures/frontend/`、`swarm-yuan/tests/gate-fixtures/summary/`

**Interfaces:**
- Consumes: 无。
- Produces: 汇总段新增 SKIP 披露块——后续所有任务的 fixture 断言须知道这段输出的存在（追加式，不移除任何既有行）。

- [ ] **Step 1: 修 check_link_depth madge 空输出假 pass（gates-advisory.sh）**

```bash
# 旧：
  # ---- 3. 降级 madge ----
  if has_madge; then
    local tree; tree=$(madge --tree --extensions ts,js "$PROJECT_DIR" 2>/dev/null || true)
    local max_indent=0
# 新（stderr 落临时文件；tree 空则 warn 披露并落空返回，继续走到下方纯转发统计降级段）：
  # ---- 3. 降级 madge ----
  if has_madge; then
    local tree _madge_err
    _madge_err=$(mktemp "${TMPDIR:-/tmp}/swarm-yuan-madge.XXXXXX")
    tree=$(madge --tree --extensions ts,js "$PROJECT_DIR" 2>"$_madge_err" || true)
    if [[ -z "$tree" ]]; then
      warn "madge 执行无输出（stderr: $(head -1 "$_madge_err" 2>/dev/null || echo 空)）——调用链深度降级为纯转发统计"
      rm -f "$_madge_err"
    else
      rm -f "$_madge_err"
      local max_indent=0
      while IFS= read -r line; do
        local spaces; spaces=$(echo "$line" | grep -oE '^[ ]*' | wc -c | xargs)
        [[ "$spaces" -gt "$max_indent" ]] && max_indent=$spaces
      done <<< "$tree"
      local depth=$(( max_indent / 2 ))
      if [[ "$depth" -gt "$MAX_LINK_DEPTH" ]]; then
        warn "调用链最大深度约 ${depth}（madge 估算）超过阈值 ${MAX_LINK_DEPTH}，建议拆分中转层"
      fi
      pass "调用链深度检查完成（基于 madge，最大深度约 ${depth}）"
      return
    fi
  fi
```

（删除原 madge 分支里 `local max_indent=0` 到 `return` 的旧体，由上述 else 分支替代；纯转发统计段保持原位不动——madge 空输出时自然落入。）

- [ ] **Step 2: 修 check_frontend 循环依赖 madge 静默（gates-warn.sh）**

```bash
# 旧：
  if command -v madge >/dev/null 2>&1; then
    local circ
    circ=$(madge --circular --extensions ts,tsx,js,jsx "$COMPONENT_DIR" 2>/dev/null || true)
    if echo "$circ" | grep -qi 'circular'; then
      fail "检测到组件循环依赖（madge）——A↔B 互相 import 会导致运行时 undefined："
      echo "$circ" | sed 's/^/    /'
      found=1
    fi
  else
# 新：
  if command -v madge >/dev/null 2>&1; then
    local circ _circ_err
    _circ_err=$(mktemp "${TMPDIR:-/tmp}/swarm-yuan-madge.XXXXXX")
    circ=$(madge --circular --extensions ts,tsx,js,jsx "$COMPONENT_DIR" 2>"$_circ_err" || true)
    if echo "$circ" | grep -qi 'circular'; then
      fail "检测到组件循环依赖（madge）——A↔B 互相 import 会导致运行时 undefined："
      echo "$circ" | sed 's/^/    /'
      found=1
    elif [[ -z "$circ" && -s "$_circ_err" ]]; then
      warn "madge 循环依赖检测执行失败（stderr: $(head -1 "$_circ_err" 2>/dev/null)）——本项未判定"
    fi
    rm -f "$_circ_err"
  else
```

- [ ] **Step 3: SKIP 汇总透明化（precheck.sh 末尾，`if [[ $FAIL -eq 0 ]]; then` 之前插入）**

```bash
# WP-S1 跳过透明化（R1-G5）：SILENT 模式被抑制的未配置跳过在汇总段显式披露——绿≠合规
if [[ $SKIP_COUNT -gt 0 ]]; then
  echo "⊘ 跳过 ${SKIP_COUNT} 个门禁（未配置；逐门禁详情见 --doctor 或单跑该门禁）："
  for _sk in $SKIP_LIST; do echo "    - ${_sk#check_}"; done
fi
```

- [ ] **Step 4: 跑受影响 fixture + 全链路冒烟**

```bash
bash tests/run-gate-fixture.sh link-depth
bash tests/run-gate-fixture.sh frontend
bash tests/run-gate-fixture.sh          # 全量 36 组
bash tests/e2e/run-e2e.sh               # e2e 输出若含汇总断言需核对
```

Expected: 全绿。注意 SKIP 披露块会出现在所有有跳过的运行输出尾部——fixture 断言是"须包含/不得包含"子串语义，追加行不破坏既有断言；若某 fixture 的 forbidden-ids/expect-output 恰好锚定输出尾部则修该断言为新输出，如实记录。

- [ ] **Step 5: verifier 基线核对 + 提交**

```bash
bash verifier/v1/run-verifier.sh cli-ab   # A/B：提交后 HEAD 已含变更，diff 应为空；若 golden 语料（core10-sequence 等）含汇总尾部，按 verifier 账本流程更新基线
git add assets/gates-advisory.sh assets/gates-warn.sh assets/precheck.sh
git commit -m "fix(wp-s1): 地基修复B——madge stderr 捕获×2（沉睡门禁现形）+ SKIP 汇总透明化"
```

---

### Task 3: 标准映射层 standards-map.conf + check_compliance 扩展

**Files:**
- Create: `swarm-yuan/assets/standards-map.conf`
- Modify: `swarm-yuan/assets/precheck.compliance.conf`（+STANDARDS_MAP_FILE）
- Modify: `swarm-yuan/assets/gates-strict.sh`（check_compliance 函数尾部扩展）
- Test: `swarm-yuan/tests/gate-fixtures/compliance/violating-map/`、`swarm-yuan/tests/gate-fixtures/compliance/compliant-map/`

**Interfaces:**
- Consumes: check_compliance 既有结构（gates-strict.sh 内，六锚点核验 + spec §22 核验）。
- Produces: `STANDARDS_MAP_FILE` conf 变量；fail id `gate_compliance_standards_map_format` / `gate_compliance_standards_map_confidence`；映射表格式契约（5 字段 pipe 分隔）——Task 4-7 的新门禁须在映射表中有条目（本任务一次写全 4 个新门禁条目，门禁函数后续任务落）。

- [ ] **Step 1: 写 failing fixture（violating-map）**

`tests/gate-fixtures/compliance/violating-map/scripts/precheck.conf`：

```bash
# compliance violating-map：STANDARDS_MAP_FILE 指向格式破损的映射表
PROJECT_DIR="__REPO_ROOT__"
COMPLIANCE_MATRIX_FILE=""
STANDARDS_MAP_FILE="standards-map-broken.conf"
```

`tests/gate-fixtures/compliance/violating-map/standards-map-broken.conf`：

```
# 破损样本：第 2 行只有 3 个字段；第 3 行 confidence 非法
check_security.sql_injection | CWE-89 | GB/T 34944-2017
check_dengbao.mfa | CWE-308 | GB/T 22239-2019 | 5.0:Authentication | wrong-level
```

`tests/gate-fixtures/compliance/violating-map/expected-ids`：

```
gate_compliance_standards_map_format
gate_compliance_standards_map_confidence
```

- [ ] **Step 2: 跑 fixture 确认失败**

```bash
bash tests/run-gate-fixture.sh compliance 2>&1 | grep -E 'violating-map|✗|✓'
```

Expected: violating-map  FAIL 断言未命中（gate_compliance_standards_map_format 未输出）——功能不存在，红灯确认。注意既有 violating/compliant 两组须保持原结果。

- [ ] **Step 3: conf 变量 + 映射表本体**

`assets/precheck.compliance.conf` 追加（"===== 长期清单收口"段之后新段）：

```bash
# ===== 标准映射层（WP-S1：standards-map.conf，门禁规则 ↔ CWE/GB/ISO/ASVS 映射）=====
STANDARDS_MAP_FILE=""               # 标准映射表路径，空则探测 SKILL_DIR/assets/standards-map.conf；文件不存在则跳过核验
```

`assets/standards-map.conf`（首版内容——新门禁 4 条 + 既有合规门禁 9 条 + 核心安全相关 4 条；置信字段实现回避纪律）：

```
# standards-map.conf —— 门禁规则 ↔ 标准条款机器可读映射（WP-S1）
# 格式（pipe 分隔，# 注释）：rule_or_gate_id | cwe_ids | gb_iso_ref | asvs5_section | confidence
# confidence: high=官方来源已核验 / medium=第三方来源 / unverified=待验证（门禁输出带"待验证"字样）
# 回避纪律：GB/T 43848 不称"强制 SBOM"；ISO 42001 不引条款号；34943/44/46 不引类别数
check_dengbao | CWE-308 | GB/T 22239-2019 | 5.0:Authentication | high
check_pia | CWE-359 | GB/T 35273-2020 | 5.0:Privacy | high
check_sast_deep | CWE-695 | GB/T 34944-2017 | 5.0:Security-Architecture | high
check_oss_eval | CWE-1104 | GB/T 43848-2024 | 5.0:Supply-Chain | high
check_crypto | CWE-327 | GB/T 39786-2021 | 5.0:Cryptography | high
check_privacy | CWE-359 | GB/T 35273-2020 | 5.0:Privacy | high
check_authz | CWE-862 | OWASP-ASVS-5.0 | 5.0:Authorization | high
check_requirements | — | ISO/IEC/IEEE-29148 | — | high
check_rtm | — | ISO/IEC/IEEE-29148 | — | high
check_sbom | CWE-1104 | SPDX-ISO/IEC-5962 | 5.0:Supply-Chain | high
check_release_sign | — | SLSA-Build-L2 | 5.0:Supply-Chain | high
check_docs_pack | — | GB/T-8567-2006 | — | high
check_compliance | — | GB/T-25000.51 | — | high
check_security.sql_injection | CWE-89 | GB/T 34944-2017 | 5.0:Injection | high
check_security.xss | CWE-79 | GB/T 34944-2017 | 5.0:Web-Frontend | high
check_sensitive | CWE-798 | GB/T 38674-2020 | 5.0:Secrets | high
check_security.command_injection | CWE-78 | GB/T 34943-2017 | 5.0:Injection | medium
```

- [ ] **Step 4: check_compliance 扩展（gates-strict.sh，check_compliance 函数尾部 `pass` 之前插入核验块）**

```bash
  # ---- WP-S1 标准映射表核验（STANDARDS_MAP_FILE 配置或默认探测；文件不存在则跳过）----
  local _smap="${STANDARDS_MAP_FILE:-}"
  [[ -z "$_smap" && -f "${SKILL_DIR:-.}/assets/standards-map.conf" ]] && _smap="${SKILL_DIR}/assets/standards-map.conf"
  if [[ -n "$_smap" && -f "$_smap" ]]; then
    local _ln_no=0 _bad_fmt="" _bad_conf="" _row _nf _cf
    while IFS= read -r _row || [[ -n "$_row" ]]; do
      _ln_no=$((_ln_no+1))
      case "$_row" in ''|\#*) continue;; esac
      _nf=$(printf '%s\n' "$_row" | awk -F'|' '{print NF}')
      if [[ "$_nf" -ne 5 ]]; then
        _bad_fmt="${_bad_fmt}${_ln_no}行(${_nf}字段) "
        continue
      fi
      _cf=$(printf '%s\n' "$_row" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$5); print $5}')
      case "$_cf" in high|medium|unverified) ;; *) _bad_conf="${_bad_conf}${_ln_no}行(${_cf}) ";; esac
    done < "$_smap"
    if [[ -n "$_bad_fmt" ]]; then
      fail "gate_compliance_standards_map_format: 标准映射表字段数≠5：${_bad_fmt}（须为 rule|cwe|gb_iso|asvs5|confidence 五字段）"
    fi
    if [[ -n "$_bad_conf" ]]; then
      fail "gate_compliance_standards_map_confidence: 标准映射表 confidence 非法值：${_bad_conf}（仅 high|medium|unverified）"
    fi
    [[ -z "$_bad_fmt" && -z "$_bad_conf" ]] && pass "标准映射表核验通过（${_smap}）"
  fi
```

- [ ] **Step 5: compliant-map fixture + 双态验证**

`tests/gate-fixtures/compliance/compliant-map/scripts/precheck.conf`：

```bash
PROJECT_DIR="__REPO_ROOT__"
COMPLIANCE_MATRIX_FILE=""
STANDARDS_MAP_FILE="standards-map-ok.conf"
```

`tests/gate-fixtures/compliance/compliant-map/standards-map-ok.conf`：

```
check_dengbao | CWE-308 | GB/T 22239-2019 | 5.0:Authentication | high
```

`tests/gate-fixtures/compliance/compliant-map/expect-output`：

```
标准映射表核验通过
```

```bash
bash tests/run-gate-fixture.sh compliance
```

Expected: violating-map FAIL（两个 expected-ids 命中）、compliant-map PASS、既有两组不回归。

- [ ] **Step 6: 提交**

```bash
git add assets/standards-map.conf assets/precheck.compliance.conf assets/gates-strict.sh tests/gate-fixtures/compliance/
git commit -m "feat(wp-s1): 标准映射层 standards-map.conf + check_compliance 五字段/confidence 核验"
```

---

### Task 4: `--dengbao` 等保 2.0 控制点门禁

**Files:**
- Modify: `swarm-yuan/assets/gates-strict.sh`（追加 check_dengbao，预期 strict：4 个 fail 点）
- Modify: `swarm-yuan/assets/precheck.compliance.conf`（+3 变量）
- Modify: `swarm-yuan/assets/precheck.sh`（6 处注册，见 Global Constraints）
- Test: `swarm-yuan/tests/gate-fixtures/dengbao/{violating,compliant}/`

**Interfaces:**
- Consumes: `PRIVACY_SCAN_DIRS`（既有，勾稽用）、`SPEC_FILE`（既有）、`skip_if_unconfigured`/`fail`/`warn`/`pass`（既有）。
- Produces: flag `--dengbao`；conf `DENGBAO_LEVEL / DENGBAO_SCAN_DIRS / DENGBAO_EXEMPT_FILE`；fail ids `gate_dengbao_mfa / gate_dengbao_audit_missing / gate_dengbao_audit_fields / gate_dengbao_level_mismatch / gate_dengbao_privacy_unconfigured`。

- [ ] **Step 1: failing fixture**

`tests/gate-fixtures/dengbao/violating/scripts/precheck.conf`：

```bash
# dengbao violating：等保三级，无 MFA/无审计/spec 缺审计字段声明/未配 privacy
PROJECT_DIR="__REPO_ROOT__"
DENGBAO_LEVEL="3"
DENGBAO_SCAN_DIRS=("src")
SPEC_FILE="spec.md"
```

`tests/gate-fixtures/dengbao/violating/src/LoginService.java`：

```java
public class LoginService {
    public boolean login(String user, String password) {
        return "admin".equals(user) && "hash".equals(password);
    }
}
```

`tests/gate-fixtures/dengbao/violating/spec.md`：

```markdown
# 需求规格说明
## §23.2 等保声明
等保级别：三级
```

`tests/gate-fixtures/dengbao/violating/expected-ids`：

```
gate_dengbao_mfa
gate_dengbao_audit_missing
gate_dengbao_audit_fields
gate_dengbao_privacy_unconfigured
```

- [ ] **Step 2: 确认红灯**

```bash
bash tests/run-gate-fixture.sh dengbao
```

Expected: runner 报 `✗ 未知门禁组：dengbao（注册表无同名 flag 且非 summary）`（rc=2）——flag 未注册即红灯。

- [ ] **Step 3: conf 变量（precheck.compliance.conf 追加）**

```bash
# ===== 等保 2.0 控制点映射（--dengbao，WP-S1；GB/T 22239-2019 安全计算环境/安全建设管理）=====
DENGBAO_LEVEL=""                  # 等保级别：空=跳过；2/3=启用（启用后 fail-closed；三级起要求双因子鉴别）
DENGBAO_SCAN_DIRS=()              # 服务端源码扫描目录（MFA/审计证据）；启用但留空 → warn 披露 fail-open 风险
DENGBAO_EXEMPT_FILE=""            # 豁免登记文件（四字段：规则id|理由|审批人|日期），命中 id 的 fail 降级 warn 留痕
```

- [ ] **Step 4: check_dengbao 实现（gates-strict.sh 追加，置于 check_rtm 之后）**

```bash
check_dengbao() {
  echo "=== 等级保护 2.0 控制点映射检查（GB/T 22239-2019 安全计算环境/安全建设管理）==="
  local level="${DENGBAO_LEVEL:-}"
  if [[ -z "$level" ]]; then
    skip_if_unconfigured "DENGBAO_LEVEL 未配置（等保测评场景设 2 或 3）"
    return
  fi
  if [[ "$level" != "2" && "$level" != "3" ]]; then
    warn "未知 DENGBAO_LEVEL：${level}（仅支持 2/3），未执行"
    return
  fi
  local found=0
  # 豁免登记（四字段：规则id|理由|审批人|日期；空理由视为无效豁免不降级）
  local _exempt=""
  if [[ -n "${DENGBAO_EXEMPT_FILE:-}" && -f "${DENGBAO_EXEMPT_FILE}" ]]; then
    _exempt=$(awk -F'|' '!/^[[:space:]]*(#|$)/ { r=$2; gsub(/^[ \t]+|[ \t]+$/,"",r); if (r != "") { id=$1; gsub(/^[ \t]+|[ \t]+$/,"",id); print id } }' "$DENGBAO_EXEMPT_FILE" 2>/dev/null || true)
  fi
  _db_exempted() { printf '%s\n' "$_exempt" | grep -qF "$1"; }
  # 扫描目录就绪性（与 --crypto 同姿态：启用但留空 → warn 披露）
  if [[ ${#DENGBAO_SCAN_DIRS[@]} -eq 0 ]]; then
    warn "DENGBAO_SCAN_DIRS 未配置，MFA/审计代码证据扫描未执行（fail-open 风险）"
  fi
  local _scan_hits
  _scan_hits() { # $1=ERE；stdout=命中行（跨目录聚合，滤注释行与 example/mock）
    local d
    for d in ${DENGBAO_SCAN_DIRS[@]+"${DENGBAO_SCAN_DIRS[@]}"}; do
      [[ -d "$d" ]] || continue
      grep -rnE "$1" "$d" --include='*.java' --include='*.kt' --include='*.ts' --include='*.js' --include='*.py' --include='*.go' 2>/dev/null \
        | grep -viE 'example|mock|node_modules' \
        | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|#|\*|/\*)' || true
    done
  }
  # ① 双因子鉴别（三级起强制：两种及以上组合且至少一种密码技术；GB/T 22239-2019 三级安全计算环境）
  if [[ "$level" == "3" ]]; then
    local _mfa
    _mfa=$(_scan_hits 'TOTP|GoogleAuthenticator|twoFactor|two_factor|2FA|\bMFA\b|\bOTP\b|短信验证码|动态口令')
    if [[ -z "$_mfa" ]]; then
      if _db_exempted gate_dengbao_mfa; then
        warn "gate_dengbao_mfa: 未检出双因子鉴别证据（已豁免留痕：${DENGBAO_EXEMPT_FILE}）"
      else
        fail "gate_dengbao_mfa: 等保三级要求双因子身份鉴别（口令+密码技术/生物技术等两种及以上组合）——DENGBAO_SCAN_DIRS 内未检出 TOTP/OTP/MFA/短信验证码等证据（GB/T 22239-2019）"
        found=1
      fi
    fi
  fi
  # ② 安全审计存在性（二级 warn / 三级 fail）
  local _audit
  _audit=$(_scan_hits 'audit|Audit|审计')
  if [[ -z "$_audit" ]]; then
    if [[ "$level" == "3" ]]; then
      if _db_exempted gate_dengbao_audit_missing; then
        warn "gate_dengbao_audit_missing: 未检出安全审计日志调用（已豁免留痕）"
      else
        fail "gate_dengbao_audit_missing: 未检出安全审计日志调用（audit/审计）——等保三级安全审计控制点要求记录并保护审计记录（GB/T 22239-2019）"
        found=1
      fi
    else
      warn "未检出安全审计日志调用（audit/审计）——等保二级建议补审计记录（GB/T 22239-2019）"
    fi
  fi
  # ③ 审计字段四要素声明（spec §23.2：日期时间/用户/事件类型/事件是否成功）
  local _spec="${SPEC_FILE:-}"
  if [[ -z "$_spec" || ! -f "$_spec" ]]; then
    if _db_exempted gate_dengbao_audit_fields; then
      warn "gate_dengbao_audit_fields: SPEC_FILE 未配置（已豁免留痕）"
    else
      fail "gate_dengbao_audit_fields: SPEC_FILE 未配置或不存在——无法核验审计字段四要素声明（spec §23.2 须声明：日期时间/用户/事件类型/事件是否成功）"
      found=1
    fi
  else
    local _fmiss=""
    grep -qF '日期时间' "$_spec" 2>/dev/null || _fmiss="${_fmiss}日期时间 "
    grep -qF '用户' "$_spec" 2>/dev/null || _fmiss="${_fmiss}用户 "
    grep -qF '事件类型' "$_spec" 2>/dev/null || _fmiss="${_fmiss}事件类型 "
    grep -qE '事件是否成功|成功与否' "$_spec" 2>/dev/null || _fmiss="${_fmiss}事件是否成功 "
    if [[ -n "$_fmiss" ]]; then
      if _db_exempted gate_dengbao_audit_fields; then
        warn "gate_dengbao_audit_fields: spec 审计字段声明缺：${_fmiss}（已豁免留痕）"
      else
        fail "gate_dengbao_audit_fields: spec §23.2 审计字段声明缺要素：${_fmiss}（GB/T 22239-2019：审计记录应包括事件的日期和时间、用户、事件类型、事件是否成功及其他审计相关信息）"
        found=1
      fi
    fi
    # ④ 等保级别一致性（spec 声明级别 vs DENGBAO_LEVEL）
    local _spec_lv
    _spec_lv=$(grep -oE '等保[^0-9]*[23]级' "$_spec" 2>/dev/null | grep -oE '[23]' | head -1 || true)
    if [[ -z "$_spec_lv" ]]; then
      warn "spec §23.2 未声明等保级别（建议补充「等保级别：X 级」）"
    elif [[ "$_spec_lv" != "$level" ]]; then
      if _db_exempted gate_dengbao_level_mismatch; then
        warn "gate_dengbao_level_mismatch: spec 声明 ${_spec_lv} 级 vs DENGBAO_LEVEL=${level}（已豁免留痕）"
      else
        fail "gate_dengbao_level_mismatch: spec 声明等保 ${_spec_lv} 级与 DENGBAO_LEVEL=${level} 不一致——立法（spec）与执法（conf）必须同源"
        found=1
      fi
    fi
  fi
  # ⑤ 个人信息保护勾稽（二级起要求；--privacy 须在配）
  if [[ ${#PRIVACY_SCAN_DIRS[@]} -eq 0 ]]; then
    if _db_exempted gate_dengbao_privacy_unconfigured; then
      warn "gate_dengbao_privacy_unconfigured: PRIVACY_SCAN_DIRS 未配置（已豁免留痕）"
    else
      fail "gate_dengbao_privacy_unconfigured: PRIVACY_SCAN_DIRS 未配置——等保二级起要求个人信息保护，须启用 --privacy 扫描（GB/T 22239-2019 个人信息保护控制点）"
      found=1
    fi
  fi
  # ⑥ 剩余信息保护（warn-only：敏感数据清除证据）
  local _resid
  _resid=$(_scan_hits 'Arrays\.fill|shred|secureErase|SecureRandom|清除敏感|内存清零')
  [[ -z "$_resid" ]] && warn "未检出剩余信息保护证据（敏感数据存储空间清除/释放，如 Arrays.fill/shred）——建议人工核对（GB/T 22239-2019 剩余信息保护）"
  [[ $found -eq 0 ]] && pass "等保 ${level} 级控制点映射检查通过（GB/T 22239-2019）"
}
```

- [ ] **Step 5: 6 处注册（precheck.sh）**

1. `ALL_GATES_COMPLIANCE=(...)` 行尾 `check_release_sign)` 前插入 `check_dengbao `；
2. `ALL_GATES_FULL=(...)` 同样位置插入；
3. `GATE_FLAGS=(...)` 行 `--release-sign)` 前插入 `--dengbao `；
4. shellcheck 静态锚点块 `check_authz; check_requirements; check_crypto; check_rtm; check_release_sign` 行尾追加 `; check_dengbao`；
5. usage 头注释 `--rtm` 行后加：`#   bash precheck.sh --dengbao        # 等保 2.0 控制点映射（GB/T 22239-2019，DENGBAO_LEVEL=2/3）`；
6. `_fix_suggest` case 中 `gate_crypto_*)` 行后加：

```bash
    gate_dengbao_*)                suggest="等保控制点缺口（GB/T 22239-2019）——补双因子/审计日志/审计字段声明，或在 DENGBAO_EXEMPT_FILE 四字段登记豁免";;
```

- [ ] **Step 6: compliant fixture + 双态验证**

`tests/gate-fixtures/dengbao/compliant/scripts/precheck.conf`：

```bash
PROJECT_DIR="__REPO_ROOT__"
DENGBAO_LEVEL="3"
DENGBAO_SCAN_DIRS=("src")
SPEC_FILE="spec.md"
PRIVACY_SCAN_DIRS=("src")
```

`tests/gate-fixtures/dengbao/compliant/src/LoginService.java`：

```java
public class LoginService {
    private static final Logger audit = LoggerFactory.getLogger("audit");
    public boolean login(String user, String password, String smsCode) {
        // 双因子：口令 + 短信验证码
        boolean ok = verifyPassword(user, password) && SmsCodeUtil.verify(user, smsCode);
        audit.info("login user={} result={}", user, ok);
        return ok;
    }
}
```

`tests/gate-fixtures/dengbao/compliant/spec.md`：

```markdown
# 需求规格说明
## §23.2 等保声明
等保级别：三级
审计字段：日期时间、用户、事件类型、事件是否成功、来源 IP。
```

`tests/gate-fixtures/dengbao/compliant/forbidden-ids`：

```
gate_dengbao_mfa
gate_dengbao_audit_missing
gate_dengbao_audit_fields
gate_dengbao_level_mismatch
gate_dengbao_privacy_unconfigured
```

```bash
bash tests/run-gate-fixture.sh dengbao
bash tests/run-gate-fixture.sh    # 全量回归
```

Expected: violating FAIL 四 id 全命中；compliant PASS（warn 不影响 rc）；36+1 组全绿。

- [ ] **Step 7: shellcheck + 提交**

```bash
shellcheck -x -e SC2086,SC1090,SC1091,SC2155,SC2034,SC2230,SC2004,SC2312 assets/precheck.sh assets/gates-strict.sh || echo "本机无 shellcheck，交 CI"
git add assets/ tests/gate-fixtures/dengbao/
git commit -m "feat(wp-s1): --dengbao 等保2.0控制点门禁（GB/T 22239 二/三级分级，fail-closed+豁免留痕）"
```

---

### Task 5: `--pia` 隐私影响评估门禁

**Files:**
- Modify: `swarm-yuan/assets/gates-strict.sh`（追加 check_pia，3 个 fail 点 → strict）
- Modify: `swarm-yuan/assets/precheck.compliance.conf`（+2 变量）
- Modify: `swarm-yuan/assets/precheck.sh`（6 处注册）
- Test: `swarm-yuan/tests/gate-fixtures/pia/{violating,compliant}/`

**Interfaces:**
- Consumes: `PRIVACY_SCAN_DIRS`（清单一致性核对）、`skip_if_unconfigured` 等。
- Produces: flag `--pia`；conf `PIA_DOCS_DIR / PIA_REQUIRED`；fail ids `gate_pia_doc_missing / gate_pia_inventory_missing / gate_pia_tbd`。

- [ ] **Step 1: failing fixture**

`tests/gate-fixtures/pia/violating/scripts/precheck.conf`：

```bash
PROJECT_DIR="__REPO_ROOT__"
PIA_REQUIRED=1
PIA_DOCS_DIR="docs/privacy"
PRIVACY_SCAN_DIRS=("src")
```

`tests/gate-fixtures/pia/violating/docs/privacy/pia-2026.md`：

```markdown
# 隐私影响评估报告
## 处理活动
TBD：待补充
```

（刻意缺"处理活动清单"文件 + PIA 文档含 TBD。）

`tests/gate-fixtures/pia/violating/src/App.java`：`public class App {}`（占位，供 PRIVACY_SCAN_DIRS 存在）

`tests/gate-fixtures/pia/violating/expected-ids`：

```
gate_pia_inventory_missing
gate_pia_tbd
```

- [ ] **Step 2: 确认红灯**

```bash
bash tests/run-gate-fixture.sh pia
```

Expected: `✗ 未知门禁组：pia`（rc=2）。

- [ ] **Step 3: conf 变量**

```bash
# ===== 隐私影响评估（--pia，WP-S1；个保法第55-56条 / GB/T 35273-2020）=====
PIA_REQUIRED=0                    # 设 1 启用 PIA 检查（启用后 fail-closed）
PIA_DOCS_DIR=""                   # PIA 文档目录，空则默认 docs/privacy
```

- [ ] **Step 4: check_pia 实现（gates-strict.sh，check_dengbao 之后）**

```bash
check_pia() {
  echo "=== 隐私影响评估（PIA）检查（个人信息保护法第55-56条 / GB/T 35273-2020）==="
  [[ "${PIA_REQUIRED:-0}" == "1" ]] || { skip_if_unconfigured "PIA_REQUIRED 未启用，PIA 检查跳过"; return; }
  local dir="${PIA_DOCS_DIR:-docs/privacy}"
  local found=0
  if [[ ! -d "$dir" ]]; then
    fail "gate_pia_doc_missing: PIA 文档目录不存在：${dir}（PIA_REQUIRED=1，fail-closed；个保法第55条：处理敏感个人信息等情形须事前进行个人信息保护影响评估）"
    return
  fi
  # ① PIA 评估文档存在性
  local _pia_doc
  _pia_doc=$(find "$dir" -maxdepth 2 -type f \( -iname '*pia*' -o -name '*隐私影响评估*' -o -name '*影响评估*' \) 2>/dev/null | head -1)
  if [[ -z "$_pia_doc" ]]; then
    fail "gate_pia_doc_missing: PIA 评估文档不存在（${dir} 下未见 *pia*/ *隐私影响评估* 文件；个保法第55-56条）"
    found=1
  fi
  # ② 个人信息处理活动清单存在性
  local _inv
  _inv=$(find "$dir" -maxdepth 2 -type f \( -name '*清单*' -o -iname '*inventory*' -o -iname '*register*' -o -iname '*activities*' \) 2>/dev/null | head -1)
  if [[ -z "$_inv" ]]; then
    fail "gate_pia_inventory_missing: 个人信息处理活动清单不存在（${dir} 下未见 *清单*/*inventory*/*register* 文件；GB/T 35273-2020 处理活动记录）"
    found=1
  fi
  # ③ PIA 文档零 TBD（评估报告不得含待定项）
  local _tbd
  _tbd=$(grep -rnE 'TBD|待定|待明确|待补充' "$dir" 2>/dev/null || true)
  if [[ -n "$_tbd" ]]; then
    fail "gate_pia_tbd: PIA 文档含待定项（TBD/待定/待明确/待补充）——评估结论必须完整：
$(printf '%s\n' "$_tbd" | head -5 | sed 's/^/    /')"
    found=1
  fi
  # ④ 清单覆盖勾稽（warn-only：PRIVACY_SCAN_DIRS 各目录应在清单中有引用）
  if [[ -n "$_inv" && ${#PRIVACY_SCAN_DIRS[@]} -gt 0 ]]; then
    local d _base
    for d in ${PRIVACY_SCAN_DIRS[@]+"${PRIVACY_SCAN_DIRS[@]}"}; do
      _base=$(basename "$d")
      grep -qF "$_base" "$_inv" 2>/dev/null || warn "处理活动清单（${_inv}）未引用 PRIVACY_SCAN_DIRS 目录：${d}——请核对登记完整性"
    done
  fi
  [[ $found -eq 0 ]] && pass "PIA 检查通过（评估文档+处理活动清单齐备，零待定项）"
}
```

- [ ] **Step 5: 6 处注册（同 Task 4 Step 5 模式，flag `--pia`、函数 `check_pia`、usage 注释 `# 隐私影响评估（个保法/GB/T 35273，PIA_REQUIRED=1）`、suggest：**

```bash
    gate_pia_*)                    suggest="补 PIA 评估文档与个人信息处理活动清单（个保法第55-56条/GB/T 35273），消除文档待定项";;
```

）

- [ ] **Step 6: compliant fixture + 双态验证**

`tests/gate-fixtures/pia/compliant/scripts/precheck.conf`：同 violating 但指向齐备文档。

`tests/gate-fixtures/pia/compliant/docs/privacy/pia-2026.md`：

```markdown
# 隐私影响评估报告
## 评估结论
本系统处理用户手机号用于登录验证，已评估风险并采取加密存储措施。
```

`tests/gate-fixtures/pia/compliant/docs/privacy/个人信息处理活动清单.md`：

```markdown
# 个人信息处理活动清单
| 目录 | 处理活动 | 信息类型 |
| src | 登录验证 | 手机号 |
```

`tests/gate-fixtures/pia/compliant/src/App.java`：`public class App {}`

`tests/gate-fixtures/pia/compliant/forbidden-ids`：

```
gate_pia_doc_missing
gate_pia_inventory_missing
gate_pia_tbd
```

```bash
bash tests/run-gate-fixture.sh pia && bash tests/run-gate-fixture.sh
```

Expected: 双态绿 + 全量 38 组绿。

- [ ] **Step 7: 提交**

```bash
git add assets/ tests/gate-fixtures/pia/
git commit -m "feat(wp-s1): --pia 隐私影响评估门禁（个保法55-56条/GB/T 35273，fail-closed）"
```

---

### Task 6: `--sast-deep` 深度 SAST 门禁

**Files:**
- Modify: `swarm-yuan/assets/gates-warn.sh`（追加 check_sast_deep，2 个 fail 点 → warn 档）
- Modify: `swarm-yuan/assets/precheck.compliance.conf`（+2 变量）
- Modify: `swarm-yuan/assets/precheck.sh`（6 处注册）
- Test: `swarm-yuan/tests/gate-fixtures/sast-deep/{violating,violating-builtin,compliant}/`（semgrep 用 fixture 内 mock，批次铁律④）

**Interfaces:**
- Consumes: `SECURITY_SCAN_DIRS`（既有，扫描目录复用）。
- Produces: flag `--sast-deep`；conf `SAST_DEEP_TOOL / SAST_DEEP_SEVERITY`；fail ids `gate_sast_deep_findings / gate_sast_deep_builtin`。

- [ ] **Step 1: failing fixture（mock semgrep）**

`tests/gate-fixtures/sast-deep/violating/scripts/precheck.conf`：

```bash
PROJECT_DIR="__REPO_ROOT__"
SECURITY_SCAN_DIRS=("src")
SAST_DEEP_TOOL="auto"
SAST_DEEP_SEVERITY="error"
```

`tests/gate-fixtures/sast-deep/violating/scripts/setup.sh`（runner 钩子：precheck 前执行，cwd=fixture；放 mock semgrep 进 PATH——runner 继承 PATH 需确认，若 runner 不继承则在 conf 同目录放 mock 并由 SAST_DEEP_TOOL 指向绝对路径）：

```bash
#!/usr/bin/env bash
# mock semgrep：输出含 1 条 ERROR severity 结果的 JSON
mkdir -p .mockbin
cat > .mockbin/semgrep <<'EOF'
#!/usr/bin/env bash
echo '{"results":[{"check_id":"test.sql-injection","severity":"ERROR","path":"src/App.java","line":3}]}'
EOF
chmod +x .mockbin/semgrep
printf '%s\n' "$PWD/.mockbin" > .mockbin-path
```

`tests/gate-fixtures/sast-deep/violating/scripts/teardown.sh`：`rm -rf .mockbin .mockbin-path`

conf 中 SAST_DEEP_TOOL 指向 mock：`SAST_DEEP_TOOL="__REPO_ROOT__/.mockbin/semgrep"`（实现须支持：TOOL 为可执行路径时直接调用——替换 conf 中 auto 行为此行）。

`tests/gate-fixtures/sast-deep/violating/src/App.java`：`public class App {}`

`tests/gate-fixtures/sast-deep/violating/expected-ids`：`gate_sast_deep_findings`

- [ ] **Step 2: 确认红灯**（`bash tests/run-gate-fixture.sh sast-deep` → 未知门禁组 rc=2）

- [ ] **Step 3: conf 变量**

```bash
# ===== 深度 SAST（--sast-deep，WP-S1；GB/T 34943/34944/34946-2017 漏洞类别，AST/数据流层）=====
SAST_DEEP_TOOL=""                 # 空/auto=按 semgrep→opengrep→内置词法降级链；或填可执行路径（含 fixture mock）；"builtin"=强制内置
SAST_DEEP_SEVERITY="error"        # 达标即 fail 的严重级别：error（默认）/warning
```

- [ ] **Step 4: check_sast_deep 实现（gates-warn.sh 追加，check_crypto 之后）**

```bash
check_sast_deep() {
  echo "=== 深度 SAST 检查（AST/数据流层；GB/T 34943/34944/34946-2017 源代码漏洞测试规范）==="
  if [[ ${#SECURITY_SCAN_DIRS[@]} -eq 0 ]]; then
    skip_if_unconfigured "SECURITY_SCAN_DIRS 未配置，深度 SAST 跳过"
    return
  fi
  local tool="${SAST_DEEP_TOOL:-auto}" sev="${SAST_DEEP_SEVERITY:-error}" found=0
  local bin=""
  if [[ "$tool" == "builtin" ]]; then
    bin="builtin"
  elif [[ "$tool" != "auto" && -n "$tool" ]]; then
    if [[ -x "$tool" ]]; then bin="$tool"; else warn "SAST_DEEP_TOOL=${tool} 不可执行，降级自动探测"; fi
  fi
  if [[ -z "$bin" ]]; then
    if command -v semgrep >/dev/null 2>&1; then bin="semgrep"
    elif command -v opengrep >/dev/null 2>&1; then bin="opengrep"
    else bin="builtin"; fi
  fi
  local dirs="${SECURITY_SCAN_DIRS[*]}"
  if [[ "$bin" == "builtin" ]]; then
    # 自带降级载体（词法模式族，明示降级；与 check_security 互补不重复——仅高危 sink 直查）
    echo "  ⓘ 降级为内置词法模式族（semgrep/opengrep 不可用；AST/数据流层未执行）"
    trace_tool "sast-deep" "builtin-lexical"
    local hits
    hits=$(grep -rnE '\beval\s*\(|\bexec\s*\(|Runtime\.getRuntime\(\)\.exec|child_process\.exec' $dirs \
      --include='*.java' --include='*.ts' --include='*.js' --include='*.py' --include='*.go' 2>/dev/null \
      | grep -viE 'example|mock|node_modules' \
      | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|#|\*|/\*)' || true)
    if [[ -n "$hits" ]]; then
      fail "gate_sast_deep_builtin: 内置模式族检出高危代码执行 sink（eval/exec/Runtime.exec）：
$(printf '%s\n' "$hits'")" 2>/dev/null; printf '%s\n' "$hits" | head -10 | sed 's/^/    /'
      found=1
    fi
  else
    echo "  ⓘ SAST 载体：${bin}（AST/规则层）"
    trace_tool "sast-deep" "$bin"
    local json _rc=0
    json=$("$bin" scan --config p/default --json --quiet $dirs 2>/dev/null) || _rc=$?
    if [[ $_rc -ne 0 || -z "$json" ]]; then
      # 网络/规则包不可达（离线环境 p/default 拉取失败）→ 降级内置，明示
      warn "${bin} 执行失败或无输出（rc=${_rc}；离线环境规则包不可达）——降级内置词法模式族"
      local hits
      hits=$(grep -rnE '\beval\s*\(|\bexec\s*\(|Runtime\.getRuntime\(\)\.exec|child_process\.exec' $dirs \
        --include='*.java' --include='*.ts' --include='*.js' --include='*.py' --include='*.go' 2>/dev/null \
        | grep -viE 'example|mock|node_modules' \
        | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|#|\*|/\*)' || true)
      if [[ -n "$hits" ]]; then
        fail "gate_sast_deep_builtin: 内置模式族检出高危代码执行 sink：
$(printf '%s\n' "$hits" | head -10 | sed 's/^/    /')"
        found=1
      fi
    else
      local _e _w
      _e=$(printf '%s\n' "$json" | grep -cE '"severity"[^,]*ERROR' || true)
      _w=$(printf '%s\n' "$json" | grep -cE '"severity"[^,]*WARNING' || true)
      echo "  ⓘ ${bin} 结果：ERROR=${_e} WARNING=${_w}"
      if [[ "$sev" == "warning" && $((_e+_w)) -gt 0 ]] || [[ "$sev" == "error" && "$_e" -gt 0 ]]; then
        fail "gate_sast_deep_findings: ${bin} 检出达标严重级别（${sev}）以上发现 ERROR=${_e} WARNING=${_w}（GB/T 34943/34944/34946 漏洞类别）——详见 ${bin} JSON 输出"
        found=1
      fi
    fi
  fi
  [[ $found -eq 0 ]] && pass "深度 SAST 检查通过（载体：${bin}）"
}
```

注意：builtin 分支 fail 消息里 `$(printf '%s\n' "$hits'")"` 为笔误风险——实现时统一用第二个分支的写法（先 `fail "...："` 再 `printf | head | sed` 两行），两个分支消息体结构保持一致。

- [ ] **Step 5: 6 处注册**（flag `--sast-deep`、函数 `check_sast_deep`、suggest：）

```bash
    gate_sast_deep_*)              suggest="深度 SAST 检出漏洞（GB/T 34943/44/46）——修复代码执行/注入 sink，或升级 SAST_DEEP_SEVERITY 阈值语义";;
```

- [ ] **Step 6: violating-builtin + compliant fixture**

`tests/gate-fixtures/sast-deep/violating-builtin/scripts/precheck.conf`：

```bash
PROJECT_DIR="__REPO_ROOT__"
SECURITY_SCAN_DIRS=("src")
SAST_DEEP_TOOL="builtin"
SAST_DEEP_SEVERITY="error"
```

`violating-builtin/src/App.java`：

```java
public class App { void run(String cmd) throws Exception { Runtime.getRuntime().exec(cmd); } }
```

`violating-builtin/expected-ids`：`gate_sast_deep_builtin`

`tests/gate-fixtures/sast-deep/compliant/scripts/precheck.conf`：同 violating-builtin（TOOL=builtin）。

`compliant/src/App.java`：`public class App { int add(int a, int b) { return a + b; } }`

`compliant/expect-output`：`深度 SAST 检查通过`

```bash
bash tests/run-gate-fixture.sh sast-deep && bash tests/run-gate-fixture.sh
```

Expected: 三组双态全绿 + 全量回归绿。

- [ ] **Step 7: 提交**

```bash
git add assets/ tests/gate-fixtures/sast-deep/
git commit -m "feat(wp-s1): --sast-deep 深度SAST门禁（semgrep→opengrep→内置降级链，GB/T 34943/44/46）"
```

---

### Task 7: `--oss-eval` 开源代码安全评价门禁

**Files:**
- Modify: `swarm-yuan/assets/gates-warn.sh`（追加 check_oss_eval，2 个 fail 点 → warn 档）
- Modify: `swarm-yuan/assets/precheck.compliance.conf`（+1 变量）
- Modify: `swarm-yuan/assets/precheck.sh`（6 处注册）
- Test: `swarm-yuan/tests/gate-fixtures/oss-eval/{violating,compliant}/`

**Interfaces:**
- Consumes: `SBOM_OUTPUT_DIR` / `SBOM_LICENSE_BLOCKLIST` / `SBOM_LICENSE_EXEMPTIONS`（既有 sbom 门禁变量，复用不重复扫描）。
- Produces: flag `--oss-eval`；conf `OSS_EVAL_REQUIRED`；fail ids `gate_oss_eval_sbom_missing / gate_oss_eval_license_blocked`。

- [ ] **Step 1: failing fixture**

`tests/gate-fixtures/oss-eval/violating/scripts/precheck.conf`：

```bash
PROJECT_DIR="__REPO_ROOT__"
OSS_EVAL_REQUIRED=1
SBOM_OUTPUT_DIR=".sbom"
SBOM_LICENSE_BLOCKLIST=("GPL-3.0" "AGPL")
```

`tests/gate-fixtures/oss-eval/violating/.sbom/sbom.json`（sbom 存在但含块名单许可证——覆盖 fail②；fail①由 violating 变体覆盖，见下）：

```json
{"bomFormat":"CycloneDX","components":[{"name":"left-pad","license":"GPL-3.0"}]}
```

`tests/gate-fixtures/oss-eval/violating/expected-ids`：`gate_oss_eval_license_blocked`

再建 `tests/gate-fixtures/oss-eval/violating-no-sbom/`（conf 同上但无 .sbom 目录），`expected-ids`：`gate_oss_eval_sbom_missing`。

- [ ] **Step 2: 确认红灯**（未知门禁组 rc=2）

- [ ] **Step 3: conf 变量**

```bash
# ===== 开源代码安全评价（--oss-eval，WP-S1；GB/T 43848-2024 四维：来源/安全质量/知识产权/管理）=====
# 措辞纪律：本标准将成分清单与许可证合规纳入评价体系，不宣称"强制提交 SBOM"
OSS_EVAL_REQUIRED=0               # 设 1 启用开源代码安全评价（启用后 fail-closed；复用 --sbom 产物）
```

- [ ] **Step 4: check_oss_eval 实现（gates-warn.sh，check_sast_deep 之后）**

```bash
check_oss_eval() {
  echo "=== 开源代码安全评价（GB/T 43848-2024：来源/安全质量/知识产权/管理四维）==="
  [[ "${OSS_EVAL_REQUIRED:-0}" == "1" ]] || { skip_if_unconfigured "OSS_EVAL_REQUIRED 未启用，开源代码安全评价跳过"; return; }
  local found=0
  # ① 成分清单存在（复用 --sbom 产物；sbom 未跑时本门禁独立核验目录）
  local dir="${SBOM_OUTPUT_DIR:-.sbom}"
  local _sbom_files
  _sbom_files=$(find "$dir" -type f \( -name '*.json' -o -name '*.spdx' -o -name '*.xml' -o -name '*.txt' \) 2>/dev/null | head -20)
  if [[ -z "$_sbom_files" ]]; then
    fail "gate_oss_eval_sbom_missing: 开源成分清单产物不存在（${dir}；GB/T 43848-2024 将成分清单纳入评价体系——先运行 --sbom 生成）"
    found=1
  fi
  # ② 许可证遵从（块名单扫描成分清单）
  if [[ -n "$_sbom_files" && ${#SBOM_LICENSE_BLOCKLIST[@]} -gt 0 ]]; then
    local lic _hits=""
    for lic in ${SBOM_LICENSE_BLOCKLIST[@]+"${SBOM_LICENSE_BLOCKLIST[@]}"}; do
      local h
      h=$(printf '%s\n' "$_sbom_files" | xargs grep -lF "$lic" 2>/dev/null || true)
      [[ -n "$h" ]] && _hits="${_hits}${lic}→$(printf '%s\n' "$h" | head -3 | tr '\n' ' ') "
    done
    if [[ -n "$_hits" ]]; then
      fail "gate_oss_eval_license_blocked: 成分清单命中许可证块名单：${_hits}（GB/T 43848-2024 知识产权维度：开源许可证遵从度评价）"
      found=1
    fi
  fi
  # ③ 上游来源登记（管理维度，warn-only）
  if [[ ! -f docs/upstream-baseline.md && ! -f UPSTREAM.md && ! -f docs/UPSTREAM.md ]]; then
    warn "未见上游来源登记文档（docs/upstream-baseline.md 或 UPSTREAM.md）——GB/T 43848-2024 来源维度建议登记开源成分来源"
  fi
  # ④ 豁免到期检查（warn-only：SBOM_LICENSE_EXEMPTIONS 五字段第 5 字段日期 < 今天）
  if [[ ${#SBOM_LICENSE_EXEMPTIONS[@]} -gt 0 ]]; then
    local today ex _d
    today=$(date -u +%Y-%m-%d)
    for ex in ${SBOM_LICENSE_EXEMPTIONS[@]+"${SBOM_LICENSE_EXEMPTIONS[@]}"}; do
      _d=$(printf '%s\n' "$ex" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$5); print $5}')
      if [[ -n "$_d" && "$_d" < "$today" ]]; then
        warn "开源许可证豁免已过期：${ex}（到期日 ${_d} < ${today}）——须复审或移除"
      fi
    done
  fi
  [[ $found -eq 0 ]] && pass "开源代码安全评价通过（成分清单在案，许可证未命中块名单）"
}
```

- [ ] **Step 5: 6 处注册**（flag `--oss-eval`、函数 `check_oss_eval`、suggest：）

```bash
    gate_oss_eval_*)               suggest="开源代码评价缺口（GB/T 43848-2024）——先跑 --sbom 生成成分清单，清理块名单许可证或登记五字段豁免";;
```

- [ ] **Step 6: compliant fixture + 双态验证**

`tests/gate-fixtures/oss-eval/compliant/scripts/precheck.conf`：同 violating。

`compliant/.sbom/sbom.json`：

```json
{"bomFormat":"CycloneDX","components":[{"name":"left-pad","license":"MIT"}]}
```

`compliant/docs/upstream-baseline.md`：`# 上游基线\n\nbaseline_status=synced`

`compliant/forbidden-ids`：

```
gate_oss_eval_sbom_missing
gate_oss_eval_license_blocked
```

```bash
bash tests/run-gate-fixture.sh oss-eval && bash tests/run-gate-fixture.sh
```

Expected: 三个 fixture 目录双态全绿 + 全量回归绿。

- [ ] **Step 7: 提交**

```bash
git add assets/ tests/gate-fixtures/oss-eval/
git commit -m "feat(wp-s1): --oss-eval 开源代码安全评价门禁（GB/T 43848-2024 四维，复用sbom产物）"
```

---

### Task 8: 政务行业 profile `gov`

**Files:**
- Create: `swarm-yuan/assets/industry-profiles/gov.conf`
- Create: `swarm-yuan/references/industry-profile-gov.md`
- Test: `swarm-yuan/tests/run-industry-profile.sh`（新建轻量断言脚本）

**Interfaces:**
- Consumes: Task 4-7 的 conf 变量（DENGBAO_LEVEL/PIA_REQUIRED/OSS_EVAL_REQUIRED）与既有 CRYPTO_PROFILE/PRIVACY_SCAN_DIRS/DOCS_PACK_PROFILE/GATE_RUNS_DIR。
- Produces: `gov` profile 可被目标 skill 以 `cat assets/industry-profiles/gov.conf >> scripts/precheck.conf` 方式启用（与 finance/medical 同机制）。

- [ ] **Step 1: gov.conf（结构对齐 finance.conf：每段挂条款依据 + fail-closed 姿态约定）**

```bash
# gov.conf —— 政务/关键信息基础设施行业 profile 配置覆盖包（WP-S1）
# =============================================================================
# 用法：把本文件整体追加到 precheck.conf 末尾，再按项目实际裁剪——
#   cat assets/industry-profiles/gov.conf >> <目标 skill>/scripts/precheck.conf
# bash 后赋值覆盖先赋值；占位值（<...>）必须替换为真实路径。
# 姿态约定：未配置的门禁静默跳过；下列安全类门禁启用后 fail-closed；豁免按
# references/standards-compliance.md §F.2 五字段登记，空理由视为无效豁免 → fail。
# 条款依据：references/industry-profile-gov.md（政务 profile 立法文档）。
# =============================================================================

# ===== 等级保护（--dengbao）=====
# 依据：GB/T 22239-2019（等保 2.0 基本要求）；《网络安全法》第 21 条（等级保护制度）；
#       GB/T 39204-2022（关基保护要求）。政务系统原则上三级起步。
# 判定：启用后 fail-closed——双因子/审计/审计字段/个人信息保护缺口 → fail。
DENGBAO_LEVEL="3"
DENGBAO_SCAN_DIRS=("<必填：服务端源码目录>")

# ===== 密码合规（--crypto）=====
# 依据：GB/T 39786-2021（密评）；《密码法》2020 +《商用密码管理条例》2023；
#       政务系统密评常态化（等保三级系统须开展商用密码应用安全性评估）。
CRYPTO_PROFILE="gm"
CRYPTO_SCAN_DIRS=("<必填：服务端源码目录>")

# ===== 个人信息保护（--privacy + --pia）=====
# 依据：《个人信息保护法》2021 第 55-56 条（PIA 与记录）；GB/T 35273-2020；
#       《数据安全法》2021（政务数据安全）。
PRIVACY_SCAN_DIRS=("<必填：源码目录>" "<必填：测试/夹具目录>")
PIA_REQUIRED=1
PIA_DOCS_DIR="docs/privacy"

# ===== 供应链与开源评价（--sbom + --oss-eval）=====
# 依据：GB/T 43848-2024（开源代码安全评价：成分清单/许可证纳入评价体系）；
#       GB/T 36637-2018（ICT 供应链安全）；GB/T 39204-2022 7.9（关基供应链）。
SBOM_REQUIRED=1
SBOM_LICENSE_BLOCKLIST=("GPL-3.0" "AGPL")
OSS_EVAL_REQUIRED=1

# ===== 交付文档包（--docs-pack）=====
# 依据：GB/T 8567-2006；等保测评须提交系统定级报告/安全建设整改方案等文档（GB/T 28448-2019）。
DOCS_PACK_PROFILE="gbt8567"
DOCS_PACK_REQUIRED=("软件需求规格说明" "软件设计说明" "软件测试计划" "软件测试报告" "软件用户手册" "软件产品规格说明")

# ===== 发布签名（--release-sign）=====
# 依据：GB/T 39204-2022 7.9 f)（交付关键环节安全管理）；NIST SP 800-218 PS.2。
RELEASE_SIGN_REQUIRED=1

# ===== 需求与追溯（--requirements/--rtm）=====
# 依据：ISO/IEC/IEEE 29148（政府采购软件验收惯例：需求条目唯一编号+双向追溯）。
REQUIREMENTS_STRICT=1
REQUIREMENTS_ID_REQUIRED=1
RTM_REQUIRED=1
RTM_MATRIX_REQUIRED=1

# ===== 证据留痕 =====
GATE_RUNS_DIR=".swarm-yuan/gate-runs"
```

- [ ] **Step 2: 立法文档 references/industry-profile-gov.md**（结构对齐 industry-profile-finance.md：定位/适用/条款→门禁映射表/差额项人工核对清单/证据 URL 与访问日期 2026-07-22）

必含章节：①定位与适用（政务/关基/事业单位信息化）；②条款→门禁映射表（网络安全法§21→dengbao；密码法+GB/T 39786→crypto；个保法§55-56→pia+privacy；GB/T 43848→oss-eval+sbom；GB/T 8567→docs-pack；GB/T 39204 7.9→release-sign+sbom）；③差额项人工核对清单（等保测评机构测评本身、密评机构评估、定级备案——门禁不可替代的线下环节）；④证据来源清单（openstd.samr.gov.cn 标准页 + 法律原文，访问日期 2026-07-22）。每条款标注置信（高=官方平台已核验；回避纪律：不虚构条款号）。

- [ ] **Step 3: profile 断言脚本 tests/run-industry-profile.sh**

```bash
#!/usr/bin/env bash
# run-industry-profile.sh —— 行业 profile 覆盖断言：profile 追加到 precheck.conf 后关键变量生效
# 用法: bash tests/run-industry-profile.sh <profile-id>（finance/medical/gov）
set -u
BASE="$(cd "$(dirname "$0")/.." && pwd)"
P="${1:?用法: run-industry-profile.sh <profile-id>}"
CONF_SRC="${BASE}/assets/industry-profiles/${P}.conf"
[[ -f "$CONF_SRC" ]] || { echo "✗ profile 不存在：${P}"; exit 2; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/swarm-yuan-profile.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cp "${BASE}/assets/precheck.conf" "$TMP/precheck.conf"
cat "$CONF_SRC" >> "$TMP/precheck.conf"
# source 后断言关键变量（conf 语法错误会在 source 时暴露）
( source "$TMP/precheck.conf" >/dev/null 2>&1 || true
  rc=0
  check() { # $1=变量名 $2=期望值（空=只查非空）
    local v
    eval "v=\"\${$1:-}\""
    if [[ -n "$2" ]]; then [[ "$v" == "$2" ]] || { echo "  ✗ $1 期望 $2 实得 '$v'"; rc=1; }
    else [[ -n "$v" ]] || { echo "  ✗ $1 为空"; rc=1; }; fi
  }
  case "$P" in
    gov)
      check DENGBAO_LEVEL 3
      check CRYPTO_PROFILE gm
      check PIA_REQUIRED 1
      check OSS_EVAL_REQUIRED 1
      check SBOM_REQUIRED 1
      check DOCS_PACK_PROFILE gbt8567
      ;;
    finance) check CRYPTO_PROFILE gm; check SBOM_REQUIRED 1 ;;
    medical) check PRIVACY_SCAN_DIRS "" ;;
    *) echo "✗ 未登记的 profile 断言集：${P}"; exit 2 ;;
  esac
  exit $rc ) || { echo "✗ profile ${P} 断言失败"; exit 1; }
echo "✓ profile ${P} 覆盖断言通过"
```

- [ ] **Step 4: 验证 + 提交**

```bash
bash tests/run-industry-profile.sh gov
bash tests/run-industry-profile.sh finance
git add assets/industry-profiles/gov.conf references/industry-profile-gov.md tests/run-industry-profile.sh
git commit -m "feat(wp-s1): 政务行业profile gov（等保三级+密评+PIA+开源评价，GB/T 22239/39786/43848）"
```

---

### Task 9: 真实项目冒烟 CI job

**Files:**
- Modify: `.github/workflows/ci.yml`（追加 real-project-smoke job）

**Interfaces:**
- Consumes: `scripts/generate-skill.sh`（生成目标 skill）、`assets/precheck.sh`（骨架 --all 冒烟）。
- Produces: CI 冒烟 job——后续所有改动若破坏真实项目可用性（R9 三缺陷类），CI 红灯。

- [ ] **Step 1: ci.yml 追加 job（置于 verifier job 之后）**

```yaml
  real-project-smoke:
    name: Real-project smoke (R9: fixture ≠ 真实项目)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Clone real projects (pinned by recorded SHA in artifact)
        run: |
          mkdir -p /tmp/real && cd /tmp/real
          git clone --depth 1 https://gitee.com/mingyue/RuoYi-Vue3.git ruoyi 2>/dev/null || \
            git clone --depth 1 https://github.com/yangzongzhuan/RuoYi-Vue3.git ruoyi
          git clone --depth 1 https://github.com/YunaiV/yudao-cloud.git yudao || echo "yudao clone 失败——记 artifact 继续"
          (cd ruoyi && git rev-parse HEAD) > /tmp/real/SHAS.txt
          (cd yudao && git rev-parse HEAD) >> /tmp/real/SHAS.txt 2>/dev/null || true
      - name: Generate skill + precheck smoke
        run: |
          cd "$GITHUB_WORKSPACE/swarm-yuan"
          for proj in ruoyi yudao; do
            [[ -d "/tmp/real/$proj" ]] || continue
            bash scripts/generate-skill.sh "smoke-$proj" "/tmp/real/$proj" --skill-root /tmp/real/skills
            SK="/tmp/real/skills/smoke-$proj"
            [[ -f "$SK/scripts/precheck.sh" ]] || { echo "✗ $proj 骨架缺 precheck.sh"; exit 1; }
            out=$(cd "/tmp/real/$proj" && bash "$SK/scripts/precheck.sh" --all 2>&1 || true)
            [[ -n "$out" ]] || { echo "✗ $proj precheck --all 无输出（R9 P0 类崩溃）"; exit 1; }
            echo "$out" | tail -5
          done
      - name: Upload smoke report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: real-project-smoke
          path: /tmp/real/SHAS.txt
```

注意：generate-skill.sh 是否支持 `--skill-root` 参数需先核对（`grep -n 'skill-root\|SKILL_ROOT' scripts/generate-skill.sh | head -5`）；不支持则按其既有输出路径参数调整（如实核对后再写 job，不得臆造 flag）。冒烟断言目标是"生成成功 + precheck 有输出不崩溃"，不断言填充完整度（填充是 AI 行为，R9 已注明）。

- [ ] **Step 2: 本地模拟冒烟（不经 CI 先验）**

```bash
cd /tmp && rm -rf real && mkdir real && cd real
git clone --depth 1 https://github.com/yangzongzhuan/RuoYi-Vue3.git ruoyi
cd /Volumes/nvme2230/lab/Swarm-yuan/.claude/worktrees/feat-wp-s-standards-deepening/swarm-yuan
bash scripts/generate-skill.sh smoke-ruoyi /tmp/real/ruoyi --skill-root /tmp/real/skills   # 以上一步核对的真参数为准
cd /tmp/real/ruoyi && bash /tmp/real/skills/smoke-ruoyi/scripts/precheck.sh --all | tail -5
```

Expected: 骨架生成成功、precheck 输出非空、rc 不异常。

- [ ] **Step 3: 提交**

```bash
git add ../../.github/workflows/ci.yml   # 相对 swarm-yuan/；实际按 worktree 根提交
git commit -m "ci(wp-s1): 真实项目冒烟job（R9核心建议：fixture不能替代真实项目测试）"
```

---

### Task 10: 收口——enforce 重归类 + facts.conf + 自举 + verifier 账本 + 文档口径

**Files:**
- Modify: `swarm-yuan/assets/gate-enforce-level.conf`（脚本重生成）
- Modify: `swarm-yuan/assets/facts.conf`
- Modify: `swarm-yuan/ci/self-precheck.conf`（新门禁最小自举配置——保持 SKIP 明示即可，不强启）
- Modify: `README.md`、`CLAUDE.md`、`swarm-yuan/SKILL.md`、`swarm-yuan/README.md`（口径数字）
- Modify: `verifier/runs/README.md`（追加账本记录）

**Interfaces:**
- Consumes: Task 3-8 全部产物。
- Produces: WP-S1 终态口径：40 门禁（核心 10 + 架构 17 + 合规 13）、conf 变量 142→151、references 18→19、enforce strict 12→14 / warn 18→20 / advisory 6。

- [ ] **Step 1: enforce 重归类 + 落位核对**

```bash
bash scripts/gen-enforce-level.sh
cat assets/gate-enforce-level.conf | grep -E 'dengbao|pia|sast|oss'
```

Expected: `check_dengbao=strict`（4 fail）、`check_pia=strict`（3 fail）、`check_sast_deep=warn`（2 fail）、`check_oss_eval=warn`（2 fail）。若实际 fail 数与预期不符导致档位漂移——函数落错文件不影响运行（source 三文件全量加载），但 self-check 一致性会按实际 fail 数断言；以 gen-enforce-level 实际输出为准调整 facts.conf，并在 commit message 如实记录漂移原因。

- [ ] **Step 2: self-check 一致性 + 全量测试**

```bash
bash scripts/self-check.sh --check-only
bash tests/run-gate-fixture.sh
bash tests/e2e/run-e2e.sh
bash verifier/v1/run-verifier.sh all
```

Expected: 全绿；verifier runs 追加本轮记录。若 C5/C6 metrics 断言红（门禁数变化），按账本流程更新 metrics-baseline 并在 runs/README.md 记录理由。

- [ ] **Step 3: facts.conf 更新**

```
FACT_GATES_TOTAL=40           # +dengbao/pia/sast-deep/oss-eval
FACT_GATES_COMPLIANCE=13      # 9+4
FACT_CONF_VARS=151            # 142+9（DENGBAO×3/PIA×2/SAST_DEEP×2/OSS_EVAL×1/STANDARDS_MAP_FILE×1）
FACT_CONF_VARS_COMPLIANCE=39  # 30+9
FACT_REFERENCES=19            # +industry-profile-gov.md
FACT_ENFORCE_STRICT=14        # 以 gen-enforce-level 实际为准
FACT_ENFORCE_WARN=20          # 同上
```

（同时更新注释行里的 catchphrase 说明。）

- [ ] **Step 4: 文档口径同步（self-check 漂移检测驱动）**

```bash
bash scripts/self-check.sh --check-only 2>&1 | grep -iE '漂移|drift|不一致' || echo "无漂移"
```

按输出逐一同步 README.md（徽章 36→40、"合规 9"→"合规 13"）、CLAUDE.md（36 gates 描述）、swarm-yuan/SKILL.md frontmatter description、swarm-yuan/README.md 对应表述。README 行业 profile 表述（如有"2 个"）→ 3 个（finance/medical/gov）。

- [ ] **Step 5: 自举配置（ci/self-precheck.conf 追加注释说明，不改启用状态）**

```bash
# WP-S1：新合规门禁（dengbao/pia/sast-deep/oss-eval）对生成器仓库保持未配置 SKIP——
# SKIP 透明化（Task 2）后跳过清单在汇总段显式披露；生成器自身无等保/PIA 交付场景，不强启。
STANDARDS_MAP_FILE=""   # 留空走默认探测 assets/standards-map.conf，自举核验映射表格式
```

- [ ] **Step 6: verifier 账本 + 终跑 + 提交**

```bash
bash verifier/v1/run-verifier.sh all | tail -20
# verifier/runs/README.md 追加：2026-07-22 wp-s1-security-gates | fixtures 61/61 | gate-fixtures 40/40 | metrics 基线更新理由（+4 合规门禁）
git add -A
git commit -m "chore(wp-s1): 收口——enforce重归类+facts.conf 40门禁/151变量+自举SKIP披露+verifier账本"
```

---

## Self-Review 记录

- **Spec 覆盖核对**：spec §4 安全族 4 门禁 → Task 4/5/6/7 ✓；§6.1 映射层 → Task 3 ✓；§6.5 gov profile → Task 8 ✓；§8 地基 5 项 → Task 1（①②③④中的 `\|`/spring-boot×2）+ Task 2（madge stderr + SKIP 透明化=①）+ Task 9（⑤冒烟 CI）✓；§9 测试 → 各 Task fixture + Task 10 verifier ✓。spec §5/§6.2/§6.3/§7 属 WP-S2，本计划不含（spec §11 分界）。地基②madge stderr 两处均覆盖 ✓。
- **Placeholder 扫描**：Task 6 Step 4 已标注 builtin 分支消息体笔误风险并给出统一写法；Task 9 Step 1 已标注 `--skill-root` 须先核对不得臆造；无 TBD/TODO。
- **类型一致性**：fail id 命名（gate_dengbao_*/gate_pia_*/gate_sast_deep_*/gate_oss_eval_*）在 fixture expected-ids、门禁实现、_fix_suggest、standards-map.conf 四处一致 ✓；conf 变量名在 compliance.conf/profile/fixture/facts.conf 四处一致 ✓。
