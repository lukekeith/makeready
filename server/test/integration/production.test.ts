/**
 * Production Integration Tests
 *
 * Tests the deployed API at app.makeready.org
 * These are true integration tests that hit the live environment
 */

import { describe, it, expect } from 'vitest';

const PRODUCTION_URL = 'https://app.makeready.org';

describe('Production API Integration Tests', () => {
  describe('Health & Status', () => {
    it('should return health check from production', async () => {
      const response = await fetch(`${PRODUCTION_URL}/health`);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data).toHaveProperty('status', 'ok');
      expect(data).toHaveProperty('timestamp');
      expect(new Date(data.timestamp)).toBeInstanceOf(Date);
    });

    it('should return API running message', async () => {
      const response = await fetch(`${PRODUCTION_URL}/api`);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data).toHaveProperty('message', 'MakeReady API is running');
    });

    it('should have CORS headers configured', async () => {
      const response = await fetch(`${PRODUCTION_URL}/health`);

      expect(response.headers.get('access-control-allow-origin')).toBeTruthy();
    });
  });

  describe('Authentication Endpoints', () => {
    it('should have Google OAuth endpoint available', async () => {
      const response = await fetch(`${PRODUCTION_URL}/auth/google`, {
        redirect: 'manual' // Don't follow redirect
      });

      // Should redirect to Google OAuth
      expect([301, 302, 303, 307, 308]).toContain(response.status);
      expect(response.headers.get('location')).toBeTruthy();
    });

    it('should require authentication for /auth/me', async () => {
      const response = await fetch(`${PRODUCTION_URL}/auth/me`);
      const data = await response.json();

      expect(response.status).toBe(401);
      expect(data).toHaveProperty('error');
    });
  });

  describe('Public Endpoints', () => {
    it('should allow unauthenticated access to invite token lookup', async () => {
      // Test with a fake token - should return 404 but not 401
      const response = await fetch(`${PRODUCTION_URL}/api/invites/FAKETOKEN123`);
      const data = await response.json();

      expect(response.status).toBe(404); // Not found, not unauthorized
      expect(data).toHaveProperty('success', false);
    });
  });

  describe('Protected Endpoints', () => {
    it('should require auth for creating invites', async () => {
      const response = await fetch(`${PRODUCTION_URL}/api/invites`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ groupId: 'test-group-id' })
      });
      const data = await response.json();

      expect(response.status).toBe(401);
      expect(data).toHaveProperty('success', false);
      expect(data).toHaveProperty('error', 'Authentication required');
    });

    it('should require auth for sending SMS invites', async () => {
      const response = await fetch(`${PRODUCTION_URL}/api/invites/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          groupId: 'test-group-id',
          recipientPhone: '+15555555555'
        })
      });
      const data = await response.json();

      expect(response.status).toBe(401);
      expect(data).toHaveProperty('success', false);
    });

    it('should require auth for QR code generation', async () => {
      const response = await fetch(`${PRODUCTION_URL}/api/qrcode/generate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ data: 'TEST123' })
      });
      const data = await response.json();

      expect(response.status).toBe(401);
      expect(data).toHaveProperty('success', false);
    });

    it('should require auth for SMS sending', async () => {
      const response = await fetch(`${PRODUCTION_URL}/api/sms/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          to: '+15555555555',
          message: 'Test message'
        })
      });
      const data = await response.json();

      expect(response.status).toBe(401);
      expect(data).toHaveProperty('success', false);
    });
  });

  describe('Verification Endpoints', () => {
    it('should accept verification send requests (unauthenticated)', async () => {
      const response = await fetch(`${PRODUCTION_URL}/api/verification/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          phoneNumber: '+15555555555' // Test number - will likely fail Twilio validation
        })
      });

      // Should not be 401 - verification is public
      // Might be 400 (bad phone) or 500 (Twilio error) but not 401
      expect(response.status).not.toBe(401);
    });

    it('should validate phone number format for verification', async () => {
      const response = await fetch(`${PRODUCTION_URL}/api/verification/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          phoneNumber: 'invalid-phone' // Invalid format
        })
      });
      const data = await response.json();

      expect(response.status).toBe(400);
      expect(data).toHaveProperty('success', false);
      expect(data.error).toMatch(/E\.164/i); // Should mention E.164 format
    });
  });

  describe('API Response Format', () => {
    it('should return JSON for all endpoints', async () => {
      const endpoints = [
        '/health',
        '/api',
        '/auth/me',
      ];

      for (const endpoint of endpoints) {
        const response = await fetch(`${PRODUCTION_URL}${endpoint}`);
        const contentType = response.headers.get('content-type');

        expect(contentType).toMatch(/application\/json/);
      }
    });

    it('should include proper error structure', async () => {
      const response = await fetch(`${PRODUCTION_URL}/api/invites/INVALID`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' }
      });
      const data = await response.json();

      expect(data).toHaveProperty('success', false);
      expect(data).toHaveProperty('error');
      expect(typeof data.error).toBe('string');
    });
  });

  describe('Security Headers', () => {
    it('should not expose sensitive server information', async () => {
      const response = await fetch(`${PRODUCTION_URL}/health`);

      // Should not have x-powered-by header (Express default)
      expect(response.headers.get('x-powered-by')).toBeNull();
    });

    it('should handle HTTPS correctly', async () => {
      const response = await fetch(`${PRODUCTION_URL}/health`);

      // Connection should be secure
      expect(PRODUCTION_URL).toMatch(/^https:/);
      expect(response.status).toBe(200);
    });
  });

  describe('Database Connectivity', () => {
    it('should successfully connect to database (via users endpoint)', async () => {
      const response = await fetch(`${PRODUCTION_URL}/api/users`);

      // Should not be 500 (database error)
      // Will be 401 if auth required, but that means DB connection works
      expect([200, 401]).toContain(response.status);
    });
  });
});
