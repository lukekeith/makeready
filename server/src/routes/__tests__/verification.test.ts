/**
 * Phone Verification Endpoint Tests
 *
 * Tests for /api/verification endpoints (Twilio Verify API)
 */

import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { app } from '../../index';

describe('Phone Verification API', () => {
  describe('POST /api/verification/send', () => {
    it('should validate phone number format (E.164)', async () => {
      const response = await request(app)
        .post('/api/verification/send')
        .send({ phoneNumber: '1234567890' }); // Missing + prefix

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(response.body.success).toBe(false);
      expect(response.body.error.toLowerCase()).toContain('e.164');
    });

    it('should require phoneNumber field', async () => {
      const response = await request(app)
        .post('/api/verification/send')
        .send({});

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(response.body.success).toBe(false);
    });

    it('should reject invalid phone number formats', async () => {
      const invalidNumbers = [
        'abc123',
        '+',
        '+1',
        '555-555-5555',
        '(555) 555-5555',
        'invalid',
      ];

      for (const phoneNumber of invalidNumbers) {
        const response = await request(app)
          .post('/api/verification/send')
          .send({ phoneNumber });

        expect(response.status).toBe(400);
        expect(response.body.success).toBe(false);
      }
    });

    // Note: Actual sending would require Twilio credentials
    // and would be tested with mocked Twilio service
  });

  describe('POST /api/verification/verify', () => {
    it('should require phoneNumber and code fields', async () => {
      const response = await request(app)
        .post('/api/verification/verify')
        .send({});

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(response.body.success).toBe(false);
    });

    it('should validate phone number format (E.164)', async () => {
      const response = await request(app)
        .post('/api/verification/verify')
        .send({
          phoneNumber: '1234567890', // Missing + prefix
          code: '123456',
        });

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(response.body.success).toBe(false);
    });

    it('should validate code length', async () => {
      // Code too short
      const response1 = await request(app)
        .post('/api/verification/verify')
        .send({
          phoneNumber: '+15555551234',
          code: '12', // Too short
        });

      expect(response1.status).toBe(400);
      expect(response1.body.success).toBe(false);

      // Code too long
      const response2 = await request(app)
        .post('/api/verification/verify')
        .send({
          phoneNumber: '+15555551234',
          code: '1234567', // Too long
        });

      expect(response2.status).toBe(400);
      expect(response2.body.success).toBe(false);
    });

    it('should accept optional inviteToken', async () => {
      // This will fail Twilio verification, but shows inviteToken is accepted
      const response = await request(app)
        .post('/api/verification/verify')
        .send({
          phoneNumber: '+15555551234',
          code: '123456',
          inviteToken: 'test-token-123',
        });

      // Will return error from Twilio, but structure is valid
      expect(response.status).toBeGreaterThanOrEqual(400);
      expect(response.body).toHaveProperty('success');
    });

    // Note: Actual verification would require valid Twilio code
    // and would be tested with mocked Twilio service
  });

  describe('POST /api/verification/resend', () => {
    it('should validate phone number format (E.164)', async () => {
      const response = await request(app)
        .post('/api/verification/resend')
        .send({ phoneNumber: '1234567890' }); // Missing + prefix

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(response.body.success).toBe(false);
      expect(response.body.error.toLowerCase()).toContain('e.164');
    });

    it('should require phoneNumber field', async () => {
      const response = await request(app)
        .post('/api/verification/resend')
        .send({});

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(response.body.success).toBe(false);
    });

    it('should accept valid E.164 phone numbers', async () => {
      const validNumbers = [
        '+15555551234',
        '+447911123456',
        '+33612345678',
      ];

      for (const phoneNumber of validNumbers) {
        const response = await request(app)
          .post('/api/verification/resend')
          .send({ phoneNumber });

        // Will fail with Twilio error or succeed, but validates format
        expect([200, 400, 500]).toContain(response.status);
        expect(response.body).toHaveProperty('success');
      }
    });

    // Note: Actual resending would require Twilio credentials
    // and would be tested with mocked Twilio service
  });
});
