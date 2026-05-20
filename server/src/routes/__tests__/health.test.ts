/**
 * Health Check Endpoint Tests
 *
 * Tests for /health and /api endpoints
 */

import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { app } from '../../index';

describe('Health Check Endpoints', () => {
  describe('GET /health', () => {
    it('should return status ok', async () => {
      const response = await request(app).get('/health');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('status');
      expect(response.body.status).toBe('ok');
      expect(response.body).toHaveProperty('timestamp');
      expect(new Date(response.body.timestamp)).toBeInstanceOf(Date);
    });

    it('should return valid timestamp', async () => {
      const beforeTime = new Date();
      const response = await request(app).get('/health');
      const afterTime = new Date();

      const responseTime = new Date(response.body.timestamp);
      expect(responseTime.getTime()).toBeGreaterThanOrEqual(beforeTime.getTime());
      expect(responseTime.getTime()).toBeLessThanOrEqual(afterTime.getTime());
    });
  });

  describe('GET /api', () => {
    it('should return API running message', async () => {
      const response = await request(app).get('/api');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('message');
      expect(response.body.message).toBe('MakeReady API is running');
    });

    it('should return JSON content type', async () => {
      const response = await request(app).get('/api');

      expect(response.status).toBe(200);
      expect(response.headers['content-type']).toMatch(/application\/json/);
    });
  });
});
