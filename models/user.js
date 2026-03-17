let User;

try {
    const { Model, DataTypes } = require('sequelize');
    const sequelize = require('../config/database');

    class UserModel extends Model {}

    UserModel.init({
        id: {
            type: DataTypes.INTEGER,
            autoIncrement: true,
            primaryKey: true,
        },
        username: {
            type: DataTypes.STRING(50),
            allowNull: false,
            unique: true,
        },
        password_hash: {
            type: DataTypes.STRING(255),
            allowNull: false,
        },
        created_at: {
            type: DataTypes.DATE,
            defaultValue: DataTypes.NOW,
        },
    }, {
        sequelize,
        modelName: 'User',
        tableName: 'Users',
        timestamps: false,
    });

    User = UserModel;
} catch (err) {
    console.log('Sequelize not available, User model disabled');
    User = null;
}

module.exports = User;