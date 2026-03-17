let Calculation;

try {
    const { Model, DataTypes } = require('sequelize');
    const sequelize = require('../config/database');

    class CalculationModel extends Model {}

    CalculationModel.init({
        id: {
            type: DataTypes.INTEGER,
            autoIncrement: true,
            primaryKey: true,
        },
        user_id: {
            type: DataTypes.INTEGER,
            references: {
                model: 'Users',
                key: 'id',
            },
            onDelete: 'CASCADE',
        },
        expression: {
            type: DataTypes.STRING(255),
            allowNull: false,
        },
        result: {
            type: DataTypes.DECIMAL(10, 2),
            allowNull: false,
        },
        created_at: {
            type: DataTypes.DATE,
            defaultValue: DataTypes.NOW,
        },
    }, {
        sequelize,
        modelName: 'Calculation',
        tableName: 'Calculations',
        timestamps: false,
    });

    Calculation = CalculationModel;
} catch (err) {
    console.log('Sequelize not available, Calculation model disabled');
    Calculation = null;
}

module.exports = Calculation;