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
import { useConfirm } from '../ui/ConfirmDialog';
import StatusChip from '../ui/StatusChip';
import PageHeader from '../ui/PageHeader';
import { SkeletonRows, EmptyRow } from '../ui/TableStates';
import { useServerTable } from '../ui/useServerTable';
import DataTableToolbar from '../ui/DataTableToolbar';
import DataTablePagination from '../ui/DataTablePagination';
import EntityAutocomplete from '../ui/EntityAutocomplete';

const MONO = '"JetBrains Mono", ui-monospace, monospace';

type OpKind = 'purchases' | 'refunds';

export default function Cards() {
  const toast = useToast();
  const confirm = useConfirm();
  const st = useServerTable<CardEntity>('/cards', {
    onError: (e) => toast(errMsg(e), 'error'),
  });
  const [issueOpen, setIssueOpen] = useState(false);
  const [account, setAccount] = useState<Account | null>(null);
  const [creditLimit, setCreditLimit] = useState('');
  const [issuing, setIssuing] = useState(false);
  const [op, setOp] = useState<{ card: CardEntity; kind: OpKind } | null>(null);
  const [amount, setAmount] = useState('');

  const issue = () => {
    if (!account) return;
    setIssuing(true);
    api
      .post('/cards', { accountId: account.accountId, creditLimit: Number(creditLimit) })
      .then(() => {
        toast('Tarjeta emitida');
        setIssueOpen(false);
        setAccount(null);
        setCreditLimit('');
        st.reload();
      })
      .catch((e) => toast(errMsg(e), 'error'))
      .finally(() => setIssuing(false));
  };

  const toggleBlock = async (c: CardEntity) => {
    const action = c.status === 'BLOCKED' ? 'unblock' : 'block';
    const details = [
      { label: 'Número', value: c.cardNumber, mono: true },
      { label: 'Cuenta', value: c.accountId, mono: true },
    ];
    const ok =
      action === 'block'
        ? await confirm({
            title: 'Bloquear tarjeta',
            message: 'No podrá realizar compras hasta que la desbloquees. Es una acción reversible.',
            confirmText: 'Bloquear',
            tone: 'warning',
            icon: <LockIcon fontSize="small" />,
            details,
          })
        : await confirm({
            title: 'Desbloquear tarjeta',
            message: 'La tarjeta volverá a estar activa y podrá realizar compras.',
            confirmText: 'Desbloquear',
            tone: 'info',
            icon: <LockOpenIcon fontSize="small" />,
            details,
          });
    if (!ok) return;
    api
      .post(`/cards/${c.cardId}/${action}`)
      .then(() => {
        toast(action === 'block' ? 'Tarjeta bloqueada' : 'Tarjeta desbloqueada');
        st.reload();
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
        st.reload();
      })
      .catch((e) => toast(errMsg(e), 'error'));
  };

  return (
    <Box>
      <PageHeader
        title="Tarjetas"
        subtitle="Emisión, bloqueo, compras y devoluciones"
        action={
          <Button variant="contained" startIcon={<AddIcon />} onClick={() => setIssueOpen(true)}>
            Emitir tarjeta
          </Button>
        }
      />

      <DataTableToolbar
        query={st.query}
        onSearch={st.onSearch}
        placeholder="Buscar por número, cuenta, ID…"
        total={st.total}
        isFiltered={st.isFiltered}
      />

      <Paper variant="outlined">
        <TableContainer>
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
              {st.loading ? (
                <SkeletonRows cols={7} />
              ) : st.rows.length === 0 ? (
                <EmptyRow
                  cols={7}
                  message={st.isFiltered ? 'No hay resultados para la búsqueda' : 'No hay tarjetas emitidas'}
                />
              ) : (
                st.rows.map((c) => (
                  <TableRow key={c.cardId} hover>
                    <TableCell>{c.cardId}</TableCell>
                    <TableCell sx={{ fontFamily: MONO, fontSize: 12.5, letterSpacing: '0.04em' }}>
                      {c.cardNumber}
                    </TableCell>
                    <TableCell>{c.accountId}</TableCell>
                    <TableCell align="right" sx={{ fontFamily: MONO, fontWeight: 500 }}>
                      {eur(c.creditLimit)}
                    </TableCell>
                    <TableCell align="right" sx={{ fontFamily: MONO, fontWeight: 500 }}>
                      {eur(c.availableCredit)}
                    </TableCell>
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

      <Dialog open={issueOpen} onClose={() => setIssueOpen(false)} fullWidth maxWidth="xs">
        <DialogTitle>Emitir tarjeta</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            <EntityAutocomplete<Account>
              label="Cuenta"
              value={account}
              onChange={setAccount}
              endpoint="/accounts"
              params={{ status: 'ACTIVE' }}
              getOptionLabel={(a) => `${a.accountId} — ${a.iban}`}
              isOptionEqualToValue={(a, b) => a.accountId === b.accountId}
            />
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
          <Button
            variant="contained"
            onClick={issue}
            disabled={!account || !creditLimit || issuing}
            startIcon={issuing ? <CircularProgress size={16} color="inherit" /> : null}
          >
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
