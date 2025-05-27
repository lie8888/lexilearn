const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');
const User = require('./User');

const EmailVerification = sequelize.define('EmailVerification', {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    userId: { type: DataTypes.INTEGER, allowNull: false, references: { model: 'Users', key: 'id' } },
    code: { type: DataTypes.STRING(6), allowNull: false },
    expiresAt: { type: DataTypes.DATE, allowNull: false }
});

EmailVerification.belongsTo(User, { foreignKey: 'userId', onDelete: 'CASCADE' });
module.exports = EmailVerification;