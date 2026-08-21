> **角色标注（2026-08-21）**：本文件是决策史**原文档**（每个决策的完整记录）；`docs/DESIGN.md` §9.2（决策史索引） 是索引与归纳——查"为什么决定"用 DESIGN.md 索引，查"决策全文"用本文件。

# swarm-yuan 范式决策记录（Paradigm Decisions）

> 活跃决策（决策 18+）。决策 1-17（建议 1-7 + 8 条建议表 + 决策 9-17）已归档至 `docs/paradigm-decisions-archive.md`（均已落地稳定，纯历史记录；决策 12/13 除外，二者仍是当前行为权威依据，归档件保留活跃锚点）。
> **口径权威源**：`swarm-yuan/assets/facts.conf`（catchphrase 数字单一事实源，self-check 机器执法）。

> **决策 13 指针锚点**（活跃决策）：决策 13（断点续传否决令废止→draft 状态门，2026-07-21 WP-H）是当前 draft/active 状态门行为的权威依据，已随决策 1-17 归档至 `docs/paradigm-decisions-archive.md` 决策 13 段。外部引用（SKILL.md:76 / state-machine.sh / README.md:350 / plans:306）指回归档件。

### 决策 18：自适应轻重 + 质量优先偏置 + 授权无关化（2026-07-21 用户方针）

**用户方针**：①swarm-yuan 应为不同项目及任务自适应轻重，避免过轻或过重；②优先保障开发交付质量而非效率；③不考虑开源组件商业授权，不据此调整功能优先级。

**决策**：
1. **项目级自适应**：`generate-skill.sh --profile` 默认值 standard → `auto`（合规关键词 → compliance；文件数 <80 → lite；其余 standard）。偏置方向**只升不降**：探测失败/边界不确定一律按更重档处理，auto 打印判定依据供用户评估，显式 `--profile` 始终优先。
2. **任务级自适应**：spec 三级映射门禁集——简单 → `--all`；标准 → `--all-full`；完整（架构/跨服务/公共接口/数据模型/权限）→ `--all-full` + `--shift-left`，compliance 档项目追加 `--compliance-suite`。规模判断不确定按更大规模处理；compliance 档无"简单任务"豁免。
3. **授权无关化**：撤销 GitNexus 许可证驱动的降级（原"PolyForm 禁商用 → 非默认"），GitNexus/graphify 按技术能力平权选型（深度调用图 vs 广谱知识图，可并用）；self-check 移除许可证忠告。授权合规评估属使用方组织责任，许可证信息仅作事实登记保留（code-graph-tools.md 表）。upstream-vendor 决策的其余理由（体积/维护面/版本追踪）仍然有效，仅撤销授权条款作为决策因子。
4. **质量 > 效率**落实点：auto 阈值偏置（<80 才 lite）、任务门禁映射的强制升级条款（公共接口/数据模型/权限改动无"简单"档）、draft 状态门（半成品无法伪装交付）——效率类优化（trace 降级/Windows CI 降频）不触碰任何质量判定逻辑。

**与减重批（决策 12-14）的关系**：减重不是"做轻"而是"恰当的重量"——三档 profile 让重量显式可选，auto 让选择自动化且偏向重的一侧。

---

### 决策 19：catchphrase 单一事实源 facts.conf（2026-07-21 减重 WP-P1）

**问题**：36 门禁/27+9、179 变量、16 特征卡、11 运行时、32 领域、13 步流程 等口径在 8+ 文件手抄，`self-check.sh check_doc_consistency` 用 6 类正则扫描 5 份文档兜底——手动同步已不可靠，`docs/PROMO.md:215` 曾长期残留"11 步"旧口径（决策 17 已修，但同类漂移会复发）。

**决策**：
1. 新增 `swarm-yuan/assets/facts.conf`（bash 可 source 的 KEY=value），穷举所有 catchphrase 数字的权威值（FACT_GATES_TOTAL=36 / FACT_GATES_CORE=10 / FACT_GATES_ARCH=17 / FACT_GATES_COMPLIANCE=9 / FACT_GATES_STANDARD=27 / FACT_CONF_VARS=179 / FACT_FEATURE_CARDS=16 / FACT_RUNTIMES=11 / FACT_DOMAINS=32 / FACT_FLOW_STEPS=13 / FACT_FRAMEWORKS=61 / FACT_REFERENCES=18 等）
2. `self-check.sh check_doc_consistency` 开头 `source facts.conf`，先用代码真值对账 facts.conf 自身（GATES_TOTAL/CORE/ARCH/COMPLIANCE/CONF_VARS/FRAMEWORKS/REFERENCES 七项），漂移即 FAIL；再用 `${FACT_*}` 值扫描散文文档（原有 6 类正则降级为"叙事漂移检测"，逻辑不变）
3. 8 份文档（README/SKILL/USAGE/PROMO/template-spec/standards-compliance/CLAUDE/paradigm-decisions）头部加 `> 口径权威源：assets/facts.conf` 引用行，指向单一事实源
4. 修 `PROMO.md:215` 残留"11 步"→"13 步"

**理由**：catchphrase 手抄导致数字漂移是范式"过重"观感的一部分——文档与代码脱节会让外部观察者误以为"全是空壳"。单一事实源把"改一处→全局同步"自动化，self-check 机器执法先对账 facts.conf 自身（防 facts.conf 漂移），再扫描文档（防文档漂移），双向兜底。

**边界**：文档头部引用行不替换正文数字（保留可读性），仅声明权威源；facts.conf 只声明"会变的数字"（门禁数/变量数/框架数等），不声明"稳定的架构"（六段式/五层认知基底等）；facts.conf 自身漂移由 self-check 机器执法（改门禁数必须同步改 facts.conf，否则 FAIL）。

---

### 决策 20：任务类型维度实装（2026-07-21 减重 WP-P4）

**问题**：`template-spec.md:32-33`「快速入口（按任务类型）」是空占位表——只有"（任务类型 → 起始节点 → 关键参考 的表）"一行，无实际映射。分支命名有 feat/fix/refactor 但无对应门禁集差异化。spec 三级（简单/标准/完整）按变更规模分级，与任务类型正交——一个 fix 可能是"完整"级（跨服务 fix），一个 feature 可能是"简单"级（加字段）。

**决策**：
1. 新增 `swarm-yuan/assets/task-type-gates.conf`（bash 可 source），7 类任务映射（对齐用户级 AGENTS.md 分支命名）：
   - feature → `--all-full`（无豁免）
   - fix → `--all --reuse`（§14-§18 认知段可免）
   - refactor → `--all-full --reuse --stable-diff`（§14-§18 可免）
   - chore → `--all`（spec 全段可免）
   - docs → `--docs-pack`（其他门禁免）
   - test → `--all --shift-left`（§14-§18 可免；§19 必填）
   - exp → `--all`（合入前须转 feature/fix）
