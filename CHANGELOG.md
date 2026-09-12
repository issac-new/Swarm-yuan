# Changelog

All notable changes to swarm-yuan are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Release notes per version are also available at [GitHub Releases](https://github.com/issac-new/Swarm-yuan/releases).

## [v2.13.3] - 2026-09-12

> R25c 收账轮：v2.13.2 系带病发布——发版时两项后台验收（verifier all / self-check）未确认结果即合并推送，CI 红（verifier all 与 gate-fixtures 两 job）直至本轮才发现。本轮补齐全量验收并修复 2 项缺陷：1 项产品级 P1（check_impact 干净基线一跑即崩）+ 2 处测试面（impact 门禁 fixture 未随 PR2 的 git 语义升级；gen-e2e mark-active 闭环未填 create 新生成的骨架占位符）。流程教训固化：stub 式单测（source 门禁文件、无 set -e）结构性测不出 set -euo pipefail 交互类缺陷，须有真实 precheck 集成判别态。

### Fixed
- **check_impact 基线短路在干净仓上杀死整个 precheck（P1，产品级）**：`_imp_dirty` 裸 grep 管道赋值在 porcelain 为空或全被豁免滤掉时退出 1，`set -euo pipefail` 下直接终止脚本——PR2 想放行的「干净基线」场景实际一跑 `--impact`/`--all-full` 即在 check_impact 崩溃截断、后续门禁全部不执行（v2.13.2 实证：flask 实仓与合成干净仓均复现即崩；当时的「基线放行」日志以现提交代码不可复现）。修复：补回 `|| true` 守卫——check_scope 同型语句本就有此守卫，PR2 抄范式时丢失。判别：test-check-impact-baseline 新增态 5 集成态（真实 precheck.sh + set -e 环境跑干净仓；旧代码红、新代码绿，双向实证）。
- **impact 门禁 fixture 未随 PR2 git 语义升级（P2，测试面）**：check_impact 引入基线短路后，impact 三 fixture（compliant / compliant-spec-glob / violating）无运行时 git 仓，门禁探到外层 Swarm-yuan 仓（clean 且不领先）——violating 被误放行、compliant 断言不命中（且当时实际被上述崩溃截断掩盖）。修复：按 scope/branch/review/stable-diff 既定惯例补 setup.sh（运行时建仓 + feat 分支携带待审变更）与 teardown.sh，三场景恢复 spec 检查主路径语义（3/3 绿，修复前 3/3 红）。
- **gen-e2e mark-active 闭环测试未填 framework-knowledge.md（P2，测试面）**：PR1 让 create 自动注入框架门禁并生成 framework-knowledge.md 骨架（含「待填充」占位符），--mark-active 状态门拒绝占位符残留；测试的 AI Step ④ 填充模拟没跟上该新文件，E2E Step ⑧ 闭环断言挂。修复：填充阶段清零该骨架占位符（与真实 AI 填充行为一致）。

### 诚实边界
- v2.13.2 的流程缺陷如实登记：验收未确认即发版。本轮全量验收（verifier all + self-check + 79 框架 fixture + 48 门禁 fixture 组 + e2e/gen-e2e + R25c 三锚测试）全绿后才发 v2.13.3。
- flask / mybatis-3 的构建失败仍为环境性（同 v2.13.2 口径：uv build 构建后端依赖、maven-enforcer 拦截本机 JDK），门禁如实报告、非误报。

## [v2.13.2] - 2026-09-12

> R25 回归轮第三段：GitHub 真实主流项目实仓回归（pallets/flask 236 文件 + mybatis/mybatis-3 2043 文件，均为企业级最主流技术栈本体仓）。全链路重放：框架探测 → create 生成 → 填充激活 → --all-full 门禁序列。发现并修复 3 项缺陷（P1×1 + P2×2），全部带判别器断言并在实仓端到端实证。同型教训再次确认：配置面（探测/激活）与执法面（门禁/注入）的每一处新接线都要在真实项目上验证，样本项目测不出依赖目录污染这类真实世界形态。

### Fixed
- **create 流程不注入框架门禁，配置与执法体脱节（PR1，P2）**：create 探测 ACTIVE_FRAMEWORKS 写入 conf，但不注入门禁片段（--inject-frameworks 是独立子命令，仅 upgrade 路径自动调）——激活后跑门禁即 advisory「框架已激活但无门禁实现」。修复：create/断点续传路径自动注入（与 upgrade 对齐），framework-knowledge.md 骨架随之生成。双档断言（lite/standard create 后 _fw_*_check 实存；旧实现 2 处挂）。
- **框架探测被 .venv 内第三方包污染（PR3，P2）**：flask 实仓探测出 webpack——来源是 `.venv/lib/.../pyright/dist/package.json`（venv 内工具自带的 node 产物）被 pkgjson 扫描命中。与 R23-D5（门禁枚举的 node_modules 污染）同型，发生在框架探测层。修复：package.json/requirements.txt/pyproject.toml 三条 find 排除链补 `.venv/venv/site-packages`。实仓复测 flask 探测归净（flask/redis/celery）；判别断言（旧实现 venv 污染形态 1 处挂）。
- **影响分析门在无变更基线上误红（PR2，P1）**：刚激活、无待审变更的存量项目跑 --all-full，check_impact 无条件要求 spec 文档即 fail——TOGAF「变更须做影响分析」前提是有变更，两实仓首次全量门禁均被此误红。修复：HEAD 在基点且工作区 clean（技能/账本自有写入面按 R23-D7 口径豁免）→ 放行；有变更（脏工作区或领先基点提交）→ 维持原 fail 语义。四态断言含实仓暴露的 porcelain 目录形态（旧实现 1 处挂）；实仓端到端复测：flask 与 mybatis-3 的 impact 门在基线态转放行。

### 诚实边界
- 两实仓的 `构建失败`（flask：uv build 需构建后端依赖；mybatis-3：maven-enforcer 拦截本机 JDK 版本）为环境性失败，门禁如实报告、非误报；`mvn test`/`gradle test` 的 AUTO:detected 默认值语义不变。
- 实仓执勤开发（fork 后改上游代码）未覆盖，本轮实仓口径为生成 → 激活 → 门禁全序列；spec 先行开发面由 R25/R25b 样本执勤覆盖。

## [v2.13.1] - 2026-09-12

> R25 回归轮补充：Python 与 Java 栈真实执勤（R25 诚实边界披露的缺口补齐）。两栈各构造零依赖可真跑的样本项目（Python/Flask 声明 + unittest、Java/mybatis 声明 + javac+main runner），走完整执勤流程（生成 → 填充激活 → spec 先行开发标签功能 → 门禁 → 合并）。三条路径全部走通，暴露 3 项缺陷并全部修复（P1×2 + P2×1），全部带判别器断言固化（旧实现必挂、新实现全过）。Node/Express 主执勤见 v2.13.0。

### Fixed
- **check_test 零用例假绿穿透多 runner 形态（PF3，P1）**：零用例检出正则只认 jest/pytest 风格——Java 执勤实证 `mvn test` 对无 JUnit 用例项目输出 `Tests run: 0` 且 exit 0，门禁打出"✓ 测试通过"（真测试 runner 是 main 方法，surefire 跑了 0 个用例）。补齐三种主流形态：Maven/Gradle surefire `Tests run: 0`、Node TAP `# tests 0`、pytest `no tests ran`。新增五形态检出断言 + 真用例不误报（旧实现 3 处挂）。
- **--mark-active 决策账本单侧探测死锁（PF2，P1）**：trace-log `--decision` 与 SKILL.md 填充指引都把决策写到项目侧 `.swarm-yuan/decisions.jsonl`，C2 核验此前只认技能侧账本——按文档执行即死锁（Python 执勤第一步激活就撞上；R23-D14 已合并 audit-closure 一侧，此处是另一半）。修复：技能侧缺账时回退项目侧/codex 技能侧，项目根从 skill_dir 上三级派生（与调用 cwd 无关）。行为级 smoke 断言含反向对照（双侧无账仍拦，防拦截面被误删；旧实现 1 处挂）。
- **Python 项目 AUTO 命令默认值不可执行（PF1，P2）**：裸 requirements.txt/pyproject.toml 项目此前默认 `TEST_CMD='pytest'` / `BUILD_CMD='python -m build'`——两者是第三方包，未声明未安装时默认值必炸（Python 执勤实证门禁真跑翻车），且 SKILL.md 认知表继承同值。修复：声明了 pytest 才用 pytest（detected），否则标准库 `python3 -m unittest discover` 零依赖兜底；纯 requirements.txt 应用仓 BUILD_CMD 留空（与 Node 样本口径一致）。conf-render 双态断言（旧实现翻车形态被锁定）。

### 诚实边界
- Java 栈 `mvn test`/`gradle test` 的 AUTO:detected 默认值未改（对真实 Maven 项目语义正确）；零依赖 runner 样本的零用例假绿由 PF3 修复后的 check_test 拦截兜底，TEST_CMD 修正仍属 AI 填充职责（conf 标 AUTO:detected）。
- 两栈执勤样本为单包最小项目；多模块 monorepo（Python workspace / Maven 多 module）执勤路径未覆盖。

## [v2.13.0] - 2026-09-12

> R25 全量回归轮：R23 口径复跑（本地全量测试矩阵 + 真实项目执勤端到端）。执勤路径全通（遗留分支收口 → --upgrade 升级 → spec 先行新功能 → 门禁全过 → 合并收口），暴露 2 项缺陷并全部修复（P1×1 + P2×1）。较 R23 的 14 项大幅收敛，验证 R23 大扫除后的生成器在真实使用路径上已稳定。

### Fixed
- **GATE_ENFORCE_DENY 解析被行尾注释污染 → deny 非法 JSON（D3，P1）**：出厂 precheck.conf 的 `GATE_ENFORCE_DENY="..." # MEASURE: ...` 带行尾注释，fail-gate-hook 的解析 sed 只剥行首/行尾引号——注释文字与中间引号混入 DENY_LIST，PostToolUse 把污染值原样落进 .gate-fail-flag，PreToolUse deny JSON 嵌入后成非法 JSON（宿主解析失败 = 门禁失败硬拦截在出厂配置下失效）。GATE_ENFORCE_DENY_BASH 同款。修复对齐同文件 SPEC_REQUIRED 解析范式（cut 剥注释 → tr 剥空白 → sed 剥引号，tr 必须在 sed 前——首版修复因顺序错误仍残留引号，被判别器态 30 抓住后二次修正）。test-fail-gate-hook 新增态 30-31（完整污染链：PostToolUse 落 flag → PreToolUse JSON 合法性断言；旧实现 3 处挂，新实现全过）。
- **--upgrade 备份目录被 git add -A 吸入版本库（D1，P2）**：SKILL_DIR/.upgrade-backup-<stamp>/ 此前无任何忽略声明，真实执勤中单次 upgrade 制造 1.8 万行垃圾提交。修复：copy_universal_templates 三路径（create/upgrade/resume）幂等写 SKILL_DIR/.gitignore 声明 `.upgrade-backup-*/`（只追加不覆盖，用户自有条目保留）。新增 tests/test-upgrade-hygiene.sh：真实 create → git 入库 → upgrade 全链路，断言 git check-ignore 命中、git status 无备份路径、二次 upgrade 幂等、用户条目保留（旧实现 5 处挂，新实现全过）；已接线 CI 治理段。

### 诚实边界
- 本轮执勤样本为 R23 同款 Node/Express 单体（task-api），未覆盖 Python/Java 栈的真实项目执勤路径；框架门禁侧仍由 79 fixture 双态 + e2e 四框架注入覆盖。
- integrity-guard 静默面（无 stdin 输入时 exit 0 无输出）为设计行为，易被误读为"没执行"；本轮实测 deny/advisory 双场景输出协议正常，未改动。
- 认知面预算第二次例外登记（发版门追账）：self-check 实测 UNIVERSAL_FILES 认知面 269669B 超预算 266336B，成因是 R24 补核两轮运行时注记增量（+3902B；补核轮不发版故未过此断言）。FACT_ARTIFACT_BYTES_BUDGET 266336→270336，facts.conf 注释逐例留痕；非内容膨胀，不构成先例。

## [v2.12.0] - 2026-09-10

> R23 全量回归轮：对生成器跑完本地全量测试矩阵后，以真实使用路径（典型 Node/Express 项目生成技能 → 特征卡填充 → mark-active 激活 → spec 先行开发新功能）做端到端执勤回归，暴露 14 项缺陷并修复 11 项（P1×4 + P2×7；P3×3 记录观察不修）。核心发现：三类执法体在按文档执行的标准流程下静默失效或自干扰——spec 发现口径三分、scope 门基分支探测错误吞合法提交、审查工具降级链失败仍报"无问题"假 pass。修复全部带回归断言固化（单测用例 + gate-fixtures 双态 + gen-e2e 步骤）。

### Added
- **`_find_spec_file` 统一 spec 发现（D6，P1）**：precheck.sh 新增单一事实源助手——SPEC_GLOB（默认 `docs/specs/*.md`）优先，旧硬编码路径兜底，内容反查殿后；check_reuse / check_impact / check_stable_diff 三处消费方接入。gate-fixtures 新增 reuse/impact `compliant-spec-glob` 形态（spec 放文档规定位置、conf 零显式配置，旧代码下复用门静默跳过、影响门假 fail， forbidden-ids 判别新旧实现）。
- **`BASE_BRANCH` 配置变量（D8，P1）**：变更基线不再硬编码 main——conf 显式配置优先，自动探测链 main→master→HEAD~1。此前 master 基分支仓库静默退化 HEAD~1，check_scope / check_stable_diff 等全部 delta 类门禁口径错误（清树也红的假阳性实证）。precheck.conf 模板带 MEASURE 元数据，FACT_CONF_VARS 184→185。
- **check_stable_diff 标注反推兜底（D11，P2）**：STABLE_GLOBS 未配置时从 reference-manual §4 说明列稳定性标注词（与 --stability-audit 同词库）机械反推稳定单元路径——README 3.5 管束链"稳定单元被改而未声明（失败）"此前因模板把 STABLE_GLOBS 标 deprecated 而出厂即休眠。gate-fixtures 新增 stable-diff 标注反推双态（warn 档语义：篡改检出打 advisory 行，rc 不阻断）。
- **gate-fixtures 新增 scope 技能资产形态（D7）**：feat 分支提交 .claude/skills 与 .swarm-yuan 变更（工具链合法写入面）→ 不再误判只读违规。

### Fixed
- **relations-extract 不认 CommonJS require()（D1，P1）**：提取正则要求引号紧跟 require/from/import，`require('../x')` 的左括号永不命中——CommonJS 项目 0 条 import 边（与文件头声称的支持范围不符，真实项目实测 0→5 边）。test-relations-extract 新增态 4b（require 相对导入边 + 裸包不成边）。
- **check_scope 与 _git_base 自干扰（D7，P1）**：①工具链自有路径（.swarm-yuan 运行时账本、.claude/skills 与 .codex/skills 技能资产）从只读比对中豁免——此前门禁自己写的 trace.jsonl / .gate-fail-flag 每轮把 scope 门打红，合法的骨架引导/upgrade/--persist 提交永久红；分层执法归位（账本防篡改靠链式锚定与审计，技能资产防手改靠 integrity-guard 与升级机制）。②配套 D8 基分支探测修复。
- **check_review ocr 降级链假绿（D9，P1）**：ocr review 失败降级 scan、scan 再失败（如 LLM endpoint 未配置）时，原实现仍打"✓ 已执行，无 High/Critical 级问题"假 pass——改为输出形态核真（非空且无 Error 头行才算审查成立），失败如实 warn"不构成审查证据"。
- **create 撞生成流程自身顺序（D2，P2）**：文档顺序 Step 4 relations-extract 先建技能目录（写 relations.jsonl）→ Step 6 create 撞已存在目录硬报错；无 SKILL.md 的机械草稿目录现按断点续传幂等补齐。gen-e2e 新增该顺序回归步骤。
- **维度枚举 node_modules 污染（D5，P2）**：inventory-dimensions.conf 六条 grep 枚举命令补 `--exclude-dir=node_modules/dist/.git`（与 find 族排除链对齐）——npm install 后枚举扫进第三方包致计数爆炸假 FAIL（真实项目实测：端点 23→6、controller 10→5，全部转 PASS）。test-inventory-verify 新增污染用例。
- **TODO-model 清单两处失真（D3/D4，P3）**：双引号串内字面 `""` 被 shell 吞（文案失真）；deprecated 变量 SERVICE_DIRS 误列清单误导填充。test-conf-render 新增两断言。
- **审查留痕文档-实现漂移（D10，P2）**：generation-flow Step 10.5"缺则 fail"与实现（默认 warn、REVIEW_RECORD_REQUIRED=1 后 fail）对齐；precheck.conf 模板补口径注记（spec 位置唯一约定 + review-record 落点与硬门开关）。
- **rules.d 文档示例语义错误（D12，P2）**：generation-flow Step 8 示例误用文件路径 pattern（`src/generated/** → forbid`）——gate-rules 求值对象是命令首 token，照文档写即无效规则；示例改为命令语义并指明路径保护落 READONLY_DIRS/check_scope。
- **review-record 路径解析（D13，P2）**：项目根直跑 precheck 时 SKILL_DIR 未导出，`references/review-record.md` 永远解析不到——补 `.claude/skills/*/references/review-record.md` 标准落点 glob 探测。
- **audit-closure 决策账本口径分裂（D14，P2）**：mark-active 核验技能侧 `.swarm-yuan/decisions.jsonl`，audit-closure 只读项目侧——生成期决策对闭环审计不可见；现两处探测合并并披露来源。

### 诚实边界
- 本轮 P3 观察项不修：清单表头计数口径（含"说明"列的表头行计入清单数，方向偏宽松）、TODO-model.txt 激活后残留、BUILD_CMD AUTO:default 与无构建项目的错配提示。均有下层门禁或人工评审兜底，修复收益/误伤比不划算，记录待真实使用周期再裁决。
- 本机环境披露：self-check 的 gstack 源码包时效重装在本机失败（v20260910-src tag 资产问题，main 上同现，非本轮引入）；CI 与其余检查全绿。

## [v2.11.0] - 2026-09-10

> 审计收账轮（决策 38）+ R22 运行时补核。按用户级 AGENTS.md 规则全面排查：代码与验证体系实测全绿，23+4 项裂缝全部集中在文档与口径层，本轮全修并为其中两类（版本口径、认知面预算）建立机器执法。

### Added
- **版本口径三面机器锚（决策 38 决定一）**：self-check 文档一致性段新增第 6 项断言——CHANGELOG 首行版本 = 根 README badge = 技能 README badge，漂移即 warn + FAIL；安装态（无 CHANGELOG.md）显式跳过。根治 v2.8.0 起四次发版漏改根 badge 的过程根因（旧 checklist 未指明哪份 README）；CONTRIBUTING 发版步骤同步指明两处 badge。
- **认知面预算例外登记（决策 38 决定二）**：FACT_ARTIFACT_BYTES_BUDGET 262144→266336（+4KiB）。实测超 35B 的成因考证为修复两处静默失效的必要税（standards-map.conf 补随发、framework-globs.rules 补随发），非内容膨胀；例外不构成先例，下次超标仍须逐例登记。

### Fixed
- usage-manual 结构修复：尾部节号 8/9/10 双轮与层级混用消除（术语区无号化，§1-§9 连续）；§9 流程并入 §6 全旅程速查；§10 数字一览指针化到 README 附录 A（速览表单一事实源）；6 处悬空指针清零（决策史/设计内核/§5.1/map.md/调研范围/自指行）；头部过程性标记删除。
- 手抄数字漂移五处：184 变量族（178→184 + 三件套分解）、门禁分层静态 17/22/16 + 有效 17/17/21（55 名单表三度漂移后删除，改 `--list-gates` 实查）、架构门禁表补 method-size/shift-left/framework 三行（17→18）、合规门禁表补 cert-audit/cwe-audit 两行（17→19）、precheck.sh 三处内注释 27(10+17)→28(10+18)。
- 版本口径三面失同步：根 README badge v2.7.0→v2.10.1（四次漏改）；SECURITY.md v2.6.1 锚定改指 CHANGELOG/Releases（去版本号免再漂移）。
- facts.conf 还账：FACT_SCRIPT_LOC 6291→6315（self-check warn 执法再次实证）；FACT_UNIVERSAL_FILES 注释考古链补段（5170a0a 61→65 改值未改链）。
- 生成器模板去污染：`.claude/commands/swarm-yuan.md` 删 hermes-agent 项目特定路径，泛化为「只读上游快照区按 AGENTS.md 声明」；jest-vitest.md ncwk 契约条目改通用规律先行 + 实例锚点后置（五要素与 verify 块不变）。
- 次口径：CLAUDE.md 生成器侧行数 ~68K→~74K；capabilities 版本注记头部同步至 v2.1.267；baseline「159 版」与 capabilities「223 版」表观矛盾消除（改指首行计数口径）；根 tests/ 空壳目录清理。

### Changed
- R22 运行时基线补核：claude-code v2.1.267（maxEffortLevel 治理原语 + prompt-cache 工具动态性族 + managed fail-closed 第四实证）、codex rust-v0.154.0（实验性 worktree 支持 + inline 追问 + plugin/skill 热刷新）、dsh 0.1.5-rc.1、openspec 1.13.0（delta parser 不再静默改写）等九行；档案 `docs/research/R22-runtime-refresh.md`。

## [v2.10.1] - 2026-09-09

### Added
- quality:full 十步模式吸收（决策 37 追记）：workflow 节点⑥增「质量门禁序列」指引——十步串行建议（build→test→contract→reuse→consistency→layer/link-depth→docs-pack→security→deps）+ fail-fast 语义（任一步 fail 即停）+ 全部映射 precheck 既有 flag 不新增门禁；节点⑦审查范围扩到序列运行证据（gate-runs.jsonl 当次 run 记录）；commands/precheck.md 增常用序列建议

## [v2.10.0] - 2026-09-09

> R21 核心链条补强轮（决策 37）：对照用户核心思路链条十环全面复盘——①②③④⑨⑩六环已实现有测试背书，本轮补齐四个真缺口并修复一个升级丢数据缺陷。核心思路不变，能力沿链条补强。

### Added
- **任务配方层（⑤+③）**：目标技能新增 `references/recipes.md`（项目特定文件）——§A 业务功能清单（功能→入口→复用组件→接口→数据→测试编目）+ §B 任务配方五要素（触发场景/前置查询/复用件/胶水/门禁与验证）；探查方法论新增 §C+.6 业务功能盘点 / §C+.7 配方提取（三源：既有实现/git 同类任务历史/开发者文档）；verify-completeness 五要素结构执法 + inventory-verify path-check 扩展核验配方引用复用件；standard/compliance 档生成，lite 不生成
- **开发者行为吸收（⑥）**：新增 `scripts/mine-habits.sh` 六维机械统计（提交前缀/分支命名/提交规模分桶/共变文件对/热点文件/测试提交占比）→ `.swarm-yuan/notes/habits.md` 初稿，AI 审读三去向（SKILL.md 铁律引用 / dev-guide 开发偏好节 / reference-manual 注意事项+配方佐证）；dev-guide 骨架固定「开发偏好」节（无来源写"暂无已记录偏好"诚实降级，节存在性执法）；配套 test-mine-habits.sh
- **关系边集（①）**：新增 `scripts/relations-extract.sh` 机械 import 边提取（TS/JS/Vue 相对说明符扩展名/index 解析、py 相对导入、go module 剥离、java 包路径映射，零外部依赖）→ `references/relations.jsonl`；--stable-diff 1 跳下游传播优先读边集（精确于 basename grep 启发式）；--mark-active 抽样核验断边（advisory）；配套 test-relations-extract.sh 四态
- **验证资产化（⑨）**：inventory-dimensions 新增 DIM_TESTFILES 测试文件维度（测试资产一等清单对象，锚 §测试案例）；check_test 未配置 TEST_CMD 且探到测试文件 → 显式 warn（消除静默跳过；enforce 档不动零 FACT 涟漪）+ gate-fixture compliant-unconfigured 回归锁
- **问题驱动沉淀通道（⑩）**：生成的目标技能 SKILL.md 自成长段增第⑤环——使用中解决的新问题三选一沉淀（inventory-update 入清单 / recipes.md 加配方或注意事项 / gate-rules --persist 入规则）+ trace-log --decision 留痕；成长触发从"结构变化"单通道扩为"结构+问题"双通道
- **项目 rules.d 探查期生成（②）**：generation-flow Step 8 从编排约束+只读判定推导项目特有三值规则初稿（求值器消费已存在，零新机制）
- 生成器 SKILL.md 概念↔实物追踪表 +4 行（任务配方/开发偏好/关系边集/问题沉淀）；README/usage-manual/design-evolution 四载体同步；决策 37 登记

### Fixed
- **--upgrade 覆盖丢失已填充模板**：snippets.md / mcp-tools.md 属 UNIVERSAL_FILES（升级即覆盖）但 Step 7 要求 AI 填入项目实际内容——新增 USER_FILLABLE_FILES 守卫（已非占位骨架则跳过覆盖并提示），gen-e2e 回归锁
- inventory-verify `_list_count` 锚定支持中文节名锚（index() 固定串四形态匹配，BSD awk 字节类坑规避）

## [v2.9.0] - 2026-09-09

### Added
- R19 四论合一方法论：`references/four-theories-methodology.md`（由 engineering-cybernetics-methodology 扩为四论闭环单载体并改名）——总纲四元框架表 + 系统论/信息论两篇新增，控制论十律原位保留；FACT_REFERENCES 42 守恒

### Changed
- 去教条化轮（design-evolution 决策 36"恰当应用"）：dsh-engineering-methodology §七/§八 版本注记压缩为指针（操作原则各留一句，细节留 refresh 调研档）——止住上游发布节奏驱动本仓文档膨胀；upstream-baseline 补执行纪律（patch 零增量不登记/同日复核废止/细节留调研档），R16-R18 四段口径注各压一行
- four-theories-methodology 同标准手术（决策 36 追记）：机制对照表一/二与落地桥表删除（纯重命名/判据全为既有断言复写），十律编号与权威叙事框架退场、五篇内容平实化保留，系统论七手段对账表改写为结构七问检查单；文档 197→156 行，四论框架与 R18 一手复核成果保留

### Fixed
- gate-trends 恒零清单 → 零拦截清单名副其实化：原实现测"零执行"却自称"恒零拦截"，窗口口径与 N 无关且恒零集由运行档位结构性决定；修正为"窗口内全 pass（零 fail 零 warn）= 从未发现问题"语义（warn 档按设计不阻断、全 skip 沉睡信号归 adaptive-gating，均不入列）；新增 `tests/test-gate-trends.sh` 钉死四态语义并接 CI；four-theories-methodology 7 处"恒零"表述同步咬合
- README §7 指标 10 改双信号：gate-trends 零拦截清单（零拦截）+ adaptive-gating 活跃度报告（沉睡）
- SKILL.md 第六层标题粘连修复（`## 第六层 引用## 第六层 引用`）；README 调研报告计数 18→22、历史档案索引 A1-A14→A1-A16

## [v2.8.0] - 2026-09-07

### Added
- R17 工程控制论方法论吸收：`references/engineering-cybernetics-methodology.md`——五条系统设计纪律 + 机制对照表（FACT_REFERENCES 41→42）
- R18《控制论与科学方法论》认知方法论吸收：控制论文档扩为上下两篇十律；同日原书 PDF OCR 一手复核（tesseract chi_sim 243 页扫描件）四律确认 + 三处精化（控制能力连乘/范围控制律/可观察可控制变量对）
- R17-ops 五律操作化：gate-trends 恒零清单 + 十条律落地桥表

### Changed
- R17/R18 运行时补核两轮：claude-code v2.1.263 / codex rust-v0.153.4 / dsh v0.1.2-rc.1 升基线 + 外围九行；upstream-baseline 16 行全量重核

（注：v2.9.0 决策 36 轮对本版的恒零清单与十律文档形态做了纠正，见上。）

## [v2.7.0] - 2026-09-05

### Added
- SECURITY.md / CONTRIBUTING.md（企业级标准合规：漏洞报告流程与响应时限 + worktree 纪律 + commit 规范 + PR/Release 流程）
- docs/ 三档案物化：`docs/design-evolution.md`（决策史全文 + 历史档案 A1-A15）/ `docs/upstream-baseline.md`（16 运行时许可证/版本/drift 供应链机器锚）/ `docs/usage-manual.md`
- R16/R17 运行时升级调研档：`docs/research/R16-runtime-refresh.md`（全量 16 运行时）+ `docs/research/R17-runtime-refresh.md`（三件套补核 + 外围九项）

### Changed
- README 终态重构（骨架三层分离→决策蒸馏→公文笔法→四问主轴→全局概念统一→费曼两轮）：收敛为纯设计内核（只答"现在是什么/为什么这样设计"，零历史零理论），过程内容物化 docs/ 三档案
- R16 全量 16 运行时重核：11 项升基线吸收（八份 references 补核段）——gsd-core state.json 状态契约 + `<fails_when>` 强制验收失败信号、claude-mem 配额熔断器四规则 + 观察者 SILENT/NO CONTACT 契约、ocr 语义文件分组审查 + 跨 session findings 非行号匹配、gstack spawned 会话原语 + wiring 层 fail-open 案、ECC Plan Canvas 监听纪律、codex-security assess-patch-risk 五值裁决候选等
- R17 三件套补核：claude-code v2.1.261（`--permission-prompts none` 无头执法档 + 宿主 deny 语义漂移警示 + `/skill-doctor` 成本审计 + 提示词外置第四次验证）、codex rust-v0.153.4（Guardian 条件性兜底 + `request_user_input_async` 回合中结构化问答 + hooks 三层信任）、dsh v0.1.2-rc.1（跨版本读兼容三件套 + 删 SQLite 后端迁移纪律 + `<domain>/<reason>` 失败词表 + Agent Teams 孵化围栏 → dsh-engineering-methodology §八）；确立**宿主治理层条件性**教义——宿主 deny/审批层版本间不保证在场，执法确定性锚自持 55 门禁
- upstream-baseline 16 行基线全量重核（claude-code v2.1.261 / codex rust-v0.153.4 / dsh v0.1.2-rc.1 / openspec v1.12.0 / claude-mem v13.24.0 / ocr v1.11.4 / ruflo v3.38.21 / codex-security v0.1.25；comet 0.4.0-rc.4 仍观望 / GitNexus v1.6.11 stable 但 license-risk 不变）

### Fixed
- 决策 27 门禁预算 54→55 规范层三处对齐决策 26.2 追认值（历史决策记录保留原值）
- codex-security-methodology FACT_REFERENCES 34→41、code-graph-tools graphify 许可证 MIT→Apache-2.0 数字/事实裂缝
- R17 版本注记段瘦身：生成物认知面 264873B→261993B 回到 262144B 预算内（R13 税制断言；机制与意义留 references，全量细节在 docs/upstream-baseline.md §3.5 与 R17 调研档）

## [v2.6.1] - 2026-08-28

### Changed
- README 终态准确化：回归收口元描述 + 双宿主硬化表述 + 平台兼容显式段 + 运行时三层真执行实证口径 + 质量基线验证矩阵（fixtures 79 / gate-fixture 48 / cli-ab 逐字节 0 / 双重点栈九节点真实交付）

### Fixed
- test-conf-render 8 处 `echo|grep -q` 改 here-string——消 pipefail 下 SIGPIPE write error 噪音（ubuntu runner 首跑 flaky 实证驱动）

## [v2.6] - 2026-08-27

### Added
- **双宿主整合完整化**：Codex hooks.json 嵌套 schema 对源码逐字段核验（R11 #23）、命令绝对路径部署（#24）、旧扁平文件自动升级重写；Claude Code 侧 generate-skill.sh 转发垫片（#25，UNIVERSAL_FILES 计数 59→61 同步机器锚）
- **运行时全量接线实证**：13 个外部运行时（深度 4 + CLI 4 + 方法论 5）全部真执行抽检——graphify 建图谱→god-nodes 检出、claude-mem worker+search 命中、gsd-tools validate health 实跑、comet init/status 实跑；降级链辅助工具（syft/cdxgen/madge）全装齐
- **复杂度预算追认**：决策 26.2 门禁预算 54→55（check_method_size 入编），self-check 首次 RC=0 全绿

### Changed
- graphify god-nodes 从 gitnexus elif 遮蔽中解放为并行正交（#22，检测面正交不互斥）；降级 grep 补 java/vue include
- codex-security 接线 flag `--json`→`--format json`（#26，0.1.21 真源 CLI 核验）

### Fixed
- R6-R12 十一轮回归累计 28 项修复全部落库（#1-#28，每项带 fixture/测试/实证锁死）
- 文档零旧口径残留（DESIGN/case-studies/README 数字全部与 facts.conf 机器真值对账）
- 双重点栈（RuoYi 前 vue+element、后 SpringBoot+MySQL）九节点真实交付验证（jar 90MB 零错）

## [v2.5] - 2026-08-21

### Added
- R16 本体论驱动重构：显式类型层（assets/ontology/ 三目录=类型事实源）+ 六锚健康检查（scripts/ontology-verify.sh 一站式）
- 类型对账断言（self-check check_ontology_types，18 实存点逐一核验）
- 语义/动能两区纪律（地图骨架头部声明）

## [v2.4] - 2026-08-21

### Added
- R15 HarnessEval 吸收：digest 链式锚定（三本账从并列升级为链式，上游篡改全链 stale 可检出）+ missing_evidence 态（"该测没测"显式态）+ gate-plan 选择即证据（启用/跳过理由负空间可审计）+ audit-closure 审计即完成条件（goal 闭环完备性重走）

## [v2.3] - 2026-08-21

### Added
- R14 better-harness 吸收：工作流审计层（goal_id+closure 目标闭环化=一个用户目标+一个验收边界，change↔validation 链接才 closed）+ 证据态分级（Present/Wired/Exercised/Outcome-supported——配置≠使用≠有效）+ 双账本（当窗验证 repair_verified_rate + guardrail 配对）+ 修复复核位（repair_review）

## [v2.2] - 2026-08-21

### Changed
- R14 基础版：工作流审计层框架（goal/closure 目标闭环 + 证据态分级概念引入）

## [v2.1] - 2026-08-21

### Changed
- R13 去抽象化增量：条件化强化（rules.d 三值/FORBID 带替代/G18/G19 断言）+ 宿主下沉（Codex hooks/settings 沙箱 deny）

## [v2.0] - 2026-08-21

### Changed
- **R13 去抽象化重构**：概念以指引式落地（认知计分退役转 AI 判断引导+notes 留痕）/ 十门禁全接线 54-54 / industry 真实加载 / 40 references 路由头；模板减负（spec 仪式节折叠/workflow 10→4 要素/核对清单 96→12）；条件化（rules.d 三值/FORBID 带替代）；生成器瘦身（SKILL.md 142→93 行/facts 21 键退役/check_doc 434→70 行/税制断言）

---

[v2.6.1]: https://github.com/issac-new/Swarm-yuan/compare/v2.6...v2.6.1
[v2.6]: https://github.com/issac-new/Swarm-yuan/compare/v2.5...v2.6
[v2.5]: https://github.com/issac-new/Swarm-yuan/compare/v2.4...v2.5
[v2.4]: https://github.com/issac-new/Swarm-yuan/compare/v2.3...v2.4
[v2.3]: https://github.com/issac-new/Swarm-yuan/compare/v2.2...v2.3
[v2.2]: https://github.com/issac-new/Swarm-yuan/compare/v2.1...v2.2
[v2.1]: https://github.com/issac-new/Swarm-yuan/compare/v2.0...v2.1
[v2.0]: https://github.com/issac-new/Swarm-yuan/releases/tag/v2.0
