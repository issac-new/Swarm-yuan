# swarm-yuan 范式决策记录（Paradigm Decisions）

> 日期：2026-07-20 ｜ 分支：`chore/leftover-suggestions`
> 记录 7 项遗留建议的处置决策与理由，供后续版本维护参考，避免重复调研。

## 处置总览

| # | 建议 | 决策 | commit |
|---|------|------|--------|
| 1 | `_resolve_path` 左结合 bug | ✅ 修 | `d31ca48` |
| 2 | GNU grep -E 下 `\|` 字面 | ❌ 不修（保留原始行为） | — |
| 3 | 测试覆盖扩展（26 门禁 fixture + CI） | 🟡 部分（CI 骨架做，26 fixture 留长期） | `74bb244` |
| 4 | offline-cache 迁移 Release | ✅ 做（不做 filter-repo 瘦身） | `1c412f2` + `2e7b...` |
| 5 | 片段内既存小瑕疵 | 🟡 部分（dubbo/seata/vue 修，sentinel 不修） | `f893f73` |
| 6 | 生成器增强（SKIP_BAT） | ✅ 做 | `2f37607` |
| 7 | 本决策文档 | ✅ 做 | 本 commit |

## 逐项决策理由

### 建议 1：`_resolve_path` 左结合 bug —— ✅ 修

**问题**：`cd "$dir" && pwd -P || cd "$dir" && pwd` 在 bash 左结合下解析为 `((cd && pwd -P) || cd) && pwd`，正常路径执行两次 pwd 返回两行值，`-f "$cand"` 永远 false，`check_layer §3/§6`、`check_contract §2` 沉睡。

**修复**：方案 C 直接 `cd && pwd -P`（POSIX -P 三平台兼容），失败走原回退。

**苏醒后发现的第二个 bug**：修复 _resolve_path 后 `check_layer §3` 苏醒，立即暴露 §1 的 glob 解析 bug——`base=${g%%/\**}` 最长匹配把 `overlay/custom/client/*/components/**` 误截成 `overlay/custom/client`，find 扫整个 client 目录，把 `__tests__/adapters/composables` 全归入 component 层，§3 误报 249 个假违规。改 `base=${g%/\**}` 最短匹配 + compgen -d 展开 glob。修复后 ncwk-dev `--layer` 从 249 假违规降到 0。

**教训**：沉睡门禁修复后会暴露下游 bug，需用真实项目样本验证苏醒后行为。

### 建议 2：GNU grep -E 下 `\|` 字面 —— ❌ 不修

**问题**：`ROLLBACK_KEYWORDS` 等 5 个变量用 `\|` 在 `grep -E` 下是字面 `|`，部分匹配永不命中。

**决策**：保留原始行为。修复会改变门禁判定（让沉睡匹配苏醒），与建议 1 同性质但影响面更大（5 个变量 × 多处 grep），且无样本可预测苏醒后行为。

**后续**：留独立版本决策，若要修需逐变量评估苏醒影响 + 补 fixture。

### 建议 3：测试覆盖扩展 —— 🟡 部分做

**做了**：`.github/workflows/ci.yml` CI 骨架 4 个 Job（57 verify + 57 fixture + self-check + shellcheck）。触发：push/PR 到 main。

**未做**：26 个非框架门禁（`--scope/--sensitive/--layer` 等）的 fixture。工作量大（每个门禁要造 violating+compliant 双态），留长期扩展，按同范式补齐。

**理由**：CI 骨架能防回归是高 ROI；26 门禁 fixture 是长期工程。

### 建议 4：offline-cache 迁移 Release —— ✅ 做（部分）

**做了**：
1. 打包 `swarm-yuan-offline-cache.zip`（44MB，含 graphify-wheels + npm + gstack + superpowers）
2. 上传到 GitHub Release `v2026.07.20-offline`（https://github.com/issac-new/Swarm-yuan/releases/tag/v2026.07.20-offline）
3. `install-offline-win.sh` 开头加降级链：本地 cache 不存在 → curl 从 Release 下载 → 降级在线安装
4. `.gitignore` 忽略 `*.whl/*.tgz/gstack/superpowers/`；`git rm --cached` 停止跟踪 37 文件（本地保留）

**未做**：`git filter-repo` 历史瘦身（改写历史 + force push 风险高，留独立决策）。历史 blob 32MB 保留在 .git，但今后不再增长。

**与 memory 全局规则关系**：不冲突。"仅 arm64.dmg + x64.zip" 针对 SwarmStudio 桌面应用；swarm-yuan 是 skill 仓库，现有 8 个 Release 全为 .zip，本附件延续 .zip 惯例（与 `v2026.07.12-offline` 的 59MB zip 先例一致）。

### 建议 5：片段内既存小瑕疵 —— 🟡 部分修

**修了**：
- dubbo.sh:25 / seata.sh:27 删 `|pom.xml`（被 `*.xml` 遮蔽，死分支，机械等价）
- vue.sh 10 处消息前缀 `vue:` → `fw_vue_<id>:`（与 vue.md §4 命名规范一致，退出码等价）

**未修**：sentinel.sh 内联 grep。A/B 类收益小（19 处单文件 if grep -qE 强改收益小），C 类 5 处 `-qiE` 不等价（`_fw_grep_count` 不支持 `-i`），D 类 4 处需要文件列表/行号/匹配内容（`_fw_grep_count` 只给计数无法替代）。整体非必要。

### 建议 6：生成器增强 —— ✅ 做

**做了**：`generate-skill.sh` 的 `copy_universal_templates` 加 `SKIP_BAT` 环境变量，设 1 跳过 .bat 复制（macOS/Linux 用户无需 .bat，让 skill 目录更干净）。默认 0 保持兼容（仍复制 7 个 .bat）。

**未做**：snippets.md / mcp-tools.md 是静态参考文档（非模板），create 模式仍复制，upgrade 模式若用户已修改则保留（现状已如此，无需改）。

### 建议 7：本决策文档 —— ✅ 做

记录上述 6 项决策，供后续版本维护参考。

## 不做的事（汇总）

- 建议 2（grep `\|` 字面）：保留原始行为，留独立版本决策
- 建议 3 的 26 门禁 fixture：工作量大，留长期扩展
- 建议 4 的 `git filter-repo` 历史瘦身：force push 风险高，留独立决策
- 建议 5 的 sentinel 内联 grep：收益小/有风险

## 风险与缓解

- **建议 1 苏醒 check_layer §3**：已用 ncwk-dev 实证（249 假违规 → 0），且修复了连带暴露的 glob 解析 bug
- **建议 4 Release 迁移**：不删历史 blob（只停止跟踪），install-offline-win.sh 加本地 cache 优先逻辑保证已有 cache 不受影响
- **建议 6 SKIP_BAT**：默认 0 保持兼容，只影响显式设 1 的用户