2. `template-spec.md` L32-33 填实任务类型映射表 + 引用 task-type-gates.conf
3. `generate-skill.sh` 生成的 `commands/spec.md` 指引改为"先判任务类型后判规模，两者取并集（更重档）"
4. `self-check.sh` 加 task-type-gates.conf 一致性断言（7 类必须齐全）

**与 spec 规模维度的关系（正交，取并集）**：
- 任务类型决定门禁子集（哪些门禁跑/豁免）
- spec 规模决定档位（--all/--all-full/--all-full+--shift-left）
- 两者取并集（更重档，质量优先，决策 18）

**边界**：
- compliance 档项目无"简单任务"豁免（决策 18）
- 公共接口/数据模型/权限改动无"简单"档（强制 ≥ --all-full）
- exp 任务合入前须转 feature/fix 正式流程（不阻塞合入是探查期特权，非交付特权）

---

### 决策 21：WP-P5 enforce_level 随 profile 调整——延后到 WP-Q1 合入后（2026-07-21）

**问题**：WP-P5 计划让 enforce_level（strict/warn/advisory）随 profile 调整——lite 档降一档（strict→warn，保护核心 strict 不降）、compliance 档升一档（advisory→warn，纯观测类保留 advisory）。

**事实核查**：enforce_level 机制（`gen-enforce-level.sh` + `gate-enforce-level.conf` + `_enforce_of`）目前仅在 `wp-q1-gate-stratification` 分支，**未合入 origin/main**。WP-P5 的实现依赖该机制存在。

**决策**：WP-P5 延后——不在本 worktree 实施 enforce_level 随 profile 调整，等 WP-Q1 合入 main 后作为独立 WP 处理。本 worktree 的自适应减重聚焦：
- 项目级（profile auto + 动态升档 WP-P6 + 技术栈反作用 WP-P9）
- 任务级（任务类型 WP-P4 + spec 三级机器执法 WP-P7）
- 阶段级（per-phase profile WP-P8）
- 结构性（catchphrase 单一事实源 WP-P1 + 冗余合并 WP-P2 + arch.conf 懒生成 WP-P3）

enforce_level 随 profile 调整是"门禁内部分级随项目档变化"的维度，与上述"项目/任务/阶段"三级自适应正交，且依赖未合入的 WP-Q1 基础设施，故延后。

**边界**：本决策不否定 WP-P5 的价值，仅记录依赖约束与延后理由。WP-Q1 合入后应优先补做。

---

### 决策 22：profile 动态升档——detect-profile-drift 只升不降（2026-07-21 减重 WP-P6）

**问题**：profile 在 `generate-skill.sh` create/upgrade 时写入 frontmatter 后固化；项目演进（<80 文件长到 >80，或新接入合规要求）不会自动升档，需手动 `--upgrade --profile`。固定 profile 与项目实际状态脱节是范式"不自适应"的典型表现。

**决策**：
1. 新增 `swarm-yuan/scripts/detect-profile-drift.sh`：重跑 `auto_detect_profile` 逻辑对比 frontmatter profile，漂移则输出建议
2. 偏置规则（质量优先，只升不降）：
   - 合规信号新增（docs/README 出现等保/密评/个保法/金融/医疗关键词）→ 强制提示升 compliance
   - 规模信号升档（文件数从 <80 涨到 ≥80）→ 提示升 standard
   - 规模信号降档（文件数从 ≥80 降到 <80）→ **不提示降 lite**（只升不降）
   - 探测失败/边界不确定 → 不提示（保守不误报）
3. 触发点：
   - precheck.sh `--all`/`--all-full` 启动时调用（轻量，stderr 输出，不阻塞主流程）
   - self-check.sh `check_profile_drift` 子检查（warn 不 fail）

**理由**：profile 固化是范式"生成时一次定死"的局限。动态升档让范式持续感知项目演进——文件数增长或新增合规要求时主动提示升级。只升不降是质量优先偏置的延续（决策 18）：降档可能放过原本被门禁覆盖的风险，升档只是增加保护。

**边界**：
- 漂移检测是 warn 不 fail（不阻塞 precheck 主流程；仅提示用户评估）
- 不自动执行升级（升级是用户决策，detect 只给建议命令）
- 合规信号优先于规模信号（合规最强，与 auto_detect_profile 一致）
- 降档不提示（避免项目临时减文件后误降档）

---

### 决策 23：spec 三级机器执法——detect-spec-scale 从 spec 推断规模（2026-07-21 减重 WP-P7）

**问题**：spec 三级（简单/标准/完整）由 AI 按 `commands/spec.md` 文本指引判定，无脚本执法——一旦判"简单"选 `--all`，中途规模变化（如编码期发现实际跨模块）不会自动升档到 `--all-full + --shift-left`。文本指引依赖 AI 自觉，无机器兜底。

**决策**：
1. 新增 `swarm-yuan/scripts/detect-spec-scale.sh`：解析 spec.md 结构化字段，推断规模等级（简单/标准/完整）
2. 推断规则（质量优先，不确定升档）：
   - 侵入点 ≤3 文件（反引号路径计数）且 无风险信号 → 简单
   - 侵入点 4-10 文件 或 含任一风险信号 → 标准
   - 侵入点 >10 文件 或 含 ≥2 风险信号 或 架构变更 → 完整
   - 风险信号：跨服务 / 公共接口 / 数据模型 / 权限 / 架构变更 / 新上下文
3. precheck.sh `--all`/`--all-full` 启动时：若 SPEC_FILE 存在，跑 detect-spec-scale，当前 MODE < 推断等级 → warn 提示升档（只升不降）
4. commands/spec.md 指引改为"填完 spec 跑 detect-spec-scale 确认规模"

**与 WP-P4 任务类型正交**：任务类型决定门禁子集（哪些门禁跑/豁免），spec 规模决定档位（--all/--all-full/--all-full+--shift-left），两者取并集（更重档，决策 18）。

**边界**：
- 规模检测是 warn 不 fail（不阻塞 precheck 主流程）
- 只升不降（spec 判"完整"但跑 `--all` → warn 提示升；spec 判"简单"但跑 `--all-full` → 不提示降）
- 无法解析侵入点保守按标准（不降简单）
- 架构变更信号强制完整档（最高优先级）

---

### 决策 24：技术栈复杂度反作用 profile——形态/框架/微服务信号升档（2026-07-21 减重 WP-P9）

**问题**：C+.0 形态判定 + C+.0.5 框架探查只影响枚举维度和 ACTIVE_FRAMEWORKS，不影响 profile 档——纯前端小项目 <80 文件判 lite，Spring 全栈大项目 >80 文件判 standard，但形态差异不进入 profile 判定。技术栈复杂度是项目"重量"的真实信号，仅按文件数判定会漏掉"小而复杂"的项目（如 50 文件的微服务多形态项目）。

