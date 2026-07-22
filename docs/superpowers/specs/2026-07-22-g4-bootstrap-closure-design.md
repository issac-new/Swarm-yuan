# G4：自举闭环设计

> 日期：2026-07-22 ｜ 分支：`feat/g4-bootstrap-closure`
> 范围：自身理念重构（C 方向第二批）—— G4 自举闭环
> 理念：自举（理念 6）—— "swarm-yuan 能用自身的 36 个门禁检查自身。一个连自己都检查不了的工具，凭什么检查你的项目？"
> 口径权威源：`swarm-yuan/assets/facts.conf`

---

## 1. 问题、目标与方案选型

### 1.1 问题定位（调研确认）

**断点 1 — 自举只跑了 `--all`（核心 10 门），未跑 `--all-full`（27 门）/ `--compliance-suite`（9 门）。** 现有 CI `generator-self-gate` Job（`.github/workflows/ci.yml`）只跑 `precheck.sh --all`（RC=0 断言）。理念宣称"36 门禁检查自身"，实际只兑现 10/36。架构 17 门与合规 9 门从未对生成器仓库执行。

**断点 2 — `--all-full` 升级有已知失败面：impact 门 fail。** 调研确认 `check_impact`（`gates-warn.sh:597-673`）是四个"无 spec fail-open 门"里唯一有硬 fail 路径的——候选路径（SPEC_FILE/IMPACT_SPEC_FILE）与兜底搜索（WRITABLE/SCAN_DIRS 内含「影响范围/消费方」md）全空时 **fail**（L616-617）。生成器仓库 cwd 下模板相对路径不可达（`_first_existing_file` 用 cwd 相对路径，`precheck.sh:74-86`），直接跑 `--all-full` 会在 impact 门 fail。需要 conf 显式配置 `SPEC_FILE`/`CHANGE_IMPACT_FILE` 指向 `swarm-yuan/assets/spec-template.md`/`plan-template.md`。

**断点 3 — 生成器仓库的 conf 需兼顾"真检查"与"不误报"。** 调研确认：
- `SCAN_DIRS` 必须保持空——sensitive 门禁用内置正则全文件类型扫描，范式仓库的门禁脚本/规则集 md 含 `password\s*[=:]`、token 正则等模式字面量，必误报（`ci/self-precheck.conf` 注释已明示此为已知误报面）。
- `WRITABLE_DIRS` 可以安全配置——domain/shift-left/impact 的代码扫描全带扩展名白名单（`--include='*.ts' '*.js' '*.py' '*.go' '*.java'`），bash/md 文件不会被扫描命中。配 WRITABLE_DIRS 的收益：impact 的 md 兜底搜索与 shift-left 埋点扫描有真实目标，从"跳过"变"实跑 pass"。
- `BUILD_CMD`/`TEST_CMD` 不配置时 check_build/check_test 打印"跳过"直接 return——bash+md 项目的正确姿态。

### 1.2 目标

让"36 门禁检查自身"从 slogan 变为 CI 强制证据：CI 对生成器仓库跑 `--all` + `--all-full` + `--compliance-suite` 三档，全部 RC=0；自举 conf 显式声明且机器执法，任何门禁语义变更导致自举失败都会被 CI 抓住。

### 1.3 方案选型

| 档 | 内容 | 风险 | 选择 |
|---|---|---|---|
| A 只扩 `--all-full` | CI 加 `--all-full` step + 补 conf 的 SPEC_FILE/CHANGE_IMPACT_FILE/WRITABLE_DIRS | 低（补 conf 即可，impact 是唯一新增失败面） | ✗ 合规 9 门未自举 |
| **B 三档全自举（选）** | A + `--compliance-suite` step + 合规 conf 显式配置 + self-check 自举断言 | 中（合规 9 门部分需配置才不静默跳过，但 skip_if_unconfigured 不阻塞 RC） | ✓ 理念完整兑现 |
| C B + 补 26 门禁新 fixture | B + 为非框架门禁补 violating/compliant 双态 fixture | 高（26 门 × 双态工程量大） | ✗ 已有 36 组 gate-fixture 全量存在 |

**选 B 的理由**：B 完整兑现"36 门禁检查自身"理念（三档全跑），且 C 档的 fixture 补充经调研确认**已完成**（`tests/gate-fixtures/` 下 36 组已全量存在，WP3.3 完成，Linux CI 严格全绿）——无需重复造 fixture。G4 的缺口在"自举"（生成器对自家跑），不在"fixture 覆盖"。

---

## 2. 架构与组件

