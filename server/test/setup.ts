/**
 * Vitest Test Setup
 *
 * This file runs before all tests to set up the test environment.
 */

import { beforeAll, afterAll } from 'vitest';
import dotenv from 'dotenv';
import { lstatSync, statSync } from 'node:fs';
import { assertInvitationTestDatabase } from './helpers/invitations-migration-db.js';
import { installLoopbackListen } from './helpers/loopback-listen.js';

// supertest's per-request server binds 127.0.0.1 so another local process can never answer a test request
// (see test/helpers/loopback-listen.ts).
installLoopbackListen();

// A focused invitation run must fail before dotenv can open the human's env pipe.
if (process.argv.some(arg => arg.includes('invitations-legacy-contract'))) {
  const leased = assertInvitationTestDatabase(process.env.TEST_DATABASE_URL);
  if (process.env.DATABASE_URL !== leased || process.env.DIRECT_URL !== leased) {
    throw new Error('Invitation tests require all database URLs to match the lease');
  }
}

// Never open a named pipe, even in a full-suite run or through a symlink.
for (const path of ['.env.test', '.env']) {
  try {
    const entry = lstatSync(path);
    if (entry.isFIFO() || (entry.isSymbolicLink() && statSync(path).isFIFO())) {
      throw new Error(`Test setup refuses named pipe ${path}`);
    }
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
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
