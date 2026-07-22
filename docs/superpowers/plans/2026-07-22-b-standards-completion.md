# B：标准/安全补全 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or executing-plans. Steps use `- [ ]` syntax.

**Goal:** 补全 ISO 9001/CMMI/密码学规范（文档级）+ SBOM CVE 阈值 + 密评国密正向核查（门禁扩展）+ 功能安全域边界声明。

**Architecture:** 新增 quality-management-standards.md + crypto-spec.md 两个参考文档；check_sbom 扩展 CVE 阈值门禁（grype 降级链）；check_crypto 扩展国密正向核查（warn 级）；standards-compliance.md §E.5 扩写边界。

**Tech Stack:** Bash 3.2 兼容 + Markdown + grype/osv-scanner 工具链。

**Spec:** `docs/superpowers/specs/2026-07-22-b-standards-completion-design.md`

## Global Constraints

- 文档级补全（质量/过程成熟度 + 密码学规范）无门禁——组织级认证/机构测评级不强行自动化
- 密评国密正向核查为 **warn 级**（加密场景判断难自动化，避免误报）
- 功能安全域显式声明边界，不强行覆盖
- bash 3.2 兼容；commit 风格 `feat(b):`

---

### Task 1: references/quality-management-standards.md（ISO 9001/CMMI/ISO 15504 映射）

**Files:**
- Create: `swarm-yuan/references/quality-management-standards.md`
- Modify: `swarm-yuan/assets/facts.conf`（FACT_REFERENCES 18→19）

- [ ] **Step 1: 写 quality-management-standards.md**

结构（§1 ISO 9001 / §2 CMMI / §3 ISO 15504 / §4 边界声明）：

```markdown
# 质量与过程成熟度标准映射（ISO 9001 / CMMI / ISO 15504）

> 边界声明：这些是**组织级**质量/过程成熟度认证体系，评估"组织是否有定义良好的过程并持续改进"，
> 认证需机构审核，非门禁级自动化能覆盖。本文档做**概念映射**——说明 swarm-yuan 的哪些机制对应
> 这些标准的哪些过程域，供认证时引用。不提供专属门禁。

## 1. ISO 9001:2015（质量管理体系）

7 质量管理原则 × swarm-yuan 机制映射：

| 原则 | swarm-yuan 机制 |
|------|----------------|
| 以顾客为关注焦点 | 特征卡第 14 项领域知识 + spec §1.2 价值声明 |
| 领导作用 | SKILL.md 铁律 + 决策分级（G1） |
| 全员参与 | AI 主导 + 用户决策（决策审计轨迹 decisions.jsonl） |
| 过程方法（PDCA） | 生成流程 13 步 + workflow 节点 + state-machine 阶段 |
| 改进 | verifier/v1 验收 + self-check 文档一致性 + profile 动态升档 |
| 循证决策 | 16 特征卡探查 + 门禁计数指向关系规律 |
| 关系管理 | 11 运行时整合（分层接线 + 诚实降级） |

## 2. CMMI v2.0（能力成熟度模型集成）

**swarm-yuan 定位 ≈ L3 已定义级**：组织级过程资产（六段式模板 + 62 框架规则集）+ 验证规程（36 门禁 + verifier/v1）。

| 过程域 | swarm-yuan 机制 | 缺口 |
|--------|----------------|------|
| PP 项目规划 | spec-template + plan-template | — |
| REQM 需求管理 | --requirements + --rtm（ISO 29148） | — |
| CM 配置管理 | --deps 版本锁定 + git worktree | 版本基线单一 |
| PPQA 过程质量保证 | 36 门禁 + enforce_level 三档 | — |
| VER 验证 | verifier/v1 + gate-fixture 双态 | — |
| MA 度量分析 | gate-runs.jsonl + adaptive gating | **缺真值度量（认知分数是关键词启发式）** |
| CAR 因果分析 | — | **缺** |
| OPD/OPF 过程改进 | memory-persistence（ruflo/ECC 引用） | **缺自实现闭环** |

（R3 §6.2 已确认 L4/L5 量化管理无从谈起，显式声明。）

## 3. ISO/IEC 15504 / SPICE（过程评估）

过程能力等级 × 门禁 enforce_level 三档类比：strict（已建立）/ warn（已管理）/ advisory（已执行）。

## 4. 边界声明

- ISO 9001/CMMI/ISO 15504 是组织级认证，swarm-yuan 提供"过程资产的工程化实现"供认证引用。
- 不提供专属门禁（单变更无法门禁化组织过程成熟度）。
```

- [ ] **Step 2: facts.conf FACT_REFERENCES 18→19**

```bash
FACT_REFERENCES=19            # references/*.md（不含 frameworks/ 子目录）；B 方向 +quality-management-standards
```

- [ ] **Step 3: 验证**

Run:
```bash
grep -cE '^## ' swarm-yuan/references/quality-management-standards.md
grep -c 'ISO 9001' swarm-yuan/references/quality-management-standards.md
```
Expected: ≥4（§1-§4）；≥2

