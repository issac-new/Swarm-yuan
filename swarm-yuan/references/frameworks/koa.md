---
ruleset_id: koa
适用版本: Koa 3.x（3.2.x 现行，2026-05 发布）/ 2.x（2.16.x 维护分支；差异单独标注）
最后调研: 2026-07-17（来源：https://github.com/koajs/koa/releases ；https://koajs.com/ ；https://github.com/koajs/router ；https://github.com/koajs/bodyparser ；https://github.com/venables/koa-helmet ）
深度门槛: 10
---

# Koa 规则集

<!--
本规则集覆盖 Koa 3.x（现行 3.2.1，2026-05-21 发布；3.0 起要求 Node >= 18，移除 generator 中间件残余支持，
AsyncLocalStorage 支持 3.2 起可用）与 2.x 维护分支（2.16.4，2026-02）。
调研时点：2026-07-17，现行版本经 https://github.com/koajs/koa/releases 联网核实。
既有 3 条门禁（router_factory / no_bare_appuse / input_guard）harvest 自 ncwk-dev precheck.sh，
conf 变量 KOA_FILE_GLOBS 约定保留（KOA_SRC_GLOBS 未配置时回退）。
-->

## §1 探查信号（→ §C+.0.5 激活依据，含置信度）

| 信号类型 | 模式 | 置信度 |
|---------|------|-------|
| 依赖 | `package.json` dependencies 含 `"koa"` / `"@koa/router"` / `"koa-bodyparser"` / `"koa-helmet"` | 高 |
| 代码 | `new Koa()` / `require('koa')` / `await next()` / `ctx.body =` / `ctx.throw(` | 高 |
| 文件 | `**/app.js` / `**/server.js`（含 koa 引用）/ `**/routes/**/*.js`（含 Router） | 中（需组合依赖信号） |
| 配置 | `PORT` + 中间件链 `app.use(` 且含 `ctx` 参数签名 | 中 |

## §2 特定构件枚举（命令 + 计数核验方式）

- 路由定义：`grep -rnE 'router\.(get|post|put|delete|patch)\(' "${PROJECT_DIR}" --include='*.js' --include='*.ts'`（计数核验基准：路由注册行数）
- Router factory：`grep -rnE 'create.*Router\(' "${PROJECT_DIR}" --include='*.js'`（计数核验基准：factory 定义/调用行数）
- 中间件注册：`grep -rnE 'app\.use\(' "${PROJECT_DIR}" --include='*.js'`（计数核验基准：app.use 行数）
- 错误监听：`grep -rnE "app\.on\(['\"]error['\"]" "${PROJECT_DIR}" --include='*.js'`（计数核验基准：app.on('error') 行数）
- ctx.state 共享：`grep -rnE 'ctx\.state\.' "${PROJECT_DIR}" --include='*.js'`（计数核验基准：ctx.state 访问行数）

## §3 领域规律（≥ 深度门槛 条，每条五要素）

### 规律：统一错误处理兜底中间件必须最先注册
- **适用版本**: 全版本
- **规律**: Koa 洋葱模型中错误沿中间件栈向上冒泡。首个 `app.use` 必须是用 try/catch 包裹 `await next()` 的错误兜底中间件，并配 `app.on('error')` 记录日志；缺失时下游错误由 Koa 默认 onerror 处理，错误栈写入响应（非 production 判断缺失）且无法统一格式化。
- **违反后果**: 错误栈泄露 CWE-209；各路由各自 try/catch 导致错误响应格式不一致。
- **验证方法**: 无 `app.on('error')` 且无 try+`await next()` 中间件 → fail。
- **对应门禁**: fw_koa_error_handler(fail)

### 规律：koa-helmet 安全头为生产基线
- **适用版本**: 全版本
- **规律**: Koa 核心不含安全头，须 `app.use(helmet())`（koa-helmet）设置 CSP/X-Frame-Options/HSTS 等基线头，注册顺序早于路由。
- **违反后果**: 点击劫持/MIME 嗅探/降级攻击面 CWE-693。
- **验证方法**: 无 `koa-helmet`/`helmet()` 引用 → fail。
- **对应门禁**: fw_koa_helmet(fail)

### 规律：路由须 factory 注入（createRouter(deps) 返回 Router）
- **适用版本**: 全版本
- **规律**: 路由模块不直接 `new Router()` 后全局挂载，而导出 `createRouter(deps)` factory，依赖（db/service）显式注入、返回配置好的 Router。入口 `app.use(createUserRouter(deps).routes())` 组装。便于单测替换依赖、避免模块级单例耦合。
- **违反后果**: 路由与全局单例耦合 → 测试须启动全应用；依赖隐式不可追踪。
- **验证方法**: 无 `create.*Router\(` 命中 → warn。
- **对应门禁**: fw_koa_router_factory(warn)

