import { useEffect, useState } from 'react';
import type { ChangeEvent } from 'react';
import Typography from '@mui/material/Typography';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Paper from '@mui/material/Paper';
import Card from '@mui/material/Card';
import CardContent from '@mui/material/CardContent';
import Table from '@mui/material/Table';
import TableBody from '@mui/material/TableBody';
import TableCell from '@mui/material/TableCell';
import TableContainer from '@mui/material/TableContainer';
import TableHead from '@mui/material/TableHead';
import TableRow from '@mui/material/TableRow';
import TextField from '@mui/material/TextField';
import MenuItem from '@mui/material/MenuItem';
import Stack from '@mui/material/Stack';
import Chip from '@mui/material/Chip';
import Divider from '@mui/material/Divider';

import { api, errMsg } from '../api/client';
import type { AuditEntry, AuditStats } from '../api/types';
import { useToast } from '../ui/Toast';
import PageHeader from '../ui/PageHeader';
import { EmptyRow } from '../ui/TableStates';
import { useDataTable } from '../ui/useDataTable';
import DataTablePagination from '../ui/DataTablePagination';

const ENTITY_TYPES = ['', 'CUSTOMER', 'ACCOUNT', 'CARD', 'LOAN', 'BATCH'];
const MONO = '"JetBrains Mono", ui-monospace, monospace';

function jsonCell(value: unknown): string {
  if (value === null || value === undefined) return '—';
  if (typeof value === 'string') return value;
  return JSON.stringify(value);
}

export default function Audit() {
  const toast = useToast();
  const [filters, setFilters] = useState({
    entityType: '',
    entityId: '',
    username: '',
    operation: '',
    dateFrom: '',
    dateTo: '',
  });
  const [entries, setEntries] = useState<AuditEntry[]>([]);
  const [stats, setStats] = useState<AuditStats | null>(null);

  const search = () => {
    const params: Record<string, string | number> = { limit: 100 };
    if (filters.entityType) params.entityType = filters.entityType;
    if (filters.entityId) params.entityId = Number(filters.entityId);
    if (filters.username) params.username = filters.username;
    if (filters.operation) params.operation = filters.operation;
    if (filters.dateFrom) params.dateFrom = filters.dateFrom;
    if (filters.dateTo) params.dateTo = filters.dateTo;
    api
      .get<{ entries: AuditEntry[] }>('/audit', { params })
      .then((r) => setEntries(r.data.entries))
      .catch((e) => toast(errMsg(e), 'error'));
  };

  useEffect(() => {
    api
      .get<AuditStats>('/audit/stats')
      .then((r) => setStats(r.data))
      .catch((e) => toast(errMsg(e), 'error'));
    search();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const set = (k: keyof typeof filters) => (e: ChangeEvent<HTMLInputElement>) =>
    setFilters((f) => ({ ...f, [k]: e.target.value }));

  const dt = useDataTable(entries, { initialRowsPerPage: 50 });

  return (
    <Box>
      <PageHeader title="Auditoría" subtitle="Rastro completo de operaciones con filtros avanzados" />

      {stats && (
        <Card sx={{ mb: 3 }}>
          <CardContent>
            <Typography variant="body2" color="text.secondary">
              {stats.totalEntries} eventos · {stats.distinctUsers} usuarios · desde {stats.firstEvent} hasta{' '}
              {stats.lastEvent}
            </Typography>
            <Divider sx={{ my: 1 }} />
            <Stack direction="row" spacing={1} useFlexGap flexWrap="wrap">
              {stats.byEntity.map((g) => (
                <Chip key={g.name} label={`${g.name}: ${g.count}`} variant="outlined" />
              ))}
            </Stack>
          </CardContent>
        </Card>
      )}

      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Stack direction="row" spacing={2} useFlexGap flexWrap="wrap" alignItems="center">
            <TextField
              select
              label="Entidad"
              value={filters.entityType}
              onChange={set('entityType')}
              sx={{ minWidth: 140 }}
            >
              {ENTITY_TYPES.map((t) => (
                <MenuItem key={t || 'all'} value={t}>
                  {t || 'Todas'}
                </MenuItem>
              ))}
            </TextField>
            <TextField label="ID entidad" type="number" value={filters.entityId} onChange={set('entityId')} />
            <TextField label="Usuario" value={filters.username} onChange={set('username')} />
            <TextField label="Operación" value={filters.operation} onChange={set('operation')} />
            <TextField
              label="Desde"
              type="date"
              value={filters.dateFrom}
              onChange={set('dateFrom')}
              InputLabelProps={{ shrink: true }}
            />
            <TextField
              label="Hasta"
              type="date"
              value={filters.dateTo}
              onChange={set('dateTo')}
              InputLabelProps={{ shrink: true }}
            />
            <Button variant="contained" onClick={search}>
              Buscar
            </Button>
          </Stack>
        </CardContent>
      </Card>

      <Paper variant="outlined">
        <TableContainer sx={{ maxHeight: 560 }}>
          <Table size="small" stickyHeader>
            <TableHead>
              <TableRow>
                <TableCell>ID</TableCell>
                <TableCell>Fecha</TableCell>
                <TableCell>Usuario</TableCell>
                <TableCell>Operación</TableCell>
                <TableCell>Entidad</TableCell>
                <TableCell>Anterior</TableCell>
                <TableCell>Nuevo</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {dt.paged.length === 0 ? (
                <EmptyRow cols={7} message="No hay eventos para los filtros aplicados" />
              ) : (
                dt.paged.map((e) => (
                <TableRow key={e.auditId} hover>
                  <TableCell>{e.auditId}</TableCell>
                  <TableCell>{e.eventTime}</TableCell>
                  <TableCell>{e.username}</TableCell>
                  <TableCell>{e.operation}</TableCell>
                  <TableCell>
                    {e.entityType} #{e.entityId}
                  </TableCell>
                  <TableCell sx={{ maxWidth: 240, fontFamily: MONO, fontSize: 11.5 }}>
                    {jsonCell(e.oldValue)}
                  </TableCell>
                  <TableCell sx={{ maxWidth: 240, fontFamily: MONO, fontSize: 11.5 }}>
                    {jsonCell(e.newValue)}
                  </TableCell>
                </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </TableContainer>
        <DataTablePagination
          count={dt.total}
          page={dt.page}
          rowsPerPage={dt.rowsPerPage}
          onPageChange={dt.onChangePage}
          onRowsPerPageChange={dt.onChangeRowsPerPage}
        />
      </Paper>
    </Box>
  );
}
