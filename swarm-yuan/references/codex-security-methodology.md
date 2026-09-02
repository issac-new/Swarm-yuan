> **何时读我**：安全扫描门禁接线与威胁建模时。codex-security——约束推理扫描/source-sink/威胁模型五要素。

# codex-security 安全扫描方法论（OpenAI Codex Security CLI 接线）

> 来源：[openai/codex-security](https://github.com/openai/codex-security) `@openai/codex-security` v0.1.11（Apache-2.0，**完全开源免费**），CLI 接线层第 4 对象（与 OpenSpec/comet/gsd-core 同档）。
> **v0.1.11 要点**：① 嵌套 Git 仓库 scan snapshots（#116）——含 submodule 的项目可整仓扫描，remediation checkout 保留嵌套仓库；② protected multi-architecture 容器镜像（x64/arm64）+ AppArmor 受限主机自动降级到 legacy sandbox——Docker 沙箱在受限 Ubuntu/容器环境不再硬崩。这两项让 codex-security 在真实项目（常含 submodule）+ 受限 CI 环境更可靠。
> 纪律：CLI 接线层允许真实命令调用（`npx @openai/codex-security scan`），不重新实现、不复制源码（上游 clone 在 `swarm-yuan/research/codex-security/`，仅供 AI 阅读引用，gitignored）。
> 守决策 27：吸收优先于新增门禁，不新增 `check_*`，门禁数保持 55；守决策 26：复杂度预算不增。
> 适用场景：目标项目需要**AI 驱动的语义级安全扫描**（非传统 SAST 的模式匹配）时，`--sast-deep` 门禁的 `SAST_DEEP_TOOL=codex-security` 显式调用 codex-security CLI，产出 SARIF + findings.json + coverage.json 三件套。也用于 AI 在 spec/审查节点引用本文的静态评估七元组 + 威胁模型五要素 + 攻击路径分析方法论。

---

## 一、定位：非 SAST 的 AI 约束推理扫描（与 semgrep/opengrep 正交，非降级链一环）

**关键纠偏**：codex-security **不是传统 SAST**，OpenAI 官方明确说明它不产出 SAST 报告、不依赖模式匹配 + 降级链那一套。它采用的是 **AI 驱动的约束推理 + 验证路径**——用大模型做 source→sink 数据流分析 + 攻击路径推演 + 威胁模型，而非规则引擎扫描。因此它**不进** swarm-yuan `--sast-deep` 的 `semgrep → opengrep → 内置词法` 降级链（降级链是 SAST 工具的降级，codex-security 非 SAST）。

codex-security 与 swarm-yuan 既有安全能力是**正交互补**关系：

| 维度 | swarm-yuan 既有（semgrep/opengrep/内置 = 传统 SAST） | codex-security（AI 约束推理，非 SAST） |
|------|------------------------------------------|---------------------|
| 设计哲学 | 规则匹配 + AST 模式 + 降级链 | AI 约束推理 + 攻击路径验证（官方明确「不包含 SAST 报告」） |
| 扫描层 | AST/词法层（规则匹配） | **语义层**（source→sink 数据流 + 攻击路径推演 + 威胁模型） |
| 输出 | JSON（severity + 规则 ID） | **三件套**：scan-manifest.json + findings.json + coverage.json + SARIF |
| 威胁模型 | 无（门禁不建威胁模型） | **repository-scoped 威胁模型**（assets/trust boundaries/attacker inputs/invariants） |
| 误报控制 | 豁免登记（5 字段） | **validate 阶段 + attack-path-analysis 阶段双重去误报**（counterevidence 必查） |
| 修复建议 | 无 | **patch 命令**（bundled fix-finding skill 产出修复补丁） |
| 扫描模式 | 全量/目录 | **standard/deep/diff/working-tree 四模式** + bulk-scan 多仓库 |
| 知识库 | 无 | `--knowledge-base` 注入架构文档/威胁模型/安全策略 |

**接线形态**：codex-security 是 `--sast-deep` 门禁的**可选独立载体**（`SAST_DEEP_TOOL=codex-security` 显式调用），**不参与** `auto` 降级链——`auto` 时降级链不变（semgrep→opengrep→builtin），codex-security 只在用户显式选择时启用。两者可并行使用（SAST 找模式命中 + codex-security 找语义漏洞）。

### 开源与许可（纠偏：非付费门槛）

- **完全开源**：Apache-2.0 许可证，代码公开，任何人可 clone/阅读/修改/分发。
- **Trusted Access 非付费门槛**：README 原文是 `recommend`（推荐）非 `require`（必须）。Trusted Access 是 OpenAI 面向安全研究人员的**身份审核计划**（vetting），不是付费订阅层。有用户反馈完成验证后「API/Codex 模型中似乎什么也没解锁」。
- **真正的成本**：底层 OpenAI API 调用按 token 计费（`--max-cost USD` 可设上限），与任何调用 OpenAI API 的工具一样，非 codex-security 独有限制。

---

## 二、CLI 接线方式（门禁内显式调用，非降级链一环）

`check_sast_deep` 门禁在 `SAST_DEEP_TOOL=codex-security` 时的调用方式（显式选择，不参与 `auto` 降级链）：

```bash
# 前置：npm install @openai/codex-security + npx @openai/codex-security login（或设 OPENAI_API_KEY）
# 扫描（AI 约束推理，非 SAST 模式匹配）：
npx @openai/codex-security scan "${SECURITY_SCAN_DIRS[@]}" \
 --output-dir "$SCAN_ROOT/results" \
 --json \
 --fail-on-severity "$SEVERITY" \
 --model gpt-5.6-sol --effort high
# 导出 SARIF：
npx @openai/codex-security export "$SCAN_ROOT/results" --export-format sarif --output "$SCAN_ROOT/results.sarif"
```

**接线形态（非降级链）**：
```
SAST_DEEP_TOOL=auto（默认）→ SAST 降级链：semgrep → opengrep → 内置词法
SAST_DEEP_TOOL=codex-security → 显式选 codex-security（AI 约束推理，非 SAST；失败时降级回 SAST 链）
```

codex-security 不进 `auto` 降级链——它不是 SAST 工具，没有"装了就用"的降级关系。用户需显式选择 `SAST_DEEP_TOOL=codex-security` 才启用。两者可并行（SAST 找模式命中 + codex-security 找语义漏洞）。

**关键约束**：
- codex-security 需 **Node.js 22.13+ / 24.x / 26.x** + **Python 3.10+** + **OpenAI API Key 或 ChatGPT 登录**——比 semgrep 重得多，且按 API token 计费（`--max-cost USD` 可设上限），故不作为默认载体，只在显式配置时启用。
- **开源免费 + API 计费**：工具本身 Apache-2.0 完全开源免费；Trusted Access 是推荐的身份审核非付费门槛；真正成本是 OpenAI API 调用按量计费。
- `--fail-on-severity` 映射：`SAST_DEEP_SEVERITY=error` → `--fail-on-severity high`；`warning` → `--fail-on-severity medium`。
- 扫描结果存 `SCAN_ROOT/results`（仓库外，`mktemp -d` 创建），**不污染工作区**。
- SARIF 输出可被 swarm-yuan 既有 `to-sarif.sh` 管线消费，或直接上传 GitHub Code Scanning。

---

## 三、静态评估七元组（AI 引用核心方法论）

codex-security 的 `references/static-finding-assessment.md` 定义了静态评估的最小有用元组，swarm-yuan AI 在 `--security` / `--sast-deep` / `--authz` 门禁的误报复核节点引用：

| 元组字段 | 含义 | swarm-yuan 既有触点 |
|---------|------|---------------------|
| **source** | 攻击者可控输入 / 外部触发 / 可信操作员输入 | `--security` 门禁的 OWASP Top 10 注入源 |
| **control** | 相关守卫 / 验证器 / 消毒器 / 鉴权检查 / 配置门 | `--authz` 门禁的 CWE-862/863/639 授权检查 |
| **sink** | 危险操作 / 易受攻击依赖 / 破损控制 / 影响点 | `--sast-deep` 内置词法的 eval/exec/Runtime.exec 检出点 |
| **reachable path** | 在给定前置条件下连接 source/control/sink 的代码/配置路径 | `--layer` 门禁的 DDD 分层边界 + 调用链 |
| **boundary** | 产品表面 + 信任边界（使路径具有安全相关性） | 特征卡第 10 项环境资源 + `--service` 微服务边界 |
| **counterevidence** | 削弱/击败/限定声明的静态事实 | `--reuse` 门禁的既有稳定单元复用（可能已含守卫） |
| **proof gaps** | 阻止更强结论的缺失事实 | `--consistency` 人工核对项（勾稽无法自动证伪的留人工） |

**铁律**（codex-security 原文转译）：不要把依赖存在性、字符串匹配、部分调用链当作完整评估。有用的静态评估既说明**找到了什么**，也说明**什么仍未证实**。

---

## 四、威胁模型五要素（repository-scoped）

codex-security 的 `skills/threat-model` 定义了仓库级威胁模型的最小五要素，swarm-yuan AI 在 spec §19 测试设计 + §20 变更影响节点引用：

| 要素 | 含义 | swarm-yuan 既有触点 |
|------|------|---------------------|
| **assets** | 哪些资产或权限重要 | 特征卡第 7 项安全规则（脱敏/密钥/白名单） |
| **trust boundaries** | 信任边界在哪 | 特征卡第 10 项环境资源（运行时/DB/缓存/MQ 边界） |
| **attacker inputs** | 哪些输入是攻击者可控的 | `--security` 门禁的注入源扫描 |
| **invariants** | 代码必须保持什么不变式 | 特征卡第 12 项数据规范（schema/勾稽） |
| **failure modes** | 仓库级最该关心的失效模式 | `--domain` 门禁的领域知识违规（密码明文/SQL 拼接） |

**与 `--shift-left` 门禁的关系**：codex-security 的威胁模型是**仓库级**（不为特定 diff 偏移），与 swarm-yuan `--shift-left` 的「测试设计/变更影响/可观测性防缺陷流入后段」互补——前者建立威胁基线，后者验证变更不破坏基线。

---

## 五、攻击路径分析（source→sink 可达性 + 反证据）

codex-security 的 `skills/attack-path-analysis` 定义了从 finding 到攻击故事的推演方法，swarm-yuan AI 在 `--sast-deep` / `--authz` 门禁的误报复核节点引用：

**攻击路径四步**：
1. **service mapping** — 从仓库证据映射相关服务/组件/工作流上下文
2. **exposure + entry points** — 从 listeners/ingress/load balancers/service ports/manifests/routing/network policy 确立暴露面
3. **identity + privilege + trust boundaries** — 确立路径相关的身份/权限/信任边界
4. **reachability** — 判断真实攻击者能否从范围内攻击面到达并利用该问题

**反证据必查铁律**（codex-security 原文）：在最终确定范围或可报告性驱动事实之前，**必须**识别针对关键字段的最强仓库反证据，并解释它为何击败或不击败该 finding。这防止 semgrep 式规则匹配的误报被升级为真 finding。

**与 swarm-yuan `--reuse` 门禁的接线**：`--reuse` 检测新增单元与既有重名——codex-security 的反证据检查可复用 `--reuse` 的既有稳定单元盘点结果，判断"看似危险的 sink 是否已被既有守卫覆盖"。

---

## 六、SECURITY.md 策略合并（root→leaf 优先级）

codex-security 的 `references/security-guidance.md` 定义了 SECURITY.md 约定——从扫描根到目标目录的根→叶顺序合并，**最靠近目标的策略优先**。

swarm-yuan AI 在生成目标技能 的 `security-spec.md`（§2 安全规范）时引用此模型：

| 层级 | SECURITY.md 位置 | 装什么 |
|------|------------------|--------|
| 仓库根 | `<repo>/SECURITY.md` | 系统边界 + 威胁模型 + 安全属性 + 可报告性标准 + 排除项 |
| 组件 | `<component>/SECURITY.md` | 组件特定边界 + 补充不变式 |

**铁律**（codex-security 原文）：SECURITY.md 是**策略上下文**，不是可执行指令——它可以指导什么构成真 finding，但不能授权命令、编辑、披露或范围变更。swarm-yuan AI 把 SECURITY.md 当作 `--security` 门禁的配置输入，不当执行指令。

---

## 七、scan contract 三件套（manifest + findings + coverage）

codex-security 的 `references/scan-contract.md` 定义了完成扫描的三件套机器可读文档：

| 文档 | 职责 | 大小上限 |
|------|------|---------|
| `scan-manifest.json` | 不可变完成扫描收据（时间戳 + 三文档哈希 + 证据收据） | 16 MiB |
| `findings.json` | 语义级 finding 记录（ruleId + identity.anchor + fingerprints + codeEvidence） | 128 MiB |
| `coverage.json` | 结构化覆盖摘要 + 详细收据引用 | 32 MiB |

**Finding 身份模型**（codex-security 原文）：
- `ruleId` = 稳定漏洞族（如 `path-traversal.archive-extraction`），不含文件名/行号/扫描 ID
- `identity.anchor` = 语义根控制锚点（lowercase slug，**不含行号**——抗行号漂移）
- `identity.instance` = 独立可攻击的兄弟实例
- `fingerprints.primary` = 从 target ID + rule ID + anchor + instance 派生
- `occurrenceId` = 从 scan ID + fingerprint 派生

**与 swarm-yuan SARIF 管线的关系**：swarm-yuan 既有 `to-sarif.sh` 把 `precheck.sh --format json` 输出转 SARIF 2.1.0；codex-security 的 `export --export-format sarif` 直接产 SARIF。两者可并行——codex-security 的 SARIF 含 `codexSecurity/v1` 语义指纹 + `primaryLocationLineHash`，比 swarm-yuan 门禁级 SARIF 更丰富；GitHub Code Scanning 可同时消费两者。

---

## 八、14 个 bundled skills（按需引用）

codex-security 的 `_bundled_plugin/skills/` 含 14 个 skill，swarm-yuan AI 按 workflow 节点引用其模式（不调 CLI 的节点用方法论引用）：

| skill | 何时引用 | swarm-yuan 触点 |
|-------|---------|----------------|
| `threat-model` | spec §19 测试设计 | 威胁模型五要素（本文 §四） |
| `security-scan` | `--sast-deep` 全量扫描 | CLI 接线（本文 §二） |
| `deep-security-scan` | `--sast-deep --mode deep` 多轮发现 | AI 约束推理深度模式（非 SAST 补充，正交） |
| `security-diff-scan` | `--scope` + `--sast-deep` diff 扫描 | `--scope` 门禁的 git diff 触碰只读 |
| `finding-discovery` | `--sast-deep` 候选发现 | 静态评估七元组（本文 §三） |
| `validation` | `--sast-deep` 误报去伪 | counterevidence 必查（本文 §五） |
| `attack-path-analysis` | `--sast-deep` 攻击路径 | source→sink 可达性（本文 §五） |
| `triage-finding` | `--sast-deep` 分诊 | severity 校准 |
| `fix-finding` | `--sast-deep` 修复建议 | `patch` 命令 |
| `vulnerability-writeup` | `--sast-deep` 漏洞报告 | findings.json codeEvidence |
| `track-findings` | `--sast-deep` 跟踪 | scan history + workbench |
| `propose-security-hardening` | spec §20 变更影响 | 加固建议 |
| `define-security-policy` | 生成目标技能 的 security-spec.md | SECURITY.md 策略合并（本文 §六） |
| `config-preflight` | `--sast-deep` 前置检查 | `--doctor` 自检 |

---

## 九、Docker 沙箱模式（CI 批量扫描参考）

codex-security 的 `Dockerfile` + `compose.yaml` + `codex-security-seccomp.json` 提供了 CI 批量扫描的沙箱范式，swarm-yuan AI 在生成目标技能 的 CI 配置时引用：

| 沙箱层 | codex-security 实现 | swarm-yuan 引用价值 |
|--------|---------------------|---------------------|
| 用户隔离 | `useradd uid=10001` + `USER 10001:10001` | CI runner 非 root |
| 能力裁剪 | `cap_drop: ALL` + `no-new-privileges:true` | 最小权限原则 |
| seccomp | `codex-security-seccomp.json`（白名单 syscall） | 系统调用级隔离 |
| 卷挂载 | input read_only / output / state 三卷分离 | 扫描输入与产物隔离 |
| 凭据 | `CODEX_API_KEY` 环境变量传入，不持久化 | API key 不入仓库 |

**与 swarm-yuan `--sbom` / `--release-sign` 门禁的关系**：codex-security 的 Docker 沙箱是 CI 批量扫描的参考实现；swarm-yuan 的 `--sbom` 门禁做 SBOM 生成 + 许可证扫描，`--release-sign` 做发布签名——三者正交，可组合使用。

---

## 十、与 swarm-yuan 既有触点的接线声明

| codex-security 概念 | swarm-yuan 既有触点 | 接线方式 |
|---------------------|---------------------|---------|
| CLI scan 命令 | `check_sast_deep` 门禁（gates-warn.sh） | `SAST_DEEP_TOOL=codex-security` 时显式调用（非降级链一环，codex-security 非 SAST；失败时降级回 SAST 链 semgrep→opengrep→builtin） |
| 静态评估七元组 | `--security` / `--sast-deep` / `--authz` 门禁的误报复核 | AI 引用本文 §三 做七元组核对 |
| 威胁模型五要素 | spec §19 测试设计 + `--shift-left` | AI 引用本文 §四 建仓库级威胁模型 |
| 攻击路径分析 | `--reuse` 门禁的既有稳定单元盘点 | 复用 `--reuse` 结果做反证据检查 |
| SECURITY.md 策略合并 | 目标技能 的 security-spec.md（§2） | AI 引用本文 §六 的 root→leaf 合并 |
| scan contract 三件套 | `to-sarif.sh` SARIF 管线 | codex-security SARIF 与门禁级 SARIF 并行消费 |
| 14 bundled skills | swarm-yuan 12 步生成流程（Step 1-12） | AI 按 workflow 节点引用对应 skill 模式（本文 §八） |
| Docker 沙箱 | `--sbom` / `--release-sign` 门禁的 CI 配置 | AI 引用本文 §九 做目标技能 CI 沙箱设计 |

---

## 十一、不引用的部分（守纪律声明）

以下 codex-security 能力**不引用**，守 CLI 接线层「不重新实现、不复制源码」铁律：

- `_bundled_plugin/scripts/` 的 Python 脚本实现（resolve_security_md.py / finalize_scan_contract.py 等）——只引用模式，不复制脚本
- `_bundled_plugin/skills/*/` 的 skill 源码——只引用 skill 的方法论模式（本文 §八），不注册为 swarm-yuan skill
- `src/` 的 TypeScript SDK 实现（api.ts / runtime.ts / cli.ts 等 66k+ 行）——CLI 接线层只调 `npx @openai/codex-security` 命令，不重新实现 SDK
- `docker/` 的 seccomp profile + entrypoint.sh——只引用沙箱范式（本文 §九），不复制 Docker 配置
- codex-security 的 MCP server（`.mcp.json`）——swarm-yuan 已有 MCP 治理（`references/mcp-governance.md`），不重复注册 codex-security MCP

---

## 十二、版本与来源

- 来源：[openai/codex-security](https://github.com/openai/codex-security) `@openai/codex-security` v0.1.4（Apache-2.0）
- 许可证：Apache License 2.0
- 上游 clone 位置：`swarm-yuan/research/codex-security/`（本地参考，gitignored，不入 git）
- 吸收决策：决策 27（运行时升级整合纪律——吸收优先于新增门禁）+ 决策 26（复杂度负向预算，门禁数保持 55）
- 自检断言：G15 `check_codex_security_cli_wiring`（`self-check.sh`，warn-only，守 CLI 接线 + facts.conf 口径）
- 口径同步：`facts.conf` `FACT_RUNTIMES=13` / `FACT_RUNTIMES_CLI=4` / `FACT_REFERENCES=34`
