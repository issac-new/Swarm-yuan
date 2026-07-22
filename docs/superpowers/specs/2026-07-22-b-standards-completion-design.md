# B：标准/安全补全设计

> 日期：2026-07-22 ｜ 分支：`feat/b-standards-completion`
> 范围：标准/安全补全（B 方向）—— 用户要求"交付物在质量及安全上必须满足相关行业及国家标准（对于当前项目所不具备的，必须进行深入调研补充）"
> 口径权威源：`swarm-yuan/assets/facts.conf`
> 调研依据：`docs/research/R7-quality-standards.md` / `docs/research/R8-security-standards.md` / `swarm-yuan/references/standards-compliance.md` / verifier 标准合规探索报告

---

## 1. 问题、目标与方案选型

### 1.1 问题定位（调研确认的缺口清单）

swarm-yuan 通过 `references/standards-compliance.md` 6 锚点矩阵 + 36 门禁（含 9 合规门禁）+ 2 行业 profile（金融/医疗）已建立较完整的标准覆盖。但调研确认以下**当前项目不具备**的缺口：

**缺口组 1：质量/过程成熟度（完全未覆盖）**
- **ISO 9001（质量管理体系）**——全仓库零引用
- **CMMI（能力成熟度模型集成）**——全仓库零引用
- **ISO/IEC 15504 / SPICE（过程评估）**——全仓库零引用

**缺口组 2：安全/密码学深度（浅覆盖）**
- **ISO/IEC 27001:2022**——仅 `standards-compliance.md:235` 一行登记 A.8.25–A.8.33，A.8.31 环境分离无检测
- **ISO/IEC 5055:2021 / GB/T 34943-34946（源代码漏洞测试规范）**——无 CWE 元数据分级（仅 mybatis 一处 CWE-89 标注）
- **密评深度（GB/T 39786-2021）**——`--crypto` 仅弱算法黑名单词法扫描，无国密正向使用核查、无密钥管理/随机数质量检测
- **SBOM CVE 阈值**——`--sbom` 仅许可证块名单，无漏洞阈值门禁（SCA 缺口）
- **无独立密码学规范文档**——密码学合规分散在矩阵/门禁/profile，缺系统性规范（密钥生命周期/国密算法使用模式/PKI）

**缺口组 3：功能安全域（明确不覆盖，须外审）**
- ISO 26262（车规）/ IEC 62304（医疗）/ IEC 61508-62443（工控）——`standards-compliance.md:281-292` 明确声明不覆盖

### 1.2 目标

对缺口组 1（质量/过程成熟度）和缺口组 2（安全/密码学深度）中**可机器化、且与现有门禁架构兼容**的部分进行补充；对缺口组 3（功能安全域）建立显式的"边界声明 + 外审指引"而非强行覆盖（这些是机构测评/认证级，非门禁级自动化能覆盖）。

### 1.3 方案选型（缺口分三组，按可机器化程度取舍）

| 缺口 | 可机器化程度 | 与现有架构兼容性 | 误报风险 | 选择 |
|------|------------|----------------|---------|------|
| **独立密码学规范文档** | 高（参考文档，无门禁） | 高（references/ 体系） | 无 | ✓ **选** |
| **SBOM CVE 阈值门禁** | 中（syft+grype 工具链） | 高（--sbom 已有降级链） | 中（CVE 阈值需校准） | ✓ **选** |
| **密评深度（国密正向核查）** | 中（国密算法使用模式 grep） | 高（--crypto 已有 gm profile） | 中 | ✓ **选** |
| **ISO 9001/CMMI 概念映射文档** | 高（参考文档，无门禁） | 高 | 无 | ✓ **选（文档级）** |
| ISO/IEC 27001 A.8.31 环境分离检测 | 低（环境拓扑判断难自动化） | 中 | 高 | ✗ 留文档级登记 |
| ISO/IEC 5055 CWE 元数据分级 | 中（需 CWE 数据库） | 中 | 中 | ✗ 留后续（工程量大） |
| 功能安全域（ISO 26262/IEC 62304） | 低（机构测评级） | 低 | 高 | ✗ 边界声明（不强行覆盖） |

**选型理由**：
- **可机器化优先**：选"参考文档补全"（密码学规范、ISO 9001/CMMI 映射）和"现有门禁扩展"（SBOM CVE、密评深度）——这些有明确落点且与现有架构兼容。
- **机构测评级不强行自动化**：ISO 27001 环境分离、功能安全域、ISO 5055 CWE 全量分级是机构测评/认证级，强行门禁化会淹没误报（违反审计"刻意不修沉睡门禁"原则），留文档级登记或显式边界声明。
- **功能安全域**：这些标准（ISO 26262 车规/IEC 62304 医疗/IEC 61508-62443 工控）要求的是完整的功能安全生命周期（HARA/ASIL 分解/安全案例），远超门禁级自动化范畴。正确做法是显式声明边界 + 指引外审，而非假装覆盖。

