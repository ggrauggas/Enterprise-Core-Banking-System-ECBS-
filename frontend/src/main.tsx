import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import CssBaseline from '@mui/material/CssBaseline';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import App from './App';
import { ToastProvider } from './ui/Toast';

const theme = createTheme({
  palette: {
    mode: 'light',
    primary: { main: '#0d47a1' },
    secondary: { main: '#00695c' },
    background: { default: '#f4f6f8' },
  },
  shape: { borderRadius: 10 },
});

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <ToastProvider>
        <BrowserRouter>
          <App />
        </BrowserRouter>
      </ToastProvider>
    </ThemeProvider>
  </React.StrictMode>,
);
