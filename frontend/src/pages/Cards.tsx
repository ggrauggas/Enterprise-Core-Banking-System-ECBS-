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
import LockIcon from '@mui/icons-material/Lock';
import LockOpenIcon from '@mui/icons-material/LockOpen';
import ShoppingCartIcon from '@mui/icons-material/ShoppingCart';
import ReplayIcon from '@mui/icons-material/Replay';

import { api, eur, errMsg } from '../api/client';
import type { Account, CardEntity } from '../api/types';
import { useToast } from '../ui/Toast';
import StatusChip from '../ui/StatusChip';

type OpKind = 'purchases' | 'refunds';

export default function Cards() {
  const toast = useToast();
  const [rows, setRows] = useState<CardEntity[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [loading, setLoading] = useState(true);
  const [issueOpen, setIssueOpen] = useState(false);
  const [accountId, setAccountId] = useState('');
  const [creditLimit, setCreditLimit] = useState('');
  const [op, setOp] = useState<{ card: CardEntity; kind: OpKind } | null>(null);
  const [amount, setAmount] = useState('');

  const load = () => {
    setLoading(true);
    Promise.all([api.get<CardEntity[]>('/cards'), api.get<Account[]>('/accounts')])
      .then(([c, a]) => {
        setRows(c.data);
        setAccounts(a.data);
      })
      .catch((e) => toast(errMsg(e), 'error'))
      .finally(() => setLoading(false));
  };

  useEffect(load, []); // eslint-disable-line react-hooks/exhaustive-deps

  const issue = () => {
    api
      .post('/cards', { accountId: Number(accountId), creditLimit: Number(creditLimit) })
      .then(() => {
        toast('Tarjeta emitida');
        setIssueOpen(false);
        setAccountId('');
        setCreditLimit('');
        load();
      })
      .catch((e) => toast(errMsg(e), 'error'));
  };

  const toggleBlock = (c: CardEntity) => {
    const action = c.status === 'BLOCKED' ? 'unblock' : 'block';
    api
      .post(`/cards/${c.cardId}/${action}`)
      .then(() => {
        toast(action === 'block' ? 'Tarjeta bloqueada' : 'Tarjeta desbloqueada');
        load();
      })
      .catch((e) => toast(errMsg(e), 'error'));
  };

  const runOp = () => {
    if (!op) return;
    api
      .post(`/cards/${op.card.cardId}/${op.kind}`, { amount: Number(amount) })
      .then((r) => {
        const d = r.data as { availableCredit?: number };
        toast(`Operación OK · disponible ${eur(d.availableCredit)}`);
        setOp(null);
        setAmount('');
        load();
      })
      .catch((e) => toast(errMsg(e), 'error'));
  };

  return (
    <Box>
      <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 2 }}>
        <Typography variant="h4">Tarjetas</Typography>
        <Button variant="contained" startIcon={<AddIcon />} onClick={() => setIssueOpen(true)}>
          Emitir tarjeta
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
                <TableCell>Número</TableCell>
                <TableCell>Cuenta</TableCell>
                <TableCell align="right">Límite</TableCell>
                <TableCell align="right">Disponible</TableCell>
                <TableCell>Estado</TableCell>
                <TableCell align="right">Acciones</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {rows.map((c) => (
                <TableRow key={c.cardId} hover>
                  <TableCell>{c.cardId}</TableCell>
                  <TableCell>{c.cardNumber}</TableCell>
                  <TableCell>{c.accountId}</TableCell>
                  <TableCell align="right">{eur(c.creditLimit)}</TableCell>
                  <TableCell align="right">{eur(c.availableCredit)}</TableCell>
                  <TableCell>
                    <StatusChip status={c.status} />
                  </TableCell>
                  <TableCell align="right">
                    <Tooltip title="Compra">
                      <span>
                        <IconButton
                          size="small"
                          disabled={c.status !== 'ACTIVE'}
                          onClick={() => setOp({ card: c, kind: 'purchases' })}
                        >
                          <ShoppingCartIcon fontSize="small" />
                        </IconButton>
                      </span>
                    </Tooltip>
                    <Tooltip title="Devolución">
                      <span>
                        <IconButton
                          size="small"
                          disabled={c.status !== 'ACTIVE'}
                          onClick={() => setOp({ card: c, kind: 'refunds' })}
                        >
                          <ReplayIcon fontSize="small" />
                        </IconButton>
                      </span>
                    </Tooltip>
                    <Tooltip title={c.status === 'BLOCKED' ? 'Desbloquear' : 'Bloquear'}>
                      <span>
                        <IconButton
                          size="small"
                          color={c.status === 'BLOCKED' ? 'success' : 'warning'}
                          disabled={c.status === 'CANCELLED'}
                          onClick={() => toggleBlock(c)}
                        >
                          {c.status === 'BLOCKED' ? (
                            <LockOpenIcon fontSize="small" />
                          ) : (
                            <LockIcon fontSize="small" />
                          )}
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

      <Dialog open={issueOpen} onClose={() => setIssueOpen(false)} fullWidth maxWidth="xs">
        <DialogTitle>Emitir tarjeta</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            <TextField
              select
              label="Cuenta"
              value={accountId}
              onChange={(e) => setAccountId(e.target.value)}
              fullWidth
            >
              {accounts
                .filter((a) => a.status === 'ACTIVE')
                .map((a) => (
                  <MenuItem key={a.accountId} value={a.accountId}>
                    {a.accountId} — {a.iban}
                  </MenuItem>
                ))}
            </TextField>
            <TextField
              label="Límite de crédito"
              type="number"
              value={creditLimit}
              onChange={(e) => setCreditLimit(e.target.value)}
              fullWidth
            />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setIssueOpen(false)}>Cancelar</Button>
          <Button variant="contained" onClick={issue} disabled={!accountId || !creditLimit}>
            Emitir
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={op !== null} onClose={() => setOp(null)} fullWidth maxWidth="xs">
        <DialogTitle>
          {op?.kind === 'purchases' ? 'Compra' : 'Devolución'} · tarjeta {op?.card.cardId}
        </DialogTitle>
        <DialogContent>
          <TextField
            label="Importe"
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            fullWidth
            sx={{ mt: 1 }}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOp(null)}>Cancelar</Button>
          <Button variant="contained" onClick={runOp} disabled={!amount}>
            Confirmar
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
