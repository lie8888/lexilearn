const Router = require('koa-router');
const { listVocabs, downloadVocab } = require('../controllers/vocabController');
const router = new Router({ prefix: '/vocab' });

// 查询所有词库元数据
router.get('/', listVocabs);
// 根据ID获取单个词库下载链接
router.get('/:id', downloadVocab);

module.exports = router;