import { defineConfig, configDefaults } from 'vitest/config';
import path from 'path';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    // test/rate-limit-verification.test.ts is a manual tsx script (no
    // describe/it; fires real HTTP at a running server) — exclude it so vitest
    // doesn't collect it and fail with "No test suite found".
    exclude: [...configDefaults.exclude, 'test/rate-limit-verification.test.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov'],
      exclude: [
        'node_modules/',
        'dist/',
        'src/generated/',
        '**/*.config.*',
        '**/*.d.ts',
        'test/setup.ts',
        'test/helpers/**',
      ],
      thresholds: {
        lines: 55,
        functions: 64,
        branches: 70,
        statements: 55,
        // Enrollment-edit feature (monday#12270302158): keep it fully covered.
        // Branch < 100 only because of two plural-"s" ternaries, a random
        // code-collision retry loop, and one `?? null` default — all trivial.
        'src/services/enrollment-edit.ts': { lines: 100, functions: 100, statements: 100, branches: 88 },
        'src/services/enrollment-schedule.ts': { lines: 100, functions: 100, statements: 100, branches: 100 },
      },
    },
    setupFiles: ['./test/setup.ts'],
    testTimeout: 10000,
    // Test files share a single Postgres database, and some suites wipe whole
    // tables in beforeEach. Running files in parallel makes those writes race —
    // causing deadlocks and foreign-key violations (e.g. one file deletes a
    // group while another is creating an enrollment that references it). Run
    // files serially so only one suite touches the DB at a time.
    fileParallelism: false,
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
