import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// In local dev the API calls are proxied to the backend; inside Docker
// the nginx config does the same job.
export default defineConfig({
  plugins: [react()],
  server: {
    host: true,
    port: 3000,
    proxy: {
      '/api': {
        target: process.env.VITE_API_PROXY_TARGET ?? 'http://localhost:8080',
        changeOrigin: true,
      },
    },
  },
});
