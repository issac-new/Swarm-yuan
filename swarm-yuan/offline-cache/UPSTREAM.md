# offline-cache 上游来源登记

供应链可审计性记录（GB/T 43848-2024 来源维度）。

| 组件 | 版本 | License | 上游仓库 | 获取日期 | 本地路径 |
|---|---|---|---|---|---|
| gstack | v1.60.1.0 | MIT © 2026 Garry Tan | https://github.com/garytan/gstack | 2026-07-20 | offline-cache/gstack/ |
| superpowers-marketplace | v1.0.13 | MIT © 2025 Jesse Vincent | https://github.com/obra/superpowers-marketplace | 2026-07-20 | offline-cache/superpowers/ |

## 注意事项

- `offline-cache/superpowers/` 为 **marketplace 目录仓**（市场元数据），**不含** superpowers 核心插件 v6.1.1 本体。
  核心插件须在线安装：`/plugin install superpowers` 或克隆 `https://github.com/obra/superpowers`。
- `offline-cache/gstack/` 为完整源码克隆（无 `.git`，供应链审计须以本表记录的 tag/版本为准）。
- MIT 许可证义务：分发副本须保留各自 `LICENSE` 文件中的版权声明与许可声明。
- gstack 含 opt-in 遥测（`SKILL.md:191-217`）；面向数据出境敏感场景，安装时提示用户可选择 `telemetry off`。
