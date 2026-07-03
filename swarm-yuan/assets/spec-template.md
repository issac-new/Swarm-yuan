# 设计文档：<feature 名称>

> 日期: YYYY-MM-DD
> 状态: 草案 / 已评审 / 已实施
> 关联: （引用相关需求、上游 issue、已有 spec）

## 1. 背景与目标

### 1.1 现状
（描述当前状态、痛点、为什么做这个）

### 1.2 目标
1. （明确、可验证的目标）

### 1.3 非目标
- （明确不做什么，防止范围蔓延）

## 2. 决策记录

| 决策 | 选择 | 备选 | 理由 |
|------|------|------|------|
| 改造类型 | <按项目分类> | — | （理由） |
| （其他决策） | | | |

## 3. 改造类型与侵入点

> 按项目实际的改造分类填写（如 A类/B类、core/plugin、src/lib）。

### 3.1 <分类1>（<位置>）
- 新增/修改文件清单：
  - `<路径>`

### 3.2 <分类2>（<位置>）
- 侵入点清单：

| 目标文件 | 改动内容 | 标识 |
|----------|----------|------|
| `<路径>` | | |

## 4. Spec Delta（OpenSpec 格式，specs as source of truth）

> 采用 OpenSpec delta spec 格式。每个 capability 一个 `specs/<name>/spec.md`。
> Requirement 用 SHALL/MUST；Scenario 用 WHEN/THEN；#### 4 个 hashtag。

### ADDED Requirements

### Requirement: <需求名>
<需求描述，用 SHALL/MUST>

#### Scenario: <场景名>
- **WHEN** <条件>
- **THEN** <预期>

### MODIFIED Requirements
> 必须包含完整更新内容（从主 spec 复制）

### REMOVED Requirements
> 必须包含 **Reason** 和 **Migration**

## 5. 详细设计（design.md，可选——复杂变更才写）

### 5.1 Context
### 5.2 Goals / Non-Goals
### 5.3 Decisions（含 Rationale + Alternative considered）
### 5.4 Risks / Trade-offs（[Risk] → Mitigation）

## 6. 前端/UI
（组件结构、路由、状态、交互流程。依赖链从代码图谱查询：`graphify path A B`）

## 7. 后端/逻辑
（接口、数据模型、业务逻辑）

## 8. 接口
（新增/修改的 API，方法/路径/入参/出参）

## 9. 静态资源与页面元素填充（assets §5）
- 需下载/新增的静态资源：（图片/字体/配置文件，路径与来源）
- 页面元素填充：（占位元素 → 真实数据的映射方式）
- 资源引用方式：（import / public 目录 / CDN）

## 10. 数据设计
（schema 变更、数据流、勾稽关系。样例数据见 assets/data-sample-template.md）

## 11. 测试策略
- 单测覆盖：
- 手动验证步骤：
- 回归边界：
- 业务规则案例：（check §2，列出案例数据与预期）
- 数据勾稽核对：（check §3，无多漏错重核对项）

## 12. 风险与回滚
- 风险：
- 回滚方式：

## 13. 参考资料
- 相关 spec：
- 上游文档：
