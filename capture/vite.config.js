import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

const backendTarget = `http://localhost:${process.env.CAPTURE_UI_PORT ?? 5951}`;

export default defineConfig({
  plugins: [react()],
  server: {
    port: Number(process.env.CAPTURE_UI_WEB_PORT ?? 5950),
    strictPort: true,
    proxy: {
      '/api':         { target: backendTarget, changeOrigin: true },
      '/screenshots': { target: backendTarget, changeOrigin: true },
      // Proxy the socket.io WebSocket upgrade to the backend so the Compare UI can
      // live-update on captures. ws:true is required for the protocol upgrade.
      '/socket.io':   { target: backendTarget, changeOrigin: true, ws: true },
    },
  },
});