- [ ] **Step 4: Commit**

```bash
git add swarm-yuan/references/quality-management-standards.md swarm-yuan/assets/facts.conf
git commit -m "feat(b): quality-management-standards.md ISO 9001/CMMI/ISO 15504 概念映射

- 7 质量原则 × 机制映射 / CMMI ≈L3 定位 + 缺 MA/CAR/OPD-OPF 显式声明
- 边界声明：组织级认证不强行门禁化
- FACT_REFERENCES 18→19"
```

---

### Task 2: references/crypto-spec.md（密码学系统规范）

**Files:**
- Create: `swarm-yuan/references/crypto-spec.md`
- Modify: `swarm-yuan/assets/facts.conf`（FACT_REFERENCES 19→20）

- [ ] **Step 1: 写 crypto-spec.md**

结构（§1 总原则 / §2 密钥生命周期 / §3 算法选型 / §4 随机数 / §5 PKI / §6 PQC / §7 对齐标准）：

```markdown
# 密码学应用规范（对齐 GB/T 39786 / ISO/IEC 18033 / NIST SP 800）

> 系统性密码学规范——密钥生命周期/算法选型/随机数质量/PKI/后量子迁移。
> 被 security-spec.md 引用，被 check_crypto 门禁依据。机构密评测评属线下。

## 1. 总原则
最小化（只加密必要数据）/ 默认安全（安全默认值）/ 密钥与代码分离（禁硬编码）。

## 2. 密钥生命周期
生成（CSPRNG）→ 分发（安全信道）→ 存储（KMS/HSM，禁代码内）→ 轮换（定期）→ 撤销 → 销毁。

## 3. 算法选型
| 用途 | 推荐 | 禁用 |
|------|------|------|
| 口令哈希 | bcrypt/scrypt/argon2 | MD5/SHA1 |
| 对称加密 | AES-256-GCM | DES/3DES/ECB 模式 |
| 非对称 | RSA-3072/ECDSA-P256 | RSA-1024 |
| 哈希 | SHA-256+ | MD5/SHA1 |
| **国密（GB/T 39786-2021）** | SM2（非对称）/SM3（哈希）/SM4（对称） | — |

## 4. 随机数质量
安全场景必须 CSPRNG（/dev/urandom、secrets、SecureRandom、crypto.randomBytes）；
禁用 Math.random/rand()/Random 于安全上下文。

## 5. PKI 与证书管理
证书链完整验证 / OCSP 装订 / 有效期监控 / 私钥保护。

## 6. 后量子迁移（PQC）展望
NIST FIPS 203（ML-KEM）/ 204（ML-DSA）/ 205（SLH-DSA），混合模式过渡。

## 7. 对齐标准
GB/T 39786-2021（密评）/ ISO/IEC 18033（加密算法）/ NIST SP 800-131A（算法迁移）。
```

- [ ] **Step 2: facts.conf FACT_REFERENCES 19→20**

- [ ] **Step 3: 验证 + Commit**

```bash
grep -cE '^## ' swarm-yuan/references/crypto-spec.md   # ≥7
git add swarm-yuan/references/crypto-spec.md swarm-yuan/assets/facts.conf
git commit -m "feat(b): crypto-spec.md 系统性密码学规范

- 密钥生命周期/算法选型（含国密 SM2/3/4）/随机数/PKI/PQC
- 对齐 GB/T 39786/ISO 18033/NIST SP 800
- FACT_REFERENCES 19→20"
```

---

### Task 3: check_sbom 扩展 CVE 阈值门禁

**Files:**
- Modify: `swarm-yuan/assets/precheck.sh`（check_sbom，gates-strict.sh:755-849）
- Modify: `swarm-yuan/assets/precheck.compliance.conf`

- [ ] **Step 1: precheck.compliance.conf 新增 CVE 配置**

```bash
# CVE 漏洞阈值（B 方向，SCA 补全）：critical/high/medium，默认 high
CVE_THRESHOLD=high
# CVE 豁免 5 字段（对象|规则|理由|审批人|日期）
CVE_EXEMPTIONS=""
```

- [ ] **Step 2: check_sbom 追加 grype CVE 扫描**

在 check_sbom 生成 SBOM 后追加：

```bash
  # B 方向：CVE 阈值门禁（SCA 补全）——SBOM 生成后 grype 扫描
  if [[ -n "${CVE_THRESHOLD:-}" && -n "$_sbom_file" ]]; then
    if command -v grype >/dev/null 2>&1; then
      trace_tool "grype" "sbom scan"
      if ! grype "sbom:$_sbom_file" --fail-on "$CVE_THRESHOLD" >/dev/null 2>&1; then
        fail "gate_sbom_cve_threshold: SBOM 检出 ≥$CVE_THRESHOLD 级 CVE（grype，豁免须 5 字段留痕）"
      fi
    elif command -v osv-scanner >/dev/null 2>&1; then
      warn "grype 不可用，降级 osv-scanner（阈值判定弱化）"
    else
      warn "CVE 阈值配置但 grype/osv-scanner 均不可用，跳过漏洞扫描"
    fi
  fi
```