### 2.1 总体架构

```
ci/self-precheck.conf          .github/workflows/ci.yml
（自举 conf 三档声明）          （generator-self-gate Job 三档 step）
        │                              │
        │  sed __REPO_ROOT__            │  mktemp + cp + git checkout -b
        ▼                              ▼
   precheck.sh --all          ┌─────────────────────┐
   precheck.sh --all-full  →  │  生成器仓库自身       │  → 三档 RC=0 断言
   precheck.sh --compliance   └─────────────────────┘
        │
        ▼
scripts/self-check.sh check_bootstrap_gate（新断言）
  对账 ci/self-precheck.conf 声明的门禁档位 vs 实际 CI step 数
```

### 2.2 组件清单

| # | 文件 | 动作 | 改动要点 |
|---|------|------|---------|
| 1 | `swarm-yuan/ci/self-precheck.conf` | 改 | 补 `WRITABLE_DIRS`/`SPEC_FILE`/`CHANGE_IMPACT_FILE` + 合规 conf 注释（三档声明） |
| 2 | `.github/workflows/ci.yml` | 改 | generator-self-gate Job 加 `--all-full` + `--compliance-suite` 两个 step |
| 3 | `swarm-yuan/scripts/self-check.sh` | 改 | 新增 `check_bootstrap_gate` 断言：self-precheck.conf 声明的门禁档位 vs CI step 数一致 |
| 4 | `swarm-yuan/assets/facts.conf` | 改 | 新增 `FACT_BOOTSTRAP_GATES=3`（all/all-full/compliance-suite 三档） |

### 2.3 自举 conf 设计（ci/self-precheck.conf 扩写）

```bash
# self-precheck.conf —— 生成器仓库自举门禁配置（三档）
# 断言目标：precheck.sh --all / --all-full / --compliance-suite 对生成器仓库 RC=0
# 口径权威源：assets/facts.conf（FACT_BOOTSTRAP_GATES=3）

PROJECT_DIR="__REPO_ROOT__"
BRANCH_REGEX='^(feat|fix|refactor|docs|chore|test)/.+'
PROTECTED_BRANCHES=("main")

# WRITABLE_DIRS 可安全配置：domain/shift-left/impact 的代码扫描全带扩展名白名单
# （--include='*.ts' '*.js' '*.py' '*.go' '*.java'），bash/md 文件不会被扫描命中。
# 配置收益：impact 的 md 兜底搜索与 shift-left 埋点扫描有真实目标，从"跳过"变"实跑 pass"。
WRITABLE_DIRS=("swarm-yuan/scripts" "swarm-yuan/assets" "swarm-yuan/references")

# SCAN_DIRS 必须保持空：sensitive 门禁用内置正则全文件类型扫描，
# 范式仓库的门禁脚本/规则集 md 含 password\s*[=:]、token 正则等模式字面量，必误报。
SCAN_DIRS=()

# SPEC_FILE/CHANGE_IMPACT_FILE 显式指向自家模板：
# impact 门（gates-warn.sh:616-617）在候选路径+兜底全空时 fail——
# 生成器仓库 cwd 下模板相对路径不可达（_first_existing_file 用 cwd 相对路径），
# 必须 conf 显式配置指向 swarm-yuan/assets/spec-template.md/plan-template.md 自证 pass。
SPEC_FILE="__REPO_ROOT__/swarm-yuan/assets/spec-template.md"
CHANGE_IMPACT_FILE="__REPO_ROOT__/swarm-yuan/assets/plan-template.md"

# 合规 9 门（sbom/privacy/authz/requirements/crypto/rtm/release-sign/compliance/docs-pack）：
# 未配置项 skip_if_unconfigured 静默跳过，不阻塞 RC。
# 已配置项（如 requirements 的 REQUIREMENTS_STRICT）按需显式声明。
```

---

## 3. 数据流与门禁档位映射

### 3.1 三档自举门禁序列

| 档 | 命令 | 门禁数 | 关键依赖 | 新增失败面 |
|---|------|-------|---------|-----------|
| `--all` | 核心 10 | branch/scope/build/sensitive/review/reuse/deps/security/test/consistency | 已有（现有 CI） | 无 |
| `--all-full` | 标准 27（核心 10+架构 17） | 核心 10 + layer/stable-diff/link-depth/adr/contract/consistency-cross/impact/service/api/state/frontend/cognition/domain/knowledge/mermaid/shift-left/framework | 需 conf 补 SPEC_FILE/CHANGE_IMPACT_FILE/WRITABLE_DIRS | **impact 门**（唯一硬 fail 路径） |
| `--compliance-suite` | 合规 9 | compliance/docs-pack/sbom/privacy/authz/requirements/crypto/rtm/release-sign | 未配置项 skip_if_unconfigured 静默跳过 | 无（skip 不阻塞 RC） |

