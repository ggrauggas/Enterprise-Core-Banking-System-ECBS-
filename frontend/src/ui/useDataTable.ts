import { useCallback, useDeferredValue, useEffect, useMemo, useRef, useState } from 'react';
import type { ChangeEvent } from 'react';

interface Options<T> {
  /** Builds the text a row is matched against when searching. */
  getSearchText?: (row: T) => string;
  initialRowsPerPage?: number;
}

/**
 * Client-side search + pagination for in-memory table data.
 *
 * Only the current page slice is returned, so the table renders a bounded
 * number of rows regardless of dataset size. Filtering runs against a deferred
 * copy of the query (`useDeferredValue`) so typing stays responsive even with
 * tens of thousands of rows.
 */
export function useDataTable<T>(rows: T[], options: Options<T> = {}) {
  const { initialRowsPerPage = 25 } = options;
  const [query, setQuery] = useState('');
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(initialRowsPerPage);

  const deferredQuery = useDeferredValue(query);

  // Keep the latest accessor without making it a memo dependency.
  const getSearchText = useRef(options.getSearchText);
  getSearchText.current = options.getSearchText;

  const filtered = useMemo(() => {
    const q = deferredQuery.trim().toLowerCase();
    const fn = getSearchText.current;
    if (!q || !fn) return rows;
    return rows.filter((r) => fn(r).toLowerCase().includes(q));
  }, [rows, deferredQuery]);

  const pageCount = Math.max(1, Math.ceil(filtered.length / rowsPerPage));

  // Snap the page back into range when the result set shrinks (search/delete).
  useEffect(() => {
    if (page > pageCount - 1) setPage(pageCount - 1);
  }, [page, pageCount]);

  const paged = useMemo(
    () => filtered.slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage),
    [filtered, page, rowsPerPage],
  );

  const onSearch = useCallback((value: string) => {
    setQuery(value);
    setPage(0);
  }, []);

  const onChangePage = useCallback((_: unknown, next: number) => setPage(next), []);

  const onChangeRowsPerPage = useCallback((e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    setRowsPerPage(parseInt(e.target.value, 10));
    setPage(0);
  }, []);

  return {
    query,
    onSearch,
    page,
    rowsPerPage,
    onChangePage,
    onChangeRowsPerPage,
    paged,
    total: filtered.length,
    unfilteredTotal: rows.length,
    isFiltered: deferredQuery.trim().length > 0,
  };
}
