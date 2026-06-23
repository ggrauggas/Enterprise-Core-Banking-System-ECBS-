import { useCallback, useEffect, useRef, useState } from 'react';
import type { ChangeEvent } from 'react';
import { api } from '../api/client';

interface PageEnvelope<T> {
  content: T[];
  totalElements: number;
}

interface Options {
  initialRowsPerPage?: number;
  /** Extra query params sent on every request (e.g. a status filter). */
  params?: Record<string, string | number | undefined>;
  onError?: (e: unknown) => void;
}

/**
 * Server-side pagination + search for a list endpoint that returns a
 * {@code { content, totalElements }} envelope when called with `page`.
 *
 * Only one page of rows is ever fetched and held in memory, so the view scales
 * to arbitrarily large tables. The search term is debounced so typing issues at
 * most one request per pause rather than one per keystroke.
 */
export function useServerTable<T>(endpoint: string, options: Options = {}) {
  const { initialRowsPerPage = 25 } = options;
  const [rows, setRows] = useState<T[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(initialRowsPerPage);
  const [query, setQuery] = useState('');
  const [debouncedQuery, setDebouncedQuery] = useState('');
  const [reloadKey, setReloadKey] = useState(0);

  const extraKey = JSON.stringify(options.params ?? {});
  const paramsRef = useRef(options.params);
  paramsRef.current = options.params;
  const onErrorRef = useRef(options.onError);
  onErrorRef.current = options.onError;

  // Debounce the search term; reset to the first page when it changes.
  useEffect(() => {
    const t = setTimeout(() => {
      setDebouncedQuery(query);
      setPage(0);
    }, 300);
    return () => clearTimeout(t);
  }, [query]);

  // A changed filter (extra params) also resets to the first page.
  useEffect(() => {
    setPage(0);
  }, [extraKey]);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    const params: Record<string, string | number> = {
      page,
      size: rowsPerPage,
    };
    const extra = paramsRef.current ?? {};
    for (const [k, v] of Object.entries(extra)) {
      if (v !== undefined && v !== '') params[k] = v;
    }
    const q = debouncedQuery.trim();
    if (q) params.q = q;

    api
      .get<PageEnvelope<T> | T[]>(endpoint, { params })
      .then((r) => {
        if (cancelled) return;
        const data = r.data;
        if (Array.isArray(data)) {
          // Defensive: a stale backend that ignores `page` returns a plain
          // array. Degrade gracefully instead of crashing on `.content`.
          setRows(data.slice(0, rowsPerPage));
          setTotal(data.length);
        } else {
          setRows(data.content ?? []);
          setTotal(data.totalElements ?? 0);
        }
      })
      .catch((e) => {
        if (cancelled) return;
        setRows([]);
        setTotal(0);
        onErrorRef.current?.(e);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [endpoint, page, rowsPerPage, debouncedQuery, extraKey, reloadKey]);

  const onSearch = useCallback((value: string) => setQuery(value), []);
  const onChangePage = useCallback((_: unknown, next: number) => setPage(next), []);
  const onChangeRowsPerPage = useCallback((e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    setRowsPerPage(parseInt(e.target.value, 10));
    setPage(0);
  }, []);
  /** Refetch the current page (after a create/update/delete). */
  const reload = useCallback(() => setReloadKey((k) => k + 1), []);

  return {
    rows,
    total,
    loading,
    page,
    rowsPerPage,
    query,
    onSearch,
    onChangePage,
    onChangeRowsPerPage,
    reload,
    isFiltered: debouncedQuery.trim().length > 0,
  };
}
