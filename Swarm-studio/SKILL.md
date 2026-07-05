---
name: ncwk-dev
description: "SwarmStudio hermes-overlay 二次开发全流程技能。触发关键词: hermes-overlay, cockpit, matrix-chat, kanban, patch inject, overlay, custom 注册, vitest, vite.config.overlay, 二次开发, 拼装式开发, ncwk. 覆盖 patch 注入、custom 注册、拼装优先、SQLite、NaiveUI、特征卡 14 项全覆盖。"
---

# ncwk-dev — SwarmStudio hermes-overlay 二次开发全流程技能

> 项目形态：overlay 层（patch + custom 注册），注入 hermes-studio 上游（v0.6.25）。
> 核心理念：**拼装式开发** — 优先复用既有稳定单元，禁止重复造轮子、侵入式重构、破坏性改造。

## 核心理念与项目定位

- **项目类型**：Vue 3 + NaiveUI 桌面应用（SwarmStudio），overlay 注入式二次开发
- **overlay 仓库** `overlay/`（hermes-overlay v0.6.22-overlay, type:module, node>=23）— **唯一可改目录**
- **upstream** `upstream/hermes-studio/`（v0.6.25）— **只读**，仅 `git pull` 同步
- **改造机制**：upstream 变更经 `overlay/patches/`（109 patch 文件）构建时 `npm run inject` 注入；custom 组件经 `@registries/client` 注册接入
- **改造分类**：A类（custom/ 纯新增）+ B类（patches/ 骨架修改）
- **技术栈**：Vue 3 + TypeScript + Vite + NaiveUI + Vitest + SQLite + Koa + Electron
- **端口**：8647（后端 Koa）/ 8649（前端 Vite dev）/ 8650（Agent health）

## 十条铁律

1. **仅改 overlay/**：严格禁止修改 upstream/（见 AGENTS.md）
2. **版本锁定**：不随意升级核心依赖（precheck `--deps`）
3. **安全规范**：遵守 OWASP Top 10（precheck `--security`）
4. **拼装优先**：新功能 = 既有稳定单元拼装 + 最小新增胶水代码（precheck `--reuse`）
5. **分支规范**：feat/fix/refactor，基于 main，merge --no-ff（precheck `--branch`）
6. **A类/B类分类**：A类放 custom/（Vite alias），B类放 patches/（git apply）
7. **inject 幂等**：`npm run inject` 可重复执行，`npm run clean` 可回滚
8. **测试先行**：custom/**/*.test.ts，37 个测试文件，vitest 运行
9. **release 规则**：仅上传 arm64.dmg + x64.zip 2 种文件
10. **不自动推送**：除非用户明确要求，不推送至 GitHub

## 命令速查

| 用途 | 命令 |
|------|------|
| dev | `cd overlay && npm run dev`（:8649） |
| build | `cd overlay && npm run build` |
| test | `cd overlay && npm test` |
| inject | `cd overlay && npm run inject` |
| clean | `cd overlay && npm run clean` |
| verify | `cd overlay && npm run verify` |
| build:full | `cd overlay && npm run build:full` |
| build:dmg:mac | `cd overlay && npm run build:dmg:mac` |
| 后端服务 | `cd overlay && bash scripts/serve-server.sh &`（:8647） |

## 全流程总览（八节点）

```
①需求理解 → ②设计spec → ③实施plan → ④分支准备 → ⑤编码实现 → ⑥测试审查 → ⑦合入main → ⑧构建发布
```

每节点开始前先读取项目最新知识（AGENTS.md/CLAUDE.md/记忆）。

## 门禁速查

| 门禁 | 检查什么 | 命令 |
|------|---------|------|
| --branch | 分支命名 | `bash scripts/precheck.sh --branch` |
| --scope | 改动范围（overlay/ vs upstream/） | `--scope` |
| --build | 构建通过 | `--build` |
| --test | 测试通过 | `--test` |
| --security | OWASP Top 10 | `--security` |
| --reuse | 复用合规 | `--reuse` |
| --deps | 依赖版本锁定 | `--deps` |
| --all | 核心 10 门禁 | `--all` |
| --all-full | 全部 25 门禁 | `--all-full` |

## 完成检查表

- [ ] 分支规范（feat/fix/refactor）
- [ ] 改动范围（仅 overlay/）
- [ ] 构建通过
- [ ] 测试通过
- [ ] 安全无硬性违规
- [ ] spec §5.5 复用约束已填
- [ ] 依赖版本未变更（或已声明）
- [ ] 无占位符残留
