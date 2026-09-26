# Changelog


## [v2.32.0] - 2026-09-26

> R64 Ruby 换栈演练轮（第十棒）：真实开源 **rack v2.2.9**（Bundler + minitest 1152 runs/4078 assertions/20 failures/0 errors 实测，见下方勘误）首执勤——Ruby 生态五面全盲（规则集/探测/提取/命令嗅探/枚举器），全补齐：**ruby 规则集三件套**（ruby.md 11 条五要素规律 + ruby.sh 4 门禁 + 双态夹具 4/4+4/4 + 探测三信号，FACT_FRAMEWORKS 80→81，golden 82 行零漂移）+ 工具链四修（Ruby 提取/composer→Bundler 嗅探/DIM Ruby 形态/探测）。真实项目实测：rack 提取 **74 条 Ruby import 边**（require_relative 裸名+前缀双形态/gem require 零泄漏），conf-render 出 `bundle install`/`bundle exec rake`。
>
> **勘误（2026-09-26 独立验收）**：本节原记"4126 assertions/0 failures"有误——复跑两次一致为 **1152 runs/4078 assertions/20 failures/0 errors/2 skips**（ruby 4.0.7 工具链）。20 个失败全部集中 Rack::Session::Cookie/Pool 规格断言，根因是 Ruby 4.0 起 `Hash#inspect` 输出 `=>` 两侧加空格的格式漂移（rack 2.2.9 早于 Ruby 4.0 的环境差异，非本轮回归，rack 源码零改动可证）。已同步勘误 GitHub Release 正文。

### Added
- **ruby 规则集三件套**（子代理按 php 模式建成）：references/frameworks/ruby.md（4 条机械门禁规律：Gemfile↔lock 漂移双判/硬编码密钥/ENV 键双源/erb @ivar 双向 + 7 条人工检查）；assets/framework-gates/ruby.sh（fw_ruby_hardcoded_secret(fail)/gemfile_lock/env_key_drift/view_var，requires_conf 三变量）；tests/fixtures/ruby/ 双态夹具（expected-fail-ids 4 id/expected-pass-ids 4 id）+ 探测三信号行（Gemfile/Rakefile/file_exists + *.gemspec/file_glob）+ 索引重生成（81 框架）。
- **relations-extract Ruby 提取分支**：require_relative 裸名（'helper' 无前缀——Ruby 最常见形态）+ './x' 前缀双形态 → .rb 或 /basename.rb 解析（目录约定）；gem require 不发边；vendor/bundle 排除。
- **conf-render Gemfile 命令族**：BUILD=`bundle install` / TEST=`bundle exec rake`（lock 存在才 confirmed，非改写纪律同 composer）。
- **tests/test-r64-ruby-drill-locks.sh（5 断言，CI 接线）**：L1-L3 行为锁 + L4-L5 源码锁。