**决策**：
1. `auto_detect_profile` 追加技术栈复杂度信号（在合规/规模信号之后，优先级：合规 > 技术栈复杂度 > 规模）：
   - **形态信号**：同时含 ≥3 种形态（前端 .vue/.jsx/.tsx + 后端 .py/.java/.go/.rb/.php/.kt + 异步 consumer/listener/subscriber + 微服务 services/多服务 + 桌面 electron/tauri/android/ios）→ 升 standard
   - **框架信号**：依赖文件中框架数 ≥20（package.json dependencies + pom.xml artifactId + go.mod require 粗计）→ 升 standard
   - **微服务信号**：services/ 目录存在且含 ≥2 子目录 → 升 standard
2. 偏置：技术栈复杂度信号触发时**只升不降**（与决策 18 一致）
3. auto 判定输出 reason 含技术栈信号详情（供用户评估）

**理由**：文件数是项目"体积"信号，技术栈复杂度是项目"结构"信号——两者正交。一个 50 文件的微服务多形态项目，其认知负担和门禁需求远高于 100 文件的单体前端项目。技术栈复杂度反作用 profile 让自适应从"单维（规模）"升级为"双维（规模+结构）"，更贴合项目实际重量。

**边界**：
- 技术栈复杂度信号只升不降（不因形态少而降档）
- 形态判定是粗粒度（按文件扩展名 + 目录结构），不替代 §C+.0 的精细形态判定（后者影响枚举维度）
- 框架数粗计（依赖文件行数），不替代 §C+.0.5 的框架探查（后者激活规则集）

---

### 决策 25：范式定位声明——适用/不适用场景显式化（2026-07-21 减重 WP-P10）

**问题**：无"适用规模门槛"声明，"过重"被外部观察者视为缺陷而非显式适用域。范式定位不清晰导致：(1) 小项目用户套范式后抱怨"太重"；(2) 大项目用户不知道范式能帮他们减负。

**决策**：
1. 新增 `docs/paradigm-positioning.md`：显式声明适用/不适用场景 + 轻量替代方案 + "过重"的诚实评估
2. README.md 加"适用场景"章节（链接定位文档）
3. SKILL.md 加"不适用场景"段（扩展既有"不适用"一句话）
4. CLAUDE.md 加范式定位段

**适用场景**：团队协作（≥2 人）、中大型项目（≥80 文件或 ≥3 形态）、强监管交付（合规要求）、长期维护项目（需沉淀记忆）、多技术栈混合项目（微服务/全栈）。

**不适用场景**：个人脚本/一次性原型、学习用 demo、极小改动（改 typo/调样式）、无 AI 辅助的纯人工开发。

**轻量替代**：
- 范式内：`--profile lite`（只建三目录 + 核心门禁最小集）
- 范式外：单文件 `precheck.sh` 做门禁不套生成器；传统 lint/test 工具链；AI 原生开发

**定位声明**："swarm-yuan 是重量级范式，重量是设计选择不是缺陷——通过 profile 自适应让重量显式可选。"

**理由**：范式定位显式化是"诚实化"的延续——不假装适合所有项目，明确告诉用户何时该用、何时不该用。这既是对用户的尊重（避免小项目用户踩坑），也是对范式价值的保护（避免在不适用场景被误判为"无用"）。

### 决策 30：auto_detect_profile 偏置方向修正——只升不降→信号明确才升（2026-07-21 WP-Q2）

**背景**：决策 18 的"只升不降"让 lite 档几乎不被自动选中——auto 实际输出被压缩到 standard/compliance 二选一。一个 79 文件的小项目若没有合规关键词但 find 探测稍有不稳（SIGPIPE/head 截断）就走 standard。这与"自适应避免过重"的目标直接矛盾：把自适应退化成"自动选重档"。

**决策**：修正偏置方向，从"不确定即升档"改为"信号明确才升档，模糊走默认 standard"：
1. **明确升档**（不变）：合规关键词命中 → compliance；形态 ≥3 / 框架 ≥20 / 微服务 / monorepo → standard
2. **明确降档**：文件数 <80 且无合规关键词且非 monorepo 且依赖数 <20 → lite（WP-Q2 新增：允许降 lite）
3. **模糊走默认**：find 探测失败、依赖数不可读、边界不确定 → standard（不升不降，非"一律升"）
4. **质量优先的正确落实**：在该 fail 的地方严格 fail（strict 门禁真 fail），不在档位选择上"宁可偏重"——一个 79 文件小项目该跑 lite 就跑 lite，但 lite 档的 strict 门禁必须真 fail，不是 warn。既轻又硬，而非"lite 档藏重量"。

**与决策 18 的关系**：决策 18 的"只升不降"是当时的保守选择（advisory 门禁尚未分层，降 lite 怕放过风险）。决策 31（门禁分层）已让 advisory 显式化（6 个永不 fail），lite 档跑 strict 子集即可保证硬门禁不丢——此时"只升不降"的保守前提不再成立，修正为"明确才升"是顺势而为。

**与决策 22（detect-profile-drift）的关系**：决策 22 的"只升不降"指运行时漂移检测（项目从 lite 演进到 standard 时提示升级，不提示降级）——这是单向演进假设，仍然保留。本决策 30 修正的是生成时 auto 判定的偏置，两者作用域不同：生成时允许降 lite（信号明确），运行时漂移只升不降（演进假设）。

### 决策 31：门禁分层 enforce_level（strict/warn/advisory）—— 2026-07-21 WP-Q1

**背景**：分析发现 precheck.sh 36 门禁中 `fail()` 调用仅 2 次（非门禁函数体内的 `fail()`），其余 34 个靠 echo/pass/warn 走流程——"门禁是执法"宣称与实际行为有系统性落差。check_cognition 275 行函数 fail=0（决策 12 已诚实化为 warn-only），但仍在 36 这个数字里被宣称"门禁"。

**决策**：引入 `enforce_level` 横切分层维度，与 core/standard/compliance 正交（一个门禁同时属于 core + strict，或 standard + advisory）：
- **strict（12 个，≥3 fail）**：真 fail 阻断交付——branch/layer/reuse/security/shift-left/compliance/sbom/privacy/authz/requirements/rtm/release-sign
- **warn（18 个，1-2 fail）**：能 fail 但触发窄，混合 warn
- **advisory（6 个，0 fail）**：永不 fail，只 warn/pass（观测/认知类）——cognition/consistency/consistency-cross/link-depth/state/mermaid

