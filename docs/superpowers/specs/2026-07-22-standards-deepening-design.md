# WP-S 标准合规深化设计（spec）

- 日期：2026-07-22
- 分支：feat/wp-s-standards-deepening
- 状态：待用户审阅
- 前置研究：docs/research/R1–R9（2026-07-20/22 基线）+ 本轮标准事实核验（10 条，来源见附录 B）

---

## 1. 背景与目标

### 1.1 调研结论摘要

swarm-yuan 已是真实的"研发范式元技能生成器"：16 项特征卡（立法）+ 36 门禁（执法，strict 12 / warn 18 / advisory 6）+ 62 框架规则三件套 + 四档 profile。对 11 个上游运行时采用三层接线模型（深度接线 4 / CLI 接线 3 / 方法论引用 4），执行诚实。R9 实测证明 5 个真实项目端到端可用、门禁检出真实安全问题。

距"交付物在质量及安全上满足行业及国家标准"的残余缺口（R7/R8 基线，扣除近期合规 9 门禁已补项）：

- **质量侧**：特征卡未对齐 GB/T 25000.10 质量模型；测试证据链与准出（GB/T 15532/9386）；评审记录与 AI 过程信息项（GB/T 8566 / ISO 42001）；门禁规则缺 CWE/条款级元数据（62 框架中 20+ 零 CWE 引用）；度量门禁化。
- **安全侧**：等保 2.0（GB/T 22239）控制点级映射未做；PIA 隐私影响评估（个保法/GB/T 35273）；SAST 停留词法层（对照 GB/T 34943/44/46）；开源代码安全评价四维（GB/T 43848-2024）未闭环。
- **行业 profile**：仅 finance + medical，缺政务/关基（等保强制场景）。
- **交换格式**：无 JSON/SARIF 机器可读输出（SARIF 2.1.0 为 OASIS Standard）。
- **地基**：静默跳过不透明、madge stderr 丢弃、4 处 `\|` 字面 bug、spring-boot 两处平台相关沉睡、真实项目冒烟未入 CI。

### 1.2 目标

在不推翻既有资产（门禁三件套、四要素验收、fixture 双态、verifier 金向量、profile 四档）的前提下：

1. 新增 8 个标准门禁（安全族 4 + 质量族 4），36 → 44 门禁，全部挂 `--compliance-suite`。
2. 特征卡新增第 17 项「合规与质量特性基线」，驱动全部新门禁配置。
3. spec 模板新增 §23「质量特性与标准剪裁」。
4. 新增标准映射机器可读层 `assets/standards-map.conf`，回填框架规则 CWE 元数据（P0 批 20 个）。
5. 新增行业 profile `gov`（政务/关基）。
6. 输出层最小实现：`--format json` + SARIF 2.1.0 转换。
7. 夹带修复 5 项阻断执法的地基缺陷。
8. 真实项目冒烟测试入 CI。

### 1.3 非目标（YAGNI / 后续批次）

- 汽车 ISO 26262、电力 27 号令、医疗 IEC 62304 行业 profile（后续 WP）。
- 门禁引擎全量重构（输出层只做汇总层最小实现，不动 36 个既有门禁内部）。
- 方法论引用层（gstack/superpowers）未吸收理念的门禁化（独立 WP）。
- ASVS 5.0 全章映射（本轮只覆盖新门禁涉及的章节；authz 门禁既有映射不动）。
- 62 框架 CWE 全量回填（本轮 P0 批 20 个，其余后续）。

---

## 2. 已核验标准事实（设计依据，全部有来源）

