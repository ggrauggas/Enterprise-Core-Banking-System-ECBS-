import axios from 'axios';

/** Axios instance pointing at the backend API (proxied by Vite / nginx). */
export const api = axios.create({
  baseURL: '/api/v1',
  headers: { 'X-ECBS-User': 'web-ui' },
});

/** Extracts a human message from an API error (ECBS problem body or axios). */
export function errMsg(e: unknown): string {
  if (axios.isAxiosError(e)) {
    const data = e.response?.data as { message?: string; errorCode?: string } | undefined;
    if (data?.message) {
      return data.errorCode && data.errorCode !== 'VALIDATION'
        ? `${data.errorCode}: ${data.message}`
        : data.message;
    }
    return e.message;
  }
  return String(e);
}

/**
 * Currency formatter (EUR, Spanish locale).
 *
 * The `Intl.NumberFormat` instance is built once and reused: constructing it
 * per cell is comparatively expensive and shows up when rendering long lists.
 */
const eurFormat = new Intl.NumberFormat('es-ES', { style: 'currency', currency: 'EUR' });

export function eur(value: number | string | undefined): string {
  const n = typeof value === 'string' ? Number(value) : value ?? 0;
  return eurFormat.format(Number.isFinite(n) ? n : 0);
}