---

## 2. 架构与组件

### 2.1 总体架构

```
┌─ 缺口组 1：质量/过程成熟度（文档级补全）────────────────┐
│  references/quality-management-standards.md  [新增]      │
│  ISO 9001 / CMMI / ISO 15504 概念映射到 swarm-yuan 机制  │
│  （16 特征卡≈过程资产，36 门禁≈过程控制，verifier≈验证） │
└──────────────────────────────────────────────────────┘
┌─ 缺口组 2：安全/密码学深度（文档+门禁扩展）─────────────┐
│  references/crypto-spec.md  [新增]                       │
│  密钥生命周期/国密算法使用模式/PKI/随机数质量              │
│  precheck.sh --sbom 扩展：CVE 阈值门禁（grype 集成）      │
│  precheck.sh --crypto 扩展：国密正向使用核查              │
└──────────────────────────────────────────────────────┘
┌─ 缺口组 3：功能安全域（边界声明）───────────────────────┐
│  references/standards-compliance.md §E.5 扩写            │
│  显式声明不覆盖 + 外审指引（HARA/ASIL/安全案例需机构测评） │
└──────────────────────────────────────────────────────┘
```

### 2.2 组件清单

| # | 文件 | 动作 | 改动要点 |
|---|------|------|---------|
| 1 | `references/quality-management-standards.md` | **新增** | ISO 9001/CMMI/ISO 15504 概念映射到 swarm-yuan 机制（无门禁，纯文档） |
| 2 | `references/crypto-spec.md` | **新增** | 系统性密码学规范（密钥生命周期/国密算法使用模式/PKI/随机数质量/后量子迁移） |
| 3 | `assets/precheck.sh` check_sbom | 改 | 扩展 CVE 阈值门禁（syft 生成 SBOM 后 grype 扫描，阈值可配） |
| 4 | `assets/precheck.sh` check_crypto | 改 | 扩展国密正向使用核查（SM2/SM3/SM4 使用模式 grep + 密钥管理提示） |
| 5 | `references/standards-compliance.md` | 改 | §E.5 功能安全域扩写（显式边界 + 外审指引）+ §D 补 ISO 9001/CMMI 登记 |
| 6 | `assets/precheck.compliance.conf` | 改 | 新增 CVE_THRESHOLD/GM_CRYPTO_PATTERNS 等配置变量 |
| 7 | `assets/facts.conf` | 改 | 新增 references 数 + 合规 conf 变量数口径 |

### 2.3 四个补全项的具体设计

#### 补全①：references/quality-management-standards.md（文档级）

**为什么只文档级**：ISO 9001/CMMI/ISO 15504 是**组织级**质量/过程成熟度认证体系，评估的是"组织是否有定义良好的过程并持续改进"，不是单变更可门禁化的技术检查项。swarm-yuan 的机制（16 特征卡/36 门禁/verifier）**恰好是这些标准要求的"过程资产"的工程化实现**，但认证本身需机构审核。正确做法是概念映射文档——说明 swarm-yuan 的哪些机制对应这些标准的哪些过程域，供认证时引用。

**内容结构**：
```
§1 ISO 9001:2015（质量管理体系）
  - 7 质量管理原则 × swarm-yuan 机制映射
  - 过程方法（PDCA）× 生成流程 13 步映射
§2 CMMI v2.0（能力成熟度模型集成）
  - 成熟度等级 × swarm-yuan 定位（≈L3 已定义级：组织级过程资产+验证规程）
  - 过程域（PP/PMC/REQM/CM/PPQA/VER/VAL/OPD/OPF）× 机制映射
  - 缺口声明：缺 MA（度量分析）真值/CAR 因果分析/OPD-OPF 闭环（R3 §6.2 已确认）
§3 ISO/IEC 15504 / SPICE（过程评估）
  - 过程能力等级 × 门禁 enforce_level 三档类比
§4 边界声明
  - 这些是组织级认证，非门禁级自动化能覆盖
  - swarm-yuan 提供的是"过程资产的工程化实现"，认证需机构审核
```

#### 补全②：references/crypto-spec.md（文档级）

**为什么需要**：调研确认"密码学无独立规范文档——分散在矩阵/门禁/profile，缺系统性密码学规范（如密钥生命周期、国密算法使用模式、PKI）"。

