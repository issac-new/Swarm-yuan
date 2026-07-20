# 标准合规差距分析与重构实施计划

> 日期：2026-07-20 ｜ 编制：范式架构师_GapAnalyst ｜ 分支建议：`feat/standards-compliance`
> 证据基线：`docs/research/R1–R8`（2026-07-20，全部结论已经主仓独立复核）+ 本计划编制时对 `precheck.sh`/`precheck.conf`/`self-check.sh`/`generate-skill.sh`/`spec-template.md`/`spring-boot.sh`/`.claude/commands/swarm-yuan.md` 的逐点复核。
> 铁律约束：precheck.sh 单文件可移植；不贸然唤醒沉睡门禁；新门禁未配置时静默跳过、安全类启用后 fail-closed；一切数字变更给出口径同步清单。

---

## 一、差距矩阵

状态：✅ 已满足 ｜ 🟡 部分满足 ｜ ❌ 缺失。证据列为仓库内出处（调研报告编号=R1–R8）。

### 1.1 GB/T 25000.51-2016（RUSP）八大特性 × 现状

| 特性 | 标准要求（条款） | swarm-yuan 现状（证据） | 状态 | 行动 |
|---|---|---|---|---|
| 功能适合性 | §5.3 功能完备/正确/适合；测试覆盖声明 | `--build`/`--test`（precheck.sh:345/358）+ `--consistency`；无需求↔测试追溯 | 🟡 | P2 RTM 门禁（Q-11） |
| 性能效率 | §5.3 时间/资源/容量 | `--link-depth`（:756，GNU-only 兜底失效 R2§8）+ 框架门禁性能规律（redis/kafka） | 🟡 | P1 可移植兜底；P2 密度度量 |
| 兼容性 | §5.3 共存/互操作 | `--framework` 57 规则集 §6 版本陷阱 + `--deps` 版本基线（:1000） | 🟡 | P1 actuator YAML 支持 |
| 易用性（25010:2023=交互能力） | §5.2 用户文档集要求 | **无文档门禁**（R7 Q-03） | ❌ | **P0 `--docs-pack`** |
| 可靠性 | §5.3 成熟/可用/容错/可恢复 | `--shift-left` 回滚/灰度（:2329）+ `--review`；无故障安全（Safety）维度（Q-02） | 🟡 | P2 Safety 检查 |
| 信息安全性 | §5.3 保密/完整/抗抵赖/可核查/真实 | `--security`（:1101）+ `--sensitive`（:371，fail-open）+ security-spec.md | 🟡 | **P0 `--sbom`/`--privacy`** |
| 维护性 | §5.3 模块/复用/可分析/可修改/可测试 | `--layer/--reuse/--stable-diff/--frontend/--state/--adr`（体系最完整域） | ✅🟡 | — |
| 可移植性 | §5.3 适应/易安装/易替换 | 三平台铁律 + .bat 包装器；**CI 仅 ubuntu，BSD/bash3.2 分支无验证**（R2§7、R4 §五.3） | 🟡 | P1 macOS CI 矩阵 |

配套：§6 测试文档集（计划/说明/结果）❌→P0 `--docs-pack`（profile=rusp）；§7.5 符合性评价报告 🟡→P1 verifier 报告格式对齐（Q-05）。

### 1.2 过程·测试·文档标准

| 标准+条款 | 交付物要求 | 现状（证据） | 状态 | 行动 |
|---|---|---|---|---|
| GB/T 8566-2022 附录 A/B | 显式剪裁声明 + 过程信息项留痕 | 无剪裁声明物（R7 Q-16） | ❌ | **P0 spec §22 剪裁声明**；P2 AI 过程信息项 |
| GB/T 8566-2022 验证/确认 | built-right 与 right-built 双证据 | verifier/v1（C1 强/C5/C6 弱，R2§7） | 🟡 | P1 C5/C6 断言化 |
| GB/T 15532-2008 准入 | 受控基线 + 编译通过 + 文档齐 | `--build`/`--test`（未配置 fail-open，R2 §3） | 🟡 | P1 conf lint |
| GB/T 15532-2008 准出 | 文档齐全、问题有处理、**失效须可见** | **SILENT 跳过 ~15 门禁仍称"通过"（:237-248）；check_sensitive 空 SCAN_DIRS 假 pass（:385-401）** | ❌ | **P0 跳过计数器 + sensitive warn 修复 + 安全门禁 fail-closed** |
| GB/T 8567-2006 §7（25 文档） | 生存周期文档包 | 27 门禁全在代码层，文档包零覆盖（R7 Q-15，**最高优先级缺口**） | ❌ | **P0 `--docs-pack`** |
| GB/T 9386-2008 §4–§11 | 测试计划/说明/报告 8 种 | 无（Q-04/Q-14） | ❌ | **P0 `--docs-pack`（gbt9386 预设）** |
| ISO/IEC/IEEE 29148:2018 | 无 TBD、唯一 ID、可验证、RTM | spec 模板结构在；lint 无（Q-09/10/11） | 🟡 | P0 零占位符执法覆盖 TBD；P1 需求 lint |
| GB/T 11457（术语） | 同概念同词 | `--consistency-cross` glossary grep（:1366） | 🟡 | — |
| GB/T 25000.21/30 测度元素 | 质量需求引用「特性/测量函数/阈值/证据」四元组 | conf 146 变量无标准元数据（Q-06） | ❌ | **P0 standards-compliance.md 登记门禁级四元组**；P1 conf 全量元数据 |

