import { useEffect, useState } from 'react';
import Autocomplete from '@mui/material/Autocomplete';
import TextField from '@mui/material/TextField';
import CircularProgress from '@mui/material/CircularProgress';
import { api } from '../api/client';

interface PageEnvelope<T> {
  content: T[];
  totalElements: number;
}

interface Props<T> {
  label: string;
  value: T | null;
  onChange: (value: T | null) => void;
  /** Paginated list endpoint returning a { content } envelope. */
  endpoint: string;
  params?: Record<string, string | number | undefined>;
  getOptionLabel: (option: T) => string;
  isOptionEqualToValue: (a: T, b: T) => boolean;
  fullWidth?: boolean;
}

/**
 * Async, server-searched single-select. Fetches at most a handful of options
 * matching the typed term instead of loading an entire (potentially huge)
 * collection into a native `<select>`.
 */
export default function EntityAutocomplete<T>({
  label,
  value,
  onChange,
  endpoint,
  params,
  getOptionLabel,
  isOptionEqualToValue,
  fullWidth = true,
}: Props<T>) {
  const [open, setOpen] = useState(false);
  const [input, setInput] = useState('');
  const [options, setOptions] = useState<T[]>([]);
  const [loading, setLoading] = useState(false);
  const paramsKey = JSON.stringify(params ?? {});

  useEffect(() => {
    if (!open) return;
    let active = true;
    setLoading(true);
    const handle = setTimeout(() => {
      const query: Record<string, string | number> = { page: 0, size: 20 };
      const extra = params ?? {};
      for (const [k, v] of Object.entries(extra)) {
        if (v !== undefined && v !== '') query[k] = v;
      }
      if (input.trim()) query.q = input.trim();
      api
        .get<PageEnvelope<T>>(endpoint, { params: query })
        .then((r) => {
          if (active) setOptions(r.data.content);
        })
        .catch(() => {
          if (active) setOptions([]);
        })
        .finally(() => {
          if (active) setLoading(false);
        });
    }, 250);
    return () => {
      active = false;
      clearTimeout(handle);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, input, endpoint, paramsKey]);

  return (
    <Autocomplete
      open={open}
      onOpen={() => setOpen(true)}
      onClose={() => setOpen(false)}
      value={value}
      onChange={(_, v) => onChange(v)}
      inputValue={input}
      onInputChange={(_, v) => setInput(v)}
      options={options}
      loading={loading}
      getOptionLabel={getOptionLabel}
      isOptionEqualToValue={isOptionEqualToValue}
      filterOptions={(x) => x}
      fullWidth={fullWidth}
      noOptionsText={input.trim() ? 'Sin coincidencias' : 'Escribe para buscar…'}
      renderInput={(p) => (
        <TextField
          {...p}
          label={label}
          InputProps={{
            ...p.InputProps,
            endAdornment: (
              <>
                {loading ? <CircularProgress color="inherit" size={16} /> : null}
                {p.InputProps.endAdornment}
              </>
            ),
          }}
        />
      )}
    />
  );
}
