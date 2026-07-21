# swarm-yuan 范式决策记录（Paradigm Decisions）

> 日期：2026-07-20 ｜ 分支：`chore/leftover-suggestions`
> 记录 7 项遗留建议的处置决策与理由，供后续版本维护参考，避免重复调研。

## 处置总览

| # | 建议 | 决策 | commit |
|---|------|------|--------|
| 1 | `_resolve_path` 左结合 bug | ✅ 修 | `d31ca48` |
| 2 | GNU grep -E 下 `\|` 字面 | ❌ 不修（保留原始行为） | — |
| 3 | 测试覆盖扩展（26 门禁 fixture + CI） | 🟡 部分（CI 骨架做，26 fixture 留长期） | `74bb244` |
| 4 | offline-cache 迁移 Release | ✅ 做（不做 filter-repo 瘦身） | `1c412f2` + `2e7b...` |
| 5 | 片段内既存小瑕疵 | 🟡 部分（dubbo/seata/vue 修，sentinel 不修） | `f893f73` |
| 6 | 生成器增强（SKIP_BAT） | ✅ 做 | `2f37607` |
| 7 | 本决策文档 | ✅ 做 | 本 commit |

## 逐项决策理由

### 建议 1：`_resolve_path` 左结合 bug —— ✅ 修

**问题**：`cd "$dir" && pwd -P || cd "$dir" && pwd` 在 bash 左结合下解析为 `((cd && pwd -P) || cd) && pwd`，正常路径执行两次 pwd 返回两行值，`-f "$cand"` 永远 false，`check_layer §3/§6`、`check_contract §2` 沉睡。

**修复**：方案 C 直接 `cd && pwd -P`（POSIX -P 三平台兼容），失败走原回退。

**苏醒后发现的第二个 bug**：修复 _resolve_path 后 `check_layer §3` 苏醒，立即暴露 §1 的 glob 解析 bug——`base=${g%%/\**}` 最长匹配把 `overlay/custom/client/*/components/**` 误截成 `overlay/custom/client`，find 扫整个 client 目录，把 `__tests__/adapters/composables` 全归入 component 层，§3 误报 249 个假违规。改 `base=${g%/\**}` 最短匹配 + compgen -d 展开 glob。修复后 ncwk-dev `--layer` 从 249 假违规降到 0。

**教训**：沉睡门禁修复后会暴露下游 bug，需用真实项目样本验证苏醒后行为。

### 建议 2：GNU grep -E 下 `\|` 字面 —— ❌ 不修

**问题**：`ROLLBACK_KEYWORDS` 等 5 个变量用 `\|` 在 `grep -E` 下是字面 `|`，部分匹配永不命中。

**决策**：保留原始行为。修复会改变门禁判定（让沉睡匹配苏醒），与建议 1 同性质但影响面更大（5 个变量 × 多处 grep），且无样本可预测苏醒后行为。

**后续**：留独立版本决策，若要修需逐变量评估苏醒影响 + 补 fixture。

### 建议 3：测试覆盖扩展 —— 🟡 部分做

**做了**：`.github/workflows/ci.yml` CI 骨架 4 个 Job（57 verify + 57 fixture + self-check + shellcheck）。触发：push/PR 到 main。

**未做**：26 个非框架门禁（`--scope/--sensitive/--layer` 等）的 fixture。工作量大（每个门禁要造 violating+compliant 双态），留长期扩展，按同范式补齐。

**理由**：CI 骨架能防回归是高 ROI；26 门禁 fixture 是长期工程。

### 建议 4：offline-cache 迁移 Release —— ✅ 做（部分）

**做了**：
1. 打包 `swarm-yuan-offline-cache.zip`（44MB，含 graphify-wheels + npm + gstack + superpowers）
2. 上传到 GitHub Release `v2026.07.20-offline`（https://github.com/issac-new/Swarm-yuan/releases/tag/v2026.07.20-offline）
3. `install-offline-win.sh` 开头加降级链：本地 cache 不存在 → curl 从 Release 下载 → 降级在线安装
4. `.gitignore` 忽略 `*.whl/*.tgz/gstack/superpowers/`；`git rm --cached` 停止跟踪 37 文件（本地保留）

**未做**：`git filter-repo` 历史瘦身（改写历史 + force push 风险高，留独立决策）。历史 blob 32MB 保留在 .git，但今后不再增长。

**与 memory 全局规则关系**：不冲突。"仅 arm64.dmg + x64.zip" 针对 SwarmStudio 桌面应用；swarm-yuan 是 skill 仓库，现有 8 个 Release 全为 .zip，本附件延续 .zip 惯例（与 `v2026.07.12-offline` 的 59MB zip 先例一致）。

### 建议 5：片段内既存小瑕疵 —— 🟡 部分修

**修了**：
- dubbo.sh:25 / seata.sh:27 删 `|pom.xml`（被 `*.xml` 遮蔽，死分支，机械等价）
- vue.sh 10 处消息前缀 `vue:` → `fw_vue_<id>:`（与 vue.md §4 命名规范一致，退出码等价）

