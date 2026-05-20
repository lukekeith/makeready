/**
 * Request Test Helpers
 *
 * Utilities for making test requests
 */

import request from 'supertest';
import type { Express } from 'express';
import type { User } from '../../src/generated/prisma';

/**
 * Create an authenticated request helper
 */
export function createAuthenticatedAgent(app: Express, mockUser: User) {
  // In a real app, you'd set up session/cookie here
  // For now, we'll rely on mocking at the middleware level
  return request(app);
}

/**
 * Helper to expect validation error
 */
export function expectValidationError(response: any, field?: string) {
  expect(response.status).toBe(400);
  expect(response.body).toHaveProperty('error');
  if (field) {
    expect(response.body.error.toLowerCase()).toContain(field.toLowerCase());
  }
}

/**
 * Helper to expect authentication error
 */
export function expectAuthenticationError(response: any) {
  expect(response.status).toBe(401);
  expect(response.body).toHaveProperty('error');
  expect(response.body.error.toLowerCase()).toContain('auth');
}

/**
 * Helper to expect success response
 */
export function expectSuccess(response: any) {
  expect(response.status).toBe(200);
  expect(response.body).toHaveProperty('success');
  expect(response.body.success).toBe(true);
}

/**
 * Helper to expect not found error
 */
export function expectNotFound(response: any) {
  expect(response.status).toBe(404);
  expect(response.body).toHaveProperty('error');
}
