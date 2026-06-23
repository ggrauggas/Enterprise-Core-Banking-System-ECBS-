import { useState } from 'react';
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
import { useConfirm } from '../ui/ConfirmDialog';
import StatusChip from '../ui/StatusChip';
import PageHeader from '../ui/PageHeader';
import { SkeletonRows, EmptyRow } from '../ui/TableStates';
import { useServerTable } from '../ui/useServerTable';
import DataTableToolbar from '../ui/DataTableToolbar';
import DataTablePagination from '../ui/DataTablePagination';
import EntityAutocomplete from '../ui/EntityAutocomplete';

const MONO = '"JetBrains Mono", ui-monospace, monospace';

export default function Accounts() {
  const toast = useToast();
  const confirm = useConfirm();
  const st = useServerTable<Account>('/accounts', {
    onError: (e) => toast(errMsg(e), 'error'),
  });
  const [open, setOpen] = useState(false);
  const [customer, setCustomer] = useState<Customer | null>(null);
  const [accountType, setAccountType] = useState('CHECKING');
  const [saving, setSaving] = useState(false);
  const [movements, setMovements] = useState<Transaction[] | null>(null);
  const [movingAccount, setMovingAccount] = useState<Account | null>(null);

  const openAccount = () => {
    if (!customer) return;
    setSaving(true);
    api
      .post('/accounts', { customerId: customer.customerId, accountType })
      .then(() => {
        toast('Cuenta abierta');
        setOpen(false);
        setCustomer(null);
        st.reload();
      })
      .catch((e) => toast(errMsg(e), 'error'))
      .finally(() => setSaving(false));
  };

  const close = async (a: Account) => {
    const ok = await confirm({
      title: 'Cerrar cuenta',
      message:
        'El cierre es definitivo. El saldo debe ser 0 para poder cerrarla; en caso contrario la operación será rechazada.',
      confirmText: 'Cerrar cuenta',
      tone: 'danger',
      icon: <LockIcon fontSize="small" />,
      details: [
        { label: 'IBAN', value: a.iban, mono: true },
        { label: 'Titular', value: `Cliente ${a.customerId}`, mono: true },
        { label: 'Saldo', value: eur(a.balance), mono: true, emphasis: a.balance !== 0 },
      ],
    });
    if (!ok) return;
    api
      .post(`/accounts/${a.accountId}/close`)
      .then(() => {
        toast('Cuenta cerrada');
        st.reload();
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
      <PageHeader
        title="Cuentas"
        subtitle="Apertura, cierre y consulta de movimientos"
        action={
          <Button variant="contained" startIcon={<AddIcon />} onClick={() => setOpen(true)}>
            Abrir cuenta
          </Button>
        }
      />

      <DataTableToolbar
        query={st.query}
        onSearch={st.onSearch}
        placeholder="Buscar por IBAN, cliente, ID…"
        total={st.total}
        isFiltered={st.isFiltered}
      />

      <Paper variant="outlined">
        <TableContainer>
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
              {st.loading ? (
                <SkeletonRows cols={7} />
              ) : st.rows.length === 0 ? (
                <EmptyRow
                  cols={7}
                  message={st.isFiltered ? 'No hay resultados para la búsqueda' : 'No hay cuentas registradas'}
                />
              ) : (
                st.rows.map((a) => (
                  <TableRow key={a.accountId} hover>
                    <TableCell>{a.accountId}</TableCell>
                    <TableCell sx={{ fontFamily: MONO, fontSize: 12.5, letterSpacing: '0.02em' }}>
                      {a.iban}
                    </TableCell>
                    <TableCell>{a.customerId}</TableCell>
                    <TableCell>{a.accountType}</TableCell>
                    <TableCell align="right" sx={{ fontFamily: MONO, fontWeight: 500 }}>
                      {eur(a.balance)}
                    </TableCell>
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

      <Dialog open={open} onClose={() => setOpen(false)} fullWidth maxWidth="xs">
        <DialogTitle>Abrir cuenta</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            <EntityAutocomplete<Customer>
              label="Cliente"
              value={customer}
              onChange={setCustomer}
              endpoint="/customers"
              params={{ status: 'ACTIVE' }}
              getOptionLabel={(c) => `${c.customerId} — ${c.firstName} ${c.lastName}`}
              isOptionEqualToValue={(a, b) => a.customerId === b.customerId}
            />
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
          <Button
            variant="contained"
            onClick={openAccount}
            disabled={saving || !customer}
            startIcon={saving ? <CircularProgress size={16} color="inherit" /> : null}
          >
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
                {movements.length === 0 ? (
                  <EmptyRow cols={5} message="Sin movimientos" />
                ) : (
                  movements.map((t) => (
                    <TableRow key={t.transactionId} hover>
                      <TableCell>{t.transactionId}</TableCell>
                      <TableCell>{t.timestamp?.slice(0, 19).replace('T', ' ')}</TableCell>
                      <TableCell>{t.transactionType}</TableCell>
                      <TableCell align="right" sx={{ fontFamily: MONO, fontWeight: 500 }}>
                        {eur(t.amount)}
                      </TableCell>
                      <TableCell>{t.description}</TableCell>
                    </TableRow>
                  ))
                )}
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