| # | 事实 | 置信 |
|---|------|------|
| F1 | ISO/IEC 25010:2023 产品质量九特性：功能适合性/性能效率/兼容性/交互能力/可靠性/安全性/可维护性/灵活性/Safety（无害性，2023 版新增；Usability→交互能力、Portability→灵活性改名） | 高（ISO OBP） |
| F2 | GB/T 25000.10 现行仍为 2016 版（八特性，无 Safety），未见修订版发布——国标滞后窗口内主动对齐 25010:2023 | 高（openstd.samr.gov.cn） |
| F3 | GB/T 22239-2019 技术要求五类（物理/通信网络/区域边界/计算环境/管理中心）+ 管理要求五类；"安全建设管理"属管理要求。三级起要求双因子鉴别（两种及以上组合且至少一种密码技术）；审计记录字段=日期时间/用户/事件类型/成功与否（三级加审计保护）；剩余信息保护与个人信息保护二级起有要求、三级加码 | 高（标准全文转载） |
| F4 | GB/T 34943-2017《C/C++语言源代码漏洞测试规范》、34944-2017《Java》、34946-2017《C#》均现行（注意名称是"漏洞测试规范"） | 高（官方平台） |
| F5 | OWASP ASVS 5.0.0 已于 2025-05-30 正式发布（取代 4.0.3）；CWE 映射改经 OWASP CRE 对齐；L1 聚焦约 70/345 条 | 高（OWASP 官网/GitHub） |
| F6 | SARIF 2.1.0 为 OASIS Standard（2020-03-27 批准）；2.2 仍 prerelease——只实现 2.1.0 | 高（OASIS 官网） |
| F7 | GB/T 43848-2024《网络安全技术 软件产品开源代码安全评价方法》（2024-11-01 实施），评价四维：来源/安全质量/知识产权（许可证遵从）/管理（物料清单文档审核）。**回避纪律：不得宣称"强制提交 SBOM"**，只表述"成分清单与许可证合规纳入评价体系" | 高（官方平台）；强制措辞未证实 |
| F8 | ISO/IEC 42001:2023 含成文信息控制与可追溯目标；**回避纪律：不引用具体条款号**，只引用到"管理体系成文信息+可追溯"层面。中国生成式 AI 国标 GB/T 45654-2025（服务安全基本要求）等已发布，本轮仅登记不映射 | 高；条款级未证实 |
| F9 | GB/T 8566-2022《系统与软件工程 软件生存周期过程》现行，官方标注"采"（第三方信源：等同采用 ISO/IEC/IEEE 12207:2017） | 较高 |
| F10 | GB/T 15532-2008《计算机软件测试规范》现行有效，未见替代 | 高（官方平台） |

---

## 3. 总体架构

新增与 framework-gates 平行的**标准门禁族**机制：

```
references/standards-compliance.md   ← 立法（标准映射主文档，吸收 R7/R8 映射表 + F1-F10）
assets/standards-map.conf            ← 机器可读映射（规则id|CWE|GB/ISO条款|ASVS5章|来源置信）
assets/precheck.compliance.conf      ← 新增配置变量（DENGBAO_LEVEL 等，见 §6.3）
assets/precheck.sh + gates-*.sh      ← 8 个新 check_* 函数（enforce_level 由 gen-enforce-level.sh 机械归类）
assets/spec-template.md              ← 新增 §23
assets/industry-profiles/gov.conf    ← 政务/关基 profile
scripts/to-sarif.sh                  ← JSON → SARIF 2.1.0 转换
tests/gate-fixtures/<gate>/          ← 8 组双态 fixture
```

特征卡第 17 项「合规与质量特性基线」提取：适用标准族（quality/security 子集）、等保级别（空/2/3）、行业 profile（空/finance/medical/gov）、质量特性剪裁声明、AI 过程信息项要求。驱动 `--dengbao`/`--pia`/`--quality-model`/`--review-record` 等的启用与档位。

---

## 4. 安全门禁族（4 个，挂 --compliance-suite）

### 4.1 `--dengbao`（等保 2.0 控制点映射）

- 依据：F3（GB/T 22239-2019 安全计算环境 + 安全建设管理）。
- 配置：`DENGBAO_LEVEL=""|2|3`（空=跳过并明示 SKIP）。
- 检查项（启用即 fail-closed，豁免须 `DENGBAO_EXEMPT_FILE` 留痕）：
  1. 身份鉴别：三级时扫描认证入口存在双因子证据（TOTP/OTP/短信+口令/密钥之一组合配置），缺失 fail；二级 warn。
  2. 安全审计：日志调用点审计字段完整性（时间/用户/事件类型/结果四要素，按日志框架模式匹配 + spec §23 审计字段声明核对），缺字段 fail。
  3. 剩余信息保护：敏感数据（口令、密钥、个人信息）存储/缓存清除证据，缺失 warn。
  4. 个人信息保护：与 `--privacy` 门禁结果勾稽（privacy fail 则 dengbao fail）。
  5. 安全建设管理（文档面）：spec §23 等保级别声明与 DENGBAO_LEVEL 一致性，不一致 fail。
- 扫描目录沿用 `SECURITY_SCAN_DIRS`，启用 `DENGBAO_SCAN_DIRS` 覆盖。

### 4.2 `--pia`（隐私影响评估）

