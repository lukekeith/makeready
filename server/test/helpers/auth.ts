/**
 * Authentication Test Helpers
 *
 * Utilities for mocking authentication in tests
 */

import type { User } from '../../src/generated/prisma';

/**
 * Mock authenticated user
 */
export const mockUser: User = {
  id: 'test-user-id',
  googleId: 'google-test-id',
  email: 'test@makeready.app',
  name: 'Test User',
  picture: 'https://example.com/avatar.png',
  phoneNumber: '+15555551234',
  phoneVerified: true,
  createdAt: new Date('2025-01-01'),
  updatedAt: new Date('2025-01-01'),
};

/**
 * Mock unauthenticated user
 */
export const mockUnauthenticatedUser = null;

/**
 * Create a mock request with authenticated user
 */
export function createAuthenticatedRequest(user: User = mockUser) {
  return {
    user,
    isAuthenticated: () => true,
    logout: (callback?: (err: any) => void) => {
      if (callback) callback(null);
    },
  };
}

/**
 * Create a mock request with no authentication
 */
export function createUnauthenticatedRequest() {
  return {
    user: undefined,
    isAuthenticated: () => false,
    logout: (callback?: (err: any) => void) => {
      if (callback) callback(null);
    },
  };
}
