import { useEffect, useState } from 'react';
import Typography from '@mui/material/Typography';
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
import MenuItem from '@mui/material/MenuItem';
import Stack from '@mui/material/Stack';
import Tooltip from '@mui/material/Tooltip';
import CircularProgress from '@mui/material/CircularProgress';
import AddIcon from '@mui/icons-material/Add';
import ReceiptLongIcon from '@mui/icons-material/ReceiptLong';
import LockIcon from '@mui/icons-material/Lock';

import { api, eur, errMsg } from '../api/client';
import type { Account, Customer, Transaction } from '../api/types';
import { useToast } from '../ui/Toast';
import StatusChip from '../ui/StatusChip';

export default function Accounts() {
  const toast = useToast();
  const [rows, setRows] = useState<Account[]>([]);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [open, setOpen] = useState(false);
  const [customerId, setCustomerId] = useState('');
  const [accountType, setAccountType] = useState('CHECKING');
  const [saving, setSaving] = useState(false);
  const [movements, setMovements] = useState<Transaction[] | null>(null);
  const [movingAccount, setMovingAccount] = useState<Account | null>(null);

  const load = () => {
    setLoading(true);
    Promise.all([api.get<Account[]>('/accounts'), api.get<Customer[]>('/customers')])
      .then(([a, c]) => {
        setRows(a.data);
        setCustomers(c.data);
      })
      .catch((e) => toast(errMsg(e), 'error'))
      .finally(() => setLoading(false));
  };

  useEffect(load, []); // eslint-disable-line react-hooks/exhaustive-deps

  const openAccount = () => {
    setSaving(true);
    api
      .post('/accounts', { customerId: Number(customerId), accountType })
      .then(() => {
        toast('Cuenta abierta');
        setOpen(false);
        setCustomerId('');
        load();
      })
      .catch((e) => toast(errMsg(e), 'error'))
      .finally(() => setSaving(false));
  };

  const close = (a: Account) => {
    if (!window.confirm(`¿Cerrar la cuenta ${a.iban}? (saldo debe ser 0)`)) return;
    api
      .post(`/accounts/${a.accountId}/close`)
      .then(() => {
        toast('Cuenta cerrada');
        load();
      })
      .catch((e) => toast(errMsg(e), 'error'));
  };

  const showMovements = (a: Account) => {
    setMovingAccount(a);
    setMovements(null);
    api
      .get<Transaction[]>(`/accounts/${a.accountId}/transactions`)
      .then((r) => setMovements(r.data))
      .catch((e) => toast(errMsg(e), 'error'));
  };

  return (
    <Box>
      <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 2 }}>
        <Typography variant="h4">Cuentas</Typography>
        <Button variant="contained" startIcon={<AddIcon />} onClick={() => setOpen(true)}>
          Abrir cuenta
        </Button>
      </Stack>

      {loading ? (
        <CircularProgress />
      ) : (
        <TableContainer component={Paper}>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>ID</TableCell>
                <TableCell>IBAN</TableCell>
                <TableCell>Cliente</TableCell>
                <TableCell>Tipo</TableCell>
                <TableCell align="right">Saldo</TableCell>
                <TableCell>Estado</TableCell>
                <TableCell align="right">Acciones</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {rows.map((a) => (
                <TableRow key={a.accountId} hover>
                  <TableCell>{a.accountId}</TableCell>
                  <TableCell>{a.iban}</TableCell>
                  <TableCell>{a.customerId}</TableCell>
                  <TableCell>{a.accountType}</TableCell>
                  <TableCell align="right">{eur(a.balance)}</TableCell>
                  <TableCell>
                    <StatusChip status={a.status} />
                  </TableCell>
                  <TableCell align="right">
                    <Tooltip title="Movimientos">
                      <IconButton size="small" onClick={() => showMovements(a)}>
                        <ReceiptLongIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                    <Tooltip title="Cerrar cuenta">
                      <span>
                        <IconButton
                          size="small"
                          color="error"
                          disabled={a.status === 'CLOSED'}
                          onClick={() => close(a)}
                        >
                          <LockIcon fontSize="small" />
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

      <Dialog open={open} onClose={() => setOpen(false)} fullWidth maxWidth="xs">
        <DialogTitle>Abrir cuenta</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            <TextField
              select
              label="Cliente"
              value={customerId}
              onChange={(e) => setCustomerId(e.target.value)}
              fullWidth
            >
              {customers
                .filter((c) => c.status === 'ACTIVE')
                .map((c) => (
                  <MenuItem key={c.customerId} value={c.customerId}>
                    {c.customerId} — {c.firstName} {c.lastName}
                  </MenuItem>
                ))}
            </TextField>
            <TextField
              select
              label="Tipo"
              value={accountType}
              onChange={(e) => setAccountType(e.target.value)}
              fullWidth
            >
              <MenuItem value="CHECKING">Corriente</MenuItem>
              <MenuItem value="SAVINGS">Ahorro</MenuItem>
            </TextField>
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpen(false)}>Cancelar</Button>
          <Button variant="contained" onClick={openAccount} disabled={saving || !customerId}>
            Abrir
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={movingAccount !== null} onClose={() => setMovingAccount(null)} fullWidth maxWidth="md">
        <DialogTitle>Movimientos · {movingAccount?.iban}</DialogTitle>
        <DialogContent>
          {movements === null ? (
            <CircularProgress />
          ) : (
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell>ID</TableCell>
                  <TableCell>Fecha</TableCell>
                  <TableCell>Tipo</TableCell>
                  <TableCell align="right">Importe</TableCell>
                  <TableCell>Descripción</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {movements.map((t) => (
                  <TableRow key={t.transactionId}>
                    <TableCell>{t.transactionId}</TableCell>
                    <TableCell>{t.timestamp?.slice(0, 19).replace('T', ' ')}</TableCell>
                    <TableCell>{t.transactionType}</TableCell>
                    <TableCell align="right">{eur(t.amount)}</TableCell>
                    <TableCell>{t.description}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setMovingAccount(null)}>Cerrar</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
