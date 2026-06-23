import { useEffect, useState } from 'react';
import Typography from '@mui/material/Typography';
import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import CardContent from '@mui/material/CardContent';
import Stack from '@mui/material/Stack';
import Skeleton from '@mui/material/Skeleton';
import Alert from '@mui/material/Alert';
import Divider from '@mui/material/Divider';
import type { ReactNode } from 'react';

import { api, eur, errMsg } from '../api/client';
import type { BankReport, AuditStats } from '../api/types';
import PageHeader from '../ui/PageHeader';

const MONO = '"JetBrains Mono", ui-monospace, monospace';
// Single-hue palette: every accent is a tone of this blue.
const BLUE = '#15539e';
const BLUE_DEEP = '#0d2740';
const TRACK = '#e7eefa';

interface Metric {
  label: string;
  value: string;
  hint?: string;
}

/**
 * Flagship banking panel: the headline figure on a navy field (echoing the
 * app bar), with the supporting metrics laid out as a divided strip below.
 */
function HeroBoard({ headline, metrics }: { headline: Metric; metrics: Metric[] }) {
  return (
    <Box
      component="section"
      sx={{
        borderRadius: 4,
        p: { xs: 3, md: 4 },
        mb: 3,
        color: '#fff',
        position: 'relative',
        overflow: 'hidden',
        background:
          'radial-gradient(135% 160% at 0% 0%, #1d5891 0%, #103254 48%, #0b2238 100%)',
        boxShadow: '0 20px 44px -20px rgba(13,39,64,0.55)',
      }}
    >
      <Typography
        variant="overline"
        sx={{ opacity: 0.62, letterSpacing: '0.16em', display: 'block' }}
      >
        {headline.label}
      </Typography>
      <Typography
        sx={{
          fontSize: { xs: '2.5rem', md: '3.1rem' },
          fontWeight: 800,
          letterSpacing: '-0.025em',
          lineHeight: 1,
          mt: 0.5,
          fontVariantNumeric: 'tabular-nums',
        }}
      >
        {headline.value}
      </Typography>
      {headline.hint && (
        <Typography variant="body2" sx={{ opacity: 0.66, mt: 1.25 }}>
          {headline.hint}
        </Typography>
      )}

      <Divider sx={{ my: { xs: 2.5, md: 3.25 }, borderColor: 'rgba(255,255,255,0.13)' }} />

      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: { xs: 'repeat(2, 1fr)', md: 'repeat(4, 1fr)' },
        }}
      >
        {metrics.map((m, i) => (
          <Box
            key={m.label}
            sx={{
              px: { xs: 0, md: 2.5 },
              py: { xs: 1.25, md: 0 },
              borderLeft: { md: i === 0 ? 'none' : '1px solid rgba(255,255,255,0.12)' },
              '&:first-of-type': { pl: { md: 0 } },
            }}
          >
            <Typography
              variant="overline"
              sx={{ opacity: 0.6, letterSpacing: '0.1em', display: 'block', lineHeight: 1.6 }}
            >
              {m.label}
            </Typography>
            <Typography
              sx={{
                fontSize: '1.5rem',
                fontWeight: 700,
                letterSpacing: '-0.01em',
                lineHeight: 1.1,
                mt: 0.25,
                fontVariantNumeric: 'tabular-nums',
              }}
            >
              {m.value}
            </Typography>
            {m.hint && (
              <Typography variant="caption" sx={{ opacity: 0.55, display: 'block', mt: 0.25 }}>
                {m.hint}
              </Typography>
            )}
          </Box>
        ))}
      </Box>
    </Box>
  );
}

interface Group {
  name: string;
  count: number;
}

