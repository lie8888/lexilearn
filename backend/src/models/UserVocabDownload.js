const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const User = require('./User');
const VocabList = require('./VocabList');

const UserVocabDownload = sequelize.define('UserVocabDownload', {
    userId: { type: DataTypes.INTEGER, allowNull: false, references: { model: 'Users', key: 'id' } },
    vocabListId: { type: DataTypes.INTEGER, allowNull: false, references: { model: 'VocabLists', key: 'id' } },
    downloadedAt: { type: DataTypes.DATE, defaultValue: DataTypes.NOW }
});

User.belongsToMany(VocabList, { through: UserVocabDownload, foreignKey: 'userId' });
VocabList.belongsToMany(User, { through: UserVocabDownload, foreignKey: 'vocabListId' });
module.exports = UserVocabDownload;