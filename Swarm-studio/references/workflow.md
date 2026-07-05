# 八节点开发流程

## 流程总览
```
①需求理解 → ②设计spec → ③实施plan → ④分支准备 → ⑤编码实现 → ⑥测试审查 → ⑦合入main → ⑧构建发布
```

## 节点①：需求理解
- 读取项目最新知识（AGENTS.md/CLAUDE.md/记忆）
- 明确需求：A类（custom 新增）还是 B类（patches 修改）
- 判断变更规模（简单/标准/完整）

## 节点②：设计 spec
- 复制 spec-template.md 到 specs/
- 填写 §1-§5.5（复用约束：查 reference-manual §4/5/6 可复用单元）
- B类修改须在 §3 填侵入点清单

## 节点③：实施 plan
- MECE 拆分任务
- A类：custom/ 下新建文件 + registries/ 注册
- B类：patches/ 下新建 patch 文件 + patches/series 添加

## 节点④：分支准备
```bash
cd overlay && git checkout main && git checkout -b feat/<feature-name>
```

## 节点⑤：编码实现
- A类：custom/client/<module>/ 下编码，通过 @/custom alias 引用
- B类：修改 upstream 文件后 `git diff > patches/NNN-xxx.patch`
- 编码前查 reference-manual §4/5/6 复用清单（拼装优先）
- inject 确保：`npm run inject`（predev/prebuild 自动执行）

## 节点⑥：测试审查
```bash
cd overlay && npm test
bash scripts/precheck.sh --all
```

## 节点⑦：合入 main
```bash
cd overlay && git checkout main && git merge --no-ff feat/<feature-name>
```
需用户确认后执行。

## 节点⑧：构建发布
```bash
cd overlay && npm run build:dmg:mac  # arm64.dmg + x64.zip
```
仅上传 arm64.dmg + x64.zip。需用户确认。
