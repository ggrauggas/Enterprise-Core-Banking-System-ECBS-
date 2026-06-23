/// <reference types="vitest/config" />
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
  // Vitest (Fase 14): jsdom environment so React components can render,
  // jest-dom matchers wired up via the setup file.
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
    css: false,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      include: ['src/**/*.{ts,tsx}'],
      exclude: ['src/main.tsx', 'src/**/*.test.{ts,tsx}', 'src/test/**'],
      // Enforce a high bar on the modules that carry real logic (the API
      // client and the shared UI primitives). The page components are CRUD
      // shells exercised end-to-end by the integration smoke suite
      // (tests/smoke-api.sh), so they are not gated here per file.
      thresholds: {
        'src/api/**/*.ts': { statements: 90, branches: 90, functions: 90, lines: 90 },
        'src/ui/**/*.tsx': { statements: 90, branches: 80, functions: 70, lines: 90 },
      },
    },
  },
});
