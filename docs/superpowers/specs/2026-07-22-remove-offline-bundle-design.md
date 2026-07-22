# 设计:移除离线安装包,改为在线 npm/pip 安装 + 源码包一键安装

- 日期:2026-07-22
- 范围:swarm-yuan skill(安装/自检体系)
- 状态:待实现

## 1. 背景与目标

swarm-yuan 当前并存两套依赖安装体系:

1. **离线安装包体系** —— `swarm-yuan/offline-cache/`(7 个 npm tgz + 31 个 python wheel + gstack/superpowers clone + 2 个历史 zip,33MB)+ `build-offline-win.sh` / `install-offline-win.sh`(+.bat)/ `fetch-offline-cache.sh`。二进制自 `v2026.07.20` 起挂 GitHub Release `v2026.07.20-offline`,不入 git。
2. **安装自检体系** —— `scripts/self-check.sh`(802 行),表驱动检测 11 个运行时,安装降级链:**本地源码(git clone + npm link) → npm i -g → npx**。

**目标**:砍掉离线安装包体系;安装自检改为直接用 npm/pip 在线安装;对无法走包管理器的依赖(gstack / superpowers / ECC),发版时附 GitHub 源码包,自检时拉取安装,实现一键安装。

## 2. 决策摘要(已与用户确认)

| 决策点 | 取值 |
|---|---|
| 无法 npm/pip 的依赖范围 | gstack / superpowers / ECC(3 项) |
| 其余 8 项安装方式 | openspec/comet/gitnexus/gsd-core/claude-mem/ocr/ruflo → `npm i -g`;graphify → `uv tool install`/`pipx`/`pip` 在线 |
| 源码包发版机制 | 手动脚本 `release-src-packages.sh`(git clone 上游 → zip → `gh release upload`) |
| 旧离线脚本/目录处置 | 全部删除(build/install/fetch 三个脚本 + .bat + `offline-cache/` 目录 + .gitignore 规则 + 文档入口) |
| self-check 现有"本地源码优先"降级链 | 删除(RESEARCH_DIR git clone + npm link 整段) |

## 3. 架构变化

### 3.1 删除清单

- `swarm-yuan/offline-cache/`(整个目录:`npm/`、`graphify-wheels/`、`gstack/`、`superpowers/`、`UPSTREAM.md`、2 个历史 zip)
- `swarm-yuan/scripts/build-offline-win.sh`
- `swarm-yuan/scripts/install-offline-win.sh`
- `swarm-yuan/scripts/install-offline-win.bat`
- `swarm-yuan/scripts/fetch-offline-cache.sh`
- `.gitignore` 根 L24-33(offline-cache 治理块)
- `swarm-yuan/.gitignore` L1-11(offline-cache 规则块)
- `ci.yml` L208 `scripts/install-offline-win.sh scripts/build-offline-win.sh` 信息层 shellcheck 条目
- `install.sh` L105/112 `offline-cache` 排除逻辑(目录已不存在,排除守卫可删)
- README(根 + `swarm-yuan/`)中 offline-cache / 离线安装章节
- CLAUDE.md 中离线安装命令入口(若有)

### 3.2 新增

- `swarm-yuan/scripts/release-src-packages.sh` —— 手动发版脚本:
  1. `git clone --depth 1` 三个上游仓库(gstack `garrytan/gstack`、superpowers `obra/superpowers`(核心插件本体，含 skills/ 与 plugin.json，非 `obra/superpowers-marketplace` 空壳)、ECC `affaan-m/ECC`)到临时目录
  2. 各自打成 `<name>-src.zip`(排除 `.git`)
  3. `gh release create v<ver>-src` / `gh release upload v<ver>-src *.zip`(tag 由调用者传参或脚本自派版本号 `date -u +%Y%m%d`)
  4. 用法:`bash scripts/release-src-packages.sh [version]`
- self-check.sh 内新增 `install_from_src_release()` 函数族:从 Release `v<ver>-src` 下载 `<name>-src.zip` → 解压到临时目录 → 安装到目标位置(见 3.3)

### 3.3 改造 self-check.sh

**PROJECTS 表重分类(11 项,安装方式三类):**