**未修**：sentinel.sh 内联 grep。A/B 类收益小（19 处单文件 if grep -qE 强改收益小），C 类 5 处 `-qiE` 不等价（`_fw_grep_count` 不支持 `-i`），D 类 4 处需要文件列表/行号/匹配内容（`_fw_grep_count` 只给计数无法替代）。整体非必要。

### 建议 6：生成器增强 —— ✅ 做

**做了**：`generate-skill.sh` 的 `copy_universal_templates` 加 `SKIP_BAT` 环境变量，设 1 跳过 .bat 复制（macOS/Linux 用户无需 .bat，让 skill 目录更干净）。默认 0 保持兼容（仍复制 7 个 .bat）。

**未做**：snippets.md / mcp-tools.md 是静态参考文档（非模板），create 模式仍复制，upgrade 模式若用户已修改则保留（现状已如此，无需改）。

### 建议 7：本决策文档 —— ✅ 做

记录上述 6 项决策，供后续版本维护参考。

## 不做的事（汇总）

- 建议 2（grep `\|` 字面）：保留原始行为，留独立版本决策
- 建议 3 的 26 门禁 fixture：工作量大，留长期扩展
- 建议 4 的 `git filter-repo` 历史瘦身：force push 风险高，留独立决策
- 建议 5 的 sentinel 内联 grep：收益小/有风险

## 重构报告（2026-07-20）评估的 8 条建议处置

外部重构报告提出 8 条建议，评估后处置如下：

| # | 建议 | 决策 | 理由 |
|---|------|------|------|
| 1 | precheck.sh 拆分为模块化（precheck/lib/gates/） | ❌ 不做 | 范式核心约束：单文件可移植（目标 skill 只需 cp 一个 precheck.sh）。拆分会破坏 install.sh 的"复制即用"设计 |
| 2 | 分层配置 schema + local | ❌ 不做 | 已用 `_default_conf()` + `${VAR+x}` 兜底解决 set -u 崩溃；schema 文件增加复杂度但收益有限 |
| 3 | Shell 可移植性（install.sh 加严格模式） | ✅ 部分做 | install.sh 已有 `set -euo pipefail`（报告不属实）；已加 `--version` + bash 版本校验 |
| 4 | 框架片段 META 头标准化 | 🟡 标注 | 需改 57 片段，工作量大。当前注释约定 + verify-framework-ruleset.sh 已兜底四要素核验 |
| 5 | bats-core 测试框架 | 🟡 标注 | 引入 bats-core 是大工程。已做 CI 骨架（ci.yml 4 Job）+ self-check 文档一致性检查这种轻量项 |
| 6 | 文档一致性检查 | ✅ 做 | self-check.sh 加 `check_doc_consistency`（片段数/门禁数/conf 变量数/references 数）；已发现并修复 SKILL.md "45 变量"→"146 变量"漂移 |
| 7 | 降级策略可观测性 | 🟡 标注 | 改降级函数是大重构（涉及多个 check_* 门禁），先标注，后续版本评估 |
| 8 | 状态机持久化（断点续传） | ❌ 不做 | SKILL.md 明确"不允许中途停在骨架阶段"是设计哲学，断点续传违背零占位符铁律 |

## 风险与缓解

- **建议 1 苏醒 check_layer §3**：已用 ncwk-dev 实证（249 假违规 → 0），且修复了连带暴露的 glob 解析 bug
- **建议 4 Release 迁移**：不删历史 blob（只停止跟踪），install-offline-win.sh 加本地 cache 优先逻辑保证已有 cache 不受影响
- **建议 6 SKIP_BAT**：默认 0 保持兼容，只影响显式设 1 的用户
- **重构报告建议 1/2/8 不做**：保护范式核心设计（单文件可移植 / 已有兜底 / 零占位符铁律）

---

## 2026-07-21 设计理念落地一致性整改决策

> 触发：用户要求"整理项目设计理念，确保落地实现与设计一致，目标 skill 要能在实际项目中使用，运行时要真实使用不能是花架子，三平台自测回归集成测试"。
> 三路并行探查（运行时接线 / 全流程覆盖 / 跨平台兼容）后，3 项决策。

### 决策 9：11 运行时半接线→真接线（OpenSpec/comet/gsd-core）—— ✅ 做

**问题**：探查发现 11 运行时里 4 个深度接线（GitNexus/graphify/claude-mem/ocr，precheck.sh 真实命令调用）、3 个半接线（OpenSpec/comet/gsd-core，self-check 能装但 precheck/hooks 不调用，靠 AI 自主用 slash）、4 个纯文档引用（superpowers/gstack/ECC/Ruflo）。与"整合 11 运行时"宣称有落差。

**决策**：把 3 个半接线提升为 CLI 真接线——OpenSpec 接进 check_requirements（`openspec validate --all --strict`）、comet 接进 state-machine guard_phase（`comet guard`）、gsd-core 接进 check_review（`gsd-tools validate health`，warn 级）。全部带 `has_*` 守卫 + 降级到自带载体，未装不阻塞。4 个纯文档引用保持方法论引用层，诚实标注不假装深接。