### 1.3 安全标准（条款→门禁映射详表入 P0 standards-compliance.md §D/§E）

| 标准+条款 | 交付物要求 | 现状（证据） | 状态 | 行动 |
|---|---|---|---|---|
| GB/T 22239-2019 7.1.4.x（二级计算环境） | 口令策略/默认账户/审计字段/剩余信息/个信保护 | security-spec.md 清单；代码层仅 `--security` 10 模式族（R8 §①） | 🟡 | P0 矩阵登记；P1 安全门禁族扩展 |
| GB/T 22239-2019 8.1.4.1d/8.1.4.8（三级增量） | 双因素、数据保密性（密码技术）、密码方案文档 | 无（R8 §①） | ❌ | P2 国密/等保 profile |
| GB/T 28448-2019 测评单元四要素 | 指标→对象→实施→判定证据 | 门禁输出为终端散文，无落盘证据（R8 §②） | 🟡 | P1 门禁运行记录落盘 `.swarm-yuan/gate-runs/` |
| 网安法§21/数安法§27/个保法§51·55 + GB/T 35273-2020 11.2/11.4 | 日志留存≥6月、加密去标识化、**发布前 PIA** | **PII/隐私零门禁**（R8 §③） | ❌ | **P0 `--privacy`（fail-closed+豁免留痕）**；PIA 登记入 spec §22 |
| GB/T 38674-2020 §5/§8.1 | 数据清洗/加密/访问控制/日志/第三方评估 | `--security` 同构覆盖输入验证/注入（R8 §④） | ✅🟡 | P0 矩阵挂条款号 |
| GB/T 34943/34944/34946-2017 | 语言漏洞分类 + SAST+人工复核 + 四件套报告 | 仅 mybatis 一处 CWE-89 标注；无条款元数据（R2 §8.2、R8 §⑥） | 🟡 | P0 矩阵映射；P1 CWE 元数据分级硬约束（NOEVID） |
| GB/T 18336（CC/EAL） | 配置管理/交付/测试/缺陷纠正证据分级 | 无对应（R8 §⑤） | ❌ | P0 矩阵登记 EAL↔verifier 等级语义（文档层） |
| ISO/IEC 27001:2022 A.8.25–A.8.33 | 安全 SDLC/编码/测试/环境分离/变更 | `--security`+`--sensitive` 部分覆盖；A.8.31 环境分离无检（R8 #31） | 🟡 | P1 privacy/sensitive 深化 |
| NIST SSDF v1.1 PO/PS/PW/RV | 组织准备/发布完整性/安全生产/漏洞响应 | PW≈门禁体系；**PS.2 发布签名缺失**；RV 无根因字段（R8 §⑧） | 🟡 | P2 发布签名门禁 |
| OWASP ASVS 5.0 / Top10:2025 / CWE Top25:2025 | 文档化安全决策；A03 供应链、A10 异常处理；授权类弱点×4 | security-spec 对齐 2021 版；**授权检查无一等门禁**（R8 §⑨） | 🟡 | P0 矩阵+豁免登记；P1 授权类门禁 |
| GB/T 39786-2021（密评三级） | SM2/3/4、密钥管理、密评证明登记 | 无（R8 §⑪） | ❌ | P2 国密门禁；P0 矩阵登记缺口 |
| GB/T 39204-2022 §7.9 j) | 定制软件源代码安全检测报告 | SAST 证据无归档（R8 §⑫） | 🟡 | P1 gate-runs 落盘 |
| **工具链许可证** | 商用合规 | **GitNexus=PolyForm Noncommercial 禁商用，列为铁律之首（SKILL.md:108，R6 §1.3）** | ❌ | **P0 降级+graphify(MIT) 提默认** |

### 1.4 供应链与国际工程标准

| 标准 | 要求 | 现状 | 状态 | 行动 |
|---|---|---|---|---|
| ISO/IEC 5962（SPDX）/ECMA-424（CycloneDX）/GB/T 43848-2024 | 机器可读 SBOM + 开源成分评价 | 无（R8 #21/22/25；Top10:2025 A03） | ❌ | **P0 `--sbom`（生成+许可证扫描+降级链）** |
| SLSA v1.0 Build L2 / Sigstore | 签名 provenance | 无 | ❌ | P2 |
| ISO/IEC 5230（OpenChain） | 许可证合规程序 | offline-cache 缺 UPSTREAM.md 溯源（R5 §八.7） | 🟡 | **P0 UPSTREAM.md + docs/upstream-baseline.md** |
| ISO/IEC 5055:2021（138 弱点） | 弱点密度/合规率 | 词法层 grep，无 CWE 对齐（R2 §8） | ❌ | P1 元数据；P2 密度度量 |
| ISO/IEC 25010:2023 Safety | 故障安全/危险警告 | 无（Q-02） | ❌ | P2 |

### 1.5 差距计数

