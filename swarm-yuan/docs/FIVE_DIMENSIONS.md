# 五维字段详解：可复用稳定单元的完整描述

## 什么是五维字段

特征卡第 11 项"可复用稳定单元"中，每个单元用五个维度完整描述：

| 维度 | 含义 | 作用 |
|------|------|------|
| **签名** | 单元的技术标识（函数名/组件名/类名/接口名） | 精确定位，避免歧义 |
| **路径** | 单元在代码库中的文件位置 | 快速查找，确认存在 |
| **用途** | 单元的功能描述（做什么、解决什么问题） | 理解价值，判断是否可复用 |
| **复用方式** | 如何引用这个单元（import/alias/注册/API 调用） | 指导编码，避免错误引用 |
| **稳定性标注** | 单元的稳定性等级（核心稳定/可演进/实验性） | 评估风险，决定是否依赖 |

---

## 真实项目示例

### 示例 1: Vue 组件

**签名**: `CockpitWorkspace`

**路径**: `custom/client/cockpit/components/CockpitWorkspace.vue`

**用途**: 
- Cockpit 主工作区容器组件
- 整合看板、聊天、文件面板、协作图谱四大功能区
- 提供三段联动式布局（全貌→聚焦→处理）
- 管理用户决策流（WorkDecision）和任务状态

**复用方式**:
```typescript
// 在 registries/client/bootstrap.ts 中注册
import('./../custom/client/cockpit').then(({ registerCockpit }) => registerCockpit(app))

// 在其他组件中引用
import CockpitWorkspace from '@/custom/cockpit/components/CockpitWorkspace.vue'
```

**稳定性标注**: **核心稳定** ⭐⭐⭐
- 位于 cockpit 模块顶层，被多个子组件依赖
- 接口稳定（props/emit 未变）
- 测试覆盖完整（cockpit-store.test.ts）
- 禁止侵入式重构

---

### 示例 2: TS 函数

**签名**: `isGatewayNotice(content: unknown): boolean`

**路径**: `custom/client/chat/gateway-notice.ts`

**用途**:
- 判断文本是否为网关关闭/重启告警
- 识别 swarm-agent gateway 推送的系统事件消息
- 命中后由 chat store 打 `systemType: 'gateway'` 标记
- 渲染层据此折叠为紧凑系统提示

**复用方式**:
```typescript
// 在 chat store 中调用
import { isGatewayNotice } from '@/custom/chat/gateway-notice'

if (isGatewayNotice(message.content)) {
  message.systemType = 'gateway'
}
```

**稳定性标注**: **核心稳定** ⭐⭐⭐
- 纯函数，无副作用
- 正则模式稳定（`/^⚠️\s*Gateway\s+(shutting down|restarting)\b/i`）
- 被 vitest 单测覆盖
- 可安全依赖

---

### 示例 3: Pinia Store

**签名**: `useCockpitStore()`

**路径**: `custom/client/cockpit/store/cockpit.ts`

**用途**:
- Cockpit 全局状态管理
- 整合看板（kanban）、聊天（chat）、Matrix 客户端状态
- 提供任务搜索、注意力管理、协作图谱、历史记录、通知等功能
- 管理用户待办（UserTodo）和租户过滤

**复用方式**:
```typescript
// 在组件中调用
import { useCockpitStore } from '@/custom/cockpit/store/cockpit'

const cockpitStore = useCockpitStore()
const tasks = cockpitStore.filteredTasks
```

**稳定性标注**: **核心稳定** ⭐⭐⭐
- 被 CockpitWorkspace 等多个组件依赖
- 接口稳定（computed/ref 未变）
- 测试覆盖（cockpit-store.test.ts）
- 禁止修改签名（新增字段可以，改字段不行）

---

### 示例 4: API 接口

**签名**: `kanbanApi.getTasks(params: KanbanTaskQuery): Promise<KanbanTask[]>`

**路径**: `custom/client/cockpit/api/kanban-extras.ts`

**用途**:
- 获取看板任务列表
- 支持分页、过滤、排序
- 返回标准化的 KanbanTask 类型

**复用方式**:
```typescript
// 在 store 或组件中调用
import * as kanbanApi from '@/custom/cockpit/api/kanban-extras'

const tasks = await kanbanApi.getTasks({ status: 'open', limit: 50 })
```

**稳定性标注**: **可演进** ⭐⭐
- 接口参数可能扩展（新增过滤条件）
- 返回类型稳定（KanbanTask 未变）
- 调用方需处理分页逻辑
- 可依赖，但需关注版本变更

---

### 示例 5: 适配器（Adapter）

**签名**: `taskAdapter.mapToViewModel(task: KanbanTask): TaskViewModel`

**路径**: `custom/client/cockpit/adapters/task-adapter.ts`

**用途**:
- 将后端 KanbanTask 转换为前端 TaskViewModel
- 处理字段映射、默认值、计算属性
- 解耦后端 API 与前端渲染

**复用方式**:
```typescript
// 在 store 中调用
import * as taskAdapter from '@/custom/cockpit/adapters/task-adapter'

const viewModel = taskAdapter.mapToViewModel(rawTask)
```

