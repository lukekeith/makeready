/**
 * Public Endpoint Tests
 *
 * Tests for /public endpoints (no authentication required)
 */

import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { app } from '../../index';

describe('Public API', () => {
  describe('GET /public/qrcode', () => {
    it('should not require authentication', async () => {
      const response = await request(app)
        .get('/public/qrcode?url=https://makeready.app');

      // Should succeed without auth (not 401)
      expect(response.status).toBe(200);
      expect(response.headers['content-type']).toBe('image/png');
    });

    it('should require url parameter', async () => {
      const response = await request(app)
        .get('/public/qrcode');

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(response.body.success).toBe(false);
    });

    it('should validate url parameter is a valid URL', async () => {
      const invalidUrls = [
        'not-a-url',
        'just-text',
        '12345',
        '',
      ];

      for (const url of invalidUrls) {
        const response = await request(app)
          .get(`/public/qrcode?url=${encodeURIComponent(url)}`);

        expect(response.status).toBe(400);
        expect(response.body).toHaveProperty('error');
        expect(response.body.success).toBe(false);
      }
    });

    it('should accept valid URLs', async () => {
      const validUrls = [
        'https://makeready.app',
        'http://localhost:3001',
        'https://google.com/search?q=test',
        'https://example.com:8080/path',
      ];

      for (const url of validUrls) {
        const response = await request(app)
          .get(`/public/qrcode?url=${encodeURIComponent(url)}`);

        expect(response.status).toBe(200);
        expect(response.headers['content-type']).toBe('image/png');
        expect(response.body).toBeInstanceOf(Buffer);
        expect(response.body.length).toBeGreaterThan(0);
      }
    });

    it('should generate QR code with default settings', async () => {
      const response = await request(app)
        .get('/public/qrcode?url=https://makeready.app');

      expect(response.status).toBe(200);
      expect(response.headers['content-type']).toBe('image/png');
      expect(response.body).toBeInstanceOf(Buffer);
      expect(response.body.length).toBeGreaterThan(0);
    });

    it('should accept custom size parameter', async () => {
      const response = await request(app)
        .get('/public/qrcode?url=https://makeready.app&size=500');

      expect(response.status).toBe(200);
      expect(response.headers['content-type']).toBe('image/png');
    });

    it('should validate size parameter range', async () => {
      // Too small
      const tooSmall = await request(app)
        .get('/public/qrcode?url=https://makeready.app&size=50');

      expect(tooSmall.status).toBe(400);
      expect(tooSmall.body.success).toBe(false);

      // Too large
      const tooLarge = await request(app)
        .get('/public/qrcode?url=https://makeready.app&size=3000');

      expect(tooLarge.status).toBe(400);
      expect(tooLarge.body.success).toBe(false);
    });

    it('should accept includeLogo parameter', async () => {
      const withLogo = await request(app)
        .get('/public/qrcode?url=https://makeready.app&includeLogo=true&size=300');

      const withoutLogo = await request(app)
        .get('/public/qrcode?url=https://makeready.app&includeLogo=false&size=300');

      expect(withLogo.status).toBe(200);
      expect(withoutLogo.status).toBe(200);
      expect(withLogo.headers['content-type']).toBe('image/png');
      expect(withoutLogo.headers['content-type']).toBe('image/png');

      // Both should generate valid QR codes
      expect(withLogo.body.length).toBeGreaterThan(1000);
      expect(withoutLogo.body.length).toBeGreaterThan(1000);

      // QR with logo should typically be larger (2.5-4x)
      // Note: Size difference depends on logo complexity and QR content
      if (withLogo.body.length > withoutLogo.body.length) {
        expect(withLogo.body.length / withoutLogo.body.length).toBeGreaterThan(1.5);
      }
    });

    it('should accept custom color parameters', async () => {
      const response = await request(app)
        .get('/public/qrcode?url=https://makeready.app&color=%23ff0000&bg=%23000000');

      expect(response.status).toBe(200);
      expect(response.headers['content-type']).toBe('image/png');
    });

    it('should validate hex color format', async () => {
      const invalidColor = await request(app)
        .get('/public/qrcode?url=https://makeready.app&color=red');

      expect(invalidColor.status).toBe(400);
      expect(invalidColor.body.success).toBe(false);

      const invalidBg = await request(app)
        .get('/public/qrcode?url=https://makeready.app&bg=invalid');

      expect(invalidBg.status).toBe(400);
      expect(invalidBg.body.success).toBe(false);
    });

    it('should set cache headers', async () => {
      const response = await request(app)
        .get('/public/qrcode?url=https://makeready.app');

      expect(response.status).toBe(200);
      expect(response.headers['cache-control']).toBeDefined();
      expect(response.headers['cache-control']).toContain('public');
    });

    it('should handle complex URLs with query parameters', async () => {
      const complexUrl = 'https://example.com/path?param1=value1&param2=value2#hash';
      const response = await request(app)
        .get(`/public/qrcode?url=${encodeURIComponent(complexUrl)}`);

      expect(response.status).toBe(200);
      expect(response.headers['content-type']).toBe('image/png');
    });
  });
});