标准映射条目合计 33 行：✅🟡 4 ｜ 🟡 15 ｜ ❌ 14。❌ 中 9 项由 P0 覆盖（文档包×2、准出 fail-closed×1、隐私×1、SBOM×1、溯源×1、许可证×1、测度四元组登记×1、剪裁声明×1）。

---

## 二、实施总览

### 2.1 批次

- **P0（本批，T1–T10）**：已核实缺陷修复 + 标准立法层 + 4 个合规新门禁 + 零占位符机器执法 + SILENT 披露 + 配套 fixture/verifier。
- **P1（下一批，P1-1–P1-10）**：fixture 断言全面升级、跨平台矩阵、安全门禁族深化、conf lint、证据落盘、方法论修补。
- **P2（长期）**：26 门禁全量 fixture、RTM、度量趋势、国密/行业 profile、发布签名、AI 过程信息项。

### 2.2 文件归属表（一个文件仅一个 owner）

| Owner | 文件（新建=✚） |
|---|---|
| **T1** | ✚ `swarm-yuan/references/standards-compliance.md` |
| **T2** | `swarm-yuan/assets/spec-template.md` |
| **T3** | `swarm-yuan/assets/precheck.sh`、`swarm-yuan/assets/precheck.conf` |
| **T4** | ✚ `swarm-yuan/tests/run-gate-fixture.sh`、✚ `swarm-yuan/tests/gate-fixtures/**`、`swarm-yuan/tests/run-framework-fixture.sh`、`verifier/v1/acceptance-criteria.md`、`verifier/v1/run-verifier.sh`、`.github/workflows/ci.yml` |
| **T5** | `swarm-yuan/scripts/generate-skill.sh` |
| **T6** | `swarm-yuan/assets/framework-gates/spring-boot.sh`、`swarm-yuan/tests/fixtures/spring-boot/**` |
| **T7** | `swarm-yuan/scripts/self-check.sh` |
| **T8** | `swarm-yuan/references/code-graph-tools.md`、✚ `docs/upstream-baseline.md`、✚ `swarm-yuan/offline-cache/UPSTREAM.md`（untracked，随 zip 分发） |
| **T9** | `swarm-yuan/SKILL.md`、`swarm-yuan/README.md`、`README.md`（根）、`swarm-yuan/docs/USAGE.md`、`swarm-yuan/docs/PROMO.md`、`swarm-yuan/.claude/commands/swarm-yuan.md`、`swarm-yuan/references/cognition-framework.md`、`swarm-yuan/scripts/install-offline-win.sh`、`swarm-yuan/scripts/build-offline-win.sh`、`swarm-yuan/scripts/install-offline-win.bat`、`swarm-yuan/scripts/precheck.bat`（及同目录其余 6 个 .bat 同步复查） |
| **T10** | ✚ `verifier/runs/<ts>-standards-refactor-*.log`（只增不改） |

依赖序：T1（锚点契约）→T2/T3→T4→T6；T5 独立；T7/T8 独立；T9 最后（吃 T3/T5 终值）；T10 收尾。锚点契约本计划已冻结，T1–T8 可并行。

### 2.3 数字口径同步总表（P0 完成后的真值）

| 口径 | 旧值 | 新值 | 真值来源（命令） | 同步文件（owner） |
|---|---|---|---|---|
| 门禁总数 | 27 | **31（核心 10+架构 17+合规 4）** | `grep -cE '^check_[a-z_]+\(\)' precheck.sh` | SKILL/README×2/USAGE/PROMO/commands（T9）；generate-skill.sh:522（T5）；precheck.bat:8（T9）；self-check 真值计算（T7） |
| 单门禁 flag | 27 | 31 | `GATE_FLAGS` 长度 | 同上 |
| conf 变量 | 146 | **162（+16）** | `grep -cE '^[A-Z_][A-Z0-9_]*=' precheck.conf` | T9 全部散文 + commands 45→162 |
| 特征卡 | 14（commands 残留） | 16 | README:38-59 | commands（T9） |
| 运行时 | 9/10/11 三处漂移 | 11 | self-check PROJECTS 表 | cognition-framework.md:116、install-offline-win.sh:2、build-offline-win.sh:3、install-offline-win.bat:29（T9） |
| 运行时名单 | 10 名漏 ECC | 11 名含 ECC | self-check:249-261 | SKILL.md:3 frontmatter、SKILL.md:106 方法论清单（T9） |
| 通用文件 | 22 | 23 | `UNIVERSAL_FILES` 长度 | README 结构图/散文（T9，先 grep「22 个通用/22 项」确认命中面） |
| references 方法论文档 | 13 | 14 | `ls references/*.md`（不含 frameworks/） | SKILL.md:114-126 清单、template-spec checklist（T9；template-spec 由 T2?——否，checklist 行属 T9 协调：约定 T2 仅改 assets/spec-template.md，template-spec.md 无数字改动则不动） |
| spec 段 | 「22 段」名实不符 + §6 重复 | **22 主段（§22=标准合规）+3 子段，名实相符** | `grep -c '^## ' assets/spec-template.md` → 25 | README:257/273、USAGE:297（T9） |
| 认知分数显示 | /11、/19（错配） | /14、/22 | precheck.sh:2051/2125-2126（T3，仅打印文案，不动阈值与打分） | — |
| 框架规则集表述 | 「57」混用 | 57 规则集（58 文件含模板） | ls 三件套 | 散文涉及处（T9，顺手项） |

