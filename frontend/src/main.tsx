import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import CssBaseline from '@mui/material/CssBaseline';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import App from './App';
import { ToastProvider } from './ui/Toast';

const NAVY = '#0b3d66';
const NAVY_DARK = '#072742';
const BORDER = '#e3e8ef';

const theme = createTheme({
  palette: {
    mode: 'light',
    primary: { main: NAVY, dark: NAVY_DARK, light: '#3f6d96' },
    secondary: { main: '#159b78' },
    success: { main: '#1b8a5a' },
    error: { main: '#c62828' },
    warning: { main: '#ed9c1c' },
    info: { main: '#2972b6' },
    background: { default: '#eef1f5', paper: '#ffffff' },
    text: { primary: '#1c2733', secondary: '#5b6b7f' },
    divider: BORDER,
  },
  shape: { borderRadius: 12 },
  typography: {
    fontFamily: '"Inter", "Roboto", "Helvetica", "Arial", sans-serif',
    h4: { fontWeight: 800, letterSpacing: '-0.02em' },
    h5: { fontWeight: 700, letterSpacing: '-0.01em' },
    h6: { fontWeight: 700 },
    subtitle2: { fontWeight: 600 },
    button: { fontWeight: 600 },
  },
  components: {
    MuiAppBar: {
      styleOverrides: { root: { backgroundImage: 'none' } },
    },
    MuiButton: {
      defaultProps: { disableElevation: true },
      styleOverrides: { root: { textTransform: 'none', borderRadius: 8 } },
    },
    MuiCard: {
      defaultProps: { elevation: 0 },
      styleOverrides: {
        root: {
          border: `1px solid ${BORDER}`,
          borderRadius: 14,
          boxShadow: '0 1px 2px rgba(16,40,66,0.04)',
        },
      },
    },
    MuiPaper: {
      styleOverrides: { outlined: { borderColor: BORDER } },
    },
    MuiTableCell: {
      styleOverrides: {
        head: {
          backgroundColor: '#f5f7fa',
          color: '#566677',
          fontWeight: 700,
          fontSize: 11,
          letterSpacing: '0.06em',
          textTransform: 'uppercase',
        },
        root: { borderColor: '#eef1f5' },
      },
    },
    MuiTableRow: {
      styleOverrides: {
        root: { '&:last-child td': { borderBottom: 0 } },
      },
    },
    MuiChip: {
      styleOverrides: { root: { fontWeight: 600, borderRadius: 8 } },
    },
    MuiDrawer: {
      styleOverrides: {
        paper: { borderRight: `1px solid ${BORDER}`, backgroundColor: '#ffffff' },
      },
    },
    MuiTableContainer: {
      styleOverrides: { root: { borderRadius: 14 } },
    },
  },
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