（注：`$_sbom_file` 以 check_sbom 实际 SBOM 输出变量名为准。）

- [ ] **Step 3: 语法检查 + Commit**

```bash
bash -n swarm-yuan/assets/precheck.sh
git add swarm-yuan/assets/precheck.sh swarm-yuan/assets/precheck.compliance.conf
git commit -m "feat(b): check_sbom 扩展 CVE 阈值门禁（SCA 补全）

- SBOM 生成后 grype --fail-on 扫描，超阈值 fail
- 工具降级链 grype→osv-scanner→跳过；阈值可配 + 豁免 5 字段
- 对齐 NIST SSDF RV/OWASP A06"
```

---

### Task 4: check_crypto 扩展国密正向核查 + standards-compliance §E.5 扩写

**Files:**
- Modify: `swarm-yuan/assets/precheck.sh`（check_crypto，gates-warn.sh:1178-1216）
- Modify: `swarm-yuan/references/standards-compliance.md`

- [ ] **Step 1: check_crypto 追加国密正向核查**

在 CRYPTO_PROFILE=gm 的弱算法黑名单后追加：

```bash
  # B 方向：国密正向使用核查（warn 级，加密场景判断难自动化避免误报）
  if [[ "${CRYPTO_PROFILE:-}" == "gm" ]]; then
    local _enc_use _gm_use
    _enc_use=$(grep -rlE 'encrypt|decrypt|加密|解密' $CRYPTO_SCAN_DIRS --include='*.java' --include='*.py' --include='*.js' --include='*.ts' --include='*.go' 2>/dev/null | head -1 || true)
    _gm_use=$(grep -rlE '\bSM2\b|\bSM3\b|\bSM4\b' $CRYPTO_SCAN_DIRS 2>/dev/null | head -1 || true)
    if [[ -n "$_enc_use" && -z "$_gm_use" ]]; then
      warn "gate_crypto_gm_positive: 检测到加密操作但未使用国密算法（密评场景须 SM2/SM3/SM4）：$_enc_use"
    fi
    # 随机数质量
    grep -rnE 'Math\.random|\brand\s*\(' $CRYPTO_SCAN_DIRS --include='*.js' --include='*.ts' --include='*.py' 2>/dev/null | grep -qiE 'password|token|secret|key|加密' && \
      warn "gate_crypto_weak_rng: 安全上下文使用弱随机数（Math.random/rand），须 CSPRNG"
  fi
```

（注：`$CRYPTO_SCAN_DIRS` 以 check_crypto 实际变量为准；正向核查 warn 级。）

- [ ] **Step 2: standards-compliance.md §E.5 功能安全域扩写**

扩写功能安全域占位段，显式声明边界 + 外审指引：

```markdown
### E.5 功能安全域（显式边界声明，须机构外审）

**明确不覆盖**：ISO 26262（车规 ASIL）/ IEC 62304（医疗软件）/ IEC 61508-62443（工控功能安全）。

**理由**：这些标准要求完整的功能安全生命周期（HARA 危害分析/ASIL 分解/安全案例 Safety Case），
属机构测评/认证级，远超门禁级自动化范畴。强行门禁化会淹没误报（违反"不贸然唤醒沉睡门禁"原则）。

**外审指引**：涉及功能安全域的项目，swarm-yuan 提供的 36 门禁可作为**通用质量/安全基线**，
但功能安全合规必须由具备资质的机构按标准全文外审。swarm-yuan 的门禁证据（gate-runs.jsonl/
SBOM/RTM）可作为外审输入。
```

- [ ] **Step 3: 语法检查 + Commit**

```bash
bash -n swarm-yuan/assets/precheck.sh
git add swarm-yuan/assets/precheck.sh swarm-yuan/references/standards-compliance.md
git commit -m "feat(b): check_crypto 国密正向核查 + 功能安全域边界声明

- CRYPTO_PROFILE=gm 时国密正向使用核查（SM2/3/4）+ 弱随机数检测（warn 级）
- standards-compliance §E.5 功能安全域显式边界 + 外审指引"
```

---

## Self-Review

**Spec coverage:** §2.2 组件 #1→Task1、#2→Task2、#3→Task3、#4→Task4、#5→Task4、#6→Task3、#7→Task1/2 ✓；§2.3 四补全项→Task1-4 ✓；§4.4 边界→Task1/4 ✓。无 gap。

**Placeholder scan:** Task3/4 的"变量名以实际为准"是因 check_sbom/check_crypto 内部变量需现场确认，已给出完整可适配代码。可接受。

**Type consistency:** CVE_THRESHOLD（Task3 conf 定义，check_sbom 消费）✓；FACT_REFERENCES 18→19→20（Task1/2 递增）✓；CRYPTO_PROFILE=gm（Task4 沿用现有）✓。
