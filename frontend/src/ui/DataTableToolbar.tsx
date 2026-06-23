import TextField from '@mui/material/TextField';
import InputAdornment from '@mui/material/InputAdornment';
import IconButton from '@mui/material/IconButton';
import Stack from '@mui/material/Stack';
import Typography from '@mui/material/Typography';
import SearchIcon from '@mui/icons-material/Search';
import ClearIcon from '@mui/icons-material/Close';
import type { ReactNode } from 'react';

interface Props {
  query: string;
  onSearch: (value: string) => void;
  placeholder?: string;
  /** Total matching rows reported by the server. */
  total: number;
  isFiltered: boolean;
  /** Optional extra controls rendered on the right (e.g. status filter). */
  children?: ReactNode;
}

/** Search box + result count shown above a paginated data table. */
export default function DataTableToolbar({
  query,
  onSearch,
  placeholder,
  total,
  isFiltered,
  children,
}: Props) {
  return (
    <Stack
      direction={{ xs: 'column', sm: 'row' }}
      alignItems={{ xs: 'stretch', sm: 'center' }}
      justifyContent="space-between"
      spacing={1.5}
      sx={{ mb: 1.5 }}
    >
      <TextField
        size="small"
        value={query}
        onChange={(e) => onSearch(e.target.value)}
        placeholder={placeholder ?? 'Buscar…'}
        sx={{ width: { xs: '100%', sm: 320 } }}
        InputProps={{
          startAdornment: (
            <InputAdornment position="start">
              <SearchIcon fontSize="small" sx={{ color: 'text.disabled' }} />
            </InputAdornment>
          ),
          endAdornment: query ? (
            <InputAdornment position="end">
              <IconButton size="small" aria-label="Limpiar búsqueda" onClick={() => onSearch('')}>
                <ClearIcon fontSize="small" />
              </IconButton>
            </InputAdornment>
          ) : null,
        }}
      />
      <Stack direction="row" alignItems="center" spacing={1.5}>
        {children}
        <Typography variant="body2" color="text.secondary" sx={{ whiteSpace: 'nowrap' }}>
          {total.toLocaleString('es-ES')} {isFiltered ? 'resultados' : total === 1 ? 'registro' : 'registros'}
        </Typography>
      </Stack>
    </Stack>
  );
}
