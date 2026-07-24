import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // Proxy API calls to the Node service in dev so the browser only ever talks
    // to one origin (no CORS, and VITE_API_URL can stay '/api'). Override the
    // target with the API_PROXY_TARGET env var if the server runs elsewhere.
    proxy: {
      '/api': {
        target: process.env.API_PROXY_TARGET || 'http://localhost:8787',
        changeOrigin: true,
      },
    },
  },
});
