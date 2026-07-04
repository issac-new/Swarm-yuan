# 安全规范 (Security Specification)

> swarm-yuan 必须遵守应用安全规范及代码安全、网络安全规范，防范常见安全问题。
> 目标技能生成时必须将本规范编织进 reference-manual.md §2 + dev-guide.md + precheck.sh --security。
> 参考标准：OWASP Top 10、STRIDE 威胁模型、CWE/SANS Top 25。

---

## 一、应用安全（Application Security）

### 1.1 注入防护（OWASP A03: Injection）
- **SQL 注入**：所有数据库查询必须参数化（prepared statements / parameterized queries），禁止字符串拼接 SQL
- **命令注入**：所有 shell/exec/spawn 调用必须用参数数组，禁止 `exec(string)` 拼接用户输入
- **LDAP/XPath/ORM 注入**：使用框架提供的转义/参数化机制
- **模板注入**：SSTI 防护，用户输入不直接进模板引擎

### 1.2 跨站脚本 XSS（OWASP A03）
- 所有用户输入渲染到 HTML 必须转义（框架默认转义，禁用 `v-html`/`innerHTML` 除非已净化）
- CSP（Content-Security-Policy）头设置
- 输入校验 + 输出编码

### 1.3 跨站请求伪造 CSRF（OWASP A01）
- 状态变更请求必须用 CSRF token 或 SameSite cookie
- API 接口优先用 Bearer token 认证（非 cookie）

### 1.4 失效访问控制（OWASP A01）
- 每个 API 端点必须有认证 + 授权检查
- 遵循最小权限原则
- 水平越权（用户 A 访问用户 B 的资源）必须防护
- 垂直越权（普通用户访问管理员功能）必须防护
- 默认拒绝（deny by default）

### 1.5 身份认证失效（OWASP A07）
- 密码哈希用 bcrypt/scrypt/argon2，禁止 MD5/SHA1
- JWT 必须验签 + 验过期 + 验 audience/issuer
- Session token 必须随机、不可预测
- 登录失败限流（brute force 防护）

### 1.6 敏感数据泄露（OWASP A02）
- 传输层必须 TLS/HTTPS（生产环境）
- 敏感数据（密码/token/密钥）不进日志、不进 URL query、不进错误消息
- 代码中无硬编码密钥（precheck --sensitive 检测）
- `.env` 文件 gitignore，不提交
- API 响应不返回多余敏感字段

---

## 二、代码安全（Code Security）

### 2.1 路径穿越（Path Traversal, CWE-22）
- 所有文件路径操作必须校验在允许目录内（如 `isPathWithin()` 或 `path.resolve()` + 前缀校验）
- 用户输入的文件名必须正则校验（如 `^[A-Za-z0-9._-]+$`）
- 禁止 `../` 序列

### 2.2 不安全反序列化（OWASP A08）
- 禁止 `eval()` / `Function()` / `unserialize()` 处理不可信数据
- JSON.parse 输入需 try-catch
- 禁止 `document.write` / `setTimeout(string)` / `setInterval(string)`

### 2.3 依赖安全（OWASP A06）
- **★版本锁定**：功能性开发不随意升级依赖版本（见 SKILL.md 版本锁定原则）
- 定期审计依赖漏洞（`npm audit` / `pip audit` / `govulncheck`）
- 禁止引入已知漏洞的依赖版本
- 新增依赖须经审查（供应链安全）

### 2.4 SSRF 防御（Server-Side Request Forgery, CWE-918）
- 所有出站 HTTP 请求必须经 SSRF 校验（协议白名单、私有 IP 阻断、DNS rebinding 防护）
- 参考 url-guard.ts 模式：`assertSafeOutboundUrl()`

### 2.5 安全配置（OWASP A05）
- 错误处理不泄露堆栈/路径/版本信息（生产环境）
- 安全头：X-Content-Type-Options、X-Frame-Options、X-XSS-Protection、HSTS
- 禁用调试模式（生产环境）
- CORS 配置最小化（不 `*`）

### 2.6 日志安全
- 日志不记录完整 token/密码/密钥（脱敏 `***`）
- 日志不记录用户敏感 PII
- 访问日志记录关键操作（审计追踪）

---

## 三、网络安全（Network Security）

### 3.1 接口安全
- 所有 API 必须认证（除明确公开端点）
- 速率限制（rate limiting）防暴力枚举
- 输入校验（类型/长度/格式/范围）
- 输出过滤（不返回多余字段）

### 3.2 传输安全
- 生产环境强制 HTTPS
- WebSocket 用 WSS
- HSTS 头
- TLS 版本 ≥ 1.2

### 3.3 端口安全
- 仅暴露必要端口
- 内部服务端口不对外（如 DB/缓存/MQ 端口）
- 管理端口需 IP 白名单或 VPN

