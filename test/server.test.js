const request = require('supertest');
const app = require('../index');

describe('Server Tests', () => {
  test('Health check endpoint', async () => {
    const response = await request(app)
      .get('/health')
      .expect(200);
    
    expect(response.body.status).toBe('healthy');
  });

  test('Root endpoint', async () => {
    const response = await request(app)
      .get('/')
      .expect(200);
    
    expect(response.body.message).toBe('Server is running!');
  });

  test('API status endpoint', async () => {
    const response = await request(app)
      .get('/api/status')
      .expect(200);
    
    expect(response.body.status).toBe('active');
  });

  test('404 for unknown routes', async () => {
    const response = await request(app)
      .get('/unknown')
      .expect(404);
    
    expect(response.body.error).toBe('Route not found');
  });
});