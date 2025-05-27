const VocabList = require('../models/VocabList');
const logger = require('../config/logger');

async function listVocabs(ctx) {
    logger.info(`查询所有词库`);
    ctx.body = await VocabList.findAll();
}

async function downloadVocab(ctx) {
    const { id } = ctx.params;
    logger.info(`下载词库请求, id=${id}`);
    const vocab = await VocabList.findByPk(id);
    if (!vocab) {
        logger.warn(`词库不存在, id=${id}`);
        ctx.throw(404, '词库不存在');
    }
    ctx.body = { jsonUrl: vocab.jsonUrl, name: vocab.name };
    logger.info(`词库信息返回, id=${id}`);
}

module.exports = { listVocabs, downloadVocab };