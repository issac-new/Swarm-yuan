# mermaid 门禁 fixture 语义登记

`check_mermaid`（--mermaid，架构图/流程图/调用链 Mermaid 可视化检查）**永不 fail**：
函数体内无 `fail()` 调用，`found` 恒为 0，缺图仅 `warn`，退出码恒为 0。

因此本门禁的「违规语义态」无法以 `violating/`（期望退出非 0）承载，
改用 `compliant-*` 命名（runner 期望退出 0）+ `expect-output` 断言 warn 文案：

| fixture | 语义态 | 断言 |
| --- | --- | --- |
| `compliant/` | reference-manual.md 含 ```mermaid 代码块 | expect-output 命中「含 Mermaid 可视化」pass 行 |
| `compliant-warn-no-diagram/` | 纯文字手册，无 Mermaid 图 | expect-output 命中「未检测到 Mermaid 图」warn 文案；末尾 pass 行仍打印（warn 与 pass 共存） |

门禁行为真值来源：`assets/precheck.sh` `check_mermaid()` ——
探测 `references/reference-manual.md`（及备选路径）是否含 ```` ```mermaid ````
或 `<mermaid`；缺则 warn 提示架构/流程/调用链须用 Mermaid 可视化。
