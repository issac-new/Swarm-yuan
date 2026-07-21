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

### 决策 13：断点续传否决令废止——draft 状态门替代一次性铁律（2026-07-21 减重 WP-H）

**问题**：决策档曾否决状态机断点续传（理由：违背零占位符铁律）。但该否决使生成流程成为 all-or-nothing——12 步管线必须一次走完，是范式"过重"的最大采用门槛；且长流程中断后只能整体重来。

**新论据**：原否决针对的是"断点续传 = 中途交付半成品"。状态门方案把"可中断"与"可交付"解耦：
1. 骨架 frontmatter `status: draft`（机器可识别），draft 期间 `--all-full`/`--compliance-suite` 被 precheck 禁用（exit 2）——半成品无法以"门禁全绿"伪装成交付物
2. `--mark-active` 以严格零占位符核验（--strict）为翻转前提——零占位符铁律从"流程纪律"升级为"状态迁移的机器准入"
3. 断点续传幂等（只补缺失文件，不覆盖已有内容），与 upgrade 路径语义清晰分离

**决策**：正式废止"断点续传违背零占位符铁律"的否决，以 draft/active 状态门替代。零占位符铁律的适用点从"流程结束"移到"draft→active 迁移"。

**联动**：WP-E 三档 profile（零占位符按档适用）+ WP-G 特征卡 P0/P1 分级（P1 可「（P1 待补）」，--mark-active 前清零）+ WP-A 合规门禁拆出（27+9）。

### 决策 14：offline-cache 治理收口（2026-07-21 减重 WP-J）

**事实核查**：git 索引内 offline-cache 实际只剩 UPSTREAM.md（8KB）——whl/tgz/zip 自 v2026.07.20 起已迁 GitHub Release 附件（install-offline-win.sh 的降级链自动下载），196MB 均为本地 ignored 内容。根 .gitignore 旧注释"已故意纳入 git 跟踪"是迁移前的表述残留，与 swarm-yuan/.gitignore 矛盾。

**决策**：
1. 根 .gitignore 矛盾注释重写（指向 Release 迁移事实与 fetch 脚本）
2. 新增 scripts/fetch-offline-cache.sh（从 Release v2026.07.20-offline 拉取，已存在跳过，失败附手工指引）
3. 无索引手术可做（索引早已只有 UPSTREAM.md）——本项为表述与工具收口，非新决策方向

### 决策 15：连贯动作理念落实——generate-skill 真生成 settings/.mcp + fail 诊断 + state-machine auto（2026-07-21）

**问题**：设计理念 1（连贯动作）3 处虚假——SKILL.md Step 9 宣称生成 settings.local.json/.mcp.json 但 generate-skill.sh 不生成；precheck fail 仅 exit 1 无诊断修复建议；state-machine guard 占位直接 pass、transition 需显式传阶段。

**决策**：
1. generate-skill.sh create + upgrade 段真生成 settings.local.json（最小权限模板）+ .mcp.json（MCP server 接入模板，默认空 mcpServers，AI 按已装运行时激活）
2. precheck.sh fail() 收集 FAIL_IDS + _fix_suggest 映射表（30+ 常见 fail id → 建议文案）+ --fix-suggest 子命令（只输出建议不 exit 1）
3. state-machine.sh guard_phase 实装产出物检查（design 查 proposal.md/SPEC_FILE、verify 查 tasks.md 全勾）+ auto 子命令（自动判下一阶段 + guard + transition，免去记阶段名）

**理由**：用户要求"连贯动作落实"。3 处虚假让"一键全流程"名不副实。修复后生成器真产出全套配置、fail 有修复建议、状态机自动流转。

**边界**：fail 修复建议只建议不自动执行（与"用户决策"原则一致）；auto 不跳过 guard（守卫仍检查产出物）；settings/.mcp 是模板带占位符由 AI 填充（配置模板允许占位符，--verify-completeness 不扫这两文件）。

### 决策 16：全链路追踪理念落实——trace-log 孤儿转真接线（2026-07-21）

**问题**：设计理念 2（全链路追踪）3 处虚假——trace-log.sh 功能完整但 precheck/state-machine/generate-skill/self-check 四脚本无一处调用（孤儿）；9 个第三方工具调用点调用前无公告、空结果时静默；探查阶段无进度提示。

**决策**：
1. precheck.sh _gate_exec 门禁级接 trace-log（每门禁 started + done/fail/warn/pass 双状态，输出 stderr 不污染 stdout/cli-ab）
2. 新增 trace_tool() 辅助函数，9 个工具调用点（gitnexus query/trace/detect_changes、graphify explain、ocr review、claude-mem search、openspec validate、gsd-tools validate health、comet guard）调用前各加一行 trace_tool
3. check_layer 空结果加 pass（修静默：gitnexus 无跨层问题时不再完全静默）
4. state-machine.sh / generate-skill.sh 各接 trace_tool（comet guard / create / upgrade / inject / verify）
5. SKILL.md Step 1 探查进度 prompt 补强（三路子代理每路启动前调 trace-log）

**理由**：用户要求"全链路追踪落实"。trace-log 设计正确却自己是孤儿是最大虚假。修复后每步调用有 `→ [节点] 调用 actor · tool（status）` 公告 + trace.jsonl 落盘。

**边界**：trace 输出 stderr（stdout 纯净不破坏 cli-ab 逐字节等价）；trace-log 落盘失败仅 warn 不阻塞主流程；探查阶段进度靠 prompt 约束 AI（无脚本强制，因探查是 AI 行为非脚本）。

### 决策 17：全局一致性收口——文档口径与实现对齐（2026-07-21）

**问题**：全局排查发现文档残留过时口径——acceptance-criteria.md 仍写 57 fixture/31 flag/六组（实际 61/36/全量 36 组）；USAGE.md "hermes-agent"（应为 agent 运行时）；README "11 步"（实际 13 节点 0~8）；README 目录树未列 settings.local.json/.mcp.json。

**决策**：
1. acceptance-criteria.md 全量更新：57→61、31→36、六组→全量 36 组、C3 补 Swarm-studio ABSENT、C4 补严格层/信息层分离、C8 补全量 36 组
2. USAGE.md 步骤表 5.5 补 settings.local.json/.mcp.json 生成；hermes-agent→agent 运行时
3. README（根 + swarm-yuan/）11 步→13 步；目录树后补"生成的目标 skill 含"清单（含 settings.local.json/.mcp.json）
4. 本决策 15/16/17 记录入 paradigm-decisions.md

**理由**：用户要求"全局排查并彻底完成"。文档口径与实现脱节会让外部观察者误以为"全是空壳"。本次把所有过时数字/术语/清单与当前实现对齐。