/** Ranked distribution rendered as a horizontal bar list (all blue). */
function BarList({ items, empty }: { items: Group[]; empty: string }) {
  if (items.length === 0) {
    return (
      <Typography variant="body2" color="text.secondary" sx={{ py: 2 }}>
        {empty}
      </Typography>
    );
  }
  const max = Math.max(...items.map((i) => i.count), 1);
  return (
    <Stack spacing={1.75} sx={{ mt: 0.5 }}>
      {items.map((g) => (
        <Box
          key={g.name}
          sx={{
            display: 'grid',
            gridTemplateColumns: 'minmax(96px, 168px) 1fr auto',
            alignItems: 'center',
            columnGap: 1.5,
          }}
        >
          <Typography
            variant="body2"
            noWrap
            title={g.name}
            sx={{ fontWeight: 600, color: 'text.primary', letterSpacing: '0.01em' }}
          >
            {g.name}
          </Typography>
          <Box sx={{ height: 9, borderRadius: 5, bgcolor: TRACK, overflow: 'hidden' }}>
            <Box
              sx={{
                height: '100%',
                width: `${Math.round((g.count / max) * 100)}%`,
                minWidth: 6,
                borderRadius: 5,
                background: `linear-gradient(90deg, ${BLUE} 0%, #2e6fc0 100%)`,
                transition: 'width .4s ease',
              }}
            />
          </Box>
          <Typography
            variant="body2"
            sx={{ fontFamily: MONO, fontWeight: 600, color: BLUE_DEEP, minWidth: 40, textAlign: 'right' }}
          >
            {g.count.toLocaleString('es-ES')}
          </Typography>
        </Box>
      ))}
    </Stack>
  );
}

function Panel({ title, meta, children }: { title: string; meta?: ReactNode; children: ReactNode }) {
  return (
    <Card sx={{ flex: '1 1 340px', minWidth: 300 }}>
      <CardContent sx={{ p: 3 }}>
        <Stack
          direction="row"
          justifyContent="space-between"
          alignItems="baseline"
          sx={{ mb: 2, pb: 1.5, borderBottom: '1px solid', borderColor: 'divider' }}
        >
          <Typography variant="h6">{title}</Typography>
          {meta && (
            <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>
              {meta}
            </Typography>
          )}
        </Stack>
        {children}
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

  if (loading) {
    return (
      <Box>
        <PageHeader title="Dashboard" subtitle="Resumen operativo del banco" />
        <Skeleton variant="rounded" height={252} sx={{ borderRadius: 4, mb: 3 }} />
        <Stack direction="row" spacing={2.5} useFlexGap flexWrap="wrap">
          <Skeleton variant="rounded" height={240} sx={{ flex: '1 1 340px', borderRadius: 4 }} />
          <Skeleton variant="rounded" height={240} sx={{ flex: '1 1 340px', borderRadius: 4 }} />
        </Stack>
      </Box>
    );
  }
  if (error) return <Alert severity="error">{error}</Alert>;
  if (!bank || !stats) return null;

  const inactiveCustomers = bank.totalCustomers - bank.activeCustomers;

  const headline: Metric = {
    label: 'Depósitos totales bajo gestión',
    value: eur(bank.totalDeposits),
    hint: `Saldo agregado de ${bank.totalAccounts.toLocaleString('es-ES')} cuentas en ${bank.activeCustomers.toLocaleString('es-ES')} clientes activos`,
  };

  const metrics: Metric[] = [
    {
      label: 'Clientes activos',
      value: bank.activeCustomers.toLocaleString('es-ES'),
      hint: `${bank.totalCustomers.toLocaleString('es-ES')} en cartera · ${inactiveCustomers} inactivos`,
    },
    {
      label: 'Cuentas abiertas',
      value: bank.totalAccounts.toLocaleString('es-ES'),
      hint: 'Corrientes y de ahorro',
    },
    {
      label: 'Préstamos activos',
      value: bank.activeLoans.toLocaleString('es-ES'),
      hint: `${eur(bank.totalLoanAmount)} en circulación`,
    },
    {
      label: 'Tarjetas activas',
      value: bank.activeCards.toLocaleString('es-ES'),
      hint: 'Operativas para compras',
    },
  ];

  const period =
    stats.firstEvent && stats.lastEvent
      ? `${stats.firstEvent.slice(0, 10)} — ${stats.lastEvent.slice(0, 10)}`
      : undefined;

  return (
    <Box>
      <PageHeader title="Dashboard" subtitle="Resumen operativo del banco" />

      <HeroBoard headline={headline} metrics={metrics} />

      <Stack direction="row" spacing={2.5} useFlexGap flexWrap="wrap" alignItems="stretch">
        <Panel
          title="Actividad por entidad"
          meta={`${stats.totalEntries.toLocaleString('es-ES')} eventos · ${stats.distinctUsers} usuarios`}
        >
          <BarList items={stats.byEntity} empty="Sin actividad registrada" />
        </Panel>

        <Panel title="Operaciones más frecuentes" meta={period}>
          <BarList items={stats.byOperation.slice(0, 8)} empty="Sin operaciones registradas" />
        </Panel>
      </Stack>
    </Box>
  );
}
