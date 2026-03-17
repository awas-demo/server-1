// Jest setup file for common test configurations

// Set test environment variables
process.env.NODE_ENV = 'test';
process.env.PORT = 3001;
process.env.DB_HOST = 'localhost';
process.env.DB_NAME = 'test_db';
process.env.DB_USER = 'test';
process.env.DB_PASSWORD = 'test';

// Suppress console.log during tests unless explicitly needed
if (process.env.JEST_VERBOSE !== 'true') {
    console.log = jest.fn();
    console.info = jest.fn();
    console.warn = jest.fn();
    console.error = jest.fn();
}

// Global test timeout
jest.setTimeout(10000);