import { createContext, useCallback, useContext, useRef, useState } from 'react';
import type { ReactNode } from 'react';
import Dialog from '@mui/material/Dialog';
import DialogTitle from '@mui/material/DialogTitle';
import DialogContent from '@mui/material/DialogContent';
import DialogContentText from '@mui/material/DialogContentText';
import DialogActions from '@mui/material/DialogActions';
import Button from '@mui/material/Button';
import Box from '@mui/material/Box';
import Stack from '@mui/material/Stack';
import Typography from '@mui/material/Typography';
import WarningAmberRoundedIcon from '@mui/icons-material/WarningAmberRounded';
import HelpOutlineRoundedIcon from '@mui/icons-material/HelpOutlineRounded';

/** Visual tone of a confirmation, mapped onto the restricted palette. */
export type ConfirmTone = 'info' | 'warning' | 'danger';

/** A single labelled row shown in the contextual summary panel. */
export interface ConfirmDetail {
  label: string;
  value: ReactNode;
  /** Render the value with the monospace family (amounts, IBAN, ids). */
  mono?: boolean;
  /** Tint the value red — for figures or fields that need attention. */
  emphasis?: boolean;
}

interface ConfirmOptions {
  title?: string;
  message: ReactNode;
  confirmText?: string;
  cancelText?: string;
  /** info = blue (default), warning = yellow, danger = red. */
  tone?: ConfirmTone;
  /** Custom action icon. Falls back to a tone-appropriate default. */
  icon?: ReactNode;
  /** Contextual key/value rows describing exactly what will happen. */
  details?: ConfirmDetail[];
  /** Back-compat alias: when true the dialog uses the `danger` tone. */
  destructive?: boolean;
}

type ConfirmFn = (options: ConfirmOptions) => Promise<boolean>;

const ConfirmContext = createContext<ConfirmFn>(async () => false);

/** Returns an async `confirm(options)` that resolves to the user's choice. */
export function useConfirm(): ConfirmFn {
  return useContext(ConfirmContext);
}

const MONO = '"JetBrains Mono", ui-monospace, monospace';

// Each tone carries its own icon chip colour and confirm-button colour. Only
// blue / yellow / red are used, in line with the banking palette.
const TONES: Record<
  ConfirmTone,
  { chipBg: string; chipFg: string; button: 'primary' | 'warning' | 'error'; icon: ReactNode }
> = {
  info: {
    chipBg: 'rgba(21,83,158,0.10)',
    chipFg: '#15539e',
    button: 'primary',
    icon: <HelpOutlineRoundedIcon fontSize="small" />,
  },
  warning: {
    chipBg: 'rgba(230,167,0,0.18)',
    chipFg: '#8a6300',
    button: 'warning',
    icon: <WarningAmberRoundedIcon fontSize="small" />,
  },
  danger: {
    chipBg: 'rgba(211,47,47,0.10)',
    chipFg: '#b5302c',
    button: 'error',
    icon: <WarningAmberRoundedIcon fontSize="small" />,
  },
};

interface State {
  open: boolean;
  options: ConfirmOptions;
}

export function ConfirmProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<State>({ open: false, options: { message: '' } });
  const resolver = useRef<(value: boolean) => void>();

  const confirm = useCallback<ConfirmFn>((options) => {
    setState({ open: true, options });
    return new Promise<boolean>((resolve) => {
      resolver.current = resolve;
    });
  }, []);

  const settle = (result: boolean) => {
    setState((s) => ({ ...s, open: false }));
    resolver.current?.(result);
    resolver.current = undefined;
  };

  const o = state.options;
  const tone: ConfirmTone = o.tone ?? (o.destructive ? 'danger' : 'info');
  const t = TONES[tone];

  return (
    <ConfirmContext.Provider value={confirm}>
      {children}
      <Dialog open={state.open} onClose={() => settle(false)} maxWidth="xs" fullWidth>
        <DialogTitle sx={{ display: 'flex', alignItems: 'center', gap: 1.25 }}>
          <Box
            sx={{
              display: 'inline-flex',
              p: 0.85,
              borderRadius: 2.5,
              bgcolor: t.chipBg,
              color: t.chipFg,
            }}
          >
            {o.icon ?? t.icon}
          </Box>
          {o.title ?? 'Confirmar acción'}
        </DialogTitle>
        <DialogContent>
          <DialogContentText sx={{ color: 'text.secondary' }}>{o.message}</DialogContentText>

          {o.details && o.details.length > 0 && (
            <Stack
              spacing={0}
              sx={{
                mt: 2,
                borderRadius: 2.5,
                border: '1px solid',
                borderColor: 'divider',
                bgcolor: '#f7faff',
                overflow: 'hidden',
              }}
            >
              {o.details.map((d, i) => (
                <Box
                  key={d.label}
                  sx={{
                    display: 'flex',
                    alignItems: 'baseline',
                    justifyContent: 'space-between',
                    gap: 2,
                    px: 1.75,
                    py: 1,
                    borderTop: i === 0 ? 'none' : '1px solid',
                    borderColor: 'divider',
                  }}
                >
                  <Typography
                    variant="caption"
                    sx={{ color: 'text.secondary', fontWeight: 600, letterSpacing: '0.02em' }}
                  >
                    {d.label}
                  </Typography>
                  <Typography
                    variant="body2"
                    sx={{
                      textAlign: 'right',
                      fontWeight: 600,
                      fontFamily: d.mono ? MONO : undefined,
                      color: d.emphasis ? 'error.main' : 'text.primary',
                    }}
                  >
                    {d.value}
                  </Typography>
                </Box>
              ))}
            </Stack>
          )}
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2.5 }}>
          <Button onClick={() => settle(false)} color="inherit">
            {o.cancelText ?? 'Cancelar'}
          </Button>
          <Button variant="contained" color={t.button} onClick={() => settle(true)} autoFocus>
            {o.confirmText ?? 'Confirmar'}
          </Button>
        </DialogActions>
      </Dialog>
    </ConfirmContext.Provider>
  );
}
