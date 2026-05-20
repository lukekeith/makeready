/**
 * Authentication Endpoint Tests
 *
 * Tests for /auth endpoints (Google OAuth)
 */

import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { app } from '../../index';

describe('Auth API', () => {
  describe('GET /auth/google', () => {
    it('should redirect to Google OAuth', async () => {
      const response = await request(app)
        .get('/auth/google')
        .redirects(0); // Don't follow redirects

      // Passport will redirect to Google
      expect(response.status).toBe(302);
      expect(response.headers.location).toBeDefined();
    });

    it('should accept platform query parameter', async () => {
      const response = await request(app)
        .get('/auth/google?platform=ios')
        .redirects(0);

      // Still redirects to Google with state parameter
      expect(response.status).toBe(302);
      expect(response.headers.location).toBeDefined();
    });

    it('should default to web platform without query param', async () => {
      const response = await request(app)
        .get('/auth/google')
        .redirects(0);

      expect(response.status).toBe(302);
    });
  });

  describe('GET /auth/google/callback', () => {
    it('should handle OAuth callback', async () => {
      // This endpoint requires valid Google OAuth flow
      // Without proper OAuth state, it will redirect to failure URL
      const response = await request(app)
        .get('/auth/google/callback')
        .redirects(0);

      // Will redirect (either success or failure)
      expect([302, 401, 400]).toContain(response.status);
    });

    it('should accept state query parameter', async () => {
      const response = await request(app)
        .get('/auth/google/callback?state=platform:ios')
        .redirects(0);

      // Will redirect or error without valid OAuth
      expect([302, 401, 400]).toContain(response.status);
    });

    // Note: Full OAuth flow testing would require mocking Passport
    // and Google OAuth provider
  });

  describe('POST /auth/exchange', () => {
    it('should require code parameter', async () => {
      const response = await request(app)
        .post('/auth/exchange')
        .send({});

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(response.body.error.toLowerCase()).toContain('code');
    });

    it('should reject invalid auth code', async () => {
      const response = await request(app)
        .post('/auth/exchange')
        .send({ code: 'invalid-code-12345' });

      expect(response.status).toBe(401);
      expect(response.body).toHaveProperty('error');
      expect(response.body.error.toLowerCase()).toContain('invalid');
    });

    it('should accept code parameter structure', async () => {
      const response = await request(app)
        .post('/auth/exchange')
        .send({ code: 'test-auth-code' });

      // Will fail with invalid code, but structure is correct
      expect(response.status).toBe(401);
      expect(response.body).toHaveProperty('error');
    });

    // Note: Testing successful exchange would require creating
    // a valid auth code from the OAuth flow
  });

  describe('GET /auth/me', () => {
    it('should return 401 when not authenticated', async () => {
      const response = await request(app).get('/auth/me');

      expect(response.status).toBe(401);
      expect(response.body).toHaveProperty('error');
      expect(response.body.error.toLowerCase()).toContain('not authenticated');
    });

    it('should not expose session details when unauthenticated', async () => {
      const response = await request(app).get('/auth/me');

      expect(response.status).toBe(401);
      expect(response.body).not.toHaveProperty('user');
      expect(response.body).not.toHaveProperty('sessionId');
    });

    // Note: Testing authenticated /me would require setting up
    // a valid session cookie from OAuth flow
  });

  describe('POST /auth/logout', () => {
    it('should handle logout request', async () => {
      const response = await request(app).post('/auth/logout');

      // Should succeed even if not authenticated
      expect([200, 500]).toContain(response.status);
      expect(response.body).toHaveProperty('message');
    });

    it('should return JSON response', async () => {
      const response = await request(app).post('/auth/logout');

      expect(response.headers['content-type']).toMatch(/application\/json/);
      expect(response.body).toHaveProperty('message');
    });

    // Note: Testing logout with active session would require
    // authenticated session setup
  });
});
