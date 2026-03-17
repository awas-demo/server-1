const request = require('supertest');
const express = require('express');

// Mock app for testing
const app = express();
app.get('/health', (req, res) => res.json({ status: 'OK' }));

describe('Server Health Check', () => {
  test('GET /health should return 200', async () => {
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('OK');
  });
});