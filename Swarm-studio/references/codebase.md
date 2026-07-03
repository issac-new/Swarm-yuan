# codebase.md — SwarmStudio 代码库参考（reference §1）

> 本文件是 Swarm-studio 技能的代码库结构参考。开发前必读。

## §1 Workspace 布局

```
<project-root>/
├── overlay/                 # ← 所有开发在此（二次开发仓库，git 仓库）
│   ├── package.json         # hermes-overlay v0.6.22-overlay, type:module, engines.node>=23.0.0
│   ├── patches/             # B 类 patch（83 个活跃，series 文件排序）
│   │   └── series           # patch 顺序清单（非注释行=83）
│   ├── custom/              # A 类自有源码
│   │   ├── client/          # Vue 组件、store、composables（cockpit/matrix-chat/kanban/chat/branding）
│   │   │   └── test/setup.ts # 测试 stub（ResizeObserver/localStorage/matchMedia/i18n）
│   │   ├── server/          # Koa 后端（package.json CJS 无 type:module）
│   │   └── hermes-agent-plugins/  # Agent 插件（run-trace 等）
│   ├── registries/
│   │   ├── client/          # bootstrap.ts / entry.mts / index.ts（注册入口）
│   │   └── server/
│   ├── scripts/             # inject.mjs / verify-clean.mjs / ensure-injected.mjs / build.mjs / build-dmg.mjs / sync-upstream.sh / serve-server.sh / add-i18n-keys.mjs / generate-openapi.mjs
│   ├── packages/client/     # 客户端包
│   ├── packages/            # desktop（swarmstudio v0.6.23, electron）
│   ├── config/              # 配置
│   ├── assets/              # 静态资源
│   ├── docs/                # overlay 自有文档
│   ├── vite.config.overlay.ts # inject 时生成（gitignored）
│   ├── vitest.config.ts     # 手维护测试配置
│   └── RELEASE-NOTES.md
├── upstream/                # ← 只读，禁止直接修改
│   ├── hermes-studio/       # hermes-web-ui v0.6.23（桌面应用主体）
│   ├── element-web/         # Element Web Matrix 客户端参考
│   └── hermes-agent/        # Hermes AI Agent 运行时
├── docs/superpowers/
│   ├── specs/               # 设计文档 YYYY-MM-DD-<topic>-design.md（29 files）
│   └── plans/               # 实施计划 YYYY-MM-DD-<topic>.md（30 files）
├── AGENTS.md                # 41 行工作区规则（overlay-only / 分支 / 结构）
└── .agents/skills/Swarm-studio/ # 本技能
```

## overlay/ 关键结构

- **package.json**：`hermes-overlay` v0.6.22-overlay，`type: module`，`engines.node: >=23.0.0`，无自有 deps（node_modules 是指向 upstream 的符号链接）
- **scripts**（npm scripts）：

| script | 命令 |
|--------|------|
| inject | `node scripts/inject.mjs` |
| clean | `node scripts/inject.mjs --clean` |
| verify | `node scripts/verify-clean.mjs` |
| sync | `bash scripts/sync-upstream.sh` |
| ensure-injected | `node scripts/ensure-injected.mjs` |
| build | `vite build --config vite.config.overlay.ts`（prebuild=ensure-injected） |
| dev | `cross-env HERMES_WEB_UI_BACKEND_PORT=8647 vite --config vite.config.overlay.ts --host --port 8649 --strictPort`（predev=ensure-injected） |
| test | `vitest run` |
| build:full | `node scripts/build.mjs` |
| build:dmg:mac | `node scripts/build-dmg.mjs --mac` |
| build:dmg:win | `node scripts/build-dmg.mjs --win` |

## 技术栈

| 层 | 技术 | 版本 |
|----|------|------|
| 前端框架 | Vue | ^3.5.32 |
| 状态管理 | Pinia | ^3.0.4 |
| 路由 | vue-router | ^4.6.4 |
| i18n | vue-i18n | ^11.3.2 |
| 构建工具 | Vite | ^8.0.4 |
| 类型 | TypeScript | ~6.0.2 |
| UI 库 | naive-ui | ^2.44.1 |
| Matrix SDK | matrix-js-sdk | ^41.8.0-rc.0 |
| 后端 | Koa | ^2.15.3 |
| 测试 | Vitest | ^3.2.4 |
| 桌面 | Electron | ^42.3.0（electron-builder ^25.1.8, electron-updater ^6.3.9） |
| 数据库 | node:sqlite (DatabaseSync) | embedded，无外部 DB |
| Agent 运行时 | hermes-agent | Python >=3.11 <3.14 |