### Fixed
- **DIM Ruby 形态**：controller 正则补 Sinatra 路由 `get/post/put/delete/patch +./`（用 `.` 通配引号——conf 内字面单引号截断 grep 模式串致 bash 语法错）；TESTFILES 补 *_spec.rb/test_*.rb/*_test.rb；--include='*.rb'。
- G20/引号坑：Sinatra 路由模式的引号字面量问题在 conf 文件中以 `.` 通配符解（config 双引号包裹 grep 单引号串——字面 ' 不可入，与 shell 变量转义不同族）。

## [v2.31.0] - 2026-09-26

> R63 边界披露清账轮（"继续（边界披露）"）：三条披露边界的①②清账——SIGNALS 探测新增 **composer 通道**（composer.json require/require-dev 依赖字符串匹配，awk 状态机只取依赖段键防误报，匹配语义复用 pkgjson 词边界口径；php 信号行挂新通道，实测 require "php" 即命中）；golden-vector 新增**显式一键重建**（`SWARM_YUAN_GOLDEN_REBUILD=1 bash scripts/self-check.sh`，opt-in 不自动跟随漂移——保验证器基线独立性；非 opt-in 漂移仍 FAIL）。③Ruby 第十棒后续轮。

### Added
- **detect-frameworks composer 通道**（边界①）：桶构建（require/require-dev 段内键，含 vendor/name 与 php/ext-*）+ case 分派 + 词边界/精确匹配复用 pkgjson 分支 + `php|php|composer` 信号行 + framework-signals 索引重生成（80 框架）。实测：`{"require":{"php":"^8.1"}}` → 探出 php；require-dev 段键同进桶；非依赖段 JSON 键零误报。laravel/symfony 子规则集细分自此有通道（无需再开新通道）。
- **golden 显式一键重建**（边界②）：环境变量 opt-in 走 verifier 官方 `rebuild-golden` → 重建后本轮即对账 → 提示审 git diff；漂移分支保留 FAIL（不自动跟随——基线独立性）。
- **tests/test-r63-boundary-clearance.sh（5 断言，CI 接线）**：L1/L2 行为锁 + L3-L5 源码锁。

## [v2.30.0] - 2026-09-26

> R62 PHP 换栈演练轮（第九棒）：真实开源 **vlucas/phpdotenv**（Composer 2.10.3 + PHPUnit 280/280 实测）首执勤——打出 **PHP 生态五面全盲**（规则集/探测/提取/命令嗅探/枚举器全无，"连在册都没有"形态），全补齐：**php 规则集三件套**（php.md 12 条五要素规律 + php.sh 5 门禁 + 双态夹具 5/5 检出 5/5 放行 + 探测信号 4 通道，FACT_FRAMEWORKS 79→80）+ 工具链四修（PHP 提取/composer 嗅探/DIM 形态/机制修）。真实项目行为实测：phpdotenv 提取出 87 条 PHP import 边（use PSR-4 唯一命中 + require/include 相对解析），conf-render 出 composer 命令族。

### Added
- **php 规则集三件套**（子代理按框架三件套模式建成，golden-vector 重建对账 81 行零漂移）：references/frameworks/php.md（§1-§6，5 条机械门禁规律 + 7 条人工检查）、assets/framework-gates/php.sh（fw_php_hardcoded_secret(fail)/composer_lock/env_key_drift/route_name/view_var，requires_conf 声明四变量）、tests/fixtures/php 双态夹具（expected-fail-ids/expected-pass-ids 变异锁）、detect-frameworks 四信号行 + framework-signals 索引重生成。
- **relations-extract PHP 提取分支**（D2）：use 命名空间→PSR-4 类名唯一命中（重名不发边）+ require/include 相对/__DIR__ 引用解析；vendor/ 排除链补齐（PHP 的 .venv 等价物）。
- **conf-render composer 命令族**（D3）：BUILD=`composer install`（按 lock 确定性安装，R60-A2 非改写纪律）/TEST=`vendor/bin/phpunit`；composer.lock 存在才置 confirmed（不实跑不语义确认）。
- **tests/test-r62-php-drill-locks.sh（6 断言，CI 接线）**：L1/L2 行为锁（PSR-4 边+require 边+vendor 零）/L3 行为锁（命令族）/L4-L6 源码锁。

### Fixed
- **D4 DIM 枚举器 PHP 形态**：controller 正则补 Route::/->get( 入口、测试面补 *Test.php、文件类型补 *.php。
- **机制修（子代理审计发现#1）**：test-framework-conf-consistency 期望值改读 FACT_FRAMEWORKS 单一事实源——原常量写死，每新增规则集须手改测试否则 CI 红（手抄数字同族）。
- 两处 G20 多字节违规自踩自清（${var} 纪律；G20 扫描面已含 tests/）。

### 已知边界（留档）
- SIGNALS 表七通道无 composer 依赖字符串匹配（php 只能 file_exists/file_glob 激活；laravel/symfony 子规则集细分需新通道）；golden-vector 重建仍是手工步骤（流程已文档化）。

## [v2.29.0] - 2026-09-26

> R61 补缺轮（"直至全部完成"清单直至全部完成"清单①②③）：R60 留档待办清账——A8 迁移增量判别真接线（提示≠实跑：原 warn 只提示"跑 makemigrations --check"却从不实跑，现 manage.py 形态实跑 --check --dry-run 判增量、可复用 app 形态诚实降级披露）、A6 DIM 枚举器 Django 形态补全（path()/re_path()/as_view() 入口 + models.py ORM 面）、A9/A11 悬置销项（S1 README 死键/S2 双型模板上下文——裁决回填转正，项目级语义正式收口）。变异锁 9/9→11/11（L9/L10）。

### Fixed
- **A8 fw_django_migration_drift 提示≠实跑**：有迁移时实跑 `makemigrations --check --dry-run`（rc=1 报增量漂移、rc 其他诚实降级"未覆盖"）；可复用 app（无 manage.py）维持计数启发式 + 显式披露"增量判别未覆盖"。
- **A6 枚举器 Django 盲区**：DIM_BACKEND_CONTROLLER 补 `path(/re_path(/as_view(` 入口形态；DIM_ORM_SCHEMA 补 `models.py` 面。
- **A9/A11 悬置销项**：S1（README 死键 TODO_ALLOWED_FILE_ATTACHMENTS）裁决"以代码为准、不改上游文档、记冲突表"；S2（双型模板上下文）裁决"接受为上游设计现状、记已知语义边界"——悬置清单销项闭环（转正销项记录入 notes/cognition.md）。

### Changed
- tests/test-r60-django-drill-locks.sh +L9/L10（11 断言）；全量 sweep 零失败；self-check 全绿。

## [v2.28.0] - 2026-09-25

> R60 Django 换栈演练轮：栈轮换第八棒到 **Python/Django**（真实开源 django-todo：Django 6.1.1 + pytest 43/43 实测，venv 全链真实可跑）——流A 生成 + mark-active 全流程 + 审计产出 **16 类字符串耦合机械全盲面 + 11 条生成器缺陷（A1-A11）**；七条机器可修全修（A1-A7/A10）+ 十六类耦合面产品化进 frameworks/django.md 清单，9 断言变异锁。核心发现：字符串耦合防线是 Java/MyBatis 中心的——Django 生态的模板字段/URL 名/POST 参数/admin 注册/CSV 列头/迁移双源等全在机械提取面之外。

### Fixed
- **A1 同族漏修再现**：relations-extract 排除链只护了部分成员——Java 发现链有 .venv 排除、Python import 链没有（实测 1962 边 96% 是 .venv 里 _pytest 内部噪声）。全链清剿补 .venv/venv/__pycache__/.tox。
- **A7 枚举器双缺陷**：DIM 注册表排除链漏 .venv 族（DIM_TESTFILES 24 命中 18 个在 venv）+ controller 正则无词尾边界（`router.allow` 命中 `router.all` 分支，45/47 假阳性）——mark-active 报的 FAIL 全是假象；补排除链 + `([^a-zA-Z0-9_]|$)` 边界。
- **A3 分层门禁 Python 空转**：check_layer/领域污染的 import 提取只认引号形态（`import ['"]x`），Python 无引号 import 全漏——引号改可选。
- **A2 嗅探命令违反版本锁定**：uv 分支默认 `uv run build` 双缺陷——build 脚本未必存在（实跑 Failed to spawn）+ uv run 按 uv.lock 改写 venv（实测 Django 6.1.1 被静默降 6.1）；改非改写口径（compileall + `uv run --no-sync`）。
- **A4/A5 django 门禁两修**：secret_key 查补测试夹具豁免（test_settings 硬编码是测试标配，对齐 debug 查口径）；DEBUG 查补元组形态 `DEBUG = (True,)`。
- **A10 稳定性同名测试匹配补 Python 惯例族**：test_<base> 前缀/测试目录路径/<base>_test——原式只认名字互含，tests/test_utils.py 靠目录承载测试语义时假告警。

### Added
- **frameworks/django.md §字符串耦合面清单**：十六类机械盲区表格化（模板名/URL 路由名/模板字段/POST 参数/context 键/手写 input/CSV 列头/工厂字段/admin 注册/settings 键/邮件线程 ID/迁移双源/静态路径/related_name/upload_to/unique_together），spec 四查① 与探查 Python 节补指针——按栈建立等价清单自此有范式。
- **tests/test-r60-django-drill-locks.sh（9 断言，CI 接线）**：L1 行为锁（.venv 噪音边排除）+ L2-L8 源码/文本锁。
- 演练证据：kb60-django-todo 目标技能（47 构件/20 接口/8 页面三角/21 行字段映射台账，悬置清单 6 项）；A8（makemigrations --check 未接线）与 A9/A11（项目级语义）留档待办。

## [v2.27.1] - 2026-09-25

> R59 契约面同族清剿轮（R58 D1 修复的"修一处必 grep 同族"收尾）：全仓清剿"字段变更/影响面/回归"家族 15 个候选文件，锁定 6 处同族漏网全补契约面语义——要害是 **assets/spec-template.md（随发的 spec 模板本体）字段变更块还是旧三查**（AI 填 spec 时看的载体比 guide 层更要害），"三查齐后"→"四查齐后"。D9 同族（形态挑食过滤器）复查零残留。变异锁 +7（L8 清剿面断言，15/15）。

### Fixed（同族清剿 6 处）
- **assets/spec-template.md §20**：字段变更块三查→四查（+④对外契约面：API JSON 暴露字段→前端调用点/契约测试/fixtures）；"三查齐后才可声明影响面"→"四查齐后"。
- **references/frameworks/spring-data-jpa.md**：JPQL 字段级引用规律补契约面（JPA 栈同族——字段暴露 API JSON 同查）。
- **SKILL.md 弧线表**：数据映射链行召回清单补"契约面"（改字段召回 XML/job/迁移/**契约面**）。
- **assets/framework-gates/mybatis.sh**：fw_mybatis_field_sync 提示语补范围诚实声明（JSON 契约面不在本门禁面——见 spec 四查）。
- **scripts/relations-extract.sh**：头注补非覆盖披露（HTTP/JSON 契约面不在机械提取面——语义边 route/call 补，反查见 spec 四查④）。
- **scripts/relations-query.sh**：field 反查注释补契约面指针。

### Changed
- tests/test-r58-knowledge-drill-locks.sh +L8 清剿面锁（6 文件契约面在位 + spec 四查语义）→ 15 断言；全量 sweep 零失败；预算在 R58 登记限内（无需新登记）。

## [v2.27.0] - 2026-09-25

> R58 知识库真机演练轮：R49 吸收的四段知识协议首次真机验证（六步读法/回归分级/过期三态/悬置清单/页面三角在 r47-drill-vue-spring 真实前后端同仓项目实弹）——**8 处生成器/协议缺陷全修**（D1-D6/D8-D9），其中 D9（框架空转检查器双挑食：声明变量名非 glob 族不认 + 标量填值不认——vite 永远过不了 mark-active）由 mark-active 卡壳逼出。修复全部带变异锁（test-r58-knowledge-drill-locks 8 断言）。

### Fixed
- **D1 契约面缺失（同族漏修第九形态）**：数据模型变更配方三查→四查——字段暴露于 API JSON 时反查前端调用点/契约测试/fixtures（此前 username 改名推导出的回归集漏前端两 spec，种子实证漏改 XML 6 红对照）；§19 ②接口命中注明"字段改名暴露于 API JSON 即属之"；knowledge-lifecycle §六同族补。
- **D2 relations-query 空结果语义二义**：无边命中提示改三支判别（字段不存在/不在 resultMap/知识缺漏），不再混写一个括号。
- **D3 稳定性标注误聚合**：「禁止改语义」说明词被 index 直查聚合为文件级禁止改 → 与变更信号对撞假告警；gsub 剔除后判（mark-active 实证：假告警消失、真告警保留）。
- **D4 emit 语言特异硬编码**：workflow 节点⑥ 调用追踪行写死 `pytest/mutation`（Java/Vue 项目骨架）→ `<测试命令>` 占位 + run-gen-e2e 同族锁（pytest|vitest|jest|mocha|junit|go test|cargo test 全族禁入骨架）。
- **D5 页面三角零落点**：exploration-guide 前端探查要点的产出无模板承载位 → template-spec §3 增前端页面表承载行（`| 页面 | 操作 | 调用+真实入参 | 权限与降级 |`）。
- **D6 悬置清单零落点**：R49 协议纯叙事无接线 → template-spec 填充规则增 ★悬置清单（notes/cognition.md 集中落点）；演练内销项实演（db 只读矛盾回填转正）。
- **D8 过期三态触发盲区**：指纹只看结构，文件内容演化不触发三态处置 → SKILL.md 反馈回路注明触发双路（结构走指纹 --diff，内容演化走 git diff/--stable-diff）。
- **D9 框架空转检查器双挑食**：check_framework_globs 只认 glob 族变量名（vite 声明 VITE_CONFIG_FILE 等被全滤）+ 填值正则只认数组形态（标量 `="…"` 假阴性）→ R48-G5b 语义补全：声明在案认全部声明变量、填值双形态；mark-active 由拦转通实证。

### Added
- **tests/test-r58-knowledge-drill-locks.sh（8 断言，CI 接线）**：D1-D9 可机化修复面的变异锁（文本在位×4 + 行为锁×3 + 源码锁×1）。
- 演练证据：kb58-vue-spring 目标技能（fill 由子代理完成：六文件零占位符+99 条框架规律+5 条决策账，mvn 31/31+npm 13/13 实测）；`.swarm-yuan/notes/cognition.md` 悬置清单销项实录。

### Changed
- FACT_CONTEXT_SURFACE_BUDGET 188416→190464（第三次登记，实测 189570B，四处协议产品化 +1010B）；FACT_ARTIFACT_BYTES_BUDGET 483328→487424（第十二次登记，实测 483421B，knowledge-lifecycle 同族补）。

## [v2.26.1] - 2026-09-25

> R57 运行时刷新轮：19 行台账全覆盖（6 移动 + 10 零移动 + 2 无稳定 tag + 1 顺延）。实质 minor 两件（ruflo 3.42.5→3.45.0 / codex rust-v0.156.1→rust-v0.157.0）+ patch 四件（claude-code 2.1.282 / openspec 1.13.2 / codex-security 0.1.31 / graphify 0.9.67）；四条横切机制吸收（机制级不整包）；graphify v1.0.0 异源 tag **第四次**诱取以四重证据驳回（台账执法实录）。证据链 `docs/research/R57-runtime-refresh.md`（18KB 源码级锚点）。

### Changed
- **台账六行更新**（`docs/upstream-baseline.md`，均 `baseline_status=synced`）：claude-code 2.1.282（闭源仅发布说明级，内部机制标注「未验证」）/ codex rust-v0.157.0 / ruflo 3.45.0 / openspec 1.13.2 / codex-security 0.1.31 / graphify 0.9.67（行内注记「v1.0.0 异源 tag 第四次诱取已拒」）。
- **四条横切机制吸收**（落 references/ 注记，不整包）：①未跑的检查必须记 `Not verified`、验证按操作语义分区判定（ADDED 查存在/REMOVED 查消失/RENAMED 不查旧名）；②归因必须附证据链并允许弃权（三态 identified/abstained/error + `evidence[]`/`limitations[]`）、硬失败只认显式标记；③门禁升级为「可撤销许可」（策略变更作废在途、deny 不可重试）+ 检查点自带恢复元数据 + 派发原子性与孤儿清理；④新能力默认关、可拔除、可测量 + 冻结语料 AND 门禁决定默认切换（首测准确率 +10.6 点但 p95 +485% 故不切换——诚实记录不采用）+ 失败面显式化（`embeddingError`/「Learning degraded」）。
- **骨架级两模式**（agent-skills-methodology）：破坏性操作「atomic rename 认领→读→比对确认才删」；导出/重生成必须幂等（write-atomic-if-changed）。

## [v2.26.0] - 2026-09-25

> R56 全量回归轮：栈轮换第七棒到**纯前端**（React 19 + TypeScript strict + Vite 7 + Vitest 3 + Testing Library，真实工具链 build/test 全绿），真实场景项目（r56-drill-kanban 三列看板，localStorage 持久化，25 用例/4 测试文件）生成目标技能，走完流A 全流程（⓪-⑨ + --inject-frameworks + 零占位符 --strict + mark-active）与流B 典型研发执勤（dueDate 字段变更 TDD 红→绿全链 spec/plan/tasks/拼装合规声明 4/4；状态机六阶段 open→design→build→verify→archive 含 verify 未全勾/verify_result 两处负向拦截；fail-gate-hook spec-first 正反实测 + --report 审计；rules.d 三值 forbid/allow；指纹自成长 --write→--diff 检出 scope→清单单条更新→新基线）。识别并修复 5 处缺陷（D1-D5），全部带变异锁（回退即红实测）。共性根因第七次复现（R28「相邻路径」、R30「只认一种形态」、R33「生态系统性缺位」、R36「同族漏修」、R39「五处缺位」、R44「生态形态穷举」）：本轮 D1/D2/D4/D5 均为「同族漏修」——范式迁移（R23-D5 排除链、R25-D3 剥注释、R33 文件级计数）只落到了同族的个别成员，React/TS colocated 形态首执勤即在漏网成员上炸出。

### Fixed
- **fail-gate-hook spec-first 整链静默失效**（D5，P0）：WRITABLE_DIRS 提取是同文件三个 conf 解析器中唯一未走 R25-D3「cut 剥注释」范式的——旧式 `sed 's/)$//'` 行尾锚，conf 行带行尾注释（模板自身惯用 `WRITABLE_DIRS=()  # TODO:model` 写法）时剥不掉括号，提取出 `src)  # ...` 垃圾串 → 可写区匹配恒 false → 无 spec 写源码全程放行。修：迁移到「末行生效 + cut 剥注释 + rtrim 后剥括号」范式；变异锁 4 态（注释形态必拦/批准 spec 放行/空数组+注释放行/多元素数组第二目录命中），回退实测态32/35 转红。
- **前端 UI 组件维把测试文件计为组件**（D1）：DIM_FRONTEND_UI_CMD 数所有 `*.tsx/*.jsx/*.vue/*.svelte`，React colocated 形态下 `*.test.tsx` 与 DIM_TESTFILES 双计数（r56-drill 实测枚举 10 = 7 源 + 3 测试）。修：排除 `*.test.*`/`*.spec.*`/`__tests__/`（与 DIM_TESTFILES 检测面互斥，两处注释互指）；变异锁态21（2 源+2 测试 → 枚举必须 2）。
- **库导出维行粒度错配假 FAIL**（D2）：DIM_LIB_EXPORT_CMD 用 `grep -rhE` 数 export **行**（一文件多导出即 N 行），而清单行是**文件**粒度——TS/JS 多导出文件是常态（实测枚举 17 行 vs 清单 10 行 → 0.59 FAIL），此前只在无 `^export` 语言上跑过恒 0 从未真实执勤。修：`grep -rl` 文件级计数（对齐头注契约与 DIM_TYPEDEF 教义）+ RM_REF 扩 `§4 §6 §9` 多锚（导出单元横跨组件/接口/数据节）+ 补 `*.tsx/*.jsx` 计入与 `*.test.*` 排除；变异锁态22（6 导出单文件 + .tsx + 测试导出 → 枚举精确 2）。
- **fan-in 信号被第三方包灌水**（D4）：stability-audit 两处 fan-in grep 缺排除链（R23-D5 纪律只落到维度枚举面，同族漏修）——npm install 后扫进 node_modules，实测 id.ts fan-in 1758（真实边集 32 条）。修：grep 类 `--exclude-dir` 六项对齐 DIM_* 族（node_modules/dist/.git + 跨栈 target/bin/obj）；变异锁态23（100 个 node_modules 引用 → fan-in 必须 0）。
- **master 基分支仓库保护分支零覆盖**（D3）：PROTECTED_BRANCHES 模板默认仅 `("main")`——git init 默认 master 形态的仓库保护名单为空（R23-D8 已认 BASE_BRANCH 同族缺口）；check_branch 提示语硬编码 main。修：默认 `("main" "master")` 双名（护不存在的名字无害）+ 提示语泛化 master；变异锁两处（gate-fixture violating-on-master 必拦 + 生成物 conf 默认断言）。

### Changed
- **tests/test-fail-gate-hook.sh** 态 32-35（31→35 断言）：WRITABLE_DIRS 注释形态四态注入。
- **tests/test-inventory-verify.sh** 态 21-23（20→23 断言）：UI 双计数/库导出粒度/风扇灌水三态注入。
- **tests/test-upgrade-hygiene.sh** +态7 生成物 conf 保护分支双名断言；**tests/gate-fixtures/branch/violating-on-master/** 新 fixture（master 形态）。

## [v2.25.2] - 2026-09-25

> R55 扩面收口轮（续 R54）：把 R52 自曝的最后一条机器断言边界关闭——G25 ⑥「随发或声明」从 `*-methodology.md` 扩到**分派表引用的全部档名**。扩面预演即抓出三处生成器侧引用无标注（generation-flow/template-spec/quality-management-standards），补【生成器侧】标注；变异锁测试加态5（抹掉行为档标注必拦），13/13 PASS。

### Fixed
- **G25 ⑥ 扩面前的三处无标注引用**（扩面预演实锤）：task-methodology-router 中 generation-flow（12 步口径引用）、template-spec（test 行回归分级引用）、quality-management-standards（合规审计行引用）均为只在生成器仓存在的文档——三处引用补【生成器侧】标注，语义显式化。

### Changed
- **self-check G25 ⑥ 扩面**：检查对象从 `references/*-methodology.md` 扩为「分派表引用的所有 references/*.md」（capability-map 自身除外；未被分派表引用的生成器侧文档无需标注——分派表是引用面的事实源）。扩面后实测零缺口。
- **tests/test-capability-map-g25.sh +态5**（12→13 断言）：抹掉 context-engineering-layering 的【生成器侧】标注 → 扩面断言必须拦——证明 ⑥ 对非 *-methodology 行为档同样执法。

## [v2.25.1] - 2026-09-25


## [v2.25.1] - 2026-09-25

> R54 全面排查轮：六面排查清单逐项打勾（36 测试全零退出/CI 三连绿/死链零/陈旧数字零/三表一致/lite 语义自洽披露），唯一实锤缺陷修复——**G25 六断言零变异锁**（违背 R44"warn 级断言须负向断言"先例）：补 test-capability-map-g25.sh 十二断言（正向六面存在性 + 孤儿/幽灵/分派落档/随发缺口四态注入必拦），CI 接线。

### Added
- **tests/test-capability-map-g25.sh（12 断言，CI 接线）**：sed 提取 `check_capability_map_wiring` 为变异锁锚（函数改名/移位即红）+ stub warn + 全量 46 档真 fixture；态0 正向六面全绿零 warn + 六断言面标签存在性（检查段被删即红）；态1-4 逐态注入违规（map 未收录档/不存在档表行/router 抹档名/UNIVERSAL 删档）必须被对应断言拦——首跑即抓到 fixture 不全（幽灵断言对缺失档真实报警，灵敏度实证）。实测 12/12 PASS。

### 排查结论（docs/research/R54-full-audit.md）
- ✅ 基础面：tests/ 全量 36 脚本逐一跑零失败；CI 最近三 run（R51/R52/R53 合并）全 success；self-check 全绿。
- ✅ 死链零（两处 workflow.md 引用为目标技能限定语境）、脚本引用零死链、陈旧数字口径零残留。
- ✅ 三表一致（map 46 行=47 档、第六层+八档短名行、UNIVERSAL 31 refs 由 G25 ⑥ 执法）。
- 披露①：第六层八行业档以短名一行承载（逐档事实源在能力地图，设计如此）；披露②：lite 档不分发分派表与方法论档（lite=认知档无执勤分派需求，升 standard 自动获得）。
- ✅ verifier v1/v2 于 CI Job 6 全量覆盖；黑话抽查无裸用（弧线表已带首现全称）。

## [v2.25.0] - 2026-09-25


## [v2.25.0] - 2026-09-25

> R53 平实语言轮（用户追加约束"不要有脚手架和黑话"）：近三轮整合引入的自造术语（流A/流B、档、随发、接线、对偶、G25、三件套、认知面、税制、变异锁……）全部补首现释义——使用手册术语词典扩 15 条（单一事实源），SKILL.md 流A/流B 首现定义，随发面 task-methodology-router 人话化（去"反向索引/对偶"式黑话，机器锚词【生成器侧】与档名保持字面不动），capability-map 定位段平实化，生成 workflow.md 产物头去"生成器仓/不随发生成物"脚手架口吻。脚手架残留审计：用户面 grep 零命中（"装配"为仓库自有架构词保留）。

### Changed
- **docs/usage-manual.md 术语词典 +15 条**：流A（生成流程）/流B（执勤工作流）/档（参考文档）/随发/接线/能力地图/方法论分派表/【生成器侧】/G 断言/三件套（生成期必读面）/认知面/税制/变异锁/证据分级 A/B/C——每条一句话平实释义，整合词汇与既有 20+ 条同处一表。
- **SKILL.md**：总闭环句补流A/流B 首现定义（"流A=生成器的 12 步生成流程；流B=目标技能的九节点执勤工作流"）+ 两处 R49 枚举瘦身为档引用（预算内替换，三件套 188383B≤188416B）。
- **task-methodology-router.md（随发面）**：分派表标题与引言人话化——"反向索引/对偶/覆盖纪律/self-check G25 守"→"配套查询：从文档查用途 vs 从任务查读什么"；表头"方法论档分派（按消费节点序）"→"该读的参考文档（按执勤工作流节点序）"；机器锚（【生成器侧】标注、全部档名）字面不动，G25 ⑤⑥ 断言实测仍绿。
- **capability-map.md**：定位段平实化（"弧线表"首现给出全称"理念→兑现追踪表"+"内部俗称弧线表"；"接线单一事实源"→"接线总台账"+展开说明）。
- **generate-skill.sh workflow.md 产物头**：去"template-spec 不随发生成物"式内部口吻→"该文件不随技能分发"。
- **README.md**：术语消歧段补整合术语词典指针。

### 决策依据
用户级 AGENTS.md 第 4 节"黑话必须翻译：内部代号首现给全称或一句话解释"；R37"脚手架/装配内容不吸收"先例。决策 45 入 design-evolution：**机器锚词与人文叙事分离**——grep 锚（【生成器侧】/调用追踪/方法论引用/档名）保持字面供断言执法，叙事层一律平实语言 + 术语词典兜底。


## [v2.24.0] - 2026-09-25

> R52 随发补缺轮（完成审计触发）：消除 R51 自曝弱覆盖——workflow.md 节点段「方法论引用」机器校验断言落地（verify-completeness 双要素契约 + 正负变异锁测试）；更深裂缝同轮修复：**分派表随发但 13 篇方法论仅 3 篇随发**（目标技能侧 feature 行分派的 knowledge-lifecycle 等 10 档根本不存在，分派是空心的）——12 档按流B 消费节点补随发 + 生成器侧档显式标【生成器侧】 + G25 ⑥「随发或声明」可达性断言。吸收层三向闭环定局：建档必接线（G25 ①）、接线必可达（G25 ⑤）、可达必随发（G25 ⑥）。

### Added
- **workflow.md 节点段「⑩ 方法论引用」机器校验**（verify-completeness，与 ⑨ 调用追踪同级双要素契约）：每个「## 节点…」段必须含方法论引用行（引用本节点消费的 references 档，对偶 task-methodology-router 分派表消费节点序），缺则列 file:line 并 exit 1。emit 九节点骨架逐节点预填具体档（①decision-governance/agent-skills/ai-process-records、②knowledge-lifecycle/code-graph-tools、③cost-estimation/cognitive-bias/togaf、④mea-loop/knowledge-lifecycle、⑤lazy-generation/subagent-orchestration、⑥review-methodology/gsd-patterns、⑦review-methodology/agent-skills、⑧decision-governance、⑨canary-monitoring/ai-process-records）。
- **tests/test-workflow-methodology-ref.sh（正负变异锁，CI 接线）**：正向 3 节点全要素通过 + 负向①剥方法论引用被拦 + 负向②剥调用追踪被拦（既有契约防回潮）；run-gen-e2e 增「方法论引用 ≥9 处」正向断言。
- **12 档随发补缺**（UNIVERSAL_FILES 71→83）：knowledge-lifecycle / decision-governance / ai-process-records / agent-skills-methodology + codex / mea-loop / togaf-metamodel / cordis-composability / frontend-design / codex-security / mcp-governance（standard）+ crypto-spec（compliance，check_crypto 判定依据同 cwe 口径）——按流B 消费节点补齐，目标技能侧分派不再悬空。
- **self-check G25 ⑥ 随发或声明断言**：`*-methodology.md` 必须随发或在分派表标【生成器侧】（four-theories/dsh-engineering/context-engineering-layering 已标注）。

### Fixed
- **cordis/mea-loop「AI 填充指引」章节撞零占位符扫描词表**：两档章节标题含"填充指引"（骨架占位符扫描词），随发进目标技能即卡 mark-active（gen-e2e 实测死锁）——改名「AI 填充指南」（语义不变，扫描词表不动）。
- **README 预算行三处陈旧数字**（R51 漏改同族残留 + R33 起漂移）：税制行/附录 D 的"320KB/327680B/第九次"→"472KiB/483328B/第十一次"；"SKILL.md ≤8KB"→"≤9728B（≈8KB 锚）"。

### Changed
- template-spec workflow 段 10 字段→11 字段（⑩ 方法论引用入详写块+填充规则+验收清单；⑨ 调用追踪编号不动，"第 ⑨ 要素"引用面零涟漪）。
- FACT_UNIVERSAL_FILES 71→83；FACT_ARTIFACT_BYTES_BUDGET 336896→483328（第十一次逐例登记，实测 477979B，12 档随发 ≈+145KB 功能必要税）；FACT_SKILLMD_BYTES_BUDGET 9216→9728（第三次登记，gen-e2e 实测 9697B，索引表 +12 行）。
- task-methodology-router 分派表补「可及性」契约（流B 行引用档随发；【生成器侧】显式标注）。


## [v2.23.0] - 2026-09-25

> R51 整合轮（续 R50）：补上"整合成整体"缺失的**反向分派面**——R50 台账是正向索引（档→消费节点），但 task-methodology-router 名实不符（自称"任务类型 × 方法论路由表"实际不分派任何方法论档，13 篇 *-methodology.md 仅 2 篇被提及），任务→方法论的分派缺失。本轮 §方法论分派表成档（14 任务类型 × 方法论档，13 方法论全覆盖）+ G25 扩"分派零落档"断言——吸收层闭环定局：建档必接线（正向）、接线必可达（反向）。

### Added
- **task-methodology-router.md §方法论分派表（R51）**：反向索引（任务类型 → 该读哪些档，按流B 消费节点序，【必】/【按】分级）——流B 七类（feature/fix/refactor/chore/docs/test/exp，task-type-gates.conf 权威集）+ 七横切场景（架构/前端/安全/治理机制设计/发布运维/验收交付/记忆沉淀）共 14 行，13 篇 *-methodology.md 全部可分派到达；生成侧任务叠加分派注记（升级→knowledge-lifecycle+memory-persistence；合规审计→four-theories+quality-management-standards）；其余档（gsd-patterns/logic-razor/cognitive-bias/governance-agents/mcp-governance/code-graph-tools/claude-code-capabilities/context-engineering-layering/domain-knowledge）按场景补充到达；安全合规族声明不走任务分派（--security/--industry/compliance 档门禁条件加载）。
- **self-check G25 ⑤ 分派零落档断言**：references/*-methodology.md 每档 basename 必须出现在 task-methodology-router.md（warn-only，不计入门禁 55）——反向索引闭环机器可检。

### Changed
- **task-methodology-router 三维度定局**：节点序列（跑哪些步）+ 门禁聚焦（守哪些门）+ 方法论分派（读哪些档）；pua 对比表"路由对象"行同步；与 task-type-gates.conf/capability-map 的关系补全（capability-map 正向索引 ↔ 分派表反向索引对偶）。
- **template-spec 方法论整合行**：补分派单源指针（"方法论分派（任务类型→档）单源见 task-methodology-router.md §方法论分派表"）——不复刻清单，合一收敛。
- **capability-map §一/§四**：补正反对偶说明 + 对账纪律第 4 条（分派零落档）。
- **FACT_ARTIFACT_BYTES_BUDGET 327680→336896（第十次逐例登记）**：实测 332672B 超 4992B，成因=分派表+三维度+对偶行 +5136B（功能本体随发执勤侧），理由链留 facts.conf。三件套 187886B ≤ 188416B（余量内，无需登记）。

## [v2.22.0] - 2026-09-24

> R50 整合轮：吸收层接线台账成档——46 档 references + 19 运行时首次有单一事实源对账（capability-map，五族整合视图 + 逐档 来源/证据/消费节点/触发）；SKILL.md 第六层从散文泛列举重写为五族路由表（46 档全部按名路由，兑现 46 个档头"路由表见 SKILL.md"承诺）；self-check G25 双向对账断言（孤儿零容忍/幽灵零容忍/两级互指），"吸收了但没接线"从此机器可检。

### Added
- **references/capability-map.md**（吸收层接线台账单一事实源，46→47）：§一 五族整合视图（生成主干/拼装与知识消费/编排与治理/验证与过程资产/安全合规与行业——吸收物按总闭环段归位）；§二 46 档逐档接线表（来源→证据分级→消费节点→触发）；§三 19 运行时消费侧映射（供给侧 upstream-baseline 之外的消费侧：接线深度/消费点/降级链）；§四 对账纪律。生成器侧台账，不入 UNIVERSAL_FILES 随发。
- **self-check G25 能力地图双向对账断言**（warn-only，不计入 FACT_GATES_TOTAL=55）：①孤儿零容忍（references/*.md 每档必须被 map 收录）；②幽灵零容忍（map 表格首列档名必须实存——awk 机械解析）；③两级互指（SKILL.md 第六层必须引用 capability-map）。

### Changed
- **SKILL.md 第六层路由表化**（整合裂缝根治）：原散文段"方法论→各 *-methodology.md（…等）"泛列举下约三分之一档位（claude-code-capabilities/memory-persistence/review-methodology/gsd-patterns/行业八档等）不按名出现；重写为五族表格，46 档全部按名路由 + capability-map 互指。
- **README 附录 B 吸收登记表**：方法论行 13 份→47 篇（陈旧计数修正）+ capability-map 台账指针；**附录 D 第 7 行**：认知面上限 310KB→320KiB/327680B（R37 期第七次登记后的陈旧数字，第八/九次登记后漂移未同步——同族残留修正）。
- FACT_REFERENCES 46→47（新档登记，facts.conf 口径链同步）。

## [v2.21.0] - 2026-09-24

> R49 知识生命周期吸收轮：京东海博 AI 知识库能力建设文章深调研——知识生产/消费/沉淀/防腐四段协议成档（knowledge-lifecycle-methodology，45→46），净增五机制接线：过期三态处置（更新/降级标注/归档）、回归范围分级推导（必跑/应跑/建议跑四路反查以边集为底座）、知识读取六步协议、前端页面知识三角、悬置清单回填协议；OKF 外部锚点官方一手核验（B 级），AB 实验数字按 C 级标注"文章自报"。

### Added
- **references/knowledge-lifecycle-methodology.md**（新调研档）：四段协议全景 + 与 swarm-yuan 既有落点对账表（生产→流A 探查/消费→流B ②/沉淀→memory-writeback+问题沉淀/防腐→指纹反馈回路/验证→verifier）+ 粒度决策（单文件地图模式 vs OKF 原子文件树——保住计数核验与 last-good 两条执法线为前提）+ 不吸收清单（角色化知识层/跨仓链路缝合/build-* 装配叙事/平台化展望均披露）。来源：京东技术《拆解京东海博 AI-Native 落地保障：海博团队 AI 知识库能力建设》（2026-09-24）。
- **反馈回路过期三态处置**（SKILL.md 第五层 + README 结构通道）：受指纹 --diff 影响的 reference-manual 条目，仍成立→更新（续期）；证据源已变但新证据不足→降级标注（degraded，引用时声明待核）；证据源已消失→归档不删（保留 valid time 历史，与双时态注记同构）。与既有 last-good 红线正交：红线防探查失败污染，三态防条目级陈旧。
- **回归范围分级推导协议**（template-spec 左移要求·测试左移 + workflow 节点②）：以 relations.jsonl 边集为反查底座四路由窄到宽——直接命中→必跑 / 接口命中→应跑 / 数据面命中（data-mapping/mapper-binding 边拉 mapper/消费方）→应跑 / 链路扩散（归入业务链/配方）→建议跑；分级写进 spec §19 回归范围字段（必跑:/应跑:/建议跑: 三行）。AI 判断引导，不新增 check_*（决策 27）。
- **知识读取六步协议**（SKILL.md 流B ②）：意图→地图→锁定→摘要优先→追链（边集一跳/两跳）→分组注入；token 经济核心=摘要优先 + 分组注入（吸收上游 okf-knowledge-read 6 步 Pipeline）。
- **前端页面知识三角**（exploration-guide「Node.js / 前端」）：每路由级页面枚举 操作（按钮/入口/弹窗）→ 调用（API + 真实入参在调用点反推）→ 权限（可见可点条件 + 降级提示）；微前端另理主子应用通信。
- **悬置清单回填协议**（exploration-guide 多源矛盾裁决节）：并存标注仍不能定 + AI 拿不准的业务语义，集中落 notes/cognition.md 悬置清单段（问题/两源证据锚点/需谁回填），回填后按裁决序转正销项；清单长度成为探查完成度显式指标。

### Changed
- FACT_REFERENCES 45→46（新档登记，facts.conf 口径链同步）。

## [v2.20.0] - 2026-09-24

> R48 跨栈回归补齐轮：三族同仓缺陷横向审计（不再靠换栈演练碰运气）——探测表 12 规则集零信号补 10 个、Go/Rust 解析基准假设 PROJ 根（同仓边集为零）、conf-render 根级单点嗅探（同仓命令全空）；R47 三修复补变异锁，负向断言逼出 D3 残留半修（前缀伪造变量假阳性放行）。

### Fixed
- **detect-frameworks.sh 12 规则集探测零信号**（R48-G1）：kubernetes/flutter/harmonyos/c-cpp/android/ios-swiftui/hive/spark/tdengine/opengauss 十个补机械信号（file_exists/file_glob/pom/pyreq 四通道），ACTIVE_FRAMEWORKS 恒空、对应门禁永不注入的"规则集在册≠链路可达"缺口关闭；doris（客户端依赖形态杂）与 rag-pipeline（模式非依赖）设计上保持手动，表内注释披露。
- **relations-extract.sh Go 双缺陷**（R48-G2）：go.mod 只读项目根 + import 解析基准假设 PROJ 根——前后端同仓时 go.mod 在 server/ 等子目录，GO_MODULE 恒空、Go 工程内边集全漏（实测 1 条边全是前端）。修：全仓发现 go.mod 清单（剪 node_modules/target/vendor 噪音），每个 go.mod 自带 module 前缀与基准目录；根级项目行为不变（r36 实测 11 条对齐）。
- **relations-extract.sh Rust crate 根硬编码**（R48-G3）：`crate::` 解析基准固定 `src/`（项目根）——同仓时 src/ 在 backend/ 下，Rust 工程内边全漏。修：crate 根=文件自身路径的 src/ 前缀（backend/src/main.rs → backend/src），根级形态行为不变（r39 实测 9 条对齐）。
- **conf-render.sh 命令嗅探根级单点**（R48-G4）：package.json/pom.xml/go.mod/pyproject/requirements/Cargo 全部只查项目根（.NET 分支已是 maxdepth 3）——前后端同仓四栈 BUILD/TEST_CMD 落 AUTO:default 空值（R47 实证）。修：无根清单时 depth≤3 发现各工程目录，按确定性优先级（pom>gradle>node>go>python>rust）合成子 shell 复合命令 `(cd <dir> && <cmd>) && ...`（段间无 cd 状态耦合、相对路径可移植、任一段失败整体失败）；node 子工程无 test/build 脚本不发对应段。根级单栈路径不变（四真实项目渲染逐字节对齐）。
- **generate-skill.sh mark-active 前缀伪造变量假阳性**（R48-G5b，D3 残留半修）：注入区块已声明 requires_conf 时，id 前缀推导仍接受伪造变量（填 JESTVITEST_SRC_GLOBS 过执法，而 jest-vitest 门禁实际读 VITEST_*——放行了但门禁依旧空转）。修：声明在案 → 只认声明变量；未注入 ruleset 的框架保留前缀兜底。

### Added
- **tests/fixtures/monorepo-cross-stack/**：五栈前后端同仓最小形态 fixtures（goweb/rsfull/pyfull/nodeweb/javaweb），锚定解析基准/探测/命令合成三类同仓缺陷的回归面。
- **tests/test-cross-stack-monorepo.sh**（13 断言，CI 接线）：五栈边集非零 + Go/Rust 边逐字锚 + javaweb mapper-binding/field-mapping ≥1 + element-ui 探测锁 + poly 复合命令锁 + 根级单栈不漂移负向锚。
- **tests/test-framework-conf-consistency.sh**（6 断言，CI 接线）：79 片段 requires_conf 全量声明 + 每规则集 mark-active 可活性 + D3 变异锁正负空三态（正向 VITEST_TEST_GLOBS 放行/负向 JESTVITEST_* 拦截/空态拦截）——R47 修复从此有变异锁，重构回潮 CI 即红。
- **generate-skill.sh --check-framework-globs <skill-dir> 子命令**：mark-active 框架空转防线抽函数可测化（check_framework_globs 单一事实源，子命令供测试与填充期自检直调）。
- **test-detect-frameworks.sh 态5**：10 个新信号正负双态（正态 10 框架全中 + 空项目零误报）。

### Changed
- README（根+技能双载体）badge v2.19.0→v2.20.0


## [v2.19.0] - 2026-09-24

> R47 典型前后端项目演练轮：Vue2+ElementUI / Spring Boot+MyBatis（前后端同仓）全栈执勤实证 3 缺陷全修——detect-frameworks 漏检 element-ui 包名、relations-extract 对前后端同仓形态 Java 边集整链为零、mark-active 框架 glob 执法 id↔变量前缀名实不符卡死激活。

### Fixed
- **detect-frameworks.sh element-ui 探测漏检**（R47-D1）：探测表只有 `element-plus`（Vue3 变体）映射 element 规则集，没有 `element-ui`（Vue2 包名）——Vue2+Element UI 这一最常见企业栈检出 7 框架独缺 element。补 `element|element-ui|pkgjson` 表行，本项目检出 7→8。
- **relations-extract.sh 前后端同仓 Java 根失锚**（R47-D2）：Java import 解析、`_fq_resolve`（mapper-binding/data-mapping/bean-wiring 消费）、`_short_resolve`（typeAlias 短名）三处硬编码 `src/main/java`/`$PROJ/src` 前缀——Java 根在 `backend/` 等子目录的同仓形态下三链边集全为零（21 条边全是前端 import，0 条 mapper-binding）。修：启动时发现 `*/src/{main,test}/java` 源根清单（剪 node_modules/target 等噪音），三处统一消费；演练项目边集 21→80（import 62 + mapper-binding 2 + data-mapping 4 + field-mapping 12）。
- **generate-skill.sh --mark-active 框架 glob 执法名实不符**（R47-D3）：按检出框架 id 机械推导变量前缀（jest-vitest→`JESTVITEST_*`），而 conf 实际变量是规则集 requires_conf 声明的 `VITEST_*`——jest-vitest 检出的项目框架门禁空转检查永查不到变量，mark-active 永久卡死。修：变量名优先取注入区块 `# ruleset: <id> requires_conf:` 声明（过滤 GLOBS/DIRS/FILES 后缀族），id 前缀推导保留为补充。

