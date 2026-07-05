# 代码片段

## A类组件注册

```typescript
// registries/client/bootstrap.ts
import('./../custom/client/cockpit').then(({ registerCockpit }) => registerCockpit(app))
```

## B类 patch 创建

```bash
cd overlay
npm run inject
# 修改 upstream 文件
cd upstream/hermes-studio
git diff > ../../patches/NNN-description.patch
cd ../../
# 添加到 series
echo "NNN-description.patch" >> patches/series
npm run clean && npm run inject  # 验证
```

## Vite alias 配置

```typescript
// vite.config.overlay.ts
resolve: {
  alias: {
    '@/custom': path.resolve(__dirname, 'custom/client'),
    '@registries': path.resolve(__dirname, 'registries'),
    '@': path.resolve(__dirname, '../upstream/hermes-studio/packages/client/src'),
  }
}
```

## 测试命令

```bash
cd overlay
npm test                          # 全部测试
npm test -- cockpit               # 按 filename 过滤
npm test -- -t "attention"        # 按测试名过滤
```
