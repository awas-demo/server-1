let sequelize;

try {
    const { Sequelize } = require('sequelize');
    
    sequelize = new Sequelize(
        process.env.DB_NAME || 'server_db', 
        process.env.DB_USER || 'postgres', 
        process.env.DB_PASSWORD || 'postgres', 
        {
            host: process.env.DB_HOST || 'localhost',
            dialect: 'postgres',
            logging: process.env.NODE_ENV === 'development' ? console.log : false,
        }
    );
} catch (err) {
    console.log('Sequelize not available, database functionality disabled');
    // Create a mock sequelize object to prevent errors
    sequelize = {
        authenticate: async () => { throw new Error('Database not available'); },
        sync: async () => { throw new Error('Database not available'); }
    };
}

module.exports = sequelize;