# diagram gate-fixture（R13 后语义）

check_diagram 自 WP-Q2H-A/R13 起 转 AI 自觉判断模式（机械 grep 分支退役，
GATE_AI_JUDGMENT 恒 1）：输出固定引导文案（自查要点 + notes 留痕提示 + advisory pass 行），
子组输出一致——原机械双态区分（含图/无图、深链/浅链）已随机械分支退役。
样本源码保留（给 AI 判断场景提供真实上下文）。

# diagram 门禁 fixture 语义登记（原 mermaid，升级为多图表引擎）

`check_diagram`（--diagram，原 --mermaid 别名仍兼容；架构图/流程图/调用链 + 统计/分布/趋势可视化检查）**永不 fail**：
函数体内无 `fail()` 调用，`found` 恒为 0，缺图仅 `warn`，退出码恒为 0。

双引擎按内容选图表：结构关系图（依赖/调用链/分层矩阵/流程/C4）用 mermaid（GitHub 原生渲染）；
数据统计图（分布/趋势/指标对比）用 echarts/antv option JSON 代码块。

因此本门禁的「违规语义态」无法以 `violating/`（期望退出非 0）承载，
改用 `compliant-*` 命名（runner 期望退出 0）+ `expect-output` 断言 warn 文案：

| fixture | 语义态 | 断言 |
| --- | --- | --- |
| `compliant/` | reference-manual.md 含 ```mermaid 结构图 + ```echarts 数据图 | expect-output 命中「含 mermaid 结构图」「含 echarts/antv 数据图」pass 行 |
| `compliant-warn-no-diagram/` | 纯文字手册，无任何图表 | expect-output 命中「未检测到可视化图」warn 文案；末尾 pass 行仍打印（warn 与 pass 共存） |

门禁行为真值来源：`assets/gates-advisory.sh` `check_diagram()` ——
探测 `references/reference-manual.md`（及备选路径）是否含 ```` ```mermaid ````/```` ```echarts ````/```` ```antv ````
或对应标签/初始化代码；缺则 warn 提示按内容选恰当图表引擎。
