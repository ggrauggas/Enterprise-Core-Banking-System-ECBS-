import { describe, expect, it } from 'vitest';
import { AxiosError, AxiosHeaders } from 'axios';
import { errMsg, eur } from './client';

function axiosErrorWith(data: unknown, message = 'Request failed'): AxiosError {
  const err = new AxiosError(message, 'ERR_BAD_REQUEST');
  err.response = {
    data,
    status: 400,
    statusText: 'Bad Request',
    headers: {},
    config: { headers: new AxiosHeaders() },
  };
  return err;
}

describe('eur', () => {
  it('formats a number as euros', () => {
    const out = eur(1234.5);
    expect(out).toContain('€');
    expect(out).toContain('1');
  });

  it('parses numeric strings', () => {
    expect(eur('250.00')).toContain('€');
  });

  it('treats undefined as zero', () => {
    expect(eur(undefined)).toContain('0');
  });
});

describe('errMsg', () => {
  it('prefixes the ECBS error code for business errors', () => {
    const e = axiosErrorWith({ message: 'DUPLICATE RECORD', errorCode: 'E003' });
    expect(errMsg(e)).toBe('E003: DUPLICATE RECORD');
  });

  it('omits the code for validation errors', () => {
    const e = axiosErrorWith({ message: 'Request validation failed', errorCode: 'VALIDATION' });
    expect(errMsg(e)).toBe('Request validation failed');
  });

  it('falls back to the axios message when no problem body', () => {
    const e = axiosErrorWith(undefined, 'Network Error');
    expect(errMsg(e)).toBe('Network Error');
  });

  it('stringifies non-axios values', () => {
    expect(errMsg('boom')).toBe('boom');
    expect(errMsg(new Error('plain'))).toContain('plain');
  });
});