- 依据：个保法第 55–56 条、GB/T 35273-2020。
- 配置：`PIA_DOCS_DIR`（默认 docs/privacy）、`PIA_REQUIRED=0|1`。
- 检查项：① PIA 文档存在（文件名匹配 pia/隐私影响评估）；② 个人信息处理活动清单存在；③ `--privacy` 扫描命中目录与清单登记的一致性（命中未登记 warn）；④ PIA 文档零 TBD（fail-closed）。
- 与 privacy 门禁关系：privacy 扫代码中的个人信息明文，pia 验文档过程合规，互补不重复。

### 4.3 `--sast-deep`（AST/数据流层 SAST）

- 依据：F4（GB/T 34943/44/46-2017 漏洞类别）。
- 降级链（沿用"调用不重实现 + 自带降级载体"）：`semgrep scan --config auto` → `opengrep` → 自带 grep 模式族（复用 check_security 规则），stdout 明示当前载体（trace.jsonl 落盘）。
- 配置：`SAST_DEEP_TOOL=auto|semgrep|opengrep|builtin`、`SAST_DEEP_SEVERITY=error|warning`（达到该级别 fail）。
- 内置载体与外部工具结果按 standards-map.conf 挂 CWE id 输出。

### 4.4 `--oss-eval`（开源代码安全评价）

- 依据：F7（GB/T 43848-2024 四维）。
- 检查项：① 成分清单存在（复用 `--sbom` 产物，sbom 跳过则本门禁 SKIP 并明示）；② 许可证块名单扫描结果引用；③ 上游来源登记（docs/upstream-baseline.md 或目标项目等价物存在 + baseline_status 标记完整）；④ 漏洞处置记录（已知漏洞豁免须有到期日）。
- 措辞纪律：文档与门禁输出只说"成分清单/许可证合规纳入评价"，不宣称"强制 SBOM"（F7 回避项）。

---

## 5. 质量门禁族（4 个，挂 --compliance-suite）

### 5.1 `--quality-model`（质量特性剪裁核验）

- 依据：F1/F2。
- 检查项：spec §23 质量特性剪裁表完整——25000.10-2016 八特性逐项声明"适用/剪裁+理由"（零占位符，fail-closed）；Safety 维度单独声明（对齐 25010:2023，标注"国标 25000.10-2016 暂无该维度，主动对齐国际版"）；声明与特征卡第 17 项一致。

### 5.2 `--test-evidence`（测试证据链）

- 依据：F10（GB/T 15532-2008）、GB/T 9386-2008。
- 配置：`TEST_EVIDENCE_DIR`（默认 docs/test）。
- 检查项：① 测试计划/测试说明/测试报告三类文档存在（模板名可配）；② 测试报告含准出条件结论段；③ 报告中的用例编号与 `--rtm` 的 REQ- 编号可勾稽（抽样核对，断链 warn）；④ 零 TBD。
- 与 docs-pack 关系：docs-pack 验文档包清单存在性，test-evidence 验测试证据链内容有效性，互补。

### 5.3 `--review-record`（评审记录与 AI 过程信息项）

- 依据：F9（GB/T 8566-2022 评审过程）、F8（ISO/IEC 42001 成文信息+可追溯，只引用到层面不引条款号）。
- 配置：`REVIEW_RECORD_DIR`（默认 docs/reviews）、`AI_DISCLOSURE_REQUIRED=0|1`。
- 检查项：① 评审记录存在且含评审人/日期/结论三要素；② AI 辅助生成的交付物带 AI 生成声明 + 人工复核记录（spec §23 勾选 + 记录文件）；③ 结论为"不通过"的记录须有对应整改闭环引用。

### 5.4 `--metrics`（度量门禁化）

- 依据：GB/T 25000.30（质量度量）、CCSA DevOps 度量要素。
- 实现：复用 scripts/gate-trends.sh 产物——`gate-runs.jsonl` 存在且任意 strict 门禁连续 N 次（`METRICS_TREND_WINDOW`，默认 3）通过率下降 = fail；无数据 = SKIP 明示。
- 边界：本门禁只做"趋势恶化告警"，不做绝对阈值（阈值属项目自治）。

---

## 6. 标准映射层与特征卡/模板扩展

### 6.1 `assets/standards-map.conf`（机器可读）

格式（pipe 分隔，grep -E 友好，无 declare -A）：

```
# rule_or_gate_id | cwe_ids | gb_iso_ref | asvs5_section | confidence(high|medium|unverified)
check_security.sql_injection | CWE-89 | GB/T 34944-2017 | 5.0:Securing-Data | high
```

