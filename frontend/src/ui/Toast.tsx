import { createContext, useCallback, useContext, useState } from 'react';
import type { ReactNode } from 'react';
import Snackbar from '@mui/material/Snackbar';
import Alert from '@mui/material/Alert';
import type { AlertColor } from '@mui/material/Alert';

type ShowToast = (message: string, severity?: AlertColor) => void;

const ToastContext = createContext<ShowToast>(() => undefined);

export function useToast(): ShowToast {
  return useContext(ToastContext);
}

interface ToastState {
  open: boolean;
  message: string;
  severity: AlertColor;
}

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toast, setToast] = useState<ToastState>({
    open: false,
    message: '',
    severity: 'success',
  });

  const show = useCallback<ShowToast>((message, severity = 'success') => {
    setToast({ open: true, message, severity });
  }, []);

  const close = () => setToast((s) => ({ ...s, open: false }));

  return (
    <ToastContext.Provider value={show}>
      {children}
      <Snackbar
        open={toast.open}
        autoHideDuration={4500}
        onClose={close}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
      >
        <Alert severity={toast.severity} variant="filled" onClose={close} sx={{ maxWidth: 440 }}>
          {toast.message}
        </Alert>
      </Snackbar>
    </ToastContext.Provider>
  );
}