### Changed
- README（根+技能双载体）badge v2.18.0→v2.19.0

### 演练档案
- 项目 `lab/r47-drill-vue-spring`（52 文件，git 两提交）：后端 Spring Boot 2.7.18（Spring Framework 5.3）+ MyBatis XML + MySQL，23→31 测试（JUnit5 三件：Mockito/MockMvc/H2 MySQL 模式集成）；前端 Vue 2.7.16 + Element UI 2.15.14 + vuex/vue-router/axios + Vite 5 + Vitest，10→13 测试；`vite build` 产物构建实证。
- 目标技能 `lab/r47-drill-skills/vue-spring-demo`（standard 档）：流A ⓪-⑨ 全链（framework-knowledge 8 框架 97 条规律全实证、conf 三件套、precheck --all 10/10、verify-completeness --strict 零占位符、mark-active 激活）；流B user-status-toggle（PATCH /api/users/{id}/status）九节点 TDD 闭环（先红后绿 11 新测试、状态机 open→design→build→verify→archive 守卫三次真实拦截、spec §5.5 复用声明、合入 main、指纹 --diff 感知→边集重建→新基线自成长链）。


## [v2.18.0] - 2026-09-24

> R46 三项目演练完成 + 修复路径别解析问题：完成 react-express/vue-fastapi/nextjs-blog 三个典型前后端项目的定制化技能生成与 TDD 全链演示，暴露并修复 inventory-verify.sh 对 Windows 反斜杠路径的处理问题（#2）。