### 3.4 请求安全
- 请求体大小限制
- 文件上传：类型校验 + 大小限制 + 存储隔离
- 防重放攻击（nonce/timestamp）

---

## 四、LLM/AI 安全（AI 生成代码特有）

### 4.1 LLM 信任边界
- AI 生成的代码必须经人工审查（不能盲信）
- AI 生成的代码不直接 exec（命令注入风险）
- Prompt injection 防护（用户输入不直接拼进 system prompt）

### 4.2 代码注入防护
- AI 生成代码中的 `eval`/`exec`/`Function` 必须 review
- AI 生成的 SQL 必须 review 参数化
- AI 生成的 HTML 必须 review XSS 防护

---

## 五、安全检查清单（precheck.sh --security）

生成目标技能时，precheck.sh 必须含 `--security` 子命令，检测以下模式：

| 检测项 | 扫描模式 | 严重度 |
|--------|---------|--------|
| 硬编码密钥 | `sk-`/`AKIA`/`password=`/`api_key=`/`secret=`/`token=` | High |
| SQL 拼接 | `query.*\+.*\$\{|execute.*\+|raw.*\+` | High |
| 命令注入 | `exec\(.*\+|spawn\(.*\+|system\(.*\+\|` | High |
| eval/Function | `eval\(|new Function\(|document\.write` | High |
| v-html/innerHTML | `v-html|innerHTML.*=.*\$\{` | Medium |
| 路径穿越 | `\.\.\/|readFile.*req\.|readFile.*params\.` | High |
| 禁用 TLS | `rejectUnauthorized.*false|NODE_TLS_REJECT` | High |
| CORS * | `cors.*\*|Access-Control-Allow-Origin.*\*` | Medium |
| 弱密码哈希 | `md5\(|sha1\(|createHash.*md5` | High |
| 调试模式生产 | `debug.*true|NODE_ENV.*development` (prod 检查) | Medium |

---

## 六、三平台兼容（swarm-yuan 自身的脚本须遵守，Windows / macOS / Linux）

> 本节是 **swarm-yuan 生成器自身**的兼容性要求——precheck.sh / generate-skill.sh / self-check.sh / state-machine.sh 等脚本必须兼容三平台。生成的目标技能如需三平台兼容，由目标技能自行声明（非强制）。

### 6.1 Shell 脚本兼容（swarm-yuan 自身）
- swarm-yuan 的 `.sh` 脚本必须兼容 macOS（BSD bash 3.2）和 Linux（GNU bash 4+）：
  - **不用 `declare -A`**（bash 3.2 不支持关联数组）→ 用 `case` 或临时文件替代
  - `sed -i` → macOS 需 `sed -i ''`，Linux 需 `sed -i`；统一用 `sed -i.bak ... && rm -f .bak`
  - `date` → macOS 无 `date -d`，用 `date -u +%Y-%m-%dT%H:%M:%SZ`（兼容）
  - `grep` → macOS 无 `grep -P`，统一用 `grep -E`（ERE）
  - `readlink` → macOS 无 `readlink -f`，用 `$(cd "$(dirname "$0")" && pwd)`
  - `wc -l` → 输出含前导空格，用 `| xargs` 清理
  - **`$var中文` 须 `${var}`**（bash C-locale 下 `$var` 紧跟多字节字符会报 unbound variable）
- 路径分隔符：脚本中用 `/`（bash 在 Windows Git Bash/WSL 下兼容）
- 换行符：`.sh` 文件用 LF（不 CRLF）
- 环境变量引用：统一 `${VAR}` 形式

### 6.2 路径兼容
- 代码中路径用 `/`（Node/Python 跨平台兼容）
- 不硬编码绝对路径（用配置/env/相对路径）
- 路径拼接用 `path.join()`（Node）/ `os.path.join()`（Python）/ `path/filepath.Join()`（Go）
- 临时目录用 `os.tmpdir()` / `mktemp -d`，不硬编码 `/tmp`

### 6.3 平台特定逻辑
- 平台判断：`process.platform`（Node `win32`/`darwin`/`linux`）/ `sys.platform`（Python）/ `runtime.GOOS`（Go）
- 平台差异逻辑用条件分支隔离，不混入主逻辑
- Windows 特有：路径用 `\`、换行 CRLF、无符号链接权限、`node:sqlite` 路径格式

### 6.4 依赖兼容
- 确认依赖支持三平台（检查 package.json engines / pyproject.toml classifiers）
- 原生模块（node-gyp）需三平台预编译或有构建说明
- Electron 桌面：`build:dmg:mac` / `build:dmg:win` / `build:dmg:linux` 分别构建

### 6.5 文件系统兼容
- 文件名大小写：Windows 不区分、macOS 默认不区分、Linux 区分 → 统一用小写
- 文件名特殊字符：避免 `:` `*` `?` `<` `>` `|` `"`（Windows 禁用）
- 权限：Windows 无 `chmod`，脚本中 `chmod +x` 需 try/容错