- 本轮内容：8 个新门禁全部条目 + 36 既有门禁的映射 + P0 批 20 个框架规则的 CWE 回填。
- 置信字段实现 F7/F8 回避纪律：`unverified` 条目门禁输出带"待验证"字样，不引条款号。
- `--compliance` 门禁扩展：核验 standards-map.conf 每条目四字段非空 + confidence 合法值。

### 6.2 特征卡第 17 项「合规与质量特性基线」

| 要素 | 内容 |
|---|---|
| AI 提取什么 | 适用标准族、等保级别、行业 profile、质量特性剪裁、AI 过程信息项要求 |
| 驱动什么 | `--dengbao` `--pia` `--quality-model` `--review-record` `--oss-eval` 启用与档位；gov/finance/medical profile 选择 |

同步更新：SKILL.md 特征卡表、README.md、exploration-guide、generate-skill.sh 骨架模板、facts.conf（16→17）。

### 6.3 spec 模板 §23「质量特性与标准剪裁」（新增主段）

固定子段：§23.1 质量特性剪裁表（八特性+Safety）；§23.2 等保级别与审计字段声明；§23.3 标准族适用声明与剪裁理由；§23.4 AI 过程信息项（AI 生成声明+人工复核）；§23.5 豁免与留痕索引。spec 三级机器执法（detect-spec-scale.sh）把 §23 纳入"完整"档必备段。

### 6.4 新增配置变量（进 precheck.compliance.conf，新增 14 个）

`DENGBAO_LEVEL / DENGBAO_SCAN_DIRS / DENGBAO_EXEMPT_FILE / PIA_DOCS_DIR / PIA_REQUIRED / SAST_DEEP_TOOL / SAST_DEEP_SEVERITY / OSS_EVAL_REQUIRED / QUALITY_MODEL_REQUIRED / TEST_EVIDENCE_DIR / REVIEW_RECORD_DIR / AI_DISCLOSURE_REQUIRED / METRICS_TREND_WINDOW / OUTPUT_FORMAT`

全部给空默认值（未配置=SKIP 明示），懒生成机制同步；变量总数以 facts.conf 同步时实数为准（README 口径 142 与 CLAUDE.md 三件套口径 179 的差异在同步时一并核对）。

### 6.5 行业 profile `gov`

`assets/industry-profiles/gov.conf`：`DENGBAO_LEVEL=3` + `CRYPTO_PROFILE=gm` + `PRIVACY_REQUIRED=1` + `PIA_REQUIRED=1` + docs-pack 严格档 + `AI_DISCLOSURE_REQUIRED=1`，逐条挂法规依据注释（GB/T 22239/39786、个保法）。配套立法文档 `references/industry-profile-gov.md`（结构对齐 finance/medical 两件套）。facts.conf 行业 profile 2→3。

---

## 7. 输出层（最小实现）

- `precheck.sh --format json|text`（默认 text 不变）：汇总层输出 `{gate, level, result(fail|warn|pass|skip), message, standards_ref}` 数组；SKIP 必须显式出现（同时解决地基项①的透明化）。
- `scripts/to-sarif.sh < report.json > report.sarif`：SARIF 2.1.0（F6），rules 元数据从 standards-map.conf 取 CWE/条款；只做 2.1.0 不追 2.2。
- 不动既有 36 门禁的内部 stdout（verifier C5 字节级兼容不受破坏——`--format` 是新增可选 flag）。

---

## 8. 地基修复夹带（5 项）

| # | 缺陷 | 处置 | 决策档案核对 |
|---|------|------|-------------|
| ① | `--all-full` 静默跳过输出"✓ 通过" | 改显式 SKIP 计数 + 汇总段列出跳过清单；JSON 输出同步 | R1-G5 已立项，非刻意沉睡 |
| ② | madge stderr 被丢弃致循环依赖分支沉睡 | 捕获 stderr 到变量，失败时降级"纯转发统计"并明示 | R2 已确认缺陷 |
| ③ | 4 处 grep `\|` 字面 bug | 修字面量为 alternation 或拆两次 grep；逐处验证 fixture 不误醒 | 决策 2 标注"留独立版本评估"→ 本轮即该版本 |
| ④ | spring-boot 两处平台相关沉睡（BSD grep `\[\]` 字符类、actuator 嵌套 YAML 漏配） | 改 POSIX 兼容写法 + YAML 解析兼容嵌套；macOS+ubuntu 双端验证 | R4 新发现，无否决记录 |
| ⑤ | 真实项目冒烟未入 CI | 新增 CI job：RuoYi-Vue3（前端）+ yudao-cloud（后端多模块）pin commit，generate + precheck --all 冒烟，artifact 存报告 | R9 核心建议 |

