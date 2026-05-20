/**
 * Vitest Test Setup
 *
 * This file runs before all tests to set up the test environment.
 */

import { beforeAll, afterAll } from 'vitest';
import dotenv from 'dotenv';

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
