# 性能基线 before/after 对比报告（compare-baseline.sh）

- pre-opt 基线: `../verifier/baselines/pre-opt`
- post-opt 基线: `../verifier/baselines/post-opt`
- 诚实限制: 脚本无法观测模型 token；上下文表面=字节级代理，wall-clock=模型处理时间代理（有噪声）。本报告纯信息性，不设 pass/fail 阈值。

## 上下文表面（生成期必读面，字节/行数）

| 指标 | pre-opt | post-opt | 降幅 |
|------|---------|----------|------|
| TOTAL 字节 | 193226 | 156992 | 18.8% |
| TOTAL 行数 | 2144 | 1856 | 13.4% |

### 变更文件明细（pre vs post 字节/行数不一致项）

| 文件 | pre 字节 | post 字节 | pre 行 | post 行 |
|------|---------|----------|--------|---------|
| SKILL.md | 25585 | 27455 | 164 | 170 |
| references/exploration-guide.md | 101086 | 62979 | 1334 | 1040 |
| references/template-spec.md | 66555 | 66558 | 646 | 646 |

## 脚本耗时（wall-clock 样本）

| 脚本 | pre-opt | post-opt |
|------|---------|----------|
| detect-frameworks.sh fixture=angular 1s | detect-frameworks.sh fixture=android 1s |

## 门禁脚本 LOC/字节

| 文件 | pre LOC | post LOC | pre bytes | post bytes |
|------|---------|----------|-----------|-----------|
| assets/precheck.sh | 1406 | 1418 | 69865 | 71758 |
| assets/gates-strict.sh | 1418 | 1597 | 69645 | 79572 |
| assets/gates-warn.sh | 1416 | 1496 | 67117 | 71425 |
| assets/gates-advisory.sh | 878 | 1087 | 47572 | 57977 |

## 各 WP 贡献归因（信息性）

- WP-P1（信号索引数据化）: exploration-guide.md 瘦身 ~300 行（信号表外迁为 assets/framework-signals.md）
- WP-P2（inventory-verify）: 新增脚本，不直接降上下文表面（核验工作脚本化，模型少跑 grep）
- WP-P3（framework-evidence）: Step 4.5 模型读台账而非逐条跑 grep（62 文件 × ~5 规律的 token 池，最大降幅点，脚本侧不可直接观测）
- WP-P4（conf-render）: Step 8 模型只审 TODO:model 清单（从写 158 行变审+补少数，脚本侧不可直接观测）
- WP-P5（上下文裁剪）: 目标 skill 加载面按 profile 分层（lite/standard 裁 §14-18 + 认知三件套），用 `context-surface.sh --skill <lite-skill>` 对比可见
- 模型侧基线: 未自动采集（须手动跑一次生成落 baselines/pre-opt/model-side/，本报告如实披露未采集）
