# 代码片段与组件参数 (Snippets)

## 命令
```bash
cd <project-root>/overlay
npm run inject && (cd ../upstream/hermes-studio && npm i --ignore-scripts && mkdir -p dist) && cd ../../overlay
bash scripts/serve-server.sh &  # :8647
npm run dev                      # :8649
lsof -ti:8647|xargs kill -9 2>/dev/null; bash scripts/serve-server.sh &  # 重启后端
npm run clean && npm run inject  # B类重新注入
npm run build:full; npm run build:dmg:mac; npm test; npm run sync
```

## A类注册模板
```ts
import type { App } from 'vue'
import { registerRoute, registerNavEntry } from '@registries/client'
export function register<Feature>(app: App) {
  registerRoute({ path: '/hermes/cockpit/<f>', name: 'hermes.<f>', component: () => import('./views/<F>View.vue') })
  registerNavEntry({ id: '<f>', label: '<标签>', section: 'cockpit' })
}
```

## B类 patch
```bash
cd upstream/hermes-studio && git diff > ../../overlay/patches/NNN-<desc>.patch && git checkout -- .
# 追加 series，cd ../../overlay && npm run clean && npm run inject
```

## 注册 API
| API | 参数 |
|-----|------|
| registerRoute | RouteRecordRaw |
| registerNavEntry | { id, label, icon?, section? } |
| registerComponent | name, comp |

## 关节组件
- CockpitView — cockpit 入口，cockpit.ts(1452行) 驱动
- SwarmKanbanView — Board→Column→TaskCard
- MatrixChatView — matrix-room.ts(1302行)