**机器化**：
1. `scripts/gen-enforce-level.sh` 扫 precheck.sh 每个 check_* 函数的 fail() 调用数，按 ≥3/1-2/0 自动归类，生成 `assets/gate-enforce-level.conf`（幂等可重跑）
2. `precheck.sh` `_enforce_of()` 读 conf（bash 3.2 兼容：换行分隔字符串 + awk 查表，不用 declare -A）；`_ENFORCE_OVERRIDE_K/V` 数组支持手动覆盖（如 check_review 从 warn 升 strict）
3. `_gate_exec()` 内 advisory 路径：子 shell 内重定义 `fail()`/`warn()`/`pass()` 为纯 echo，advisory 门禁的 fail/warn 调用变成纯输出行，永不进 FAIL_COUNT/WARN_COUNT——"advisory 是观测类，不阻断交付"语义机器化
4. `--list-gates` 子命令：输出 flag/gate_fn/enforce/tier 四列（横切维度可视化）
5. `self-check.sh` 加两断言：①gate-enforce-level.conf 与 precheck.sh fail() 数一致（防漂移）②strict 门禁必含 ≥1 fail()（防 strict 声明空壳）+ advisory 必须是 0 fail（防分类矛盾）

**理由**：
1. 诚实化——advisory 6 个门禁明确"永不 fail"，不再混在 36 里让读者以为都是硬门禁；strict 12 个是真执法，数量清晰
2. 自适应基础——后续 lite 档可只跑 strict 子集（真 fail 的），advisory 在 lite 档降级为跳过，实现"既轻又硬"而非现在的"lite 档藏重量"（不拷架构 17 门禁文件）
3. 自动归类——按 fail() 能力机械分类，不靠人工主观判断；改 fail() 即自动更新 enforce_level；self-check 防漂移
4. 手动覆盖逃生口——_ENFORCE_OVERRIDE 让语义判断优先于机械分类（如 check_review 1 fail 但语义上该 strict）

**与决策 12（check_cognition 诚实化）的关系**：决策 12 把 check_cognition 从"宣称 fail"改成"诚实 warn-only"，本决策把它从"warn-only 但仍算门禁"进一步归类为 advisory——分层更清晰。决策 12 是单门禁诚实化，本决策是全部门禁系统性分层。

**与决策 5（不拆 precheck.sh）的关系**：本决策不拆 precheck.sh（保留单文件 cp 铁律），只在内部加 enforce 机制。后续 Q1.3 拆分 36 门禁为 strict/warn/advisory 三文件是独立决策（install.sh 打包保留单文件 cp）。

### 决策 26：复杂度负向预算--门禁/变量数冻结上限（2026-07-26 WP-rhetoric-honesty）

**问题**：范式声称帮项目降复杂度，但自身复杂度轨迹是单向膨胀--门禁数 27（初版）-> 52 -> 54（v2026.07.24），conf 变量数持续上升，框架规则 27 -> 74。若无约束，软件熵增将使范式自身复杂度不可控，与"帮项目降复杂度"的定位自相矛盾--范式可信度会被自身的演化曲线证伪。paradigm-positioning.md:8 已把"重量是设计选择不是缺陷"作为定位，但该定位只在"重量有上限"时才成立；无上限的"设计选择"等于无约束的熵增。

**决策**：自 v2026.07.26 起引入"复杂度负向预算"--

1. `facts.conf` 新增 `FACT_GATES_BUDGET=54`（门禁数上限，冻结于当前规模）与 `FACT_CONF_VARS_BUDGET=200`（变量数上限，当前 170 预留 30 增长空间）
2. `self-check.sh` 新增断言：`FACT_GATES_TOTAL > FACT_GATES_BUDGET` 则 **fail**（非 warn）--门禁数超预算是硬契约违反，须阻断合并
3. **新增须等额删除**：每个新 check_* 须在同一 WP 内删除 ≥1 个低价值 check_*（合并/废弃），保持总数 ≤ 预算
4. **例外机制**：合规强制（如新增国标映射需新门禁族）可申请预算上调，须在本决策记录追加"决策 26 修订 N"并说明理由 + 新预算值 + 上调期限
5. 变量数 `FACT_CONF_VARS` 同理受 `FACT_CONF_VARS_BUDGET` 约束，超预算同样 fail

**理由**：
1. 反熵增--软件熵增律表明无约束的复杂度增长不可逆；负向预算是把"减重"从口号变为机器执法（与 self-check 数字漂移检测同源机制）
2. 保护范式可信度--"帮项目降复杂度"的工具若自身复杂度无上限上升，其范式主张被自身演化曲线证伪；预算是"言行一致"的机器保障
3. 强制取舍--新增须等额删除，迫使每个新门禁证明其价值高于被删的旧门禁，避免"只加不减"的渐进式膨胀
4. 例外留逃生口--合规等硬需求可上调预算，但须显式记录理由，避免暗箱膨胀

**与决策 25（范式定位）的关系**：决策 25 把"过重"从缺陷转为"显式可选"的适用域声明；本决策给"显式可选"加了上限--"重量是设计选择"成立的前提是"重量有预算"。无预算的"设计选择"等于无约束膨胀，决策 25 的定位会沦为修辞。本决策是决策 25 的诚实化补丁。

**与 self-check 现有断言的关系**：现有 `check_doc_consistency` 守"数字漂移"（声明 vs 真值）；本决策的预算断言守"数字膨胀"（真值 vs 预算）。前者防"说错"，后者防"长太多"，两者互补。

#### 决策 26.1：等价替换 check_canary → check_loop_oracle（2026-07-27 WP-loop）

**问题**：E1（Oracle Gate 循环）提供了脚本层 `setup-loop.sh` + `loop-hook.sh`，但无门禁化兜底——AI 不主动跑 loop 时，无机械门检查「是否有未完成的 loop」。`check_canary`（advisory 档，0 fail）在生成器自身仓库无实际 canary 环境（无发布产物/无线上指标），形同虚设：未配 `CANARY_LATENCY_MS/CANARY_ERROR_RATE` 时直接 `return 0`，从未 fail。

**决策**：等价替换 `check_canary`（advisory）→ `check_loop_oracle`（strict）——
1. 删除 `gates-advisory.sh` 的 `check_canary()` 函数体（保留占位注释供计数核验）
2. 新增 `gates-strict.sh` 的 `check_loop_oracle()`：3 fail 调用（required/no_history/incomplete）→ strict 档
3. `precheck.sh` `GATE_FLAGS` 替换 `--canary` → `--loop-oracle`
4. `gate-enforce-level.conf` 重生成（gen-enforce-level.sh 幂等）：strict 21→21，advisory 14→14，总数维持 54
5. canary 监控能力保留为 `references/canary-monitoring.md` 文档 + Oracle Gate 循环形式（`setup-loop.sh --verify '<canary 验证命令>'`）
6. `FACT_GATES_ADVISORY_ONLY` 10→9（canary 是 advisory-only 10 之一）