**理由**：用户明确选"提升半接线为真接线"。3 个运行时都有真实 CLI（本机实测 comet/openspec/gsd-tools 子命令），接线后目标 skill 在装了这些运行时的项目里能真实调用其能力，不再是花架子。降级设计保护未装场景。

**fixture**：requirements-openspec（mock bin/openspec）、review-gsd（mock bin/gsd-tools）、state-machine comet guard 实测（mock bin/comet）。36 gate-fixture 全量验证无回归。

### 决策 10：Windows 平台真实化（CI + .bat + 离线包）—— ✅ 做

**问题**：Windows 是虚假声称——CI 无 windows-latest、.bat 包装器从未测试、离线包 wheel 全是 macosx arm64 却叫 `-win`、.bat 的 WSL 路径转换有 bug（WSL 用 `/mnt/c/` 但 .bat 用 `/c/`）。

**决策**：
1. CI 加 windows-latest Job（bash -n + 61 fixture + 36 gate-fixture + .bat 烟雾测试）
2. 修 8 个 .bat 的 WSL 路径转换（`echo !BASH_CMD! | findstr /i "wsl"` 判断，WSL 用 `/mnt/c/`，Git Bash 用 `/c/`）
3. build-offline-win.sh 加多平台 wheel 下载（`pip3 download --platform macosx_11_0_arm64/manylinux2014_x86_64/win_amd64 --only-binary=:all:`）
4. UPSTREAM.md 补离线包平台覆盖说明

**理由**：用户明确选"补 Windows CI + 修离线包"。这是最实的虚假声称，必须让"三平台"名副其实。.bat WSL 路径 bug 是 bash 3.2 全角字符 bug 同类（平台相关沉睡），CI 实跑才能现形。

**风险**：Windows CI 可能暴露既有 bash 兼容问题——缓解：windows Job 初期 bash -n + fixture 双态 + .bat 烟雾，发现问题逐个修；不追求一次全绿，先让问题现形。

### 决策 11：测试覆盖补齐（e2e + verifier + 36 gate-fixture 进 CI）—— ✅ 做

**问题**：CI 不跑 e2e、不跑 verifier、36 gate-fixture 只跑 6 组、shellcheck 只查 6 个脚本。验收体系（C1-C8）形同虚设——CI 不执行验收器。

**决策**：
1. CI 加 e2e Job（四框架注入全链路）
2. CI 加 verifier all Job（C1-C8 全量：fixtures + gate-fixtures + e2e + cli-ab + metrics-assert，timeout 15min）
3. run-verifier.sh 的 gate_fixtures 从硬编码 6 组改为全量遍历 36 组；CI 的 fixture-double-state Job 同步改全量
4. shellcheck 覆盖从 6 个脚本扩展到 18 个（含 verifier/v1/* + tests/* + state-machine.sh + offline 脚本）

**理由**：用户明确选"全补"。验收体系不进 CI 等于没有验收——本次让 C1-C8 真正生效。36 gate-fixture 全量覆盖所有门禁组（含 WP1 新增的 openspec/gsd fixture）。

**教训**：验收体系（verifier/）和 CI 长期脱节是组织缺陷——verifier 是 P1 重构时建的验收器，但只手动跑过（runs/ 留 7 个日志），从未进 CI。本次补齐后，任何门禁语义变更都会被 verifier all 的 cli-ab 逐字节等价断言抓住。

### 决策 12：check_cognition 诚实化（不实装 fail 阈值）—— ✅ 做（2026-07-21 减重 WP-B）

**问题**：check_cognition 被 2026-07-20 审计自认"装饰性叙事"（0 个 fail() 调用、裸 `echo "⚠"` 不计 WARN_COUNT 不受 SILENT 控制、COGNITION_MAP 是死变量），作为 36 门禁之一账面虚增执法强度。

**决策**：不实装 fail 阈值（维持"刻意不重设计"的既有决策），做三点诚实化：
1. 函数入口明示性质：「认知体检报告（warn-only，永不 fail，不参与门禁否决）」
2. 裸 `echo "    ⚠"` 统一为 `warn()`（计 WARN_COUNT、受 SILENT 控制；④映射/①概念/②结构/第二层共 5 处）
3. 死变量 COGNITION_MAP 接入：_default_conf 补声明，④映射段配置且文件存在时纳入检查输入（不改变 /3 计分口径）

**理由**：审计已判定其实质是"只读体检报告"。诚实化 = 账面与实质一致，而非强行赋予它不具备的执法语义。装 fail 阈值的风险（计分口径未经真实项目校准，误报即淹没）大于收益。

**联动**：同日 WP-A 合规 9 门禁拆出 --all-full 为 --compliance-suite（27+9），门禁总数 36 不变、函数不变，self-check 机械一致性断言不受影响。
