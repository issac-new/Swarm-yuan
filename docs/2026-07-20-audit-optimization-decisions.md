# 范式审计与迭代优化决策记录（2026-07-20）

> 分支：`fix/audit-optimization`（已合入 main）｜ 触发：`/goal 全面分析 swarm-yuan skill，排查设计理念/实现机制/实现文件问题并迭代优化`
> 方法：4 个并行子代理审计（设计理念 / precheck 机制 / 生成器+生命周期 / 57 门禁+fixture），全部结论经主会话**独立复核**（读代码路径 + 实跑复现）后才处置。

## 审计结论总览

**算术骨架真实成立**（独立复核确认）：27 个门禁 flag ↔ 27 个 `check_*` 函数一一对应；核心 10 + 架构 17 = 27；precheck.conf = 146 变量；57 框架三件套（规则 md / 门禁片段 / fixture）1:1:1；32 领域；57/57 fixture 双态绿。

**但因果链在真实配置上被四类问题削弱**：① 沉睡/崩溃（set -e + pipefail + 空数组）；② 未配置门禁静默跳过，绿 ≠ 合规；③ 存在性门禁对范式自带模板自证；④ 文档头部数字无单一事实源 → 漂移。

## 已修复（5 批，均带验证）

| # | 严重级 | 问题 | 修复 | commit |
|---|--------|------|------|--------|
| 1 | CRITICAL | `check_shift_left` 三处 grep 缺 `|| true`，set -e+pipefail 下 `--all-full` 在 framework/test 门禁前中断（实测复现：输出停在「运维监控左移」，框架+测试门禁永不执行） | grep 管线末加 `|| true` | `61f2af6` |
| 2 | HIGH | `--all`/`--all-full` 分发循环中，单门禁 fail 路径非零返回（check_scope:339 等）触发 set -e，中断后续 8-9 个门禁 | 分发循环加 `|| true`（FAIL 全局仍正确汇总） | `61f2af6` |
| 3 | HIGH | 7 处空数组 `"${ARR[@]}"` 在 bash 3.2 崩溃（unbound variable），`_default_conf` 默认空数组时触发 | 改 `${ARR[@]+"${ARR[@]}"}` 防护 | `61f2af6` |
| 4 | MED | `check_stable_diff` glob 前缀 `%%` 最长匹配 bug（`paradigm-decisions.md` 已在 check_layer 修过的同款） | `%%` → `%` 最短匹配 | `61f2af6` |
| 5 | HIGH(fail-open) | `generate-skill.sh --inject-frameworks` 缺闭标记时 awk `skip=1` 到 EOF，静默删除区块后公共库+main 分发（无备份不可恢复） | 校验双标记，缺闭标记即中止不改动文件 | `61f2af6` |
| 6 | 文档漂移 | USAGE.md/PROMO.md 停留 14特征/25门禁/45变量/架构15/10运行时；SKILL.md 正文 10运行时（frontmatter 本就 11）；framework-signal-index 漂移（koa 缺 socket.io） | 全部同步至真值 16/27/146/11；索引重生成 | `2817185` |
| 7 | 机制 | `check_doc_consistency` 只 grep SKILL.md，抓不到 USAGE/PROMO 漂移；门禁函数计数 `[a-z]+` 漏数下划线（23≠27） | 新增跨文档数字一致性检查（从代码算真值扫散文）+ 索引时效检查 + 计数口径修复 | `2817185` |
| 8 | chore | Swarm-studio 通用文件过时（批次 1/2 修复未同步） | `SKILLS_PATH_REWRITE --upgrade` 重同步，恢复填充型文件，清理 backup/.bat | `d8568a8` |
| 9 | HIGH | verifier shellcheck 腿硬编码 `/mnt/agents/tools`，无 shellcheck 机器谎报 `SHELLCHECK_ERRORS 0` | 按 `$SHELLCHECK`→PATH→/tmp→/mnt 解析，均无则失败关闭报 `SHELLCHECK_UNAVAILABLE` | `7c8c69d` |
| 10 | HIGH | 修复 #1 移除崩溃掩盖后，ROLLBACK_KEYWORDS 的 `\|` 字面 bug 变成活跃误报（有回滚预案也 fail） | 单独修复 ROLLBACK_KEYWORDS 为 ERE 交替符（仅这个可达硬门禁；其余 4 处 warn-only 保留沉睡） | 本批 |