**稳定性标注**: **可演进** ⭐⭐
- 映射逻辑可能随后端字段变化
- 接口稳定（mapToViewModel 签名未变）
- 被 cockpit-store 依赖
- 可依赖，但需关注后端变更

---

## 五维字段的作用

### 1. 签名：精确定位

- **避免歧义**：`useCockpitStore` vs `useKanbanStore` 是两个不同的 store
- **支持搜索**：IDE 可快速跳转到定义
- **支持重构**：重命名时全局替换

### 2. 路径：快速查找

- **确认存在**：`custom/client/cockpit/store/cockpit.ts` 确实存在
- **理解结构**：路径反映模块划分（cockpit/store/ vs cockpit/components/）
- **支持导航**：点击路径直接打开文件

### 3. 用途：理解价值

- **判断复用**：这个单元解决什么问题？我的需求是否匹配？
- **避免重复**：已有 `isGatewayNotice` 就不需要再写一个
- **指导设计**：新单元应该放在哪里？如何命名？

### 4. 复用方式：指导编码

- **正确引用**：`import { useCockpitStore } from '@/custom/cockpit/store/cockpit'`
- **避免错误**：不要用 `@/stores/hermes/cockpit`（路径错误）
- **支持注册**：在 bootstrap.ts 中注册组件

### 5. 稳定性标注：评估风险

- **核心稳定** ⭐⭐⭐：可安全依赖，禁止侵入式重构
- **可演进** ⭐⭐：可依赖，但需关注版本变更
- **实验性** ⭐：谨慎依赖，可能大幅变更

---

## 特征卡第 11 项的完整示例

```markdown
## 11. 可复用稳定单元清单

### 组件库

| 签名 | 路径 | 用途 | 复用方式 | 稳定性 |
|------|------|------|---------|--------|
| CockpitWorkspace | custom/client/cockpit/components/CockpitWorkspace.vue | 主工作区容器 | import + registerCockpit | ⭐⭐⭐ 核心稳定 |
| CockpitKanban | custom/client/cockpit/components/CockpitKanban.vue | 看板面板 | import | ⭐⭐⭐ 核心稳定 |
| CockpitChatPane | custom/client/cockpit/components/CockpitChatPane.vue | 聊天面板 | import | ⭐⭐⭐ 核心稳定 |
| GatewayNoticeBanner | custom/client/chat/components/GatewayNoticeBanner.vue | 网关通知横幅 | import | ⭐⭐⭐ 核心稳定 |

### 函数库

| 签名 | 路径 | 用途 | 复用方式 | 稳定性 |
|------|------|------|---------|--------|
| isGatewayNotice | custom/client/chat/gateway-notice.ts | 判断网关告警 | import | ⭐⭐⭐ 核心稳定 |
| renderMarkdown | custom/client/cockpit/components/CockpitWorkspace.vue | Markdown 渲染 | 组件内使用 | ⭐⭐ 可演进 |

### Store

| 签名 | 路径 | 用途 | 复用方式 | 稳定性 |
|------|------|------|---------|--------|
| useCockpitStore | custom/client/cockpit/store/cockpit.ts | Cockpit 全局状态 | import + 调用 | ⭐⭐⭐ 核心稳定 |
| useKanbanStore | custom/client/kanban/store/kanban.ts | 看板状态 | import + 调用 | ⭐⭐⭐ 核心稳定 |

### API

| 签名 | 路径 | 用途 | 复用方式 | 稳定性 |
|------|------|------|---------|--------|
| kanbanApi.getTasks | custom/client/cockpit/api/kanban-extras.ts | 获取看板任务 | import + 调用 | ⭐⭐ 可演进 |

### 适配器

| 签名 | 路径 | 用途 | 复用方式 | 稳定性 |
|------|------|------|---------|--------|
| taskAdapter.mapToViewModel | custom/client/cockpit/adapters/task-adapter.ts | 任务数据转换 | import + 调用 | ⭐⭐ 可演进 |
```

---

## 五维字段在门禁中的应用

### `--reuse` 门禁

检测新增单元是否与既有单元重名：

```bash
# 检查新增的 isGatewayNotice 是否与既有单元重名
grep -r "export function isGatewayNotice" custom/
# 如果找到多个定义 → fail（重复造轮子）
```

### `--stable-diff` 门禁

检测稳定层是否被改而未声明：

```bash
# 检查 STABLE_GLOBS 指定的稳定单元是否被修改
git diff custom/client/cockpit/store/cockpit.ts
# 如果有改动但 spec §3 未声明 MODIFIED → fail
```

### `--layer` 门禁

检测依赖方向是否违反分层规则：

```bash
# 检查 domain 层是否导入了 presentation 层
grep "import.*from.*components" custom/client/cockpit/store/cockpit.ts
# 如果 store 导入了 components → fail（依赖倒置）
```

---

## 总结

五维字段是特征卡第 11 项的核心——它完整描述了每个可复用稳定单元的技术标识、位置、功能、引用方式和稳定性。

**特征卡是立法，门禁是执法。** 五维字段定义了"哪些单元可以复用、如何复用"，`--reuse` / `--stable-diff` / `--layer` 门禁验证"代码是否遵守这些规则"。