**内容结构**：
```
§1 密码学应用总原则（最小化/默认安全/密钥与代码分离）
§2 密钥生命周期（生成/分发/存储/轮换/撤销/销毁）
§3 算法选型
  - 通用：bcrypt/scrypt/argon2（口令哈希）、AES-256-GCM（对称）、RSA-3072/ECDSA-P256（非对称）、SHA-256+（哈希）
  - 禁用：MD5/SHA1/DES/RSA-1024/ECB 模式
  - 国密（GB/T 39786-2021）：SM2（非对称）/SM3（哈希）/SM4（对称）使用模式
§4 随机数质量（CSPRNG，禁用 Math.random/rand() 于安全场景）
§5 PKI 与证书管理（证书链验证/OCSP/有效期）
§6 后量子迁移（PQC）展望（NIST FIPS 203/204/205，ML-KEM/ML-DSA/SLH-DSA）
§7 对齐标准（GB/T 39786 / ISO/IEC 18033 / NIST SP 800 系列）
```

#### 补全③：check_sbom 扩展 CVE 阈值门禁

**现状**：`--sbom` 生成 SBOM + 许可证块名单，无漏洞阈值（调研确认"无 CVE 漏洞阈值门禁，仅许可证层，SCA 缺口"）。

**扩展**：SBOM 生成后追加 grype 漏洞扫描（工具降级链 `grype → osv-scanner → 跳过`），按可配阈值 fail：

```
check_sbom 现有：syft → cdxgen → lockfile 解析 → license 块名单
新增：SBOM 生成后 → grype sbom:<file> --fail-on <severity>
  - CVE_THRESHOLD=high（默认）：critical+high 漏洞 → fail
  - CVE_THRESHOLD=critical：仅 critical → fail
  - 工具降级：无 grype → osv-scanner → 无则 warn 跳过（与现有降级链一致）
  - 姿态：skip_if_unconfigured → 配置 CVE_THRESHOLD 后 fail-closed
```

**误报控制**：CVE 阈值需校准（默认值 high 可能对某些项目过严），阈值可配 + 豁免 5 字段留痕（与现有豁免机制一致）。

#### 补全④：check_crypto 扩展国密正向使用核查

**现状**：`--crypto` 仅弱算法黑名单词法扫描（MD5/SHA1/DES），无国密正向使用核查（调研确认）。

**扩展**：CRYPTO_PROFILE=gm 时，在弱算法黑名单之上追加国密正向核查：

```
check_crypto 现有：弱算法黑名单（MD5/SHA1/DES/RSA-1024/ECDSA）
新增（CRYPTO_PROFILE=gm 时）：
  - 国密正向使用核查：检测到加密操作但无 SM2/SM3/SM4 引用 → warn
    （"检测到加密操作但未使用国密算法，密评场景须 SM2/SM3/SM4"）
  - 密钥管理提示：硬编码密钥模式（与 sensitive 门禁协同）→ warn
  - 随机数质量：Math.random/rand() 于安全上下文 → warn
  - 姿态：国密正向核查为 warn（不 fail，避免误报——加密场景判断难自动化）
```

**边界**：机构密评测评仍属线下（`standards-compliance.md` 已声明），门禁只覆盖词法层可检测项。

---

## 3. 数据流与标准映射

### 3.1 四个补全项的数据流

```
质量/过程成熟度（文档级）：
  ISO 9001/CMMI/ISO 15504 → quality-management-standards.md 概念映射
  → 供认证时引用（无门禁）

密码学规范（文档级）：
  密钥生命周期/国密/PKI/随机数 → crypto-spec.md
  → 被 security-spec.md 引用，被 check_crypto 门禁依据

SBOM CVE 阈值（门禁扩展）：
  SBOM 生成 → grype 扫描 → CVE 超阈值 fail
  → 补 SCA（软件成分分析）缺口

密评深度（门禁扩展）：
  CRYPTO_PROFILE=gm → 弱算法黑名单（现有）+ 国密正向核查（新增）
  → 补密评自动化深度
```

### 3.2 标准映射表（新增/扩展）

| 标准 | 现状 | B 方向落地 | 门禁/文档 |
|------|------|-----------|----------|
| ISO 9001:2015 | ❌ 零覆盖 | 概念映射文档 | quality-management-standards.md（无门禁） |
| CMMI v2.0 | ❌ 零覆盖 | 概念映射文档 | 同上（无门禁） |
| ISO/IEC 15504 | ❌ 零覆盖 | 概念映射文档 | 同上（无门禁） |
| 密码学系统规范 | ❌ 分散 | 独立规范文档 | crypto-spec.md（无专属门禁，被 check_crypto 依据） |
| SBOM CVE（SCA） | 🟡 仅许可证 | CVE 阈值门禁 | check_sbom 扩展 |
| GB/T 39786 密评深度 | 🟡 弱算法黑名单 | 国密正向核查 | check_crypto 扩展 |
| ISO 26262/IEC 62304/IEC 61508 | ❌ 明确不覆盖 | 边界声明 + 外审指引 | standards-compliance.md §E.5 扩写 |

---

## 4. 错误处理、测试与对齐标准

### 4.1 错误处理

