import path from 'path'
import { defineConfig } from 'vitest/config'
import vue from '@vitejs/plugin-vue'

// Vitest runs from its OWN config rather than vite.config.js, because the main
// config is built around the laravel-vite-plugin (fixed entry inputs, a dev
// manifest, an SCSS load-path shim) — none of which a component test needs, and
// all of which would have to be satisfied for the run to start.
//
// Added 2026-08-04 by docs/features/highlighting/ phase 5.8. Before this the
// client was the ONE workspace with no `test` script, so the repo-root
// `npm test` (which runs `--workspaces`) walked straight past it. The server
// already runs vitest; this matches it.
export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'resources/js'),
    },
  },
  test: {
    // Component tests mount into a DOM; the pure-logic tests don't care.
    environment: 'happy-dom',
    include: ['resources/js/**/*.{test,spec}.ts'],
  },
})
