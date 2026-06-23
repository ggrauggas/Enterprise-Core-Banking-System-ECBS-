import { afterEach, describe, expect, it, vi } from 'vitest';
import { act, renderHook, waitFor } from '@testing-library/react';
import { api } from '../api/client';
import { useServerTable } from './useServerTable';

interface Row {
  id: number;
}

function mockPage() {
  return vi.spyOn(api, 'get').mockImplementation((_url: string, config?: { params?: Record<string, unknown> }) => {
    const params = config?.params ?? {};
    return Promise.resolve({ data: { content: [{ id: 1 }], totalElements: 137 }, __params: params } as never);
  });
}

function lastParams(spy: ReturnType<typeof mockPage>) {
  const call = spy.mock.calls.at(-1);
  return (call?.[1] as { params?: Record<string, unknown> } | undefined)?.params ?? {};
}

describe('useServerTable', () => {
  afterEach(() => vi.restoreAllMocks());

  it('fetches the first page and exposes the server total', async () => {
    const spy = mockPage();
    const { result } = renderHook(() => useServerTable<Row>('/customers'));

    await waitFor(() => expect(result.current.loading).toBe(false));
    expect(result.current.rows).toHaveLength(1);
    expect(result.current.total).toBe(137);
    expect(lastParams(spy)).toMatchObject({ page: 0, size: 25 });
  });

  it('requests a new page from the server on page change', async () => {
    const spy = mockPage();
    const { result } = renderHook(() => useServerTable<Row>('/customers'));
    await waitFor(() => expect(result.current.loading).toBe(false));

    act(() => result.current.onChangePage(null, 3));

    await waitFor(() => expect(lastParams(spy)).toMatchObject({ page: 3 }));
  });

  it('sends the debounced search term as q', async () => {
    const spy = mockPage();
    const { result } = renderHook(() => useServerTable<Row>('/customers'));
    await waitFor(() => expect(result.current.loading).toBe(false));

    act(() => result.current.onSearch('lovelace'));

    await waitFor(() => expect(lastParams(spy)).toMatchObject({ q: 'lovelace', page: 0 }));
    expect(result.current.isFiltered).toBe(true);
  });
});
