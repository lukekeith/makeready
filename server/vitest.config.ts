import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
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
      },
    },
    setupFiles: ['./test/setup.ts'],
    testTimeout: 10000,
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
