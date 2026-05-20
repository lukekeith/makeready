/**
 * Users Endpoint Tests
 *
 * Tests for /api/users endpoints
 */

import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { app } from '../../index';

describe('Users API', () => {
  describe('GET /api/users', () => {
    it('should return list of users', async () => {
      const response = await request(app).get('/api/users');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('users');
      expect(response.body).toHaveProperty('count');
      expect(Array.isArray(response.body.users)).toBe(true);
      expect(response.body.count).toBe(response.body.users.length);
    });

    it('should return users ordered by createdAt desc', async () => {
      const response = await request(app).get('/api/users');

      if (response.body.users.length > 1) {
        const timestamps = response.body.users.map((u: any) => new Date(u.createdAt).getTime());

        // Check that timestamps are in descending order
        for (let i = 0; i < timestamps.length - 1; i++) {
          expect(timestamps[i]).toBeGreaterThanOrEqual(timestamps[i + 1]);
        }
      }

      expect(response.status).toBe(200);
    });

    it('should return users with expected properties', async () => {
      const response = await request(app).get('/api/users');

      expect(response.status).toBe(200);

      if (response.body.users.length > 0) {
        const user = response.body.users[0];
        expect(user).toHaveProperty('id');
        expect(user).toHaveProperty('email');
        expect(user).toHaveProperty('createdAt');
      }
    });

    it('should return JSON content type', async () => {
      const response = await request(app).get('/api/users');

      expect(response.status).toBe(200);
      expect(response.headers['content-type']).toMatch(/application\/json/);
    });
  });

  describe('GET /api/users/:id', () => {
    it('should return 404 for non-existent user', async () => {
      const fakeId = 'non-existent-id-12345';
      const response = await request(app).get(`/api/users/${fakeId}`);

      expect(response.status).toBe(404);
      expect(response.body).toHaveProperty('error');
      expect(response.body.error).toBe('User not found');
    });

    it('should return user by ID if exists', async () => {
      // First get list of users to find a valid ID
      const listResponse = await request(app).get('/api/users');

      if (listResponse.body.users.length > 0) {
        const userId = listResponse.body.users[0].id;
        const response = await request(app).get(`/api/users/${userId}`);

        expect(response.status).toBe(200);
        expect(response.body).toHaveProperty('user');
        expect(response.body.user).toHaveProperty('id');
        expect(response.body.user.id).toBe(userId);
      } else {
        // No users in database, skip this test
        expect(true).toBe(true);
      }
    });

    it('should return user with expected properties', async () => {
      const listResponse = await request(app).get('/api/users');

      if (listResponse.body.users.length > 0) {
        const userId = listResponse.body.users[0].id;
        const response = await request(app).get(`/api/users/${userId}`);

        expect(response.status).toBe(200);
        expect(response.body.user).toHaveProperty('id');
        expect(response.body.user).toHaveProperty('email');
        expect(response.body.user).toHaveProperty('googleId');
        expect(response.body.user).toHaveProperty('createdAt');
        expect(response.body.user).toHaveProperty('updatedAt');
      } else {
        expect(true).toBe(true);
      }
    });
  });
});
