# 开发指南

## 改造分类

| 类型 | 性质 | 位置 | 机制 |
|------|------|------|------|
| A类 | 纯新增（组件/store/服务） | custom/ | Vite alias redirect + entry shim + runtime registry |
| B类 | 骨架修改（schema/config/routes） | patches/ | git apply at build time |

## A类开发流程

1. 在 `custom/client/<module>/` 下新建 .vue/.ts 文件
2. 在 `registries/client/bootstrap.ts` 中注册（import + registerRoute/registerNavEntry/registerComponent）
3. 通过 `@/custom` alias 引用（Vite 自动重定向）
4. 如需新 store，在 `custom/client/<module>/` 下创建，通过 `@/custom` 引用

## B类开发流程

1. `npm run inject` 确保 upstream 已注入
2. 修改 upstream 文件（临时）
3. `git diff > patches/NNN-<description>.patch`
4. 在 `patches/series` 中添加条目
5. `npm run clean && npm run inject` 验证 patch 可重复应用

## 拼装式开发原则

- **优先复用**：编码前查 reference-manual §4/5/6 可复用稳定单元清单
- **禁止重复造轮子**：新增前先查是否已有同等功能的稳定单元
- **禁止侵入式重构**：不改既有稳定单元签名/行为
- **禁止破坏性改造**：不改 upstream 骨架/第三方依赖
- 每个新增文件须标注复用了哪些既有单元（见 spec-template §5.5）

## 安全编码规范

- 密码必须哈希（bcrypt/argon2），不可明文
- SQL 必须参数化，不可拼接
- XSS 须输出编码，v-html 须 sanitize
- 密钥不入代码库，用环境变量
- 输入验证在边界（schema/DTO）

## 三平台兼容

- sed -i.bak+rm / grep -E / date -u / $(cd+pwd) / wc|xargs
- 路径用 / + path.join
- 文件名小写无特殊字符