---

## 三、P0 任务详设

### T1 · references/standards-compliance.md（标准立法层）

**目标**：目标 skill 的「标准立法」层——门禁与标准条款的显式映射矩阵，GB/T 28448「指标→对象→实施→判定」四元组建模。

**frozen 锚点契约**（T3/T4/fixture 依赖，不得改名）：

```
## A. GB/T 25000.51 八特性 × 门禁映射
## B. GB/T 8566 过程 × 生成流程映射
## C. GB/T 8567+9386 文档包 × 交付物映射
## D. 安全标准 × 门禁映射（等保/三法/38674/34943/39786）
## E. 国际工程标准映射（ISO 5055/SSDF/ASVS/SBOM-SLSA）
## F. 门禁姿态与豁免登记
```

**内容要求**：§A 按八特性逐行挂 31 门禁（含 4 新门禁）+「特性/测量函数/阈值/证据」四元组列；§B 生成流程 ⓪–⑫ 步 ↔ 8566 四过程组 + 剪裁声明写法；§C 六包交付物（需求/设计/测试/部署/运维/管理）↔ `--docs-pack` profile（rusp/gbt9386/gbt8567/custom）；§D R8 35 项映射表的「门禁落点」列实化（22239 条款/三法/38674/34943 系列 ↔ `--security/--sensitive/--domain/--privacy/--sbom`）；§E 5055/SSDF PO-PS-PW-RV/ASVS 5.0/SBOM-SLSA ↔ 门禁与 P2 缺口登记；§F 全 31 门禁姿态表（fail-closed / skip-if-unconfigured / warn-only）+ 豁免 5 字段格式（`对象|规则|理由|审批人|日期`）。

**DoD**：6 锚点逐字存在；覆盖 §1.1–1.4 全部 ❌/🟡 行；每条映射给出门禁或「缺口（P1/P2）」标注；无「待填充」。

---

### T2 · assets/spec-template.md 增补「标准合规」章

**实施**：① 删 :152 重复行 `## 6. 前端/UI`；② 文末新增 `## 22. 标准合规`，子段：**22.1 剪裁声明**（引用 references/standards-compliance.md 矩阵，声明适用标准集与剪裁理由——8566 附录 A 对齐）；**22.2 文档包清单**（GB/T 8567/9386 勾选表，与 DOCS_PACK_PROFILE 联动）；**22.3 安全豁免登记**（表头：门禁|规则|对象|理由|审批人|日期）；**22.4 PIA/密评登记**（个保法§55 / GB/T 39786 适用时）。

**DoD**：`grep -c '^## 6\. 前端/UI'` =1；`grep '^## 22\. 标准合规'` 命中；`grep -c '^## '` =25（22 主段+3 子段）；create 骨架生成后该章随模板复制。

---

### T3 · precheck.sh + precheck.conf：合规门禁族 + SILENT 披露 + 微修复

**① 注册表**：新增 `ALL_GATES_COMPLIANCE=(check_compliance check_docs_pack check_sbom check_privacy)`；`ALL_GATES_FULL` 在 `check_framework` 后、`check_test` 前插入四项；`GATE_FLAGS` 追加 `--compliance --docs-pack --sbom --privacy`；`--all` 核心 10 不变。

**② 四门禁逻辑**（判定语义全新，不改既有 27 门禁）：

| 门禁 | 启用条件 | 检查逻辑 | fail 条件（稳定 id） | 默认姿态 |
|---|---|---|---|---|
| `check_compliance` | 矩阵文件存在或 COMPLIANCE_MATRIX_FILE 已设 | 解析 SKILL_DIR（`$(cd "$(dirname "$0")/.." && pwd)`，回退 PROJECT_DIR）下矩阵；6 锚点（默认集同 T1）逐一 grep；全文「待填充/<占位符>」计数；SPEC_FILE 存在时查 `## 22. 标准合规` 段 | `gate_compliance_matrix_missing` / `gate_compliance_anchor_incomplete:<锚点>` / `gate_compliance_placeholder` / `gate_compliance_spec_section_missing` | 未配置静默跳过；存在即执法 |
| `check_docs_pack` | DOCS_PACK_PROFILE 非空 | profile→必备清单（rusp 内置：产品说明/用户手册/测试计划/测试说明/测试报告；gbt9386 内置测试 4+4；gbt8567/custom 取 DOCS_PACK_REQUIRED）；逐个存在性 + TBD 扫描 | `gate_docs_pack_missing:<file>` / `gate_docs_pack_tbd:<file>`（ALLOW_TBD=1 时降级 warn） | **未配置静默跳过** |
| `check_sbom` | SBOM_REQUIRED="1" | 工具降级链 `$SBOM_TOOL→syft→cdxgen→scancode→内置 lockfile 解析`（package-lock/yarn.lock/pnpm-lock/go.sum/requirements.txt/pom.xml + node_modules package.json license 提取）；产物落 SBOM_OUTPUT_DIR（带时间戳，证据归档）；许可证块名单扫描；豁免 5 字段校验+逐条回显 | `gate_sbom_toolchain_unavailable`（无工具且无 lockfile，**fail-closed**）/ `gate_sbom_license_blocked:<组件>` / `gate_sbom_exemption_invalid` | 未启用静默跳过；启用后 fail-closed |
| `check_privacy` | PRIVACY_SCAN_DIRS 非空 | 配置目录全不存在→fail；内置 ERE（18 位身份证/1[3-9] 手机号/16-19 位银行卡）+ EXTRA_PATTERNS + SENSITIVE_KEYWORDS；滤 example/mock/dummy/placeholder/样例；豁免校验+回显 | `gate_privacy_dirs_missing` / `gate_privacy_pii_found:<file>` / `gate_privacy_exemption_invalid` | 未启用静默跳过；启用后 fail-closed |

