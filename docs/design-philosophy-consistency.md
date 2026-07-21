# swarm-yuan 设计理念与实现一致性核对表

> 日期：2026-07-21 ｜ 单一事实源：本文表与 `swarm-yuan/scripts/self-check.sh` 的 `check_doc_consistency` 机械解析互证。
> 目的：让"目标 skill 在实际项目中可用、研发全流程 7 阶段真实可执行、11 运行时非花架子、三平台 CI 全覆盖"从宣称变成可核对的事实。

## 一、11 运行时接线分层（WP1）

| 层 | 运行时 | 真实接线方式（脚本里会执行的） | 降级载体 | self-check 可安装 | 验证 fixture |
|----|--------|------------------------------|---------|------------------|-------------|
| **深度接线（4）** | GitNexus | precheck.sh `gitnexus status`/`query`/`trace`/`detect_changes`（19 处子进程调用） | graphify → grep+madge | ✅ 源码+npm | check_layer/link-depth/impact gate-fixture |
| **深度接线（4）** | graphify | precheck.sh `graphify explain`（7 处） | grep+madge | ✅ uv/pipx | check_link-depth gate-fixture 降级路径 |
| **深度接线（4）** | claude-mem | precheck.sh `claude-mem search "project rules conventions"` | progress ledger + decisions.md | ✅ 源码(bun)+npx | check_knowledge gate-fixture |
| **深度接线（4）** | ocr | precheck.sh `ocr review --from --to --audience agent` + 降级 `ocr scan` | 5 维度手动清单 | ✅ npm i -g | review gate-fixture（mock bin/ocr） |
| **CLI 接线（3）** | OpenSpec | check_requirements `openspec validate --all --strict`（WP1.1 新增） | 自带文档检查（TBD/ID/EARS） | ✅ 源码+npm | requirements-openspec gate-fixture（mock bin/openspec） |
| **CLI 接线（3）** | comet | state-machine.sh `comet guard`（WP1.2 新增） | 自带 state-machine.sh 文件检查 | ✅ 源码+npm | state-machine guard 实测（mock bin/comet） |
| **CLI 接线（3）** | gsd-core | check_review `gsd-tools validate health`（WP1.3 新增，warn 级） | ocr + 手动清单 | ✅ 源码 build+npx | review-gsd gate-fixture（mock bin/gsd-tools） |
| **方法论引用（4）** | superpowers | 无 CLI；AI 按 subagent-orchestration.md 引用其 14 skills 模式 | 自带 subagent-orchestration.md 手动编排 | ❌ 需 `/plugin install` | 无（方法论层不接线 CLI） |
| **方法论引用（4）** | gstack | precheck.sh `if [[ -d ~/.claude/skills/gstack ]]; then echo 提示`（不执行 gstack 命令） | ocr + 手动清单 | ❌ 需 git clone + setup | 无 |
| **方法论引用（4）** | Ruflo | 无脚本调用；文档明说"不要求安装" | superpowers+claude-mem+gsd-core | ✅ npm i -g（但装上无脚本调用） | 无 |
| **方法论引用（4）** | ECC | 无 CLI；AI 按 review-methodology.md 引用其 hook profile 模式 | 自带 precheck + state-machine | ❌ 需 `/plugin install` | 无 |

**核对结论**：11 运行时按 4 深 + 3 CLI + 4 方法论分层，每层有自带降级载体，未装不阻塞（fail-open）。深度+CLI 层（7 个）在 precheck.sh/state-machine.sh 有真实命令调用 + fixture 验证；方法论层（4 个）诚实标注为模式引用，不假装深接。

## 二、研发全流程 7 阶段 × 门禁映射

| 阶段 | spec 章节 | workflow 节点 | 门禁函数 | 双态 fixture | 真实可执行 |
|------|----------|--------------|---------|-------------|-----------|
| 需求 | §1 背景目标 / §4 Spec Delta | ①需求理解 → ②设计 spec | check_requirements（+openspec validate） | requirements / requirements-openspec | ✅ |
| 分析（左移） | §19 测试设计 / §20 变更影响 / §21 可观测性 | ②spec ★左移 / ③plan ★左移 | check_shift_left / check_impact | shift-left / impact | ✅ |
| 设计 | §3 改造类型 / §5 详细设计 / §5.5 复用 / §14-§18 | ②-③ design+tasks | check_layer / check_stable_diff / check_link_depth / check_reuse / check_deps / check_security / check_cognition / check_domain | layer/stable-diff/link-depth/reuse/deps/security/cognition/domain | ✅ |
| 开发 | plan Task 1..N / §20 变更影响 | ④分支 → ⑤编码（subagent-driven） | check_build / check_framework（61 框架动态分发） | build / 61 framework-fixture | ✅ |
| 测试 | §11 测试策略 / §19 用例骨架 | ⑥测试验证（ocr 5 维度） | check_test / check_review（+gsd-tools health） | test / review / review-gsd | ✅ |
| 部署/发布 | §20.3 灰度 / §21.5 告警+Runbook | ⑧构建发布（★运维左移） | check_build / check_release_sign / check_sbom / check_privacy | build / release-sign / sbom / privacy | ✅ |
| 运维/合规交付 | §21 可观测性 / §22 标准合规 | ⑦合入 + ⑧发布 + ⑨完成检查 | check_compliance / check_docs_pack / check_shift_left §21 | compliance / docs-pack / shift-left | ✅ |

**核对结论**：7 阶段无空壳，每阶段有 spec 章节 + workflow 节点 + 门禁函数 + 双态 fixture。