| name | 安装方式 | 安装函数 |
|---|---|---|
| openspec | npm | `install_openspec` → `npm i -g @fission-ai/openspec@latest` |
| comet | npm | `install_comet` → `npm i -g @rpamis/comet@latest` |
| gitnexus | npm | `install_gitnexus` → `npm i -g gitnexus@latest` |
| gsd-core | npm | `install_gsd_core` → `npx -y @opengsd/gsd-core@latest --claude --global` |
| claude-mem | npm | `install_claude_mem` → `npx -y claude-mem@latest install` |
| ocr | npm | `install_ocr` → `npm i -g @alibaba-group/open-code-review@latest` |
| ruflo | npm | `install_ruflo` → `npm i -g ruflo@latest` |
| graphify | python | `install_graphify` → `uv tool install graphifyy` → `pipx install graphifyy` → `pip install graphifyy` 降级 |
| gstack | 源码包 | `install_gstack` → 下载 Release zip → 解压到 `~/.claude/skills/gstack` → `./setup` |
| superpowers | 源码包 | `install_superpowers` → 下载 Release zip → 解压到 `~/.claude/plugins/superpowers`(或 `~/.claude/skills/superpowers`) |
| ECC | 源码包 | `install_ecc` → 下载 Release zip → 解压到 `~/.claude/plugins/ecc`(或 `~/.claude/skills/ecc`) |

**删除:**
- L4-9 注释中的"本地源码优先"策略段
- L29-38 `RESEARCH_DIR` 推断逻辑
- L100-138 `install_from_source()` 函数
- L140-146 `src_root_*()` 函数族
- L148-225 各 `install_*` 中的 `if [[ -n "$RESEARCH_DIR" ... ]]` 源码分支,改为直连 npm/pip
- L244-250 `upgrade_from_source()`
- L318-324 "源码优先 / npm 模式"提示分支
- L375-406 `--latest` 源码模式升级段(改为统一 npm 版本比对 + graphify uv 重装)
- `--npm` 参数及 `USE_NPM_ONLY` 变量(源码链已删,该开关无意义)
- `src_root_func` 列(表第 5 字段)
- `install_hint()` 中 gstack/superpowers/ECC 三项的人工 clone 提示(改为已可自动装的说明)

**保留:**
- `check_*` 检测函数族(11 个,不变)
- `--check-only` / `--install <name>` / `--latest` 模式
- 安装后复查逻辑(L446-453)
- 框架规则库时效/规则集核验/文档一致性/上游基线检查段(L458-797,与本次无关)
- `fail-closed` 语义(superpowers 空壳检测 L75-89 不变)

**新增 `install_from_src_release()`:**
```bash
# 参数: <name> <release_tag> <zip_name> <dest_dir> [setup_cmd]
install_from_src_release(){
  local name="$1" tag="$2" zip="$3" dest="$4" setup="${5:-}"
  local repo="issac-new/Swarm-yuan"
  local url="https://github.com/$repo/releases/download/$tag/$zip"
  local tmp; tmp="$(mktemp -d)"
  echo "  → [$name] 下载源码包 $url"
  if ! (cd "$tmp" && curl -fsSL -o "$zip" "$url"); then
    echo "  ✗ $name 下载失败: $url"
    echo "    手工下载: 浏览器打开 $url"
    rm -rf "$tmp"; return 1
  fi
  mkdir -p "$dest"
  (cd "$tmp" && unzip -q "$zip" -d extracted)
  # zip 内为单层目录,取其内容
  local inner; inner="$(ls -d "$tmp"/extracted/*/ 2>/dev/null | head -1)"
  cp -R "${inner:-$tmp/extracted/}"* "$dest/" 2>/dev/null || cp -R "$tmp/extracted/." "$dest/"
  rm -rf "$tmp"
  if [[ -n "$setup" ]]; then
    echo "  → [$name] 运行 setup: $setup"
    (cd "$dest" && eval "$setup") || warn "$name setup 失败(已复制文件,请手动检查)"
  fi
}
```

**配置常量(脚本顶部):**
```bash
SRC_RELEASE_REPO="issac-new/Swarm-yuan"
SRC_RELEASE_TAG="${SRC_RELEASE_TAG:-v$(date -u +%Y%m%d)-src}"  # 可被环境变量覆盖
```