| 补全项 | 故障 | 行为 |
|-------|------|------|
| SBOM CVE | grype 不可用 | 降级 osv-scanner → 无则 warn 跳过（与现有降级链一致） |
| SBOM CVE | CVE 阈值误报 | 阈值可配 + 豁免 5 字段留痕 |
| 密评正向核查 | 加密场景误判 | warn 不 fail（避免误报淹没） |
| 文档级补全 | 无故障面（纯文档） | — |

### 4.2 测试策略

| 验证手段 | 覆盖什么 |
|---------|---------|
| `bash -n` 语法检查 | check_sbom/check_crypto 改动 |
| SBOM CVE 手动验证 | 造含已知 CVE 依赖的 lockfile，看 grype fail |
| 密评正向核查手动验证 | CRYPTO_PROFILE=gm + 非国密加密代码，看 warn |
| 文档完整性 | grep 验证 quality-management-standards.md/crypto-spec.md 章节齐全 |
| facts.conf 对账 | references 数 + conf 变量数口径 |

### 4.3 对齐标准

| 标准 | B 落地 |
|------|--------|
| ISO 9001:2015 | 概念映射文档（组织级认证需机构审核，swarm-yuan 提供过程资产工程化实现） |
| CMMI v2.0 | 同上（≈L3 已定义级定位，缺 MA/CAR/OPD-OPF 显式声明） |
| ISO/IEC 15504 | 同上（过程能力等级 × enforce_level 三档类比） |
| GB/T 39786-2021 密评 | 国密正向核查 + crypto-spec.md 国密使用模式 |
| ISO/IEC 18033 / NIST SP 800 | crypto-spec.md 算法选型依据 |
| SBOM/SCA（供应链） | CVE 阈值门禁补 SCA 缺口（对齐 NIST SSDF RV/OWASP A06） |
| ISO 26262/IEC 62304/IEC 61508 | 显式边界声明 + 外审指引（不强行覆盖机构测评级） |

### 4.4 边界声明（重要）

**B 方向明确不做的事**：
- ❌ 不强行门禁化 ISO 27001 环境分离检测（环境拓扑判断难自动化，误报风险高）
- ❌ 不做 ISO 5055 CWE 全量分级（需 CWE 数据库，工程量大，留后续）
- ❌ 不假装覆盖功能安全域（ISO 26262/IEC 62304/IEC 61508 是机构测评级，显式声明边界 + 外审指引）
- ❌ 不做 ISO 9001/CMMI 认证自动化（组织级认证需机构审核，只做概念映射文档）

**理由**：这些是机构测评/认证级要求，强行门禁化会淹没误报（违反审计"刻意不修沉睡门禁"原则——无真实项目校准的硬门禁是头号风险）。正确做法是文档级登记 + 显式边界声明，让"不覆盖"成为诚实声明而非隐性缺口。

---

## 5. 实现顺序预估

| WP | 内容 | 依赖 | 预估文件改动 |
|----|------|------|------------|
| WP-B-1 | references/quality-management-standards.md 新增（ISO 9001/CMMI/ISO 15504 映射） | 无 | 1 新增 |
| WP-B-2 | references/crypto-spec.md 新增（密码学系统规范） | 无 | 1 新增 |
| WP-B-3 | check_sbom 扩展 CVE 阈值 + precheck.compliance.conf 配置 | 无 | 2 改 |
| WP-B-4 | check_crypto 扩展国密正向核查 | 无 | 1 改 |
| WP-B-5 | standards-compliance.md §E.5 扩写 + facts.conf 口径 | WP-B-1/2 | 2 改 |

---

## 6. 关键证据索引

- ISO 9001/CMMI/ISO 15504 零覆盖：verifier 标准合规探索报告 §4.2
- ISO 27001 浅覆盖：`swarm-yuan/references/standards-compliance.md:235`
- ISO 5055/GB 34943 无 CWE 分级：`swarm-yuan/references/standards-compliance.md:224,244-249`
- 密评仅弱算法黑名单：`swarm-yuan/assets/gates-warn.sh:1178-1216`
- SBOM 无 CVE 阈值：`swarm-yuan/assets/gates-strict.sh:755-849`
- 无独立密码学规范文档：verifier 标准合规探索报告 §5.3
- 功能安全域不覆盖：`swarm-yuan/references/standards-compliance.md:281-292`
- R3 CMMI ≈L3 定位 + 缺 MA/CAR：`docs/research/R3-methodology.md` §6.2
- R7 质量标准调研：`docs/research/R7-quality-standards.md`
- R8 安全标准调研：`docs/research/R8-security-standards.md`
- check_sbom 现有实现：`swarm-yuan/assets/gates-strict.sh:755-849`
- check_crypto 现有实现：`swarm-yuan/assets/gates-warn.sh:1178-1216`
- security-spec.md 密码哈希一行：`swarm-yuan/references/security-spec.md:34`