**理由**：
1. **门禁预算守恒**——决策 26 要求新增须等额删除；canary（advisory，从未 fail）→ loop_oracle（strict，3 fail）是"低价值换高价值"的等价替换，总门禁数 54 不变
2. **强制力升级**——canary 是 advisory（0 fail，永不阻塞），loop_oracle 是 strict（3 fail，可阻塞 RC）；从"观测不阻断"升级为"机器执法阻断"
3. **能力保留**——canary 监控未消失，改为 Oracle Gate 循环形式落地（`setup-loop.sh --verify`），比原 advisory 门禁的 warn 强制力更强（promise 被拒则 loop 继续）
4. **填补缺口**——E1 的脚本层 Oracle 只有 AI 主动启动 loop 才生效；`check_loop_oracle` 是门禁级 backstop，`LOOP_ORACLE_REQUIRED=1` 时强制要求走 Oracle 验证

**与 E1（Oracle Gate 循环）的关系**：E1 是脚本层（`setup-loop.sh` + `loop-hook.sh`），本决策是门禁层（`check_loop_oracle`）。两层互补：脚本层管"loop 怎么跑"，门禁层管"loop 是否跑完"。

**Z3 fail-closed**：`LOOP_ORACLE_REQUIRED=1` 时，无 loop 状态文件且无 `LOOP_ORACLE_EXEMPT_REASON` → fail（与 sbom/crypto/dengbao 等 7 项 strict 合规门禁同 fail-closed 语义）。


### 决策 27：运行时升级整合纪律--吸收优先于新增门禁（2026-07-26 runtime-update-2026-07）

**问题**：`swarm-yuan/research/` 下 11 个外部运行时仓库需定期对齐上游最新稳定版，以保持深度/CLI/方法论三层接线的有效性。但每次升级挖出的新功能概念（如 gsd-core v1.8.0 的 reversibility tagging、superpowers v6.2.0 的 resume-based fix loop）会自然引诱"新增门禁"的冲动--若每次升级都加门禁，决策 26 的复杂度负向预算会被上游版本节奏绑架（上游发版越快、swarm-yuan 门禁越膨胀）。

**决策**：自 v2026.07.26 起确立"运行时升级整合纪律"--

1. **定期对齐**：`research/` 下 11 个运行时仓库定期对齐上游最新稳定版（非 rc/beta/alpha）；升级留底写入 `docs/runtime-update-<日期>.md` 差异报告。
2. **吸收优先于新增门禁**：升级挖出的新功能概念，**优先以方法论吸收**（references 文档 / SKILL.md 叙事 / state-machine warn 分支 / trace-log 字段 / 新增 G<N> self-check 断言）落地，**不新增 `check_*` 门禁**（守决策 26 的 `FACT_GATES_BUDGET=54` 上限）。
3. **新增门禁的最后手段**：仅当满足以下任一条件才允许新增门禁--① 等额删除旧门禁（守决策 26）；② 合规强制（如新增国标映射需新门禁族，按决策 26 修订流程申请预算上调）；③ 概念无法以方法论吸收且不机器执法会致范式失真。
4. **self-check 断言不受门禁预算约束**：G<N> 断言（如 G10 版本 oracle 单源真值）是 `self-check.sh` 的自检逻辑，不计入 `FACT_GATES_TOTAL=54`（54 = `precheck.sh` 的 `check_*` 函数数）。新增 G<N> 断言是合规的扩展点。
5. **conf 变量有余量**：`FACT_CONF_VARS_BUDGET=200` vs 当前 170，预留 30 槽位；新增 precheck.conf 变量在预算内。

**理由**：
1. **解耦上游节奏**：把"对齐上游"与"门禁膨胀"解耦--上游发版是外部节奏，门禁数是内部复杂度，后者不应被前者绑架。
2. **方法论吸收的充分性**：多数运行时新概念是"模式指引"（如 reversibility 评级、resume-based fix loop），由 AI 引用执行即可，无需机器执法；硬门禁化是过度工程。
3. **守决策 26 可信度**：决策 26 把"门禁数有上限"作为范式可信度的机器保障；本决策给"升级时如何不破上限"的操作纪律，两者互补。
4. **self-check 断言是轻量扩展点**：G<N> 断言守的是 swarm-yuan 自身的健康（修辞诚实/复杂度预算/版本 oracle 单源），非项目门禁；它不受 54 预算约束，是吸收"运行时新概念催生的自检需求"的合规出口。

**与决策 26 的关系**：决策 26 确立"门禁数有预算上限"；本决策确立"运行时升级时如何守预算"--吸收优先、新增最后。本决策是决策 26 在升级场景的操作化。

**首次应用（2026-07-26）**：本轮升级 6 个运行时（claude-mem/graphify/gsd-core/open-code-review/ruflo/superpowers），挖出 6 项整合吸收（reversibility 评级 / broken-windows ledger / honest-edge provenance / resume-based 修复环 / 可证伪性纪律 / version oracle 单源），全部以方法论吸收 + G10 断言落地，**门禁数保持 54**（G9 通过）。详见 `docs/runtime-update-2026-07.md`。

---

## 决策 28：标记沿调用链传播（Palantir markings-propagate 映射，R11 调研吸收，2026-07-31）

**问题**：R11 调研（`docs/research/R11-palantir-mapping.md` §4.1）把 Palantir 工程哲学作为外部参照系审视 swarm-yuan 设计盲区，发现首要缺口——稳定单元标注（稳定/不稳定/禁止改，`exploration-guide.md` §11f）是 **file-glob 级静态属性**（`STABLE_GLOBS`），不沿调用链向下传播。`--stable-diff` 门禁只检测"是否直接改了 STABLE_GLOBS 内文件"（`gates-warn.sh` `check_stable_diff` §1-§2），**检测不到"是否改了依赖禁止改单元的下游文件"**。例：

```
UserRepo (禁止改, 在 STABLE_GLOBS) ← UserService (无标注) ← UserController (无标注)
现状：改 UserService 不触发 --stable-diff → 但可能破坏 UserRepo 调用契约
```

这与决策 31（门禁分层）发现"36 门禁仅 2 fail"同性质——"标记是执法"宣称与实际行为有系统性落差。Palantir 的对应机制是 `/docs/foundry/security/overview/` 的 "Mandatory controls propagate along lineage"：标记是数据本身的属性，沿计算传播；新建看板不会"忘记"加安全，因为看板读的对象自带标记。

**决策**：扩展 `--stable-diff` 语义加传播段（下游改动只 **warn** 不 **fail**，保持 enforce_level 归类不变），**不新增 `check_*` 门禁**（守决策 26：门禁预算 54 不变）——