### Added
- **R46 三个演练项目技能**：react-express、vue-fastapi、nextjs-blog，每个项目包含定制化 SKILL.md（含任务配方 recipes.md、组件清单 reference-manual.md、边界规则 rules.d）
- **react-express 新增优先级过滤功能**：GET /api/tasks?priority=<level> 端点，支持按优先级筛选任务
- **vue-fastapi 新增完成状态切换功能**：PATCH /api/cards/{card_id}/toggle 端点，支持切换卡片完成状态
- **nextjs-blog 新增草稿箱功能**：GET /api/drafts 端点，返回所有未发布文章

### Fixed
- **inventory-verify.sh Windows 路径处理**（P2）：路径提取循环中添加反斜杠转正斜杠转换（`_p="${_p//\//}"`），解决 AI 生成 markdown 时使用 Windows 风格路径（`src\server.js`）导致的 HALLUCINATION 误报。修复后 `backend\server.js` 等路径可正确映射到 `backend/server.js`。
- **备份仓库 git init 修复**：`git mv` 在 swarm-yuan 目录缺失时失败，改为复制+删除方案
- **zsh 全局替换语法问题**：`$=var` 在 zsh 中触发全局替换语法，改为标准 `${var//\//}` 写法

### Changed
- README（根+技能双载体）badge v2.17.0→v2.18.0
- 认知面预算：实测 327536B ≤ 预算 327680B


