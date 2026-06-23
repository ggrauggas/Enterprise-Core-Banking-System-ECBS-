import { useState } from 'react';
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
import CheckIcon from '@mui/icons-material/Check';
import CloseIcon from '@mui/icons-material/Close';
import TableChartIcon from '@mui/icons-material/TableChart';

import { api, eur, errMsg } from '../api/client';
import type { Account, Loan, Simulation } from '../api/types';
import { useToast } from '../ui/Toast';
import StatusChip from '../ui/StatusChip';
import PageHeader from '../ui/PageHeader';
import { SkeletonRows, EmptyRow } from '../ui/TableStates';
import { useServerTable } from '../ui/useServerTable';
import DataTableToolbar from '../ui/DataTableToolbar';
import DataTablePagination from '../ui/DataTablePagination';

const MONO = '"JetBrains Mono", ui-monospace, monospace';
const blankSim = { amount: '10000', interestRate: '5', durationMonths: '36' };

export default function Loans() {
  const toast = useToast();
  const st = useServerTable<Loan>('/loans', {
    onError: (e) => toast(errMsg(e), 'error'),
  });
  const [sim, setSim] = useState(blankSim);
  const [schedule, setSchedule] = useState<Simulation | null>(null);

  const [requestOpen, setRequestOpen] = useState(false);
  const [reqForm, setReqForm] = useState({ customerId: '', amount: '', interestRate: '', durationMonths: '' });
  const [approve, setApprove] = useState<Loan | null>(null);
  const [ownerAccounts, setOwnerAccounts] = useState<Account[]>([]);
  const [disburseAccount, setDisburseAccount] = useState('');
  const [reject, setReject] = useState<Loan | null>(null);
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);

  const runSimulate = () => {
    api
      .post<Simulation>('/loans/simulate', {
        amount: Number(sim.amount),
        interestRate: Number(sim.interestRate),
        durationMonths: Number(sim.durationMonths),
      })
      .then((r) => setSchedule(r.data))
      .catch((e) => toast(errMsg(e), 'error'));
  };

  const viewSchedule = (l: Loan) => {
    api
      .get<Simulation>(`/loans/${l.loanId}/schedule`)
      .then((r) => setSchedule(r.data))
      .catch((e) => toast(errMsg(e), 'error'));
  };

  const submitRequest = () => {
    setBusy(true);
    api
      .post('/loans', {
        customerId: Number(reqForm.customerId),
        amount: Number(reqForm.amount),
        interestRate: Number(reqForm.interestRate),
        durationMonths: Number(reqForm.durationMonths),
      })
      .then(() => {
        toast('Préstamo solicitado');
        setRequestOpen(false);
        setReqForm({ customerId: '', amount: '', interestRate: '', durationMonths: '' });
        st.reload();
      })
      .catch((e) => toast(errMsg(e), 'error'))
      .finally(() => setBusy(false));
  };

  // Owner accounts are small (per customer) so they are fetched on demand when
  // the approve dialog opens rather than loading every account up front.
  const openApprove = (l: Loan) => {
    setApprove(l);
    setDisburseAccount('');
    setOwnerAccounts([]);
    api
      .get<Account[]>('/accounts', { params: { customerId: l.customerId, status: 'ACTIVE' } })
      .then((r) => setOwnerAccounts(r.data))
      .catch((e) => toast(errMsg(e), 'error'));
  };

  const submitApprove = () => {
    if (!approve) return;
    setBusy(true);
    const body = disburseAccount ? { accountId: Number(disburseAccount) } : {};
    api
      .post(`/loans/${approve.loanId}/approve`, body)
      .then(() => {
        toast(disburseAccount ? 'Préstamo aprobado y desembolsado' : 'Préstamo aprobado');
        setApprove(null);
        setDisburseAccount('');
        st.reload();
      })
      .catch((e) => toast(errMsg(e), 'error'))
      .finally(() => setBusy(false));
  };

  const submitReject = () => {
    if (!reject) return;
    setBusy(true);
    api
      .post(`/loans/${reject.loanId}/reject`, { reason })
      .then(() => {
        toast('Préstamo rechazado');
        setReject(null);
        setReason('');
        st.reload();
      })
      .catch((e) => toast(errMsg(e), 'error'))
      .finally(() => setBusy(false));
  };

  return (
    <Box>
      <PageHeader
        title="Préstamos"
        subtitle="Simulación, solicitud, aprobación y seguimiento"
        action={
          <Button variant="contained" startIcon={<AddIcon />} onClick={() => setRequestOpen(true)}>
            Solicitar préstamo
          </Button>
        }
      />

      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            Simulador (método francés)
          </Typography>
          <Stack direction="row" spacing={2} useFlexGap flexWrap="wrap" alignItems="center">
            <TextField
              label="Importe"
              type="number"
              value={sim.amount}
              onChange={(e) => setSim({ ...sim, amount: e.target.value })}
            />
            <TextField
              label="Interés (%)"
              type="number"
              value={sim.interestRate}
              onChange={(e) => setSim({ ...sim, interestRate: e.target.value })}
            />
            <TextField
              label="Meses"
              type="number"
              value={sim.durationMonths}
              onChange={(e) => setSim({ ...sim, durationMonths: e.target.value })}
            />
            <Button variant="outlined" onClick={runSimulate}>
              Simular
            </Button>
          </Stack>
        </CardContent>
      </Card>

      <DataTableToolbar
        query={st.query}
        onSearch={st.onSearch}
        placeholder="Buscar por cliente, ID…"
        total={st.total}
        isFiltered={st.isFiltered}
      />

      <Paper variant="outlined">
        <TableContainer>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>ID</TableCell>
                <TableCell>Cliente</TableCell>
                <TableCell align="right">Importe</TableCell>
                <TableCell align="right">Interés</TableCell>
                <TableCell align="right">Meses</TableCell>
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
                  message={st.isFiltered ? 'No hay resultados para la búsqueda' : 'No hay préstamos registrados'}
                />
              ) : (
                st.rows.map((l) => (
                  <TableRow key={l.loanId} hover>
                    <TableCell>{l.loanId}</TableCell>
                    <TableCell>{l.customerId}</TableCell>
                    <TableCell align="right" sx={{ fontFamily: MONO, fontWeight: 500 }}>
                      {eur(l.amount)}
                    </TableCell>
                    <TableCell align="right">{l.interestRate}%</TableCell>
                    <TableCell align="right">{l.durationMonths}</TableCell>
                    <TableCell>
                      <StatusChip status={l.status} />
                    </TableCell>
                    <TableCell align="right">
                      <Tooltip title="Cuadro de amortización">
                        <IconButton size="small" onClick={() => viewSchedule(l)}>
                          <TableChartIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title="Aprobar">
                        <span>
                          <IconButton
                            size="small"
                            color="success"
                            disabled={l.status !== 'REQUESTED'}
                            onClick={() => openApprove(l)}
                          >
                            <CheckIcon fontSize="small" />
                          </IconButton>
                        </span>
                      </Tooltip>
                      <Tooltip title="Rechazar">
                        <span>
                          <IconButton
                            size="small"
                            color="error"
                            disabled={l.status !== 'REQUESTED'}
                            onClick={() => setReject(l)}
                          >
                            <CloseIcon fontSize="small" />
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

      {/* Request dialog */}
      <Dialog open={requestOpen} onClose={() => setRequestOpen(false)} fullWidth maxWidth="xs">
        <DialogTitle>Solicitar préstamo</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 1 }}>
            <TextField
              label="ID cliente"
              type="number"
              value={reqForm.customerId}
              onChange={(e) => setReqForm({ ...reqForm, customerId: e.target.value })}
            />
            <TextField
              label="Importe"
              type="number"
              value={reqForm.amount}
              onChange={(e) => setReqForm({ ...reqForm, amount: e.target.value })}
            />
            <TextField
              label="Interés (%)"
              type="number"
              value={reqForm.interestRate}
              onChange={(e) => setReqForm({ ...reqForm, interestRate: e.target.value })}
            />
            <TextField
              label="Meses"
              type="number"
              value={reqForm.durationMonths}
              onChange={(e) => setReqForm({ ...reqForm, durationMonths: e.target.value })}
            />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setRequestOpen(false)}>Cancelar</Button>
          <Button
            variant="contained"
            onClick={submitRequest}
            disabled={busy}
            startIcon={busy ? <CircularProgress size={16} color="inherit" /> : null}
          >
            Solicitar
          </Button>
        </DialogActions>
      </Dialog>

      {/* Approve dialog */}
      <Dialog open={approve !== null} onClose={() => setApprove(null)} fullWidth maxWidth="xs">
        <DialogTitle>Aprobar préstamo {approve?.loanId}</DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Opcional: selecciona una cuenta del titular para desembolsar el importe.
          </Typography>
          <TextField
            select
            label="Cuenta de desembolso (opcional)"
            value={disburseAccount}
            onChange={(e) => setDisburseAccount(e.target.value)}
            fullWidth
          >
            <MenuItem value="">Sin desembolso</MenuItem>
            {ownerAccounts.map((a) => (
              <MenuItem key={a.accountId} value={a.accountId}>
                {a.accountId} — {a.iban}
              </MenuItem>
            ))}
          </TextField>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setApprove(null)}>Cancelar</Button>
          <Button
            variant="contained"
            color="success"
            onClick={submitApprove}
            disabled={busy}
            startIcon={busy ? <CircularProgress size={16} color="inherit" /> : null}
          >
            Aprobar
          </Button>
        </DialogActions>
      </Dialog>

      {/* Reject dialog */}
      <Dialog open={reject !== null} onClose={() => setReject(null)} fullWidth maxWidth="xs">
        <DialogTitle>Rechazar préstamo {reject?.loanId}</DialogTitle>
        <DialogContent>
          <TextField
            label="Motivo"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            fullWidth
            multiline
            minRows={2}
            sx={{ mt: 1 }}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setReject(null)}>Cancelar</Button>
          <Button
            variant="contained"
            color="error"
            onClick={submitReject}
            disabled={busy || !reason.trim()}
            startIcon={busy ? <CircularProgress size={16} color="inherit" /> : null}
          >
            Rechazar
          </Button>
        </DialogActions>
      </Dialog>

      {/* Schedule dialog */}
      <Dialog open={schedule !== null} onClose={() => setSchedule(null)} fullWidth maxWidth="md">
        <DialogTitle>Cuadro de amortización</DialogTitle>
        <DialogContent>
          {schedule && (
            <>
              <Stack direction="row" spacing={3} sx={{ mb: 2 }} useFlexGap flexWrap="wrap">
                <Typography>
                  Cuota: <b>{eur(schedule.monthlyPayment)}</b>
                </Typography>
                <Typography>
                  Total pagado: <b>{eur(schedule.totalPaid)}</b>
                </Typography>
                <Typography>
                  Intereses: <b>{eur(schedule.totalInterest)}</b>
                </Typography>
              </Stack>
              <TableContainer component={Paper} variant="outlined" sx={{ maxHeight: 420 }}>
                <Table size="small" stickyHeader>
                  <TableHead>
                    <TableRow>
                      <TableCell>Mes</TableCell>
                      <TableCell>Vencimiento</TableCell>
                      <TableCell align="right">Cuota</TableCell>
                      <TableCell align="right">Interés</TableCell>
                      <TableCell align="right">Capital</TableCell>
                      <TableCell align="right">Pendiente</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {schedule.schedule.map((r) => (
                      <TableRow key={r.month}>
                        <TableCell>{r.month}</TableCell>
                        <TableCell>{r.dueDate}</TableCell>
                        <TableCell align="right" sx={{ fontFamily: MONO }}>{eur(r.payment)}</TableCell>
                        <TableCell align="right" sx={{ fontFamily: MONO }}>{eur(r.interest)}</TableCell>
                        <TableCell align="right" sx={{ fontFamily: MONO }}>{eur(r.principal)}</TableCell>
                        <TableCell align="right" sx={{ fontFamily: MONO }}>{eur(r.remaining)}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
            </>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setSchedule(null)}>Cerrar</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
