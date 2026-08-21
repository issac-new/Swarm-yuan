> **归档标注（2026-08-21 v3 整合）**：本文已并入 `docs/DESIGN.md` §0 冲程三（机械 vs AI 边界）——DESIGN.md 是单一设计事实源；本文保留为历史原文档（不再单独维护，内容以 DESIGN.md 为准）。

> **档案标注（2026-08-21）**：本文已并入 `docs/DESIGN.md` §2.2（范式作为条件）——DESIGN.md 是单一设计事实源；本文保留为机械 vs AI 边界复盘（历史）的历史原文档（不再单独维护，内容以 DESIGN.md 为准）。

# Q2-heavy 评审报告：机械门禁 vs AI 灵活性的边界（D1/D2/D4）

**评审背景**：Q2 报告（"机械门禁/脚本扫描破坏 AI 灵活性"）的深水区单独评审。WP-Q2-lite 已收
failure-detector 去重 + tone 软化 + trace-log --key-node 三件套，但还有三条更深的问题需要拍板。

**评审方法**：把 54 门禁按"机械信号 vs AI 判断"二分，给出三个维度（D1 探索式 / D2 假装可机器 /
D4 流程过度脚本化）的边界清单。

---

## D1：探索式 gate 移除/rewrite —— 哪些门禁应改为 AI 自觉判断

**判定原则**：门禁的输出是否确定可信？
- 可信（exit 0/1 与断言一致） → 保留机械
- 不可信（启发式/易误报/依赖工具版本） → 转 AI 自觉判断（advisory 级保留，不机械 run）

**转 AI 自觉判断的候选（advisory → 文档化提示，不再机械跑）：**

| 门禁 | 现状 | 问题 | 建议 |
|------|------|------|------|
| `check_cognition` | grep + wc -l 数 5 个维度 | 5 维度本质是认知框架清单，AI 读 reference 即可 | 转文档化（"检查 cognition 5 维度"），不再机械 grep |
| `check_consistency` | 术语↔代码 grep | 误报高（同名词多） | 保留但降为「提醒人工核对」模板 |
| `check_link_depth` | graphify/madge 深度 | 工具依赖重，未装降级统计纯转发函数 | 转可选（OFF=1 时不跑） |
| `check_diagram` | 检测 mermaid/plantuml | 启发式，AI 看图即可 | 转 AI 自觉判断 |
| `check_decision_audit` | decisions.jsonl 格式 | 格式机械可查，但"决策是否合理"是 AI 判断 | 保留格式校验，删"合理性"判断 |
| `check_state` | state.yaml 字段 | 字段机械可查，但状态是否合理是 AI 判断 | 保留字段校验 |
| `check_pr_quality` | 各种 wc -l + grep | 启发式强，AI 看 diff 即可 | 转 AI 自觉判断 |
| `check_operate` | HTTP/health-check 探活 | 探活机械可信，但"运营是否合理"是 AI 判断 | 保留探活，删"合理性"判断 |

**保留机械（信号可信，误报少）：**
- `check_layer` / `check_branch` / `check_security` / `check_sensitive` —— grep + 模式匹配确定
- `check_requirements` / `check_rtm` —— spec 结构化字段机械可查
- `check_test_evidence` / `check_review_record` / `check_release_sign` —— 文件存在性机械可查

---

## D2：taste vs mechanical —— 哪些门禁"假装可机器"

**判定原则**：fail/warn 是否每次都能指向真实问题？

**误报高的（应转 advisory 或重写信号）：**