1. **`assets/precheck.arch.conf`** +`STABLE_PROPAGATE=1`/`STABLE_PROPAGATE_HOPS=1`（开关+跳数，默认开启 1 跳）
2. **`assets/precheck.sh` `_default_conf`** 兜底补同名变量（防 set -u 崩 + 目标技能 conf 缺时降级）
3. **`assets/gates-warn.sh` `check_stable_diff` §3 传播段**：本次变更触及"调用 STABLE_GLOBS 文件的下游文件"时 warn "依赖禁止改单元 X，改动可能破坏其契约，须在 spec §MODIFIED 声明"。下游影响域来源优先从 `reference-manual.md §5` 的机器可读标记 `<!-- stable-propagate: <stable> → <downstream> -->` 提取，降级为 grep import 反查（best-effort）
4. **`references/exploration-guide.md` §11g** 新增"下游影响域"段（特征卡第 11 项 P0 子项）：每个"禁止改层"稳定单元须记录 1 跳下游影响域（用 graphify path / gitnexus trace 提取），作为传播 warn 的数据源
5. **`scripts/self-check.sh` G16 断言**（不计入 FACT_GATES_TOTAL=54，守决策 27 第 4 条）：守 absorb 四载体一致性（arch.conf 开关 + exploration-guide 填充指引 + facts.conf 口径 + gates-warn.sh 传播段），缺失才 fail，叙事漂移只 warn
6. **`assets/facts.conf`** +`FACT_STABLE_PROPAGATE=1`/`FACT_STABLE_PROPAGATE_HOPS=1`（口径同步）+ `FACT_CONF_VARS` 169→171 / `FACT_CONF_VARS_ARCH` 109→111（机械计数真值）

**预算核算**：

| 项 | 变更前 | 变更后 | 预算 | 余量 |
|----|--------|--------|------|------|
| FACT_GATES_TOTAL | 54 | 54（扩展现有 `check_stable_diff` 语义，不加 `check_*`） | 54 | 0 |
| FACT_CONF_VARS | 169 | 171（+STABLE_PROPAGATE/STABLE_PROPAGATE_HOPS） | 200 | 29 |
| G<N> 断言 | G15 | G16（不计入 54） | — | — |

✅ 全部合规决策 26（门禁预算）+ 决策 27（吸收优先于新增门禁）。

**理由**：
1. **诚实化**——`--stable-diff` 宣称"防范破坏 Repository 接口"，现状只防"直接改 Repository"，防不了"改 Service 间接破坏 Repository 契约"；传播段把后者纳入 warn，消除"宣称 vs 实际行为"的落差（与决策 31 同性质诚实化）
2. **warn 不 fail**——下游改动是"风险提示"（warn 级），直接改稳定单元才是"硬执法"（strict 级，§2 的 fail 不变）；warn 不增 fail 计数 → 不改变 `--stable-diff` 的 enforce_level 归类（保持原档），与决策 31"advisory/warn/strict 横切分层"一致
3. **方法论吸收**——Palantir "markings propagate along lineage" 不硬搬为 `check_marking_propagation` 新门禁，而是扩展现有 `--stable-diff` 的语义 + 特征卡填充指引 + G16 断言三载体吸收，守决策 26/27
4. **1 跳邻域防爆炸**——默认 `STABLE_PROPAGATE_HOPS=1`（仅 1 跳下游），避免大型项目（如 yudao-cloud 5564 java 文件，R9 样本）图遍历爆炸；2+ 跳列为 R12 待测项（R11 §8）

**与决策 31（门禁分层）的关系**：决策 31 把 54 门禁按 fail 能力分 strict/warn/advisory 三档；本决策扩展 `--stable-diff`（warn 档）的语义，不改变其 enforce_level 归类（下游 warn 不增 fail 计数）。两者正交：决策 31 是"按 fail 数分层"，本决策是"按传播深度分层 warn"。

**与决策 27（吸收优先于新增门禁）的关系**：本决策是 R11 调研（外部参照系）催生的改进，Palantir "markings propagate" 概念以方法论吸收（门禁语义扩展 + 填充指引 + G16 断言三载体）落地，**0 新 `check_*` 门禁**——验证决策 27 纪律不仅适用于"上游运行时升级"，也适用于"外部理念调研"场景。

**可信度声明**：Palantir "markings propagate along lineage" 一手来源 `/docs/foundry/security/overview/`（高可信，R11 §0.3）。swarm-yuan 的"file-glob 级不传播"现状是 2026-07-31 工作树实测（`gates-warn.sh:254-336` + `precheck.arch.conf:9`）。

---

## 决策 29：语义/动能二分显式命名 + 动作授权锚定组件标记 + FDE 反向传播形式化（Palantir ontology/FDE 映射，R11 调研吸收，2026-07-31）

**问题**：R11 调研（§4.2/§4.3/§4.4）发现三个次要缺口：
- **§4.2 语义/动能二分未显式命名**：swarm-yuan 的"特征卡（语义）+ 门禁（动能）"二分与 Palantir "semantic/kinetic primitives"二分**结构性同构**，但只用"立法/执法/司法"三权隐喻命名，未显式命名语义/动能分层——导致"组件清单（语义）"与"门禁规则（动能）"的耦合关系（门禁依据来自特征卡，`README.md:107` 立法→执法映射表）不清晰。
- **§4.3 动作授权未锚定组件标记**：动作授权（决策三级分类 + 四权分离）是"资产路径驱动"（改 precheck.conf/facts.conf 要 policy-guardian，改普通源码不要），**不取决于组件的稳定性标注或上游依赖**——存在治理盲区（改依赖禁止改单元的下游文件既不触发 `--stable-diff`，也不触发 UserChallenge）。
- **§4.4 FDE 反向传播通道未形式化**：forward deploy 强（每项目生成专属技能 + memory-writeback 三路写回），backprop 弱/手工（R1-R9 调研 + WP-* 批次都是人工捕获）；R9 已暴露"5 项目清一色 Java/JS Web"样本偏倚，反向传播弱会加剧偏倚。

**决策**（纯文档变更，0 新门禁，0 新变量）：

1. **`references/cognition-framework.md` 新增 §7** "语义层/动能层二分（Palantir 本体论映射）"：
   - 语义层 = 特征卡 17 项 + 详尽组件库清单（§C+.1）+ 调用链路（§C+.2）+ 编排约束（§C+.3）
   - 动能层 = 54 门禁（check_*）+ 决策治理三级分类 + 四权分离 agent 拓扑 + 状态机
   - 继承关系：动能层规则继承自语义层（门禁依据来自特征卡，`README.md:107` 立法→执法映射表）
   - 与立法/执法/司法三权隐喻的关系：正交（三权描述权力分立，语义/动能描述结构分层）
