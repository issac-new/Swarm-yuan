# swarm-yuan — 让 AI 懂你的项目，再写代码

> 从「AI 辅助写代码」到「AI 懂项目再写代码」的认知基础设施。

[![Release](https://img.shields.io/badge/release-v2.6.1-blue)](https://github.com/issac-new/Swarm-yuan/releases/tag/v2.6.1)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)]()

---

## 为什么需要它

AI 的代码生成能力已经很强，但「项目认知」仍是多数工具忽视的环节——改了不该改的文件、升级了不该升级的依赖、重复造了已有组件的轮子、检查靠人工逐行 review。

swarm-yuan 是**元技能生成器**：为任意代码仓库生成项目专属开发技能（目标技能）。核心闭环 = **探查**（全量组件库清单 + 调用链分析）→ **门禁**（三值规则 + hooks 强制）→ **自成长**（项目变了技能跟着变）。

---

## 三层架构

| 层 | 职责 | 关键机制 |
|----|------|---------|
| 特征卡（立法） | 让 AI 认识项目 | 探查产出特征项，每项落到真实路径与版本号，不用占位符 |
| 门禁（执法） | 守护代码合规 | 四族门禁全部有真实触发路径；rules.d 三值规则取最严；hooks 双宿主（Claude Code + Codex）真实拦截 |
| 验证器（司法） | 独立证明门禁有效 | fixture 双态 + cli 逐字节等价 + 合规套件 |

---

## 生成物规格

生成的目标技能 = **一张地图 + 一组条件 + 一条演化链**：

- **地图**：组件/接口/约束清单——两列表 `| 路径 | 说明与约束 |`，路径供 path-check 执法
- **条件**：precheck 门禁 + hooks + draft/active 状态门——做错就被拦，不占认知
- **演化链**：fingerprint 感知 → 局部重探查 → 单条更新 → 落新基线

生成物是薄的（每会话固定税 SKILL.md ≤8KB、概念体系 ≤5）；生成器是厚的（探查知识全量一次性消费）。

---

## 快速开始

```bash
# ① 安装（自动检测 Claude Code/Codex/Cursor/Windsurf/OpenCode/Gemini/Kimi）
git clone https://github.com/issac-new/Swarm-yuan.git && cd Swarm-yuan
bash install.sh            # macOS / Linux / Git Bash
# Windows：先装 Git for Windows（或 WSL），再双击 install.bat——Windows 原生 cmd/PowerShell 不支持

# ② 为项目生成技能（AI 一键完成）
# 对 AI 说："为 /path/to/project 生成开发技能"
bash scripts/generate-skill.sh <skill-name> <project-dir> [target-dir]

# ③ 激活（零占位符 + 路径存在性核验）
bash scripts/generate-skill.sh --mark-active <skill-dir>

# ④ 日常使用（对 AI 说话，零手动配置）
# "开始新需求：xxx" / "跑门禁" / "升级 skill" / "报了误报"
```

> **平台兼容**：macOS / Linux / Windows（Git Bash > WSL > MSYS2）三平台全支持，CI 矩阵背书。

---

## 运行时整合

**只引用不重新实现**，按接线深度分三层：

| 层 | 运行时 | 接线方式 |
|----|--------|---------|
| 深度接线 | GitNexus / graphify / claude-mem / ocr | 门禁内真实子进程调用，带多级降级链 |
| CLI 接线 | OpenSpec / comet / gsd-core / codex-security | 门禁按需调用 CLI，降级到自带载体 |
| 方法论引用 | superpowers / gstack / Ruflo / ECC / impeccable | AI 按 workflow 节点引用其模式 |

每层有自带降级载体——未装运行时不阻塞、不假装全深度接线。v2.6 已实证修复三类"已安装≠接线可达"盲区（签名/优先级遮蔽/schema 形态）。

---

## 质量基线

真值由 `assets/facts.conf` 机器执法（`self-check.sh`），文档不手抄数字：

- 门禁 55 项全部有真实触发路径（预算 55 冻结）
- references 全部带"何时读我"路由头（孤儿资产 = 0）
- 生成物税 SKILL.md ≤8KB、references ≤256KB
- 19 测试脚本 + gen-e2e + self-check RC=0（CI ubuntu/macos/windows 三平台）
- v2.6 回归收口：79 fixture 双态 / 48 合规 gate-fixture / cli 逐字节等价 / 双重点栈（vue+element 前端、SpringBoot+MySQL 后端）九节点真实交付验证

---

## 深入阅读

- `../docs/DESIGN-PRIMER.md` — 零背景入门（术语首现即定义）
- `../docs/DESIGN.md` — 单一设计事实源
- `../docs/paradigm-decisions.md` — 演化史与决策记录
- `references/case-studies/articulation-orchestration.md` — 落地案例
- `../docs/upstream-baseline.md` — 运行时上游版本基线

## License

MIT — see [LICENSE](../LICENSE)
