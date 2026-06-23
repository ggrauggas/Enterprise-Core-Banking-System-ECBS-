import { useState } from 'react';
import type { ChangeEvent } from 'react';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Paper from '@mui/material/Paper';
import Table from '@mui/material/Table';
import TableBody from '@mui/material/TableBody';
import TableCell from '@mui/material/TableCell';
import TableContainer from '@mui/material/TableContainer';
import TableHead from '@mui/material/TableHead';
import TableRow from '@mui/material/TableRow';
import IconButton from '@mui/material/IconButton';
import Dialog from '@mui/material/Dialog';
import DialogTitle from '@mui/material/DialogTitle';
import DialogContent from '@mui/material/DialogContent';
import DialogActions from '@mui/material/DialogActions';
import TextField from '@mui/material/TextField';
import Stack from '@mui/material/Stack';
import Tooltip from '@mui/material/Tooltip';
import CircularProgress from '@mui/material/CircularProgress';
import AddIcon from '@mui/icons-material/Add';
import EditIcon from '@mui/icons-material/Edit';
import PersonOffIcon from '@mui/icons-material/PersonOff';

import { api, errMsg } from '../api/client';
import type { Customer } from '../api/types';
import { useToast } from '../ui/Toast';
import { useConfirm } from '../ui/ConfirmDialog';
import StatusChip from '../ui/StatusChip';
import PageHeader from '../ui/PageHeader';
import { SkeletonRows, EmptyRow } from '../ui/TableStates';
import { useServerTable } from '../ui/useServerTable';
import DataTableToolbar from '../ui/DataTableToolbar';
import DataTablePagination from '../ui/DataTablePagination';

interface FormState {
  firstName: string;
  lastName: string;
  birthDate: string;
  email: string;
  phone: string;
}

const EMPTY: FormState = { firstName: '', lastName: '', birthDate: '', email: '', phone: '' };

export default function Customers() {
  const toast = useToast();
  const confirm = useConfirm();
  const st = useServerTable<Customer>('/customers', {
    onError: (e) => toast(errMsg(e), 'error'),
  });
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Customer | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [saving, setSaving] = useState(false);

  const openCreate = () => {
    setEditing(null);
    setForm(EMPTY);
    setOpen(true);
  };

  const openEdit = (c: Customer) => {
    setEditing(c);
    setForm({
      firstName: c.firstName,
      lastName: c.lastName,
      birthDate: c.birthDate,
      email: c.email,
      phone: c.phone,
    });
    setOpen(true);
  };

  const save = () => {
    setSaving(true);
    const req = editing
      ? api.put(`/customers/${editing.customerId}`, {
          firstName: form.firstName,
          lastName: form.lastName,
          email: form.email,
          phone: form.phone,
        })
      : api.post('/customers', form);
    req
      .then(() => {
        toast(editing ? 'Cliente actualizado' : 'Cliente creado');
        setOpen(false);
        st.reload();
      })
      .catch((e) => toast(errMsg(e), 'error'))
      .finally(() => setSaving(false));
  };

  const remove = async (c: Customer) => {
    const ok = await confirm({
      title: 'Dar de baja al cliente',
      message:
        'Se realizará la baja lógica. Podrás consultarlo filtrando por estado, pero el cliente dejará de operar.',
      confirmText: 'Dar de baja',
      tone: 'danger',
      icon: <PersonOffIcon fontSize="small" />,
      details: [
        { label: 'Cliente', value: `${c.firstName} ${c.lastName}` },
        { label: 'ID', value: c.customerId, mono: true },
        { label: 'Email', value: c.email },
      ],
    });
    if (!ok) return;
    api
      .delete(`/customers/${c.customerId}`)
      .then(() => {
        toast('Cliente dado de baja');
        st.reload();
      })
      .catch((e) => toast(errMsg(e), 'error'));
  };

  const set = (k: keyof FormState) => (e: ChangeEvent<HTMLInputElement>) =>
    setForm((f) => ({ ...f, [k]: e.target.value }));

  return (
    <Box>
      <PageHeader
        title="Clientes"
        subtitle="Alta, modificación y baja lógica de clientes"
        action={
          <Button variant="contained" startIcon={<AddIcon />} onClick={openCreate}>
            Nuevo cliente
          </Button>
        }
      />

      <DataTableToolbar
        query={st.query}
        onSearch={st.onSearch}
        placeholder="Buscar por nombre, email, teléfono…"
        total={st.total}
        isFiltered={st.isFiltered}
      />

      <Paper variant="outlined">
        <TableContainer>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>ID</TableCell>
                <TableCell>Nombre</TableCell>
                <TableCell>Email</TableCell>
                <TableCell>Teléfono</TableCell>
                <TableCell>Nacimiento</TableCell>
                <TableCell>Estado</TableCell>
                <TableCell align="right">Acciones</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {st.loading ? (
                <SkeletonRows cols={7} />
              ) : st.rows.length === 0 ? (
                <EmptyRow
                  cols={7}
                  message={st.isFiltered ? 'No hay resultados para la búsqueda' : 'No hay clientes registrados'}
                />
              ) : (
                st.rows.map((c) => (
                  <TableRow key={c.customerId} hover>
                    <TableCell>{c.customerId}</TableCell>
                    <TableCell>
                      {c.firstName} {c.lastName}
                    </TableCell>
                    <TableCell>{c.email}</TableCell>
                    <TableCell>{c.phone}</TableCell>
                    <TableCell>{c.birthDate}</TableCell>
                    <TableCell>
                      <StatusChip status={c.status} />
                    </TableCell>
                    <TableCell align="right">
                      <Tooltip title="Editar">
                        <IconButton size="small" onClick={() => openEdit(c)}>
                          <EditIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title="Baja lógica">
                        <span>
                          <IconButton
                            size="small"
                            color="error"
                            disabled={c.status === 'DELETED'}
                            onClick={() => remove(c)}
                          >
                            <PersonOffIcon fontSize="small" />
                          </IconButton>
                        </span>
                      </Tooltip>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </TableContainer>
        {!st.loading && (
          <DataTablePagination
            count={st.total}
            page={st.page}
            rowsPerPage={st.rowsPerPage}
            onPageChange={st.onChangePage}
            onRowsPerPageChange={st.onChangeRowsPerPage}
          />
        )}
      </Paper>

      <Dialog open={open} onClose={() => setOpen(false)} fullWidth maxWidth="sm">
        <DialogTitle>{editing ? 'Editar cliente' : 'Nuevo cliente'}</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            <TextField label="Nombre" value={form.firstName} onChange={set('firstName')} fullWidth />
            <TextField label="Apellidos" value={form.lastName} onChange={set('lastName')} fullWidth />
            <TextField
              label="Fecha de nacimiento"
              type="date"
              value={form.birthDate}
              onChange={set('birthDate')}
              fullWidth
              disabled={editing !== null}
              InputLabelProps={{ shrink: true }}
            />
            <TextField label="Email" value={form.email} onChange={set('email')} fullWidth />
            <TextField label="Teléfono" value={form.phone} onChange={set('phone')} fullWidth />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpen(false)}>Cancelar</Button>
          <Button
            variant="contained"
            onClick={save}
            disabled={saving}
            startIcon={saving ? <CircularProgress size={16} color="inherit" /> : null}
          >
            Guardar
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