2. **`references/decision-governance.md` §2.2 升级规则补一条**"组件标记驱动升级"：
   - AI 记录决策时，若拟改文件在某个"禁止改"稳定单元的下游影响域（决策 28 的 1 跳邻域），自动评 `costly` 可逆性（§2.4 已有 costly 评级，此处补"何时判 costly"的规则）
   - `cost_if_wrong` 字段须反映"可能破坏上游稳定单元契约"
   - 这不改变三级分类（Mechanical/Taste/UserChallenge），只在 `reversibility` 横切属性上体现
3. **`references/fde-backprop.md` 新建**（方法论引用层，非门禁）：定义"反向传播纪律"——每 N 个 forward deploy 后（N 可配，建议 5），跑 `scripts/cost-report.sh` 聚合 N 个项目的 `decisions.jsonl`/`trace.jsonl`，提取高频 UserChallenge 模式与高频门禁 fail 模式，作为 WP-* 批次的输入（人工审阅后落地，非自动改核心模板——守"AI 主导+用户决策"原则）。借鉴 Palantir FDE = "human equivalent of backpropagation"。
4. **`swarm-yuan/SKILL.md`** "它整合的方法论"表方法论引用层补一行：FDE-backprop（本仓库自创，借鉴 Palantir FDE=human backpropagation）

**预算核算**：0 新门禁，0 新变量，1 新 references 文件（`fde-backprop.md`，FACT_REFERENCES 34→35，references 不受决策 26 门禁预算管）。

**理由**：
1. **设计清晰度**——语义/动能二分是结构性切分（描述"是什么"vs"能做什么"），与三权隐喻（权力分立）正交；显式命名两层让"组件清单→门禁规则"的继承关系可见，非"立法/执法"单一隐喻所能表达
2. **治理盲区**——决策 28 的传播 warn（§4.1）+ 本决策的动作授权锚定组件标记（§4.3）双通道补"改下游依赖禁止改单元"的治理缺口：门禁层 warn + 决策层 `costly` 评级
3. **FDE 反向传播形式化**——swarm-yuan 的 forward deploy 强（每项目生成专属技能 + memory-writeback 三路写回），backprop 弱/手工（R1-R9 调研 + WP-* 批次都是人工捕获）；R9 已暴露"5 项目清一色 Java/JS Web"样本偏倚，反向传播弱会加剧"核心模板只反映 Java/JS Web 品类"偏倚
4. **纯方法论吸收**——0 新门禁 0 新变量，守决策 26/27；Palantir 本体论/AIP/FDE 概念以 references 文档吸收，不硬搬为机器门禁

**与决策 28 的关系**：决策 28 补"标记沿调用链传播"的门禁层缺口（`--stable-diff` 传播 warn）；本决策补"动作授权锚定组件标记"的决策层缺口（`costly` 评级规则）+ 语义/动能显式命名的设计清晰度缺口 + FDE 反向传播的形式化缺口。两者共同落地 R11 调研的 P1-P3 建议。

**可信度声明**：Palantir 本体论（semantic/kinetic 二分）/ AIP（AI 经本体论行动）/ FDE = human backpropagation 均一手来源（`/docs/foundry/ontology/overview/` + `/docs/foundry/aip/overview/` + Architecture Center，高可信，R11 §0.3/§1.1/§1.5/§1.7）。

---

## 决策 32：上下文窗口自适应压缩——SKILL.md 分层折叠 + frontmatter 精简 + 预算门禁（2026-08-01）

**问题**：`context-surface.sh --gen`（生成期必读三件套：SKILL.md + exploration-guide.md + template-spec.md）当前 170,709 字节，已从 post-opt 基线 156,992 膨胀回涨（+13,717 字节，+8.7%），逼近 pre-opt 基线 193,226。SKILL.md 200 行/37KB 是常驻硬成本，其中约 90 行是"按需展开"段（Step 详解 :90-107、方法论吸收记录 :141-150、reference 清单表 :154-192），但它们常驻 SKILL.md 正文，每次 skill 加载都进上下文。`FACT_CONTEXT_SURFACE_PRE_OPT=193226` 是孤儿事实（self-check 不校验）。

**决策**：三层压缩 + 预算门禁，0 新门禁 0 新 G<N> 断言（预算检查并入现有 G9 `check_complexity_budget()`）——

1. **第一层 SKILL.md 正文分层折叠**（主战场）：
   - Step 1-12 详解（:90-107，~8KB）移到新建 `references/generation-flow.md`，正文只留 ASCII 节点总览流程图 + 4 条铁律摘要 + 指针
   - 方法论吸收记录（Palantir + 运行时升级 6 条，:141-150，~3KB）折叠为 1 句话指针指向 `docs/runtime-update-2026-07.md`
   - reference 清单表 33 行（:154-192，~3KB）压缩为 6 行分类索引（探查/填充/认知/方法论/合规/安全）
   - AI 主导 7 条决策分类（:59-66，~2KB）折叠为 1 句话指针指向 `references/decision-governance.md`
   - verifier 定位 + WP-P3 框架台账（:101-103，~1KB）折叠为 1 句话指针
2. **第二层 frontmatter description 精简**：删门禁子分类细节（27 via --all-full: core 10 + architecture 17; compliance 17...）+ shift-left/rtm/release-sign 细节，保留触发词 + 核心能力 + 13/54/5/32 四个主 catchphrase。931B → ~350B（-62%）
3. **第三层 上下文预算门禁**：
   - `facts.conf` +`FACT_CONTEXT_SURFACE_BUDGET=180000`（当前压缩后 ~120000，预留余量）
   - `self-check.sh` `check_complexity_budget()`（G9）追加上下文表面预算 **warn** 断言（跑 `context-surface.sh --gen` 取 TOTAL，超预算只 warn 不 fail，渐进式对齐 MEASURE 模式）
   - CI 已跑 `--check-only`，预算 warn 进 CI 输出防回涨
   - `FACT_CONTEXT_SURFACE_PRE_OPT` 保留为历史基线（不动），新预算是独立键

**预算核算**：

| 项 | 变更前 | 变更后 | 预算 |
|----|--------|--------|------|
| FACT_GATES_TOTAL | 54 | 54（不改门禁） | 54 |
| FACT_CONF_VARS | 171 | 171（FACT_CONTEXT_SURFACE_BUDGET 在 facts.conf 非三件套，不计入） | 200 |
| FACT_REFERENCES | 34 | 35（+generation-flow.md） | — |
| context-surface --gen | 170,709B | ~120,000B（-30%） | 180,000（warn） |
| G<N> 断言 | G16 | G16（并入 G9，不加新） | — |

✅ 合规决策 26/27。

