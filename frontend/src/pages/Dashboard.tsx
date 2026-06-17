import { useEffect, useState } from 'react';
import Typography from '@mui/material/Typography';
import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import CardContent from '@mui/material/CardContent';
import Stack from '@mui/material/Stack';
import Avatar from '@mui/material/Avatar';
import CircularProgress from '@mui/material/CircularProgress';
import Alert from '@mui/material/Alert';
import Divider from '@mui/material/Divider';
import Chip from '@mui/material/Chip';
import PeopleIcon from '@mui/icons-material/People';
import SavingsIcon from '@mui/icons-material/Savings';
import EuroIcon from '@mui/icons-material/Euro';
import RequestQuoteIcon from '@mui/icons-material/RequestQuote';
import CreditCardIcon from '@mui/icons-material/CreditCard';
import type { ReactElement } from 'react';

import { api, eur, errMsg } from '../api/client';
import type { BankReport, AuditStats } from '../api/types';
import PageHeader from '../ui/PageHeader';

interface Kpi {
  label: string;
  value: string;
  icon: ReactElement;
  color: string;
}

function KpiCard({ kpi }: { kpi: Kpi }) {
  return (
    <Card
      sx={{
        flex: '1 1 210px',
        minWidth: 210,
        borderTop: `3px solid ${kpi.color}`,
        transition: 'transform .15s ease, box-shadow .15s ease',
        '&:hover': { transform: 'translateY(-3px)', boxShadow: '0 8px 24px rgba(16,40,66,0.10)' },
      }}
    >
      <CardContent>
        <Stack direction="row" spacing={2} alignItems="center">
          <Avatar
            variant="rounded"
            sx={{
              background: `linear-gradient(135deg, ${kpi.color} 0%, ${kpi.color}cc 100%)`,
              width: 50,
              height: 50,
            }}
          >
            {kpi.icon}
          </Avatar>
          <Box sx={{ minWidth: 0 }}>
            <Typography variant="h5" noWrap>
              {kpi.value}
            </Typography>
            <Typography variant="body2" color="text.secondary">
              {kpi.label}
            </Typography>
          </Box>
        </Stack>
      </CardContent>
    </Card>
  );
}

export default function Dashboard() {
  const [bank, setBank] = useState<BankReport | null>(null);
  const [stats, setStats] = useState<AuditStats | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      api.get<BankReport>('/reports/bank'),
      api.get<AuditStats>('/audit/stats'),
    ])
      .then(([b, s]) => {
        setBank(b.data);
        setStats(s.data);
      })
      .catch((e) => setError(errMsg(e)))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <CircularProgress />;
  if (error) return <Alert severity="error">{error}</Alert>;
  if (!bank || !stats) return null;

  const kpis: Kpi[] = [
    { label: 'Clientes activos', value: String(bank.activeCustomers), icon: <PeopleIcon />, color: '#1565c0' },
    { label: 'Cuentas activas', value: String(bank.totalAccounts), icon: <SavingsIcon />, color: '#00897b' },
    { label: 'Depósitos totales', value: eur(bank.totalDeposits), icon: <EuroIcon />, color: '#2e7d32' },
    { label: 'Préstamos activos', value: `${bank.activeLoans} · ${eur(bank.totalLoanAmount)}`, icon: <RequestQuoteIcon />, color: '#ef6c00' },
    { label: 'Tarjetas activas', value: String(bank.activeCards), icon: <CreditCardIcon />, color: '#6a1b9a' },
  ];

  return (
    <Box>
      <PageHeader title="Dashboard" subtitle="Resumen operativo del banco" />

      <Stack direction="row" spacing={2.5} useFlexGap flexWrap="wrap" sx={{ mb: 3 }}>
        {kpis.map((k) => (
          <KpiCard key={k.label} kpi={k} />
        ))}
      </Stack>

      <Stack direction="row" spacing={2.5} useFlexGap flexWrap="wrap">
        <Card sx={{ flex: '1 1 320px' }}>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              Actividad auditada por entidad
            </Typography>
            <Typography variant="body2" color="text.secondary" gutterBottom>
              {stats.totalEntries} eventos · {stats.distinctUsers} usuarios
            </Typography>
            <Divider sx={{ my: 1.5 }} />
            <Stack direction="row" spacing={1} useFlexGap flexWrap="wrap">
              {stats.byEntity.map((g) => (
                <Chip key={g.name} label={`${g.name}: ${g.count}`} variant="outlined" />
              ))}
            </Stack>
          </CardContent>
        </Card>

        <Card sx={{ flex: '1 1 320px' }}>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              Operaciones más frecuentes
            </Typography>
            <Divider sx={{ my: 1.5 }} />
            <Stack direction="row" spacing={1} useFlexGap flexWrap="wrap">
              {stats.byOperation.slice(0, 10).map((g) => (
                <Chip key={g.name} label={`${g.name}: ${g.count}`} color="primary" variant="outlined" />
              ))}
            </Stack>
          </CardContent>
        </Card>
      </Stack>
    </Box>
  );
}