## 三、三平台 CI 矩阵（WP2）

| 平台 | CI Job | 覆盖 | 状态 |
|------|--------|------|------|
| Linux | ubuntu-latest（verify-framework-rulesets / fixture-double-state / generator-self-gate / self-check / shellcheck / e2e / verifier） | 61 ruleset + 61 fixture + 36 gate-fixture + e2e + verifier all + shellcheck 18 脚本 | ✅ 全覆盖 |
| macOS | macos-latest（macos-bsd-compat） | bash 3.2 语法 + 61 ruleset + 61 fixture + 36 gate-fixture（BSD grep/awk 兼容） | ✅ 全覆盖 |
| Windows | windows-latest（windows-compat，WP2.1 新增） | Git Bash bash -n + 61 fixture + 36 gate-fixture + .bat 烟雾测试 | ✅ WP2.1 新增 |

**核对结论**：三平台 CI 全覆盖，Windows 不再是虚假声称。.bat WSL 路径转换 bug 已修（WP2.2）。离线包 wheel 三平台覆盖（WP2.3）。

## 四、测试覆盖矩阵（WP3）

| 测试体系 | CI Job | 覆盖 | 状态 |
|---------|--------|------|------|
| 61 framework fixture（id 级双态） | fixture-double-state + macos + windows | 61 框架 × violating/compliant/expected-fail-ids | ✅ 三平台 |
| 36 gate-fixture（全量双态） | fixture-double-state + macos + windows + verifier | 36 门禁组（WP3.3 从 6 组扩到全量） | ✅ 全量 |
| e2e（四框架注入全链路） | e2e + verifier all | Java demo mybatis/lombok/spring-batch/sharding | ✅ WP3.1 进 CI |
| verifier all（C1-C8 验收） | verifier（WP3.2 新增） | fixtures + gate-fixtures + e2e + cli-ab + metrics-assert | ✅ WP3.2 进 CI |
| shellcheck | shellcheck（WP3.4 扩展） | 18 个核心+verifier+tests 脚本 | ✅ WP3.4 扩展 |

**核对结论**：测试覆盖缺口补齐，e2e/verifier/36 gate-fixture 全进 CI。

## 五、两条设计理念落实（WP4，2026-07-21）

| 理念 | 落实点 | 机器执法 | 状态 |
|------|--------|---------|------|
| **1. 连贯动作**（一键生成 + 一键使用，无需用户指定阶段/工具） | `/swarm-yuan <项目路径>` → Step 0-10 全自动；目标 skill 用户只说"开始新需求 xxx" → 8 节点自动驱动；hooks.json 自动接线（SessionStart 状态恢复 + PreToolUse 范围门禁）；工具选择走 has_* 守卫 + 降级链（gitnexus→graphify→madge→启发式） | `--verify-completeness` 零占位符；骨架铁律禁中途停止 | ✅ 已落实（设计性例外：特征卡/spec/合入/发布等 7 处用户决策点保留确认——确认≠指定阶段/工具） |
| **2. 全链路追踪**（每步调用有信息提示，显示调用了何种工具及技能，无需用户确认） | ① stdout 公告：每 Step/节点输出 `→ [Step N/节点X] 调用 <技能/工具> · <目的>`；② 落盘：`scripts/trace-log.sh` 追加 `.swarm-yuan/trace.jsonl`（ai-process-records §2.4 第四级调用留痕）；③ 门禁执行层：每门禁 `=== 检查 ===` 横幅 + pass/warn 归因工具 + gate-runs.jsonl + SARIF；④ hooks 单行摘要（原 `--quiet` 为无效参数已移除，改为一行 ✓/✗ 提示）；⑤ **第三方工具调用点全接线（WP-D1/D3）**：`trace_tool()` 桥（precheck.sh + state-machine.sh）——gitnexus query/trace/detect_changes、graphify explain、claude-mem search、ocr review/scan、openspec validate、gsd-tools validate health、comet guard 共 7 工具 10 个调用点逐一接入，输出走 **stderr**（cli-ab stdout 逐字节契约不破），守卫探测（has_*/indexed）不 trace 防噪音 | `--verify-completeness` 校验 workflow.md 每节点含「调用追踪」要素（template-spec §2 第 ⑨ 要素），缺则列 file:line + exit 1 | ✅ 已落实 |

**核对结论**：理念 1 此前已落实；理念 2 的缺口（AI 行为层无调用公告铁律、无机器校验、hooks 静默）由 WP4 补齐——workflow 10 要素（新增第 ⑨ 调用追踪）+ trace-log.sh 双通道 + verify-completeness 机器执法 + hooks 单行摘要。

## 六、自检命令

```bash
# 文档一致性（数字口径机械核对，含根 CLAUDE.md）
bash swarm-yuan/scripts/self-check.sh --check-only

# 全量验收（61 fixture id 级 + 36 gate-fixture + e2e + cli-ab + metrics-assert）
bash verifier/v1/run-verifier.sh all

# 理念 2 机器执法（workflow 调用追踪要素 + 零占位符）
bash swarm-yuan/scripts/generate-skill.sh --verify-completeness <skill_dir>

# trace-log 双通道实测（stdout 公告 + trace.jsonl 落盘）
bash swarm-yuan/assets/trace-log.sh --node "Step 4" --actor graphify --tool "graphify explain"

# 三平台 CI（推到 GitHub 后自动跑 ubuntu + macos + windows）
git push
```
