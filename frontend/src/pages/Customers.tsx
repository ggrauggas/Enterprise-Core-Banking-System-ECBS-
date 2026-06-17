import { useEffect, useState } from 'react';
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
import StatusChip from '../ui/StatusChip';
import PageHeader from '../ui/PageHeader';

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
  const [rows, setRows] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Customer | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY);
  const [saving, setSaving] = useState(false);

  const load = () => {
    setLoading(true);
    api
      .get<Customer[]>('/customers')
      .then((r) => setRows(r.data))
      .catch((e) => toast(errMsg(e), 'error'))
      .finally(() => setLoading(false));
  };

  useEffect(load, []); // eslint-disable-line react-hooks/exhaustive-deps

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
        load();
      })
      .catch((e) => toast(errMsg(e), 'error'))
      .finally(() => setSaving(false));
  };

  const remove = (c: Customer) => {
    if (!window.confirm(`¿Dar de baja a ${c.firstName} ${c.lastName}?`)) return;
    api
      .delete(`/customers/${c.customerId}`)
      .then(() => {
        toast('Cliente dado de baja');
        load();
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

      {loading ? (
        <CircularProgress />
      ) : (
        <TableContainer component={Paper}>
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
              {rows.map((c) => (
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
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

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
          <Button variant="contained" onClick={save} disabled={saving}>
            Guardar
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
