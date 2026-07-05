# 编译规则与发布

## 编译规则

| 用途 | 命令 | 产物 |
|------|------|------|
| 前端构建 | `npm run build` | dist/（vite bundle） |
| 全量构建 | `npm run build:full` | upstream/dist/（openapi+client+server） |
| macOS DMG | `npm run build:dmg:mac` | arm64.dmg + x64.zip |
| Windows | `npm run build:dmg:win` | x64.exe + zip + msi |
| Linux | `npm run build:dmg:linux` | linux 包 |

## 发布规则

- **仅上传 arm64.dmg + x64.zip 2 种文件**（全局规则）
- 不上传其他资产
- 发布前须用户确认
- 不自动推送 GitHub（除非用户明确要求）

## 失败排查

- inject 失败：`npm run clean` 清理后重试
- 构建失败：检查 `npm run verify`（upstream working tree clean）
- 测试失败：`npm test -- <pattern>` 定位
- patch 冲突：`npm run sync`（clean → git fetch/reset → re-inject）
