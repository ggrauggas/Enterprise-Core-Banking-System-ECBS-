import { useEffect, useState } from 'react';
import axios from 'axios';
import AppBar from '@mui/material/AppBar';
import Toolbar from '@mui/material/Toolbar';
import Typography from '@mui/material/Typography';
import Container from '@mui/material/Container';
import Card from '@mui/material/Card';
import CardContent from '@mui/material/CardContent';
import Chip from '@mui/material/Chip';
import Stack from '@mui/material/Stack';
import CircularProgress from '@mui/material/CircularProgress';
import AccountBalanceIcon from '@mui/icons-material/AccountBalance';

interface SystemInfo {
  service: string;
  version: string;
  timestamp: string;
  cobolBridge?: { status?: string; programCount?: number; error?: string };
  cobolHello?: { exitCode?: number; data?: { message?: string; timestamp?: string } };
}

type LoadState =
  | { kind: 'loading' }
  | { kind: 'error'; message: string }
  | { kind: 'ready'; info: SystemInfo };

function StatusChip({ up, label }: { up: boolean; label: string }) {
  return <Chip label={label} color={up ? 'success' : 'error'} size="small" />;
}

export default function App() {
  const [state, setState] = useState<LoadState>({ kind: 'loading' });

  useEffect(() => {
    axios
      .get<SystemInfo>('/api/v1/system/info')
      .then((res) => setState({ kind: 'ready', info: res.data }))
      .catch((err) => setState({ kind: 'error', message: String(err) }));
  }, []);

  return (
    <>
      <AppBar position="static">
        <Toolbar>
          <AccountBalanceIcon sx={{ mr: 2 }} />
          <Typography variant="h6" component="div">
            ECBS — Enterprise Core Banking System
          </Typography>
        </Toolbar>
      </AppBar>

      <Container maxWidth="md" sx={{ mt: 4 }}>
        <Typography variant="h5" gutterBottom>
          Estado del sistema (Fase 1)
        </Typography>

        {state.kind === 'loading' && <CircularProgress />}

        {state.kind === 'error' && (
          <Card>
            <CardContent>
              <Stack direction="row" spacing={2} alignItems="center">
                <StatusChip up={false} label="Backend DOWN" />
                <Typography color="text.secondary">{state.message}</Typography>
              </Stack>
            </CardContent>
          </Card>
        )}

        {state.kind === 'ready' && (
          <Stack spacing={2}>
            <Card>
              <CardContent>
                <Stack direction="row" spacing={2} alignItems="center">
                  <StatusChip up label="Backend UP" />
                  <Typography>
                    {state.info.service} v{state.info.version} — {state.info.timestamp}
                  </Typography>
                </Stack>
              </CardContent>
            </Card>

            <Card>
              <CardContent>
                <Stack direction="row" spacing={2} alignItems="center">
                  <StatusChip
                    up={state.info.cobolBridge?.status === 'UP'}
                    label={`COBOL Bridge ${state.info.cobolBridge?.status ?? 'DOWN'}`}
                  />
                  <Typography>
                    {state.info.cobolBridge?.status === 'UP'
                      ? `${state.info.cobolBridge?.programCount ?? 0} programas disponibles`
                      : state.info.cobolBridge?.error ?? 'sin conexión'}
                  </Typography>
                </Stack>
              </CardContent>
            </Card>

            <Card>
              <CardContent>
                <Stack direction="row" spacing={2} alignItems="center">
                  <StatusChip
                    up={state.info.cobolHello?.exitCode === 0}
                    label="Programa COBOL HELLO"
                  />
                  <Typography>
                    {state.info.cobolHello?.data?.message ?? 'sin respuesta'}
                  </Typography>
                </Stack>
              </CardContent>
            </Card>
          </Stack>
        )}
      </Container>
    </>
  );
}
