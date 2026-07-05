# 代码库概况

## 目录结构
```
ncwk/
├── overlay/                    ← 唯一可改目录（hermes-overlay v0.6.22-overlay）
│   ├── custom/client/          ← A类前端（cockpit, matrix-chat, kanban, branding, chat）
│   ├── custom/server/          ← A类后端（kanban, matrix auth）
│   ├── custom/hermes-agent-plugins/  ← A类 agent 插件
│   ├── patches/                ← B类 patches（109 个）
│   ├── registries/client/      ← entry.mts, bootstrap.ts（注册枢纽）
│   ├── config/                 ← features.ts, bootstrap.ts
│   ├── scripts/                ← inject.mjs, build.mjs, serve-server.sh
│   ├── tests/                  ← 额外测试
│   ├── packages/               ← 子包
│   └── vite.config.overlay.ts  ← Vite alias 配置
├── upstream/                   ← 只读
│   ├── hermes-studio/          ← SwarmStudio 主体（v0.6.25）
│   ├── element-web/            ← Element Web 参考实现
│   └── hermes-agent/           ← Hermes AI Agent 运行时
└── docs/                       ← 设计文档
```

## 技术栈版本表

| 技术 | 版本 | 说明 |
|------|------|------|
| Node.js | >=23.0.0 | engines 要求 |
| Vue | 3.x | 前端框架 |
| TypeScript | 5.x | 类型系统 |
| Vite | 最新 | 构建工具 + dev server |
| NaiveUI | 最新 | UI 组件库 |
| Vitest | 最新 | 测试框架 |
| SQLite | node:sqlite | 数据库 |
| Koa | 最新 | 后端服务 |
| Electron | 最新 | 桌面应用打包 |

## 端口约定

| 端口 | 服务 |
|------|------|
| 8647 | 后端（Koa server） |
| 8649 | 前端 dev（Vite HMR） |
| 8650 | Agent health（proxied via /agent-health） |

## Vite Alias 链

```
/src/main.ts → registries/client/entry.mts（入口 shim）
@/custom     → custom/client（A类组件）
@registries  → registries（注册枢纽）
@            → upstream/.../client/src（upstream fallback）
```

## 构建机制

- `npm run inject`：验证 upstream clean → 按 series 顺序 apply patches → 创建 symlinks → 生成 vite.config.overlay.ts → 写 .overlay-injected.json
- `npm run clean`：反向 patches，恢复 upstream pristine
- `npm run ensure-injected`：幂等注入（predev/prebuild 自动调用）
