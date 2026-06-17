import { useEffect, useState } from 'react';
import Typography from '@mui/material/Typography';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Paper from '@mui/material/Paper';
import Card from '@mui/material/Card';
import CardContent from '@mui/material/CardContent';
import Tabs from '@mui/material/Tabs';
import Tab from '@mui/material/Tab';
import TextField from '@mui/material/TextField';
import MenuItem from '@mui/material/MenuItem';
import Stack from '@mui/material/Stack';
import Table from '@mui/material/Table';
import TableBody from '@mui/material/TableBody';
import TableCell from '@mui/material/TableCell';
import TableContainer from '@mui/material/TableContainer';
import TableHead from '@mui/material/TableHead';
import TableRow from '@mui/material/TableRow';

import { api, eur, errMsg } from '../api/client';
import type { Account, Transaction } from '../api/types';
import { useToast } from '../ui/Toast';
import PageHeader from '../ui/PageHeader';

export default function Transactions() {
  const toast = useToast();
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [tab, setTab] = useState(0);
  const [accountId, setAccountId] = useState('');
  const [toAccountId, setToAccountId] = useState('');
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [busy, setBusy] = useState(false);

  const [viewId, setViewId] = useState('');
  const [movements, setMovements] = useState<Transaction[]>([]);

  const loadAccounts = () =>
    api
      .get<Account[]>('/accounts')
      .then((r) => setAccounts(r.data))
      .catch((e) => toast(errMsg(e), 'error'));

  useEffect(() => {
    loadAccounts();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const reset = () => {
    setAmount('');
    setDescription('');
  };

  const submit = () => {
    setBusy(true);
    const amt = Number(amount);
    let req;
    if (tab === 0) {
      req = api.post('/transactions/deposits', { accountId: Number(accountId), amount: amt, description });
    } else if (tab === 1) {
      req = api.post('/transactions/withdrawals', { accountId: Number(accountId), amount: amt, description });
    } else {
      req = api.post('/transactions/transfers', {
        fromAccountId: Number(accountId),
        toAccountId: Number(toAccountId),
        amount: amt,
        description,
      });
    }
    req
      .then((r) => {
        const d = r.data as { newBalance?: number; fromNewBalance?: number };
        const bal = tab === 2 ? d.fromNewBalance : d.newBalance;
        toast(`Operación realizada${bal !== undefined ? ` · saldo origen ${eur(bal)}` : ''}`);
        reset();
        loadAccounts();
      })
      .catch((e) => toast(errMsg(e), 'error'))
      .finally(() => setBusy(false));
  };

  const lookup = () => {
    api
      .get<Transaction[]>(`/transactions`, { params: { accountId: Number(viewId) } })
      .then((r) => setMovements(r.data))
      .catch((e) => toast(errMsg(e), 'error'));
  };

  const activeAccounts = accounts.filter((a) => a.status === 'ACTIVE');
  const accountOption = (a: Account) => `${a.accountId} — ${a.iban} (${eur(a.balance)})`;

  return (
    <Box>
      <PageHeader title="Transacciones" subtitle="Depósitos, retiros y transferencias" />

      <Stack direction="row" spacing={2} useFlexGap flexWrap="wrap">
        <Card sx={{ flex: '1 1 380px' }}>
          <CardContent>
            <Tabs value={tab} onChange={(_, v) => setTab(v)} sx={{ mb: 2 }}>
              <Tab label="Depósito" />
              <Tab label="Retiro" />
              <Tab label="Transferencia" />
            </Tabs>
            <Stack spacing={2}>
              <TextField
                select
                label={tab === 2 ? 'Cuenta origen' : 'Cuenta'}
                value={accountId}
                onChange={(e) => setAccountId(e.target.value)}
                fullWidth
              >
                {activeAccounts.map((a) => (
                  <MenuItem key={a.accountId} value={a.accountId}>
                    {accountOption(a)}
                  </MenuItem>
                ))}
              </TextField>
              {tab === 2 && (
                <TextField
                  select
                  label="Cuenta destino"
                  value={toAccountId}
                  onChange={(e) => setToAccountId(e.target.value)}
                  fullWidth
                >
                  {activeAccounts.map((a) => (
                    <MenuItem key={a.accountId} value={a.accountId}>
                      {accountOption(a)}
                    </MenuItem>
                  ))}
                </TextField>
              )}
              <TextField
                label="Importe"
                type="number"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                fullWidth
              />
              <TextField
                label="Descripción"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                fullWidth
              />
              <Button
                variant="contained"
                onClick={submit}
                disabled={busy || !accountId || !amount || (tab === 2 && !toAccountId)}
              >
                Ejecutar
              </Button>
            </Stack>
          </CardContent>
        </Card>

        <Card sx={{ flex: '1 1 380px' }}>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              Consultar movimientos
            </Typography>
            <Stack direction="row" spacing={1} sx={{ mb: 2 }}>
              <TextField
                select
                label="Cuenta"
                value={viewId}
                onChange={(e) => setViewId(e.target.value)}
                sx={{ flexGrow: 1 }}
              >
                {accounts.map((a) => (
                  <MenuItem key={a.accountId} value={a.accountId}>
                    {accountOption(a)}
                  </MenuItem>
                ))}
              </TextField>
              <Button variant="outlined" onClick={lookup} disabled={!viewId}>
                Ver
              </Button>
            </Stack>
            <TableContainer component={Paper} variant="outlined" sx={{ maxHeight: 360 }}>
              <Table size="small" stickyHeader>
                <TableHead>
                  <TableRow>
                    <TableCell>Tipo</TableCell>
                    <TableCell align="right">Importe</TableCell>
                    <TableCell>Fecha</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {movements.map((t) => (
                    <TableRow key={t.transactionId}>
                      <TableCell>{t.transactionType}</TableCell>
                      <TableCell align="right">{eur(t.amount)}</TableCell>
                      <TableCell>{t.timestamp?.slice(0, 19).replace('T', ' ')}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </CardContent>
        </Card>
      </Stack>
    </Box>
  );
}