**③ SILENT 跳过计数器（非破坏）**：新增 `INVOKE_COUNT/SKIP_COUNT/SKIP_LIST/WARN_COUNT/FAIL_COUNT`；`skip_if_unconfigured` 按 `_CURRENT_GATE` 去重计数（三个分发循环先赋值 `_CURRENT_GATE`）；末次汇总在退出码判定前追加打印：`—— 执行汇总：调用 N，执行 N−S，跳过 S（清单），fail F，warn W ——`。**退出码与既有输出行一字不改**。

**④ 微修复（输出级，不动判定）**：`check_sensitive` 空 SCAN_DIRS 时 `pass "未发现"` 改 `warn "SCAN_DIRS 未配置，敏感信息扫描未执行（fail-open 风险）"`；:2051 `/11`→`/14`、:2125 `five_layer_max=19`→`22`（含注释）。

**⑤ conf**：追加「标准合规」段 16 变量（COMPLIANCE_MATRIX_FILE/COMPLIANCE_REQUIRED_SECTIONS/DOCS_PACK_PROFILE/DOCS_PACK_DIR/DOCS_PACK_REQUIRED/DOCS_PACK_ALLOW_TBD/SBOM_REQUIRED/SBOM_OUTPUT_DIR/SBOM_FORMAT/SBOM_TOOL/SBOM_LICENSE_BLOCKLIST/SBOM_LICENSE_EXEMPTIONS/PRIVACY_SCAN_DIRS/PRIVACY_EXTRA_PATTERNS/PRIVACY_SENSITIVE_KEYWORDS/PRIVACY_EXEMPTIONS），`_default_conf` 为 7 个新数组补 `${VAR+x}` 兜底（bash 3.2）。

**DoD**：`bash -n` 过；`GATE_FLAGS`=31、`check_*`=31、conf=162；`--all` 序列 diff 为空；最小 conf `--all-full` 退出码与基线一致且输出含执行汇总行；shellcheck error ≤ 基线。

---

### T4 · 新门禁 fixture + 通用运行器 + verifier/CI 配套

**实施**：✚ `tests/run-gate-fixture.sh <gate>`（复用 `__REPO_ROOT__` 占位 + precheck.sh 拷贝 + 单 flag 执行；遍历 `tests/gate-fixtures/<gate>/violating*/` 期望 exit≠0、`compliant*/` 期望 exit=0；支持目录内 `expected-ids`/`forbidden-ids`/`expect-output` 三个可选断言文件）；✚ fixtures：`compliance`（violating=缺 1 锚点+含占位符）、`docs-pack`（violating=缺测试报告+TBD）、`sbom`（violating=node_modules 内 GPL-3.0 mock；violating-unavailable=空项目 SBOM_REQUIRED=1）、`privacy`（violating=源码含 18 位身份证串）、`sensitive`（violating=sk- 密钥；compliant=空 SCAN_DIRS 且 expect-output 含「未配置未执行」warn 文案）、`summary`（compliant=最小 conf `--all-full`，expect-output 含「跳过」计数）。`run-framework-fixture.sh` 增 `expected-fail-ids` 可选断言（T6 依赖）。`verifier/v1/acceptance-criteria.md` 增 **C8**：合规门禁 fixture 双态 + id 级断言全绿；`run-verifier.sh` 增 `gate-fixtures` 模式。ci.yml 既有 fixture Job 追加 gate-fixtures 步骤（不新增平台）。

**DoD**：6 组 fixture 双态+id 断言全绿；`run-verifier.sh gate-fixtures` RC=0；C8 文案入库；CI 绿。

---

### T5 · generate-skill.sh：骨架数字 + 零占位符机器执法 + 清单扩容