每批验证：`bash -n` 语法通过 + 57/57 fixture 双态绿 + e2e RC 0 + `--all-full` 最小 conf 实跑到 framework/test 门禁并正常汇总。

## 刻意不修（遵循范式「不贸然唤醒沉睡门禁」原则）

以下问题真实存在且为 HIGH，但修复会**改变门禁判定行为**，在无真实项目样本+fixture 覆盖的情况下，贸然修复可能「唤醒沉睡门禁 → 淹没真实项目误报」（`paradigm-decisions.md` 建议 1/2 的教训）。留作独立版本决策，每项需先补 fixture 再评估苏醒影响：

1. **五层认知基底是装饰性叙事**：`check_cognition` 含 **0 个 `fail()` 调用**（门禁永不 fail，仅对范式自带 spec-template 做关键词打分）；分数上限标注 `/11`（实际 14）`/19`（实际 22）错配。修复 = 重新设计该门禁的判定语义，不是改 bug。
2. **`\|` 交替符在 grep -E 下是字面**（5 处：ROLLBACK_KEYWORDS/BREAKING_DDL/METRIC/LOG/TRACE）：实测 `grep -ciE '回滚\|revert'` 对含两词的 spec 返回 0。**已部分修复**：ROLLBACK_KEYWORDS 经 `SPEC_FILE` 可达且是硬门禁，修复 #1 移除崩溃掩盖后实测会对「有回滚预案」的 spec 误报 fail（`✗ spec 无回滚预案声明`）——故单独修复为 ERE 交替符（见下「追加修复」）。BREAKING_DDL/METRIC/LOG/TRACE 四处是 warn-only 且已带 `|| true`，修复会让它们「苏醒」开始 warn（行为改变），按 `paradigm-decisions.md:31-36` 决策**保留沉睡**，留独立版本评估。
3. **存在性门禁对范式自带模板自证**：`--shift-left`/`--domain`/`--cognition`/`--impact` 在无项目 spec 时回退到 `assets/spec-template.md` 并对其空壳判 pass。`--reuse` 已修过同类（precheck.sh:830-836 注释），其余四处未修。
4. **SILENT 跳过洞**：`--all-full` 下未配置门禁静默消失（约 15 个），运行仍 conclude「✓ 门禁检查通过」，汇总不披露实际执行了几个。是「文档记录的设计」（precheck.sh:234），但汇总行过度声称。建议加跳过计数器（非破坏）。
5. **`check_link_depth` 兜底 GNU-only**（`grep -rzoP`，macOS/BSD 无效）→ pure_fwd 静默为 0（fail-open）；**madge 循环依赖 grep 可能永不命中**（verdict 走 stderr 被丢弃）。
6. **Swarm-studio 样例违反自家 v2 旗舰主张**：reference-manual §4 只 10 组件无签名/计数核验（README 称 15+），§6 用通配符 `/api/kanban/*`（template-spec 禁通配符），§9/辩证/领域段缺失；`precheck.conf:1` 硬编码作者机器绝对路径。修复 = 重填样例（内容工作，非 bug）。
7. **运行时数 9/10/11 三处漂移**（cognition-framework.md:116 说 9）——本次只统一了 SKILL/USAGE/PROMO 到 11；cognition-framework.md 的「9」涉及该文档自身叙事，留待确认是否同步。

## 遗留（低优先，未处置）

- `migrate_merged_frameworks` 写回多行 `ACTIVE_FRAMEWORKS` 会产生孤儿续行（MED，需非模板 conf 格式才触发）。
- `SKILLS_PATH_REWRITE` 会改写 self-check.sh 内运行时探测路径（MED，studio 实例 superpowers/ecc 检测受影响）。
- `state-machine.sh` 允许前向跳阶段（open→verify 守卫是占位 `pass`）。
- 5 个死 conf 变量（COGNITION_MAP/LOMBOK_ANNOTATIONS/TEST_DIR_PATTERNS/IMPL_DIR_PATTERNS/METRIC_ENDPOINTS）。
- 安装/自举层面：CI 从未对生成器仓库跑 27 门禁；26/27 非框架门禁无 fixture。

## 方法论备注

子代理审计的每条 HIGH/CRITICAL 结论，主会话都**独立复核**（读代码路径 + 写最小 conf 实跑复现）后才动手——子代理报告的「--all-full 中断」「空数组崩溃」「fail-open 注入」「USAGE 漂移」「认知门禁 0 fail」「\| 字面」六条全部经实跑确认属实。这避免了按二手报告误改门禁逻辑（本仓库的头号风险）。
