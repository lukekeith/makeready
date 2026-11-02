/**
 * Vitest Test Setup
 *
 * This file runs before all tests to set up the test environment.
 */

import { beforeAll, afterAll } from 'vitest';
import dotenv from 'dotenv';
import { assertInvitationTestDatabase } from './helpers/invitations-migration-db.js';

// A focused invitation run must fail before dotenv can open the human's env pipe.
if (process.argv.some(arg => arg.includes('invitations-legacy-contract'))) {
  const leased = assertInvitationTestDatabase(process.env.TEST_DATABASE_URL);
  if (process.env.DATABASE_URL !== leased || process.env.DIRECT_URL !== leased) {
    throw new Error('Invitation tests require all database URLs to match the lease');
  }
}

// Load test environment variables
dotenv.config({ path: '.env.test' });

// If no test env file, fall back to regular .env
if (!process.env.DATABASE_URL) {
  dotenv.config();
}

// Set NODE_ENV to test
process.env.NODE_ENV = 'test';

// Increase timeout for database operations
beforeAll(async () => {
  console.log('🧪 Test suite starting...');
  console.log(`📍 NODE_ENV: ${process.env.NODE_ENV}`);
});

afterAll(async () => {
  console.log('✅ Test suite completed');
});
