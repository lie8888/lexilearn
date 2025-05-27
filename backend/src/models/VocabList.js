const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const VocabList = sequelize.define('VocabList', {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    name: { type: DataTypes.STRING(100), allowNull: false },
    jsonUrl: { type: DataTypes.STRING(500), allowNull: false },
    version: { type: DataTypes.STRING(20), defaultValue: '1.0' }
});

module.exports = VocabList;