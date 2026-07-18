// violating fixture:
//  - 路由无 schema 校验 → fw_fastify_schema_validation(fail)
//  - onSend 改写 payload 未回传 → fw_fastify_onsend_return(fail)
//  - 无 setErrorHandler → fw_fastify_error_handler(fail)
//  - 路由先于 register 声明 / 无 logger / 无限流 / 无认证 → 多处 warn
//
// 期望：bash run-framework-fixture.sh fastify → violating 退出码 != 0（FAIL）
const fastify = require('fastify')();
const cors = require('@fastify/cors');

// CORS 任意源放行
fastify.register(cors, { origin: '*' });

// 路由先于鉴权插件 register 声明（后注册插件钩子对本路由不生效）
fastify.get('/users', async (request, reply) => {
  return { users: [] };
});

fastify.post('/users', async (request, reply) => {
  // body 未校验直接入库
  return { created: true, user: request.body };
});

fastify.register(require('./plugins/util'));

// onSend 试图包统一响应壳，但未回传新 payload（静默丢弃）
fastify.addHook('onSend', async (request, reply, payload) => {
  const wrapped = JSON.stringify({ code: 0, data: JSON.parse(payload) });
  request.log.info('wrapped length', wrapped.length);
});

fastify.listen({ port: 3000 });
