> **何时读我**：任务命中本文档主题时按需读取（路由表见 SKILL.md）。首行：# 任务类型 × 方法论路由表（借鉴 tanweai/pua methodology-router 改写）

# 任务类型 × 方法论路由表（借鉴 tanweai/pua methodology-router 改写）

> 整合自 [tanweai/pua](https://github.com/tanweai/pua) 的方法论智能路由理念。
> pua 按「任务类型 → 大厂味道 + 方法论」路由（Debug→华为RCA、新功能→Musk Algorithm）。
> swarm-yuan 改写为「**任务类型 × 项目形态 → 生成流程节点序列 + 门禁聚焦**」——
> 不路由"味道"（swarm-yuan 无 PUA 话术），路由"该跑哪些节点 + 聚焦哪些门禁"。

## 核心理念

swarm-yuan 的 12 步生成流程是线性的（Step 1-12，唯一编号口径见 generation-flow.md），但不同任务类型的关键节点不同：
- **新项目生成**：全 12 步 + compliance 档合规矩阵
- **框架规则注入**：Step 3（探查框架）→ Step 7 内④.5（框架深化）→ ⑦.5（门禁注入）→ Step 11（记忆写回）+ framework-gates 四要素核验
- **升级已有技能**：Step 4（项目形态重判）→ Step 7（填充，保留 PROJECT_SPECIFIC_FILES）→ Step 11（记忆写回）→ Step 12（最终检查）
- **合规审计**：Step 5（特征卡含合规基线）→ Step 8（合规门禁配置）→ Step 9（集成拓扑）→ Step 12（fail-closed 核验）+ industry-profiles

**路由表的价值**：避免「所有任务都跑全量 12 步」的浪费，聚焦关键路径。

## 路由表

| 任务类型 | 触发信号 | 关键节点序列 | 门禁聚焦 | profile 档 |
|---------|---------|-------------|---------|-----------|
| **新项目生成** | `generate-skill.sh <name> <project-dir>`（无 --upgrade） | 全 12 步（Step 1-12） | --all-full（标准 27）+ 按需 --compliance-suite | auto（默认 standard，合规信号→compliance） |
| **框架规则注入** | `--inject-frameworks` 或 ACTIVE_FRAMEWORKS 变更 | Step 3（探查框架）→ Step 7 内④.5（框架深化）→ ⑦.5（门禁注入）→ Step 11（记忆写回） | 框架四要素核验（计数/规则/函数/约束）+ --framework <id> exit 0 | 继承现有 profile |
| **升级已有技能** | `--upgrade <name> <project-dir>` | Step 4（项目形态重判）→ Step 7（填充，保留 PROJECT_SPECIFIC_FILES）→ Step 11（记忆写回）→ Step 12（最终检查） | --verify-completeness + 维度计数核验 + 框架四要素 | 继承现有 profile |
| **合规审计** | `--compliance-suite` 或 compliance 档项目 | Step 5（特征卡含合规基线）→ Step 8（合规门禁配置）→ Step 9（四权分离拓扑）→ Step 12（Z3 fail-closed 核验） | --compliance-suite（合规 17：sbom/crypto/dengbao/pia/sast-deep/oss-eval/release-sign）+ 行业 profile | compliance |
| **占位符修复** | `--verify-completeness` 报占位符残留 | Step 7（填充缺失文件）→ Step 8（conf 占位符）→ Step 12（复验） | --verify-completeness --strict（列 file:line）+ self-check 数字漂移 | 继承现有 profile |
| **门禁 fail 修复** | precheck.sh --all-full 报 fail | Step 8（conf 调整）→ Step 10（重跑门禁）→ Step 11（记忆写回） | gate-runs.jsonl fail-id 级断言 + conf-render.sh 重嗅探 | 继承现有 profile |
| **数字漂移修复** | self-check.sh 报文档数字与 facts.conf 不符 | Step 7（文档同步）→ Step 12（self-check 复验） | self-check.sh --check-only（数字漂移检测） | N/A（生成器自身维护） |
| **Oracle Gate 循环** | `setup-loop.sh` 启动 | 无固定节点——AI 自主迭代直到 verify_command 通过 | verify_command（默认 self-check + precheck --all-full） | 继承现有 profile |

## 路由决策准则

1. **任务类型从命令/意图识别**：`--upgrade` → 升级；`--inject-frameworks` → 注入；`--compliance-suite` → 合规审计；其余 → 新项目生成
2. **profile 从项目特征识别**（auto_detect_profile）：合规关键词命中 → compliance；文件数 <80 → lite；其余 → standard
3. **门禁聚焦取并集**（质量优先取更重档）：任务类型基础集 + 规模档叠加，两者取并集
4. **Oracle Gate 是逃生舱**：常规路由搞不定时（self-check/precheck 持续 fail），启动无限迭代模式让 AI 自动修到通过

## 与 pua methodology-router 的差异

| 维度 | pua | swarm-yuan |
|------|-----|-----------|
| 路由对象 | 大厂味道（旁白风格）+ 方法论（行为约束） | 生成流程节点序列 + 门禁聚焦 |
| 路由依据 | 失败模式（原地打转/放弃/质量差/没搜就猜/被动等待/空口完成/思维固化） | 任务类型（新项目/注入/升级/合规/修复） |
| 切换信号 | PostToolUse hook 检测失败模式 → 切味道 | 命令参数 + 项目特征 → 选节点序列 |
| 切换后果 | 换旁白风格 + 换方法论步骤 | 换跑哪些节点 + 聚焦哪些门禁 |
| 叙事 | PUA 话术（阿里味/华为味/Musk味...） | 无叙事（swarm-yuan 用三权分立隐喻，不用 PUA） |

## 与现有机制的关系

- **与 task-type-gates.conf 的关系**：task-type-gates.conf 是「任务类型 → 门禁命令映射」（feature→--all-full；fix→--all --reuse），本路由表是「任务类型 → 生成流程节点序列」，两者互补——前者管运行什么门禁，后者管跑哪些生成节点。
- **与 profile 档的关系**：profile（auto/lite/standard/compliance）管生成什么文件集，路由表管跑哪些节点——compliance 档 + 合规审计任务 = 全节点 + 合规门禁聚焦。
- **与 Oracle Gate（E1）的关系**：路由表是常规路径，Oracle Gate 是非常规逃生舱——常规路由持续 fail 时切到无限迭代模式。
- **与四权分离拓扑（E3）的关系**：compliance 档 + 改治理资产任务 → 路由表指向 Step 7 强制走四权分离拓扑。

## 使用方式

AI 在 Step 0（开工）时读本表，按任务类型选节点序列 + 门禁聚焦，在 trace-log 公告路由结果：

```
→ [Step 0] 任务类型路由：合规审计 → 节点序列 Step 3/5.5/7/8 → 门禁聚焦 --compliance-suite + Z3 fail-closed
```

用户也可手动指定：`/swarm-yuan <项目路径> --task-type compliance-audit`（AI 按指定类型路由，不自动识别）。