**实施**：① :522 骨架 checklist `25 门禁`→`31 门禁`；② `UNIVERSAL_FILES` 增 `"references/standards-compliance.md|ref"`（22→23）；③ 新增子命令 `--verify-completeness <skill_dir>`：grep 目标 skill 的 SKILL.md/references/*.md/precheck.conf/hooks.json 中 `待填充|（待填充）|<占位符>|填充指引` + 骨架未勾 checkbox，任一命中打印 file:line 清单并 exit 1，零命中打印「✓ 零占位符确认」exit 0；④ upgrade 路径对旧 conf 不做新变量合并（靠 `_default_conf` 兜底跳过），在 upgrade 输出加一行提示。**DoD**：create 骨架立即 `--verify-completeness` exit 1；填充后 exit 0（双态证据）；`--inject-frameworks` 幂等与哈希裁决不回归；`SKILLS_PATH_REWRITE` 冒烟过。

---

### T6 · spring-boot BSD grep 字符类修复（可移植性 bug，非语义扩张）

**实施**：`spring-boot.sh:37` 与 `:124` 的 `[A-Za-z0-9_<>,.\[\] ]` 改 POSIX 安全写法 `[][A-Za-z0-9_<>,. ]`（`]` 置首为字面、`[` 原样收录）；其余逻辑不动。`tests/fixtures/spring-boot/` 增 `expected-fail-ids`（内容：`fw_sboot_transactional_selfinvoke`、`fw_sboot_jakarta_migration`；actuator 嵌套 YAML 失效属判定面扩张，**留 P1-1**，fixture 注释如实登记「2/3 主触发已断言」）。

**DoD（双平台等价证据）**：GNU 与 BSD grep 下对同一合成样本（`public void doSave(String order) {` + `this.doSave(x)`）提取结果逐字节一致；修复前 BSD 空/GNU 非空、修复后两侧一致非空；spring-boot fixture 双态+id 断言绿；57/57 framework fixture 全绿（golden vector 不动）。

---

### T7 · self-check.sh：superpowers 空壳 fail-closed + verify 接入 + 口径扩展

**实施**：① `check_superpowers`（:75-76）改实质检测：目录内存在核心插件证据（`skills/` 子目录或 `.claude-plugin/plugin.json` 且非仅 marketplace.json）才 pass；仅 marketplace 元数据 → miss 并提示「空壳：marketplace 元数据非核心插件，需在线 /plugin install」。② `check_gitnexus` 加许可证忠告行（PolyForm Noncommercial 禁商用，商用项目用 graphify）。③ 新增「框架规则集核验」段：遍历 57 id 调 `verify-framework-ruleset.sh`，聚合计数，任一失败置 FAIL。④ `check_doc_consistency`：架构数真值改为从注册表数组解析（核心 10/合规 4/架构=FULL−CORE−COMPLIANCE）；扫描目标增 `.claude/commands/swarm-yuan.md`；新增「合规 4」与 references 14 口径行。⑤ 轻量基线忠告：读 `docs/upstream-baseline.md` 中 `baseline_status=drifted` 行并 warn 列出（不联网）。

**DoD**：合成 HOME fixture——仅 marketplace 目录 → miss；含 skills/ → pass；篡改 README 数字 → FAIL；全量 self-check 实跑 RC=0。

---

### T8 · 许可证降级 + 溯源与基线登记

**实施**：① `references/code-graph-tools.md`：新增「许可证与选型」节（GitNexus PolyForm Noncommercial 1.0.0 禁商用→非默认、仅非商用可选；graphify MIT→默认首选）；org URL safishamsi/graphify→Graphify-Labs/graphify；graphify 基线标注 v0.9.x（0.10 待评估）。② ✚ `docs/upstream-baseline.md`：11 运行时登记表（仓库/许可证/引用基线/2026-07-20 最新版/状态：comet 0.3.9→0.4.0-beta.5 drifted、Ruflo 3.21.1→3.32.8 drifted、graphify 0.9.x→0.10.0 drifted、claude-mem 迭代极快 watch、GitNexus license-risk、其余 synced）。③ ✚ `swarm-yuan/offline-cache/UPSTREAM.md`（untracked，随 zip）：gstack v1.60.1.0（MIT, Garry Tan, GitHub repo, 获取日期 2026-07-20）+ superpowers-marketplace v1.0.13（MIT, Jesse Vincent）+ **明示核心插件 v6.1.1 未 vendor** + 遥测提示（gstack opt-in telemetry，数据敏感场景可 `telemetry off`）。

**DoD**：三文件入库（UPSTREAM.md 强制 `git add -f` 与否按 .gitignore 现状决策并注释；底线是 zip 内可见）；T9 引用措辞与本文件一致。

---

### T9 · 文档口径批（最后执行，吃 T3/T5 终值）

**实施**：按 §2.3 总表逐文件同步；含 GitNexus 降级措辞（SKILL.md:108 工具引用铁律 graphify 提首、README:61/134、PROMO 对应行——统一采用 T8 冻结措辞）；SKILL.md:3 frontmatter 补 ECC + 修正「3-layer」旧叙事为「按形态动态适配」；SKILL.md:106 方法论清单补 Ruflo/ECC 至 11；SKILL.md Step 12 改为脚本化：`bash scripts/generate-skill.sh --verify-completeness <skill_dir>`（替换「AI 自己 grep」散文）；README:162/USAGE 对应「grep 确认零占位符」同步为脚本化表述；`precheck.bat:8`「全部 25 门禁」→「全部 31 门禁」并复查其余 6 个 .bat；commands/swarm-yuan.md 14→16 特征卡、45→162 变量。

**DoD**：`grep -rn "25 门禁\|25个门禁\|14 项特征\|45 个配置\|9 个运行时\|10 个运行时" --include='*.md' --include='*.bat' --include='*.sh'` 命中为 0（研究/决策历史文档 docs/ 下豁免并注释）；`check_doc_consistency` 自证绿。

---

### T10 · 全量回归 + 证据归档

**DoD**：`bash -n` 全脚本；57/57 framework fixture + e2e RC=0 + golden-vector diff 为空；`run-verifier.sh fixtures/gate-fixtures/shellcheck` 三模式记录 `verifier/runs/<ts>-standards-refactor-*.log`；self-check RC=0；按 C1–C4+C8 出验证小结。

---

## 四、P1（下一批，每项带 DoD 要点）

1. **P1-1 fixture 断言升级**：57 框架全量 `expected-fail-ids` 登记（目标 fail 触发覆盖 88/124→124/124）；spring-boot actuator 嵌套 YAML 支持（先断言后修）。2. **P1-2 跨平台**：CI 增 macOS runner（BSD grep+bash3.2）；verify-framework-ruleset.sh 增 NOBSD 静态检查（禁 `\[\]`、禁 GNU-only `-P/-z`）。3. **P1-3 安全门禁族深化**：secret-scan 工具链（gitleaks）、SAST 门禁（semgrep 降级链）、授权类弱点门禁（CWE-862/863）。4. **P1-4 conf lint（--doctor）**：162 变量 schema/glob 可达/死变量。5. **P1-5 证据落盘**：`--format json`（SARIF 子集）+ `.swarm-yuan/gate-runs/` 运行记录（GB/T 15532 过程文档）。6. **P1-6 verifier 断言化**：C5 131 调用 A/B 编入脚本、C6 阈值断言、CI 对生成器仓库自跑 `--all`。7. **P1-7 上游基线制度化**：self-check 偏差告警接 docs/upstream-baseline.md；comet 0.4 能力重核；superpowers 核心插件 vendor 决策。8. **P1-8 MCP 默认最小化政策**（生成物 MCP 注册：默认最小+逐 connector 书面理由）。9. **P1-9 需求 lint**（TBD/唯一 ID/glossary 一致性，29148 门禁化）。10. **P1-10 方法论修补**：4-Phase SOP 定义页、razor↔abstain 裁决条款、razor 执法点或「纯阅读」标注、EARS 对齐声明。

## 五、P2（长期）

26 门禁全量 fixture；RTM 门禁（Q-11）；弱点密度/通过率趋势度量（Q-08/Q-20）；676 子门禁 CWE/GB 条款全量元数据；国密门禁（SM2/3/4 白名单 lint）+ 等保/密评/金融/医疗行业 profile；发布签名/provenance（SLSA L2+cosign）；AI 过程信息项制度化（prompt/diff/人工复核留痕，8566 剪裁扩展）；信创栈与 AI/LLM 框架规则集；功能安全域占位（ISO 26262/IEC 62304）；多平台规则渲染。

## 六、不做清单（本批明确不做）

| # | 不做 | 理由 |
|---|---|---|
| 1 | 唤醒 BREAKING_DDL/METRIC/LOG/TRACE 四处 `\|` 沉睡 | 判定行为改变不可预测，须 fixture 先行（paradigm-decisions.md:31-36；审计档:34） |
| 2 | check_cognition 语义重设计/加 fail | 属重设计非修复；本批仅修打印文案错配（不动阈值与打分） |
| 3 | 26 门禁全量 fixture | 工作量大，留 P2（paradigm-decisions.md:42）；本批覆盖 4 新门禁+sensitive+summary |
| 4 | git filter-repo 历史瘦身 | force-push 风险（paradigm-decisions.md 建议 4） |
| 5 | actuator 嵌套 YAML 支持 | 判定面扩张，P1-1 先升级断言再修 |
| 6 | superpowers 核心插件 vendor | zip 体积与维护面决策，P1-7 评估；本批只做诚实检测+文案 |
| 7 | `--all` 核心 10 序列变更 | 保护存量项目预期；合规族仅 `--all-full`/单门禁执行 |
| 8 | 存在性门禁模板自证回退修复（--shift-left/--domain/--cognition/--impact） | 审计档:35 刻意不修；改 fail 语义须 fixture 先行 |
| 9 | logic-razor 门禁化 | 须先裁决 razor↔abstain 冲突（P1-10） |
| 10 | 取消 SILENT 机制 | 本批只加披露计数，不改变跳过行为本身（非破坏） |

## 七、风险与验证策略

| 修改类 | 主要风险 | 回归验证 |
|---|---|---|
| precheck.sh（T3） | 新门禁误伤存量；计数器改输出 | `bash -n`；57/57 fixture；e2e；golden-vector diff 空；A/B 退出码向量（修复前后同 fixture 集逐值相等）；最小 conf `--all-full` 退出码不变；shellcheck ≤ 基线；verifier runs 归档 |
| spring-boot.sh（T6） | 沉睡门禁苏醒误报真实项目 | GNU/BSD 双平台合成样本逐字节一致；expected-fail-ids 断言；57/57 全量；评估存量项目（ncwk-dev）重跑对比 |
| generate-skill.sh（T5） | create/upgrade/inject 回归 | create→verify exit 1、填充→0 双态；inject 幂等+哈希裁决；SKILLS_PATH_REWRITE 冒烟 |
| self-check.sh（T7） | 误报 miss | 合成 HOME 双态 fixture；篡改文档 FAIL 自证；实机全量 RC=0 |
| 文档数字（T9） | 漏同步再漂移 | 旧值 grep 清零（§T9 DoD）；check_doc_consistency 绿 |
| 新 reference/模板（T1/T2） | 锚点漂移致门禁误 fail | compliance fixture 双态锁锚点；spec §6 计数+§22 grep 断言 |
| conf 扩容（T3⑤） | bash 3.2 空数组崩溃 | `_default_conf` 兜底 + 旧 conf（无新变量）`--all-full` 实跑不崩 |

回退策略：全部改动在 `feat/standards-compliance` 分支，按 T1–T10 逐任务 commit；任一 DoD 不过即回滚该任务 commit，不带病进入下一任务。

---

## 八、P1/P2 执行状态附录（2026-07-20 第二批）

> 终态真值：门禁 34（核心 10 + 架构 17 + 合规 7）、conf 171 变量、references 16、框架 61（规则库目录 62 文件含 `_template.md`）、特征卡 16、运行时 11。gate-fixtures 34 组（6 P0 组 + 28 新增组）全绿；61/61 框架 fixture 双态绿。

### P1 逐项完成度

| 项 | 内容 | 状态 | 证据 |
|---|---|---|---|
| P1-1 | fixture 断言升级（57 框架 expected-fail-ids 全覆盖） | ✅ 完成 | 61 框架全登记 expected-fail-ids；verify-framework-ruleset 61/61 |
| P1-2 | 跨平台（CI macOS runner + NOBSD 静态检查） | ✅ 完成 | ci.yml macOS Job；verify-framework-ruleset.sh 要素 3c 五类禁则（白名单仅 tailwind.sh:81） |
| P1-3 | 安全门禁族深化（gitleaks/semgrep/授权类） | ✅ 完成 | sensitive 扩 gitleaks 子 fixture；semgrep 降级链 17 处挂接；`--authz`（CWE-862/863/639/284） |
| P1-4 | conf lint（--doctor） | ✅ 完成 | precheck.sh `--doctor`（conf lint：路径/glob 可达/死变量/框架 requires_conf，带病启动） |
| P1-5 | 证据落盘（--format json + gate-runs） | ✅ 完成 | `--format json`（SARIF 2.1.0 子集）+ `GATE_RUNS_DIR`/gate-runs.jsonl；`_gate_exec` 包装；text 模式零差异铁律守住（cli-ab 核心 10 逐字节一致） |
| P1-6 | verifier 断言化（cli-ab/metrics + 生成器自门禁） | ✅ 完成 | verifier/v1/cli-ab-test.sh（147 调用）+ metrics 断言；ci.yml generator-self-gate Job |
| P1-7 | 上游基线制度化 | ✅ 完成 | docs/upstream-baseline.md 扩 32 行登记；self-check 漂移忠告已接入 |
| P1-8 | MCP 默认最小化政策 | ✅ 完成 | `references/mcp-governance.md` 新增 |
| P1-9 | 需求 lint（29148 门禁化） | ✅ 完成 | `--requirements`（TBD/REQ- 唯一 ID 严格模式 fail-closed，EARS 覆盖率 warn-only） |
| P1-10 | 方法论修补 | ✅ 完成 | gsd-patterns.md「4-Phase SOP 定义页」（:71）；logic-razor.md「razor↔abstain 裁决条款」（:108）+ 纯阅读执法姿态标注（:6）；template-spec.md EARS↔29148 对齐声明（:360） |

### P2 本批已完成项

- **新门禁 fixture 28 组**（branch/scope/build/deps/test/review/security/domain/authz/reuse/layer/stable-diff/link-depth/contract/consistency-cross/adr/service/api/state/frontend/impact/knowledge/consistency/mermaid/shift-left/cognition/requirements/crypto，加 P0 6 组合 34 组；运行器无参数遍历全量 RC=0）
- **57 框架 CWE 元数据**（ruleset 登记全覆盖）
- **4 个新框架规则集**（dameng/langchain/terraform/kratos，57→61；索引已由 gen-framework-index.sh 重建）
- **国密 `--crypto`**（GB/T 39786-2021 密评 profile=gm：弱算法 fail，SM2/SM3/SM4 白名单；standards-compliance §D.5 挂接）
- **AI 过程信息项制度化**（`references/ai-process-records.md`，8566 附录 A/B 扩展，文档层制度）
- **功能安全域占位**（standards-compliance.md §E.5：ISO 26262/IEC 62304/IEC 61508-62443）

### 转 P3 清单

1. **RTM 门禁**（Q-11：需求↔测试追溯矩阵，29148 深化）
2. **发布签名 provenance**（SLSA v1.0 Build L2 + cosign，对齐 SSDF v1.2 草案 PS.2）
3. **多平台规则渲染**（规则库 → 各 harness 渲染管线）
4. **行业 profile**（等保/密评/金融/医疗，在 `--crypto` gm profile 模式上扩展）
5. **趋势可视化深化**（弱点密度/通过率趋势 Q-08/Q-20，gate-runs.jsonl 为数据源）
