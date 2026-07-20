# cognition 门禁 fixture 语义登记

`check_cognition`（--cognition，六阶认知链 + 六维动力学计分体检）**永不 fail**：
函数体内无 `fail()` 调用，计分不足仅 `warn`，退出码恒为 0。

因此本门禁的「违规语义态」（低分）无法以 `violating/`（期望退出非 0）承载，
两个 fixture 均为 `compliant-*`（runner 期望退出 0），用 `expect-output`
逐行断言确定性计分输出（git 相关的「速度」行等非确定性输出不断言）：

| fixture | 语义态 | 关键断言 |
| --- | --- | --- |
| `compliant/` | 仅术语表 + 分层定义 → 低分（认知断层） | `认知总分：4/14`、`第一层认知递进不足（4/14）`、`五层认知基底总分：4/22` |
| `compliant-full/` | 术语表/分层/聚合/服务/组件/状态/ADR/技术债齐全 → 第一层满分 | `认知总分：14/14 + 4 条规律编码`、`第一层认知递进完整`、`五层认知基底总分：14/22`（spec 故意最小化，第二~五层恒 0 分） |

门禁行为真值来源：`assets/precheck.sh` `check_cognition()` ——
①概念（GLOSSARY_FILE/reference-manual §4-6 单元表）→ ②结构（LAYER_DEFS/AGGREGATE_DIR/CONTEXT_DIRS）
→ ③空间（SERVICE_DIRS/COMPONENT_DIR/STORE_DIR）→ ④映射（术语↔代码漂移/分层↔目录/SOR_FILE）
→ ⑤规律编码 → ⑥处理关系（SPEC_FILE/ADR_DIR/TECH_DEBT_FILE），总分 14 + 规律数；
再叠加第二~五层（思维语言/认知辩证/偏差防范/辩证认知）得五层总分 22。