**upstream hermes-studio**：hermes-web-ui v0.6.23；**desktop**：swarmstudio v0.6.23。

## 数据库（embedded SQLite）

- **引擎**：`node:sqlite` 的 `DatabaseSync`（Node 内置，需 Node>=22.5，本项目要求 >=23）
- **DB 文件**：`<DB_DIR>/hermes-web-ui.db`
- **DB_DIR**：test→`packages/server/data/test-runtime`；dev→`packages/server/data`；prod→`~/.hermes-web-ui`（环境变量 `HERMES_WEB_UI_HOME`）
- **prod 配置**：WAL 模式 + `foreign_keys=ON`
- **schema 位置**：`packages/server/src/db/hermes/schemas.ts`（834 行，26 张表）
- **Node<22.5 回退**：JSON 文件存储
- **无外部 DB / Redis / MQ / ELK**——全部 embedded

**26 张表**：sessions, messages, session_usage, users, user_profiles, workflows, workflow_runs, workflow_run_node_sessions, chat_compression_snapshots, model_context, devices, stt_*(4), tts_*(4), gc_rooms, gc_messages, gc_room_agents, gc_context_snapshots, gc_room_members, gc_pending_session_deletes, gc_session_profiles。

## Feature flags（features.ts，7 个）

| flag | 环境变量 | 判断 | 默认 |
|------|---------|------|------|
| matrixChat | `VITE_CUSTOM_MATRIX_CHAT` | `!== false` | on |
| matrixAuth | — | `=== true` | off |
| matrixAdmin | — | `=== true` | off |
| kanbanEnhancements | — | `!== false` | on |
| branding | — | `!== false` | on |
| extendedI18n | — | `!== false` | on |
| cockpit | — | `!== false` | on |

## Vite alias 链

| alias | 指向 |
|-------|------|
| `/src/main.ts` | `registries/client/entry.mts`（入口替换） |
| `@/custom` | `custom/client` |
| `@custom` | `custom/client` |
| `@registries` | `registries` |
| `@` | upstream `.../client/src` |

## 端口

| 端口 | 服务 |
|------|------|
| 8647 | Koa 后端 |
| 8649 | Vite HMR（`--strictPort`） |
| 8650 | agent-health（`/agent-health` 代理，Bearer $API_SERVER_KEY） |
| 8642 | Hermes gateway |
| 9119 | Hermes dashboard |

## inject 机制

`npm run inject`（node scripts/inject.mjs）流程：
1. **clean self-residuals** — 清除上次注入残留
2. **dirty-check upstream** — 校验 upstream 工作树干净
3. **apply patches by series order** — `git apply --whitespace=nowarn`，按 `patches/series` 顺序；路由按前缀：
   - `hermes_cli/` `plugins/` `agent/` `apps/` `assets/` `acp_` → **hermes-agent**（容错跳过，失败不阻断）
   - 其余 → **hermes-studio**（fatal，失败即报错）
4. **symlink node_modules** — 指向 upstream node_modules（overlay 无自有 deps）
5. **symlink server/src/custom** — 后端自定义代码链接
6. **generate vite.config.overlay.ts** — 生成 Vite 配置（gitignored）
7. **write .overlay-injected.json manifest** — 注入清单

`npm run clean` = 反向还原；`npm run ensure-injected` = 幂等确保已注入；`npm run verify` = 校验注入态干净。

## 关键约束

- **overlay-only 修改**：`upstream/` 只读，变更只能经 patch inject
- **dev server 期间禁止 upstream checkout/clean**：会破坏注入态
- **后端 CJS**：`custom/server/package.json` 不设 `type:module`，避免 ERR_REQUIRE_ESM
- **release 仅 arm64.dmg + x64.zip**
- **绝不删除 backup/pre-squash 分支**
- **无 seed/fixture 数据**：测试 stub 在 `custom/client/test/setup.ts`
- **LLM API keys 用户自配**：OPENROUTER/GOOGLE/GLM 等，非本地基础设施
