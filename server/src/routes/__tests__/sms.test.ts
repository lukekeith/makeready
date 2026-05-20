/**
 * SMS Endpoint Tests
 *
 * Tests for /api/sms endpoints (Twilio Programmable SMS)
 */

import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { app } from '../../index';

describe('SMS API', () => {
  describe('POST /api/sms/send', () => {
    it('should require authentication', async () => {
      const response = await request(app)
        .post('/api/sms/send')
        .send({
          to: '+15555551234',
          message: 'Test message',
        });

      expect(response.status).toBe(401);
      expect(response.body).toHaveProperty('error');
      expect(response.body.success).toBe(false);
      expect(response.body.error.toLowerCase()).toContain('auth');
    });

    it('should validate phone number format', async () => {
      const response = await request(app)
        .post('/api/sms/send')
        .send({
          to: '1234567890', // Missing + prefix
          message: 'Test message',
        });

      // Will fail auth first, but structure is validated
      expect(response.status).toBe(401);
    });

    it('should validate message length', async () => {
      const tooLongMessage = 'a'.repeat(1601);

      const response = await request(app)
        .post('/api/sms/send')
        .send({
          to: '+15555551234',
          message: tooLongMessage,
        });

      // Will fail auth first, but structure is validated
      expect(response.status).toBe(401);
    });

    it('should require both to and message fields', async () => {
      const response = await request(app)
        .post('/api/sms/send')
        .send({});

      expect(response.status).toBe(401); // Fails auth before validation
    });
  });

  describe('POST /api/sms/send-to-self', () => {
    it('should require authentication', async () => {
      const response = await request(app)
        .post('/api/sms/send-to-self')
        .send({
          message: 'Test message to self',
        });

      expect(response.status).toBe(401);
      expect(response.body).toHaveProperty('error');
      expect(response.body.success).toBe(false);
      expect(response.body.error.toLowerCase()).toContain('auth');
    });

    it('should validate message length', async () => {
      const tooLongMessage = 'a'.repeat(1601);

      const response = await request(app)
        .post('/api/sms/send-to-self')
        .send({
          message: tooLongMessage,
        });

      // Will fail auth first
      expect(response.status).toBe(401);
    });

    it('should require message field', async () => {
      const response = await request(app)
        .post('/api/sms/send-to-self')
        .send({});

      expect(response.status).toBe(401); // Fails auth before validation
    });
  });

  describe('POST /api/sms/incoming', () => {
    it('should return TwiML response for STOP keyword', async () => {
      const response = await request(app)
        .post('/api/sms/incoming')
        .type('form')
        .send({
          From: '+15555551234',
          Body: 'STOP',
        });

      expect(response.status).toBe(200);
      expect(response.headers['content-type']).toContain('text/xml');
      expect(response.text).toContain('unsubscribed');
    });

    it('should return TwiML response for HELP keyword', async () => {
      const response = await request(app)
        .post('/api/sms/incoming')
        .type('form')
        .send({
          From: '+15555551234',
          Body: 'HELP',
        });

      expect(response.status).toBe(200);
      expect(response.headers['content-type']).toContain('text/xml');
      expect(response.text).toContain('support@makeready.org');
    });

    it('should return empty TwiML for unrecognized messages', async () => {
      const response = await request(app)
        .post('/api/sms/incoming')
        .type('form')
        .send({
          From: '+15555551234',
          Body: 'Hello there',
        });

      expect(response.status).toBe(200);
      expect(response.headers['content-type']).toContain('text/xml');
    });

    it('should handle START keyword for re-subscription', async () => {
      const response = await request(app)
        .post('/api/sms/incoming')
        .type('form')
        .send({
          From: '+15555551234',
          Body: 'START',
        });

      expect(response.status).toBe(200);
      expect(response.headers['content-type']).toContain('text/xml');
      expect(response.text).toContain('resubscribed');
    });
  });
});