### 规律：禁裸 app.use(router)，必须 app.use(router.routes())
- **适用版本**: 全版本（@koa/router / koa-router）
- **规律**: Koa Router 实例本身不是中间件，必须 `app.use(router.routes())`（常配 `router.allowedMethods()` 自动 405/501）。裸 `app.use(router)` 在 Koa 下路由不生效（与 Express 语义不同，Express router 可直接作中间件）。
- **违反后果**: 路由全部 404；或迁移 Express 代码时静默失效。
- **验证方法**: `app.use(<x>Router)` 未跟 `.routes()` → warn。
- **对应门禁**: fw_koa_no_bare_appuse(warn)

### 规律：路由参数与请求体须输入校验
- **适用版本**: 全版本
- **规律**: `ctx.params`/`ctx.request.body`/`ctx.query` 为不可信输入，进入业务前须白名单校验（joi/zod/自写 validate 函数），@koa/router 的路径参数同样须校验形状。
- **违反后果**: 未校验输入直达业务/ORM → 注入、类型混淆 CWE-20。
- **验证方法**: 无 `validate|joi|zod|yup|ajv` 命中 → warn。
- **对应门禁**: fw_koa_input_guard(warn)

### 规律：洋葱模型——await next() 须 try/catch（或 try/finally）包裹
- **适用版本**: 全版本
- **规律**: 中间件中 `await next()` 之后的代码在下游全部完成后执行（洋葱回程）。需要错误拦截或资源清理的中间件必须 try/catch/finally 包裹 `await next()`，否则下游抛错直接越过本中间件，日志/事务/计时逻辑断裂。
- **违反后果**: 错误冒泡越过中间件 → 日志缺失、连接未释放、计时不准。
- **验证方法**: 文件含 `await next()` 但无 `try{` → warn。
- **对应门禁**: fw_koa_onion_try_catch(warn)

### 规律：跨中间件共享数据须挂 ctx.state，禁直接扩展 ctx
- **适用版本**: 全版本
- **规律**: 官方约定跨中间件共享数据（当前用户、trace id）挂 `ctx.state.xxx`；直接向 `ctx.foo = ...` 赋值污染上下文命名空间，与库内部属性冲突风险（Koa 文档明确推荐 ctx.state）。扩展 API 才用 `app.context`。
- **违反后果**: 属性名冲突 → 覆盖框架/库内部字段，行为不可预期。
- **验证方法**: `ctx.<自定义名> = ` 赋值（排除 body/status/state 等白名单属性）→ warn。
- **对应门禁**: fw_koa_ctx_state(warn)

### 规律：koa-bodyparser 须显式 jsonLimit/formLimit
- **适用版本**: 全版本
- **规律**: `app.use(bodyParser())` 默认 jsonLimit 1mb，须按业务显式声明 `{ jsonLimit, formLimit, textLimit }` 并开启 `enableTypes` 收敛。显式 limit 使超限返回 413。
- **违反后果**: 大包请求耗尽内存 CWE-400。
- **验证方法**: `bodyParser(...)` 调用无 `jsonLimit|formLimit` → warn。
- **对应门禁**: fw_koa_body_limit(warn)

### 规律：业务错误须 ctx.throw(status)，禁裸 throw new Error
- **适用版本**: 全版本
- **规律**: `ctx.throw(400, 'name required')` 抛带 `status`/`expose` 语义的 HttpError，统一错误中间件按 status 响应且 4xx 消息可暴露给客户端；裸 `throw new Error` 一律按 500 处理且不暴露消息，客户端无法区分参数错误与服务器故障。
- **违反后果**: 4xx 业务错误变 500；错误监控误报。
- **验证方法**: `throw new Error` 命中 → warn。
- **对应门禁**: fw_koa_ctx_throw(warn)

### 规律：中间件必须 async/await 风格，generator 中间件已废弃
- **适用版本**: Koa 2+ / 3.x
- **规律**: Koa 1.x generator 中间件（`function *(next)`）在 Koa 2 起移除（须 koa-convert 过渡），Koa 3 完全不支持。新代码与迁移代码一律 `async (ctx, next) => { ... }`。
- **违反后果**: Koa 2/3 下 generator 中间件不执行或抛 TypeError。
- **验证方法**: `app.use(function*` / `function *` 中间件命中 → warn。
- **对应门禁**: fw_koa_async_middleware(warn)

### 规律：CORS 须显式 origin 白名单
- **适用版本**: 全版本（@koa/cors）
- **规律**: `app.use(cors())` 空参默认反射 Origin（等价放行任意源）。生产须 `cors({ origin: 'https://app.example.com' })` 或白名单函数；带凭据时不可通配。
- **违反后果**: 任意源跨域读敏感接口 CWE-942。
- **验证方法**: `cors()` 空参或 `origin: '*'` → warn。
- **对应门禁**: fw_koa_cors(warn)