All notable changes to swarm-yuan are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Release notes per version are also available at [GitHub Releases](https://github.com/issac-new/Swarm-yuan/releases).

## [v2.17.0] - 2026-09-23

> R45 双运行时纳入轮：tanweai/pua v3.5.1 与 semantica-agi/semantica v0.7.0 源码级调研后纳入基础运行时登记（17→19 行），并完成机制吸收与能力完善。pua 为存量来源补登记——六项机制（任务路由/四权分离/Oracle Gate/compaction 续传/失败检测/防作弊门）在 WP-loop 批已改写吸收却从未进供应链登记表（治理裂缝本轮补上，立决策 40"存量来源必登记"），同时吸收 v3.5.1 五协议增量；semantica 按"机制级吸收不引依赖"裁决（22 个核心依赖的企业数据 KG 平台不适配 skill 场景），只吸收数据模型层三个小而硬机制。调研细节 `docs/research/R45-dual-runtime-absorption.md`（A 级证据：两仓浅克隆源码精读 + 子代理独立深挖复核）。

### Added
- **governance-agents.md §Z 交付纪律协议**（pua v3.5.1 五协议改写）：诊断先行（改码前一行 `[SWARM-YUAN-DIAGNOSIS] 问题/证据/下一步` 外部承诺，防「分析正确但不行动」）；失败计数语义表（升压看已失败实验数非命令红绿——同一事件不重复计数/bug-existence test=复现证据非失败/权限缺失=有据阻塞非无限重试）；信心门控六步（列声明→找漏洞→修或披露→跑证据→循环判定→「事实上的 100%」）；四状态交付（未验证/局部已验证/已完成/有据阻塞，替代二值叙事；AI 自报与 verifier 机器结论冲突时以机器侧为准）；体面退出（穷尽后结构化失败报告：已验证事实+已排除+缩小范围+推荐下一步+交接信息）。
- **trace-log.sh --verify-chain 决策审计哈希链**（semantica provenance `checksum+sequence_id+previous_checksum` 三件套吸收）：decisions.jsonl 决策行自动携带 seq/previous_checksum/checksum（写侧与校侧同构 cksum），三类破坏机器可检——body 篡改（checksum 失配）/整行删除（后继 prev 失配+seq 断档）/重编号（seq 连续性）；R45 前旧格式行 legacy 跳过（链自首个带链字段行起算，诚实披露边界）；文件不存在 vacuously intact。已入 governance-agents verifier 验证命令集与 facts.conf（FACT_TRACE_CHAIN=1）。
- **exploration-guide §多源探查矛盾裁决**（semantica conflicts 七策略 + SourceTracker 可信度模型吸收）：来源可信度基线五级（代码实测>配置>设计文档>需求>记忆）；裁决序四级（可信度加权→最新性→并存标注→人工裁决 UserChallenge）；裁决三纪律（记录败方/落 trace/禁静默取其一）；双时态注记（valid time=代码何时如此 vs recorded time=第 N 轮探查何时知道——反馈回路单条更新不改写历史有效性，与 last-good 红线衔接）。
- upstream-baseline 17→19 行（pua/semantica 双行 synced 登记，机制源定位同 dsh 先例）；facts.conf +FACT_TRACE_CHAIN；SKILL.md 第六层路由补 governance-agents/exploration-guide 新节指引；决策 40 入 design-evolution。

### Fixed
- **failure-detector.sh 计数语义两处偏差对齐 pua v3.5.1 runtime-contract**（P1）：①原任意 Bash 成功即清零失败计数——`ls` 成功就重置，L 级在「失败→探查→失败」节奏下永远升不起来，与「Successful tools are silent」语义相反；现为普通成功保持 COUNT、验证类命令成功（test/verify/check/build/lint 语义）才清零（「子目标验收通过」的机器近似），突破检测（COUNT≥3 且 PEAK≥2 后成功）保留。②原 grep/rg 无匹配（exit 1）计为失败——「无匹配=信息非失败」；新增豁免判定（exit 1+命令含 grep/rg+输出无 error 模式→不计），真错误（exit 2/输出含 error）仍计。
- **failure-detector.sh BASH_COMMAND 变量撞 shell 内建**（P1，R45 执勤实证）：命令文本存入 `BASH_COMMAND` 后被 shell 重置为当前命令（内建特殊变量，每条简单命令前重赋值）——R45 新增的 grep 豁免与验证类清零判定在真实 hook 执行下取到错误值。改用 `TOOL_COMMAND`。该缺陷同时证明：R44-D8 修复的 tool_response 双兼容在此前无 e2e 覆盖，本轮补齐。
- **trace-log.sh 决策行 JSON 合法性**（P2，写侧自查发现）：链字段追加实现初版丢失行尾闭合 `}`（写出非法 JSONL）；修复并使 checksum 覆盖「完整 JSON body + seq + prev」，写读两侧同构。

### Changed
- test-failure-detector.sh 扩至 19 态（+态 12-14 计数语义：grep 豁免/真错误仍计/普通成功保持+验证成功清零；+态 15-19 哈希链：链字段与 JSON 合法性/prev 衔接/篡改检出/删行检出/legacy 兼容/无文件 exit 0）。
- README（根+技能双载体）badge v2.16.2→v2.17.0；技能 README 运行时口径 17→19 三处；upstream-baseline 表头与口径注同步。
- 认知面预算：实测 327536B ≤ 预算 327680B（余 144B，无超标登记——trace-log/failure-detector 增量计入；governance-agents 属 compliance 档不计税）。

## [v2.16.2] - 2026-09-23

> R44 全量回归轮：栈轮换第六棒到 .NET/C#（ASP.NET Core 10 Web API + EF Core 10 + SQLite + xUnit 2.9，.NET SDK 10.0.401 真实工具链 build/test/ef 全绿），真实场景项目（r44-drill-inventory 仓储库存 API，9 端点/2 实体/2 迁移/12 用例）生成目标技能，走完流A 全流程（⓪-⑨ + mark-active + --all 绿 + --all-full fail=0）与流B 典型研发执勤（低库存端点 TDD 全链 proposal→spec→hook 正反→状态机五段→红绿→28 门禁→gate-runs 证据→archive；UnitCost 字段变更四件套；指纹自成长 --write→--diff 检出→单条更新→新基线；rules.d forbid/prompt/未覆盖三值实测；fail-gate-hook --report 审计四段；failure-detector L1 升级+SPINNING 同签名去重）。识别并修复 8 处缺陷（D1-D8）。共性根因第六次复现（R28"相邻路径"、R30"只认一种形态"、R33"生态系统性缺位"、R36"同族漏修"、R39"五处缺位"）：本轮 D1-D5 为 .NET 生态形态在构建嗅探/框架探测/用例计数/维度枚举/nullable 扫描面五层缺位或死分支——新栈执勤必须穷举"探测→清单→门禁→反查"全链路的语言形态假设。

### Fixed
- **conf-render.sh 嗅探表补 .NET 工程文件分支**（D1，P1）：原表无 .csproj/.fsproj/.sln/.slnx 分支（同 R39-D1 Rust 形态缺位家族）——.NET 项目 BUILD_CMD/TEST_CMD 落 AUTO:default 空值，check_build/check_test 无命令可跑，"零手动配置"对整个 .NET 生态失效。现 `dotnet build`/`dotnet test` 以 AUTO:detected 渲染（任一 .NET 工程文件存在即 confirmed；find 全工程排除 bin/obj，单解决方案目录免参可发现）。
- **detect-frameworks.sh 新增 file_glob 信号通道**（D2，P1）：framework-signals.md 本就记载 dotnet 三条文件信号，但检测器只有依赖字符串/file_exists 两类通道可表达——ACTIVE_FRAMEWORKS 恒空、10 条 fw_dotnet_* 门禁不自动注入（"规则集在册≠链路可达"）。新增 file_glob 通道（signal=文件名 glob，全工程 find 命中即激活），dotnet 经 *.csproj/*.fsproj 转自动探测（实测演练项目 ACTIVE_FRAMEWORKS=() → ("dotnet")）。
- **check_test 零用例检出补 dotnet 单行聚合分支 + 探测清单镜像**（D3，P1）：xUnit/VSTest 每 assembly 打一行 "Passed!  - Failed: 0, Passed: 12, ..."——原通用正则对其零用例形态（Total 为 0）零命中，零用例假绿静默 pass，且用例数不进口径。补 dotnet 聚合分支（全部行 Passed 求和，总和 0 才 warn，与 R39-D2 cargo 分支同哲学）；TEST_CMD 未配置的测试探测清单同步补 *Tests.cs/*Test.cs + bin/obj 排除（与 DIM_TESTFILES 镜像纪律）。
- **inventory-dimensions.conf 补六维 C# 形态**（D4，P1）：接口端点/后端 controller/类型定义/测试文件/定时任务/ORM schema 六维此前对 .cs 恒 0（ENUM_ZERO_DIM 全家桶，实测八维全 0）。补 `[Http(Get|Post|Put|Delete|Patch)` 特性（每方法一特性，不过冲）、`: ControllerBase` 继承声明、public/internal 类型声明行、*Tests.cs 命名约定、IHostedService/BackgroundService、Migrations 目录 .cs；数据模型维补 DbSet< 命中 DbContext 文件，EF 纯 POCO 实体暂留披露（同 R39 Rust 先例：机械枚举高误报面，诚实降级优于虚报）。
- **fw_dotnet_nullable 的 csproj 死分支修复**（D5，P1）：原循环内 .cs 后缀 continue 守卫在 csproj 检查之前——.csproj 根本进不了循环体，`<Nullable>enable</Nullable>`（SDK 现代项目主流启用方式）永不可见，门禁对标准启用的项目恒误报。修：csproj 走独立全工程 find 兜底（排除 bin/obj，不依赖 DOTNET_GLOBS 收录），.cs 保留 #nullable 指令路径。dotnet fixture compliant 侧改 csproj 启用形态；runner 新增 expected-pass-ids 负向断言（advisory 门禁退出码恒 0，rc 断言锁不住死分支；变异实测：回退修复后 fixture 红、恢复后绿）。
- **check_build/check_test 命令缺失诚实化 + 退出码显式捕获**（D6，P2）：原 check_build `if eval ... | tail` 判的是管道尾命令（tail）的退出码，正确性依赖外层 pipefail 间接传导；且命令不存在与构建失败同词——实测 dotnet 不在 PATH 时汇总只说"构建失败"，排障方向不明。拆分捕获：命令缺失单列 fail 并指向工具链/conf 安装路径。
- **project-fingerprint.sh 排除链补 bin/ obj/**（D7，P2）：.NET 构建产物（实测基线 552 个 .dll/.pdb/.deps.json 混入 685 总文件）随 SDK/包版本或 clean 重建改变文件集 → --diff 误报"项目已变化"（R33-D6 Maven target/ 同族）。补两目录排除，inventory-dimensions 各维排除链同步（两处口径一致纪律）。
- **failure-detector.sh 结果字段双兼容**（D8，P1）：Claude Code PostToolUse payload 结果字段为 tool_response，原实现只读 tool_result——现代宿主下 exit_code 恒取 0，失败计数/L 级升级/SPINNING 同签名去重整链死代码（回归#20b"字段错位→机制整体失效"同型；实测 tool_response 键三连发计数恒 0，tool_result 键正常 L1→SPINNING）。改为双字段兼容取值。

### Changed
- FACT_SCRIPT_LOC 6489→6516 第十次登记（D3/D6 两修改 gates-warn.sh）；gate-enforce-level.conf 按再生器同步（决策 35 逐字节再生锚）；dotnet fixture 加固（violating 补 nullable/logging/auth/https/di 五断言 + compliant 侧 expected-pass-ids 十门禁负向断言）；认知面预算无超标（本轮零注记膨胀）。

## [v2.16.1] - 2026-09-19

> R39 全量回归轮：栈轮换第五棒到 Rust（axum 0.8 + tokio + rusqlite 0.37，Rust 1.98 真实工具链编译/测试/clippy 全绿），真实场景项目（r39-drill-taskflow 任务工单 API）生成目标技能，走完流A 全流程（⓪-⑨：自检→mine-habits→探查→清单→特征卡→骨架→填充→框架深化→conf→hooks→门禁→独立审查→记忆写回→verify-completeness→mark-active）与流B 典型研发任务执勤（CSV 导出端点九节点全链 proposal→spec→plan→TDD→28 门禁→独立审查→verify 证据→archive；priority 字段变更五件套；指纹自成长链 --write→结构演进→--diff 检出 scope→单条更新→新基线；spec-first hook 无 spec deny/有 spec 放行正反实测；rules.d 三值 forbid/prompt 匹配；failure-detector L1 升级+SPINNING 同签名去重；fail-gate-hook --report 审计四段）。识别并修复 9 处缺陷（D1-D9）。共性根因第五次复现（R28"相邻路径"、R30"只认一种形态"、R33"生态系统性缺位"、R36"同族漏修"）：本轮 D1/D1b/D4/D7a/D8 为 Rust 生态形态在嗅探表/维度枚举器/测试文件正则/import 解析五处缺位——新栈执勤必须穷举"探测→清单→门禁→反查"全链路的语言形态假设。

### Fixed
- **conf-render.sh 嗅探表补 Cargo.toml 分支**（D1，P1）：Rust 项目 BUILD_CMD/TEST_CMD 此前落 AUTO:default 空值，check_build/check_test 无命令可跑——"零手动配置"对整个 Rust 生态失效。现 `cargo build`/`cargo test` 以 AUTO:detected 渲染（Cargo.toml 存在即 confirmed，workspace 根与单 crate 同样成立）。
- **detect-frameworks.sh 支持 file_exists 型信号**（D1b，P1）：原实现只做依赖字符串匹配，"Cargo.toml 文件存在即激活"的 cargo 规则集激活语义无法表达，ACTIVE_FRAMEWORKS 恒空、10 条 cargo 门禁不会自动注入。新增 file_exists 通道（signal=项目根相对路径），cargo 与 dockerfile 两框架转自动探测；cargo.md §1 时代注记同步废止（三体一致）。
- **check_test 零用例检出补 cargo 多 suite 聚合分支**（D2，P1）：cargo unittests/集成/doc-tests 各打一行 test result，空 suite 合法打印 "running 0 tests"——原通用正则单行命中即 warn，8 用例全过仍误报"输出 0 用例"且 tail -20 窗口敏感形态不稳。现聚合全部 test result 行 passed 求和，总和 0 才 warn。
- **--verify-completeness 的 --strict 双序兼容**（D3，P2）：SKILL.md 流A 表记载写法 `--verify-completeness --strict <dir>`（标志前置）与实现（`<dir> --strict` 后置）矛盾，照权威文档写法报"目录不存在： --strict"，且与主解析器"标志须前置"约定互斥。现任意位置剥离 --strict，取首个目录参数。
- **inventory-dimensions.conf 补 Rust 维度枚举**（D4，P1）：接口端点/后端 controller/类型定义/测试文件四维此前对 .rs 恒 0（ENUM_ZERO_DIM 全家桶）。补 axum `.route(`（多动词链按注册点计，低估方向安全同 R33-D2 教义）、`^pub (struct|enum|trait)`、`tests/*.rs` 与 `test_*.rs`（含 */target/* 排除）；数据模型维暂留披露（Rust 无声明式 ORM 标记，机械枚举高误报面，诚实降级优于虚报）。
- **fw_cargo_license_check/fw_cargo_audit 扫描面对齐规则集口径**（D5，P1）：原只在 CARGO_GLOBS 文件集内找 deny.toml/cargo-audit 引用——deny.toml 不在默认 globs、README 写明 `cargo audit` 的合规项目双误报。现按 ruleset cargo.md §3 规律 9/10 口径：全仓 find deny.toml/audit.toml + README*/docs/.github 引用兜底。
- **fw_cargo_unwrap_expect 的 tests/ 豁免修复相对路径**（D6，P1）：_fw_resolve_globs 解出相对路径 `tests/xxx.rs` 时不命中 `*/tests/*` case 模式（缺 `tests/*` 分支），tests/ 豁免整体失效（fixture 绝对路径下测不出的形态盲区）。
- **check_shift_left spec 发现统一走 _find_spec_file + Rust 测试文件形态**（D7a/b，P1）：原 _first_existing_file 硬编码文件名发现不走 SPEC_GLOB——spec-first 拦它写码、左移检查却不认它的 spec（同一 conf 语义两套发现逻辑，R23 D6 统一只落了 check_reuse 一处）；测试文件正则 `.test.|.spec.|__tests__` 不认 Rust `tests/*.rs`，TDD 实做了仍报"无 test 文件提交"。
- **relations-extract.sh 补 Rust use 语句解析**（D8，P1）：import 边提取无 Rust 形态（`use crate::/super::/self::`），实测 0 边、影响面反查空转。补 crate::（src/ 前缀 + .rs/.mod.rs 双候选）与 super::/self::（同目录兄弟）解析；嵌套 use 不展开（机械初稿低估不虚报，AI 语义边兜底）。
- **inventory-update.sh 列数契约对齐模板**（D9，P2）：原执法"≥5 列（五维字段）"与 reference-manual.md 模板"§4/§6/§9 表格行两列"矛盾——按模板格式写的清单无法用指定工具追加/替换，单条更新通道对两列清单整体不可用。放宽为 ≥2 列，五维字段保留为 DIM 台账风格建议形态；test-inventory-update 态8 断言随契约同步（8a 单列拒绝 / 8b 两列放行）。

### Changed
- 认知面预算无增量（SKILL.md 零改动）；FACT_SCRIPT_LOC 6468→6489 第八次登记（D2/D7 两修：gates-warn.sh cargo 聚合分支 + gates-strict.sh spec 发现与 Rust 测试形态）；GOLDEN_VECTOR 80 行逐行一致（9 修零 fixture 位移）；verifier 全套 exit=0（79 fixture 双态 + e2e + shellcheck 0 error + bootstrap 自举 + metrics）。

## [v2.16.0] - 2026-09-18

> R37 Harness 实践吸收轮：行者明灵《Harness实践：OpenSpec + Superpowers + CodeGraph + Ponytail + Caveman + RTK》上下篇深度调研。四新上游对象全部 API 实测核验后才登记（codegraph 71,356★/MIT、ponytail 141,551★/MIT、caveman 106,373★/混合许可、rtk 80,864★/Apache-2.0）；文章转述经源码核实修正/升级两处（comet "Shape"相名为文章用语——A 级证实的是非 full 流程 Open 直进 Build 的仪式裁剪机制；官方评测数字与 allow_paths 语义在克隆 README 直查升 B/A 级后才写入载体）。机制吸收 10 项落 9 载体，同构对照 6 项不重复吸收，候选登记 5 项带触发条件，不吸收 5 项显式登记（RTK 代理接线/Caveman BSL-1.1 Proxy/Ponytail 插件形态等）。档案 `docs/research/R37-harness-practice-absorption.md`。

### Added
- **懒生成方法论随发执勤侧**（references/lazy-generation-methodology.md 新建，UNIVERSAL_FILES 71）：七层复用阶梯（需要存在→代码库→标准库→平台原生→已装依赖→一行→最小实现）把⑤编码"先查再写"从理念一句话变成机械下探决策程序；懒≠偷工四不砍（验证/错误处理/安全校验/无障碍——门禁下限不随任务小而豁免）；上游 issue #126 基线伪影教训（单例峰值≠总体均值）与"装完≠激活"（trusted_hash）诚实登记。
- **codegraph 进图谱选型与基线表**（第 17 行，watch 登记未接线）：GitNexus（license-risk 零接触）之外的深度图 MIT 备选——单 MCP 工具 `codegraph_explore` + `explore/affected` CLI（覆盖子代理 MCP 描述盲区）+ 100% 本地 SQLite/FTS5 + 索引随代码自动同步；+80% 上下文残留官方诚实声明一并登记；升级接线前提=本机跑通一次索引+查询（A 级）。
- **评测双口径判据与裁判运动员分离**（review-methodology R37 条目）：pass^3（连三绿=稳定性）/pass@3（三内一过=能力上界）——单次全绿只是准入不是收敛判据；comet eval 的 judge 与 execution 四重分离（独立 agent/模型/baseUrl/凭证，被评对象不得自证）；独立只读 Verifier（Verify 相无写权限独立验收）——三权分立的上游第二实证。
- **comet 实操层七机制**（subagent-orchestration R37 增量段，research/comet 克隆 0.4.1 A 级直查）：Native 仪式裁剪（非 full 流程 Open 直进 Build）/resume-probe 四值恢复探测（auto_resume/ask_user/out_of_scope/none）/hook.allow_paths 白名单语义（默认空+前缀继承+保护名单+fail closed）/doctor"恰好一个受管 Router Hook"判据/官方评测数字（README L57 直查：token −76.8%/轮次 −57.4%/耗时 −47.4%/pass^3 87.5%）+ Superpowers 三引擎安全审查附记。
- **工具面设计三原则**（mcp-governance）：单强工具 vs 多窄工具（codegraph 单工具 vs GitNexus 17 工具选型对照，不设唯一答案）/CLI 形态覆盖子代理盲区（子代理上下文看不到 MCP 工具描述，关键能力须双形态）/生效=多前提同时就位（装了 CLI≠建了索引≠注册了 MCP）。
- **Codex hooks 事件面与信任机制**（codex-methodology R37 注记，C 级）：11 类事件切面/matcher 按工具名正则（`Edit|Write` 拦 apply_patch）/trusted_hash 内容锚定（改动未复审即失效）/多来源全加载并发（注入须幂等）/SessionEnd 1s 硬预算（短事件只放轻断言）/`[features] hooks=false` 会话门禁证据不可作数/`$`执行 `@`引用语义。（装配/安装器类内容按用户裁决不吸收：插件安装行为、codegraph 自动写 MCP 配置、comet init 接入语境——吸收机制不吸收装配叙事）
- **上下文三漏与输出经济学**（context-engineering-layering §十一）：读/拿/说三通道漏点各对既有落点（图谱/结构化输出/门禁消息）；改写胜过说教（PreToolUse 机械改写优于提示词恳求）+ tee 底牌（压缩不丢证据，失败全量落盘）+ bytes÷4 诚实稀释（bash 字节≠账单 token）；不可压缩物清单（proposal/spec/tasks/验证报告/commit message/PR description 等落盘产物永不压缩）。
- **三种熵分类学**（four-theories-methodology 信息论篇）：流程熵（范围蔓延/跳阶/漂移→状态机+路由）/代码熵（过度工程/造轮子→拼装+懒阶梯）/上下文熵（过期信息滞留→指纹感知+交接压缩）——三治面正交，失控先命名熵类再选治法。
- **A/B/C 证据分级口径**（upstream-baseline 口径注）：A=本机实测/B=官方一手直查/C=二手转述；媒体报道指针默认 C 级，未经核实不得写入引用基线列——本轮四仓指针全部重核后才登记。

### Changed
- 认知面预算第七次逐例登记 303104→317440B（实测 313499B，功能性增量非注记膨胀：懒生成 4.0KB 随发 + code-graph-tools 三选型扩容 4.3KB + comet 七机制 2.5KB + mcp-governance 1.6KB + review 1.1KB 等，不构成先例）；基线表 16→17 行（口径注/表题/行数同步，FACT_RUNTIMES=13 不变——codegraph 是图谱平权选型非接线运行时）；FACT_REFERENCES 44→45、FACT_UNIVERSAL_FILES 70→71；README 外部方法论 12→13 份；门禁 55 不增（决策 26/27），零新 check_*。

## [v2.15.4] - 2026-09-18

> R36 全量回归轮：栈轮换第四棒到 Go（gin + gorm + go-redis + MySQL，Go 1.27 真实工具链编译/vet/测试通过），真实场景项目（r36-drill-order-api 订单服务）生成目标技能，走完流A 全流程（探查→清单→填充→conf→hooks→门禁→独立审查→写回→mark-active 三道关）与流B 典型研发任务执勤（订单取消需求全链 proposal→spec→状态机逐级推进→TDD→28 门禁→独立审查→verify 证据→archive；取消原因字段变更三件套；指纹自成长感知→重探查→清单更新→边集重建→落新基线；spec-first hook 与 rules.d 三值拦截正反实测），识别并修复 10 处缺陷 + 1 处基线追账。共性根因第四次复现（R28"相邻路径"、R30"只认一种形态"、R33"生态系统性缺位"）：本轮 D2-D4 为 Go 生态形态在探测表与维度枚举器缺位，D1 为 G24 同款性能问题在四个同族循环漏修——修一个不扫同族。

### Fixed
- **self-check --check-only fork 风暴 11min35s→40s（R36-D1）**：G20 多字节/G22 sed 方言/G10 版本 oracle/R13 层间引用/G24 内层共五处逐行 `printf|grep` 循环改为单 awk 向量化。全角标点用字面量交替（awk 正则字节级，字符类 `[）。，…]` 会误匹配任意 CJK 第二三字节）；`\b` 无 awk 支持改词边界等价式。G24 注释自证"逐条 grep 190 文件实测 2min+ 不可接受"并已修自身，同族四循环漏修。输出与修前逐字节一致，五处均过违规注入变异验证（保持检出力）。
- **框架探测 gomod 信号 Go 生态零覆盖（R36-D2）**：detect-frameworks 框架表 gomod 行仅 kratos/gin/gorm/terraform 四族，go.mod 含 `github.com/redis/go-redis/v9`、`gorm.io/driver/mysql` 双双漏报（Java/Py/Node 的 redis/mysql 各有 pom/pyreq 行）。补 redis（go-redis/redigo）与 mysql（gorm driver/go-sql-driver）四行，执勤项目实测 gin+gorm → gin+gorm+redis+mysql。
- **维度枚举缺 gin 大写动词形态（R36-D3）**：后端 controller/接口端点两维度正则只认 JS 小写 `router.get` 与 Java 注解，gin `v1.GET(...)` 全漏（实测 6 路由/6 端点枚举全 0，仅靠 ENUM_ZERO_DIM 披露兜底），而 `references/frameworks/gin.md` §2 自带正确正则——仓内两处矛盾。补 `\.(GET|POST|PUT|DELETE|PATCH)\(`；并补测试文件排除（httptest 测试路由注册计入端点，实测 7 生产路由+1 测试注册=8 vs 清单 7 → 0.875 假 FAIL，R36-D3b——端点是生产面维度）。修后 7/7、7/7 真实对账。
- **数据模型维度 Go 形态恒 0（R36-D4）**：R33-D4 补的包约定形态是 Java 点分语法 `package x.model;`，对 Go 单标识符 `package model`（无点无分号）恒 0——`--include='*.go'` 是死配置；gorm struct tag `gorm:"` 强特征亦缺位。补单标识符包声明与 gorm tag 两形态，实测 0→4 文件。
- **check_reuse skip 态叠加假 pass（R36-D5）**：无 spec 时 skip_if_unconfigured 落账后函数不返回，继续走 AI 自查指引并打印「✓ 复用合规检查通过」——汇总=skip 对、门禁输出与 trace=done 错，三处呈现分裂。skip 后 `return 0`；非证据模式 trace 状态推导补 skip 态（与证据模式五态 fail>skip>warn>pass 对齐）。
- **check_deps/check_knowledge 自定义 target-dir 失明（R36-D6）**：基线 codebase.md 与 spec 探测硬编码 `$PROJECT_DIR/.claude/skills` 默认安装位，target-dir 生成的技能自带 references/codebase.md 不可见（warn 误导补配）。补技能自身 references/ 兜底（precheck 启动期解析的 `_CONF_DIR` 绝对路径——运行期 BASH_SOURCE 相对路径在 `cd $PROJECT_DIR` 后失效）与项目 SPEC_GLOB 约定位兜底，共三处。
- **stability-audit fan-in 对 Go 包导入恒 0（R36-D7）**：fan-in 以文件基名字符串找引用方，Go 导入的是包路径（`internal/repository`）不含基名 `order_repo`——实测 internal/ 下全部文件误报 fan-in=0。对含斜杠路径补父目录字符串代理信号，误报 14→9（余量全为真实"无同名测试/禁改却变更"披露）。
- **relations-extract 重建清空 AI 语义边（R36-D8）**：边集重建整文件覆盖，AI 按流程补充的 route/call 等语义边在每次自成长重建时丢失（执勤实测 17 行→11 行）。重建保留非机械 kind 边（exact 去重幂等），摘要行新增"AI 语义边保留 N"。
- **gate-rules"尾 \* 可省"语义对 3+ token 失效（R36-D9）**：行格式注释称 `npm publish *` 命中裸命令，实现只对首两 token 生效——`docker compose down -v *` 对裸命令四路 case 全不中，FORBID 静默降级 prompt。补 CMD 对 `_pat_base` 的前缀匹配（裸命令与带任意尾参均命中）；test-gate-rules 补态 4b（3+ token 裸/带参两断言）。
- **conf 自洽性：READONLY_DIRS 覆盖 SPEC_GLOB 无告警（R36-D10）**：docs 设为只读而 spec 约定落 docs/specs/ 时，spec-first 流程每次写 spec 即触发 check_scope fail（流程自我打架，执勤真实踩中）。conf 加载后 warn 提示调整（不阻断，配置意图因项目而异）。
- **基线追账**：FACT_SCRIPT_LOC 6425→6468（本轮 D5/D6/D10 改四门禁脚本 +43 行，self-check 机械计数复核后登记）；守门测试 test-gate-rules 态 4b。

## [v2.15.3] - 2026-09-17

> R33 全量回归轮：基线排查（self-check 揭税制超标与 LOC 漂移两处追账）后，轮换到 Java 栈（R28 Python→R30 Node→本轮 Spring Boot 3.2.5 + MyBatis XML + Lombok + JUnit5/Maven，JDK 25 工具链）真实场景项目（r33-drill-inventory-api）生成目标技能，走完填充、mark-active 三道关、库存预警需求研发全链（proposal→spec→状态机逐级推进→TDD→门禁→独立审查→archive）、清单核验、关系边集、指纹自成长，识别并修复 7 处缺陷 + 1 处引导缺口。共性根因第三次复现（R28"相邻路径"、R30"只认一种形态"）：Java 生态形态在维度枚举器与机械信号里系统性缺位。

### Fixed
- **清单计数把骨架标准表头计成数据行（R33-D1）**：A7 修复把表头关键词锚定在"首格任意位置"，而模板自家两列表头 `| 路径 | 说明与约束 |` 的"说明"在第二格——表头行被计入清单（每表 +1 虚高，实测 §6 双表 6 行计成 8），叠加枚举侧膨胀放大成假 FAIL。改为关键词首格开头锚定（数据行以反引号路径开头，判别可靠）；同族正则在 `_list_count` 与 `_extract_rows_paths` 两处同改（inventory-verify.sh + test-inventory-verify 补态 16）。
- **controller 维度枚举正则无边界（R33-D2）**：`@(Get|Post|...|RequestMapping|Controller)` 前缀匹配把 Lombok `@Getter` 误作端点（`@PostConstruct` 同理），类级 `@RequestMapping`/`@RestController` 非端点也计数——Java 枚举虚高 50%（实测 12 命中 vs 8 真实端点）。改精确注解名 `@(GetMapping|PostMapping|...)`；类级注解承载的项目会低估，低估方向安全（capped 1.0 PASS + ENUM_ZERO_DIM 披露兜底）优于高估假 FAIL（inventory-dimensions.conf + test-inventory-verify 态 17）。
- **接口端点维度 Java 分支是死正则（R33-D3）**：`@(Get|Post|...)\\(` 要求注解名后紧跟括号，而 Spring 实际形态是 `@GetMapping(...)`（Get 后面是 Mapping）——该分支在任何 Spring 项目恒 0 命中，Java REST 项目端点维度整体失效（全靠 ENUM_ZERO_DIM 披露兜底）。同 D2 改精确注解名，裸注解（路径继承类级）也命中（inventory-dimensions.conf + test-inventory-verify 态 17）。演练项目实测 0 → 9 端点全检出。
- **数据模型维度缺纯 MyBatis 实体形态（R33-D4）**：plain MyBatis 实体无任何注解标记（@Entity/@TableName/BaseMapper< 全不命中）恒 0 枚举。补包约定形态（`package ….(domain|entity|entities|model|po|pojo);`，dto/mapper/service 包天然排除）；XML `resultMap type=` 反查因文件计数粒度错配不采纳，以披露兜底（inventory-dimensions.conf + test-inventory-verify 态 17）。演练项目实测 0 → 3 实体。
- **ORM schema 维度在 lite 档恒 NO_LIST（R33-D5）**：`DIM_ORM_SCHEMA_RM_REF='§8'` 单锚，而 lite 档 reference-manual 精简为 §4/§6/§9 三节——模型↔迁移漂移防线（漏改字段防线的姊妹缺陷）在 lite 档无处核验。RM_REF 支持空格分隔多锚（'§8 §9'，合计行数）：standard/compliance 登 §8 数据字典、lite 自然落 §9 数据勾稽，两档皆核验（inventory-dimensions.conf + inventory-verify.sh _list_count 多锚 + test-inventory-verify 补态 18）。
- **指纹排除链缺 Maven target/（R33-D6）**：.git/node_modules/dist/build 都排了，Java 主流构建目录 target/ 没排——25 个 .class/.jar/.lst 计入基线，每次 mvn build 后 `--diff` 误报「项目已变化」，自成长链被构建噪音反复误触发。补 target/.gradle/venv/.venv（与 DIM_DATA_MODEL 排除链同源对齐；project-fingerprint.sh + test-project-fingerprint 补态 16：构建产物新增后 --diff 不误报）。
- **稳定性审计两处形态盲区（R33-D7）**：①controller 等入口层由路由引用而非 import，fan-in 恒 0 是框架常态——恒吃「标注稳定但 fan-in=0」warn（入口层信号豁免）；②greenfield 仓库 forbid 标注文件的"出生提交"即 1 次变更——恒吃「禁止改但变更」warn（阈值 >1，出生后又被改才算）。演练项目 warn 26 → 22，残留为"无同名测试"类真信号（inventory-verify.sh + test-inventory-verify 补态 19/20）。
- **框架 glob 填充交接缺口（R33-F1，引导+执法双修）**：--inject-frameworks 注入 ACTIVE_FRAMEWORKS 后 conf 里留一组空的 `<FW>_SRC_GLOBS` TODO，但 SKILL.md 填充指引不提、mark-active 不核验——填充 AI 漏填时框架门禁全部静默空转（扫不到文件），门禁形同虚设。双修：填充指引新增 conf 条目（检测到框架才出现）；mark-active 增逐检出框架核对（`<FW>` 前缀变量两份 conf 至少一个已填非空值，缺即拦）。实现侧两踩 set -euo pipefail 雷区：grep 无命中管道赋值静默 exit 1（|| true 兜底）、`[[ ]] && cmd` 条件假即杀（改 if）——本轮各实测踩中一次（generate-skill.sh + run-gen-e2e 补 R33-F1 正反断言）。

### 基线追账（self-check 揭示，随本轮修复）
- **FACT_ARTIFACT_BYTES_BUDGET 298544→303104**：实测 299581B 超 1037B，成因=R31/R32 运行时补核注记增量（补核轮不发版故未过断言，发版门补追账——R26 同源先例）。
- **FACT_SCRIPT_LOC 6411→6425**：R30 两修（check_reuse 语义修正 + check_test 零用例左边界）改 gates-*.sh +14 行未同步。
- **FACT_SKILLMD_BYTES_BUDGET 8704→9216**：R33-F1 填充指引 conf 条目的功能性引导增量。

### 验证
- 全量 30 单元测试 + gen-e2e + 79 规则集/fixture 双态 + self-check 全绿；修复版工具对演练项目复验：接口端点 0→9、数据模型 0→3、controller 假 FAIL→PASS、迁移资产 §9 登记可核验、构建产物指纹噪音归零。

## [v2.15.2] - 2026-09-16

> R30 全量回归轮：基线全绿后，在 Express+TypeScript+Prisma+Jest 真实场景项目（shop-api）上生成目标技能，走完门禁执勤、spec-first 研发全流程（低库存端点：proposal→spec→状态机逐级推进→TDD→失败注入）、fingerprint 感知、自成长升级、清单核验、关系边集、mark-active 分离存放全链，识别并修复 7 处缺陷。共性根因延续 R28：探查/检测层"只认一种形态"（Prisma schema、大写 Router、版本号子串），另有门禁语义拧反（check_reuse 拦正常拼装）与状态机跳级穿透两处深 latent。

### Fixed
- **test-check-impact-baseline 相对路径调用必红（R30-D1）**：GATES/ASSETS 定格写在 cd 舞步之后，`cd tests` 后裸文件名调用时 `$0` 相对路径在错误 cwd 下解析（`./..` 连升两级落到仓库根），态 1-5 全红。CI（`working-directory: swarm-yuan` + `bash tests/...`）相对路径恰好自洽故绿——本地最自然的调用形态必红，再次印证 CI 绿≠流程可用。同族扫描 31 测试仅此一处（test-check-impact-baseline.sh）。
- **模板永久文案自缚占位符检测（R30-D2）**：verify-completeness 占位符词表（待填充/（待填充）/<占位符>/填充指引）把生成器 heredoc 写进目标技能的永久说明 blockquote（reference-manual 两区纪律口径等 5 处）一并命中——`--mark-active` 永久死锁，AI 按报错删行的最小动作连带丢失方法论口径。5 处永久说明改词「填充规范」；真占位符（frontmatter description/标题）保留检测；`_nav_design` 行改指激活后仍存在的位置；交接清单区加显式整区删除指引（generate-skill.sh + 新增 test-template-lexical-consistency：静态 4 断言 + 端到端真生成零误伤）。
- **check_test 零用例正则无左边界（R30-D3）**：npm run 横幅 `> shop-api@0.1.0 test` 的版本号尾 0 与脚本名构成 `0 test` 子串即命中——一切版本号以 0 结尾的 npm 项目每次执勤假报「空跑通过不算兜底」，warn 噪声淹没真信号。首分支加左边界 `(^|[[:space:]])`；版本号内不再命中，行首/空白后形态照常（gates-warn.sh + test-check-test-zero-runs 补态 7/8）。
- **inventory 探查缺 Prisma 与大写 Router 形态（R30-D4）**：DIM_DATA_MODEL_CMD 缺 Prisma 声明式强特征（`^model` + `*.prisma` include）——schema.prisma 3 模型项目枚举恒 0（R28 修 SQLAlchemy 的同构相邻形态，且 R28 条目"覆盖 Prisma"实为未覆盖）；DIM_API_ENDPOINT_CMD 只认字面小写 `router.`——express 生态主流 `<name>Router.get(` 全漏，5 端点只中 1。另：枚举 0 + 清单非空时比率防除零给 1.00 PASS、枚举器自身漏报完全静默——新增 ENUM_ZERO_DIM advisory 披露行（inventory-dimensions.conf + inventory-verify.sh + test-inventory-verify 补态 15/15b）。
- **关系边集单层 ../ 的 to 键残留 ./ 前缀（R30-D5）**：`_norm_rel` 的 `../*` 分支单层场景 dir=`dirname(base)`="." 直接拼进输出——tests/ 目录 `from '../src/x'`（主流测试形态）的边 to 落成 `./src/x`，与 src/ 侧同目标边的干净路径键失配（--stable-diff 反查/查边集按 to 对账断链）。base/dir 更新同源，顶层"."不进输出前缀（relations-extract.sh + test-relations-extract 补态 4d）。
- **状态机 transition 只拦回退不拦跳级（R30-D7）**：open 直达 `transition verify` 实证成功（verify 准入 tasks.md 缺省降级跳过）——design 的 proposal 准入与 build 的 spec 批准（SPEC_REQUIRED=1 spec-first 硬防线）被单次跳跃整体绕过，六阶段守卫形同虚设。前跳限一阶，跨级报出被跳过阶段并提示逐级推进路径；逐级合法转换不误伤（state-machine.sh + test-state-machine 补态 4/5）。
- **init 覆盖确认非交互场景 exit 0 静默无效（R30-D8）**：交互 read 在 AI/CI stdin 下立即 EOF → confirm 空 → exit 0——rc=0 但状态未重置，调用方（自动化执勤正是主战场）误信 init 成功，后续 transition 全落在旧 change 上（本轮演练实证）。非交互环境无 --force 时 ERROR exit 1（rc 语义明确）；`init <name> --force` 显式覆盖；交互终端保留 y/N 确认；附带分发透传 `${3}`（--force 原传不到函数）（state-machine.sh + test-state-machine 补态 6）。
- **check_reuse 重名检测语义拧反（R30-D9）**：awk 默认空白分字段取 `$2` 非表格列语义，且 spec-template §5.5「新增胶水代码」表首列口径就是文件路径——胶水落在既有文件内正是拼装式开发的推荐形态，路径对比恒重名，任何正常 spec 必 fail；该门禁此前零守门测试。`-F'|'` 按表格列取首列；路径形态单元格不参与重名对比；单元名形态保留拦截（gates-strict.sh + 新增 test-reuse-gate：真实 precheck.sh --reuse 入口三态，不 stub 内部函数）。

## [v2.15.1] - 2026-09-16

> R28 全量回归轮：完整链路实战回归（基线全绿后，在 FastAPI+SQLAlchemy+pytest 真实场景项目上生成目标技能，并走完门禁执勤、失败注入、fingerprint 感知、自成长升级、清单核验、关系边集、状态机、mark-active 全链），确认 6 处缺陷全修。共性根因：R25-PF1/PF2 修复的"相邻路径"未覆盖——探查层只认一种形态、机械层只做了半程实现。

### Fixed
- **Python 测试命令形态（执勤实证 taskflow-api）**：纯 requirements.txt 项目（无 pytest.ini/pyproject）探查产出 `TEST_CMD='pytest'`，裸 pytest 不把 cwd 注入 sys.path，check_test 收集 `from app.main import app` 必 ModuleNotFoundError——生成的门禁在主流形态项目上必 fail。改为 `python3 -m pytest`（`-m` 语义注入 cwd，对有配置项目等价；与同函数 unittest 兜底的 `python3 -m` 口径一致）。根因是 R25-PF1 只验证了"已声明 pytest→可执行"，未验证"可执行→可收集"的相邻路径（conf-render.sh + test-conf-render 态 8 同步）。
- **inventory 数据模型维度缺 SQLAlchemy**：DIM_DATA_MODEL_CMD 覆盖 JPA/MyBatis-Plus/Mongo/Prisma/mongoose/sequelize，唯独缺 SQLAlchemy 声明式强特征 `__tablename__=`——Python 生态最主流 ORM 在 fastapi+sqlalchemy 项目必漏报 0（inventory-dimensions.conf + test-inventory-verify 态 13d 守门）。
- **关系边集 Python 绝对导入恒 0**：relations-extract 原实现只认相对导入（`from .x import y`），注释声称"绝对导入 best-effort 根解析"但无对应分支——FastAPI/Django 等绝对导入主流项目（PEP 8 推荐）import 边恒 0。补绝对导入提取（包路径转目录试探，与 Go module 前缀剥离同构；子模块符号用 `find -name` 精确命中，防 macOS 大小写不敏感 FS 误命中并 emit 失真路径）。实测演练项目 0 边 → 26 条（relations-extract.sh + test-relations-extract 态 4c 守门）。
- **状态机未知阶段名误导报错**：`transition implement`（合法为 build）先打「阶段转换」横幅再报「不能回退」——横幅+回退话术双重误导。阶段名合法性前置校验，未知名直接报「未知阶段」并列出合法值；phase 字段写坏同样显式报错（state-machine.sh + 新增 test-state-machine.sh 守门）。
- **状态机 conf 接线消费占位符**：骨架模板 precheck.conf 的 `PROJECT_DIR="<项目根绝对路径>"` 在 draft 未回填期被 `_sm_conf_val` 当真实值消费，状态文件落进 cwd 下字面量垃圾目录。占位符形态（`<...>`）视为未配置，回退默认（state-machine.sh + test-state-machine 态 0 守门）。
- **mark-active 分离存放形态决策双账失效**：技能与项目分离存放（CI 产物目录）时，decisions.jsonl 双账回退链两路皆空——PROJECT_DIR 未导出、skill_dir 上三级不再是项目根。从 conf 提前读出 PROJECT_DIR（占位符不导出）导出后即闭环，实机验证分离副本 draft→active 通过（generate-skill.sh）。

### 验证
- 全量 28 单元测试 + 3 e2e（gen/e2e/fieldchange）+ 79 规则集/fixture 双态 + gate-fixtures 全组 + bash -n 全语法面，修复后复跑零失败；修复点典型场景重演（新生成产物 TEST_CMD/边集 26 条/数据模型枚举 3）逐项断言通过。

## [v2.15.0] - 2026-09-15

> 支付行业 profile + 领域知识镜像 + 跨平台门禁轮（R26 批次收口）：行业档从七传统行业扩到第八档"支付"（业务机理+技术实现融合，与 finance 立法视角正交互补）；支付领域知识实体（《支付之门》/规范全文/冲突裁决库）镜像入仓，迁移机器后引用可达；新增跨平台可移植性门禁（G24），把 Windows Git Bash/麒麟老 bash 的兼容性从散文纪律升级为机器执法。

### Added
- **支付行业 profile（`industry-profile-payment.md` + `payment.conf`，第八档）**：吸收 hermes pay-team 四人格（清算结算/支付基础设施/监管合规/路由）知识内核——清算vs结算/RTGS·DNS/央行四系统（HVPS/BEPS/超网/CIPS）/三方对账五类差错/复式记账 + 通道对接/快捷支付四要素/账户分账/幂等冲正 + 牌照/备付金/AML/数据合规/数字人民币。`--industry payment` 真实加载（conf-render 枚举+断言集同步）；`payment.conf` 覆盖包承接支付特有敏感字段（卡号/CVV2/磁道/交易密码）+ 国密 + PIA + 授权 + SBOM + 发布签名 + 对账勾稽。FACT_REFERENCES 42→43。
- **领域知识镜像（`vendor-knowledge/`）**：支付知识库实体 24M/300 文件镜像入仓——顶层自研内核（索引/内核框架/监管梳理/known-conflicts 冲突裁决）走普通 git；`standards/`(20M)/`books/`(2.1M)/`fulltext/`(1.8M) 版权材料走 git LFS（学习研究用途）。`_shared/` 裁剪四论四问/语言规范/输出契约三文件。源头嵌套 .git 已剥除（gitlink 修正）。
- **镜像同步脚本（`scripts/sync-vendor-knowledge.sh`）**：`sync` 从 `~/.hermes` 拉取 + `--check` 完整性校验；跨平台（bash 3.2+/Git Bash/WSL/麒麟/macOS），rsync 缺失降级 cp -R，源头嵌套 .git 自动剥除。
- **跨平台可移植性门禁（G24）**：self-check 新增机械检查——裸 mktemp（补 `${TMPDIR:-/tmp}` 模板）/ GNU-only 命令（tac·grep -P·`sed -i` 无后缀·`readlink -f`）/ bash4 特性（declare -A·mapfile·`${var,,}`）；检查器文件整文件豁免防自报误报，文件级预筛 0.015s。与 G20 多字节/G22 sed 方言同范式。

### Fixed
- **跨平台兼容性 14 处**：13 处裸 `mktemp`/`mktemp -d` 补 `${TMPDIR:-/tmp}` 模板（防 BSD 无模板崩溃/CWD 污染）；`precheck.sh` `tac` → awk 倒序缓冲（GNU/BSD 双兼容）；`verifier/v1/run-verifier.sh` 裸 `mktemp -d`（G24 门禁实证抓到）。
- **payment/finance 重叠清冗**：payment.md §1.3 数据合规原重述 finance 立法条款（JR/T 0171 分级/个保法/PIA/密评），改为指向 finance 的落地指针；finance.md §0 加边界交叉引用——立法条款归 finance、支付业务机理归 payment，双向路由防双源漂移。
- **卫生**：移出误入的 mapstruct fixture `target/` 构建产物，`.gitignore` 补 `target/`/`*.jar` 规则。

### 诚实边界
- 麒麟/Windows 真机未实测：兼容性靠"静态扫描 + macOS BSD/bash 3.2 实证 + G24 门禁机械化"三层间接保证；真机回归须在对应机器跑 `self-check --check-only` 与 `install.sh --list`。
- vendor-knowledge 版权实体（书籍/专栏/规范全文）为 LFS 管理、学习研究用途：克隆机须 `git lfs pull` 取回实体，公开仓分发时指针降级为知识地图（详见 `vendor-knowledge/MANIFEST.md`）。
- 本轮 vendor 束（gstack/superpowers/ECC 源码）无变更，不发 src 包（v2.8.0 起口径）。

## [v2.14.3] - 2026-09-15

> 字段级边 + 文档证据源轮（排查补全驱动）：v2.14.2 发版后实测发现两个新缺口——边集只到文件级（改字段只能定位到 XML 文件，不能定位到具体字段行）；需求/设计文档作为证据源完全空白（无优先级规则、无冲突声明、无 PDF/Word 转换流程）。本轮补齐这两项，并修复 v2.14.2 发版时埋下的 CI 红（预算锚漏测骨架文案增量）。

### Fixed
- **CI verifier-all 红修复（预算锚追记）**：`FACT_SKILLMD_BYTES_BUDGET` 8320→8640——v2.14.2 登记时只实测了清单区 +160B，漏测自成长段"边集重建/核验"口径文案 +329B + relations-query.sh 入清单 +51B + 项目根绝对路径占位余量（gen-e2e 用绝对路径回填，本地 worktree 路径深 106 字符 vs CI ~70）。连续三次估算低估（忘测文案/字符宽度/路径占位）的教训固化：预算例外登记必须对产物全量实测，不拆维度估算。gen-e2e 与 verifier all 本地 RC=0 复验绿。

### Added
- **字段级边（`field-mapping`）**：relations-extract.sh 在 resultMap 内提取 `<result column="x" property="y">` 明细边——evidence 带 `column=property` + 行号，改实体字段的影响面反查从"定位到 XML 文件"细化为"定位到具体字段行"。统计行纳 field-mapping 计数。
- **边集反查工具（`relations-query.sh`，随发）**：执勤侧按实体类/字段名/XML/文件四模式反查引用点——`--field userName` 出引用该字段的全部 resultMap 行（改字段必查）；`--entity User` 出引用该实体的全部 XML；fail-open 只读不重建。消费方：流B ②探查影响面、spec §20.1 变更影响段、数据模型变更配方三查。
- **研发侧消费指引挂接**：spec-template §20.1 变更影响范围段补"改实体字段/数据模型时边集三查"指引（声明式耦合点 grep 源码查不全）；workflow.md 骨架节点②探查质量门禁补同条款。
- **文档证据源优先级（B1）**：exploration-guide 新增"文档证据源优先级"表——代码为准/为主（当前真实行为）、设计文档为辅（架构决策意图/外部交互设计/数据契约）、需求文档仅需求分析参考；**冲突声明义务**（文档与代码不一致须在 spec 假设与约束段显式声明 + 以代码为准 + 建议文档更新）。template-spec §1.5 补"②.5 文档冲突声明"格式段。
- **文档转换流程（B2）**：exploration-guide 新增"文档转换决策"——PDF→pdftotext/pdfplumber、Word→pandoc/python-docx、图片→OCR+mermaid、Excel→openpyxl 表格转 markdown，转换产物入 docs/converted/（入 git 可追溯）；提取去向 reference-manual §5.2 文档证据注记（架构决策意图）+ §6 外部交互契约（API/MQ/数据库/第三方）。

### 诚实边界
- 字段级边只覆盖 MyBatis resultMap 的 `<result column property>` 明细（`<id>`/`@TableField`/JPQL 字段引用未入 field-mapping，归 §8 字段级映射台账）。
- 文档转换是探查期指引（AI 按流程执行），无门禁执法（转换质量靠 spec 评审 + reference-manual 注记复核）；docs/converted/ 是否入 git 由项目自行决定（建议入，可追溯）。
- 上下文表面预算首次例外登记 180000→184000（B1/B2/A1/A2 方法论文档增量 +4628B，非注记膨胀）；UNIVERSAL_FILES 68→69（relations-query.sh 随发）。

## [v2.14.2] - 2026-09-15

> 执勤侧自包含轮（实测定案驱动）：v2.14.1 发版后对生成产物实测发现——边集/清单的**重建与核验工具不随发**到目标技能。分析能覆盖 MyBatis XML（v2.14.0/2.14.1 已修），但项目演进后要在执勤侧重建边集/核验清单，必须回生成器侧跑 `relations-extract.sh` / `inventory-verify.sh`——闭环在执勤侧不自包含。本轮把三个工具随发，执勤侧拿到完整重建/核验能力，无需回生成器。

### 痛点与根因
- `relations-extract.sh`（边集重建/--verify 断边）与 `inventory-verify.sh`（清单计数核验/path-check）只存在生成器仓，**不在 `UNIVERSAL_FILES` 随发清单里**——`mark-active` 的抽样核验读的是生成器侧副本（路径通），但生成完成后目标技能目录里没有这两个脚本；项目演进后想重建边集/核验清单，执勤侧无工具可用。
- 维度注册表 `inventory-dimensions.conf` 是 inventory-verify 的数据源，同样不随发——即使拷来脚本也缺配置。

### Fixed
- **三工具随发（自包含执勤）**：`scripts/relations-extract.sh`、`scripts/inventory-verify.sh`、`assets/inventory-dimensions.conf` 入 `UNIVERSAL_FILES`（lite 档起随发）。两脚本零外部依赖、自洽（inventory-verify 仅读随发的 `assets/inventory-dimensions.conf`；relations-extract 无外部引用）。实测：生成产物内对样本项目实跑边集重建（mapper-binding/data-mapping 出边）、清单核验（消费随发维度注册表）、断边核验（`--verify` 抽样）全链路通过。
- **骨架口径同步**：自成长段的"核验：生成器侧 inventory-verify.sh"更新为本地自包含表述（脚本已随发，无需回生成器）；新增"边集重建"条目。

### 口径与预算登记
- `FACT_UNIVERSAL_FILES` 65→68、`FACT_UNIVERSAL_FILES_CORE` 37→40（+3 工具随发，机械计数同步）。
- `FACT_SKILLMD_BYTES_BUDGET` 首次例外登记 8192→8320：实测产物 8234B 超 42B，成因=三工具入随发清单后骨架文件清单区如实新增 3 行（+160B，生成物文件清单=执勤手册的功能信息增量，非叙事膨胀）。对齐 FACT_ARTIFACT_BYTES_BUDGET 逐例登记先例，不构成先例。

### 诚实边界
- 随发的是**工具脚本**，执勤侧重跑时的**方法论指引**（exploration-guide §C+）仍回生成器仓读（既定设计：方法论不随发，防目标技能膨胀）。
- `relations-extract.sh --verify` 在执勤侧是 advisory（fail-open），断边提示重建不阻断执勤。

## [v2.14.1] - 2026-09-14

> 声明式字符串耦合横向清剿轮：把 v2.14.0 在 MyBatis XML / Spring Batch 暴露的"字符串耦合分析缺失"模式横向排查到全部主流技术栈，确认并修复四类同型缺口。排查方法学：凡是"编译器不校验、import 依赖边不含、清单无维度"的三不管字符串引用，都是漏改字段的同型炸点。

### 排查矩阵（六类声明式耦合 × 处置）
- **映射文件↔代码**：MyBatis ✅（v2.14.0）；JPA orm.xml / hibernate hbm.xml ❌→✅ 本轮入边集；Prisma/GraphQL schema/proto 确定性不足机械提取 → 方法论台账覆盖。
- **字段名字符串**：MapStruct @Mapping 经核实**编译期注解处理器已校验**（漏改即编译红，非静默缺陷）——不重复造门禁；JPA @Query JPQL 实体/字段名编译不查（容器启动才解析）→ 新门禁。
- **拓扑名配对**：Kafka/RabbitMQ 端点名是**双边字符串**（生产者写一个名、监听器听另一个名，改一边编译过、启动正常、消息静默断链）→ 双栈新配对门禁 + 消息拓扑配对表方法论。
- **模型↔迁移漂移**：Django 漏 makemigrations / GORM tag↔DDL / alembic/flyway/liquibase/prisma migrations 全家 → 新 DIM_ORM_SCHEMA 维度 + Django 漂移门禁 + Layer 5 链路泛化。
- **模板绑定 / 配置装配**：Spring beans XML `<bean class=>`→Java 装配边入边集（bean-wiring）；yml↔@Value 由 Spring 启动 fail-fast 自兜底，不重复执法。
- 调度信号补盲：DIM_SCHEDULE_JOB 增 @XxlJob/ElasticJob（国产调度栈）。

### Added
- **relations-extract.sh**：+Spring beans XML（`<bean class="a.b.C">`→Java，kind=`bean-wiring`）与 JPA orm.xml/`*.hbm.xml`（`<entity class=>`/`<class name=>`→实体，kind=`data-mapping`）声明式边；文件判据按 XML 根元素内容（含 `<beans`/`<entity-mapping`/`<hibernate-mapping`），只解析全限定名（短名机械不猜）。
- **DIM_ORM_SCHEMA 维度**：prisma schema / Django migrations / alembic / flyway（`V*__*.sql`）/ liquibase changelog / orm.xml / hbm.xml / `schema*.sql` 全枚举 → §8 数据字典机器计数核验；`--path-check` 抽取面扩至 §8（迁移文件路径同样验真）。
- **四个新门禁**：`fw_kafka_topic_pair`(warn，生产/消费 topic 字面量双向 diff)、`fw_rabbit_endpoint_pair`(warn，含原生 basicPublish)、`fw_jpa_jpql_entity`(warn，@Query JPQL from/join 实体名在源码集定位)、`fw_django_migration_drift`(warn，有模型零迁移=漏 makemigrations 信号；有迁移 pass 带 --check 提示)——四规则集规律各 +1（kafka-r14/rabbitmq-r13/django-r14/spring-data-jpa-r14）。
- **方法论扩充**：exploration-guide §C+.2-B Layer 5 泛化到 ORM 全家（JPA/GORM/Django/SQLAlchemy/Prisma/TypeORM/Sequelize 逐栈主线 + 模型↔迁移漂移"第五查"）；§C+.2-A 新增**消息拓扑配对表**（端点名/生产侧/消费侧/序列化/幂等五列，单边端点显式登记）；template-spec §5/§8 对应章节要求同步。
- **集中式双态测试** `tests/test-fw-declarative-gates.sh`：四门禁命中态 + 不误报态各一；test-relations-extract 态 6（Spring/JPA XML 边）；test-inventory-verify 态 14（DIM_ORM_SCHEMA 计数/漏列/排除链）。

### 诚实边界
- MQ 端点配对只比**字面量**——常量引用（`send(topicVar)`）与配置中心 topic 提不出字符串，天然跳过；跨服务/外部系统单边是正常形态，故 warn 级人工核对而非 fail。
- JPQL 校验到实体名级；字段级（`o.status`）静态解析成本高，归 §8 字段级映射台账。
- django 迁移漂移门禁只能判"零迁移"强信号与"有迁移"提示态，增量漂移（改模型没生成新迁移）静态不可判，提示 `makemigrations --check`。
- MapStruct 字段字符串（@Mapping target/source）经核实由编译期 processor 校验，本轮不加门禁（避免重复执法面）；其静默面（新增目标字段漏映射）仍由 unmappedTargetPolicy=ERROR 规律覆盖。

## [v2.14.0] - 2026-09-14

> 数据映射依赖分析补全轮（研发反馈驱动）：一线反馈用生成的目标技能做研发时**漏改了字段**——改实体字段后 mapper XML 与批处理任务没有同步。排查确认这不是门禁失职，而是**探查层结构性盲区**：mapper XML 的 resultMap property、SQL 列名、批处理 reader 的 SQL 列都是**字符串耦合点**——编译器不校验、import 依赖边不含 XML、组件清单没有数据模型维度，四道防线对同一类耦合集体失明。本轮在探查（边集+清单+链路模型）与执法（字段级门禁）两层补全，并把"改实体字段"这类高频任务固化为配方与场景回归。

### 痛点与根因
- **字符串耦合点零边集**：`relations-extract.sh` 只提代码 import 边；MyBatis XML 的 `namespace`→Mapper 接口、`resultMap type`→实体完全不在边集里。流B 探查"改 X 影响谁"时查不到 XML——而 XML 恰恰是漏改后编译不报错、运行期静默丢值的地方。
- **清单维度缺失**：`inventory-dimensions.conf` 8 个维度无一覆盖数据模型实体、mapper XML、定时/批处理任务——机器计数核验不约束，AI 填清单可整维跳过。
- **链路模型缺口**：后端链路最深追到 repository→ORM→DB，没有"实体↔表列↔resultMap↔SQL 列"的数据映射链，也没有"job→reader/processor/writer→读写数据资产"的任务链——批处理不在请求管道里，import 边查不全它的数据依赖。
- **门禁粒度不够**：mybatis 门禁只有"接口数=namespace 数"的数量级检查，没有字段级一致性——漏改字段后门禁全绿。

### Added
- **声明式映射边（探查层）**：`relations-extract.sh` 新增 MyBatis 边提取——`mapper-binding`（namespace→Mapper 接口）与 `data-mapping`（resultMap/resultType/parameterType→实体）；`mybatis-config.xml` 的 `<typeAlias>` 别名映射优先解析，短名按全工程唯一同名类命中，多命中不出边（机械不猜）；`target/` 构建产物排除。改实体字段时 `--stable-diff` 与流B 探查都能把 mapper XML 拉进影响面。
- **数据映射三维度（清单层）**：`DIM_DATA_MODEL`（ORM 实体→§9）、`DIM_MAPPER_XML`（SQL 声明层→§9）、`DIM_SCHEDULE_JOB`（@Scheduled/Quartz/Spring Batch/celery beat 任务入口→§5）进 `inventory-dimensions.conf` 机器计数核验；`--path-check` 路径验真面扩展到 §5 任务表。
- **数据映射链路与任务链路（方法论层）**：exploration-guide §C+.2-B 新增 Layer 5 数据映射链路（Mapper 接口↔XML↔实体字段↔表列，产出字段级映射台账）；新增 §C+.2-J 定时/批处理任务链路（触发器→job→reader SQL 列/processor 字段访问/writer mapper 方法→读写数据资产表）；语义边 kind 扩展 `mapper-binding`/`data-mapping`/`job-flow`；template-spec §5/§8/§9 填充要求与 recipes"数据模型变更配方"三查要素（查边集/查台账/查任务表）同步落地。
- **字段级门禁 `fw_mybatis_field_sync`（执法层）**：resultMap 的每个 `property` 必须能在 `type` 指向实体（含一层 extends 父类）中以词边界找到——判定宽松防误报（实体中任意出现即算同步，重命名后旧词完全消失才 fail）。漏改字段从"运行期静默丢值"前移为"门禁期拦截"。mybatis 规则集规律第 19 条 + 门禁清单第 18 条同步。

### 使用指南
- **生成侧**：无需新参数——探查到 MyBatis/调度信号时边集与三维度核验自动生效；生成的 reference-manual 会多出 §5 调度任务表与 §9 模型映射表。
- **研发侧（改实体字段）**：先查 `relations.jsonl` 中 `to=实体` 的 `data-mapping` 边反查全部 mapper XML，再查 §8 字段级映射台账定位 property/SQL 列，最后查 §5 任务表定位读写该数据资产的 job——三查齐了再动手，改完跑 `--framework` 让 `fw_mybatis_field_sync` 兜底。
- **验证资产**：新增 `tests/e2e/run-fieldchange-e2e.sh` 场景回归（生成目标技能→改实体字段漏改被拦→同步修复闭环→新增定时任务清单执法），把本轮修复的完整事故链固化为可复跑回归。

### 诚实边界
- `fw_mybatis_field_sync` 判定是词边界宽松匹配——实体注释中出现旧字段名会算作同步（宽松设计换低误报，极端场景靠 §8 台账人工核对）；实体类多文件同名时跳过该 resultMap（机械不猜，AI 按 §C+.2-B 补）。
- Spring Batch/Quartz 的 job→数据资产边是语义边（reader SQL 内嵌列名无确定性映射），机械层只出 MyBatis XML 边；job-flow 边由 AI 按 §C+.2-J 链路模型逐条补。
- 认知面预算第四次例外登记 274432→278528B（本轮功能性增量 3818B，逐例登记）；FACT_SCRIPT_LOC 补记 R25c 欠账 6387→6409。

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
