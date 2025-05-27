const Router = require('koa-router');
const { register, verify, login } = require('../controllers/userController');
const router = new Router({ prefix: '/user' });
router.post('/register', register);
router.post('/verify', verify);
router.post('/login', login);
module.exports = router;