### 规律：app.context 扩展用于 API 增强而非请求态
- **适用版本**: 全版本
- **规律**: `app.context` 是 ctx 原型，挂载共享方法（如 `ctx.db()`）影响全局所有请求；请求级数据禁止挂 app.context（跨请求共享导致串数据）。请求态一律 ctx.state。
- **违反后果**: 请求态挂 app.context → 并发请求互相覆盖数据（严重串号事故）。
- **验证方法**: 检出 `app.context.<name> =` 且赋值为请求相关数据 → 人工检查语义（请求态/共享方法）。
- **对应门禁**: 人工检查

<!--
共 12 条规律（≥10 门槛）。每条均挂门禁 id 或标注人工检查，无游离规律。
-->

## §4 门禁清单（id / 级别 / 实现逻辑 / 依赖 conf 变量）

| 门禁 id | 级别 | 实现逻辑 | 依赖变量 |
|---------|------|---------|---------|
| fw_koa_router_factory | warn | 无 create.*Router( factory → warn 路由未注入化 | KOA_SRC_GLOBS |
| fw_koa_no_bare_appuse | warn | app.use(router) 未跟 .routes() → warn | KOA_SRC_GLOBS |
| fw_koa_input_guard | warn | 无 validate/joi/zod 输入校验 → warn | KOA_SRC_GLOBS |
| fw_koa_error_handler | fail | 无 app.on('error') 且无 try+await next() 兜底中间件 → fail | KOA_SRC_GLOBS |
| fw_koa_helmet | fail | 无 koa-helmet 引用 → fail 安全头基线缺失 | KOA_SRC_GLOBS |
| fw_koa_onion_try_catch | warn | await next() 无 try 包裹 → warn 洋葱断裂 | KOA_SRC_GLOBS |
| fw_koa_ctx_state | warn | ctx.<自定义属性> 直接赋值 → warn 须 ctx.state | KOA_SRC_GLOBS |
| fw_koa_body_limit | warn | bodyParser 无 jsonLimit/formLimit → warn | KOA_SRC_GLOBS |
| fw_koa_ctx_throw | warn | 裸 throw new Error → warn 须 ctx.throw(4xx) | KOA_SRC_GLOBS |
| fw_koa_async_middleware | warn | generator 中间件 → warn Koa 2+/3 废弃 | KOA_SRC_GLOBS |
| fw_koa_cors | warn | cors() 空参或 origin:* → warn | KOA_SRC_GLOBS |

<!--
门禁 id 命名规范：fw_koa_<rule>（rule 全小写下划线）。
本表 11 条 id 均在 assets/framework-gates/koa.sh 中有同名实现，片段头注释 # gates: 与本表一致。
KOA_SRC_GLOBS 未配置时实现回退 ncwk-dev 约定 KOA_FILE_GLOBS；KOA_ROUTER_FACTORY_REQUIRED /
KOA_FORBIDDEN_GLOBAL_APPUSE / KOA_INPUT_GUARD 缺省给默认值保持门禁生效。
fixture 验证覆盖：violating 含全局裸 app.use(router) + 无错误处理 + 无 helmet → error_handler/helmet fail 主触发；
compliant 用 factory 注入 + try/catch 错误兜底 + koa-helmet 修正后全 pass。
-->

## §5 跨框架交互规则

| 交互对 | 规则 | 理由 |
|-------|------|------|
| koa × @koa/router | 必须 router.routes() 注册；allowedMethods() 自动 405 | 裸 Router 不是中间件，路由不生效 |
| koa × koa-bodyparser | bodyparser 须注册在路由之前 | 顺序错误 ctx.request.body 为 undefined |
| koa × koa-helmet | helmet 须注册在 CORS/路由之前 | 先注册路由不经 helmet |
| koa × @koa/cors | 带凭据请求 origin 不可通配 | credentials + 通配源被浏览器拒绝且放大风险 |

## §6 版本陷阱速查

| 版本 | 变化 | 影响 |
|------|------|------|
| Koa 2.0（2017） | generator 中间件移除，改 async/await | 1.x 中间件须 koa-convert 或重写 |
| Koa 2.16（2026-02 维护） | Host Header Injection 修复（2.16.4） | 2.x 须升 2.16.4+ |
| Koa 3.0（2025-02） | 要求 Node >= 18；移除旧中间件签名残余；`ctx.status` 默认值对齐规范 | 低版本 Node 无法运行；老中间件须复核 |
| Koa 3.1（2026-02） | Host Header Injection 修复（3.1.2） | 3.x 须升 3.1.2+ |
| Koa 3.2（2026-03/05） | AsyncLocalStorage 支持（3.2.0）；request.length >2GB 溢出修复（3.2.1） | 大文件上传场景须 3.2.1+ |
| @koa/router 12/13 | 路径匹配 path-to-regexp v8（`*` 通配改 `(.*)` 或命名参数） | Koa 3 配套升级时通配路由须改写 |
