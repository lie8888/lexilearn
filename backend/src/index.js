const Koa = require('koa');
const path = require('path');
const serve = require('koa-static');
const bodyParser = require('koa-bodyparser');
const jwt = require('koa-jwt');
const koaLogger = require('koa-logger');
const userRoutes = require('./routes/user');
const vocabRoutes = require('./routes/vocab');
const sequelize = require('./config/db');
const logger = require('./config/logger');
require('dotenv').config();

const app = new Koa();
// 实时控制台日志
app.use(koaLogger());
// 请求日志（Winston）
app.use(async (ctx, next) => {
    const start = Date.now();
    await next();
    const ms = Date.now() - start;
    logger.info(`${ctx.method} ${ctx.url} - ${ms}ms`);
});

// 静态资源：public 目录下的所有文件通过 / 路径访问
app.use(serve(path.join(__dirname, '../public')));

app.use(bodyParser());

// 公共路由：注册、验证、登录
app.use(userRoutes.routes());

// JWT 鉴权，排除 /user 和 /vocab 前缀
app.use(jwt({ secret: process.env.JWT_SECRET }).unless({ path: [/^\/user/, /^\/vocab/] }));

// 词库路由
app.use(vocabRoutes.routes());

(async () => {
    await sequelize.sync();
    app.listen(3000, '0.0.0.0', () => logger.info('Server listening on port 3000'));
})();