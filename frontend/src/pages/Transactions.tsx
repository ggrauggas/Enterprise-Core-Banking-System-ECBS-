import { useState } from 'react';
import Typography from '@mui/material/Typography';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Paper from '@mui/material/Paper';
import Card from '@mui/material/Card';
import CardContent from '@mui/material/CardContent';
import Tabs from '@mui/material/Tabs';
import Tab from '@mui/material/Tab';
import TextField from '@mui/material/TextField';
import Stack from '@mui/material/Stack';
import CircularProgress from '@mui/material/CircularProgress';
import Table from '@mui/material/Table';
import TableBody from '@mui/material/TableBody';
import TableCell from '@mui/material/TableCell';
import TableContainer from '@mui/material/TableContainer';
import TableHead from '@mui/material/TableHead';
import TableRow from '@mui/material/TableRow';

import SouthWestIcon from '@mui/icons-material/SouthWest';
import NorthEastIcon from '@mui/icons-material/NorthEast';
import SwapHorizIcon from '@mui/icons-material/SwapHoriz';

import { api, eur, errMsg } from '../api/client';
import type { Account, Transaction } from '../api/types';
import { useToast } from '../ui/Toast';
import { useConfirm } from '../ui/ConfirmDialog';
import PageHeader from '../ui/PageHeader';
import { EmptyRow } from '../ui/TableStates';
import EntityAutocomplete from '../ui/EntityAutocomplete';

const MONO = '"JetBrains Mono", ui-monospace, monospace';
const accountLabel = (a: Account) => `${a.accountId} — ${a.iban} (${eur(a.balance)})`;
const sameAccount = (a: Account, b: Account) => a.accountId === b.accountId;

export default function Transactions() {
  const toast = useToast();
  const confirm = useConfirm();
  const [tab, setTab] = useState(0);
  const [fromAccount, setFromAccount] = useState<Account | null>(null);
  const [toAccount, setToAccount] = useState<Account | null>(null);
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [busy, setBusy] = useState(false);

  const [viewAccount, setViewAccount] = useState<Account | null>(null);
  const [movements, setMovements] = useState<Transaction[]>([]);

  const reset = () => {
    setAmount('');
    setDescription('');
  };

  const submit = async () => {
    if (!fromAccount) return;
    const amt = Number(amount);

    const meta =
      tab === 0
        ? {
            title: 'Confirmar depósito',
            message: 'Se ingresará el importe en la cuenta seleccionada.',
            tone: 'info' as const,
            icon: <SouthWestIcon fontSize="small" />,
            details: [
              { label: 'Cuenta', value: fromAccount.iban, mono: true },
              { label: 'Importe', value: eur(amt), mono: true },
            ],
          }
        : tab === 1
          ? {
              title: 'Confirmar retiro',
              message: 'Se retirará el importe de la cuenta. Verifica que hay saldo suficiente.',
              tone: 'warning' as const,
              icon: <NorthEastIcon fontSize="small" />,
              details: [
                { label: 'Cuenta', value: fromAccount.iban, mono: true },
                { label: 'Saldo actual', value: eur(fromAccount.balance), mono: true },
                { label: 'Importe', value: eur(amt), mono: true, emphasis: true },
              ],
            }
          : {
              title: 'Confirmar transferencia',
              message: 'El importe se moverá de la cuenta origen a la cuenta destino.',
              tone: 'warning' as const,
              icon: <SwapHorizIcon fontSize="small" />,
              details: [
                { label: 'Origen', value: fromAccount.iban, mono: true },
                { label: 'Destino', value: toAccount?.iban ?? '—', mono: true },
                { label: 'Importe', value: eur(amt), mono: true, emphasis: true },
              ],
            };

    const ok = await confirm({ ...meta, confirmText: 'Ejecutar' });
    if (!ok) return;

    setBusy(true);
    let req;
    if (tab === 0) {
      req = api.post('/transactions/deposits', { accountId: fromAccount.accountId, amount: amt, description });
    } else if (tab === 1) {
      req = api.post('/transactions/withdrawals', { accountId: fromAccount.accountId, amount: amt, description });
    } else {
      req = api.post('/transactions/transfers', {
        fromAccountId: fromAccount.accountId,
        toAccountId: toAccount?.accountId,
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
      })
      .catch((e) => toast(errMsg(e), 'error'))
      .finally(() => setBusy(false));
  };

  const lookup = () => {
    if (!viewAccount) return;
    api
      .get<Transaction[]>(`/transactions`, { params: { accountId: viewAccount.accountId } })
      .then((r) => setMovements(r.data))
      .catch((e) => toast(errMsg(e), 'error'));
  };

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
              <EntityAutocomplete<Account>
                label={tab === 2 ? 'Cuenta origen' : 'Cuenta'}
                value={fromAccount}
                onChange={setFromAccount}
                endpoint="/accounts"
                params={{ status: 'ACTIVE' }}
                getOptionLabel={accountLabel}
                isOptionEqualToValue={sameAccount}
              />
              {tab === 2 && (
                <EntityAutocomplete<Account>
                  label="Cuenta destino"
                  value={toAccount}
                  onChange={setToAccount}
                  endpoint="/accounts"
                  params={{ status: 'ACTIVE' }}
                  getOptionLabel={accountLabel}
                  isOptionEqualToValue={sameAccount}
                />
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
                disabled={busy || !fromAccount || !amount || (tab === 2 && !toAccount)}
                startIcon={busy ? <CircularProgress size={16} color="inherit" /> : null}
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
            <Stack direction="row" spacing={1} sx={{ mb: 2 }} alignItems="center">
              <Box sx={{ flexGrow: 1 }}>
                <EntityAutocomplete<Account>
                  label="Cuenta"
                  value={viewAccount}
                  onChange={setViewAccount}
                  endpoint="/accounts"
                  getOptionLabel={accountLabel}
                  isOptionEqualToValue={sameAccount}
                />
              </Box>
              <Button variant="outlined" onClick={lookup} disabled={!viewAccount}>
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
                  {movements.length === 0 ? (
                    <EmptyRow cols={3} message="Sin movimientos para mostrar" />
                  ) : (
                    movements.map((t) => (
                      <TableRow key={t.transactionId} hover>
                        <TableCell>{t.transactionType}</TableCell>
                        <TableCell align="right" sx={{ fontFamily: MONO, fontWeight: 500 }}>
                          {eur(t.amount)}
                        </TableCell>
                        <TableCell>{t.timestamp?.slice(0, 19).replace('T', ' ')}</TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
              </Table>
            </TableContainer>
          </CardContent>
        </Card>
      </Stack>
    </Box>
  );
}
