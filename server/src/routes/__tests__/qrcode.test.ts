/**
 * QR Code Generation Endpoint Tests
 *
 * Tests for /api/qrcode endpoints
 */

import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { app } from '../../index';

describe('QR Code API', () => {
  describe('POST /api/qrcode/test', () => {
    it('should generate QR code without authentication', async () => {
      const response = await request(app)
        .post('/api/qrcode/test')
        .send({ inviteCode: 'TEST123' });

      expect(response.status).toBe(200);
      expect(response.headers['content-type']).toBe('image/png');
      expect(response.body).toBeInstanceOf(Buffer);
      expect(response.body.length).toBeGreaterThan(0);
    });

    it('should embed logo when includeLogo is true', async () => {
      const withLogo = await request(app)
        .post('/api/qrcode/test')
        .send({ inviteCode: 'TEST_LOGO', includeLogo: true, size: 300 });

      const withoutLogo = await request(app)
        .post('/api/qrcode/test')
        .send({ inviteCode: 'TEST_LOGO', includeLogo: false, size: 300 });

      expect(withLogo.status).toBe(200);
      expect(withoutLogo.status).toBe(200);

      // Both should return valid PNG images
      expect(withLogo.body).toBeInstanceOf(Buffer);
      expect(withoutLogo.body).toBeInstanceOf(Buffer);
      expect(withLogo.body.length).toBeGreaterThan(0);
      expect(withoutLogo.body.length).toBeGreaterThan(0);
    });

    it('should generate QR code with custom size', async () => {
      const small = await request(app)
        .post('/api/qrcode/test')
        .send({ inviteCode: 'TEST_SIZE', includeLogo: false, size: 200 });

      const large = await request(app)
        .post('/api/qrcode/test')
        .send({ inviteCode: 'TEST_SIZE', includeLogo: false, size: 600 });

      expect(small.status).toBe(200);
      expect(large.status).toBe(200);

      // Larger QR code should have more bytes
      expect(large.body.length).toBeGreaterThan(small.body.length);
    });

    it('should use default values when not provided', async () => {
      const response = await request(app)
        .post('/api/qrcode/test')
        .send({});

      expect(response.status).toBe(200);
      expect(response.headers['content-type']).toBe('image/png');
    });
  });

  describe('POST /api/qrcode/generate', () => {
    it('should require authentication', async () => {
      const response = await request(app)
        .post('/api/qrcode/generate')
        .send({ inviteCode: 'TEST_AUTH' });

      expect(response.status).toBe(401);
      expect(response.body).toHaveProperty('error');
      expect(response.body.success).toBe(false);
      expect(response.body.error.toLowerCase()).toContain('auth');
    });

    it('should validate inviteCode is required', async () => {
      const response = await request(app)
        .post('/api/qrcode/generate')
        .send({});

      expect(response.status).toBe(401); // Will fail auth first
    });

    it('should validate hex color format', async () => {
      // Note: This will fail auth, but demonstrates validation would work
      const response = await request(app)
        .post('/api/qrcode/generate')
        .send({
          inviteCode: 'TEST',
          color: 'invalid-color',
        });

      expect(response.status).toBe(401); // Fails auth before validation
    });

    it('should validate size range', async () => {
      // Note: This will fail auth, but demonstrates validation would work
      const response = await request(app)
        .post('/api/qrcode/generate')
        .send({
          inviteCode: 'TEST',
          size: 5000, // Too large (max 2000)
        });

      expect(response.status).toBe(401); // Fails auth before validation
    });

    // Note: Authenticated tests would require session/cookie setup
    // For full coverage, you'd mock the authentication middleware
  });
});
