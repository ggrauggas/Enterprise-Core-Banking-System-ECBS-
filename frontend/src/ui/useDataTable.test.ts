import { describe, expect, it } from 'vitest';
import { act, renderHook, waitFor } from '@testing-library/react';
import { useDataTable } from './useDataTable';

interface Row {
  id: number;
  name: string;
}

const rows: Row[] = Array.from({ length: 57 }, (_, i) => ({ id: i + 1, name: `Row ${i + 1}` }));

describe('useDataTable', () => {
  it('only returns the current page slice', () => {
    const { result } = renderHook(() =>
      useDataTable(rows, { initialRowsPerPage: 25 }),
    );

    expect(result.current.paged).toHaveLength(25);
    expect(result.current.paged[0].id).toBe(1);
    expect(result.current.total).toBe(57);
    expect(result.current.unfilteredTotal).toBe(57);
  });

  it('paginates without re-rendering the whole dataset', () => {
    const { result } = renderHook(() => useDataTable(rows, { initialRowsPerPage: 25 }));

    act(() => result.current.onChangePage(null, 2));

    // Last page holds the remaining 7 rows (50..56).
    expect(result.current.paged).toHaveLength(7);
    expect(result.current.paged[0].id).toBe(51);
  });

  it('filters by the search text and resets to the first page', async () => {
    const { result } = renderHook(() =>
      useDataTable(rows, { getSearchText: (r) => r.name, initialRowsPerPage: 25 }),
    );

    act(() => result.current.onChangePage(null, 1));
    act(() => result.current.onSearch('Row 5'));

    await waitFor(() => expect(result.current.isFiltered).toBe(true));
    // "Row 5", "Row 50".."Row 57" => 9 matches.
    await waitFor(() => expect(result.current.total).toBe(9));
    expect(result.current.page).toBe(0);
  });
});