### 3.4 数据流

```
用户跑 install.sh(复制 skill 到 ~/.claude/skills/swarm-yuan/)
  → 不再排除 offline-cache(目录已删)
  → 用户/CI 跑 self-check.sh
  → 检测 11 项:
      miss 的:
        npm 类   → npm i -g <pkg>@latest(或 npx -y <pkg>@latest <args>)
        graphify → uv tool install graphifyy → pipx → pip 降级
        源码类   → install_from_src_release <name> <tag> <zip> <dest> <setup>
                  → curl 下载 Release zip → 解压 → cp 到目标 → ./setup
      已装的 --latest:
        npm 类   → upgrade_npm_pkg(npm view version 比对)
        graphify → uv tool install --force --from 重装
        源码类   → 重下源码包覆盖安装
  → 复查 → exit $FAIL
```

### 3.5 发版流程(手动)

```bash
# 在仓库根
bash swarm-yuan/scripts/release-src-packages.sh 20260722
# 脚本内部:
#   1. git clone --depth 1 garrytan/gstack / obra/superpowers / affaan-m/ECC 到 tmp
#   2. zip -r --exclude=.git gstack-src.zip gstack/  (×3)
#   3. gh release create v20260722-src --title ... 或 gh release upload v20260722-src *.zip
# 输出: Release v20260722-src 含 gstack-src.zip / superpowers-src.zip / ecc-src.zip
```

用户侧自检时 `SRC_RELEASE_TAG=v20260722-src bash self-check.sh --install gstack` 即可一键装。

## 4. 错误处理

- **npm/pip 失败**:`--check-only` 不报错(仅检测);交互模式输出失败日志,建议用户检查网络/包管理器,不中断其余项安装
- **Release 源码包下载失败**:输出 URL,提示手工浏览器下载,return 1(计入 FAIL,与现状"无法自动装"语义一致)
- **setup 失败**:warn 但已复制文件,提示手动检查(与现 `install_hint` 语义对齐)
- **fail-closed 保留**:superpowers 空壳检测不变(marketplace 元数据 ≠ 核心插件)
- **复查语义不变**:初检 miss 但安装后复查 pass 不算 FAIL

## 5. 测试

- `tests/` fixture 中涉及 offline-cache 的用例清理(若有)
- `ci.yml`:
  - 删除 L208 离线脚本 shellcheck 条目
  - self-check job 验证脚本仍 `bash -n` 通过(无语法错)
  - 新增 `release-src-packages.sh` 进信息层 shellcheck(或严格层,视复杂度)
- 手动验证:
  - `bash swarm-yuan/scripts/release-src-packages.sh` 本地跑(需 `gh` 已登录)能产出 3 个 zip 并上传
  - `SRC_RELEASE_TAG=<tag> bash swarm-yuan/scripts/self-check.sh --install gstack` 能下载并安装(需网络)
  - `bash swarm-yuan/scripts/self-check.sh --check-only` 仍正常输出 11 项检测 + 文档一致性段

## 6. 实施顺序(建议)

1. 改造 `self-check.sh`(删源码链 + 新增 `install_from_src_release` + 重写 11 个 install 函数)
2. 新增 `release-src-packages.sh`
3. 删除离线脚本与 `offline-cache/` 目录
4. 清理 `.gitignore`(根 + swarm-yuan)、`ci.yml`、`install.sh`、README、CLAUDE.md
5. `bash -n` + shellcheck 自测 + `--check-only` 端到端跑通

## 7. 待实施时确认的细节

- ECC 上游仓库:`https://github.com/affaan-m/ECC`(self-check.sh L97/L288 已引用),安装目标 `~/.claude/plugins/ecc` 或 `~/.claude/skills/ecc`(L97 检测两路径均判 pass,安装择 `~/.claude/plugins/ecc`)
- superpowers 源码包安装目标:现状检测 `~/.claude/plugins/superpowers` 与 `~/.claude/skills/superpowers`(L81),安装择 `~/.claude/plugins/superpowers`
- README/CLAUDE.md 离线章节的具体改写文案(实施时按上下文重写,非机械删除)
- `release-src-packages.sh` 的 `gh` 依赖:若未装 `gh` 脚本报错退出并提示安装
