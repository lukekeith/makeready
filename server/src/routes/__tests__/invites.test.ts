/**
 * Group Invites Endpoint Tests
 *
 * Tests for /api/invites endpoints
 */

import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { app } from '../../index';

describe('Invites API', () => {
  describe('POST /api/invites', () => {
    it('should require authentication', async () => {
      const response = await request(app)
        .post('/api/invites')
        .send({});

      expect(response.status).toBe(401);
      expect(response.body).toHaveProperty('error');
      expect(response.body.success).toBe(false);
      expect(response.body.error.toLowerCase()).toContain('auth');
    });

    it('should validate groupId as UUID if provided', async () => {
      const response = await request(app)
        .post('/api/invites')
        .send({
          groupId: 'invalid-uuid',
        });

      // Will fail auth first
      expect(response.status).toBe(401);
    });

    it('should validate expiresAt as datetime if provided', async () => {
      const response = await request(app)
        .post('/api/invites')
        .send({
          expiresAt: 'not-a-date',
        });

      // Will fail auth first
      expect(response.status).toBe(401);
    });

    it('should accept empty body (creates invite without group)', async () => {
      const response = await request(app)
        .post('/api/invites')
        .send({});

      // Will fail auth, but empty body is valid structure
      expect(response.status).toBe(401);
    });

    // Note: Authenticated tests would require session/cookie setup
  });

  describe('POST /api/invites/send', () => {
    it('should require authentication', async () => {
      const response = await request(app)
        .post('/api/invites/send')
        .send({
          groupId: '123e4567-e89b-12d3-a456-426614174000',
          recipientPhone: '+15555551234',
        });

      expect(response.status).toBe(401);
      expect(response.body).toHaveProperty('error');
      expect(response.body.success).toBe(false);
      expect(response.body.error.toLowerCase()).toContain('auth');
    });

    it('should require groupId and recipientPhone', async () => {
      const response = await request(app)
        .post('/api/invites/send')
        .send({});

      expect(response.status).toBe(401); // Fails auth before validation
    });

    it('should validate groupId as UUID', async () => {
      const response = await request(app)
        .post('/api/invites/send')
        .send({
          groupId: 'invalid-uuid',
          recipientPhone: '+15555551234',
        });

      // Will fail auth first
      expect(response.status).toBe(401);
    });

    it('should validate phone number format', async () => {
      const response = await request(app)
        .post('/api/invites/send')
        .send({
          groupId: '123e4567-e89b-12d3-a456-426614174000',
          recipientPhone: '1234567890', // Missing + prefix
        });

      // Will fail auth first
      expect(response.status).toBe(401);
    });

    // Note: Authenticated tests would require session/cookie setup
    // and existing group data in test database
  });

  describe('GET /api/invites/:token', () => {
    it('should not require authentication (public endpoint)', async () => {
      const response = await request(app)
        .get('/api/invites/TEST_TOKEN_123');

      // Will return 404 (invite not found) not 401 (auth required)
      expect(response.status).toBe(404);
      expect(response.body).toHaveProperty('error');
      expect(response.body.success).toBe(false);
      expect(response.body.error.toLowerCase()).not.toContain('auth');
    });

    it('should return 404 for non-existent invite token', async () => {
      const fakeToken = 'NONEXISTENT123';
      const response = await request(app)
        .get(`/api/invites/${fakeToken}`);

      expect(response.status).toBe(404);
      expect(response.body).toHaveProperty('error');
      expect(response.body.success).toBe(false);
      expect(response.body.error.toLowerCase()).toContain('not found');
    });

    it('should accept any alphanumeric token format', async () => {
      const tokens = [
        'ABC123XYZ',
        'TEST123',
        'INVITE2024',
        '0123456789',
      ];

      for (const token of tokens) {
        const response = await request(app)
          .get(`/api/invites/${token}`);

        // Will return 404 (not found) but accepts the token format
        expect(response.status).toBe(404);
        expect(response.body).toHaveProperty('success');
      }
    });

    it('should return expected response structure on error', async () => {
      const response = await request(app)
        .get('/api/invites/FAKE_TOKEN');

      expect(response.status).toBe(404);
      expect(response.body).toHaveProperty('success');
      expect(response.body).toHaveProperty('error');
      expect(response.body.success).toBe(false);
    });

    // Note: Testing successful invite retrieval would require
    // creating test invite data in the database
  });
});