**理由**：
1. **按需展开段常驻是上下文浪费**——Step 详解只在执行到对应 Step 时需要，不该常驻 SKILL.md；references 设计意图本就是按需读取（SKILL.md:154"按需读取"），Step 详解同理
2. **frontmatter 是不可压缩硬成本**——skill 被 skill-finder 匹配时强制进上下文，931B 含门禁子分类细节属过度信息，精简到"被匹配"的最小集
3. **预算门禁防回涨**——post-opt→当前的 +8.7% 回涨无人守；warn 断言让回涨可见，CI 输出形成软约束
4. **0 新门禁 0 新断言**——预算检查复用 G9 `check_complexity_budget()`，不加新 `check_*`/G<N>（守决策 26/27）

**与决策 26（复杂度负向预算）的关系**：决策 26 守"门禁数/conf 变量数"预算；本决策补"上下文表面字节"预算——三者同源（负向预算防膨胀），但维度不同（数量 vs 字节）。字节预算 warn-only（渐进式），数量预算 fail（已达标）。

**与 generate-skill.sh 目标技能 SKILL.md 的关系**：目标技能侧已实现按 profile 档过滤 SKILL.md 索引表（`generate-skill.sh:1328` WP-P5），本决策给 swarm-yuan 自身 SKILL.md 加同层级的"按需折叠"——生成器自身先做到精简，生成的目标技能才能继承精简模式。


## 决策 33：范式作为条件而非内容——去抽象化重构与落地优先原则（2026-08-21，R13）

**决定**：swarm-yuan 从"内容驱动"重构为**两体系统（厚生成器 + 薄生成物）**，全部机制按"条件 vs 内容"判别式归位；总原则确立 **落地优先于删除**。

**背景**：R13 根本性复盘（zcode 会话库 32 主会话全量还原五轮"过重"诊断史 + 仓库病理量化 + Codex 源码级对照）确诊：范式被编码为要 AI 阅读、记忆、自觉执行的内容——40+ 概念体系靠机械打分落地（0 fail）、10/54 门禁默认不可触达、7 份行业 profile 无脚本加载、生成物 AI 读代码前先消费 5 万 token。维护者三问纠正：①概念体系不删除、完善落地；②门禁不下调；③industry-profile 必须真实加载。

**判别式**：机制分两类——**条件**（运行时约束行为、零认知占用、糊弄结构上不可能）与**内容**（要 AI 先读先记再自觉、每会话重复付税、糊弄结构上必然）。保护清单全部在条件侧；病灶清单全部在内容侧。补充教义：权限边界 fail-closed；fail-open 只允许在有下层强制兜底处。

**关键落地**（五批次，批次合计净 -653 行，diff 铁律机器验证）：
- 认知框架落地化：check_cognition 机械计分退役 → AI 判断引导 + `.swarm-yuan/notes/` 留痕（概念不删除，落地为"AI 判断的检查单"）
- 十门禁全接线：cert/cwe-audit→compliance 序列、decision/state-phase→full 序列、upstream-baseline→precheck 启动、其余挂宿主 hooks/loop-hook（可达率 54/54，FACT_GATES_TOTAL 保持 54）
- industry-profile 真实加载：`conf-render.sh --industry` 渲染 precheck.industry.conf 挂 source 链
- 模板减负：spec 仪式节折叠按需（9 核心节）/ workflow 10→4 要素 / 核对清单 96→12 / 五维表→两维表
- 门禁条件化：`scripts/gate-rules.sh` 三值求值器（allow/prompt/forbid 取最严）+ `rules.d/*.rules` 规则即数据 + FORBID 消息带替代方案
- 生成器瘦身：SKILL.md 重写为工作指引式（142→93 行/8.7KB，决策号/WP 号退出正文）/ facts 21 记账键退役 / check_doc_consistency 434→70 行（散文数字扫描退役——不手抄即无漂移）/ 税制断言（认知面 ≤256KB）
- 宿主下沉：Codex hooks 渲染（v0.148 exit 2=deny 经 codex-gate-wrapper.sh 协议适配）+ settings 沙箱通配符 deny（**/.env 防重命名绕过）+ failure-detector 叙事剧场退役

**验收（§6 进 self-check 断言）**：固定税 ≤8KB｜概念 ≤12｜可达率 54/54｜认知面 252KB<256KB｜孤儿资产=0（G18）｜反向引用=0（G19）｜吸收落地率 100%。

**预算变更**：FACT_GATES_TOTAL 54（不下调）/ FACT_ARTIFACT_BYTES_BUDGET=262144（新增）/ FACT_SKILLMD_BYTES_BUDGET=8192（新增）/ FACT_CONF_VARS_USERFACE=20（新增）。

## 决策 34：概念落地问责 + 吸收三问 + 生成物税制（防复胖三制度，2026-08-21，R13）

**决定**：三条防复胖制度成为生成器侧条件（self-check 机器可查），替代决策 26 的纯数量预算（数量预算只防新增，不防概念闲置——闲置才是棘轮失效的根因）。

1. **概念落地问责**：新概念体系进 SKILL.md 或生成物，必须同时给出落地路径（接线/AI 判断引导/路由——三选一，不接受"先放着"）。机器载体：self-check 概念消费路径断言。
2. **吸收三问**：①能否落到运行时条件（门禁/hook/脚本）？②替换既有机制还是叠加？③六个月后谁会引用？——三问不过只留调研报告（docs/research/），不进 references。R4 六段叠加吸收已按此回退（批次 0）。
3. **生成物税制**：进 UNIVERSAL_FILES 的审核问题 = "目标 AI 每会话为它付多少税"；行为参数留在包内不进全局配置（conf user 面收缩，43 glob 已迁 rules.d/framework-globs.rules）。机器载体：`FACT_ARTIFACT_BYTES_BUDGET` / `FACT_SKILLMD_BYTES_BUDGET` / `FACT_CONF_VARS_USERFACE` 三断言键。

**节奏注记**：批次之间至少间隔一个真实使用周期（用当前形态生成真实项目技能验证后再进下一批）——慢本身就是防复胖（07-21 一天 32 commit 曾被点名为"减重密度可疑"）。

**与决策 26 的关系**：决策 26 守"门禁数/conf 变量数"负向预算；本决策补"概念闲置/吸收纪律/生成物税"三个维度——同源（防膨胀）但覆盖存量与过程，不止数量。

**与决策 27 的关系**：决策 27（吸收优先于新增门禁）被三问强化——"吸收"不再自动成立，必须答出落地形态；方法论文档不再是合法归宿，条件是。

---

**决策索引（R13 后）**：决策 1-17 见 `paradigm-decisions-archive.md`；决策 18-29 见本文前部；决策 30-32 自适应与压缩；决策 33-34 R13 重构与防复胖。