| 门禁 | 误报成因 | 建议 |
|------|---------|------|
| `check_consistency_cross` | 术语↔代码 grep，同名词/缩写误报 | 转 advisory（已 advisory，但 warn 级别仍输出） |
| `check_stable_diff` | "稳定"标注 vs 实际改动 | 改 inventory-verify --stability-audit 接管（已做） |
| `check_adr` | ADR_DIR 不存在 fail 太硬 | 改 warn（已 advisory，但 ADR_DIR 还是 fail） |
| `check_framework` | 框架规则 grep 启发式 | 按 fw 分组，没装 fw 时跳过 |
| `check_knowledge` | 知识库存在性 + grep 规律 | 知识库缺失不算 fail，仅 warn |
| `check_sast_deep` | semgrep/lexical 启发式 | 未装时 warn，不 fail |
| `check_metrics` | 覆盖率/复杂度启发式 | 未配置时 skip_if_unconfigured |
| `check_crypto` | 加密配置 grep | 启发式强，AI 看代码即可 |
| `check_oss_eval` | SBOM/license 启发式 | 无 SBOM 工具时降级 |
| `check_docs_pack` | 文档存在性机械可查，但"文档质量"是 AI 判断 | 保留存在性，删质量判断 |

**taste 类（AI 判断，不应机械化）：**
- 组件复用是否重复造轮子（AI 看语义，不只 grep 重名）
- 架构决策是否合理（ADR 质量）
- spec 是否清晰可执行（不是结构化字段就能保证）
- 测试是否覆盖关键路径（不是文件存在性）

---

## D4：生成流程过度脚本化 —— 哪些环节应让 AI 判断

**现状**：generate-skill.sh 17 步骨架创建 + 8 节点 workflow + state-machine.sh 阶段追踪。
**问题**：有些环节是"AI 应该自己判断"（非机械流程），但目前脚本化了。

**应让 AI 判断的环节：**

| 环节 | 现状 | 问题 | 建议 |
|------|------|------|------|
| Step 2 特征卡提取 | extract-feature-cards.sh 机械 | 17 项特征卡本质是 AI 阅读 spec 后的判断 | 脚本只做"模板化输出"，特征值 AI 填 |
| Step 4 组件库清单 | inventory-verify 机械计数 | 已硬化（WP-Q1A）防幻觉 | 保留现状 |
| Step 5 conf 填充 | conf-render.sh 嗅探+模板 | 嗅探机械可信，但"是否需要该门禁"是 AI 判断 | conf-render 出初稿，AI 审 |
| Step 6 框架深化 | framework-evidence 机械 grep | 框架规律本质是 AI 对项目代码的理解 | 机械只做"证据存在性"，规律实例化 AI 做 |
| Step 7 hooks/commands 生成 | generate-skill 模板化 | 模板固定，但"目标 skill 是否需要这些 hooks" 是 AI 判断 | 默认全开，AI 删 |

**保留机械的环节（确定性高）：**
- 骨架创建（generate-skill.sh 文件复制+占位符）—— 纯机械
- precheck.conf 模板渲染（conf-render.sh）—— 嗅探+模板机械
- 占位符清零（verify_completeness）—— 机械 grep
- 状态门（--mark-active）—— 机械规则
- 门禁分级 enforce_level 加载 —— 机械 conf 读

---

## 综合建议（不动代码，仅评审结论）

1. **advisory 档 15 个门禁里，5 个转 AI 自觉判断**（cognition/diagram/pr_quality/consistency/link_depth 中的"质量判断"部分），其余 10 个保留机械信号但删掉"合理性"判断（只报存在性/格式）。
2. **warn 档 25 个门禁里，7 个降级为 advisory**（consistency_cross/stable_diff/framework/knowledge/sast_deep/metrics/crypto），避免误报打断主流程。
3. **strict 档 20 个门禁不动**——这 20 个信号可信、误报少，机械运行合理。
4. **生成流程**保留机械骨架创建 + conf-render + verify_completeness + mark-active + enforce_level；特征卡提取/框架规律实例化/hooks 选择这三个环节转"机械出初稿 + AI 审"模式。

**下一步**：
- 用户拍板是否进入实施（Q2-heavy D1/D2/D4 改造）
- 若实施，预计 4 个 worktree（advisory 降级 / warn 降级 / 生成流程 AI 化 / 文档同步）
- WP-Enforce2/3 待 Q2-heavy 结论（若 advisory 大量降级，Enforce2/3 需要重新评估范围）
