const { DataTypes } = require('sequelize');
const sequelize = require('../config/db');

const User = sequelize.define('User', {
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    email: { type: DataTypes.STRING(256), allowNull: false, unique: true },
    passwordHash: { type: DataTypes.STRING(512), allowNull: false },
    isVerified: { type: DataTypes.BOOLEAN, defaultValue: false }
});

module.exports = User;