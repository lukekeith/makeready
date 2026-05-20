import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { resolve } from 'path'

export default defineConfig({
  plugins: [vue()],
  build: {
    outDir: 'dist/standalone',
    rollupOptions: {
      input: resolve(__dirname, 'resources/js/themed-content-standalone.ts'),
      output: {
        entryFileNames: 'themed-content.js',
        assetFileNames: 'themed-content.[ext]',
        // Inline everything into one JS file
        manualChunks: undefined,
      },
    },
    // Inline CSS into JS
    cssCodeSplit: false,
  },
  resolve: {
    alias: {
      '@': resolve(__dirname, 'resources/js'),
    },
  },
})