每项改动前重读 `docs/paradigm-decisions.md` 对应条目确认无"刻意沉睡"否决。

---

## 9. 测试与验收

1. **gate-fixture 双态 ×8**：tests/gate-fixtures/{dengbao,pia,sast-deep,oss-eval,quality-model,test-evidence,review-record,metrics}/{violating,compliant}，含 expected-ids 断言；sast-deep fixture 在无 semgrep 环境验证降级链明示。
2. **gov profile fixture**：industry-profiles/gov.conf 加载后 DENGBAO_LEVEL=3 生效断言。
3. **SARIF fixture**：to-sarif.sh 输出过 SARIF 2.1.0 schema 关键字段断言（version/runs/rules/results）。
4. **verifier 金向量更新**：golden-vector 不变（框架 fixture 不动），C5 CLI 兼容增加 `--format json` 语料，C6 metrics 基线更新；runs/ 追加账本记录。
5. **facts.conf 同步**：门禁 36→44、特征卡 16→17、行业 profile 2→3、conf 变量数、references 数；self-check 口径执法全绿。
6. **冒烟 CI job**：§8-⑤。
7. **自举**：生成器仓库自身跑 `--compliance-suite` 新门禁（ci/self-precheck.conf 增补最小配置），红灯不过。
8. **三平台**：CI ubuntu + macos + windows 全覆盖新 fixture（§8-④ 依赖 macos 端验证）。

---

## 10. 错误处理与降级姿态

- 新门禁沿用 compliance 既有姿态：**未配置 SKIP 明示、启用即 fail-closed、豁免留痕**（豁免文件路径进 §23.5 索引）。
- sast-deep 三级降级链，载体选择写 trace.jsonl。
- 全部新代码遵守跨平台 bash 约束：无 `declare -A`、`sed -i.bak` 后 `rm`、`grep -E`、`date -u`、`$(cd ... && pwd)`、bash 3.2 兼容。
- enforce_level 由 `scripts/gen-enforce-level.sh` 机械归类（fail()≥3 strict / 1-2 warn / 0 advisory），不手工指定；预期：dengbao/pia/quality-model/test-evidence/review-record 落 strict，sast-deep/oss-eval 视实现落 warn~strict，metrics 落 warn（趋势恶化 1 个 fail 路径）。

---

## 11. 范围控制与分批

本 spec 为单一份，实施允许拆两个 plan 顺序收口（先 S1 后 S2）：

- **WP-S1（安全+地基）**：§4 安全族 4 门禁 + §6.1 映射层 + §6.5 gov profile + §8 地基修复 + §9 对应测试。
- **WP-S2（质量+输出）**：§5 质量族 4 门禁 + §6.2/§6.3 特征卡与模板 + §7 输出层 + §9 对应测试 + facts.conf 终态同步。

分界依据：S1 不动特征卡位数（36→40 门禁、16 卡不变），facts.conf 改动小；S2 才翻 16→17/40→44 的大数字，一次性改。若 S1 实施中发现必须动特征卡，回退为单 plan。

---

## 附录 A：与既有研究的追溯

| 本 spec 条目 | 来源 |
|---|---|
| §4 安全族 | R8 安全门禁族 6 子项建议（secret-scan 已由 sensitive 覆盖、发布签名已由 release-sign 覆盖，故 6→4） |
| §5 质量族 | R7 Q-01/Q-02（quality-model）、Q-04/Q-13/Q-14（test-evidence）、Q-16/Q-22（review-record）、Q-20（metrics） |
| §6.1 映射层 | R2 建议 5（规则挂 CWE/条款）、R4（CWE 证据分级） |
| §7 输出层 | R2 建议 3（--format json）、R7 Q-08（SARIF/机器可交换） |
| §8 地基 | R1-G5、R2（madge/`\|`）、R4（spring-boot）、R9（冒烟 CI） |
| 回避纪律 | 本轮核验"未能证实"清单（F4 类别数、F7 强制措辞、F8 条款号） |

## 附录 B：标准事实来源

ISO OBP（25010:2023）、openstd.samr.gov.cn（25000.10-2016、34943/44/46、43848-2024、8566-2022、15532-2008、GB/T 45654-2025）、GB/T 22239-2019 全文（cnblogs 转载核对）、OWASP ASVS 官网及 GitHub Releases（5.0.0，2025-05-30）、OASIS SARIF 2.1.0 OS（2020-03-27）、ISO 81230（42001:2023）、TC260 公开案例（43848 落地含 SCA/SBOM 实践）。