### 3.2 自举 conf → 门禁行为映射

| conf 变量 | 驱动门禁 | 配置后行为 | 不配置行为 |
|-----------|---------|-----------|-----------|
| `WRITABLE_DIRS` | impact（md 兜底）/ shift-left（埋点扫描）/ domain（§3 扫描） | 有真实目标，实跑 pass | 跳过或空目标 |
| `SPEC_FILE` | shift-left（§19/§20/§21）/ domain（§18）/ impact（影响范围段） | 对模板自证 pass | shift-left warn 不 fail；impact 兜底搜索 |
| `CHANGE_IMPACT_FILE` | impact | 对模板自证 pass | 同上 |
| `SCAN_DIRS`（保持空） | sensitive | 无扫描目标，跳过 | 同上（防误报） |

---

## 4. 错误处理、测试与对齐标准

### 4.1 错误处理

| 故障 | 行为 | 理由 |
|------|------|------|
| impact 门 fail（conf 未配 SPEC_FILE） | CI 红，阻断合并 | 这是自举的核心断言——conf 配置错误必须暴露 |
| 合规门未配置静默跳过 | RC=0（skip_if_unconfigured 不阻塞） | 符合现有设计（SILENT 跳过是文档记录的设计） |
| SCAN_DIRS 误配置导致 sensitive 误报 | CI 红，阻断合并 | 自举 conf 注释明确 SCAN_DIRS 必须空，误配即失败 |
| self-check 对账失败（conf 声明 vs CI step 数不符） | self-check warn + FAIL=1 | 口径漂移机器执法 |

### 4.2 测试策略

| 验证手段 | 覆盖什么 | 怎么跑 |
|---------|---------|--------|
| CI generator-self-gate Job | 三档门禁 RC=0 | push/PR 自动跑 |
| 本地手动验证 conf | 三档在本地 RC=0 | `bash -c 'cd /tmp && cp ... && sed ... && bash precheck.sh --all-full'` |
| self-check check_bootstrap_gate | conf 声明 vs CI step 数一致 | `bash scripts/self-check.sh --check-only` |
| facts.conf 对账 | FACT_BOOTSTRAP_GATES=3 与 CI step 数一致 | self-check 已有机制 |

### 4.3 对齐标准

| 标准/理念 | G4 落地 |
|----------|---------|
| 理念 6 自举 | 36 门禁检查自身从 slogan 变 CI 证据（三档全跑） |
| 决策 11 测试覆盖补齐 | 自举 Job 从 `--all` 扩到三档，与"验收体系不进 CI 等于没有验收"同精神 |
| GB/T 25000.51 §7.5 符合性评价 | 生成器自身即 RUSP，自举门禁即符合性评价证据 |

---

## 5. 实现顺序预估

| WP | 内容 | 依赖 | 预估文件改动 |
|----|------|------|------------|
| WP-G4-1 | ci/self-precheck.conf 三档扩写 + facts.conf 口径 | 无 | 1 改 + 1 改 |
| WP-G4-2 | ci.yml generator-self-gate Job 加 --all-full + --compliance-suite step | WP-G4-1 | 1 改 |
| WP-G4-3 | self-check.sh check_bootstrap_gate 断言 + 本地手动验证三档 RC=0 | WP-G4-2 | 1 改 |

---

## 6. 关键证据索引

- 现有自举 conf：`swarm-yuan/ci/self-precheck.conf`（最小配置）
- 现有 CI generator-self-gate Job：`.github/workflows/ci.yml`
- impact 门硬 fail 路径：`swarm-yuan/assets/gates-warn.sh:597-673`（L616-617 fail）
- skip_if_unconfigured：`swarm-yuan/assets/precheck.sh:424-435`
- SILENT=1 于 --all-full：`swarm-yuan/assets/precheck.sh:362-364`
- `_first_existing_file` cwd 相对路径：`swarm-yuan/assets/precheck.sh:74-86`
- 36 组 gate-fixture 全量存在：`swarm-yuan/tests/gate-fixtures/`（WP3.3 完成）
- 决策 11 测试覆盖补齐：`docs/paradigm-decisions.md` 决策 11
- 审计确认 26/27 非框架门禁无 fixture（已解决）：`docs/2026-07-20-audit-optimization-decisions.md` §遗留
